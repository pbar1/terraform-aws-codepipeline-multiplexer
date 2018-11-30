resource "github_repository_webhook" "repo" {
  repository = "${var.repo_name}"
  name       = "web"
  active     = true
  events     = ["pull_request"]

  configuration {
    url          = "REPLACEME"
    content_type = "application/json"
    insecure_ssl = false
  }
}

#--------------------------------------------------------------------
# API Gateway
#--------------------------------------------------------------------

resource "aws_api_gateway_rest_api" "gh" {
  name        = "${var.github_repository}-codepipeline"
  description = "Webhook to catch GitHub PRs from ${var.github_repository}"
}

resource "aws_api_gateway_method" "webhooks" {
  rest_api_id   = "${aws_api_gateway_rest_api.gh.id}"
  resource_id   = "${aws_api_gateway_rest_api.gh.root_resource_id}"
  http_method   = "POST"
  authorization = "NONE"

  request_parameters = {
    "method.request.header.X-GitHub-Event"    = true
    "method.request.header.X-GitHub-Delivery" = true
  }
}

resource "aws_api_gateway_integration" "webhooks" {
  rest_api_id             = "${aws_api_gateway_rest_api.gh.id}"
  resource_id             = "${aws_api_gateway_rest_api.gh.root_resource_id}"
  http_method             = "${aws_api_gateway_method.webhooks.http_method}"
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${aws_lambda_function.lambda.arn}/invocations"

  request_parameters = {
    "integration.request.header.X-GitHub-Event" = "method.request.header.X-GitHub-Event"
  }

  request_templates = {
    "application/json" = <<JSON
{
  "body" : $input.json('$'),
  "header" : {
    "X-GitHub-Event": "$input.params('X-GitHub-Event')",
    "X-GitHub-Delivery": "$input.params('X-GitHub-Delivery')"
  }
}
JSON
  }
}

resource "aws_api_gateway_integration_response" "webhook" {
  rest_api_id = "${aws_api_gateway_rest_api.gh.id}"
  resource_id = "${aws_api_gateway_rest_api.gh.root_resource_id}"
  http_method = "${aws_api_gateway_integration.webhooks.http_method}"
  status_code = "200"

  response_templates {
    "application/json" = "$input.path('$')"
  }

  response_parameters = {
    "method.response.header.Content-Type"                = "integration.response.header.Content-Type"
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  selection_pattern = ".*"
}

resource "aws_api_gateway_method_response" "200" {
  rest_api_id = "${aws_api_gateway_rest_api.gh.id}"
  resource_id = "${aws_api_gateway_rest_api.gh.root_resource_id}"
  http_method = "${aws_api_gateway_method.webhooks.http_method}"
  status_code = "200"

  response_parameters = {
    "method.response.header.Content-Type"                = true
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_deployment" "gh" {
  depends_on = ["aws_api_gateway_method.webhooks"]

  rest_api_id = "${aws_api_gateway_rest_api.gh.id}"
  stage_name  = ""
}

#--------------------------------------------------------------------
# Lambda
#--------------------------------------------------------------------

resource "aws_lambda_permission" "lambda" {
  statement_id   = "AllowExecutionFromAPIGateway"
  action         = "lambda:InvokeFunction"
  function_name  = "${aws_lambda_function.lambda.arn}"
  prinprojectpal = "apigateway.amazonaws.com"
  source_arn     = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.gh.id}/*/POST/"
}

resource "aws_lambda_function" "lambda" {
  filename         = "handler.zip"
  source_code_hash = "${base64sha256(file("handler.zip"))}"
  handler          = "lambda_handler"
  function_name    = "Handler"
  role             = "${aws_iam_role.lambda.arn}"
  memory_size      = 256
  timeout          = 300
  runtime          = "go1.x"

  environment {
    variables = {
      CODEPIPELINE_PROJECT = "${var.github_repository}"
      GITHUB_SSM_PARAM     = "${var.github_oauth_token_ssm_param}"
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "cp-management"
  assume_role_policy = "${data.aws_iam_policy_document.lambda_assume.json}"
}

resource "aws_iam_role_policy_attachment" "lambda" {
  role       = "${aws_iam_role.lambda.name}"
  policy_arn = "${aws_iam_policy.lambda.arn}"
}

resource "aws_iam_policy" "lambda" {
  name        = "codepipeline-pr-policy"
  path        = "/"
  description = "Allows Lambda to manage temporary CodePipeline projects for PR branches"
  policy      = "${data.aws_iam_policy_document.lambda_policy.json}"
}

#--------------------------------------------------------------------
# CodePipeline & CodeBuild
#--------------------------------------------------------------------

resource "aws_codepipeline" "codepipeline" {
  name     = "${var.github_repository}"
  role_arn = "${var.iam_role_codepipeline}"

  artifact_store {
    location = "${var.artifact_bucket}"
    type     = "S3"

    encryption_key {
      id   = "${var.artifact_bucket_kms_key}"
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source"]

      configuration {
        Owner      = "${var.github_organization}"
        Repo       = "${var.github_repository}"
        Branch     = "${var.github_branch_default}"
        OAuthToken = "${data.aws_ssm_parameter.github_oauth_token.value}"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source"]
      version         = "1"

      configuration {
        ProjectName = "${aws_codebuild_project.codebuild.name}"
      }
    }
  }
}

resource "aws_codebuild_project" "codebuild" {
  name          = "${var.github_repository}"
  description   = "Build step for ${var.github_organization}/${var.github_repository}"
  build_timeout = "10"
  service_role  = "${var.iam_role_codebuild}"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "${var.codebuild_compute_type}"
    image           = "${var.codebuild_image}"
    type            = "${var.codebuild_os}"
    privileged_mode = "${var.codebuild_privileged_mode}"
  }

  source {
    type = "CODEPIPELINE"
  }
}
