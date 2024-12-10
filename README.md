# Proxmox Ubuntu VM Provisioning with Terraform

## Description

This Terraform code provisions multiple Ubuntu virtual machines (VMs) in a Proxmox environment, leveraging cloud-init for initial configuration and setting up SSH access for the user.

## Features

- Provisions three Ubuntu VMs with consecutive IDs and IP addresses.
- Utilizes cloud-init configuration (`user-data.yml`) to:
  - Create a user named "laura" with sudo privileges.
  - Inject the local SSH public key for passwordless access.
  - Update and install essential packages (qemu-guest-agent).
  - Set up a static IP, gateway, and DNS server.
- Automatically injects the local SSH public key (`~/.ssh/id_ed25519.pub`) into the VMs for secure access.
- After creating the VMs, automatically adds them to the `~/.ssh/known_hosts` file.
- Ignores changes to the `user_account` section in the cloud-init configuration to avoid issues with user credentials after provisioning.

## Resources

### `proxmox_virtual_environment_vm` (ubuntu_vm)

This resource creates three Ubuntu VMs with the following configurations:

- `vm_id`: Consecutive IDs starting from 801, 802, and 803.
- `name`: VM names with the format "kubeadm-vm-1", "kubeadm-vm-2", and "kubeadm-vm-3".
- `node_name`: The Proxmox host node specified by the `var.proxmox_host` variable.
- `tags`: "terraform" and "k8s" tags.
- `agent`: Enables the Proxmox guest agent.
- `disk`: A 20 GB virtio0 disk, using the downloaded Ubuntu cloud image, with SSD and discard support.
- `network_device`: Configured to use the "vmbr0" bridge.
- `initialization`: Cloud-init configuration, IP address, gateway, and DNS server settings.
- `lifecycle`: Ignores changes to the `user_account` section for user credential management.

### `proxmox_virtual_environment_download_file` (ubuntu_cloud_image)

This resource downloads the Ubuntu 24.04 cloud image from the official Ubuntu repository to be used as the base image for the VMs.

### `proxmox_virtual_environment_file` (user_data_cloud_config)

This resource creates a cloud-init configuration file (`user-data.yml`) with the following settings:

- Creates a user named "laura" with sudo privileges and no password.
- Injects the local SSH public key for passwordless access.
- Configures various cloud-init settings, such as preserving the hostname and managing `/etc/hosts`.
- Runs commands during the initial setup, including updating packages, installing qemu-guest-agent, and generating new machine and SSH host keys.

### `data.local_file` (ssh_public_key)

This data source loads the local SSH public key (`~/.ssh/id_ed25519.pub`) to be injected into the VMs.

### `locals` (ssh_hosts)

This local value generates a list of IP addresses for the created VMs.

### `null_resource` (known_hosts)

This null resource runs a local-exec provisioner to update the `~/.ssh/known_hosts` file with the IP addresses of the newly created VMs.

## Usage

1. Ensure you have Terraform installed and configured for your Proxmox environment.
2. Clone this repository or copy the provided code.
3. Configure the `var.proxmox_host` variable with your Proxmox host name.
4. Run `terraform init` to initialize the Terraform working directory.
5. Run `terraform apply` to create the resources.
6. After the VMs are created, you can SSH into them using the "laura" user and the injected SSH key.
