output "vm_ips" {
  value = [
    for vm in proxmox_virtual_environment_vm.ubuntu_vm :
    [for ipv4 in vm.initialization[0].ip_config[0].ipv4 : ipv4.address]
  ]
  description = "List of IP addresses of the created VMs"
}