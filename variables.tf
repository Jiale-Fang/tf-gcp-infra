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

variable "application_ports" {
  type        = list(number)
  description = "List of application ports to allow"
}

variable "firewall_protocol" {
  type        = string
  description = "The IP protocol used to create a firewall rule"
}

variable "firewall_source_ranges" {
  type        = list(string)
  description = "Firewall will apply only to traffic that has source IP address in these ranges"
}

variable "vm_boot_disk_params" {
  description = "Boot disk parameters"
  type = object({
    image = string
    size  = number
    type  = string
  })
}
