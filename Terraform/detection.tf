# Turn on GuardDuty (the threat detector)
resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

output "guardduty_detector_id" {
  value = aws_guardduty_detector.main.id
}