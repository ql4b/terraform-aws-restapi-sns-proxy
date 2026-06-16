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
  source  = "ql4b/rest-api-sns-proxy/aws"
  version = "~> 1.0"
  
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
  source  = "ql4b/rest-api-sns-proxy/aws"
  version = "~> 1.0"
  
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
  source  = "ql4b/rest-api-sns-proxy/aws"
  version = "~> 1.0"
  
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

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_this"></a> [this](#module\_this) | cloudposse/label/null | 0.25.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_api_gateway_api_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_api_key) | resource |
| [aws_api_gateway_deployment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_deployment) | resource |
| [aws_api_gateway_integration.sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration) | resource |
| [aws_api_gateway_integration_response.post](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration_response) | resource |
| [aws_api_gateway_method.post](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method) | resource |
| [aws_api_gateway_method_response.post](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method_response) | resource |
| [aws_api_gateway_resource.capture](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_api_gateway_rest_api.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_rest_api) | resource |
| [aws_api_gateway_stage.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_stage) | resource |
| [aws_api_gateway_usage_plan.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_usage_plan) | resource |
| [aws_api_gateway_usage_plan_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_usage_plan_key) | resource |
| [aws_iam_role.api_gateway_sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_additional_tag_map"></a> [additional\_tag\_map](#input\_additional\_tag\_map) | Additional key-value pairs to add to each map in `tags_as_list_of_maps`. Not added to `tags` or `id`.<br/>This is for some rare cases where resources want additional configuration of tags<br/>and therefore take a list of maps with tag key, value, and additional configuration. | `map(string)` | `{}` | no |
| <a name="input_api_key_required"></a> [api\_key\_required](#input\_api\_key\_required) | Whether to require an API key for the API Gateway | `bool` | `false` | no |
| <a name="input_attributes"></a> [attributes](#input\_attributes) | ID element. Additional attributes (e.g. `workers` or `cluster`) to add to `id`,<br/>in the order they appear in the list. New attributes are appended to the<br/>end of the list. The elements of the list are joined by the `delimiter`<br/>and treated as a single ID element. | `list(string)` | `[]` | no |
| <a name="input_context"></a> [context](#input\_context) | Single object for setting entire context at once.<br/>See description of individual variables for details.<br/>Leave string and numeric variables as `null` to use default value.<br/>Individual variable settings (non-null) override settings in context object,<br/>except for attributes, tags, and additional\_tag\_map, which are merged. | `any` | <pre>{<br/>  "additional_tag_map": {},<br/>  "attributes": [],<br/>  "delimiter": null,<br/>  "descriptor_formats": {},<br/>  "enabled": true,<br/>  "environment": null,<br/>  "id_length_limit": null,<br/>  "label_key_case": null,<br/>  "label_order": [],<br/>  "label_value_case": null,<br/>  "labels_as_tags": [<br/>    "unset"<br/>  ],<br/>  "name": null,<br/>  "namespace": null,<br/>  "regex_replace_chars": null,<br/>  "stage": null,<br/>  "tags": {},<br/>  "tenant": null<br/>}</pre> | no |
| <a name="input_create_usage_plan"></a> [create\_usage\_plan](#input\_create\_usage\_plan) | Whether to create usage plan and API key | `bool` | `false` | no |
| <a name="input_delimiter"></a> [delimiter](#input\_delimiter) | Delimiter to be used between ID elements.<br/>Defaults to `-` (hyphen). Set to `""` to use no delimiter at all. | `string` | `null` | no |
| <a name="input_descriptor_formats"></a> [descriptor\_formats](#input\_descriptor\_formats) | Describe additional descriptors to be output in the `descriptors` output map.<br/>Map of maps. Keys are names of descriptors. Values are maps of the form<br/>`{<br/>   format = string<br/>   labels = list(string)<br/>}`<br/>(Type is `any` so the map values can later be enhanced to provide additional options.)<br/>`format` is a Terraform format string to be passed to the `format()` function.<br/>`labels` is a list of labels, in order, to pass to `format()` function.<br/>Label values will be normalized before being passed to `format()` so they will be<br/>identical to how they appear in `id`.<br/>Default is `{}` (`descriptors` output will be empty). | `any` | `{}` | no |
| <a name="input_enable_metrics"></a> [enable\_metrics](#input\_enable\_metrics) | Enable API Gateway metrics | `bool` | `true` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Set to false to prevent the module from creating any resources | `bool` | `null` | no |
| <a name="input_endpoint_type"></a> [endpoint\_type](#input\_endpoint\_type) | API Gateway endpoint type (e.g., 'REGIONAL', 'EDGE', 'PRIVATE') | `string` | `"REGIONAL"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | ID element. Usually used for region e.g. 'uw2', 'us-west-2', OR role 'prod', 'staging', 'dev', 'UAT' | `string` | `null` | no |
| <a name="input_id_length_limit"></a> [id\_length\_limit](#input\_id\_length\_limit) | Limit `id` to this many characters (minimum 6).<br/>Set to `0` for unlimited length.<br/>Set to `null` for keep the existing setting, which defaults to `0`.<br/>Does not affect `id_full`. | `number` | `null` | no |
| <a name="input_label_key_case"></a> [label\_key\_case](#input\_label\_key\_case) | Controls the letter case of the `tags` keys (label names) for tags generated by this module.<br/>Does not affect keys of tags passed in via the `tags` input.<br/>Possible values: `lower`, `title`, `upper`.<br/>Default value: `title`. | `string` | `null` | no |
| <a name="input_label_order"></a> [label\_order](#input\_label\_order) | The order in which the labels (ID elements) appear in the `id`.<br/>Defaults to ["namespace", "environment", "stage", "name", "attributes"].<br/>You can omit any of the 6 labels ("tenant" is the 6th), but at least one must be present. | `list(string)` | `null` | no |
| <a name="input_label_value_case"></a> [label\_value\_case](#input\_label\_value\_case) | Controls the letter case of ID elements (labels) as included in `id`,<br/>set as tag values, and output by this module individually.<br/>Does not affect values of tags passed in via the `tags` input.<br/>Possible values: `lower`, `title`, `upper` and `none` (no transformation).<br/>Set this to `title` and set `delimiter` to `""` to yield Pascal Case IDs.<br/>Default value: `lower`. | `string` | `null` | no |
| <a name="input_labels_as_tags"></a> [labels\_as\_tags](#input\_labels\_as\_tags) | Set of labels (ID elements) to include as tags in the `tags` output.<br/>Default is to include all labels.<br/>Tags with empty values will not be included in the `tags` output.<br/>Set to `[]` to suppress all generated tags.<br/>**Notes:**<br/>  The value of the `name` tag, if included, will be the `id`, not the `name`.<br/>  Unlike other `null-label` inputs, the initial setting of `labels_as_tags` cannot be<br/>  changed in later chained modules. Attempts to change it will be silently ignored. | `set(string)` | <pre>[<br/>  "default"<br/>]</pre> | no |
| <a name="input_name"></a> [name](#input\_name) | ID element. Usually the component or solution name, e.g. 'app' or 'jenkins'.<br/>This is the only ID element not also included as a `tag`.<br/>The "name" tag is set to the full `id` string. There is no tag with the value of the `name` input. | `string` | `null` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | ID element. Usually an abbreviation of your organization name, e.g. 'eg' or 'cp', to help ensure generated IDs are globally unique | `string` | `null` | no |
| <a name="input_quota_limit"></a> [quota\_limit](#input\_quota\_limit) | API Gateway usage plan quota limit (requests per period) | `number` | `null` | no |
| <a name="input_quota_period"></a> [quota\_period](#input\_quota\_period) | API Gateway usage plan quota period (DAY, WEEK, MONTH) | `string` | `"DAY"` | no |
| <a name="input_regex_replace_chars"></a> [regex\_replace\_chars](#input\_regex\_replace\_chars) | Terraform regular expression (regex) string.<br/>Characters matching the regex will be removed from the ID elements.<br/>If not set, `"/[^a-zA-Z0-9-]/"` is used to remove all characters other than hyphens, letters and digits. | `string` | `null` | no |
| <a name="input_sns"></a> [sns](#input\_sns) | n/a | <pre>object({<br/>      topic_name = string<br/>      topic_arn = string<br/>    })</pre> | n/a | yes |
| <a name="input_stage"></a> [stage](#input\_stage) | ID element. Usually used to indicate role, e.g. 'prod', 'staging', 'source', 'build', 'test', 'deploy', 'release' | `string` | `null` | no |
| <a name="input_stages"></a> [stages](#input\_stages) | List of API stages to create | `list(string)` | <pre>[<br/>  "live"<br/>]</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags (e.g. `{'BusinessUnit': 'XYZ'}`).<br/>Neither the tag keys nor the tag values will be modified by this module. | `map(string)` | `{}` | no |
| <a name="input_tenant"></a> [tenant](#input\_tenant) | ID element \_(Rarely used, not included by default)\_. A customer identifier, indicating who this instance of a resource is for | `string` | `null` | no |
| <a name="input_throttle_burst_limit"></a> [throttle\_burst\_limit](#input\_throttle\_burst\_limit) | API Gateway usage plan throttle burst limit | `number` | `null` | no |
| <a name="input_throttle_rate_limit"></a> [throttle\_rate\_limit](#input\_throttle\_rate\_limit) | API Gateway usage plan throttle rate limit (requests per second) | `number` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_api_endpoint"></a> [api\_endpoint](#output\_api\_endpoint) | API Gateway endpoint URLs by stage |
| <a name="output_api_gateway_role_arn"></a> [api\_gateway\_role\_arn](#output\_api\_gateway\_role\_arn) | ARN of the API Gateway execution role for external policy attachment |
| <a name="output_api_gateway_role_name"></a> [api\_gateway\_role\_name](#output\_api\_gateway\_role\_name) | Name of the API Gateway execution role |
| <a name="output_api_id"></a> [api\_id](#output\_api\_id) | API Gateway REST API IDs by stage |
| <a name="output_api_key"></a> [api\_key](#output\_api\_key) | API Gateway API key (if created) |
| <a name="output_capture_invoke_urls"></a> [capture\_invoke\_urls](#output\_capture\_invoke\_urls) | Invoke URL for the /capture resource per stage |
| <a name="output_usage_plan_id"></a> [usage\_plan\_id](#output\_usage\_plan\_id) | Usage plan ID (if created) |
<!-- END_TF_DOCS -->

## License

MIT License - see [LICENSE](LICENSE) file for details.