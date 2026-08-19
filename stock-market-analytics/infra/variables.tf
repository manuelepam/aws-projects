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

variable "pipeline_enabled" {
  description = "Whether the producer schedules and Kinesis processor trigger are enabled."
  type        = bool
  default     = false
}

variable "allow_data_deletion" {
  description = "Allow Terraform to delete objects from the raw-data bucket during teardown."
  type        = bool
  default     = false
}
