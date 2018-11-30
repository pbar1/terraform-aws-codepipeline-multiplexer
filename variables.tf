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
# CodePipeline & CodeBuild
#--------------------------------------------------------------------

variable "artifact_bucket" {
  description = "Name of an S3 bucket to store artifacts in. If not specified, one will be created."
  default     = ""
}

variable "artifact_bucket_kms_key" {
  description = "ARN of the artifact bucket's KMS key used for encryption. If not specified, one will be created."
}

variable "iam_role_codepipeline" {
  description = "ARN of an IAM role for CodePipeline to run as. If not specified, one will be created."
  default     = ""
}

variable "iam_role_codebuild" {
  description = "ARN of an IAM role for CodeBuild to run as. If not specified, one will be created."
  default     = ""
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

#--------------------------------------------------------------------
# API Gateway & Lambda
#--------------------------------------------------------------------

variable "iam_role_lambda" {
  description = "ARN of an IAM role for Lambda to run as. If not specified, one will be created."
  default     = ""
}
