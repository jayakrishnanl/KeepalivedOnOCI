
# Region
region = "eu-frankfurt-1"

# OCID of the VCN
vcn_id = ""
vcn_cidr =""

# Timezone of compute instance
timezone = "GMT"

# Size of volume (in gb) of the instances
compute_boot_volume_size_in_gb = "50"
compute_block_volume_size_in_gb = "0"

# Block Volume mount path
# compute_bv_mount_path = "/mnt/data"

# Prefix to define hostname for service nodes
keepalived_hostname_prefix = ""
web_hostname_prefix = ""

# Number of service nodes to be created
keepalived_instance_count = "3"
web_instance_count = "1"

# Bastion instance shape
bastion_instance_shape = "VM.Standard2.1"

# Service instance shape
keepalived_instance_shape = "VM.Standard2.1"
web_instance_shape = "VM.Standard2.1"

# OS user
bastion_user = "opc"
compute_instance_user = "opc"

# Free Form tags specified to your Regional Subnets
RegionalPrivateKey = ""
RegionalPrivateValue = ""
RegionalPublicKey = ""
RegionalPublicValue = ""

# Floating IP
VIP = ""