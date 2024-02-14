# sns_module_variables_test.tftest.hcl

variables {
  region                      = "eu-west-1"
  topic_name                  = "sns-example"
  fifo_topic                  = false
  content_based_deduplication = true
  display_name                = "name"
  signature_version           = "2"
  tracing_config              = "Active"

  tags = {
    "Project" = "terraform-aws-sns"
  }

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

  enable_data_protection_policy = true
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
}

provider "aws" {
  region = var.region
}

run "verify_sns_topic_configuration" {
  command = plan

  assert {
    condition     = var.topic_name != null
    error_message = "Topic name should be set."
  }

  assert {
    condition     = contains(keys(var.tags), "Project") && var.tags["Project"] == "terraform-aws-sns"
    error_message = "The 'Project' tag with the value 'terraform-aws-sns' must be present."
  }

  assert {
    condition     = var.subscriptions != null
    error_message = "Add at least one subscription."
  }

  assert {
    condition     = var.fifo_topic == false || var.fifo_topic == true
    error_message = "FIFO topic configuration does not match expected value."
  }

  assert {
    condition     = var.fifo_topic == false || (var.fifo_topic == true && var.content_based_deduplication == true)
    error_message = "When FIFO topic is enabled, content-based deduplication must also be enabled."
  }

  assert {
    condition     = (var.enable_data_protection_policy && var.data_protection_policy != null && !var.fifo_topic) || (!var.enable_data_protection_policy && var.fifo_topic)
    error_message = "Data protection policy should be applied only when enabled, not null, and FIFO topic is false."
  }

  assert {
    condition     = var.tracing_config != "Active" || (var.tracing_config == "Active" && !var.fifo_topic)
    error_message = "TracingConfig set to Active is only supported on standard topics (fifo_topic must be false)."
  }

  assert {
    condition     = var.tracing_config == "Active" || var.tracing_config == "PassThrough"
    error_message = "TracingConfig must be set to either 'Active' or 'PassThrough'."
  }

}
