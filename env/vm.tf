resource "azurerm_network_interface" "main" {
  name                = "${azurerm_resource_group.main.name}-ni"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  network_security_group_id = azurerm_network_security_group.main.id

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id = azurerm_public_ip.main.id
  }
}

locals {
  username = "minecraftadmin"  
}

resource "azurerm_virtual_machine" "main" {
  name                  = "${azurerm_resource_group.main.name}-vm"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  network_interface_ids = [azurerm_network_interface.main.id]
  vm_size               = "Standard_B2s"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "hostname"
    admin_username = local.username
    admin_password = var.password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y unzip",
      "sudo apt-get install -y libcurl4",
    ]

    connection {
        host     = azurerm_public_ip.main.ip_address
        type     = "ssh"
        user     = local.username
        password = var.password
    }
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir /home/${local.username}/minecraft",
      "cd /home/${local.username}/minecraft",
      "wget https://minecraft.azureedge.net/bin-linux/bedrock-server-1.16.20.03.zip",
      "unzip bedrock-server-1.16.20.03.zip",     
      "sudo mv /home/${local.username}/minecraft/libCrypto.so /usr/lib/libCrypto.so",
      "sudo ldconfig -v | grep libCrypto.so",
    ]

    connection {
        host     = azurerm_public_ip.main.ip_address
        type     = "ssh"
        user     = local.username
        password = var.password
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT",      
      "sudo iptables -A INPUT -p udp --dport 19132 -j ACCEPT",
      "sudo iptables -A INPUT -p udp --dport 19133 -j ACCEPT",
    ]

    connection {
        host     = azurerm_public_ip.main.ip_address
        type     = "ssh"
        user     = local.username
        password = var.password
    }
  }

  provisioner "file" {
    source = "${path.module}/config/minecraft-server.service"
    destination = "/home/${local.username}/minecraft-server.service"

    connection {
        host     = azurerm_public_ip.main.ip_address
        type     = "ssh"
        user     = local.username
        password = var.password
    }
  }

  provisioner "file" {
    source = "${path.module}/config/whitelist.json"
    destination = "/home/${local.username}/minecraft/whitelist.json"

    connection {
        host     = azurerm_public_ip.main.ip_address
        type     = "ssh"
        user     = local.username
        password = var.password
    }
  }

  provisioner "file" {
    source = "${path.module}/config/ops.json"
    destination = "/home/${local.username}/minecraft/ops.json"

    connection {
        host     = azurerm_public_ip.main.ip_address
        type     = "ssh"
        user     = local.username
        password = var.password
    }
  }

  provisioner "file" {
    source = "${path.module}/config/server.properties"
    destination = "/home/${local.username}/minecraft/server.properties"

    connection {
        host     = azurerm_public_ip.main.ip_address
        type     = "ssh"
        user     = local.username
        password = var.password
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /home/${local.username}/minecraft-server.service /etc/systemd/system/minecraft-server.service",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable minecraft-server",
      "sudo systemctl start minecraft-server",
    ]

    connection {
        host     = azurerm_public_ip.main.ip_address
        type     = "ssh"
        user     = local.username
        password = var.password
    }
  }
}
