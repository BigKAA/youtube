# Материалы для моих видео в Youtube
Потихоньку буду обьединять файлы из разных видео

* **nexus** - хороший пример для объяснения зачем нужен StatefulSet.
Начало серии видео по devops инструментам в кубернетес.
Nexus внутри kubernetes, делаем свой docker registry.
    * https://youtu.be/I9NdVM8xyR0
* **jenkins** - Как установить Jenkins в kubernetes, руками без хелмчартов.
Как заставить kubernetes (docker) работать с частным хранилищем docker 
образов по https с "левым" сертификатом.  
    * https://youtu.be/FNTFVSavQY8
    * https://youtu.be/q4FjUpnWDFY
* **resourcequota** - Накладываем ограничения на namespace.
   * https://youtu.be/nsBeED5UNUw
* **PriorityClass** - Приориеты. Больше вопросов, чем ответов.
   * https://youtu.be/BGd-NsaQF7g
* **net** - Про сеть в kubernetes.
   * [Теория](https://youtu.be/Xo14qjvbCmU)
   * [перед установкой драйвера сети](https://youtu.be/N_eimgSDB_s) 
   * [Calico](https://youtu.be/GRlMC-7qZv8)
   * [Calico-IPAM](https://youtu.be/4kQB6fR5vm8)
   * [Services 1](https://youtu.be/OWUOHM_08mc)
   * [Services 2](https://youtu.be/OHBv_OdjVIU)
* **k8s-step-by-step** - установка небольшого кластера шаг за шагом.
  * [Планирование](k8s-step-by-step/00-planning/README.md)
  * [Установка](k8s-step-by-step/01-install/README.md)
  * [Утилиты 1](k8s-step-by-step/02-utils/README.md)
  * [Утилиты 2](k8s-step-by-step/03-utils/README.md)
  * [Мониторинг prometheus + victoriametyrics](k8s-step-by-step/04-monitoring%20victoriametrics%20+%20prometheus/README.md)
  * [Мониторинг только victoriametyrics](k8s-step-by-step/05-monitoring%20victoriametrics%20only/README.md)
  * [Логи](k8s-step-by-step/06-logs/README.md)
  
* **[ArgoCD](argocd/README.md)** - приложение для CD в k8s.
* **[Harbor](harbor/README.md)** - хранилище образов контейнеров и много 
дополнительных плюшек.
  
* **[Keycloak](keycloak/README.md)** - кластер Keycloak.
  * **[Gatekeeper](keycloak/gatekeeper/README.md)**
* **[Loki](loki/README.md)** - первая попытка поставить Loki в k8s.
* **[Mino](minio/README.md)** - установка minio в k8s. Версия под мой [миникластер](k8s-step-by-step/00-planning/README.md).

* **[Подстановка данных из Secret](keycloak/gatekeeper/manifests-v3)** - подстановка данных из Secret в 
конфигурационный файл приложения.