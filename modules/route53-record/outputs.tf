output "record_name" {
  value = aws_route53_record.this.name
}

output "record_type" {
  value = aws_route53_record.this.type
}

output "record_id" {
  value = aws_route53_record.this.id
}