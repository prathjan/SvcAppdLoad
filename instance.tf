#get the data from the app VM WS
data "terraform_remote_state" "appvm" {
  backend = "remote"
  config = {
    organization = "Lab14"
    workspaces = {
      name = var.appvmwsname
    }
  }
}

data "terraform_remote_state" "global" {
  backend = "remote"
  config = {
    organization = "Lab14"
    workspaces = {
      name = var.globalwsname
    }
  }
}


variable "appvmwsname" {
  type = string
}

variable "globalwsname" {
  type = string
}

variable "trigcount" {
  type = string
}


# Configure the VMware vSphere Provider
provider "vsphere" {
  user           = local.vsphere_user
  password       = local.vsphere_password
  vsphere_server = local.vsphere_server

  # If you have a self-signed cert
  allow_unverified_ssl = true
}


data "vsphere_datacenter" "dc" {
  name = local.datacenter
}

data "vsphere_datastore" "datastore" {
  name          = local.datastore_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  name          = local.resource_pool
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = local.network_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = local.template_name
  datacenter_id = data.vsphere_datacenter.dc.id
}


resource "random_string" "folder_name_prefix" {
  length    = 10
  min_lower = 10
  special   = false
  lower     = true

}


resource "vsphere_folder" "vm_folder" {
  path          =  "${local.vm_folder}-${random_string.folder_name_prefix.id}"
  type          = "vm"
  datacenter_id = data.vsphere_datacenter.dc.id
}


resource "vsphere_virtual_machine" "vm_deploy" {
  name             = "${local.vm_prefix}-${random_string.folder_name_prefix.id}-testvm"
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = vsphere_folder.vm_folder.path
  firmware = "bios"


  num_cpus = local.vm_cpu
  memory   = local.vm_memory
  guest_id = data.vsphere_virtual_machine.template.guest_id

  scsi_type = data.vsphere_virtual_machine.template.scsi_type

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = data.vsphere_virtual_machine.template.disks.0.size
    eagerly_scrub    = data.vsphere_virtual_machine.template.disks.0.eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.template.disks.0.thin_provisioned
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
    customize {
      linux_options {
        host_name = "${local.vm_prefix}-${random_string.folder_name_prefix.id}-testvm"
        domain    = local.vm_domain
      }
      network_interface {}
    }
  }

}


resource "null_resource" "vm_node_init" {
  triggers = {
	trig = var.trigcount
  }
  provisioner "file" {
    source = "scripts/"
    destination = "/tmp/"
    connection {
      type = "ssh"
      host = "${vsphere_virtual_machine.vm_deploy.default_ip_address}"
      user = "root"
      password = "${local.root_password}"
      port = "22"
      agent = false
    }
  }

  provisioner "remote-exec" {
    inline = [
        "chmod +x /tmp/gentraffic.sh",
        "/tmp/gentraffic.sh ${local.appvmip} ${local.appport}"
    ]
    connection {
      type = "ssh"
      host = "${vsphere_virtual_machine.vm_deploy.default_ip_address}" 
      user = "root"
      password = "${local.root_password}"
      port = "22"
      agent = false
    }
  }

}


locals {
  appvmip = data.terraform_remote_state.appvm.outputs.vm_ip[0]
  appport = data.terraform_remote_state.global.outputs.appport
  vsphere_user = yamldecode(data.terraform_remote_state.global.outputs.vsphere_user)
  vsphere_password = yamldecode(data.terraform_remote_state.global.outputs.vsphere_password)
  vsphere_server = yamldecode(data.terraform_remote_state.global.outputs.vsphere_server)
  root_password = yamldecode(data.terraform_remote_state.global.outputs.root_password)
  datacenter = yamldecode(data.terraform_remote_state.global.outputs.datacenter)
  datastore_name = yamldecode(data.terraform_remote_state.global.outputs.datastore_name)
  resource_pool = yamldecode(data.terraform_remote_state.global.outputs.resource_pool)
  network_name = yamldecode(data.terraform_remote_state.global.outputs.network_name)
  template_name = yamldecode(data.terraform_remote_state.global.outputs.template_name)
  vm_folder = yamldecode(data.terraform_remote_state.global.outputs.vm_folder)
  vm_prefix = yamldecode(data.terraform_remote_state.global.outputs.vm_prefix)
  vm_cpu = yamldecode(data.terraform_remote_state.global.outputs.vm_cpu)
  vm_memory = yamldecode(data.terraform_remote_state.global.outputs.vm_memory)
  vm_domain = yamldecode(data.terraform_remote_state.global.outputs.vm_domain)
  vm_count = yamldecode(data.terraform_remote_state.global.outputs.vm_count)
}
