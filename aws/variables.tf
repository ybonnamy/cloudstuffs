variable "region_name" {
  description = "Value of region for the EC2 instance"
  type        = string
  default     = "eu-west-3"
}

variable "availability_zone_name" {
  description = "Value of availability_zone for the EC2 instance"
  type        = string
  default     = "eu-west-3c"
}

variable "main_key_name" {
  description = "Main Key Pair Name "
  type        = string
  default     = "MainKeyPair"
}

variable "private_key" {
  description = "private_key "
  type        = string
  default     = "/home/cloudshell-user/.ssh/MainKeyPair.pem"
}


