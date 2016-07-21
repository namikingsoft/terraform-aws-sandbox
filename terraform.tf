provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region = "${var.aws_default_region}"
}

resource "aws_key_pair" "my_key_pair" {
  key_name = "my_key_pair"
  public_key = "${var.aws_public_key}"
}

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_vpc" "vpc1" {
  cidr_block = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_support = "true"
  enable_dns_hostnames = "false"
  tags {
    Name = "vpc1"
  }
}

resource "aws_internet_gateway" "vpc1_gateway" {
  vpc_id = "${aws_vpc.vpc1.id}"
}

resource "aws_nat_gateway" "vpc1_nat_public_a" {
  allocation_id = "${aws_eip.nat.id}"
  subnet_id = "${aws_subnet.vpc1_public_a.id}"
  depends_on = ["aws_internet_gateway.vpc1_gateway"]
}

resource "aws_subnet" "vpc1_public_a" {
  vpc_id = "${aws_vpc.vpc1.id}"
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-northeast-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "vpc1_public_c" {
  vpc_id = "${aws_vpc.vpc1.id}"
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-northeast-1c"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "vpc1_private_a" {
  vpc_id = "${aws_vpc.vpc1.id}"
  cidr_block = "192.168.10.0/24"
  availability_zone = "ap-northeast-1a"
  map_public_ip_on_launch = false
}

resource "aws_subnet" "vpc1_private_c" {
  vpc_id = "${aws_vpc.vpc1.id}"
  cidr_block = "192.168.11.0/24"
  availability_zone = "ap-northeast-1c"
  map_public_ip_on_launch = false
}

resource "aws_route_table" "vpc1_public_route" {
  vpc_id = "${aws_vpc.vpc1.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.vpc1_gateway.id}"
  }
}

resource "aws_route_table" "vpc1_private_route" {
  vpc_id = "${aws_vpc.vpc1.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.vpc1_nat_public_a.id}"
  }
}

resource "aws_route_table_association" "vpc1_route_public_a_association" {
  subnet_id = "${aws_subnet.vpc1_public_a.id}"
  route_table_id = "${aws_route_table.vpc1_public_route.id}"
}

resource "aws_route_table_association" "vpc1_route_public_c_association" {
  subnet_id = "${aws_subnet.vpc1_public_c.id}"
  route_table_id = "${aws_route_table.vpc1_public_route.id}"
}

resource "aws_route_table_association" "vpc1_route_private_a_association" {
  subnet_id = "${aws_subnet.vpc1_private_a.id}"
  route_table_id = "${aws_route_table.vpc1_private_route.id}"
}

resource "aws_route_table_association" "vpc1_route_private_c_association" {
  subnet_id = "${aws_subnet.vpc1_private_c.id}"
  route_table_id = "${aws_route_table.vpc1_private_route.id}"
}

resource "aws_security_group" "vpc1_security_allow_all" {
  name = "vpc1_security_allow_all"
  vpc_id = "${aws_vpc.vpc1.id}"
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    self = true
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "vpc1_security_allow_ssh" {
  name = "vpc1_security_allow_ssh"
  vpc_id = "${aws_vpc.vpc1.id}"
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "vpc1_security_allow_http" {
  name = "vpc1_security_allow_http"
  vpc_id = "${aws_vpc.vpc1.id}"
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "bastion" {
  ami = "ami-a21529cc"
  instance_type = "t2.micro"
  key_name = "${aws_key_pair.my_key_pair.key_name}"
  vpc_security_group_ids = [
    "${aws_security_group.vpc1_security_allow_ssh.id}",
    "${aws_security_group.vpc1_security_allow_all.id}"
  ]
  subnet_id = "${aws_subnet.vpc1_public_a.id}"
  associate_public_ip_address = "true"
  root_block_device = {
    volume_type = "gp2"
    volume_size = "8"
  }
}

resource "aws_instance" "httpd_a" {
  ami = "ami-a21529cc"
  instance_type = "t2.micro"
  key_name = "${aws_key_pair.my_key_pair.key_name}"
  vpc_security_group_ids = [
    "${aws_security_group.vpc1_security_allow_all.id}",
  ]
  subnet_id = "${aws_subnet.vpc1_private_a.id}"
  associate_public_ip_address = false
  private_ip = "192.168.10.10"
  root_block_device = {
    volume_type = "gp2"
    volume_size = "8"
  }
}

resource "aws_instance" "httpd_c" {
  ami = "ami-a21529cc"
  instance_type = "t2.micro"
  key_name = "${aws_key_pair.my_key_pair.key_name}"
  vpc_security_group_ids = [
    "${aws_security_group.vpc1_security_allow_all.id}",
  ]
  subnet_id = "${aws_subnet.vpc1_private_c.id}"
  associate_public_ip_address = false
  private_ip = "192.168.11.10"
  root_block_device = {
    volume_type = "gp2"
    volume_size = "8"
  }
}

resource "aws_elb" "httpd_elb" {
  name = "instance-elb"
  subnets = [
    "${aws_subnet.vpc1_private_a.id}",
    "${aws_subnet.vpc1_private_c.id}",
  ]
  security_groups = [
    "${aws_security_group.vpc1_security_allow_http.id}",
    "${aws_security_group.vpc1_security_allow_all.id}",
  ]
  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 5
    target = "HTTP:80/"
    interval = 30
  }
  instances = [
    "${aws_instance.httpd_a.id}",
    "${aws_instance.httpd_c.id}",
  ]
  cross_zone_load_balancing = true
  connection_draining = true
  connection_draining_timeout = 400
}

output "public ip of bastion" {
  value = "${aws_instance.bastion.public_ip}"
}
