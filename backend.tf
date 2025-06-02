terraform {
  required_version = ">= 1.12.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.99.1"
    }
  }

  backend "s3" {
    bucket = "demo-alb-bucket-2"
    key    = "terraform.tftstate"
    region = "ca-central-1"
  }
}