output "dns" {
  value = aws_route53_record.foo.fqdn
}