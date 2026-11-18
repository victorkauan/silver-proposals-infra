output "bucket_name" {
  description = "Bucket that receives the build (frontend deploy target)."
  value       = aws_s3_bucket.site.id
}

output "bucket_arn" {
  description = "ARN of the build bucket, for deploy permissions."
  value       = aws_s3_bucket.site.arn
}

output "distribution_id" {
  description = "CloudFront distribution to invalidate after a deploy."
  value       = aws_cloudfront_distribution.site.id
}

output "distribution_arn" {
  description = "ARN of the CloudFront distribution, for invalidation permissions."
  value       = aws_cloudfront_distribution.site.arn
}

output "url" {
  description = "Public URL of the app."
  value       = "https://${var.host_name}"
}
