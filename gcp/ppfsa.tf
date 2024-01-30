resource "google_compute_subnetwork" "ppf" {
  network                    = google_compute_network.main.id
  name                       = "ppf-subnetwork"
  ip_cidr_range              = "10.13.0.0/24"
  stack_type                 = "IPV4_IPV6"
  ipv6_access_type           = "EXTERNAL"
  private_ip_google_access   = true
  private_ipv6_google_access = true
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "allow-ppf-ipv4" {
  name    = "allow-ppf-ipv4"
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

resource "google_compute_firewall" "allow-ppf-ipv6" {
  name    = "allow-ppf-ipv6"
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


data "google_compute_image" "u20" {
  family  = "ubuntu-minimal-2004-lts"
  project = "ubuntu-os-cloud-devel"
}

module "ppfsa" {
  source            = "./modules/typicalpersisteddata/"
  instance_name     = "ppfsa"
  image_id          = data.google_compute_image.u20.self_link
  disk_size         = 10
  disk_mode         = "READ_WRITE"
  environment       = "dev"
  purpose           = "lmc"
  role              = "ppfsa"
  zone              = var.availability_zone_name
  ssh_keys          = ["${var.provisionninguser}:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOkQ/4I65lRavhUi5xsaJAgqAMEdw+DfRiPc/S9Gzddc", "${var.provisionninguser}:ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAq+4cfLij6BjRQvl0PKyUkSVa8c54/7+FSclRzwR1M4npKJ2a8XX6LAaZoIsrzoTmHfDLK2bZICcyHDx+ek8rDi22rO8Cz30FvI1KNztDABEsqu2otmF6oqiq3clrcOoDMgo2WZSibATzGCuNq1Xvt2Z/G6WEZ34zsdmbgnYMnZ3/M1iOwvbGNeTl7fPMCljreN5bUZPXOGLTndUjIcbel91aQ433v0RL7koZaQBJsG42xmutKkx6v0IuHimVLGmNLGsK57GLHjFP8dm4jv8YJuTAiy+0NIOS6iKFgpdror9+o2aaGzCi4zuvhnHf1M1h6ytdbPSU/YFSXKTr+dxbCw== mobaxterm@pcoam", "${var.provisionninguser}:ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA8/GphrIRwif4o2ZxHSYWyHMBIqCleYKQDKtlNjFJEId+auJJVL4cmJRGMFAIOo2ush7Ab8U8LxkdeIZUfwjRqlee2aSAhHsfK+YqNXOx6x9PREZu93YmACFbpkFw1ACq1CRotwfnffXySnmTSd2wKisG33911RFoDdNBmAWiOEIbAsSwpozNxehHr7HW4nPXDReQO6WBF4FIuOlLPM2iqNXa6yuMFExol8xDIQ4PDMt6oH4FiddECDHOF+wc6XDhdwiM26SKMqWB3577pJ62vUv6ip1xX+7IARJMxRkBVvZwmS3IEB40SUFDj++DHhBeYO9zOVrK245MAXqvjsuSYQ== linux@xpc"]
  subnetwork        = google_compute_subnetwork.ppf.id
  provisionninguser = var.provisionninguser
  private_key       = "~/.ssh/MainKeyPair.pem"
  #gcloud compute disks create ppfsapersisted --type=pd-standard --size=200GB --zone=europe-west9-c
  google_compute_attached_disk = "ppfsapersisted"
  route53zone                  = data.aws_route53_zone.ybonnamyname.zone_id
  publicdomainname             = var.publicdomainname
}
