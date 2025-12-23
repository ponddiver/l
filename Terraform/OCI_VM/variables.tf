variable "tenancy_ocid" {
  description = "OCID of your tenancy"
  type        = string
}

variable "user_ocid" {
  description = "OCID of the user calling the API"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint for the key pair being used"
  type        = string
}

variable "private_key_path" {
  description = "Path to your private key"
  type        = string
}

variable "region" {
  description = "OCI region"
  type        = string
  default     = "us-ashburn-1"
}

variable "compartment_ocid" {
  description = "OCID of your compartment"
  type        = string
}

variable "availability_domain" {
  description = "Availability domain name (e.g., 'QnsC:US-ASHBURN-AD-1')"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
}

variable "instance_shape" {
  description = "Shape of the instance (VM.Standard.A1.Flex is free tier eligible)"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "instance_ocpus" {
  description = "Number of OCPUs (max 4 for free tier Ampere A1)"
  type        = number
  default     = 2
}

variable "instance_memory_in_gbs" {
  description = "Amount of memory in GBs (max 24GB for free tier Ampere A1)"
  type        = number
  default     = 12
}

variable "boot_volume_size_in_gbs" {
  description = "Boot volume size in GBs (max 200GB for free tier)"
  type        = number
  default     = 100
}

variable "instance_display_name" {
  description = "Display name for the instance"
  type        = string
  default     = "oracle19c-vm"
}
