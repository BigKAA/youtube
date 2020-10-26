# ResourceQuota

ResoqurceQuota определяет ограничения на namespace. 
* Ограничивает количество объектов, создаваемых в namespace, по типу.
* Ограничевает общий объем вычислительных ресурсов.

Квоты работаю следующим образом:
* Создается ResourceQuota в namespace.
* Пользователи создают объекты в namespace. Система отслеживает, не превышают ли запрошенные
ресурсы лимиты, описанные в квотах.
* Если создание нового ресурса превышает квоту, API сервер возвращает 403-ю ошибку (FORBIDDEN)
с сообщением о том, какие квоты были превышены.

Если в namespace включена квота на вычислительные ресурсы: cpu и memory. В создаваемых 
пользователем ресурсах **должны быть явно описаны лимиты**. Если лимиты не описаны, система 
отклонит создание новых ресурсов. Для избегания подобной ситуации администратор должен 
устанавливать LimitRanger на namespace.

## Типы квот

### Вычислительные

* limits.cpu
* limits.memory
* requests.cpu
* requests.memory

### Хранения

* requests.storage
* persistentvolumeclaims
* <storage-class-name>.storageclass.storage.k8s.io/requests.storage
* <storage-class-name>.storageclass.storage.k8s.io/persistentvolumeclaims

### Количество объектов

* configmaps
* pods
* replicationcontrollers
* resourcequotas
* services
* services.loadbalancers
* services.nodeports
* secrets

## Информация о квотах.

    kubectl -n q-test describe quota
    
## Видео
  
https://youtu.be/nsBeED5UNUw
