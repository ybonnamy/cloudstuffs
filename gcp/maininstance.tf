resource "google_compute_instance" "main-instance-1" {
  boot_disk {
    auto_delete = true
    device_name = "main-instance-1"

    initialize_params {
      image = "projects/debian-cloud/global/images/debian-11-bullseye-v20231212"
      size  = 10
      type  = "pd-standard"
    }

    mode = "READ_WRITE"
  }

  zone                = var.availability_zone_name
  can_ip_forward      = false
  deletion_protection = false
  enable_display      = true
  machine_type        = "e2-small"
  name                = "instance-1"

  metadata = {
    enable-osconfig = "TRUE"
    #ssh-keys        = "user:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOkQ/4I65lRavhUi5xsaJAgqAMEdw+DfRiPc/S9Gzddc"

    "ssh-keys" = <<EOT
         user:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOkQ/4I65lRavhUi5xsaJAgqAMEdw+DfRiPc/S9Gzddc
         adm-infra:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOkQ/4I65lRavhUi5xsaJAgqAMEdw+DfRiPc/S9Gzddc
     EOT
  }

  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }
    stack_type = "IPV4_IPV6"
    subnetwork = google_compute_subnetwork.main.id
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
    provisioning_model  = "STANDARD"
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }


}
