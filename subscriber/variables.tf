variable "broker_arn" {
  description = "The ARN of the Amazon MQ RabbitMQ broker"
  type        = string
}

variable "broker_endpoint" {
  description = "The endpoint of the Amazon MQ RabbitMQ broker"
  type        = string
}

variable "broker_password" {
  description = "hardcore"
  type        = string
  sensitive   = true
}
