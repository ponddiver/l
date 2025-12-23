# Get the latest Oracle Linux 8 image
data "oci_core_images" "oracle_linux" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Virtual Cloud Network
resource "oci_core_vcn" "oracle_vcn" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "oracle-vcn"
  dns_label      = "oraclevcn"
}

# Internet Gateway
resource "oci_core_internet_gateway" "oracle_igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oracle_vcn.id
  display_name   = "oracle-igw"
  enabled        = true
}

# Route Table
resource "oci_core_route_table" "oracle_route_table" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oracle_vcn.id
  display_name   = "oracle-route-table"

  route_rules {
    network_entity_id = oci_core_internet_gateway.oracle_igw.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

# Security List
resource "oci_core_security_list" "oracle_security_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.oracle_vcn.id
  display_name   = "oracle-security-list"

  # Egress - Allow all outbound
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # Ingress - SSH
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Ingress - Oracle Listener (1521)
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 1521
      max = 1521
    }
  }

  # Ingress - Oracle Enterprise Manager (5500)
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 5500
      max = 5500
    }
  }

  # Ingress - ICMP
  ingress_security_rules {
    protocol = "1" # ICMP
    source   = "0.0.0.0/0"
  }
}

# Subnet
resource "oci_core_subnet" "oracle_subnet" {
  compartment_id      = var.compartment_ocid
  vcn_id              = oci_core_vcn.oracle_vcn.id
  cidr_block          = "10.0.1.0/24"
  display_name        = "oracle-subnet"
  dns_label           = "oraclesub"
  route_table_id      = oci_core_route_table.oracle_route_table.id
  security_list_ids   = [oci_core_security_list.oracle_security_list.id]
  prohibit_public_ip_on_vnic = false
}

# Compute Instance
resource "oci_core_instance" "oracle_instance" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = var.instance_display_name
  shape               = var.instance_shape

  # Shape config for flexible shapes (A1.Flex)
  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_in_gbs
  }

  # Boot volume configuration
  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.oracle_linux.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  }

  # Network configuration
  create_vnic_details {
    subnet_id        = oci_core_subnet.oracle_subnet.id
    display_name     = "primary-vnic"
    assign_public_ip = true
    hostname_label   = "oracle19c"
  }

  # SSH key
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {}))
  }

  # Preserve boot volume on instance termination
  preserve_boot_volume = false

  lifecycle {
    ignore_changes = [
      source_details[0].source_id
    ]
  }
}
