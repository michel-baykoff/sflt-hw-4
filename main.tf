terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone = "ru-central1-a"
}


resource "yandex_compute_disk" "boot-disk-1" {
  name     = "boot-disk-1"
  type     = "network-hdd"
  zone     = "ru-central1-a"
  size     = "20"
  image_id = "fd80sfcd16u3pv7sveh1"
}

resource "yandex_compute_disk" "boot-disk-2" {
  name     = "boot-disk-2"
  type     = "network-hdd"
  zone     = "ru-central1-a"
  size     = "20"
  image_id = "fd80sfcd16u3pv7sveh1"
}

resource "yandex_compute_instance" "nginx1" {
  name = "nginx1"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk-1.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    ssh-keys = "${file("./meta.yaml")}"
  }

  scheduling_policy {
    preemptible = true
  }
}

resource "yandex_compute_instance" "nginx2" {
  name = "nginx2"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk-2.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    ssh-keys = "${file("./meta.yaml")}"
  }

  scheduling_policy {
    preemptible = true
  }
}

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

# create load balancer target group
resource "yandex_lb_target_group" "nginx-tg" {
  name      = "nginx"
  target {
    subnet_id = "${yandex_vpc_subnet.subnet-1.id}"
    address   = "${yandex_compute_instance.nginx1.network_interface.0.ip_address}"
  }
  target {
    subnet_id = "${yandex_vpc_subnet.subnet-1.id}"
    address   = "${yandex_compute_instance.nginx2.network_interface.0.ip_address}"
  }
}

# connect lb_tg to lb
resource "yandex_lb_network_load_balancer" "nginx-lb" {
  name = "nginx-lb"
  listener {
    name = "http"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }
  attached_target_group {
    target_group_id = "${yandex_lb_target_group.nginx-tg.id}"
    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}


output "internal_ip_address_nginx1" {
  value = yandex_compute_instance.nginx1.network_interface.0.ip_address
}

output "internal_ip_address_nginx2" {
  value = yandex_compute_instance.nginx2.network_interface.0.ip_address
}

output "external_ip_address_nginx1" {
  value = yandex_compute_instance.nginx1.network_interface.0.nat_ip_address
}

output "external_ip_address_nginx2" {
  value = yandex_compute_instance.nginx2.network_interface.0.nat_ip_address
}
