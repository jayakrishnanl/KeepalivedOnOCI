# Get list of Availability Domains
data "oci_identity_availability_domains" "ADs" {
  compartment_id = "${var.tenancy_ocid}"
}

# Get list of Fault Domains
data "oci_identity_fault_domains" "fds" {
  availability_domain = "${element(local.ADs, 0)}"
  compartment_id      = "${var.compartment_ocid}"
}

# Find the Public and Private Subnets in the VCN specified

data "oci_core_subnets" "private-regional" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${var.vcn_id}"

  filter {
    name   = "freeform_tags.${var.RegionalPrivateKey}"
    values = ["${var.RegionalPrivateValue}"]
  }
}

data "oci_core_subnets" "public-regional" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${var.vcn_id}"

  filter {
    name   = "freeform_tags.${var.RegionalPublicKey}"
    values = ["${var.RegionalPublicValue}"]
  }
}


# Get a list of VNIC attachments on the Compute instances
data "oci_core_vnic_attachments" "InstanceVnicAttachments" {
  count               = "${length(local.ADs)}"
  availability_domain = "${element(local.ADs, count.index)}"
  compartment_id      = "${var.compartment_ocid}"
  instance_id         = "${element(module.create_keepalived.ComputeOcids, count.index)}"
}

locals {
  vnics = "${flatten(concat(data.oci_core_vnic_attachments.InstanceVnicAttachments.*.vnic_attachments))}"
}

# Get OCIDs of the Vnics
data "template_file" "vnic_ocids" {
  template = "$${name}"
  count    = "${var.keepalived_instance_count}"

  vars = {
    name = "${lookup(local.vnics[count.index], "vnic_id")}"
  }
}

# Render inputs for HAProxy configuration file
data "template_file" "hapcfg" {
  template = "${file("${path.module}/userdata/hap.cfg.tpl")}"

  vars = {
    web_ip = "${element(module.create_web.ComputePrivateIPs, 0)}"
  }
}

data "template_file" "kplcfg" {
  count    = "${var.keepalived_instance_count}"
  template = "${file("${path.module}/userdata/keepalived.conf.tpl")}"

  vars = {
    ip1 = "${element(module.create_keepalived.ComputePrivateIPs, count.index)}"
    ip2 = "${element(module.create_keepalived.ComputePrivateIPs, count.index + 1)}"
    ip3 = "${element(module.create_keepalived.ComputePrivateIPs, count.index + 2)}"
  }
}

data "template_file" "failover" {
  count    = "${var.keepalived_instance_count}"
  template = "${file("${path.module}/userdata/ip_failover.sh.tpl")}"

  vars = {
    VNIC = "${element(data.template_file.vnic_ocids.*.rendered, count.index)}"
    VIP  = "${var.VIP}"
  }
}

data "template_file" "iprelease" {
  count    = "${var.keepalived_instance_count}"
  template = "${file("${path.module}/userdata/ip_release.sh.tpl")}"

  vars = {
    VIP = "${var.VIP}"
  }
}

data "template_file" "bootstrap_keepalived" {
  template = "${file("${path.module}/userdata/bootstrap_keepalived.tpl")}"

  vars = {
    timezone = "${var.timezone}"
  }
}

