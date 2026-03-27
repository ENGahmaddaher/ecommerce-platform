output "s3_bucket_id" { value = aws_s3_bucket.static.id }
output "s3_bucket_arn" { value = aws_s3_bucket.static.arn }
output "cloudfront_distribution_id" { value = aws_cloudfront_distribution.static.id }
output "cloudfront_domain_name" { value = aws_cloudfront_distribution.static.domain_name }
output "cloudfront_hosted_zone_id" { value = "Z2FDTNDATAQYW2" }  # ثابت لـ CloudFront
