# Upgrade cluster

**Перед обновлением версии кластера**:

* Обязательно прочтите [Changelog](https://kubernetes.io/releases/) 
  версии на которую вы хотите обновиться. Велика вероятность, что в 
  новой версии удалена поддержка каких либо API или у них изменена
  версия.
* Поставьте "рядом" кластер с новой версией kubernetes. И там проверьте 
  все ваши манифесты, helm charts, процедуры CI|CD. 

Обновление версии кластера, [документация](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/).

