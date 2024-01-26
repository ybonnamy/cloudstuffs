variable "instance_name_maininstance" {
  description = "Value of the Name tag for the instance"
  type        = string
  default     = "maininstance"
}


resource "google_compute_instance" "main-instance-1" {
  boot_disk {
    auto_delete = true
    device_name = var.instance_name_maininstance

    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = 10
      type  = "pd-standard"
    }

    mode = "READ_WRITE"
  }

  labels = {
    name          = var.instance_name_maininstance
    environnement = "dev"
    purpose       = "lab"
    role          = "oam"
  }

  zone                = var.availability_zone_name
  name                = var.instance_name_maininstance
  can_ip_forward      = false
  deletion_protection = false
  enable_display      = true
  machine_type        = "e2-medium"

  metadata = {
    enable-osconfig = "TRUE"
    #ssh-keys        = "user:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOkQ/4I65lRavhUi5xsaJAgqAMEdw+DfRiPc/S9Gzddc"

    "ssh-keys" = <<EOT
         linux:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOkQ/4I65lRavhUi5xsaJAgqAMEdw+DfRiPc/S9Gzddc
         linux:ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAq+4cfLij6BjRQvl0PKyUkSVa8c54/7+FSclRzwR1M4npKJ2a8XX6LAaZoIsrzoTmHfDLK2bZICcyHDx+ek8rDi22rO8Cz30FvI1KNztDABEsqu2otmF6oqiq3clrcOoDMgo2WZSibATzGCuNq1Xvt2Z/G6WEZ34zsdmbgnYMnZ3/M1iOwvbGNeTl7fPMCljreN5bUZPXOGLTndUjIcbel91aQ433v0RL7koZaQBJsG42xmutKkx6v0IuHimVLGmNLGsK57GLHjFP8dm4jv8YJuTAiy+0NIOS6iKFgpdror9+o2aaGzCi4zuvhnHf1M1h6ytdbPSU/YFSXKTr+dxbCw== mobaxterm@pcoam
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

  connection {
    type        = "ssh"
    user        = "linux"
    private_key = file(var.private_key)
    host        = self.network_interface[0].access_config[0].nat_ip
  }

  provisioner "remote-exec" {
    // only aim at waiting for online VM to avoid failure of ansible-playbook
    inline = ["echo 'connected!'"]
  }
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u linux  --private-key ${var.private_key} -i ~/cloudstuffs/gcp/inventorygcp.yml -l label_name_${self.labels.name} ansible/first-install.yml"
    //command = "/bin/true"
  }

}

resource "google_compute_attached_disk" "default" {
  disk     = "maininstancepersisted"
  instance = google_compute_instance.main-instance-1.id
}

resource "aws_route53_record" "maininstanceipv4" {
  zone_id = data.aws_route53_zone.ybonnamyname.zone_id
  name    = "${var.instance_name_maininstance}.${var.publicdomainname}"
  type    = "A"
  ttl     = 300
  records = [google_compute_instance.main-instance-1.network_interface[0].access_config[0].nat_ip]
}

#below seems impossible with current terraform - worked around with ansible 
# resource "aws_route53_record" "maininstanceipv6" {
#   zone_id = data.aws_route53_zone.ybonnamyname.zone_id
#   name    = "${var.instance_name_maininstance}.${var.publicdomainname}"
#   type    = "AAAA"
#   ttl     = 300
#   records = [google_compute_instance.main-instance-1.network_interface[0].ipv6_access_config[0].external_ipv6]
# }