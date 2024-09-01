# configMap
Применяется для: 

- Создание конфигурационных файлов или любых других не пустых 
файлов. 
- Определения большого количества переменных среды окружения 
контейнера.

Содержимое configMap хранится в базе etcd. Поэтому не имеет 
смысл использовать его для больших бинарных файлов.

Текстовые данные должны быть в кодировке UTF-8. Если
файл должен быть в другой кодировке, используйте binaryData.

Необходимо сначала создать объект configMap, прежде чем вы 
начнёте его использовать. Иначе при инициализации пода будет 
выводиться сообщение об ошибке, а сам под не будет запущен.

#### Создание configMap из файла index.html:

    kubectl create configmap index-html --from-file=index.html --dry-run=client -o yaml | sed '/creationTimestamp/d' > 00-index-html.yaml

#### Создание configMap, включая в него все файлы в текущей директории:

    kubectl create configmap index-html --from-file=./ --dry-run=client -o yaml | sed '/creationTimestamp/d' > 00-index-html.yaml

#### Подключение к pod

    kubectl -n volumes-sample exec openresty-7cd79cfd94-5zjgl -i -t -- bash