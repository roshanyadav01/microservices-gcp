resource "google_iam_workload_identity_pool" "pool" {
  workload_identity_pool_id = "github-pool1"
  depends_on                = [google_project_service.services]
}

resource "google_iam_workload_identity_pool_provider" "provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider1"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }
  attribute_condition = "attribute.repository == '${var.github_repo}'"

  depends_on = [google_iam_workload_identity_pool.pool]
}

resource "google_service_account" "sa" {
  account_id = "github-sa"
  depends_on = [google_project_service.services]
}

resource "google_project_service" "services" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "sts.googleapis.com",
    "cloudresourcemanager.googleapis.com"
  ])

  project = var.project_id
  service = each.key
  disable_on_destroy = false
}

resource "google_artifact_registry_repository_iam_member" "writer" {
  location   = "us-central1"
  repository = "microservices"
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_project_iam_member" "roles" {
  for_each = toset([
    "roles/container.admin",
    "roles/artifactregistry.writer",
    "roles/storage.admin",
    "roles/viewer",
    "roles/iam.serviceAccountUser"
  ])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.sa.email}"
}

data "google_project" "current" {}

resource "google_service_account_iam_member" "binding" {
  service_account_id = google_service_account.sa.id
  role               = "roles/iam.workloadIdentityUser"
  member = "principalSet://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.pool.workload_identity_pool_id}/attribute.repository/${var.github_repo}"
}
