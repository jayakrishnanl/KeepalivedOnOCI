resource "null_resource" "provision_Keepalived" {
  count = "${var.keepalived_instance_count}"

  connection {
    agent               = false
    timeout             = "30m"
    host                = "${element(module.create_keepalived.ComputePrivateIPs, count.index)}"
    user                = "${var.compute_instance_user}"
    private_key         = "${var.ssh_private_key}"
    bastion_host        = "${module.create_bastion.ComputePublicIPs[0]}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${var.ssh_private_key}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install -y python-oci-cli",
      "sudo yum -y install haproxy keepalived",
      "sudo firewall-offline-cmd  --zone=public --add-port=80/tcp",
      "sudo firewall-offline-cmd  --zone=public --add-port=443/tcp",
      "sudo /bin/systemctl restart firewalld",
      "sudo firewall-cmd --add-rich-rule='rule protocol value=\"vrrp\" accept' --permanent",
      "sudo firewall-cmd --reload",
      "sudo mv /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.orig",
      "sudo mv /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.orig",
    ]
  }
}

resource "null_resource" "provision_config_files" {
  depends_on = ["null_resource.provision_Keepalived"]
  count      = "${var.keepalived_instance_count}"

  connection {
    agent               = false
    timeout             = "30m"
    host                = "${element(module.create_keepalived.ComputePrivateIPs, count.index)}"
    user                = "${var.compute_instance_user}"
    private_key         = "${var.ssh_private_key}"
    bastion_host        = "${module.create_bastion.ComputePublicIPs[0]}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${var.ssh_private_key}"
  }

  provisioner "file" {
    content     = "${data.template_file.hapcfg.rendered}"
    destination = "/tmp/haproxy.cfg"
  }

  provisioner "file" {
    content     = "${element(data.template_file.kplcfg.*.rendered, count.index)}"
    destination = "/tmp/keepalived.conf"
  }

  provisioner "file" {
    content     = "${element(data.template_file.iprelease.*.rendered, count.index)}"
    destination = "/tmp/ip_release.sh"
  }

  provisioner "file" {
    content     = "${element(data.template_file.failover.*.rendered, count.index)}"
    destination = "/tmp/ip_failover.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo cp /tmp/haproxy.cfg /etc/haproxy/haproxy.cfg",
      "sudo cp /tmp/keepalived.conf /etc/keepalived/keepalived.conf",
      "sudo cp /tmp/ip_failover.sh /etc/keepalived/ip_failover.sh",
      "sudo cp /tmp/ip_release.sh /etc/keepalived/ip_release.sh",
      "sudo chmod +x /etc/keepalived/ip_failover.sh",
      "sudo chmod +x /etc/keepalived/ip_release.sh",
      "sudo systemctl enable haproxy",
      "sudo systemctl start haproxy",
      "sudo systemctl enable keepalived",
      "sudo systemctl start keepalived",
    ]
  }
}
