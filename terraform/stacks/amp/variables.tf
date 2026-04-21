variable "aws_region" {
  description = "AWS region for this stack"
  type        = string
  default     = "us-east-1"
}

variable "workspace_alias" {
  description = "Friendly alias for the Amazon Managed Service for Prometheus workspace"
  type        = string
  default     = "midnight-test-amp"
}

variable "sns_topic_name" {
  description = "Name of the SNS topic used for AMP Alertmanager notifications"
  type        = string
  default     = "midnight-test-amp-alerts"
}

variable "alert_email" {
  description = "Optional email address to subscribe to the alerts topic (confirm the subscription in your inbox)"
  type        = string
  default     = null
}

variable "retention_period_in_days" {
  description = "AMP workspace metric retention in days"
  type        = number
  default     = 35
}

variable "create_alert_manager" {
  description = "Whether to create the AMP Alertmanager definition (routes alerts to SNS)"
  type        = bool
  default     = true
}

variable "alert_subject" {
  description = "Subject line for SNS messages sent by AMP Alertmanager"
  type        = string
  default     = "AMP alert"
}

variable "tags" {
  description = "Common tags applied to resources"
  type        = map(string)
  default = {
    Terraform = "true"
    Stack     = "amp"
  }
}
