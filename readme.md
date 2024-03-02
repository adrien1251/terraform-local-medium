# Tutoriel pour medium 

## Prérequis

- Localstack 
- Python 

## Comment l'installer

```bash
pip install terraform-local
tflocal -v
```

## Comment le lancer

```bash
cd terraform
tflocal init
tflocal plan -out planfile
tflocal apply -input=false -auto-approve planfile
```

## Comment le tester

```bash
curl --location 'http://localhost:4566/restapis/<agw_id>/<stage_id>/_user_request_/test' \
--header 'Accept: application/json' \
--header 'Content-Type: application/json'
```

## Comment tous supprimer

```bash
tflocal destroy -auto-approve
```