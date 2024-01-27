variable "instance_name" {
  description = "The name of the instance"
  type        = string
}

variable "image_id" {
  description = "The ID of the image to use for the instance"
  type        = string
}

variable "disk_size" {
  description = "The disk size for the instance in GB"
  type        = number
}

variable "disk_type" {
  description = "The type of the disk to attach to the instance"
  type        = string
  default     = "pd-standard"
}

variable "disk_mode" {
  description = "The mode of the disk to attach to the instance"
  type        = string
}

variable "environment" {
  description = "The environment in which the instance is deployed"
  type        = string
}

variable "purpose" {
  description = "The purpose of the instance"
  type        = string
}

variable "role" {
  description = "The role of the instance"
  type        = string
}

variable "zone" {
  description = "The availability zone in which to deploy the instance"
  type        = string
}

variable "instance_type" {
  description = "The type of instance to create"
  type        = string
  default     = "e2-medium"
}

variable "can_ip_forward" {
  description = "Defines whether the instance can forward IP"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Whether the instance should be protected from being deleted"
  type        = bool
  default     = false
}

variable "enable_display" {
  description = "Whether to enable display for the instance"
  type        = bool
  default     = true
}

variable "ssh_keys" {
  description = "List of ssh public keys to be inserted to the instance"
  type        = list(string)
}

variable "subnetwork" {
  description = "subnetwork"
  type        = string
}

variable "provisionninguser" {
  description = "provisionninguser"
  type        = string
}

variable "private_key" {
  description = "private_key"
  type        = string
}

variable "google_compute_attached_disk" {
  description = "google_compute_attached_disk"
  type        = string
}

variable "route53zone" {
  description = "The route53zone for registering the instance"
  type        = string
}

variable "publicdomainname" {
  description = "The publicdomainname for registering the instance"
  type        = string
}
