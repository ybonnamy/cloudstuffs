terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.11.0"
    }
  }
}

provider "google" {
  region = var.region_name
  zone   = var.availability_zone_name
}

provider "aws" {
  region = var.aws_region_name
  default_tags {
    tags = {
      Owner       = "yBO"
      Team        = "WorldGeeks"
      Environment = "DEV"
      Project     = "Cloudification"
      DeployedBy  = "Terraform"
    }
  }
}

