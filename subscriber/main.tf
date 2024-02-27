terraform {
  required_providers {
    rabbitmq = {
      source  = "cyrilgdn/rabbitmq"
      version = "1.8.0"
    }
  }
}

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
        detail = {
          action = ["created"],
        },
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
    mq = {
      principal  = "mq.amazonaws.com"
      source_arn = "arn:aws:mq:us-east-1:478041131377:broker:POC-AUTO-my-broker:b-0fdaad4f-1ca3-4a80-b189-ee129dc18388"
    }
  }

  event_source_mapping = {
    mq = {
      event_source_arn = "arn:aws:mq:us-east-1:478041131377:broker:POC-AUTO-my-broker:b-0fdaad4f-1ca3-4a80-b189-ee129dc18388"
      queues           = [rabbitmq_queue.something-really-matters-queue.name]
      batch_size       = 1
      source_access_configuration = [
        {
          type = "BASIC_AUTH"
          uri  = aws_secretsmanager_secret.this.arn
        },
        {
          type = "VIRTUAL_HOST"
          uri  = "/"
        }
      ]
    }
  }

  attach_policy_statements = true
  policy_statements = {
    # Execution role permissions to read records from an Amazon MQ broker
    # https://docs.aws.amazon.com/lambda/latest/dg/with-mq.html#events-mq-permissions
    mq_event_source = {
      effect    = "Allow",
      actions   = ["ec2:DescribeSubnets", "ec2:DescribeSecurityGroups", "ec2:DescribeVpcs"],
      resources = ["*"]
    },
    mq_describe_broker = {
      effect    = "Allow",
      actions   = ["mq:DescribeBroker"],
      resources = ["arn:aws:mq:us-east-1:478041131377:broker:POC-AUTO-my-broker:b-0fdaad4f-1ca3-4a80-b189-ee129dc18388"]
    },
    secrets_manager_get_value = {
      effect    = "Allow",
      actions   = ["secretsmanager:GetSecretValue"],
      resources = [aws_secretsmanager_secret.this.arn]
    }
  }
}

resource "aws_secretsmanager_secret" "this" {
  name = "POC-AUTO-my-broker-creds"
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id = aws_secretsmanager_secret.this.id
  secret_string = jsonencode({
    username = "hardcore",
    password = var.broker_password
  })
}

provider "rabbitmq" {
  endpoint = "https://b-0fdaad4f-1ca3-4a80-b189-ee129dc18388.mq.us-east-1.amazonaws.com"
  username = "hardcore"
  password = var.broker_password
}

resource "rabbitmq_queue" "something-really-matters-queue" {
  name  = "something-really-matters-queue"
  vhost = "/"
  settings {
    durable     = true
    auto_delete = false
  }
}

resource "rabbitmq_binding" "something-really-matters-queue-binding" {
  source           = "my-exchange"
  vhost            = "/"
  destination_type = "queue"
  destination      = rabbitmq_queue.something-really-matters-queue.name
  routing_key      = "com.gofreight.publisher:something-really-matters:created"
}
