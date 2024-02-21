# Google Cloud Platform Provider
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
  routing_mode                    = var.vpc_routing_mode
}

resource "google_compute_subnetwork" "webapp" {
  count         = var.vpc_count
  name          = "webapp-subnet-${count.index + 1}-${random_string.name_suffix.result}"
  ip_cidr_range = var.ip_cidr_ranges[count.index * 2]
  region        = var.region
  network       = google_compute_network.vpc_network[count.index].id
}

resource "google_compute_subnetwork" "db" {
  count         = var.vpc_count
  name          = "db-subnet-${count.index + 1}-${random_string.name_suffix.result}"
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

resource "google_compute_firewall" "vpc_firewall" {
  count   = var.vpc_count
  name    = "vpc-firewall-${count.index + 1}-${random_string.name_suffix.result}"
  network = google_compute_network.vpc_network[count.index].id
  allow {
    protocol = var.firewall_protocol
    ports    = var.application_ports
  }
  source_ranges = var.firewall_source_ranges
  target_tags   = ["webapp-${count.index + 1}-${random_string.name_suffix.result}"]
}

resource "google_compute_instance" "vm_instance" {
  count        = var.vpc_count
  name         = "vm-instance-${count.index + 1}-${random_string.name_suffix.result}"
  machine_type = "n1-standard-1"
  zone         = var.zone
  tags         = ["webapp-${count.index + 1}-${random_string.name_suffix.result}"]
  boot_disk {
    initialize_params {
      image = var.vm_boot_disk_params.image
      size  = var.vm_boot_disk_params.size
      type  = var.vm_boot_disk_params.type
    }
  }
  network_interface {
    network    = google_compute_network.vpc_network[count.index].id
    subnetwork = google_compute_subnetwork.webapp[count.index].id
    access_config {}
  }
}
