output "role_arn" {
  description = "ServiceAccount 애너테이션(eks.amazonaws.com/role-arn)에 사용"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  value = aws_iam_role.this.name
}
