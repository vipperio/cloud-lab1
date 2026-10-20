output "app_url" {
  value = "http://${aws_lb.main.dns_name}"
}

output "swagger_url" {
  value = "http://${aws_lb.main.dns_name}/docs"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "github_actions_role_arn" {
  description = "Це значення -> GitHub repo variable AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}
