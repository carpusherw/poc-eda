provider "aws" {
  region = "us-east-1"
}

module "eventbridge" {
  source = "terraform-aws-modules/eventbridge/aws"

  bus_name    = "POC-AUTO-my-bus"
  create_role = false
}

resource "aws_mq_broker" "POC-AUTO-my-broker" {
  broker_name        = "POC-AUTO-my-broker"
  engine_type        = "RabbitMQ"
  engine_version     = "3.11.20"
  host_instance_type = "mq.t3.micro"
  user {
    username = "hardcore"
    password = var.broker_password
  }

  publicly_accessible = true
}
