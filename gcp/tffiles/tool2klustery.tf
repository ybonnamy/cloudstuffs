############################################
# PEERING 
############################################

# Peering de Klustery vers Tool
resource "google_compute_network_peering" "peering_klustery_to_tool" {
  name         = "peering-klustery-to-tool"
  network      = google_compute_network.klustery.id
  peer_network = google_compute_network.tool.id

  # Important pour l'échange des routes IPv6
  export_custom_routes = true
  import_custom_routes = true
  
  # Si vous voulez que les plages secondaires (pods/services) soient visibles
  export_subnet_routes_with_public_ip = true
  import_subnet_routes_with_public_ip = true
}

# Peering de Tool vers Klustery
resource "google_compute_network_peering" "peering_tool_to_klustery" {
  name         = "peering-tool-to-klustery"
  network      = google_compute_network.tool.id
  peer_network = google_compute_network.klustery.id

  export_custom_routes = true
  import_custom_routes = true
  
  export_subnet_routes_with_public_ip = true
  import_subnet_routes_with_public_ip = true
}


# Autoriser le trafic venant de Tool vers Klustery
resource "google_compute_firewall" "allow_tool_to_klustery" {
  name    = "allow-tool-to-klustery"
  network = google_compute_network.klustery.name

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  
  # On autorise le subnet de Tool (IPv4)
  source_ranges = [google_compute_subnetwork.tool.ip_cidr_range]
}

# Autoriser le trafic venant de Klustery vers Tool
resource "google_compute_firewall" "allow_klustery_to_tool" {
  name    = "allow-klustery-to-tool"
  network = google_compute_network.tool.name

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  # On autorise le subnet de Klustery + les plages secondaires GKE
  source_ranges = local.klustery_all_ranges
}
