# Google Cloud Platform Provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Create Service account
resource "google_service_account" "custom_service_account" {
  account_id   = var.service_account.account_id
  display_name = var.service_account.display_name
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
  routing_mode                    = var.vpc_routing_mode
}

resource "google_compute_subnetwork" "webapp_subnet" {
  name                     = "webapp-subnet-${random_string.name_suffix.result}"
  ip_cidr_range            = var.ip_cidr_ranges[0]
  region                   = var.region
  network                  = google_compute_network.vpc_network.id
  private_ip_google_access = true
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

resource "google_compute_firewall" "vpc_firewall_webapp_allow_rule" {
  name     = "vpc-firewall-webapp-allow-rule-${random_string.name_suffix.result}"
  network  = google_compute_network.vpc_network.id
  priority = var.firewall.allow_rule_priority
  allow {
    protocol = var.firewall.allow_rule_protocol
    ports    = var.firewall.allow_rule_ports
  }
  source_ranges = var.firewall.allow_rule_source_ranges
  target_tags   = ["webapp-${random_string.name_suffix.result}"]
}

# Explicit to deny all another rule as required
resource "google_compute_firewall" "vpc_firewall_deny_rule" {
  name     = "vpc-firewall-deny-rule-${random_string.name_suffix.result}"
  network  = google_compute_network.vpc_network.id
  priority = var.firewall.deny_rule_priority
  deny {
    protocol = var.firewall.deny_rule_protocol
  }
  source_ranges = var.firewall.deny_rule_source_ranges
  target_tags   = ["webapp-${random_string.name_suffix.result}"]
}

resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc_network.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

resource "google_sql_database_instance" "db_instance" {
  name                = "db-instance-${random_string.name_suffix.result}"
  region              = var.region
  database_version    = var.database_instance_config.database_version
  deletion_protection = var.database_instance_config.deletion_protection

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier = var.database_instance_config.settings.tier
    ip_configuration {
      ipv4_enabled                                  = false
      enable_private_path_for_google_cloud_services = true
      private_network                               = google_compute_network.vpc_network.id
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
  name     = "webapp-db-${random_string.name_suffix.result}"
  instance = google_sql_database_instance.db_instance.name
}

resource "google_sql_user" "db_user" {
  name     = var.db_username
  password = random_password.mysql_password.result
  instance = google_sql_database_instance.db_instance.name
  host     = "%"
}

resource "random_password" "mysql_password" {
  length  = 16
  special = false
}

# fetching already created DNS zone
data "google_dns_managed_zone" "dns_zone" {
  name = var.dns_zone
}

# to register web-server's ip address in DNS
resource "google_dns_record_set" "dns_a_record" {
  name         = data.google_dns_managed_zone.dns_zone.dns_name
  managed_zone = data.google_dns_managed_zone.dns_zone.name
  type         = "A"
  ttl          = 300
  rrdatas = [
    module.gce-lb-http.external_ip
  ]
  depends_on = [module.gce-lb-http]
}

# Bind IAM Roles to the Service Account
resource "google_project_iam_binding" "logging_admin" {
  project = var.project_id
  role    = "roles/logging.admin"

  members = [
    "serviceAccount:${google_service_account.custom_service_account.email}",
  ]
}

resource "google_project_iam_binding" "monitoring_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"

  members = [
    "serviceAccount:${google_service_account.custom_service_account.email}",
  ]
}

resource "google_project_iam_binding" "pubsub_admin" {
  project = var.project_id
  role    = "roles/pubsub.admin"

  members = [
    "serviceAccount:${google_service_account.custom_service_account.email}",
  ]
}

# Create Pub/Sub
resource "google_pubsub_topic" "pubsub_topic" {
  name                       = var.topic.name
  message_retention_duration = var.topic.message_retention_duration
}

# Create Storage bucket to store cloud function code
resource "google_storage_bucket" "storage_bucket" {
  name     = "storage-bucket-${random_string.name_suffix.result}"
  location = "US"
}

resource "google_storage_bucket_object" "storage_bucket_object" {
  name   = "function-source.zip"
  bucket = google_storage_bucket.storage_bucket.name
  source = "./function-source.zip"
}

# Cloud Function, will automatically create a subscription binding to the topic
resource "google_cloudfunctions_function" "cloud_function" {
  name        = "cloud-function-${random_string.name_suffix.result}"
  description = var.cloud_function.description
  runtime     = var.cloud_function.runtime

  available_memory_mb   = var.cloud_function.available_memory_mb
  source_archive_bucket = google_storage_bucket.storage_bucket.name
  source_archive_object = google_storage_bucket_object.storage_bucket_object.name
  timeout               = var.cloud_function.timeout
  entry_point           = var.cloud_function.entry_point

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.pubsub_topic.id
  }

  environment_variables = {
    DB_URL          = "jdbc:mysql://${google_sql_database_instance.db_instance.private_ip_address}:3306/health_check?useUnicode=true&characterEncoding=utf-8&serverTimezone=America/New_York&createDatabaseIfNotExist=true"
    DB_PASSWORD     = "${random_password.mysql_password.result}"
    DB_USER         = var.db_username
    MAILGUN_API_KEY = var.mailgun_api_key
  }

  min_instances                 = var.cloud_function.min_instances
  max_instances                 = var.cloud_function.max_instances
  ingress_settings              = var.cloud_function.ingress_settings
  vpc_connector                 = "projects/${var.project_id}/locations/${var.region}/connectors/vpc-connector"
  vpc_connector_egress_settings = var.cloud_function.vpc_connector_egress_settings

  depends_on = [google_sql_database_instance.db_instance, google_vpc_access_connector.vpc_connector]
}

