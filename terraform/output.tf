# Ec2 IP
output "ec2_public_ip" {
    description = "The public IP address of the EC2 instance"
    value = aws_eip.ec2_eip[0].public_ip
    depends_on = [aws_eip.ec2_eip]
}
# Ec2 DNS
output "ec2_public_dns" {
    description = "The public DNS name of the EC2 instance"
    value = aws_eip.ec2_eip[0].public_dns
    depends_on = [aws_eip.ec2_eip]
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

