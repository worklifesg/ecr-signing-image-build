# OIDC Provider for GitHub Actions (Data Source for existing provider)
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name = "github-actions-ecr-signing-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github.arn
      }
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" : "repo:${var.github_repo}:*"
        }
      }
    }]
  })
}

# Policy for ECR and KMS Access
resource "aws_iam_role_policy" "signing_policy" {
  name = "ecr-signing-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = [
          aws_ecr_repository.image_repo.arn,
          aws_ecr_repository.signature_repo.arn
        ]
      },
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Sign",
          "kms:Verify",
          "kms:GetPublicKey",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.signing_key.arn
      }
    ]
  })
}
