terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  zone = "ru-central1-a"
} 
data "yandex_compute_image" "ubuntu_image" {
  family = "ubuntu-2004-lts"
}
 

variable "paramsvm" {
  description = "параметры машин"
  type        = map(string)
  default     = {
    namevm1     = "lessonvm1",
    cor1        = 2,
    mem1        = 2,
    namevm2     = "lessonvm2",
    cor2        = 2,
    mem2        = 2,
  }
}
resource "yandex_compute_instance" "vm-1" {
  name = var.paramsvm.namevm1
  allow_stopping_for_update = true
  resources {
    cores  = var.paramsvm.cor1
    memory = var.paramsvm.mem1
  }

  boot_disk {
    disk_id =  yandex_compute_disk.hddvm1.id
  }

  network_interface {
    subnet_id = "e9bohr7qvj70b390umrp"
    nat       = true
  }

  metadata = {
    user-data = "${file("./user.yml")}"
  }
  scheduling_policy {
    preemptible = true 
  }
  connection {
    type     = "ssh"
    user     = "user"
    private_key = file("./id_rsa")
    host = yandex_compute_instance.vm-1.network_interface.0.nat_ip_address
  }
  provisioner "file" {
    source      = "./dockerfile"
    destination = "/home/user/Dockerfile"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt update", 
      "sudo apt install docker.io -y",
      "cd /home/user", 
      "sudo docker build -t test1 .",
      "sudo docker tag test1 cr.yandex/${yandex_container_registry.my-reg.id}/test1",
      "sudo docker push cr.yandex/${yandex_container_registry.my-reg.id}/test1",    
    ]
  }
}

resource "yandex_compute_disk" "hddvm1" {
  type     = "network-hdd"
  zone     = "ru-central1-a"
  image_id = data.yandex_compute_image.ubuntu_image.id
  size = 15
}

resource "yandex_compute_instance" "vm-2" {
  name = var.paramsvm.namevm2
  allow_stopping_for_update = true
  resources {
    cores  = var.paramsvm.cor2
    memory = var.paramsvm.mem2
  }

  boot_disk {
    disk_id =  yandex_compute_disk.hddvm2.id
  }

  network_interface {
    subnet_id = "e9bohr7qvj70b390umrp"
    nat       = true
  }

  metadata = {
    user-data = "${file("./user.yml")}"
  }
  scheduling_policy {
    preemptible = true 
  }
  connection {
    type     = "ssh"
    user     = "user"
    private_key = file("./id_rsa")
    host = yandex_compute_instance.vm-2.network_interface.0.nat_ip_address
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt update", 
      "sudo apt install docker.io -y",
      "sudo docker pull cr.yandex/${yandex_container_registry.my-reg.id}/test1",
      "sudo docker run -d -p 8080:8080 cr.yandex/${yandex_container_registry.my-reg.id}/test1",
    ]
  }
  depends_on = [
    yandex_compute_instance.vm-1
  ]

}

resource "yandex_compute_disk" "hddvm2" {
  type     = "network-hdd"
  zone     = "ru-central1-a"
  image_id = data.yandex_compute_image.ubuntu_image.id
  size = 15
}

resource "yandex_container_registry" "my-reg" {
  name = "my-registry"
  folder_id = "b1gum68ifoa9fbhijk7v"
  labels = {
    my-label = "my-label-value"
  }
}
resource "yandex_container_registry_iam_binding" "puller" {
  registry_id = yandex_container_registry.my-reg.id
  role        = "container-registry.images.puller"

  members = [
    "system:allUsers",
  ]
}
resource "yandex_container_registry_iam_binding" "pusher" {
  registry_id = yandex_container_registry.my-reg.id
  role        = "container-registry.images.pusher"

  members = [
    "system:allUsers",
  ]
}