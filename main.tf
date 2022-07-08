terraform {
    backend "s3" {
      bucket = "codecool-sysadmin-tfstate"
      key    = "ec2-ansible-test/terraform.tfstate"
      region = "eu-central-1"
      dynamodb_table = "codecool-sysadmin-tfstate-ec2-ansible-test"
      profile = "cc-sysadmin-4"
    }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.21.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "eu-central-1"
  profile = "cc-sysadmin-4"
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content  = tls_private_key.this.private_key_pem
  filename = "key.pem"
  file_permission = "0600"
}

resource "aws_key_pair" "this" {
  key_name   = "ansible-test"
  public_key = tls_private_key.this.public_key_openssh
}

data "aws_vpc" "this" {
  default = true
}

resource "aws_security_group" "this" {
  name = "AllowSsh"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = data.aws_vpc.this.id

  tags = {
    Name = "AllowSsh"
  }
}

resource "aws_instance" "this" {
  count = 3

  ami                    = "ami-0a1ee2fb28fe05df3"
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.this.id]

  tags = {
    Name = "ansible-test-${count.index}"
  }
}

resource "local_file" "ansible_inventory" {
  content = templatefile("inventory.tftpl", {public_ips = aws_instance.this[*].public_ip})
  filename = "inventory.ini"
}
