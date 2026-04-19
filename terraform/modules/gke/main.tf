############################################
# GKE CLUSTER
############################################

resource "google_container_cluster" "gke" {
  name     = "microservices-cluster"
  location = var.zone   # e.g. us-central1-a

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network
  subnetwork = var.subnetwork

  # VPC-native cluster
  ip_allocation_policy {}

  lifecycle {
    prevent_destroy = true

    # Ignore fields that commonly drift
    ignore_changes = [
      initial_node_count
    ]
  }
}

############################################
# NODE POOL (COST OPTIMIZED)
############################################

resource "google_container_node_pool" "cheap_pool" {
  name     = "cheap-pool"
  cluster  = google_container_cluster.gke.id
  location = var.zone

  # Autoscaling instead of fixed nodes
  autoscaling {
    min_node_count = 1
    max_node_count = 2
  }

  node_config {
    machine_type = "e2-small"
    disk_size_gb = 30

    # Cheap but interruptible
    preemptible = true

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    tags = ["gke-node"]
  }

  lifecycle {
    ignore_changes = [
      node_count
    ]
  }
}