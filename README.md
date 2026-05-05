# oyd-exercise-3-1 — Módulo de cómputo EC2

Módulo Terraform reutilizable que provisiona una instancia EC2 corriendo un servidor HTTP en Ruby con dos endpoints (`GET /health`, `POST /echo`). La instancia descarga `server.rb` desde S3 al iniciar mediante un IAM role con permisos restringidos, y queda accesible en TCP 8080 solo desde la lista de CIDRs configurada.

## Estructura del repositorio

```
oyd-exercise-3-1/
├── app/server.rb                              # Servidor HTTP en Ruby (no modificar)
├── infra/
│   ├── provider.tf                            # AWS provider + Terraform >= 1.8
│   ├── variables.tf                           # Inputs del root
│   ├── main.tf                                # Llama al módulo compute_ec2
│   ├── outputs.tf                             # Re-exporta instance_arn y public_ip
│   ├── envs/dev/dev.tfvars                    # Valores concretos para el entorno dev
│   ├── modules/compute_ec2/
│   │   ├── variables.tf                       # 6 inputs (environment, name, ami_id, instance_type, allowed_cidr_blocks, app_s3_bucket)
│   │   ├── main.tf                            # IAM role + policy S3 restringida + instance profile + SG + EC2
│   │   └── outputs.tf                         # instance_arn, public_ip
│   └── evidence/instance.txt                  # Salida de aws ec2 describe-instances
├── .github/workflows/terraform-ci.yml         # Pipeline de PR: fmt / init / validate / plan + comentario con el plan
└── README.md
```

## Inputs del módulo

| Nombre                | Tipo           | Default      | Requerido |
|-----------------------|----------------|--------------|-----------|
| `environment`         | `string`       | —            | sí        |
| `name`                | `string`       | —            | sí        |
| `ami_id`              | `string`       | —            | sí        |
| `instance_type`       | `string`       | `t3.micro`   | no        |
| `allowed_cidr_blocks` | `list(string)` | —            | sí        |
| `app_s3_bucket`       | `string`       | —            | sí        |

## Outputs del módulo

| Nombre         | Descripción                                                  |
|----------------|--------------------------------------------------------------|
| `instance_arn` | ARN de la instancia EC2 corriendo el servidor HTTP en Ruby   |
| `public_ip`    | Dirección IPv4 pública de la instancia EC2                   |

## Uso

```bash
# 1. Subir el binario de la aplicación al bucket
aws s3 cp app/server.rb s3://<tu-bucket>/server.rb --region us-west-2

# 2. Configurar tu CIDR en infra/envs/dev/dev.tfvars
#    (por ejemplo ["$(curl -s ifconfig.me)/32"])

# 3. Aplicar
cd infra
terraform init
terraform plan  -var-file=envs/dev/dev.tfvars
terraform apply -var-file=envs/dev/dev.tfvars

# 4. Probar (usar el output public_ip)
curl http://<public_ip>:8080/health
curl -X POST http://<public_ip>:8080/echo \
  -H 'Content-Type: application/json' -d '{"msg":"hello"}'

# 5. Destruir todo
terraform destroy -var-file=envs/dev/dev.tfvars
```

## CI

`.github/workflows/terraform-ci.yml` corre en cada pull request hacia `main`. Pasos:

1. `terraform fmt --check -recursive` — falla el PR si hay archivos sin formato.
2. `terraform init -backend=false`.
3. `terraform validate`.
4. `terraform plan -var-file=envs/dev/dev.tfvars` — requiere credenciales AWS desde GitHub Secrets.
5. Publica la salida del plan como comentario colapsable en el PR (no bloqueante).

### Ejecución de demostración

| Recurso             | Enlace                                                                                                  |
|---------------------|---------------------------------------------------------------------------------------------------------|
| Pull request        | <https://github.com/SebastianAlecio/oyd-exercise-3-1/pull/1>                                            |
| Workflow run        | <https://github.com/SebastianAlecio/oyd-exercise-3-1/actions/runs/25403248837>                          |
| Resultado           | success — 5 steps en 22s, comentario con el plan posteado en el PR                                      |

Resumen del plan publicado en el PR:

```
Plan: 5 to add, 0 to change, 0 to destroy.
```

### Secrets requeridos en GitHub

| Secret                  | Valor                                                       |
|-------------------------|-------------------------------------------------------------|
| `AWS_ACCESS_KEY_ID`     | Access key con permisos para EC2 / IAM / lectura de S3      |
| `AWS_SECRET_ACCESS_KEY` | Secret key correspondiente                                  |

La región (`us-west-2`) está hardcoded en el workflow porque no es un dato sensible.

## Notas sobre AMI / tipo de instancia

El PDF lista dos AMIs de referencia para `us-west-2` (AL2023). Al momento de aplicar:

- `ami-023a34a1153befb51` (arm64, emparejado con `t4g.nano`) — existe, pero `t4g.nano` no está cubierto por Free Tier. Cuentas restringidas a Free Tier reciben `InvalidParameterCombination`.
- `ami-05572e392e21e0843` (x86_64, emparejado con `t3.micro`) — fue dado de baja por AWS (`InvalidAMIID.NotFound`).

Este despliegue usa **`ami-0fa1ce9aa6f270301`** (AL2023 x86_64 actual en `us-west-2`) con **`t3.micro`** (Free Tier). Cualquier AMI de AL2023 que coincida con la arquitectura elegida funciona — se puede cambiar desde `dev.tfvars`.

## Evidencia

Salida de `aws ec2 describe-instances` (`infra/evidence/instance.txt`):

```
-----------------------------------------------------
|                 DescribeInstances                 |
+----------------------+----------+-----------------+
|  i-0612676e01cc554ad |  running |  44.243.171.83  |
+----------------------+----------+-----------------+
```

Pruebas de los endpoints:

```bash
$ curl http://44.243.171.83:8080/health
{"status":"ok","compute":"ec2"}

$ curl -X POST http://44.243.171.83:8080/echo \
    -H 'Content-Type: application/json' -d '{"msg":"hello"}'
{"msg":"hello","compute":"ec2"}
```

Ambas respuestas incluyen el campo `compute` con valor `ec2`, cumpliendo el criterio de aceptación. Los recursos se destruyeron con `terraform destroy -var-file=envs/dev/dev.tfvars` después de capturar la evidencia.
