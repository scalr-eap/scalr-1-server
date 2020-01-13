terraform {
  backend "remote" {
    hostname = "my.scalr.com"
    organization = "org-sfgari365m7sck0"
    workspaces {
      name = "scalr-1-server"
    }
  }
}


locals {
  ssh_private_key_file = "./ssh/id_rsa"
  license_file         = "./license/license.json"
}

provider "aws" {
    region     = var.region
}

resource "random_string" "random" {
  length = 6
  special = false
  upper = false
  number = false
}
#---------------
# Process the license and SSH key
#
# License and SSH key must supplied by input variables when the template is used via Scalr Next-Gen Service Catalog because user has no mechanism to provide them via a file.
# With CLI runs (remote or local) user can provide the key and license in a file.
# File names are set in local values (./ssh/id_rsa and ./license/license.json)
# Variables are ssh_private_key and license which have default value of "FROM_FILE"
# Code below will write the contents of the variables to their respective files if they are not set to "FROM_FILE"

# SSH Key
# This inelegant code takes the SSH private key from the variable and turns it back into a properly formatted key with line breaks

resource "local_file" "ssh_key" {
  count    = var.ssh_private_key == "FROM_FILE" ? 0 : 1
  content  = var.ssh_private_key
  filename = "./ssh/temp_key"
}

resource "null_resource" "fix_key" {
  count      = var.ssh_private_key == "FROM_FILE" ? 0 : 1
  depends_on = [local_file.ssh_key]
  provisioner "local-exec" {
    command = "(HF=$(cat ./ssh/temp_key | cut -d' ' -f2-4);echo '-----BEGIN '$HF;cat ./ssh/temp_key | sed -e 's/--.*-- //' -e 's/--.*--//' | awk '{for (i = 1; i <= NF; i++) print $i}';echo '-----END '$HF) > ${local.ssh_private_key_file}"
  }
}

# license

resource "local_file" "license_file" {
  count      = var.license == "FROM_FILE" ? 0 : 1
  content    = var.license
  filename   = local.license_file
}

# Obtain the AMI for the region

data "aws_ami" "the_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

###############################
#
# Proxy Servers
#
# 1

resource "aws_instance" "scalr-server" {
  depends_on      = [null_resource.fix_key, local_file.license_file]
  ami             = "${data.aws_ami.the_ami.id}"
  instance_type   = var.instance_type
  key_name        = var.key_name
  vpc_security_group_ids = [ "${data.aws_security_group.default_sg.id}", "${aws_security_group.scalr_sg.id}"]
  subnet_id       = var.subnet

  tags = {
    Name = "${var.name_prefix}-scalr-server"
  }

  connection {
        host	= self.public_ip
        type     = "ssh"
        user     = "ubuntu"
        private_key = "${file(local.ssh_private_key_file)}"
        timeout  = "20m"
  }

  provisioner "file" {
        source = local.ssh_private_key_file
        destination = "~/.ssh/id_rsa"
  }

  provisioner "file" {
        source = local.license_file
        destination = "/var/tmp/license.json"
  }

  provisioner "file" {
      source = "./SCRIPTS/scalr_install.sh"
      destination = "/var/tmp/scalr_install.sh"
  }
}

resource "aws_ebs_volume" "scalr_vol" {
  availability_zone = "${aws_instance.scalr-server.availability_zone}"
  type = "gp2"
  size = 50
}

resource "aws_volume_attachment" "scalr_attach" {
  device_name = "/dev/sds"
  instance_id = "${aws_instance.scalr-server.id}"
  volume_id   = "${aws_ebs_volume.scalr_vol.id}"
}

resource "null_resource" "null_1" {
  depends_on = [aws_instance.scalr-server]

  connection {
        host	= aws_instance.scalr-server.public_ip
        type     = "ssh"
        user     = "ubuntu"
        private_key = "${file(local.ssh_private_key_file)}"
        timeout  = "20m"
  }

  provisioner "remote-exec" {
      inline = [
        "chmod +x /var/tmp/scalr_install.sh",
        "sudo /var/tmp/scalr_install.sh '${var.token}' ${aws_volume_attachment.scalr_attach.volume_id}",
      ]
  }
}

# Load Balancer
#

resource "aws_elb" "scalr_lb" {
  name               = "scalr-lb"

  subnets         = [var.subnet]
  security_groups = ["${data.aws_security_group.default_sg.id}", "${aws_security_group.scalr_sg.id}"]
  instances       = ["${aws_instance.scalr-server.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  listener {
    instance_port     = 5671
    instance_protocol = "http"
    lb_port           = 5671
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:80"
    interval            = 30
  }

  tags = {
    Name = "${var.name_prefix}-scalr-elb-${random_string.random.result}"
  }
}

resource "null_resource" "configure" {
  depends_on = [aws_elb.scalr_lb, aws_instance.scalr-server, null_resource.null_1]

  connection {
        host	= aws_instance.scalr-server.public_ip
        type     = "ssh"
        user     = "ubuntu"
        private_key = "${file(local.ssh_private_key_file)}"
        timeout  = "20m"
  }

  provisioner "file" {
      source = "./SCRIPTS/configure.sh"
      destination = "/var/tmp/configure.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /var/tmp/configure.sh",
      "sudo /var/tmp/configure.sh ${aws_elb.scalr_lb.dns_name}",
    ]
  }
}

resource "null_resource" "get_info" {

  depends_on = [null_resource.configure]
  connection {
        host	= aws_instance.scalr-server.public_ip
        type     = "ssh"
        user     = "ubuntu"
        private_key = "${file(local.ssh_private_key_file)}"
        timeout  = "20m"
  }

  provisioner "file" {
      source = "./SCRIPTS/get_pass.sh"
      destination = "/var/tmp/get_pass.sh"

  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x /var/tmp/get_pass.sh",
      "sudo /var/tmp/get_pass.sh",
    ]
  }
}

output "dns_name" {
  value = aws_elb.scalr_lb.dns_name
}
output "scalr_server_public_ip" {
  value = aws_instance.scalr-server.public_ip
}
output "scalr_server_private_ip" {
  value = aws_instance.scalr-server.private_ip
}