resource "google_vpc_access_connector" "vpc_connector" {
  name          = "vpc-connector"
  ip_cidr_range = var.vpc_connector.ip_cidr_range
  network       = google_compute_network.vpc_network.id
  machine_type  = var.vpc_connector.machine_type
  min_instances = var.vpc_connector.min_instances
  max_instances = var.vpc_connector.max_instances
  region        = var.region
}

// Should allow traffic from Google Front End (GFE): https://cloud.google.com/load-balancing/docs/https
resource "google_compute_firewall" "health_check_allow_rule" {
  name          = "health-check-allow-rule"
  direction     = "INGRESS"
  network       = "global/networks/default"
  priority      = 999
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["allow-health-check"]
  allow {
    ports    = ["8080"]
    protocol = "tcp"
  }
}

resource "google_compute_region_instance_template" "instance_template" {
  name_prefix = "instance-template-"
  description = "This template is used to create app server instances."

  tags = ["webapp-${random_string.name_suffix.result}", "allow-health-check"]

  instance_description = "Webapp instance"
  machine_type         = var.vm_machine_type
  can_ip_forward       = false

  scheduling {
    automatic_restart = true
  }

  // Create a new boot disk from an image
  disk {
    source_image = "projects/csye-6225-413815/global/images/${var.vm_boot_disk_params.image}"
    auto_delete  = true
    boot         = true
    disk_type    = var.vm_boot_disk_params.type
    disk_size_gb = var.vm_boot_disk_params.size
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.webapp_subnet.id
  }

  lifecycle {
    create_before_destroy = true
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    sudo cat <<EOT > /opt/csye6225_repo/startup.sh
    #!/bin/bash
    DB_HOST="${google_sql_database_instance.db_instance.private_ip_address}"
    DB_USER="webapp"
    DB_PASSWORD=${random_password.mysql_password.result}
    java -Dlogback.log.path="/var/log" -jar /opt/csye6225_repo/Health_Check-0.0.1-SNAPSHOT.jar --spring.datasource.username=\$DB_USER \
    --spring.datasource.password=\$DB_PASSWORD \
    --spring.datasource.url="jdbc:mysql://\$DB_HOST:3306/health_check?useUnicode=true&characterEncoding=utf-8&serverTimezone=America/New_York&createDatabaseIfNotExist=true" 
    EOT

    sudo chmod +x /opt/csye6225_repo/startup.sh
    sudo systemctl daemon-reload
    sudo systemctl enable csye6225
    sudo systemctl start csye6225
  EOF
  depends_on              = [google_sql_database_instance.db_instance]

  service_account {
    email  = google_service_account.custom_service_account.email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_region_instance_group_manager" "instance_group_manager" {
  name                             = "instance-group-manager"
  base_instance_name               = "webapp"
  region                           = var.region
  distribution_policy_zones        = var.instance_az
  distribution_policy_target_shape = "EVEN"

  version {
    instance_template = google_compute_region_instance_template.instance_template.self_link
  }

  named_port {
    name = "webapp-port"
    port = 8080
  }

  target_size = "1"
}

resource "google_compute_region_autoscaler" "region-autoscaler" {
  name   = "region-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.instance_group_manager.id

  autoscaling_policy {
    max_replicas    = var.autoscaling_policy.max_replicas
    min_replicas    = var.autoscaling_policy.min_replicas
    cooldown_period = var.autoscaling_policy.cooldown_period

    cpu_utilization {
      target = var.autoscaling_policy.cpu_utilization.target
    }
  }
}

module "gce-lb-http" {
  source  = "GoogleCloudPlatform/lb-http/google"
  version = "~> 9.0"

  project                         = var.project_id
  name                            = "group-http-lb"
  target_tags                     = ["lb-fw-allow-rule"]
  network                         = google_compute_network.vpc_network.id
  create_address                  = true
  ssl                             = true
  managed_ssl_certificate_domains = ["jialefang.site"]
  http_forward                    = false

  backends = {
    default = {
      port                            = var.backend_service.port
      protocol                        = var.backend_service.protocol
      port_name                       = var.backend_service.port_name
      timeout_sec                     = var.backend_service.timeout_sec
      enable_cdn                      = var.backend_service.enable_cdn
      connection_draining_timeout_sec = var.backend_service.connection_draining_timeout_sec
      locality_lb_policy              = var.backend_service.locality_lb_policy

      health_check = {
        request_path        = var.health_check.request_path
        port                = var.health_check.port
        check_interval_sec  = var.health_check.check_interval_sec
        timeout_sec         = var.health_check.timeout_sec
        healthy_threshold   = var.health_check.healthy_threshold
        unhealthy_threshold = var.health_check.unhealthy_threshold
        logging             = var.health_check.logging
      }

      log_config = {
        enable      = true
        sample_rate = 1.0
      }

      groups = [
        {
          # Each node pool instance group should be added to the backend.
          group          = google_compute_region_instance_group_manager.instance_group_manager.instance_group,
          balancing_mode = "UTILIZATION"
        },
      ]

      iap_config = {
        enable = false
      }
    }
  }
}
