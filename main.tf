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
      "https://www.googleapis.com/auth/cloud-platform"
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
  network_policy {
    enabled = true
    provider = "CALICO"
  }

  provisioner local-exec {
    command = "gcloud container clusters get-credentials ${google_container_cluster.mark_interview_cluster.name} --zone=${var.zone}"
  }
}

resource kubernetes_storage_class retained_ssd {
  metadata {
    name = "retained-ssd"
  }
  storage_provisioner = "kubernetes.io/gce-pd"
  reclaim_policy = "Retain"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    type = "pd-ssd"
    replication-type = "regional-pd"
  }

  depends_on = [google_container_cluster.mark_interview_cluster]
}

# imported
resource kubernetes_service frontend {
  metadata {
    name = "frontend-external"
    labels = {
      "skaffold.dev/builder"    = "google-cloud-build"
      "skaffold.dev/cleanup"    = "true"
      "skaffold.dev/deployer"   = "kubectl"
      "skaffold.dev/profile.0"  = "gcb"
      "skaffold.dev/run-id"     = "e7244b0b-92c7-48ba-b276-b1f118a811ae"
      "skaffold.dev/tag-policy" = "git-commit"
      "skaffold.dev/tail"       = "true"
    }
  }
  spec {
    selector = {
      app = "frontend"
    }
    port {
      name = "http"
      node_port = 31576
      port = 80
      protocol = "TCP"
      target_port = "8080"
    }
    type = "LoadBalancer"
  }
}

# imported
resource google_dns_managed_zone k8s_careers_mark {
  name = "k8s-careers-mark"
  dns_name = "mark.future.k8s.careers."
  description = "Public delegated interview zone"
}

resource google_dns_record_set frontend {
  name = "frontend.${google_dns_managed_zone.k8s_careers_mark.dns_name}"
  type = "A"
  ttl = 300
  managed_zone = google_dns_managed_zone.k8s_careers_mark.name
  rrdatas = [kubernetes_service.frontend.load_balancer_ingress[0].ip]
}
