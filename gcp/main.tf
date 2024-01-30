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

resource "google_compute_network" "main" {
  name                     = "main-network"
  enable_ula_internal_ipv6 = true
  auto_create_subnetworks  = false
}

