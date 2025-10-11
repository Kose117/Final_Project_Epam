output "bucket_name" {
  value       = aws_s3_bucket.tf_state.bucket
  description = "Bucket S3 creado para el state remoto"
}
