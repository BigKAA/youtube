# Материалы для моих видео в Youtube

* **[K8s step by step](k8s-step-by-step)** - установка небольшого кластера шаг за шагом.
  * **[Kubernetes offline installation by kubespray](k8s-step-by-step/07-starter)**
  * **[kubeadm](kubeadm)** - управление кластером при помощи kubeadm.
* **[Helm](helm)** - всякое про Helm
* **[Net](net)** - Про сеть в kubernetes.
  * **[Network Polices](net/04-NetworkPolicies)** - Встроенный firewall.
  * **[Network Polices calico](net/05-NetworkPolicy-calico)** - Реализация от проекта Calico.
* **[ArgoCD](argocd/README.md)** - приложение для CD в k8s.
* **[Nexus](nexus)** - хороший пример для объяснения зачем нужен StatefulSet.
Начало серии видео по devops инструментам в кубернетес.
Nexus внутри kubernetes, делаем свой docker registry.
* **[Jenkins](jenkins)** - Как установить Jenkins в kubernetes, руками без хелмчартов.
Как заставить kubernetes (docker) работать с частным хранилищем docker 
образов по https с "левым" сертификатом.
* **PostgreSQL в kubernetes**
  * **[Zalando Spilo](base/spilo)**
  * **[Crunchy PostgreSQL Operator](base/Crunchy%20PostgreSQL%20Operator)**
* **Gitlab**
  * **[Установка Gitlab в kubernetes](gitlab)**
  * **[Gitlab runner в kubernetes](gitlab/runner)**
* **[Harbor](harbor/README.md)** - хранилище образов контейнеров и много 
дополнительных плюшек.
* **[Keycloak](keycloak/README.md)** - кластер Keycloak.
  * [Gatekeeper](keycloak/gatekeeper/README.md) - ограничение доступа к приложениям.
* **[Kafka](kafka)** - Kafka всякое, разное.
* **[Mino](minio/README.md)** - установка minio в k8s. Версия под мой [миникластер](k8s-step-by-step/00-planning/README.md).
* **[Подстановка данных из Secret](keycloak/gatekeeper/manifests-v3)** - подстановка данных из Secret в 
конфигурационный файл приложения.
* **[Всякое разное](notclassified)** - разные полезные мелочи.
  * **[Resourcequota](resourcequota)** - Накладываем ограничения на namespace.
  * **[PriorityClass](PriorityClass)** - Приориеты. Больше вопросов, чем ответов.
  * **[Semaphore](semaphore)** - Ansible UI  
  * **[Local Path Provisioner](base/local-path-provisioner)** - Доступ к локальным 
    дискам кластера при помощи Local Path Provisioner.
  * **[Longhorn](longhorn)** - Highly available persistent storage for Kubernetes.
* **[Hashicorp vault](vault)**
* **Observability**
  * **[Мониторинг](monitoring)**
  * **Логи**
    * **[Сбор логов с асинхронной очередью](logs/async)** - kafka, vector, fluentbit, opensearch.
    * **[Loki](loki/README.md)** - первая попытка поставить Loki в k8s.
  * **[Трейсинг](tracing)** - Jaeger, Open telemetry, Opensearch Observability.
* **k3s**
  * [Установка](k3s)
