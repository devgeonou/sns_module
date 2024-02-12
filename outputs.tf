################################################################################
# Topic
################################################################################

output "topic_arn" {
  description = "The ARN of the SNS topic."
  value       = aws_sns_topic.this.arn
}

output "topic_name" {
  description = "The name of the SNS topic."
  value       = aws_sns_topic.this.name
}

output "topic_owner" {
  description = "The AWS Account ID of the SNS topic owner."
  value       = aws_sns_topic.this.owner
}

output "topic_beginning_archive_time" {
  description = "The oldest timestamp at which a FIFO topic subscriber can start a replay. Relevant only for FIFO topics."
  value       = aws_sns_topic.this.beginning_archive_time
}

################################################################################
# Subscription(s)
################################################################################

output "subscriptions" {
  description = "Map of subscriptions created and their attributes"
  value       = aws_sns_topic_subscription.this
}
