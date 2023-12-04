terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      version = "0.61.0"
    }
  }
}

provider "yandex" {
  folder_id = "FOLDER_ID"
  token     = "TOKEN"
  cloud_id  = "CLOUD_ID"
}

resource "yandex_compute_instance" "test-node" {
  name         = "test-node"
  zone         = "ru-central1-a"
  platform_id  = "standard-v2"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd89cudngj3s2osr228p" 
    }
  }

  network_interface {
    subnet_id = "SUBNET_ID"
  }
}

output "test-node-ip" {
  value = yandex_compute_instance.test-node.network_interface.0.nat_ip_address
}
