resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
  count     = var.vm_count
  vm_id     = "80${count.index + 1}"
  name      = "vm-${count.index + 1}"
  node_name = var.proxmox_host
  tags      = ["terraform", "k8s"]

  agent {
    enabled = true
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
  }

  # keep the first disk as boot disk
  disk {
    datastore_id = "local-lvm"
    interface    = "virtio0"
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    size         = 20
    iothread     = true
    ssd          = true
    discard      = "on"
  }

  network_device {
    bridge = "vmbr0"
  }

  # Cloud-Init configuration
  initialization {
    user_data_file_id = proxmox_virtual_environment_file.user_data_cloud_config.id
    ip_config {
      ipv4 {
        address = "192.168.5.19${count.index + 1}/22"
        gateway = "192.168.4.1"
      }
    }

    dns {
      servers = ["1.1.1.1"]
    }

  }

  lifecycle {
    ignore_changes = [initialization["user_account"], ]
  }
}

resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = "hdd"
  node_name    = var.proxmox_host
  url          = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
}

resource "proxmox_virtual_environment_file" "user_data_cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_host

  source_raw {
    data = <<-EOF
      #cloud-config
      users:
      - name: laura
        groups:
          - sudo
        shell: /bin/bash
        sudo: ALL=(ALL) NOPASSWD:ALL
        lock_passwd: false
        ssh_authorized_keys: 
          - ${trimspace(data.local_file.ssh_public_key.content)}

      chpasswd:
      expire: false

      preserve_hostname: false
      manage_etc_hosts: true

      runcmd:
      - rm -f /etc/machine-id
      - rm -f /var/lib/dbus/machine-id
      - systemd-machine-id-setup
      - rm -f /etc/ssh/ssh_host_*
      - dpkg-reconfigure openssh-server
      - apt update
      - apt install qemu-guest-agent -y
      - systemctl enable --now qemu-guest-agent
      - echo "done" > /tmp/cloud-config.done
    EOF

    file_name = "user-data.yml"
  }
}

#Load local SSH key for injecting into VMs
data "local_file" "ssh_public_key" {
  filename = pathexpand("~/.ssh/id_ed25519.pub")
}

locals {
  ssh_hosts = flatten([
    for vm in proxmox_virtual_environment_vm.ubuntu_vm :
    [for ipv4 in vm.initialization[0].ip_config[0].ipv4 : ipv4.address]
  ])
}

#Add machines to known hosts after creating
resource "null_resource" "known_hosts" {

  provisioner "local-exec" {

    command     = <<EOT
      sleep 20;
      %{for host_ip in local.ssh_hosts}
        if ssh-keygen -F ${host_ip} > /dev/null; then
          ssh-keygen -R ${host_ip};
        fi
        ssh-keyscan -H ${host_ip} >> ~/.ssh/known_hosts || true;
      %{endfor~}
    EOT
    interpreter = ["/bin/bash", "-c"]

  }

}
