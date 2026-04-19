terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }

  backend "gcs" {
    bucket  = "tf-state-microservices"
    prefix  = "dev"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone = var.zone
}

module "network" {
  source = "../../modules/network"
  region = var.region
  depends_on = [
    module.wif
  ]
}

module "artifact" {
  source = "../../modules/artifacts"
  region = var.region
  depends_on = [
    module.wif
  ]
}

module "gke" {
  source     = "../../modules/gke"
  region     = var.region
  zone       = var.zone
  network    = module.network.network_name
  subnetwork = module.network.subnet_name
  depends_on = [
    module.network,
    module.artifact,
    module.wif
  ]
}

module "wif" {
  source      = "../../modules/wif"
  project_id  = var.project_id
  github_repo = var.github_repo
  project_number = var.project_number
}