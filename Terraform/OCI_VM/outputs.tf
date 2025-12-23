output "instance_id" {
  description = "OCID of the created instance"
  value       = oci_core_instance.oracle_instance.id
}

output "instance_public_ip" {
  description = "Public IP address of the instance"
  value       = oci_core_instance.oracle_instance.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the instance"
  value       = oci_core_instance.oracle_instance.private_ip
}

output "vcn_id" {
  description = "OCID of the VCN"
  value       = oci_core_vcn.oracle_vcn.id
}

output "ssh_connection" {
  description = "SSH connection command"
  value       = "ssh opc@${oci_core_instance.oracle_instance.public_ip}"
}

output "instance_state" {
  description = "Current state of the instance"
  value       = oci_core_instance.oracle_instance.state
}
