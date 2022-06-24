## Terraform configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.19.0"
    }
  }
}

provider "aws" {
  region                  = "us-east-1"
  shared_credentials_files = ["~/.aws/credentials"]
 # profile                 = "myprofile"
}

terraform {
  cloud {
    organization = "www-mclark"

    workspaces {
        name     = "Project_19"
    }
  }  
}