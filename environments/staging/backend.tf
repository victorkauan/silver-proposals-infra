terraform {
  backend "s3" {
    bucket       = "silversoft-silver-proposals-tfstate"
    key          = "staging/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
