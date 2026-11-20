resource "aws_s3_bucket" "this" {
  #checkov:skip=CKV_AWS_145:ALB delivery needs SSE-S3; archives use default encryption and restricted IAM access.
  #checkov:skip=CKV_AWS_144:Regional recovery is intentional; no cross-region transfer of this archive.
  #checkov:skip=CKV_AWS_18:Archive access is restricted by IAM; a logging bucket for this bucket is outside this workload.
  #checkov:skip=CKV2_AWS_62:Object notifications are not needed for a private retention archive.
  bucket        = var.name
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

#trivy:ignore:AWS-0132 ALB access log delivery requires SSE-S3; the archives use SSE-S3 with restricted access.
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "archive-retention"
    status = "Enabled"

    filter {}

    expiration {
      days = var.retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  rule {
    id     = "remove-expired-markers"
    status = "Enabled"
    filter {}

    expiration {
      expired_object_delete_marker = true
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}
