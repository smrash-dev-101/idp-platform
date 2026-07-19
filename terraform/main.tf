
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
