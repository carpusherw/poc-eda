provider "aws" {
  region = "us-east-1"
}

module "eventbridge" {
  source = "terraform-aws-modules/eventbridge/aws"

  create_bus  = false
  bus_name    = "POC-AUTO-my-bus"
  create_role = false

  rules = {
    POC-AUTO-handler = {
      event_pattern = jsonencode({
        source      = ["com.gofreight.publisher"],
        detail-type = ["something-really-matters"],
      })
    }
  }
  targets = {
    POC-AUTO-handler = [{
      name = "POC-AUTO-my-handler-target"
      arn  = module.lambda.lambda_function_arn
    }]
  }
}

module "lambda" {
  source        = "terraform-aws-modules/lambda/aws"
  function_name = "POC-AUTO-my-handler"
  runtime       = "python3.12"
  handler       = "handler.handler"
  source_path   = "./src/handler.py"
  role_name     = "POC-AUTO-my-handler"

  create_current_version_allowed_triggers = false
  allowed_triggers = {
    POC-AUTO-my-bus = {
      principal  = "events.amazonaws.com"
      source_arn = module.eventbridge.eventbridge_rule_arns["POC-AUTO-handler"]
    }
  }
}
