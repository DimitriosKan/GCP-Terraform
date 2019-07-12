variable "project" {
	default = "terraforming-setup"
}

variable "name" {
	default = "nexus-but"
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

variable "packages" {
	default = [
		"wget",
		"unzip"
	]
}

variable "install_packages" {
	default = {
		"apt" = "sudo apt install -y"
	}
}

variable "scripts" {
	default = []
}

variable "allowed_ports" {
	default = [
		"22",
		"5000"
	]
}

# - - - CALL PROJECT - - -
provider "google" {
	credentials = "${file("~/.gcp/terraform_key.json")}"
	project	= "${var.project}"
	region	= "europe-west2"
}

#- - - Firewall setup - - -
resource "google_compute_firewall" "default" {
	name = "${var.name}-firewall"
	network = "${var.network}"
	target_tags = ["http-server", "https-server", "${var.name}-main", "${var.name}-jenkins", "${var.name}-python"]
	source_ranges = ["0.0.0.0/0"]

	allow {
		protocol = "icmp"
	}

	allow {
		protocol = "tcp"
		ports = "${var.allowed_ports}"
	}
}
