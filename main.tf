
locals {
  ADs             = "${data.oci_identity_availability_domains.ADs.availability_domains.*.name}"
  fds             = "${data.oci_identity_fault_domains.fds.fault_domains.*.name}"
  public_subnets  = "${compact(list("${lookup(data.oci_core_subnets.public-regional.subnets[0], "id")}"))}"
  private_subnets = "${compact(list("${lookup(data.oci_core_subnets.private-regional.subnets[0], "id")}"))}"
  tcp_protocol    = "6"
  udp_protocol    = "17"
  all_protocols   = "all"
  vrrp_protocol   = "112"
  anywhere        = "0.0.0.0/0"
}

#/*

# Create Bastion Node

module "create_bastion" {
  source                          = "./modules/compute"
  compartment_ocid                = "${var.compartment_ocid}"
  AD                              = "${local.ADs}"
  fault_domain                    = "${local.fds}"
  compute_subnet                  = "${local.public_subnets}"
  compute_instance_count          = "1"
  compute_hostname_prefix         = "bastion-${substr(var.region, 3, 3)}"
  compute_boot_volume_size_in_gb  = "${var.compute_boot_volume_size_in_gb}"
  compute_block_volume_size_in_gb = "0"
  compute_bv_mount_path           = ""
  compute_assign_public_ip        = "true"
  compute_image                   = "${var.instance_image_ocid[var.region]}"
  compute_instance_user           = "${var.compute_instance_user}"
  compute_instance_shape          = "${var.bastion_instance_shape}"
  compute_ssh_public_key          = "${var.ssh_public_key}"
  compute_ssh_private_key         = "${var.ssh_private_key}"
  bastion_ssh_private_key         = "${var.ssh_private_key}"
  nsgs                            = "${list(oci_core_network_security_group.bastion_nsg.id)}"
  bastion_user                    = ""
  bastion_public_ip               = ""
  timezone                        = "${var.timezone}"
  user_data                       = "./userdata/bootstrap_bastion.tpl"
}

# Create keepalived nodes
module "create_keepalived" {
  source                          = "./modules/compute"
  compartment_ocid                = "${var.compartment_ocid}"
  AD                              = "${local.ADs}"
  fault_domain                    = "${local.fds}"
  compute_subnet                  = "${local.private_subnets}"
  compute_instance_count          = "${var.keepalived_instance_count}"
  compute_hostname_prefix         = "${var.keepalived_hostname_prefix}-${substr(var.region, 3, 3)}"
  compute_boot_volume_size_in_gb  = "${var.compute_boot_volume_size_in_gb}"
  compute_block_volume_size_in_gb = "0"
  compute_bv_mount_path           = ""
  compute_assign_public_ip        = "false"
  compute_image                   = "${var.instance_image_ocid[var.region]}"
  compute_instance_shape          = "${var.keepalived_instance_shape}"
  compute_instance_user           = "${var.compute_instance_user}"
  compute_ssh_public_key          = "${var.ssh_public_key}"
  compute_ssh_private_key         = "${var.ssh_private_key}"
  bastion_ssh_private_key         = "${var.ssh_private_key}"
  bastion_public_ip               = "${module.create_bastion.ComputePublicIPs.0}"
  nsgs                            = "${list(oci_core_network_security_group.keepalived_nsg.id)}"
  bastion_user                    = "${var.bastion_user}"
  timezone                        = "${var.timezone}"
  user_data                       = "${data.template_file.bootstrap_keepalived.rendered}"
}


# Create Web Tier nodes
module "create_web" {
  source                          = "./modules/compute"
  compartment_ocid                = "${var.compartment_ocid}"
  AD                              = "${local.ADs}"
  fault_domain                    = "${local.fds}"
  compute_subnet                  = "${local.private_subnets}"
  compute_instance_count          = "${var.web_instance_count}"
  compute_hostname_prefix         = "${var.web_hostname_prefix}-${substr(var.region, 3, 3)}"
  compute_boot_volume_size_in_gb  = "${var.compute_boot_volume_size_in_gb}"
  compute_block_volume_size_in_gb = "0"
  compute_bv_mount_path           = ""
  compute_assign_public_ip        = "false"
  compute_image                   = "${var.instance_image_ocid[var.region]}"
  compute_instance_shape          = "${var.web_instance_shape}"
  compute_instance_user           = "${var.compute_instance_user}"
  compute_ssh_public_key          = "${var.ssh_public_key}"
  compute_ssh_private_key         = "${var.ssh_private_key}"
  bastion_ssh_private_key         = "${var.ssh_private_key}"
  bastion_public_ip               = "${module.create_bastion.ComputePublicIPs.0}"
  nsgs                            = "${list(oci_core_network_security_group.keepalived_nsg.id)}"
  bastion_user                    = "${var.bastion_user}"
  timezone                        = "${var.timezone}"
  user_data                       = "${data.template_file.bootstrap_web.rendered}"
}


