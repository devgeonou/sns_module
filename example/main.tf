provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}

locals {
  region     = "eu-west-1"
  topic_name = "sns-example"

  enable_feedback               = false
  enable_encryption             = false
  enable_archive_policy         = false
  enable_default_topic_policy   = false
  enable_data_protection_policy = false

  tags = {
    "Project"            = "terraform-aws-sns"
    "Exposure"           = "internal"
    "KubernetesCluster"  = ""
    "map-dba"            = ""
    "map-win-modernized" = ""
    "map-migrated"       = ""
    "ShieldProtect"      = "true"
    "Env"                = "dev"
    "SubProject"         = ""
    "SourceRepo"         = "https://gitlab.sportradar.ag/terraform/terraform-aws-sns.git"
    "SourcePath"         = ""
    "ManagedBy"          = "infra"
    "SupportedBy"        = ""
  }

}

module "default_sns" {

  source = "../"

  # General Settings

  topic_name                  = local.topic_name
  fifo_topic                  = false
  content_based_deduplication = true
  display_name                = "name"
  signature_version           = "2"
  tracing_config              = "Active"
  tags                        = local.tags
  delivery_policy = jsonencode({
    "http" : {
      "defaultHealthyRetryPolicy" : {
        "minDelayTarget" : 20,
        "maxDelayTarget" : 20,
        "numRetries" : 3,
        "numMaxDelayRetries" : 0,
        "numNoDelayRetries" : 0,
        "numMinDelayRetries" : 0,
        "backoffFunction" : "linear"
      },
      "disableSubscriptionOverrides" : false,
      "defaultThrottlePolicy" : {
        "maxReceivesPerSecond" : 1
      }
    }
  })

  # Archive

  enable_archive_policy = local.enable_archive_policy

  archive_policy = jsonencode({
    "MessageRetentionPeriod" : 30
  })

  # Encryption

  enable_encryption = local.enable_encryption
  kms_master_key_id = local.enable_encryption && length(aws_kms_key.this) > 0 ? aws_kms_key.this[0].id : null

  # Topic Policy

  enable_default_topic_policy = local.enable_default_topic_policy

  topic_policy_statements = {
    pub = {
      actions = ["sns:Publish"]
      principals = [{
        type        = "AWS"
        identifiers = [data.aws_caller_identity.current.arn]
      }]
    },

    sub = {
      actions = [
        "sns:Subscribe",
        "sns:Receive",
      ]

      principals = [{
        type        = "AWS"
        identifiers = ["*"]
      }]

      conditions = [{
        test     = "StringLike"
        variable = "sns:Endpoint"
        values   = ["arn:aws:sqs:eu-west-1:126391801411:joel-test2"]
      }]
    }
  }

  # Subscription(s)

  subscriptions = {
    "sqs_subscription" = {
      endpoint : "arn:aws:sqs:eu-west-1:126391801411:-example",
      protocol : "sqs",
      create : true,
      confirmation_timeout_in_minutes : 1,
      delivery_policy : null,
      endpoint_auto_confirms : null,
      filter_policy : null,
      filter_policy_scope : null,
      raw_message_delivery : null,
      redrive_policy : null,
      replay_policy : null,
    }
  }

  # Data Protection Policy Configuration

  enable_data_protection_policy = local.enable_data_protection_policy

  data_protection_policy = jsonencode(

    {
      Description = "Deny Inbound Address"
      Name        = "DenyInboundEmailAdressPolicy"
      Statement = [
        {
          "DataDirection" = "Inbound"
          "DataIdentifier" = [
            "arn:aws:dataprotection::aws:data-identifier/EmailAddress",
          ]
          "Operation" = {
            "Deny" = {}
          }
          "Principal" = [
            "*",
          ]
          "Sid" = "DenyInboundEmailAddress"
        },
      ]
      Version = "2021-06-01"
    }
  )

  # Feedback

  enable_feedback = local.enable_feedback

  application_feedback = local.enable_feedback ? {
    failure_role_arn    = aws_iam_role.this[0].arn
    success_role_arn    = aws_iam_role.this[0].arn
    success_sample_rate = 100
  } : null

  firehose_feedback = local.enable_feedback ? {
    failure_role_arn    = aws_iam_role.this[0].arn
    success_role_arn    = aws_iam_role.this[0].arn
    success_sample_rate = 100
  } : null

  http_feedback = local.enable_feedback ? {
    failure_role_arn    = aws_iam_role.this[0].arn
    success_role_arn    = aws_iam_role.this[0].arn
    success_sample_rate = 100
  } : null

  lambda_feedback = local.enable_feedback ? {
    failure_role_arn    = aws_iam_role.this[0].arn
    success_role_arn    = aws_iam_role.this[0].arn
    success_sample_rate = 100
  } : null

  sqs_feedback = local.enable_feedback ? {
    failure_role_arn    = aws_iam_role.this[0].arn
    success_role_arn    = aws_iam_role.this[0].arn
    success_sample_rate = 100
  } : null


}

################################################################################
# Supporting Resources
################################################################################

resource "aws_kms_key" "this" {
  count       = local.enable_encryption ? 1 : 0
  description = "KMS key to encrypt topic"
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Sid : "Enable IAM User Permissions",
        Effect : "Allow",
        Principal : {
          AWS : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action : "kms:*",
        Resource : "*"
      },
      {
        Sid : "Allow management of the key",
        Effect : "Allow",
        Principal : {
          AWS : [
            data.aws_caller_identity.current.arn,
          ]
        },
        Action : [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ],
        Resource : "*"
      }
    ]
  })
  tags = local.tags
}

resource "aws_kms_alias" "this" {
  count         = local.enable_encryption ? 1 : 0
  name          = format("alias/%s", "sns/${local.topic_name}")
  target_key_id = aws_kms_key.this[0].id
}

resource "aws_iam_role" "this" {
  count = local.enable_feedback ? 1 : 0
  name  = local.topic_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "SnsAssume"
        Principal = {
          Service = "sns.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = local.topic_name

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:PutMetricFilter",
            "logs:PutRetentionPolicy",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }

  tags = local.tags
}
