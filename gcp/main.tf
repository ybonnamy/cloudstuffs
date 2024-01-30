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

resource "google_compute_firewall" "allow-basics-ipv4" {
  name    = "allow-basics-ipv4"
  network = google_compute_network.main.id

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["8443", "443", "22"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-basics-ipv6" {
  name    = "allow-basics-ipv6"
  network = google_compute_network.main.id

  allow {
    protocol = "58"
  }

  allow {
    protocol = "tcp"
    ports    = ["8443", "443", "22"]
  }
  source_ranges = ["::/0"]
}