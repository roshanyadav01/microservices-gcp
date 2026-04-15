resource "google_compute_network" "vpc" {
  name                    = "microservices-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "microservices-subnet"
  ip_cidr_range = "10.10.0.0/16"
  region        = var.region
  network       = google_compute_network.vpc.id
  
}