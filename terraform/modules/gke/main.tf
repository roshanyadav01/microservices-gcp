resource "google_container_cluster" "gke" {
  name     = "microservices-cluster"
  location = var.zone

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network
  subnetwork = var.subnetwork

  ip_allocation_policy {}

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      node_config,
      initial_node_count,
    ]
  }

}

resource "google_container_node_pool" "cheap_pool" {
  name     = "cheap-pool"
  cluster  = google_container_cluster.gke.name
  location = var.zone

  node_count = 1

  node_config {
    machine_type = "e2-small"
    disk_size_gb = 30
    preemptible  = true

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}