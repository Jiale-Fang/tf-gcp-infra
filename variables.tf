variable "project_id" {
  type        = string
  description = "Google Project Id"
}

variable "mailgun_api_key" {
  type        = string
  description = "The email api key of the mailgun"
}

variable "service_account" {
  description = "Custom service account"
  type = object({
    account_id   = string
    display_name = string
  })
}

variable "region" {
  type        = string
  description = "Resources Region"
}

variable "zone" {
  type        = string
  description = "Resources Zone"
}

variable "dns_zone" {
  type        = string
  description = "Existing DNS zone"
}

variable "instance_az" {
  type        = list(string)
  description = "The availale zones policy for managed instance group"
}

variable "vpc_routing_mode" {
  type        = string
  description = "The routing mode of the vpcs"
}

variable "ip_cidr_ranges" {
  type        = list(string)
  description = "IP cidr ranges"
}

variable "webapp_route_dest_range" {
  type        = string
  description = "Destination range for the webapp route"
}

variable "firewall" {
  description = "The rule of firewall"
  type = object({
    allow_rule_protocol      = string
    deny_rule_protocol       = string
    allow_rule_ports         = list(number)
    allow_rule_priority      = number
    deny_rule_priority       = number
    allow_rule_source_ranges = list(string)
    deny_rule_source_ranges  = list(string)
  })
}

variable "vm_machine_type" {
  description = "The machine type of the vm"
  type        = string
}

variable "vm_boot_disk_params" {
  description = "Boot disk parameters"
  type = object({
    image = string
    size  = number
    type  = string
  })
}

variable "database_instance_config" {
  description = "Configuration for the database instance"
  type = object({
    database_version    = string
    deletion_protection = bool
    settings = object({
      tier = string
      backup_configuration = object({
        enabled            = bool
        binary_log_enabled = bool
      })
      availability_type = string
      disk_type         = string
      disk_size         = number
      edition           = string
    })
  })
}

variable "db_username" {
  type        = string
  description = "GCP Cloud SQL username"
}

variable "topic" {
  description = "The topic of pub/sub"
  type = object({
    name                       = string
    message_retention_duration = string
  })
}

variable "cloud_function" {
  description = "Cloud function trigger by pub/sub"
  type = object({
    description                   = string
    runtime                       = string
    available_memory_mb           = number
    timeout                       = number
    entry_point                   = string
    min_instances                 = number
    max_instances                 = number
    ingress_settings              = string
    vpc_connector_egress_settings = string
  })
}

variable "vpc_connector" {
  description = "Vpc serverless connector"
  type = object({
    ip_cidr_range = string
    machine_type  = string
    min_instances = number
    max_instances = number
  })
}

variable "autoscaling_policy" {
  description = "Auto scailing policy for autoscaler"
  type = object({
    max_replicas    = number
    min_replicas    = number
    cooldown_period = number
    cpu_utilization = object({
      target = number
    })
  })
}

variable "backend_service" {
  description = "Backend service for lb"
  type = object({
    port                            = string
    protocol                        = string
    port_name                       = string
    timeout_sec                     = number
    enable_cdn                      = bool
    connection_draining_timeout_sec = number
    locality_lb_policy              = string
  })
}

variable "health_check" {
  description = "Health Check endpoint"
  type = object({
    request_path        = string
    port                = string
    check_interval_sec  = number
    timeout_sec         = number
    healthy_threshold   = number
    unhealthy_threshold = number
    logging             = bool
  })
}
