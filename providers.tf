provider "google" {
  project     = var.project
  region      = var.region
  zone      = var.zone
}

terraform {
  backend gcs {
    bucket = "interview-mark-21648c-terraform"
  }
}
