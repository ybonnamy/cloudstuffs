# attempt to reproduce business partner infrastructure for training purpose
############################################
# VARIABLES DECLARATION 
############################################

variable "os_image" {
  description = "OS image to use for all boot disks"
  type        = string
  default = "projects/debian-cloud/global/images/debian-12-bookworm-v20260114"
}

variable "machine_types" {
  description = "Machine types per VM tier"
  type = map(string)
  default={
  control_plane = "e2-medium"
  worker        = "e2-medium"
  storage       = "e2-medium"
  }
}

variable "boot_disk_size" {
  description = "Size (GB) of each VM boot disk"
  type        = number
  default     = 50
}

variable "worker_count" {
  description = "Total number of kube-node (worker) instances"
  type        = number
  default     = null
}

variable "storage_count" {
  description = "Total number of kube-node-storage instances"
  type        = number
  default     = null
}

variable "manager_count" {
  description = "Total number of kube-manager (control-plane) instances"
  type        = number
  default     = null
}

variable "manager_ip_offset" {
  description = "Starting IP last byte for managers"
  type        = number
  default     = 251
}

variable "storage_ip_offset" {
  description = "Starting IP last byte for storage nodes"
  type        = number
  default     = 101
}

variable "worker_ip_offset" {
  description = "Starting IP last byte for worker nodes"
  type        = number
  default     = 11
}

data "google_compute_zones" "available" {
  region = var.region_name
  status = "UP" 
}

locals {
  zones = data.google_compute_zones.available.names
  
  # extract last zone letter for naming purposes
  azs = [for z in local.zones : split("-", z)[length(split("-", z)) - 1]]

  nb_zones = length(local.zones)
 
  # default to have one machine type in each zone
  # coalesce(a, b) takes firt non null value
  final_worker_count  = coalesce(var.worker_count, local.nb_zones)
  final_manager_count = coalesce(var.manager_count, local.nb_zones)
  final_storage_count = coalesce(var.storage_count, local.nb_zones)
  
  ssh_metadata = "ansible:${file(var.ssh_public_key)}"

  main_cidr = google_compute_subnetwork.klustery-subnetwork.ip_cidr_range
  
  # concatenate every subnets ranges for firewalling 
  klustery_all_ranges = concat(
    [local.main_cidr],
    [for r in google_compute_subnetwork.klustery-subnetwork.secondary_ip_range : r.ip_cidr_range]
  )

}

############################################
# NETWORK 
############################################

resource "google_compute_network" "klustery" {
  name                     = "klustery-network"
  enable_ula_internal_ipv6 = true
  auto_create_subnetworks  = false
  routing_mode = "REGIONAL"
}

resource "google_compute_subnetwork" "klustery-subnetwork" {
  network                    = google_compute_network.klustery.id
  name                       = "klustery-subnetwork"
  ip_cidr_range              = "10.16.0.0/24"
  stack_type                 = "IPV4_ONLY"
  purpose = "PRIVATE"
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "240.0.0.0/19"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "240.0.128.0/22"
  }
  private_ip_google_access   = true
  private_ipv6_google_access = true
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

#required for tcp-proxy-kube-* google_compute_region_target_tcp_proxy
resource "google_compute_subnetwork" "klustery-subnetwork-proxyonly" {
  name          = "klustery-subnetwork-proxyonly"
  ip_cidr_range = "240.1.0.0/24"
  network                    = google_compute_network.klustery.id
  stack_type = "IPV4_IPV6"
  purpose = "REGIONAL_MANAGED_PROXY"
  role    = "ACTIVE"
}



        
############################################
# INSTANCES
############################################

