#--------------------------------------------------------------------
# GitHub
#--------------------------------------------------------------------

variable "github_organization" {
  description = "GitHub organization that owns the source repository"
}

variable "github_repository" {
  description = "GitHub source repository"
}

variable "github_branch_default" {
  description = "Git branch for the default CodePipeline source step to watch"
  default     = "master"
}

variable "github_oauth_token_ssm_param" {
  description = "Name of AWS SSM Parameter that holds a GitHub OAuth token. Must be of type `SecureString`"
}

#--------------------------------------------------------------------
# API Gateway & Lambda
#--------------------------------------------------------------------

variable "lambda_timeout" {
  description = "Time limit (in seconds) for the Lambda function execution"
  default     = 300
}

variable "lambda_memory" {
  description = "Memory limit (in MB) to allocate to the Lambda function"
  default     = 256
}

#--------------------------------------------------------------------
# CodePipeline & CodeBuild
#--------------------------------------------------------------------

variable "artifact_bucket" {
  description = "Name of an S3 bucket to store artifacts in"
}

variable "artifact_bucket_kms_key" {
  description = "ARN of the artifact bucket's KMS key used for encryption"
}

variable "iam_role_codepipeline" {
  description = "ARN of an IAM role for CodePipeline to run as"
}

variable "iam_role_codebuild" {
  description = "ARN of an IAM role for CodeBuild to run as"
}

variable "codebuild_image" {
  default = "aws/codebuild/docker:17.09.0"
}

variable "codebuild_compute_type" {
  default = "BUILD_GENERAL1_SMALL"
}

variable "codebuild_os" {
  default = "LINUX_CONTAINER"
}

variable "codebuild_privileged_mode" {
  default = true
}
