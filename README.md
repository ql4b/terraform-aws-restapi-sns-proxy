# terraform-aws-rest-api-sns-proxy

> **API Gateway to SNS proxy with optional rate limiting and API key authentication**

Creates an API Gateway REST API that directly publishes incoming HTTP requests to an SNS topic, enabling serverless event ingestion with built-in throttling and authentication.

## Features

- **Direct SNS Integration**: API Gateway publishes directly to SNS without Lambda
- **Multi-stage Support**: Deploy to multiple stages (staging, prod, etc.)
- **Optional API Keys**: Conditional API key authentication
- **Rate Limiting**: Configurable throttling and quotas
- **CORS Support**: Built-in CORS headers for web clients
- **CloudPosse Integration**: Uses CloudPosse labeling and context

## Usage

### Basic Example

```hcl
module "sns_proxy" {
  source = "github.com/ql4b/terraform-aws-rest-api-sns-proxy"
  
  context = module.label.context
  
  sns = {
    topic_name = "my-events"
    topic_arn  = "arn:aws:sns:us-east-1:123456789:my-events"
  }
  
  stages = ["staging", "prod"]
}
```

### With API Keys and Rate Limiting

```hcl
module "sns_proxy" {
  source = "github.com/ql4b/terraform-aws-rest-api-sns-proxy"
  
  context = module.label.context
  
  sns = {
    topic_name = "analytics-events"
    topic_arn  = "arn:aws:sns:us-east-1:123456789:analytics-events"
  }
  
  stages = ["prod"]
  
  # Enable API key authentication
  create_usage_plan = true
  api_key_required  = true
  
  # Rate limiting
  throttle_rate_limit  = 100   # requests per second
  throttle_burst_limit = 200   # burst capacity
  quota_limit          = 10000 # requests per day
  quota_period         = "DAY"
}
```

### Analytics Pipeline Integration

```hcl
# SNS topic for events
resource "aws_sns_topic" "events" {
  name = "analytics-events"
}

# API Gateway proxy
module "event_ingestion" {
  source = "github.com/ql4b/terraform-aws-rest-api-sns-proxy"
  
  context = module.label.context
  attributes = ["ingestion"]
  
  sns = {
    topic_name = aws_sns_topic.events.name
    topic_arn  = aws_sns_topic.events.arn
  }
  
  create_usage_plan = true
  api_key_required  = true
  throttle_rate_limit = 1000
  quota_limit = 100000
}

# Grant API Gateway permission to publish
resource "aws_sns_topic_policy" "events" {
  arn = aws_sns_topic.events.arn
  
  policy = jsonencode({
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = module.event_ingestion.api_gateway_role_arn
      }
      Action = "sns:Publish"
      Resource = aws_sns_topic.events.arn
    }]
  })
}
```

## API Usage

### Endpoint

The module creates a `/capture` endpoint that accepts POST requests:

```
POST https://{api-id}.execute-api.{region}.amazonaws.com/{stage}/capture
```

### Request Example

```bash
curl -X POST https://abc123.execute-api.us-east-1.amazonaws.com/prod/capture \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d '{"event": "user_signup", "userId": "123", "timestamp": "2024-01-16T10:30:00Z"}'
```

### Response

```json
{
  "MessageId": "12345678-1234-1234-1234-123456789012"
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| sns | SNS topic configuration | `object({topic_name=string, topic_arn=string})` | n/a | yes |
| stages | List of API stages to create | `list(string)` | `["live"]` | no |
| endpoint_type | API Gateway endpoint type | `string` | `"REGIONAL"` | no |
| enable_metrics | Enable API Gateway metrics | `bool` | `true` | no |
| create_usage_plan | Whether to create usage plan and API key | `bool` | `false` | no |
| api_key_required | Whether to require an API key | `bool` | `false` | no |
| throttle_rate_limit | Throttle rate limit (requests per second) | `number` | `null` | no |
| throttle_burst_limit | Throttle burst limit | `number` | `null` | no |
| quota_limit | Quota limit (requests per period) | `number` | `null` | no |
| quota_period | Quota period (DAY, WEEK, MONTH) | `string` | `"DAY"` | no |

## Outputs

| Name | Description |
|------|-------------|
| api_gateway_role_arn | ARN of the API Gateway execution role |
| api_gateway_role_name | Name of the API Gateway execution role |
| api_endpoint | API Gateway endpoint URLs by stage |
| api_id | API Gateway REST API IDs by stage |
| api_key | API Gateway API key (if created) |
| usage_plan_id | Usage plan ID (if created) |

## Architecture

```
Client → API Gateway → SNS Topic → Subscribers
   ↓         ↓           ↓
API Key   /capture   Event Data
```

**Flow:**
1. Client sends POST request to `/capture` endpoint
2. API Gateway validates API key (if required)
3. Request is transformed and published to SNS topic
4. SNS delivers message to all subscribers
5. API Gateway returns SNS MessageId to client

## Use Cases

- **Event Ingestion**: Collect events from web/mobile clients
- **Analytics Pipelines**: Feed data into analytics systems
- **Webhook Endpoints**: Receive webhooks and fan out via SNS
- **Microservices Communication**: Decouple services via events
- **Real-time Data Collection**: Stream data to multiple consumers

## Permissions

The module creates an IAM role for API Gateway with permissions to publish to the specified SNS topic. You must grant this role permission to publish to your SNS topic:

```hcl
resource "aws_sns_topic_policy" "example" {
  arn = var.sns_topic_arn
  
  policy = jsonencode({
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = module.sns_proxy.api_gateway_role_arn
      }
      Action = "sns:Publish"
      Resource = var.sns_topic_arn
    }]
  })
}
```

## License

MIT License - see [LICENSE](LICENSE) file for details.