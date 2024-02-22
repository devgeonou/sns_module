variables {
  region      = "eu-west-1"
  topic_name  = "sns-example-standard"
  fifo_topic  = false
  tracing_config = null
  content_based_deduplication = false
  topic_policy_statements = {}
  kms_master_key_id           = ""

  enable_feedback               = false
  enable_encryption             = false
  enable_archive_policy         = false
  enable_default_topic_policy   = false
  enable_data_protection_policy = false

  tags = {
    "Project" = "terraform-aws-sns-standard"
  }
}

provider "aws" {
  region                  = var.region
  shared_credentials_files = ["D:/Users/joel.reyes/.aws/credentials"]
  profile                 = "126391801411_CloudDevOps"
}

run "verify_sns_topic_name_null" {
  variables {
    topic_name = null
  }

  command = plan

  expect_failures = [
    var.topic_name,
  ]
}

run "verify_sns_topic_name_empty" {
  variables {
    topic_name = ""
  }

  command = plan

  expect_failures = [
    var.topic_name,
  ]
}

run "verify_boleans_true_false" {
  variables {
    fifo_topic = null
    enable_archive_policy = null
    enable_encryption = null
    enable_default_topic_policy = null
    enable_data_protection_policy = null
    enable_feedback = null
  }

  command = plan

  expect_failures = [
    var.fifo_topic,
    var.enable_archive_policy,
    var.enable_encryption,
    var.enable_default_topic_policy,
    var.enable_data_protection_policy,
    var.enable_feedback,
  ]
}

run "verify_content_based_deduplication_null" {
  variables {
    content_based_deduplication = null
  }

  command = plan

  expect_failures = [
    var.content_based_deduplication,
  ]
}

run "verify_tracing_config_invalid" {
  variables {
    tracing_config = "InvalidValue"
  }

  command = plan

  expect_failures = [
    var.tracing_config,
  ]
}

run "verify_tags_exist" {

  command = plan

  assert {
    condition     = contains(keys(var.tags), "Project") && var.tags["Project"] == "terraform-aws-sns-standard"
    error_message = "The 'Project' tag with the value 'terraform-aws-sns-standard' must be present."
  }

}

run "standard_configuration" {

  variables {
    fifo_topic                  = false
    content_based_deduplication = false
    enable_data_protection_policy = false
  }

  command = plan

  assert {
    condition     = var.fifo_topic == false
    error_message = "FIFO topic configuration does not match expected value."
  }

  assert {
    condition     = !var.enable_data_protection_policy
    error_message = "Data protection policy should not be applied for a standard topic."
  }

  assert {
    condition     = var.content_based_deduplication == false
    error_message = "Content-based deduplication must be enabled for FIFO topics."
  }

}

run "fifo_configuration" {

  variables {
    fifo_topic                  = true
    content_based_deduplication = true
    enable_data_protection_policy = false
    tracing_config = "PassThrough"
  }

  command = plan

  assert {
    condition     = var.fifo_topic == true
    error_message = "FIFO topic configuration must be enabled."
  }

  assert {
    condition     = var.content_based_deduplication == true
    error_message = "Content-based deduplication must be enabled for FIFO topics."
  }

  assert {
    condition     = !var.enable_data_protection_policy
    error_message = "Data protection policy should be disabled for FIFO topics if enabled."
  }

  assert {
    condition     = var.tracing_config == "PassThrough"
    error_message = "TracingConfig must be set to 'PassThrough' for fifo topics"
  }

}

run "encryption_configuration" {

  variables {
    fifo_topic                  = true
    content_based_deduplication = true
    enable_data_protection_policy = false
    tracing_config = "PassThrough"
  }

  command = plan
}

run "verify_data_protection" {
  variables {
    fifo_topic                  = false
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
    enable_default_topic_policy = true
    topic_policy_statements = {}
  }

  assert {
    condition     = var.fifo_topic == false
    error_message = "FIFO topic configuration does not match expected value."
  }
  
  assert {
    condition     = var.enable_data_protection_policy
    error_message = "Data Protection Policy should be enabled for the SNS topic."
  }

  assert {
    condition     = length(var.data_protection_policy) > 0
    error_message = "A valid Data Protection Policy must be provided."
  }

  assert {
    condition     = (var.enable_data_protection_policy && var.data_protection_policy != null && !var.fifo_topic) || (!var.enable_data_protection_policy && var.fifo_topic)
    error_message = "Data protection policy should be applied only when enabled, not null, and FIFO topic is false."
  }
 }