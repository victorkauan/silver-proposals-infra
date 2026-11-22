# The bootstrap stores its own state in the bucket it creates. The first run uses local state; see
# docs/runbooks/terraform-state-bootstrap.md for the one-time migration.
terraform {
  backend "s3" {
    bucket       = "silversoft-silver-proposals-tfstate-v2"
    key          = "bootstrap/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}
