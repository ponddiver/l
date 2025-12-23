---
applyTo: '**/vagrant/**'
description: 'Create Vagrant configurations and box setups'
---

## Base Box
- Use https://oracle.github.io/vagrant-projects/boxes/oraclelinux/ as the base box for Oracle Linux Vagrant boxes.
- Use http://localhost:8080/boxes/files/ as the base box for custom internal Vagrant boxes.
- Do not use special unicode characters.

## Box Configuration
- Ensure the Vagrant box is kept up to date with the latest patches and updates.
- Configure the Vagrant box to use bridged networking by default.
- Set minimum CPU to 6 cores and minimum memory to 15 GB RAM.
- Optimize the Vagrant box for performance and resource usage.

## Provisioning & Documentation
- Include necessary provisioning scripts to automate the setup of the Vagrant box.
- Document any special configuration or setup steps required for the Vagrant box.
- Use consistent naming conventions for box versions (e.g., OracleLinux-8.9, format: OS-version).
- Maintain a Vagrantfile with clear comments explaining the configuration and any non-obvious settings.

## Security
- Implement least privilege principles in provisioning scripts (avoid running as root when possible).
- Ensure SSH key-based authentication is configured by default.