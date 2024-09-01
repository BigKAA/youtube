# secret

Секрет - это объект, который содержащий
конфиденциальные данные, такие как пароль, токен 
или объекты ssl.

Чтобы использовать секрет, pod должен ссылаться на секрет.
Секрет может быть использован:

- Как файлы в томе, смонтированном на одном или нескольких
его контейнерах.
- В качестве переменной среды окружения контейнера.

## Создание secret из файла

`kubectl -n volumes-sample create secret generic my-secret --from-file=user=user.txt --from-file=password=password.txt`

## Создание secret, указывая данные в командной строке

`kubectl -n volumes-sample create secret generic my-secret --from-literal=user=user_admin --from-literal=password=mypassword`

## Подключение к pod

    kubectl -n volumes-sample exec openresty-7cd79cfd94-5zjgl -i -t -- bash

## Secret для доступа к хранилищу docker images 
    imagePullSecrets:
      - name: registrykey
