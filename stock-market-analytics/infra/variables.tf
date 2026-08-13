variable "aws_region" {
  description = "AWS Region containing the existing stock-market resources."
  type        = string
  default     = "eu-north-1"
}

variable "alert_email" {
  description = "Confirmed email endpoint already subscribed to anomaly alerts."
  type        = string
  default     = "manuel.epam.etame+aws@gmail.com"
}
