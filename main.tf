resource google_compute_address default_region_NAT {
  name = "source-nat"
  region = var.region
  description = "Provides static outbound IP address for VMs in region ${var.region} with no external IP address."
}

resource google_project_service project {
  for_each = toset([for service in split("\n", file("services.txt")): service if service != "" ])
  service = each.value
}
resource google_compute_router default_router {
  name = "default-router"
  network = "default"
  region = var.region
  description = "Provides routed for default region ${var.region}"
}

resource google_compute_router_nat default_nat_rule {
  name = "default-nat-route"
  router = google_compute_router.default_router.name
  nat_ip_allocate_option = "MANUAL_ONLY"
  nat_ips = [google_compute_address.default_region_NAT.self_link]
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource google_container_cluster mark_interview_cluster {
  name = "mark-interview-cluster"
  location = var.zone
  description = "Demo for interview"
  min_master_version = "1.16.8-gke.15"
  initial_node_count = 3

  node_config {
    preemptible = true
    machine_type = "n1-standard-2"

    metadata = {
      disable-legacy-endpoints = "true"
    }
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }

  private_cluster_config {
    master_ipv4_cidr_block = "10.184.0.128/28"
    enable_private_endpoint = false
    enable_private_nodes = true
  }

  ip_allocation_policy {}

  addons_config {
    network_policy_config {
      disabled = false
    }
  }

}
