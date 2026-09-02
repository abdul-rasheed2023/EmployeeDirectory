terraform {
  required_version = ">= 1.11.0" # S3-native lockfile locking (use_lockfile) requires 1.11+

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.9"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.8"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
