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
