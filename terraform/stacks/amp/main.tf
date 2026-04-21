data "aws_caller_identity" "current" {}

locals {
  common_tags = merge(
    var.tags,
    {
      Name = var.workspace_alias
    }
  )

  sns_subscriptions = var.alert_email == null ? {} : {
    email = {
      protocol = "email"
      endpoint = var.alert_email
    }
  }

  alert_manager_yaml = <<-EOT
alertmanager_config: |
  route:
    group_by: ['alertname', 'severity']
    receiver: 'sns_warning'
    routes:
      - receiver: 'sns_critical'
        matchers:
          - severity="critical"
      - receiver: 'sns_warning'
        matchers:
          - severity="warning"
  receivers:
    - name: 'sns_critical'
      sns_configs:
        - sigv4:
            region: ${var.aws_region}
          topic_arn: ${module.sns.topic_arn}
          subject: '${replace(var.alert_subject, "'", "''")} [critical]'
    - name: 'sns_warning'
      sns_configs:
        - sigv4:
            region: ${var.aws_region}
          topic_arn: ${module.sns.topic_arn}
          subject: '${replace(var.alert_subject, "'", "''")} [warning]'
EOT

  alert_manager_definition = var.create_alert_manager ? local.alert_manager_yaml : null
}

module "sns" {
  source  = "terraform-aws-modules/sns/aws"
  version = "~> 7.1"

  name = var.sns_topic_name

  create_subscription  = length(local.sns_subscriptions) > 0
  subscriptions        = local.sns_subscriptions
  create_topic_policy  = true
  enable_default_topic_policy = true

  topic_policy_statements = {
    amazon_managed_prometheus = {
      sid = "AllowAmazonManagedPrometheusPublish"
      actions = [
        "sns:Publish",
        "sns:GetTopicAttributes",
      ]
      principals = [{
        type        = "Service"
        identifiers = ["aps.amazonaws.com"]
      }]
    }
  }

  tags = local.common_tags
}

module "prometheus" {
  source  = "terraform-aws-modules/managed-service-prometheus/aws"
  version = "~> 4.3"

  workspace_alias = var.workspace_alias

  retention_period_in_days = var.retention_period_in_days

  create_alert_manager     = var.create_alert_manager
  alert_manager_definition = coalesce(local.alert_manager_definition, "")

  tags = local.common_tags

  depends_on = [module.sns]
}
