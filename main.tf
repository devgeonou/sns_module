data "aws_caller_identity" "current" {}

################################################################################
# Topic
################################################################################

resource "aws_sns_topic" "this" {
  name                        = var.fifo_topic ? "${var.topic_name}.fifo" : var.topic_name
  content_based_deduplication = var.fifo_topic ? var.content_based_deduplication : null
  delivery_policy             = var.delivery_policy
  display_name                = var.display_name
  fifo_topic                  = var.fifo_topic
  signature_version           = var.signature_version
  tracing_config              = var.tracing_config
  tags                        = var.tags

  ################################################################################
  # Archive
  ################################################################################

  archive_policy = var.enable_archive_policy ? try(var.archive_policy, null) : null

  ################################################################################
  # Encryption
  ################################################################################

  kms_master_key_id = var.enable_encryption ? try(var.kms_master_key_id, null) : null

  ################################################################################
  # Feedback
  ################################################################################

  application_failure_feedback_role_arn    = var.enable_feedback ? try(var.application_feedback.failure_role_arn, null) : null
  application_success_feedback_role_arn    = var.enable_feedback ? try(var.application_feedback.success_role_arn, null) : null
  application_success_feedback_sample_rate = var.enable_feedback ? try(var.application_feedback.success_sample_rate, null) : null

  firehose_failure_feedback_role_arn    = var.enable_feedback ? try(var.firehose_feedback.failure_role_arn, null) : null
  firehose_success_feedback_role_arn    = var.enable_feedback ? try(var.firehose_feedback.success_role_arn, null) : null
  firehose_success_feedback_sample_rate = var.enable_feedback ? try(var.firehose_feedback.success_sample_rate, null) : null

  http_failure_feedback_role_arn    = var.enable_feedback ? try(var.http_feedback.failure_role_arn, null) : null
  http_success_feedback_role_arn    = var.enable_feedback ? try(var.http_feedback.success_role_arn, null) : null
  http_success_feedback_sample_rate = var.enable_feedback ? try(var.http_feedback.success_sample_rate, null) : null

  lambda_failure_feedback_role_arn    = var.enable_feedback ? try(var.lambda_feedback.failure_role_arn, null) : null
  lambda_success_feedback_role_arn    = var.enable_feedback ? try(var.lambda_feedback.success_role_arn, null) : null
  lambda_success_feedback_sample_rate = var.enable_feedback ? try(var.lambda_feedback.success_sample_rate, null) : null

  sqs_failure_feedback_role_arn    = var.enable_feedback ? try(var.sqs_feedback.failure_role_arn, null) : null
  sqs_success_feedback_role_arn    = var.enable_feedback ? try(var.sqs_feedback.success_role_arn, null) : null
  sqs_success_feedback_sample_rate = var.enable_feedback ? try(var.sqs_feedback.success_sample_rate, null) : null
}

################################################################################
# Topic Policy
################################################################################


resource "random_id" "default_statement_id" {
  byte_length = 8 # Adjust the length as needed
}

data "aws_iam_policy_document" "this" {

  source_policy_documents   = var.source_topic_policy_documents
  override_policy_documents = var.override_topic_policy_documents

  dynamic "statement" {
    for_each = var.enable_default_topic_policy ? [1] : []

    content {
      sid = "SID-${random_id.default_statement_id.hex}"
      actions = [
        "sns:Subscribe",
        "sns:SetTopicAttributes",
        "sns:RemovePermission",
        "sns:Publish",
        "sns:ListSubscriptionsByTopic",
        "sns:GetTopicAttributes",
        "sns:DeleteTopic",
        "sns:AddPermission",
      ]
      effect    = "Allow"
      resources = [aws_sns_topic.this.arn]

      principals {
        type        = "AWS"
        identifiers = ["*"]
      }

      condition {
        test     = "StringEquals"
        values   = [data.aws_caller_identity.current.account_id]
        variable = "AWS:SourceOwner"
      }
    }
  }

  dynamic "statement" {
    for_each = var.topic_policy_statements

    content {
      sid           = try(statement.value.sid, statement.key)
      actions       = try(statement.value.actions, null)
      not_actions   = try(statement.value.not_actions, null)
      effect        = try(statement.value.effect, null)
      resources     = try(statement.value.resources, [aws_sns_topic.this.arn])
      not_resources = try(statement.value.not_resources, null)

      dynamic "principals" {
        for_each = try(statement.value.principals, [])

        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }

      dynamic "not_principals" {
        for_each = try(statement.value.not_principals, [])

        content {
          type        = not_principals.value.type
          identifiers = not_principals.value.identifiers
        }
      }

      dynamic "condition" {
        for_each = try(statement.value.conditions, [])

        content {
          test     = condition.value.test
          values   = condition.value.values
          variable = condition.value.variable
        }
      }
    }
  }
}

resource "aws_sns_topic_policy" "this" {
  arn    = aws_sns_topic.this.arn
  policy = data.aws_iam_policy_document.this.json
}

################################################################################
# Subscription(s)
################################################################################

resource "aws_sns_topic_subscription" "this" {
  for_each = { for k, v in var.subscriptions : k => v }

  confirmation_timeout_in_minutes = try(each.value.confirmation_timeout_in_minutes, null)
  delivery_policy                 = try(each.value.delivery_policy, null)
  endpoint                        = each.value.endpoint
  endpoint_auto_confirms          = try(each.value.endpoint_auto_confirms, null)
  filter_policy                   = try(each.value.filter_policy, null)
  filter_policy_scope             = try(each.value.filter_policy_scope, null)
  protocol                        = each.value.protocol
  raw_message_delivery            = try(each.value.raw_message_delivery, null)
  redrive_policy                  = try(each.value.redrive_policy, null)
  replay_policy                   = try(each.value.replay_policy, null)
  subscription_role_arn           = try(each.value.subscription_role_arn, null)
  topic_arn                       = aws_sns_topic.this.arn
}

################################################################################
# Data Protection Policy
################################################################################

resource "aws_sns_topic_data_protection_policy" "this" {
  count = var.enable_data_protection_policy && var.data_protection_policy != null && !var.fifo_topic ? 1 : 0

  arn    = aws_sns_topic.this.arn
  policy = var.data_protection_policy
}
