# Google Cloud Platform Provider
provider "google" {
  project = var.project_id
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

resource "google_compute_subnetwork" "webapp_subnet" {
  count                    = var.vpc_count
  name                     = "webapp-subnet-${count.index + 1}-${random_string.name_suffix.result}"
  ip_cidr_range            = var.ip_cidr_ranges[count.index * 2]
  region                   = var.region
  network                  = google_compute_network.vpc_network[count.index].id
  private_ip_google_access = true
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

resource "google_compute_firewall" "vpc_firewall_webapp_allow_rule" {
  count    = var.vpc_count
  name     = "vpc-firewall-webapp-allow-rule-${count.index + 1}-${random_string.name_suffix.result}"
  network  = google_compute_network.vpc_network[count.index].id
  priority = var.firewall.allow_rule_priority
  allow {
    protocol = var.firewall.allow_rule_protocol
    ports    = var.firewall.allow_rule_ports
  }
  source_ranges = var.firewall.allow_rule_source_ranges
  target_tags   = ["webapp-${count.index + 1}-${random_string.name_suffix.result}"]
}

// Explicit to deny all another rule as required
resource "google_compute_firewall" "vpc_firewall_deny_rule" {
  count    = var.vpc_count
  name     = "vpc-firewall-deny-rule-${count.index + 1}-${random_string.name_suffix.result}"
  network  = google_compute_network.vpc_network[count.index].id
  priority = var.firewall.deny_rule_priority
  deny {
    protocol = var.firewall.deny_rule_protocol
  }
  source_ranges = var.firewall.deny_rule_source_ranges
  target_tags   = ["webapp-${count.index + 1}-${random_string.name_suffix.result}"]
}

resource "google_compute_instance" "vm_instance" {
  count        = var.vpc_count
  name         = "vm-instance-${count.index + 1}-${random_string.name_suffix.result}"
  machine_type = var.vm_machine_type
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
    subnetwork = google_compute_subnetwork.webapp_subnet[count.index].id
    access_config {}
  }
  metadata_startup_script = <<-EOF
    #!/bin/bash
    sudo yum update -y
    echo "y" | sudo yum install -y mysql

    sudo cat <<EOT > /opt/csye6225_repo/startup.sh
    #!/bin/bash
    DB_HOST="${var.psc_addrs[count.index]}"
    DB_USER="webapp"
    DB_PASSWORD=${random_password.mysql_password.result}
    java -jar /opt/csye6225_repo/Health_Check-0.0.1-SNAPSHOT.jar --spring.datasource.username=\$DB_USER \
    --spring.datasource.password=\$DB_PASSWORD \
    --spring.datasource.url="jdbc:mysql://\$DB_HOST:3306/health_check?useUnicode=true&characterEncoding=utf-8&serverTimezone=America/New_York&createDatabaseIfNotExist=true" 
    EOT
    
    sudo chmod +x /opt/csye6225_repo/startup.sh
    sudo systemctl daemon-reload
    sudo systemctl start csye6225
  EOF
  depends_on              = [google_sql_database_instance.db_instance]
}

resource "google_compute_address" "psc_address" {
  count        = var.vpc_count
  project      = var.project_id
  name         = "psc-address-${count.index + 1}-${random_string.name_suffix.result}"
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.webapp_subnet[count.index].id
  address      = var.psc_addrs[count.index]
}

resource "google_compute_forwarding_rule" "psc_endpoint" {
  count                   = var.vpc_count
  project                 = var.project_id
  name                    = "psc-endpoint-${count.index + 1}-${random_string.name_suffix.result}"
  region                  = var.region
  target                  = google_sql_database_instance.db_instance[count.index].psc_service_attachment_link
  network                 = google_compute_network.vpc_network[count.index].id
  ip_address              = google_compute_address.psc_address[count.index].id
  load_balancing_scheme   = ""
  allow_psc_global_access = true
}

resource "google_sql_database_instance" "db_instance" {
  count               = var.vpc_count
  name                = "db-instance-${count.index + 1}-${random_string.name_suffix.result}"
  region              = var.region
  database_version    = var.database_instance_config.database_version
  deletion_protection = var.database_instance_config.deletion_protection

  settings {
    tier = var.database_instance_config.settings.tier
    ip_configuration {
      ipv4_enabled                                  = false
      enable_private_path_for_google_cloud_services = true
      psc_config {
        psc_enabled               = true
        allowed_consumer_projects = [var.project_id]
      }
    }
    backup_configuration {
      enabled            = var.database_instance_config.settings.backup_configuration.enabled
      binary_log_enabled = var.database_instance_config.settings.backup_configuration.binary_log_enabled
    }
    availability_type = var.database_instance_config.settings.availability_type
    disk_type         = var.database_instance_config.settings.disk_type
    disk_size         = var.database_instance_config.settings.disk_size
    edition           = var.database_instance_config.settings.edition
  }

}

resource "google_sql_database" "database" {
  count    = var.vpc_count
  name     = "webapp-db-${count.index + 1}-${random_string.name_suffix.result}"
  instance = google_sql_database_instance.db_instance[count.index].name
}

resource "google_sql_user" "db_user" {
  count    = var.vpc_count
  name     = var.db_username
  password = random_password.mysql_password.result
  instance = google_sql_database_instance.db_instance[count.index].name
  host     = "%"
}

resource "random_password" "mysql_password" {
  length  = 16
  special = false
}
