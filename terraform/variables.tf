variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "image_repo_name" {
  description = "Name of the ECR repository for images"
  type        = string
  default     = "my-app-images"
}

variable "signature_repo_name" {
  description = "Name of the ECR repository for signatures"
  type        = string
  default     = "my-app-signatures"
}

variable "github_repo" {
  description = "GitHub repository for the Application (format: org/repo) that will push/sign images"
  type        = string
  # Update this with your actual app repo
  default     = "my-org/app-repo"
}

variable "secondary_region" {
  description = "Secondary AWS Region for ECR Replication"
  type        = string
  default     = "ca-central-1"
}

variable "admin_role_name" {
  description = "Name of the IAM role for Administrators"
  type        = string
  sensitive   = true
  # No default value to prevent committing sensitive data
}
