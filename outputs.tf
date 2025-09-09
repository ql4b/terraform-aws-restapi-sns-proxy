output "api_gateway_role_arn" {
  description = "ARN of the API Gateway execution role for external policy attachment"
  value       = aws_iam_role.api_gateway_sns.arn
}

output "api_gateway_role_name" {
  description = "Name of the API Gateway execution role"
  value       = aws_iam_role.api_gateway_sns.name
}

output "api_endpoint" {
  description = "API Gateway endpoint URLs by stage"
  value       = {
    for stage in local.stages :
    stage => "https://${aws_api_gateway_rest_api.this[stage].id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${stage}"
  }
}

output "api_id" {
  description = "API Gateway REST API IDs by stage"
  value       = {
    for stage in local.stages :
    stage => aws_api_gateway_rest_api.this[stage].id
  }
}

output "api_key" {
  description = "API Gateway API key (if created)"
  value       = local.create_usage_plan ? aws_api_gateway_api_key.this[0].value : null
  sensitive   = true
}

output "usage_plan_id" {
  description = "Usage plan ID (if created)"
  value       = local.create_usage_plan ? aws_api_gateway_usage_plan.this[0].id : null
}