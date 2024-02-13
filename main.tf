# Google Cloud Platform Provider
variable "region" {
  type        = string
  description = "Resources Region"
}

variable "webapp_subnet_cidr_block" {
  type        = string
  description = "Cidr block for the webapp subnet"
}

variable "db_subnet_cidr_block" {
  type        = string
  description = "Cidr block for the db subnet"
}

variable "webapp_route_dest_range" {
  type        = string
  description = "Destination range for the webapp route"
}

provider "google" {
  project = "csye-6225-413815"
  region  = var.region
}

resource "random_string" "name_suffix" {
  length  = 6
  special = false
  lower   = true
  upper   = false
}

resource "google_compute_network" "vpc_network" {
  name                            = "vpc-network-${random_string.name_suffix.result}"
  auto_create_subnetworks         = false
  delete_default_routes_on_create = true
  routing_mode                    = "REGIONAL"
}

resource "google_compute_subnetwork" "webapp" {
  name          = "webapp-${random_string.name_suffix.result}"
  ip_cidr_range = var.webapp_subnet_cidr_block
  region        = var.region
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_subnetwork" "db" {
  name          = "db-${random_string.name_suffix.result}"
  ip_cidr_range = var.db_subnet_cidr_block
  region        = var.region
  network       = google_compute_network.vpc_network.id
}

# Route for webapp
resource "google_compute_route" "webapp_route" {
  name             = "webapp-route-${random_string.name_suffix.result}"
  network          = google_compute_network.vpc_network.id
  dest_range       = var.webapp_route_dest_range
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
  tags             = ["webapp-${random_string.name_suffix.result}"]
}
