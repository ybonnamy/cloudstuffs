variable "region_name" {
  description = "Value of region for the EC2 instance"
  type        = string
  default     = "europe-west9"
}

variable "availability_zone_name" {
  description = "Value of availability_zone for the EC2 instance"
  type        = string
  default     = "europe-west9-c"
}

variable "main_key_name" {
  description = "Main Key Pair Name "
  type        = string
  default     = "MainKeyPair"
}

variable "private_key" {
  description = "private_key "
  type        = string
  default     = "~/.ssh/MainKeyPair.pem"
}

variable "aws_region_name" {
  description = "Value of region for the EC2 instance"
  type        = string
  default     = "eu-west-3"
}

data "aws_route53_zone" "ybonnamyname" {
  name         = "ybonnamy.name."
  private_zone = false
}

variable "publicdomainname" {
  description = "domain name for public ip resolutions"
  type        = string
  default     = "gcp.ybonnamy.name"
}

data "google_compute_image" "ubuntu" {
  family  = "ubuntu-2404-lts-amd64"
  project = "ubuntu-os-cloud-devel"
}
