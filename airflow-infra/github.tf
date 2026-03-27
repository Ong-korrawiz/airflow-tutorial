resource "github_actions_secret" "aws_key_id" {
  repository      = var.repo_name
  secret_name     = "AWS_ACCESS_KEY_ID"
  plaintext_value = aws_iam_access_key.github_actions.id
}

resource "github_actions_secret" "aws_secret" {
  repository      = var.repo_name
  secret_name     = "AWS_SECRET_ACCESS_KEY"
  plaintext_value = aws_iam_access_key.github_actions.secret
}

resource "github_actions_secret" "aws_region" {
  repository      = var.repo_name
  secret_name     = "AWS_REGION"
  plaintext_value = var.aws_region
}

resource "github_actions_secret" "ecr_repo" {
  repository      = var.repo_name
  secret_name     = "ECR_REPOSITORY"
  plaintext_value = aws_ecr_repository.app_repo.name
}