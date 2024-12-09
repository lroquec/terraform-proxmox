resource "proxmox_virtual_environment_vm" "k8s-servers" {
  count     = 1
  vm_id     = "80${count.index + 1}"
  name      = "kubeadm-vm-${count.index + 1}"
  node_name = var.proxmox_host
  tags      = ["terraform", "k8s"]

  agent {
    enabled = true
  }

  #   clone {
  #     vm_id = var.template_id
  #     full  = true
  #   }

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
    interface         = "ide2"
    type              = "nocloud"
    user_data_file_id = proxmox_virtual_environment_file.user_data_cloud_config.id
    ip_config {
      ipv4 {
        address = "192.168.5.19${count.index + 1}/24"
        gateway = "192.168.4.1"
      }
    }

    dns {
      servers = ["1.1.1.1"]
    }

    user_account {
      username = var.username
      keys     = [var.ssh_key]
    }

  }

  lifecycle {
    ignore_changes = [initialization["user_account"], ]
  }
}

resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "pve"
  url          = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
}

resource "proxmox_virtual_environment_file" "user_data_cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "pve"

  source_raw {
    data = <<-EOF
      #cloud-config
      users:
      - name: laura
         gecos: Laura
         shell: /bin/bash
         sudo: ALL=(ALL) NOPASSWD:ALL
         lock_passwd: false
      
      chpasswd:
      expire: true

      preserve_hostname: false
      manage_etc_hosts: true

      runcmd:
      - rm -f /etc/machine-id
      - rm -f /var/lib/dbus/machine-id
      - systemd-machine-id-setup
      - rm -f /etc/ssh/ssh_host_*
      - dpkg-reconfigure openssh-server
      - apt update
      - echo "done" > /tmp/cloud-config.done
    EOF

    file_name = "user-data.yml"
  }
}