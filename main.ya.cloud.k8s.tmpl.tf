locals {
  k8s_version = "1.25"  
  service_account = "SA_ACCOUNT" 
  folder_id = "FOLDER_ID"
  cloud_id  = "CLOUD_ID"
  cluster_name = "CLUSTER_NAME"
}

terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      version = "0.61.0"
    }
  }
}

provider "yandex" {
  folder_id = local.folder_id
}

resource "yandex_vpc_network" "lrvlnet" {
  name = "trvlnet"
}

resource "yandex_vpc_subnet" "trvlsubnet" {
  v4_cidr_blocks = ["10.0.0.0/24"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.lrvlnet.id
}

resource "yandex_iam_service_account" "trvlaccount" {
  name        = local.service_account
  description = "K8s service account"
}

resource "yandex_kubernetes_cluster" "k8s-trvl-zonal" {
  name = local.cluster_name
  network_id = yandex_vpc_network.lrvlnet.id
  master {
    version = local.k8s_version
    zonal {
      zone      = yandex_vpc_subnet.trvlsubnet.zone
      subnet_id = yandex_vpc_subnet.trvlsubnet.id
    }
    public_ip = true
    security_group_ids = [yandex_vpc_security_group.k8s-public-services.id]
  }
  service_account_id      = yandex_iam_service_account.trvlaccount.id
  node_service_account_id = yandex_iam_service_account.trvlaccount.id
  depends_on = [
    yandex_resourcemanager_folder_iam_member.k8s-clusters-agent,
    yandex_resourcemanager_folder_iam_member.vpc-public-admin,
    yandex_resourcemanager_folder_iam_member.images-puller
  ]
  kms_provider {
    key_id = yandex_kms_symmetric_key.kms-key.id
  }
}

resource "yandex_resourcemanager_folder_iam_member" "k8s-clusters-agent" {
  # Сервисному аккаунту назначается роль "k8s.clusters.agent".
  folder_id = local.folder_id
  role      = "k8s.clusters.agent"
  member    = "serviceAccount:${yandex_iam_service_account.trvlaccount.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "vpc-public-admin" {
  # Сервисному аккаунту назначается роль "vpc.publicAdmin".
  folder_id = local.folder_id
  role      = "vpc.publicAdmin"
  member    = "serviceAccount:${yandex_iam_service_account.trvlaccount.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "images-puller" {
  # Сервисному аккаунту назначается роль "container-registry.images.puller".
  folder_id = local.folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.trvlaccount.id}"
}

resource "yandex_kms_symmetric_key" "kms-key" {
  # Ключ для шифрования важной информации, такой как пароли, OAuth-токены и SSH-ключи.
  name              = "kms-key"
  default_algorithm = "AES_128"
  rotation_period   = "8760h" # 1 год.
}

resource "yandex_resourcemanager_folder_iam_member" "viewer" {
  folder_id = local.folder_id
  role      = "viewer"
  member    = "serviceAccount:${yandex_iam_service_account.trvlaccount.id}"
}

resource "yandex_vpc_security_group" "k8s-public-services" {
  name        = "k8s-public-services"
  description = "Правила группы разрешают подключение к сервисам из интернета. Примените правила только для групп узлов."
  network_id  = yandex_vpc_network.lrvlnet.id
  ingress {
    protocol          = "TCP"
    description       = "Правило разрешает проверки доступности с диапазона адресов балансировщика нагрузки. Нужно для работы отказоустойчивого кластера Managed Service for Kubernetes и сервисов балансировщика."
    predefined_target = "loadbalancer_healthchecks"
    from_port         = 0
    to_port           = 65535
  }
  ingress {
    protocol          = "ANY"
    description       = "Правило разрешает взаимодействие мастер-узел и узел-узел внутри группы безопасности."
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }
  ingress {
    protocol          = "ANY"
    description       = "Правило разрешает взаимодействие под-под и сервис-сервис."
    v4_cidr_blocks    = concat(yandex_vpc_subnet.trvlsubnet.v4_cidr_blocks)
    from_port         = 0
    to_port           = 65535
  }ingress {
    protocol          = "TCP"
    description       = "Правило разрешает входящий трафик из интернета на диапазон портов NodePort."
    v4_cidr_blocks    = ["0.0.0.0/0"]
    from_port         = 30000
    to_port           = 32767
  }  
  ingress {
    protocol       = "TCP"
    description    = "Правило разрешает подключение к API Kubernetes через порт 6443 из указанной сети."
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 6443
  }
  ingress {
    protocol       = "TCP"
    description    = "Правило разрешает подключение к API Kubernetes через порт 443 из указанной сети."
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }


  egress {
    protocol          = "ANY"
    description       = "Правило разрешает весь исходящий трафик. Узлы могут связаться с Yandex Container Registry, Yandex Object Storage, Docker Hub и т. д."
    v4_cidr_blocks    = ["0.0.0.0/0"]
    from_port         = 0
    to_port           = 65535
  }
}

resource "yandex_kubernetes_node_group" "trvlnode" {
  cluster_id = yandex_kubernetes_cluster.k8s-trvl-zonal.id
  name       = "trvlnode"

  instance_template {
    instance_name       = "trvl-{instance.index}"
    platform_id = "standard-v1"
    network_acceleration_type = "standard"
    container_runtime {
     type = "docker"
    }

    resources {
      cores  = 2
      memory = 2
      core_fraction = 20
    }

  }
  scale_policy {
    fixed_scale {
      size = 1
    }
  }

  maintenance_policy {
    auto_upgrade = false
    auto_repair  = true
  }
}
