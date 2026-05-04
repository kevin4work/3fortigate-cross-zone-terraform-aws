
output "FGT1PublicIP" {
  value = aws_eip.FGTPublicIP.public_ip
}


output "FGT2PublicIP" {
  value = aws_eip.FGTPublicIP2.public_ip
}

output "FGT3PublicIP" {
  value = aws_eip.FGTPublicIP3.public_ip
}


output "Username" {
  value = "admin"
}

output "Password_for_FGT1" {
  value = aws_instance.fgtvm.id
}

output "Password_for_FGT2" {
  value = aws_instance.fgtvm2.id
}

output "Password_for_FGT3" {
  value = aws_instance.fgtvm3.id
}

output "LoadBalancerPrivateIPAZ1" {
  value = data.aws_network_interface.vpcendpointip.private_ip
}

output "LoadBalancerPrivateIPAZ2" {
  value = data.aws_network_interface.vpcendpointipaz2.private_ip
}

output "LoadBalancerPrivateIPAZ3" {
  value = data.aws_network_interface.vpcendpointipaz3.private_ip
}

output "CustomerVPC" {
  value = var.deploy_customer_vpc ? aws_vpc.customer-vpc[0].id : null
}

output "FGTVPC" {
  value = aws_vpc.fgtvm-vpc.id
}

output "SyslogProxyPrivateIP" {
  value       = var.deploy_syslog_proxy ? aws_instance.syslog_proxy[0].private_ip : null
  description = "Private IP of syslog proxy (configure FortiGates to send logs here)"
}

output "SyslogProxyInstanceId" {
  value       = var.deploy_syslog_proxy ? aws_instance.syslog_proxy[0].id : null
  description = "Instance ID of syslog proxy"
}

output "SyslogProxyUserData" {
  value       = local.syslog_proxy_user_data
  description = "Rendered user_data script for the syslog proxy VM"
  sensitive   = true
}
