locals {
  id                    = module.this.id
  context               = module.this.context
  sns_topic_arn         = var.sns.topic_arn
  
  endpoint_type         = var.endpoint_type
  enable_metrics        = var.enable_metrics
  create_usage_plan     = var.create_usage_plan
  api_key_required      = var.api_key_required

  throttle_rate_limit   = var.throttle_rate_limit
  throttle_burst_limit  = var.throttle_burst_limit
  quota_limit           = var.quota_limit
  quota_period          = var.quota_period

  stages                = var.stages
  

}

# IAM role for API Gateway to publish to SNS
resource "aws_iam_role" "api_gateway_sns" {
  name = "${local.id}-api-gateway-sns"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })
}

# SNS publish permissions must be granted separately via SNS topic policy
# See README.md for example policy configuration

# API Gateway
resource "aws_api_gateway_rest_api" "this" {
  for_each = toset(local.stages)
  name     = "${local.id}-${each.key}"
}

resource "aws_api_gateway_resource" "capture" {
  for_each    = toset(local.stages)
  rest_api_id = aws_api_gateway_rest_api.this[each.key].id
  parent_id   = aws_api_gateway_rest_api.this[each.key].root_resource_id
  path_part   = "capture"
}

resource "aws_api_gateway_method" "post" {
  for_each         = toset(local.stages)
  rest_api_id      = aws_api_gateway_rest_api.this[each.key].id
  resource_id      = aws_api_gateway_resource.capture[each.key].id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = local.api_key_required
}

resource "aws_api_gateway_integration" "sns" {
  for_each    = toset(local.stages)
  rest_api_id = aws_api_gateway_rest_api.this[each.key].id
  resource_id = aws_api_gateway_resource.capture[each.key].id
  http_method = aws_api_gateway_method.post[each.key].http_method
  
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:sns:action/Publish"
  credentials             = aws_iam_role.api_gateway_sns.arn
  passthrough_behavior    = "NEVER"
  
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }
  
  request_templates = {
    "application/json" = "Action=Publish&TopicArn=${local.sns_topic_arn}&Message=$util.urlEncode($input.body)"
  }

}

resource "aws_api_gateway_method_response" "post" {
  for_each    = toset(local.stages)
  rest_api_id = aws_api_gateway_rest_api.this[each.key].id
  resource_id = aws_api_gateway_resource.capture[each.key].id
  http_method = aws_api_gateway_method.post[each.key].http_method
  status_code = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_integration_response" "post" {
  for_each    = toset(local.stages)
  rest_api_id = aws_api_gateway_rest_api.this[each.key].id
  resource_id = aws_api_gateway_resource.capture[each.key].id
  http_method = aws_api_gateway_method.post[each.key].http_method
  status_code = aws_api_gateway_method_response.post[each.key].status_code
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

# Deployments
resource "aws_api_gateway_deployment" "this" {
  for_each = toset(local.stages)
  
  rest_api_id = aws_api_gateway_rest_api.this[each.key].id
  depends_on = [aws_api_gateway_integration.sns]

  lifecycle {
    create_before_destroy = true
  }

  triggers = {
     redeployment = sha1(jsonencode([
      aws_api_gateway_method.post[each.key].id,
      aws_api_gateway_integration.sns[each.key].id,
      aws_api_gateway_integration.sns[each.key].request_templates,
    ]))
  }
}

# Stages
resource "aws_api_gateway_stage" "this" {
  for_each = toset(local.stages)
  
  deployment_id = aws_api_gateway_deployment.this[each.key].id
  rest_api_id   = aws_api_gateway_rest_api.this[each.key].id
  stage_name    = each.value
}

# Usage Plan (conditional)
resource "aws_api_gateway_usage_plan" "this" {
  count = local.create_usage_plan ? 1 : 0
  
  name = "${local.id}-usage-plan"
  
  dynamic "api_stages" {
    for_each = local.stages
    content {
      api_id = aws_api_gateway_rest_api.this[api_stages.value].id
      stage  = api_stages.value
    }
  }
  
  dynamic "throttle_settings" {
    for_each = local.throttle_rate_limit != null ? [1] : []
    content {
      rate_limit  = local.throttle_rate_limit
      burst_limit = local.throttle_burst_limit
    }
  }
  
  dynamic "quota_settings" {
    for_each = local.quota_limit != null ? [1] : []
    content {
      limit  = local.quota_limit
      period = local.quota_period
    }
  }
}

# API Key (conditional)
resource "aws_api_gateway_api_key" "this" {
  count = local.create_usage_plan ? 1 : 0
  
  name = "${local.id}-api-key"
}

# Link API Key to Usage Plan
resource "aws_api_gateway_usage_plan_key" "this" {
  count = local.create_usage_plan ? 1 : 0
  
  key_id        = aws_api_gateway_api_key.this[0].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.this[0].id
}

data "aws_region" "current" {}
