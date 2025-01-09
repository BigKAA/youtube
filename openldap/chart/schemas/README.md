# Пример схем

Примеры схем. Схемы предлагается загрузить в хранилище S3 и использовать в качестве примера custom schemas в values файле чарта в разделе `schemas.customSchemas`.

**Важно!** Используйте схемы от вашего дистрибутива OpenLDAP.

В моём случае в Minio создаются:

- Бакет `openldap`.
- Политика `openldap_rw`.
- Пользователь `openldap` с паролем `password`.

Пользователю `openldap` назначается политика `openldap_rw`.

Политика `openldap_rw`:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutBucketPolicy",
                "s3:GetBucketPolicy",
                "s3:DeleteBucketPolicy",
                "s3:ListAllMyBuckets",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::openldap"
            ]
        },
        {
            "Action": [
                "s3:AbortMultipartUpload",
                "s3:DeleteObject",
                "s3:GetObject",
                "s3:ListMultipartUploadParts",
                "s3:PutObject"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::openldap/*"
            ],
            "Sid": ""
        }
    ]
}
```

Файлы политик загружаются в бакет `openldap`.
