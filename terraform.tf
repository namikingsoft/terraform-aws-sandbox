provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region = "${var.aws_default_region}"
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.1.0.0/16"
  instance_tenancy = "default"
  enable_dns_support = "true"
  enable_dns_hostnames = "false"
  tags {
    Name = "my_vpc"
  }
}

resource "aws_internet_gateway" "my_gateway" {
  vpc_id = "${aws_vpc.my_vpc.id}"
}

resource "aws_subnet" "public_a" {
  vpc_id = "${aws_vpc.my_vpc.id}"
  cidr_block = "10.1.1.0/24"
  availability_zone = "ap-northeast-1a"
}

resource "aws_route_table" "public_route" {
  vpc_id = "${aws_vpc.my_vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.my_gateway.id}"
  }
}

resource "aws_route_table_association" "public_a_association" {
  subnet_id = "${aws_subnet.public_a.id}"
  route_table_id = "${aws_route_table.public_route.id}"
}

resource "aws_security_group" "my_security" {
  name = "my_security"
  description = "Allow SSH inbound traffic"
  vpc_id = "${aws_vpc.my_vpc.id}"
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

resource "aws_key_pair" "my_key_pair" {
  key_name = "my_key_pair"
  public_key = "${var.aws_public_key}"
}

resource "aws_instance" "my_instance" {
  ami = "ami-a21529cc"
  instance_type = "t2.micro"
  key_name = "${aws_key_pair.my_key_pair.key_name}"
  vpc_security_group_ids = [
    "${aws_security_group.my_security.id}"
  ]
  subnet_id = "${aws_subnet.public_a.id}"
  associate_public_ip_address = "true"
  root_block_device = {
    volume_type = "gp2"
    volume_size = "8"
  }
}

output "public ip of my_instance" {
  value = "${aws_instance.my_instance.public_ip}"
}