resource "google_compute_instance" "worker" {
  count        = local.final_worker_count
  name         = format("kube-node%d-%s", count.index + 1, local.azs[count.index % length(local.azs)])
  zone         = local.zones[count.index % length(local.azs)]
  machine_type = var.machine_types["worker"]
  tags         = ["kube-node"]

  labels = {
    name         = format("kube-node%d-%s", count.index + 1, local.azs[count.index % length(local.azs)])
    is-xdr = "true"
    ansible-group = "workers"
    k3s-role      = "worker"
  }
  
  lifecycle {
    ignore_changes = [
      attached_disk
    ]
  }

  boot_disk {
    initialize_params {
      image = var.os_image
      size  = var.boot_disk_size
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.klustery-subnetwork.id
    #network_ip = format(var.subnet_cidr_template, var.worker_ip_offset + count.index)
	network_ip = cidrhost(local.main_cidr, var.worker_ip_offset + count.index)
  }

  metadata = {
    ssh-keys = local.ssh_metadata
  }
}

resource "google_compute_instance" "storage" {
  count        = local.final_storage_count
  name         = format("kube-node-storage%d-%s", count.index + 100, local.azs[count.index % length(local.azs)])
  zone         = local.zones[count.index % length(local.azs)]
  machine_type = var.machine_types["storage"]
  tags         = ["kube-node-storage"]

  labels = {
    name          = format("kube-node-storage%d-%s", count.index + 100, local.azs[count.index % length(local.azs)])
    is-xdr = "true"
    ansible-group = "storage"
    k3s-role      = "worker"
    storage-type  = "elasticsearch-cold"
  }
  
  boot_disk {
    initialize_params {
      image = var.os_image
      size  = var.boot_disk_size
      type  = "pd-standard"
    }
  }

  lifecycle {
    ignore_changes = [
      attached_disk
    ]
  }

  network_interface {
    subnetwork = google_compute_subnetwork.klustery-subnetwork.id
    #network_ip = format(var.subnet_cidr_template, var.storage_ip_offset + count.index)
    network_ip = cidrhost(local.main_cidr, var.storage_ip_offset + count.index)
  }

  metadata = {
    ssh-keys = local.ssh_metadata
  }
}

## Control-plane VMs
resource "google_compute_instance" "control_plane" {
  count        = local.final_manager_count
  name         = format("kube-manager%d-%s", count.index + 1, local.azs[count.index % length(local.azs)])
  zone         = local.zones[count.index % length(local.azs)]
  machine_type = var.machine_types["control_plane"]
  tags         = ["kube-manager"]

  labels = {
    name         = format("kube-manager%d-%s", count.index + 1, local.azs[count.index % length(local.azs)])
    is-xdr = "true"
    ansible-group = "managers"
    k3s-role      = "manager"
  }

  boot_disk {
    initialize_params {
      image = var.os_image
      size  = var.boot_disk_size
      type  = "pd-standard"
    }
  }

  lifecycle {
    ignore_changes = [
      attached_disk
    ]
  }

  network_interface {
    subnetwork = google_compute_subnetwork.klustery-subnetwork.id
    #network_ip = format(var.subnet_cidr_template, var.manager_ip_offset + count.index)
    network_ip = cidrhost(local.main_cidr, var.manager_ip_offset + count.index)
  }

  metadata = {
    ssh-keys = local.ssh_metadata
  }
}

############################################
# Firewall Rules (SSH + all LB ports)
############################################

resource "google_compute_firewall" "allow_ingress" {
  name    = "allow-ingress"
  network = google_compute_network.klustery.id

  allow {
    protocol = "tcp"
    ports    = ["22", "6443", "80", "443", "10514", "11514", "10250", "2379", "2380", "4240", "4250"]
  }

  allow {
    protocol = "udp"
    ports    = ["8472"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_egress" {
  name    = "allow-egress"
  network = google_compute_network.klustery.id
  direction = "EGRESS"

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
}

## Unmanaged Zonal Instance Groups
resource "google_compute_instance_group" "worker_ig" {
  for_each = toset(local.azs)
  name     = "kube-node-ig-${each.key}"
  zone     = "${var.region_name}-${each.key}"

  named_port {
    name = "https"
    port = "443"
  }
  named_port {
    name = "http"
    port = "80"
  }
  named_port {
    name = "syslog"
    port = "10514"
  }
  named_port {
    name = "relp"
    port = "11514"
  }

  instances = [
    for idx in range(local.final_worker_count) :
    google_compute_instance.worker[idx].self_link
    if local.azs[idx % length(local.azs)] == each.key
  ]
}

resource "google_compute_instance_group" "ctrl_ig" {
  for_each = toset(local.azs)
  name     = "kube-manager-ig-${each.key}"
  zone     = "${var.region_name}-${each.key}"

  named_port {
    name = "https"
    port = "6443"
  }

  instances = [
    for idx in range(local.final_manager_count) :
    google_compute_instance.control_plane[idx].self_link
    if local.azs[idx % length(local.azs)] == each.key
  ]
}

############################################
# Locals (shared settings + node port map)
############################################
locals {
  node_ports = {
    80    = { port_name = "http",   proxy_header = "PROXY_V1" }
    443   = { port_name = "https",  proxy_header = "PROXY_V1" }
    10514 = { port_name = "syslog", proxy_header = "NONE" }    # proxy disabled
    11514 = { port_name = "relp",   proxy_header = "NONE" }    # proxy disabled
  }

  # If these defaults change in a way that would force HC replacement,
  # we bake a deterministic hash into the HC name so we can
  # create-before-destroy without colliding on the name.
  health_check_defaults = {
    check_interval_sec  = 10
    timeout_sec         = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  backend_service_defaults = {
    protocol              = "TCP"
    load_balancing_scheme = "INTERNAL_MANAGED"
    balancing_mode        = "CONNECTION"
    max_conns_per_inst    = 10000
    capacity_scaler       = 1.0
  }

  # 8-char fingerprint of HC settings (changes only when defaults above change)
  health_check_fingerprint = substr(sha1(jsonencode(local.health_check_defaults)), 0, 8)
}

############################################
# Health checks
############################################

# 6443: leave as-is (manager plane)
resource "google_compute_region_health_check" "kube_manager" {
  name                = "hc-kube-manager-6443"
  region              = var.region_name
  check_interval_sec  = local.health_check_defaults.check_interval_sec
  timeout_sec         = local.health_check_defaults.timeout_sec
  healthy_threshold   = local.health_check_defaults.healthy_threshold
  unhealthy_threshold = local.health_check_defaults.unhealthy_threshold

  tcp_health_check { port = 6443 }
}

# Node ports (loop)
# Lifecycle notes:
# - create_before_destroy = true so the new HC can be created first
# - unique name via fingerprint avoids "alreadyExists" during replacement
# - Backend services will update their reference to the new HC, then the old HC is free to delete
resource "google_compute_region_health_check" "kube_node" {
  for_each            = local.node_ports
  name                = "hc-kube-node-${each.key}-${local.health_check_fingerprint}"
  region              = var.region_name
  check_interval_sec  = local.health_check_defaults.check_interval_sec
  timeout_sec         = local.health_check_defaults.timeout_sec
  healthy_threshold   = local.health_check_defaults.healthy_threshold
  unhealthy_threshold = local.health_check_defaults.unhealthy_threshold

  tcp_health_check { port = tonumber(each.key) }

  lifecycle {
    create_before_destroy = true
  }
}

############################################
# Backend services
############################################

# Manager
resource "google_compute_region_backend_service" "kube_manager_api" {
  name                  = "kube-manager-api-internal"
  region                = var.region_name
  protocol              = local.backend_service_defaults.protocol
  port_name             = "https"
  load_balancing_scheme = local.backend_service_defaults.load_balancing_scheme
  health_checks         = [google_compute_region_health_check.kube_manager.id]

  dynamic "backend" {
    for_each = google_compute_instance_group.ctrl_ig
    content {
      group                        = backend.value.self_link
      balancing_mode               = local.backend_service_defaults.balancing_mode
      max_connections_per_instance = local.backend_service_defaults.max_conns_per_inst
      capacity_scaler              = local.backend_service_defaults.capacity_scaler
    }
  }
}

# Nodes (loop)
# When a HC is replaced (due to name fingerprint change), this field updates in place,
# so no special lifecycle is needed here.
resource "google_compute_region_backend_service" "kube_node_app" {
  for_each              = local.node_ports
  name                  = "kube-node-app-${each.key}"
  region                = var.region_name
  protocol              = local.backend_service_defaults.protocol
  port_name             = each.value.port_name
  load_balancing_scheme = local.backend_service_defaults.load_balancing_scheme
  health_checks         = [google_compute_region_health_check.kube_node[each.key].id]

  dynamic "backend" {
    for_each = google_compute_instance_group.worker_ig
    content {
      group                        = backend.value.self_link
      balancing_mode               = local.backend_service_defaults.balancing_mode
      max_connections_per_instance = local.backend_service_defaults.max_conns_per_inst
      capacity_scaler              = local.backend_service_defaults.capacity_scaler
    }
  }
}

############################################
# Static Internal IPs
############################################

resource "google_compute_address" "ctrl_lb_static" {
  name         = "kube-manager-lb-static-ip"
  region       = var.region_name
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.klustery-subnetwork.id
  address      = cidrhost(local.main_cidr, 2) 
  purpose      = "SHARED_LOADBALANCER_VIP"
}

resource "google_compute_address" "worker_lb_app_static" {
  name         = "kube-node-lb-app-static-ip"
  region       = var.region_name
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.klustery-subnetwork.id
  address      = cidrhost(local.main_cidr, 4)
  purpose      = "SHARED_LOADBALANCER_VIP"
}

resource "google_compute_address" "worker_lb_log_static" {
  name         = "kube-node-lb-log-static-ip"
  region       = var.region_name
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.klustery-subnetwork.id
  address      = cidrhost(local.main_cidr, 5)
  purpose      = "SHARED_LOADBALANCER_VIP"
}


############################################
# Target TCP proxies
############################################

# Manager
resource "google_compute_region_target_tcp_proxy" "kube_manager_api" {
  name            = "tcp-proxy-kube-manager"
  region          = var.region_name
  backend_service = google_compute_region_backend_service.kube_manager_api.id
}

# Nodes (loop) — points each proxy to its matching backend
resource "google_compute_region_target_tcp_proxy" "kube_node_app" {
  for_each        = local.node_ports
  name            = "tcp-proxy-kube-node-${each.key}"
  region          = var.region_name
  backend_service = google_compute_region_backend_service.kube_node_app[each.key].id
  proxy_header    = each.value.proxy_header # PROXY_V1 for 80/443, NONE for 10514/11514
}

############################################
# Forwarding rules
############################################

# Manager (single LB on its own static IP)
resource "google_compute_forwarding_rule" "kube_lb_6443" {
  name                  = "kube-manager-lb"
  region                = var.region_name
  load_balancing_scheme = "INTERNAL_MANAGED"
  target                = google_compute_region_target_tcp_proxy.kube_manager_api.id
  ip_protocol           = "TCP"
  port_range            = "6443"
  network               = google_compute_network.klustery.id
  subnetwork            = google_compute_subnetwork.klustery-subnetwork.id
  ip_address            = google_compute_address.ctrl_lb_static.address
  lifecycle {
    replace_triggered_by = [google_compute_region_target_tcp_proxy.kube_manager_api]
  }
  depends_on = [
    google_compute_subnetwork.klustery-subnetwork-proxyonly
  ]
}

resource "google_compute_forwarding_rule" "worker_lb_http" {
  for_each              = { for k, v in local.node_ports : k => v if contains([80, 443], tonumber(k)) }
  name                  = "kube-node-http-lb-${each.key}"
  region                = var.region_name
  load_balancing_scheme = "INTERNAL_MANAGED"
  target                = google_compute_region_target_tcp_proxy.kube_node_app[each.key].id
  ip_protocol           = "TCP"
  port_range            = tostring(each.key)
  network               = google_compute_network.klustery.id
  subnetwork            = google_compute_subnetwork.klustery-subnetwork.id
  ip_address            = google_compute_address.worker_lb_app_static.address
  lifecycle {
    replace_triggered_by = [google_compute_region_target_tcp_proxy.kube_node_app[each.key]]
  }
}

# Syslog/RELP LB on a separate static IP (10514, 11514)
resource "google_compute_forwarding_rule" "worker_lb_log" {
  for_each              = { for k, v in local.node_ports : k => v if contains([10514, 11514], tonumber(k)) }
  name                  = "kube-node-log-lb-${each.key}"
  region                = var.region_name
  load_balancing_scheme = "INTERNAL_MANAGED"
  target                = google_compute_region_target_tcp_proxy.kube_node_app[each.key].id
  ip_protocol           = "TCP"
  port_range            = tostring(each.key)
  network               = google_compute_network.klustery.id
  subnetwork            = google_compute_subnetwork.klustery-subnetwork.id
  ip_address            = google_compute_address.worker_lb_log_static.address
  lifecycle {
    replace_triggered_by = [google_compute_region_target_tcp_proxy.kube_node_app[each.key]]
  }
}

############################################
# ADD INTERNET EGRESS
############################################

resource "google_compute_router" "klustery-router" {
      name    = "router-nat"
      region  = var.region_name
      network = google_compute_network.klustery.id
    }

resource "google_compute_router_nat" "nat" {
      name                               = "nat-gw"
      router                             = google_compute_router.klustery-router.name
      region                             = google_compute_router.klustery-router.region
      source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES" 
      nat_ip_allocate_option = "AUTO_ONLY" 
}


############################################
# Google Compute Engine Persistent Disk CSI Driver
############################################

resource "google_project_iam_custom_role" "csi_driver_role" {
      role_id     = "gcp_compute_persistent_disk_csi_driver_custom_role_for_klustery"
      title       = "Google Compute Engine Persistent Disk CSI Driver Custom Role"
      permissions = [
        "compute.instances.get",
        "compute.instances.attachDisk",
        "compute.instances.detachDisk",
        "compute.disks.get"
      ]
    }
	
resource "google_service_account" "csi_driver_sa" {
  account_id   = "gce-pd-csidriver-sa-klustery" 
  display_name = "Service Account for GCP Compute PD CSI Driver"
}

locals {
  csi_roles = {
    "editor"         = "roles/editor",
    "storageAdmin"   = "roles/compute.storageAdmin",
    "saUser"         = "roles/iam.serviceAccountUser",
    "custom_csi"     = google_project_iam_custom_role.csi_driver_role.id
  }
}

data "google_project" "current" {}

resource "google_project_iam_member" "csi_bindings" {
  for_each = local.csi_roles
  role     = each.value
  member   = "serviceAccount:${google_service_account.csi_driver_sa.email}"
  project  = data.google_project.current.project_id
}

resource "google_service_account_key" "csi_driver_key" {
  service_account_id = google_service_account.csi_driver_sa.name
}

resource "local_file" "csi_driver_key_file" {
  content  = base64decode(google_service_account_key.csi_driver_key.private_key)
  filename = pathexpand("~/.secrets/csi_driver_key_file.json")
}


############################################
# Repo Reader 
############################################

resource "google_service_account" "k8s_repo_reader" {
  account_id   = "k8s-repo-reader-klustery" 
  display_name = "K8s Repo Reader for klustery"
}

resource "google_project_iam_member" "repo_reader_bindings" {
  role     = "roles/artifactregistry.reader"
  member   = "serviceAccount:${google_service_account.k8s_repo_reader.email}"
  project  = data.google_project.current.project_id
}

resource "google_service_account_key" "repo_reader_key" {
  service_account_id = google_service_account.k8s_repo_reader.name
}
resource "local_file" "repo_reader_key_file" {
  content  = base64decode(google_service_account_key.repo_reader_key.private_key)
  filename = pathexpand("~/.secrets/key.reporeader.klustery.json")
}