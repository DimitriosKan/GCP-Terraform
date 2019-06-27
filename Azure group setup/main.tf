provider "azurerm" {
	version = "=1.30.1"
}
resource "azurerm_resource_group" "default" {
	name	= "default"
	location= "uksouth"
}