# Create NSGs
resource "oci_core_network_security_group" "bastion_nsg" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${var.vcn_id}"
  display_name   = "BastionNSG"
}

resource "oci_core_network_security_group" "keepalived_nsg" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${var.vcn_id}"
  display_name   = "KeepalivedNSG"
}

# Create NSG Rules
resource "oci_core_network_security_group_security_rule" "keepalived_nsg_rule_1" {
  network_security_group_id = "${oci_core_network_security_group.keepalived_nsg.id}"
  direction                 = "EGRESS"
  protocol                  = "all"
  destination_type          = "CIDR_BLOCK"
  destination               = "0.0.0.0/0"
  stateless                 = false
}

resource "oci_core_network_security_group_security_rule" "keepalived_nsg_rule_2" {
  network_security_group_id = "${oci_core_network_security_group.keepalived_nsg.id}"
  protocol                  = "6"
  direction                 = "INGRESS"
  source_type               = "CIDR_BLOCK"
  source                    = "0.0.0.0/0"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_network_security_group_security_rule" "keepalived_nsg_rule_3" {
  network_security_group_id = "${oci_core_network_security_group.keepalived_nsg.id}"
  description               = "Allow traffic from bastion NSG"
  protocol                  = "all"
  direction                 = "INGRESS"
  source_type               = "NETWORK_SECURITY_GROUP"
  source                    = "${oci_core_network_security_group.bastion_nsg.id}"
  stateless                 = false
}

resource "oci_core_network_security_group_security_rule" "keepalived_nsg_rule_4" {
  network_security_group_id = "${oci_core_network_security_group.keepalived_nsg.id}"
  protocol                  = "6"
  direction                 = "INGRESS"
  source_type               = "CIDR_BLOCK"
  source                    = "0.0.0.0/0"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = "80"
      max = "80"
    }
  }
}

resource "oci_core_network_security_group_security_rule" "keepalived_nsg_rule_5" {
  network_security_group_id = "${oci_core_network_security_group.keepalived_nsg.id}"
  protocol                  = "6"
  direction                 = "INGRESS"
  source_type               = "CIDR_BLOCK"
  source                    = "0.0.0.0/0"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = "443"
      max = "443"
    }
  }
}

resource "oci_core_network_security_group_security_rule" "keepalived_nsg_rule_6" {
  network_security_group_id = "${oci_core_network_security_group.keepalived_nsg.id}"
  protocol                  = "${local.vrrp_protocol}"
  direction                 = "INGRESS"
  source_type               = "CIDR_BLOCK"
  source                    = "0.0.0.0/0"
  stateless                 = false
}

resource "oci_core_network_security_group_security_rule" "bastion_nsg_rule_1" {
  network_security_group_id = "${oci_core_network_security_group.bastion_nsg.id}"
  direction                 = "EGRESS"
  protocol                  = "all"
  destination_type          = "CIDR_BLOCK"
  destination               = "0.0.0.0/0"
  stateless                 = false
}

resource "oci_core_network_security_group_security_rule" "bastion_nsg_rule_2" {
  network_security_group_id = "${oci_core_network_security_group.bastion_nsg.id}"
  protocol                  = "6"
  direction                 = "INGRESS"
  source_type               = "CIDR_BLOCK"
  source                    = "0.0.0.0/0"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_network_security_group_security_rule" "bastion_nsg_rule_3" {
  network_security_group_id = "${oci_core_network_security_group.bastion_nsg.id}"
  description               = "Allow all traffic from Keepalived NSG"
  protocol                  = "6"
  direction                 = "INGRESS"
  source_type               = "NETWORK_SECURITY_GROUP"
  source                    = "${oci_core_network_security_group.keepalived_nsg.id}"
  stateless                 = false
}

resource "oci_core_network_security_group_security_rule" "bastion_nsg_rule_4" {
  network_security_group_id = "${oci_core_network_security_group.bastion_nsg.id}"
  protocol                  = "6"
  direction                 = "INGRESS"
  source_type               = "CIDR_BLOCK"
  source                    = "0.0.0.0/0"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "bastion_nsg_rule_5" {
  network_security_group_id = "${oci_core_network_security_group.bastion_nsg.id}"
  protocol                  = "6"
  direction                 = "INGRESS"
  source_type               = "CIDR_BLOCK"
  source                    = "0.0.0.0/0"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}
