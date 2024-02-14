# Google Cloud Platform Provider
variable "region" {
  type        = string
  description = "Resources Region"
}

variable "vpc_count" {
  type        = number
  description = "The count of the vpcs"
}

variable "ip_cidr_ranges" {
  type        = list(string)
  description = "IP cidr ranges"
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
  count                           = var.vpc_count
  name                            = "vpc-network-${count.index + 1}-${random_string.name_suffix.result}"
  auto_create_subnetworks         = false
  delete_default_routes_on_create = true
  routing_mode                    = "REGIONAL"
}

resource "google_compute_subnetwork" "webapp" {
  count         = var.vpc_count
  name          = "webapp-${count.index + 1}-${random_string.name_suffix.result}"
  ip_cidr_range = var.ip_cidr_ranges[count.index * 2]
  region        = var.region
  network       = google_compute_network.vpc_network[count.index].id
}

resource "google_compute_subnetwork" "db" {
  count         = var.vpc_count
  name          = "db-${count.index + 1}-${random_string.name_suffix.result}"
  ip_cidr_range = var.ip_cidr_ranges[count.index * 2 + 1]
  region        = var.region
  network       = google_compute_network.vpc_network[count.index].id
}

# Route for webapp
resource "google_compute_route" "webapp_route" {
  count            = var.vpc_count
  name             = "webapp-route-${count.index + 1}-${random_string.name_suffix.result}"
  network          = google_compute_network.vpc_network[count.index].id
  dest_range       = var.webapp_route_dest_range
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
  tags             = ["webapp-${count.index + 1}-${random_string.name_suffix.result}"]
}
