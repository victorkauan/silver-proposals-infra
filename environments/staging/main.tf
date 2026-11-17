provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "silver-proposals"
      Environment = "staging"
      ManagedBy   = "terraform"
    }
  }
}

provider "cloudflare" {}
