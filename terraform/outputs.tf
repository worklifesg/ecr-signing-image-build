output "image_repo_url" {
  value = aws_ecr_repository.image_repo.repository_url
}

output "signature_repo_url" {
  value = aws_ecr_repository.signature_repo.repository_url
}

output "kms_key_arn" {
  value = aws_kms_key.signing_key.arn
}

output "role_arn" {
  value = aws_iam_role.github_actions.arn
}
