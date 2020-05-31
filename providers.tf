provider "google" {
  project     = var.project
  region      = var.region
  zone      = var.zone
}

provider kubernetes {
  host = "https://${google_container_cluster.mark_interview_cluster.endpoint}"
}

terraform {
  backend gcs {
    bucket = "interview-mark-21648c-terraform"
  }
}
