terraform {
  backend "s3" {
    bucket       = "silversoft-silver-proposals-tfstate-v2"
    key          = "shared/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}
