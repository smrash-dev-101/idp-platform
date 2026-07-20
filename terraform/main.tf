
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "idp-platform-tfstate-sn"
    key            = "idp-platform/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "idp-platform-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}
resource "aws_key_pair" "idp_key" {
  key_name   = "idp-platform-key"
  public_key = file("~/.ssh/idp-platform-key.pub")
}
resource "aws_security_group" "idp_sg" {
  name        = "idp-platform-sg"
  description = "Allows SSH access for IDP platform instances"

  ingress {
    description = "SSH"
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
  tags = {
    Name    = "idp-platform-sg"
    project = "idp-platform"

  }
}
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}
resource "aws_instance" "idp_example" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.idp_key.key_name
  vpc_security_group_ids = [aws_security_group.idp_sg.id]

  tags = {
    Name        = "idp-platform-dev"
    team        = "payments-team"
    environment = "dev"
    cost-center = "payments"
  }
  lifecycle {
    postcondition {
      condition     = contains(keys(self.tags), "team") && contains(keys(self.tags), "environment") && contains(keys(self.tags), "cost-center")
      error_message = "Instance must be tagged with 'team' , 'environemnt', and 'cost-center'."
    }
  }
}
