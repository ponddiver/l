# Oracle 19c VM on OCI - Terraform Configuration

This Terraform configuration creates a Linux VM on Oracle Cloud Infrastructure (OCI) optimized for installing Oracle Database 19c, using **free tier** resources whenever possible.

## Free Tier Resources Used

- **Compute**: VM.Standard.A1.Flex (Ampere ARM-based)
  - 2 OCPUs (configurable up to 4)
  - 12 GB RAM (configurable up to 24GB)
  - Always Free eligible
- **Boot Volume**: 100 GB (up to 200GB total allowed in free tier)
- **Networking**: VCN, Subnet, Internet Gateway (all free)

## Prerequisites

1. **OCI Account**: Create a free account at https://cloud.oracle.com
2. **OCI CLI**: Install and configure OCI CLI
3. **API Key**: Generate API signing key pair for OCI
4. **Terraform**: Install Terraform (>= 1.0)

### Setup OCI API Key

```bash
# Generate API key pair
mkdir -p ~/.oci
openssl genrsa -out ~/.oci/oci_api_key.pem 2048
openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem

# Get the fingerprint
openssl rsa -pubout -outform DER -in ~/.oci/oci_api_key.pem | openssl md5 -c
```

Add the public key to your OCI user account:
- OCI Console → User Settings → API Keys → Add API Key

### Get Required OCIDs

You'll need to find these values in the OCI Console:

- **Tenancy OCID**: Profile → Tenancy → OCID
- **User OCID**: Profile → User Settings → OCID
- **Compartment OCID**: Identity → Compartments → Select your compartment → OCID
- **Availability Domain**: Use OCI CLI or console to find available domains

```bash
# List availability domains
oci iam availability-domain list --compartment-id <your-tenancy-ocid>
```

## Usage

### 1. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 2. Generate SSH Key (if you don't have one)

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/oci_key
# Copy the public key content to terraform.tfvars
cat ~/.ssh/oci_key.pub
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan and Apply

```bash
terraform plan
terraform apply
```

### 5. Connect to Your Instance

After successful deployment, get the connection command:

```bash
terraform output ssh_connection
# ssh opc@<public-ip>
```

## Oracle 19c Installation

Once connected to the VM:

### 1. Download Oracle 19c

```bash
# Switch to oracle user
sudo su - oracle

# Download Oracle 19c from Oracle.com (requires Oracle account)
# Place the zip file in /tmp/
```

### 2. Install Oracle Database

```bash
# Unzip the installation files
cd /u01/app/oracle/product/19.0.0/dbhome_1
unzip -q /tmp/LINUX.ARM64_1919000_db_home.zip

# Run the installer
./runInstaller -silent -responseFile /u01/app/oracle/product/19.0.0/dbhome_1/install/response/db_install.rsp \
    oracle.install.option=INSTALL_DB_SWONLY \
    UNIX_GROUP_NAME=oinstall \
    INVENTORY_LOCATION=/u01/app/oraInventory \
    ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1 \
    ORACLE_BASE=/u01/app/oracle \
    oracle.install.db.InstallEdition=EE \
    oracle.install.db.OSDBA_GROUP=dba \
    oracle.install.db.OSOPER_GROUP=oper \
    oracle.install.db.OSBACKUPDBA_GROUP=backupdba \
    oracle.install.db.OSDGDBA_GROUP=dgdba \
    oracle.install.db.OSKMDBA_GROUP=kmdba \
    oracle.install.db.OSRACDBA_GROUP=racdba \
    DECLINE_SECURITY_UPDATES=true

# Run root scripts when prompted (as root user)
# sudo /u01/app/oraInventory/orainstRoot.sh
# sudo /u01/app/oracle/product/19.0.0/dbhome_1/root.sh
```

### 3. Create Database

```bash
# As oracle user, create database using DBCA
dbca -silent -createDatabase \
    -templateName General_Purpose.dbc \
    -gdbname orcl \
    -sid orcl \
    -responseFile NO_VALUE \
    -characterSet AL32UTF8 \
    -memoryPercentage 80 \
    -emConfiguration NONE \
    -storageType FS \
    -datafileDestination /u02/oradata \
    -sysPassword YourSysPassword \
    -systemPassword YourSystemPassword
```

### 4. Configure Environment

Add to oracle user's `.bash_profile`:

```bash
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=orcl
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
```

## Cost Optimization

- Uses **Ampere A1 (ARM)** shape which is always free
- 2 OCPUs and 12GB RAM is sufficient for development/testing
- Can scale up to 4 OCPUs and 24GB RAM while staying in free tier
- Boot volume set to 100GB (free tier allows 200GB total)
- No additional block volumes created initially

## Security Considerations

⚠️ **Important**: The security list allows SSH and Oracle Listener access from anywhere (0.0.0.0/0). 

For production:
- Restrict SSH access to your IP only
- Use VPN or bastion host for database access
- Enable Oracle wallet for secure connections
- Implement regular backups

## Resource Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Troubleshooting

### Connection Issues
- Ensure security list rules allow port 22 (SSH)
- Verify the public IP is accessible
- Check your SSH key is correct

### Oracle Installation Issues
- Verify preinstall package is installed: `rpm -q oracle-database-preinstall-19c`
- Check kernel parameters: `sysctl -a | grep -i sem`
- Verify disk space: `df -h`

### Out of Memory
- Add more swap space
- Increase instance memory (up to 24GB free tier)
- Reduce database memory parameters

## Additional Resources

- [OCI Free Tier](https://www.oracle.com/cloud/free/)
- [Oracle Database 19c Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/19/)
- [OCI Terraform Provider](https://registry.terraform.io/providers/oracle/oci/latest/docs)

## License

This configuration is provided as-is for educational and development purposes.
