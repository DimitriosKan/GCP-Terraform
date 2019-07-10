variable "project" {
	default = "thenexusvm"
}
variable "name" {
	default = "nexus-but-$(date '+%dH%M%S')"
}

variable "machine_type" {
	default = "f1-micro"
}
variable "zone" {
	default = "europe-west2-c"
}
variable "image" {
	default = "ubuntu-1810"
}
variable "network" {
	default = "default"
}
variable "public_key" {
	default = "~/.ssh/id_rsa.pub"
}
variable "private_key" {
	default = "~/.ssh/id_rsa"
}
variable "package_manager" {
	default = "apt"
}
variable "update_packages" {
	default = {
		"apt" = "sudo apt update && sudo apt update -y"
	}
}
variable "install_packages" {
	default = {
		"apt" = "sudo apt install -y"
	}
}
variable "allowed_ports" {
	default = [
		"22",
		"5000"
	]
}

# - - - 
provider "google" {
	project	= "${var.project}"
	region	= "europe-west2"
}
