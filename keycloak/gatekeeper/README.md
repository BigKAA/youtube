# Gatekeeper

Поддерживаемая на момент создания примера версия [gatekeeper](https://gogatekeeper.github.io/)

## Конфигурация keycloak

Создаём realm app

Создаём группы g1 и g2

    Groups -> New -> g1
    Groups -> New -> g2

    Users -> Add user -> 
        Username -> user1
        Groups -> g1
        User Enabled -> ON
        Save
        Credentials -> Password & Password Confirmation
        Temporary -> OFF
    Users -> Add user -> 
        Username -> user2
        Groups -> g2
        User Enabled -> ON
        Save
        Credentials -> Password & Password Confirmation
        Temporary -> OFF

Создаём клиента

    Clients -> Create
        ClientID -> myapp
        Client Protocol -> openid-connect
        Root URL -> https://application.kryukov.local
        Save
        Access Type -> confidential
        Save
        Mappers -> Create
        Name -> groups
        Mapper Type -> Group Membership
        Token Claim Name -> groups
        Full group path -> OFF
        Save
        Mappers -> Create
        Name -> myapp-audience
        Mapper Type -> Audience
        Included Client Audience -> myapp
        Add to access token -> On
        Save

Проверяем.

    curl \
    -d "grant_type=password" \
    -d "client_id=myapp" \
    -d "client_secret=db7b8b62-4fd7-4769-b397-de57614164df" \
    -d "username=user1" \
    -d "password=password" \
    http://keycloak.kryukov.local/iam/auth/realms/app/protocol/openid-connect/token | jq

В ответе должны быть выданы access_token и refresh_token.

Посмотрим содержимое токена.

    curl --user "myapp:$CLIENT-SECRET" \
    -d "token=$ACCESS-TOKEN" \
    http://keycloak.kryukov.local/iam/auth/realms/app/protocol/openid-connect/token/introspect

Например:

    curl --user "myapp:db7b8b62-4fd7-4769-b397-de57614164df" \
    -d "token=eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICI2ZWVuY0hCTmZja240enpIaUJHblVvNHRDd1JsZjhINFByY1FpN2tRbnRrIn0.eyJleHAiOjE2MzQ3MTcxNTIsImlhdCI6MTYzNDcxNjg1MiwianRpIjoiNGZlYmY3NzMtZTE4YS00ZWMzLTgyNjYtOWQwYTVkNTFkYjQ1IiwiaXNzIjoiaHR0cDovL2tleWNsb2FrLmtyeXVrb3YubG9jYWwvaWFtL2F1dGgvcmVhbG1zL2s4cyIsImF1ZCI6ImFjY291bnQiLCJzdWIiOiI2MzA3MjI4Zi0yMGI3LTRkZDktOGEyMy0wMTM0ZDVmMDgwN2EiLCJ0eXAiOiJCZWFyZXIiLCJhenAiOiJkYXNoYm9hcmQiLCJzZXNzaW9uX3N0YXRlIjoiMDljNmNkN2EtNWU3Ny00OTZhLTg2YzctMmFlMTdmNTkzODFlIiwiYWNyIjoiMSIsImFsbG93ZWQtb3JpZ2lucyI6WyJodHRwOi8vZGFzaGJvYXJkLmtyeXVrb3YubG9jYWwiXSwicmVhbG1fYWNjZXNzIjp7InJvbGVzIjpbImRlZmF1bHQtcm9sZXMtazhzIiwib2ZmbGluZV9hY2Nlc3MiLCJ1bWFfYXV0aG9yaXphdGlvbiJdfSwicmVzb3VyY2VfYWNjZXNzIjp7ImFjY291bnQiOnsicm9sZXMiOlsibWFuYWdlLWFjY291bnQiLCJtYW5hZ2UtYWNjb3VudC1saW5rcyIsInZpZXctcHJvZmlsZSJdfX0sInNjb3BlIjoicHJvZmlsZSBlbWFpbCIsInNpZCI6IjA5YzZjZDdhLTVlNzctNDk2YS04NmM3LTJhZTE3ZjU5MzgxZSIsImVtYWlsX3ZlcmlmaWVkIjpmYWxzZSwiZ3JvdXBzIjpbImRhc2hib2FyZCJdLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJhZG1pbi1kYXNoYm9hcmQifQ.Jt4pTC8umfLbNe22nEd9cHSQnW-9T9OfH7YKTBIPhgD0GOuGzHTFrYkq9Pk0M8wL2AUIDtnoxMe8Mc-oB1VMl6220UGiRs27U8sy5pmD9taWth6Q_AJFLOmgib6Wem1AcgNSHLHCWeD6FeGGewie7uXAg_eeatYFpdKF1G1I-IB6yWbZfzlHY7HckHsPEipOuyzOG5mGgIZEwxbAgR_1uOkMQxn5-HNle0b__VLtcyJeJCgF0q7k6chaUJCFMRCQ_hWWpUIFw2dXb5UttCG7mFMmhg8HEj6I6We7nqW8WlevmQ9a_7LKL-4iLLvyWe1P94cC1od3qosYgYlz0HusDg" \
    http://keycloak.kryukov.local/iam/auth/realms/app/protocol/openid-connect/token/introspect | jq 

## Ссылка на видео.

[<img src="https://img.youtube.com/vi/zzjbDoTGdU4/maxresdefault.jpg" width="50%">](https://youtu.be/zzjbDoTGdU4)
