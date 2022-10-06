output "deploy_id" {
    description = "The ID of the deployment"
    value = random_string.deploy_id.result
    depends_on = [random_string.deploy_id]
}
# Ec2 IP
output "ec2_public_ip" {
    description = "The public IP address of the EC2 instance"
    value = aws_eip.ec2[0].public_ip
    depends_on = [aws_eip.ec2]
}
# Ec2 DNS
output "ec2_public_dns" {
    description = "The public DNS name of the EC2 instance"
    value = aws_eip.ec2[0].public_dns
    depends_on = [aws_eip.ec2]
}
# RDS Endpoint
output "rds_endpoint" {
    description = "The RDS endpoint"
    value = aws_db_instance.rds.endpoint
    depends_on = [aws_db_instance.rds]
}
# RDS Port
output "rds_port" {
    description = "The RDS port"
    value = aws_db_instance.rds.port
    depends_on = [aws_db_instance.rds]
}
# Ec2 Private Key
output "ec2_private_key" {
    description = "The private key of the EC2 instance"
    value = tls_private_key.ec2.private_key_pem
    depends_on = [tls_private_key.ec2]
    sensitive = true
}
