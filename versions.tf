terraform {
  required_version = ">= 0.13.1"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.50"
    }
  }
}
