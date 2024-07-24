# Title: RNS ID Devops challenge
# Author: Amen M. Abe
# Email: bdere12345@gmail.com
# main.tf

# define google GCP as a provider
# declare gcp project variable and region 
provider "google" {
  project = var.project_id
  region  = var.region
}

# Define variables for project ID
variable "gcp_project_id" {
  description = "The GCP project ID"
  type        = string
  default     =  "gcp-project-id"
}

# Define variables for region
variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

# Define variables for DB username
variable "db_username" {
  description = "PostgresQL database username"
  type        = string
}

# Define variables for DB password
variable "db_pass" {
  description = "PostgresQL database password"
  type        = string
}

# create resource for google SQL database for PostgresQL v 12
resource "google_sql_database_instance" "default" {
  name             = "pg-instance-name"
  database_version = "POSTGRES_12"
  settings {
    tier = "db-f1-micro" # choose small f1 micro instance for testing
  }
}

# create google SQL database inside the "google_sql_database_instance" resource defined above
resource "google_sql_database" "default" {
  name     = "db-name"
  instance = google_sql_database_instance.default.name # refer the above instance
}

# create SQL user for the instance
resource "google_sql_user" "default" {
  name     = var.db_username
  instance = google_sql_database_instance.default.name
  password = var.db_pass
}

# create cloud run service. I referred https://cloud.google.com/run 
# Referred google cloud run terraform module at https://registry.terraform.io/modules/GoogleCloudPlatform/cloud-run/google/latest
resource "google_cloud_run_service" "default" {
  name     = "service-name"
  location = var.region

  template {
    spec {
      containers {
        image = "gcr.io/cloudrun/hello" # get a sample hello world from google Artifacts Registry
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}


# set global address for load balancing
resource "google_compute_global_address" "default" {
  name = "sample-ip"
} 

# url map to the backend service defined above as "google_cloud_run_service"
resource "google_compute_url_map" "default" {
  name            = "sample-url-map"
  default_service = google_cloud_run_service.default.status[0].url
}

# TargetHttpProxy for forwarding global incoming http requests to the url map above "google_compute_url_map"
resource "google_compute_target_http_proxy" "default" {
  name    = "sample-http-proxy"
  url_map = google_compute_url_map.default.self_link
}

# GlobalForwardingRule resource forward correct traffic to http at port 80 for load balancing
resource "google_compute_global_forwarding_rule" "default" {
  name       = "sample-forwarding-rule"
  ip_address = google_compute_global_address.default.address
  port_range = "80"
  target     = google_compute_target_http_proxy.default.self_link
}
