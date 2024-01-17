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

resource "google_compute_network" "main" {
  name                     = "main-network"
  enable_ula_internal_ipv6 = true
  auto_create_subnetworks  = false
}

resource "google_compute_subnetwork" "main" {
  network                    = google_compute_network.main.id
  name                       = "main-subnetwork"
  ip_cidr_range              = "10.11.0.0/24"
  stack_type                 = "IPV4_IPV6"
  ipv6_access_type           = "EXTERNAL"
  private_ip_google_access   = true
  private_ipv6_google_access = true
  secondary_ip_range {
    range_name    = "secondary"
    ip_cidr_range = "192.168.99.0/24"
  }
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "allow-basics-ipv4" {
  name    = "allow-basics-ipv4"
  network = google_compute_network.main.id

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "22"]
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
    ports    = ["80", "443", "22"]
  }
  source_ranges = ["::/0"]
}