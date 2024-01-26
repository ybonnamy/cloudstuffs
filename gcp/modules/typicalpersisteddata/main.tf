resource "google_compute_instance" "typicalpersisteddata" {
  boot_disk {
    auto_delete = true
    device_name = var.instance_name

    initialize_params {
      image = var.image_id
      size  = var.disk_size
      type  = var.disk_type
    }

    mode = var.disk_mode
  }

  attached_disk {
    source = var.google_compute_attached_disk
  }

  labels = {
    name          = var.instance_name
    environnement = var.environment
    purpose       = var.purpose
    role          = var.role
  }

  zone                = var.zone
  name                = var.instance_name
  can_ip_forward      = var.can_ip_forward
  deletion_protection = var.deletion_protection
  enable_display      = var.enable_display
  machine_type        = var.instance_type

  metadata = {
    ssh-keys = join("\n", var.ssh_keys)
  }




  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }
    stack_type = "IPV4_IPV6"
    subnetwork = var.subnetwork
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
    user        = var.provisionninguser
    private_key = file(var.private_key)
    host        = self.network_interface[0].access_config[0].nat_ip
  }

  provisioner "remote-exec" {
    // only aim at waiting for online VM to avoid failure of ansible-playbook
    inline = ["echo 'connected!'"]
  }
  

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ${var.provisionninguser} --private-key ${var.private_key} -i ~/cloudstuffs/gcp/inventorygcp.yml -l label_name_${self.labels.name} ansible/first-install.yml"
  }

}


resource "aws_route53_record" "typicalpersisteddataipv4" {
  zone_id = var.route53zone
  name    = "${var.instance_name}.${var.publicdomainname}"
  type    = "A"
  ttl     = 300
  records = [google_compute_instance.typicalpersisteddata.network_interface[0].access_config[0].nat_ip]
}

