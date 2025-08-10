output "record_name" {
  value = aws_route53_record.rds_dns.name
}

output "record_type" {
  value = aws_route53_record.rds_dns.type
}

output "record_id" {
  value = aws_route53_record.rds_dns.id
}