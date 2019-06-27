variable "prefix" {	
	default = "TheNexus"
}

provider "azurerm" {
	version = "=1.30.1"
}

resource "azurerm_resource_group" "main" {
	name	= "${var.prefix}-resources-g"
	location= "uksouth"
}

resource "azurerm_virtual_network" "main" {
	name			= "${var.prefix}-network"
	address_space		= ["10.0.0.0/16"]
	location		= "${azurerm_resource_group.main.location}"
	resource_group_name	= "${azurerm_resource_group.main.name}"
}

resource "azurerm_subnet" "internal" {
	name			= "internal"
	resource_group_name	= "${azurerm_resource_group.main.name}"
	virtual_network_name	= "${azurerm_virtual_network.main.name}"
	address_prefix		= "10.0.2.0/24"
}

resource "azurerm_public_ip" "main" {
	name			= "pubIP"
	location		= "${azurerm_resource_group.main.location}"
	resource_group_name	= "${azurerm_resource_group.main.name}"
	allocation_method	= "Dynamic"
	domain_name_label 	= "nexus-${formatdate("DDhhmmss", timestamp())}"
}

resource "azurerm_network_security_group" "main" {
	name			= "${var.prefix}-nsg"
	location		= "${azurerm_resource_group.main.location}"
	resource_group_name	= "${azurerm_resource_group.main.name}"

	security_rule {
		name			= "SSH"
		priority		= "1001"
		direction		= "Inbound"
		access			= "Allow"
		protocol		= "Tcp"
		source_port_range	= "*"
		destination_port_range	= "22"
		source_address_prefix	= "*"
		destination_address_prefix= "*"
	}
}

resource "azurerm_network_interface" "main" {
	name			= "${var.prefix}-nic"
	location		= "${azurerm_resource_group.main.location}"
	resource_group_name	= "${azurerm_resource_group.main.name}"
	network_security_group_id = "${azurerm_network_security_group.main.id}"

	ip_configuration {
	  name			= "ipconfiguration"
	  subnet_id		= "${azurerm_subnet.internal.id}"
	  private_ip_address_allocation = "Dynamic"
		public_ip_address_id	= "${azurerm_public_ip.main.id}"
  }
	
}

resource "azurerm_virtual_machine" "main" {
	name			= "${var.prefix}-vm"
	location		= "${azurerm_resource_group.main.location}"
	resource_group_name	= "${azurerm_resource_group.main.name}"
	network_interface_ids	= ["${azurerm_network_interface.main.id}"]
	vm_size			= "Standard_DS1_v2"
	
	storage_image_reference {
		publisher 	= "Canonical"
		offer  		= "UbuntuServer"
		sku  		= "16.04-LTS"
		version 	= "latest"
	}
	storage_os_disk {
		name		= "maindisk"
		caching		= "ReadWrite"
		create_option	= "FromImage"
		managed_disk_type= "Standard_LRS"
	}
	os_profile {
		computer_name 	= "TheNexus"
		admin_username	= "deekay"
	}
	os_profile_linux_config {
		disable_password_authentication = true
		ssh_keys {
		path 		= "/home/deekay/.ssh/authorized_keys"
		key_data 	= file("~/.ssh/id_rsa.pub")
	  }
	}
	provisioner "remote-exec" {
	  inline = [
		"sudo apt update",
		"sudo apt install -y jq",
		"git clone -b dev --single-branch  https://github.com/DimitriosKan/Terraform-Deployment.git"
		
		]
	  connection {
		type = "ssh"
		user = "deekay"
		private_key = file("/home/nexus/.ssh/id_rsa")
		host = "${azurerm_public_ip.main.fqdn}"
	}
    }
}
