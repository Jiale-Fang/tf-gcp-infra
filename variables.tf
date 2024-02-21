variable "region" {
  type        = string
  description = "Resources Region"
}

variable "zone" {
  type        = string
  description = "Resources Zone"
}

variable "vpc_count" {
  type        = number
  description = "The count of the vpcs"
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
