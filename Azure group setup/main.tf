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

# - - - Virtual network & Subnet - - -
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

# - - - IP configuration - - -
resource "azurerm_public_ip" "main" {
	name			= "pubIP-jenkins"
	location		= "${azurerm_resource_group.main.location}"
	resource_group_name	= "${azurerm_resource_group.main.name}"
	allocation_method	= "Dynamic"
	domain_name_label 	= "nexus-jenkins-${formatdate("DDhhmmss", timestamp())}"
}

resource "azurerm_public_ip" "slave" {
	name			= "pubIP-slave"
	location		= "${azurerm_resource_group.main.location}"
	resource_group_name	= "${azurerm_resource_group.main.name}"
	allocation_method	= "Dynamic"
	domain_name_label 	= "nexus-slave-${formatdate("DDhhmmss", timestamp())}"
}

resource "azurerm_public_ip" "pyserver" {
	name			= "pubIP-pyserver"
	location		= "${azurerm_resource_group.main.location}"
	resource_group_name	= "${azurerm_resource_group.main.name}"
	allocation_method	= "Dynamic"
	domain_name_label 	= "nexus-pyserver-${formatdate("DDhhmmss", timestamp())}"
}

# - - - NSG & Rules - - -
resource "azurerm_network_security_group" "main" {
	name			= "${var.prefix}-nsg"
	location		= "${azurerm_resource_group.main.location}"
	resource_group_name	= "${azurerm_resource_group.main.name}"

	security_rule {
		name			= "SSH"
		priority		= "100"
		direction		= "Inbound"
		access			= "Allow"
		protocol		= "Tcp"
		source_port_range	= "*"
		destination_port_range	= "22"
		source_address_prefix	= "*"
		destination_address_prefix= "*"
	}

	security_rule {
		name			= "HTTP"
		priority		= "200"
		direction		= "Inbound"
		access			= "Allow"
		protocol		= "Tcp"
		source_port_range	= "*"
		destination_port_range	= "8080"
		source_address_prefix	= "*"
		destination_address_prefix= "*"
	}
}

# - - - NIC setup - - -
resource "azurerm_network_interface" "main" {
	name			= "${var.prefix}-nic-jenkins"
	location		= "${azurerm_resource_group.main.location}"
	resource_group_name	= "${azurerm_resource_group.main.name}"
	network_security_group_id = "${azurerm_network_security_group.main.id}"

	ip_configuration {
	  name			= "ipconfig-jenkins"
	  subnet_id		= "${azurerm_subnet.internal.id}"
	  private_ip_address_allocation = "Dynamic"
	  public_ip_address_id	= "${azurerm_public_ip.main.id}"
  }
}

resource "azurerm_network_interface" "slave" {
	name			= "${var.prefix}-nic-slave"
	location		= "${azurerm_resource_group.main.location}"
	resource_group_name	= "${azurerm_resource_group.main.name}"
	network_security_group_id = "${azurerm_network_security_group.main.id}"

	ip_configuration {
	  name			= "ipconfig-slave"
	  subnet_id		= "${azurerm_subnet.internal.id}"
	  private_ip_address_allocation = "Dynamic"
	  public_ip_address_id	= "${azurerm_public_ip.slave.id}"
  }
}

resource "azurerm_network_interface" "pyserver" {
	name			= "${var.prefix}-nic-pyserver"
	location		= "${azurerm_resource_group.main.location}"
	resource_group_name	= "${azurerm_resource_group.main.name}"
	network_security_group_id = "${azurerm_network_security_group.main.id}"

	ip_configuration {
	  name			= "ipconfig-pyserver"
	  subnet_id		= "${azurerm_subnet.internal.id}"
	  private_ip_address_allocation = "Dynamic"
	  public_ip_address_id	= "${azurerm_public_ip.pyserver.id}"
  }
}

# - - - VM setup - - -
resource "azurerm_virtual_machine" "main" {
	name			= "${var.prefix}-jenkins"
	location		= "${azurerm_resource_group.main.location}"
	resource_group_name	= "${azurerm_resource_group.main.name}"
	network_interface_ids	= ["${azurerm_network_interface.main.id}"]
	vm_size			= "Standard_B1s"
	
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
		computer_name 	= "TheNexus-Jenkins"
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
		"git clone -b dev --single-branch  https://github.com/DimitriosKan/Jenkins-Auto-Setup.git",
		"cd Jenkins-Auto-Setup/JenkOpts/ && ./install"
		]
	  connection {
		type = "ssh"
		user = "deekay"
		private_key = file("/home/nexus/.ssh/id_rsa")
		host = "${azurerm_public_ip.main.fqdn}"
	}
    }
}

resource "azurerm_virtual_machine" "slave" {
	name			= "${var.prefix}-slave"
	location		= "${azurerm_resource_group.main.location}"
	resource_group_name	= "${azurerm_resource_group.main.name}"
	network_interface_ids	= ["${azurerm_network_interface.slave.id}"]
	vm_size			= "Standard_B1s"
	
	storage_image_reference {
		publisher 	= "Canonical"
		offer  		= "UbuntuServer"
		sku  		= "16.04-LTS"
		version 	= "latest"
	}
	storage_os_disk {
		name		= "slavedisk"
		caching		= "ReadWrite"
		create_option	= "FromImage"
		managed_disk_type= "Standard_LRS"
	}
	os_profile {
		computer_name 	= "TheNexus-Slave"
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
	  inline = ["echo hostname"]
	  connection {
		type = "ssh"
		user = "deekay"
		private_key = file("/home/nexus/.ssh/id_rsa")
		host = "${azurerm_public_ip.slave.fqdn}"
	}
    }
}

resource "azurerm_virtual_machine" "pyserver" {
	name			= "${var.prefix}-server"
	location		= "${azurerm_resource_group.main.location}"
	resource_group_name	= "${azurerm_resource_group.main.name}"
	network_interface_ids	= ["${azurerm_network_interface.pyserver.id}"]
	vm_size			= "Standard_B1s"
	
	storage_image_reference {
		publisher 	= "Canonical"
		offer  		= "UbuntuServer"
		sku  		= "16.04-LTS"
		version 	= "latest"
	}
	storage_os_disk {
		name		= "pyserverdisk"
		caching		= "ReadWrite"
		create_option	= "FromImage"
		managed_disk_type= "Standard_LRS"
	}
	os_profile {
		computer_name 	= "TheNexus-PyServer"
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
	  inline = ["echo hostname"]
	  connection {
		type = "ssh"
		user = "deekay"
		private_key = file("/home/nexus/.ssh/id_rsa")
		host = "${azurerm_public_ip.pyserver.fqdn}"
	}
    }
}
