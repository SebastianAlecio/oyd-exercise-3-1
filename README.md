# oyd-exercise-3-1 — EC2 Compute Module

Reusable Terraform module that provisions an EC2 instance running a Ruby HTTP server with two endpoints (`GET /health`, `POST /echo`). The instance pulls `server.rb` from S3 at boot through a scoped IAM role, and is reachable on TCP 8080 from a configurable list of CIDR blocks.

## Repository layout

```
oyd-exercise-3-1/
├── app/server.rb                              # Ruby HTTP server (do not modify)
├── infra/
│   ├── provider.tf                            # AWS provider + Terraform >= 1.8 constraint
│   ├── variables.tf                           # Root inputs
│   ├── main.tf                                # Calls the compute_ec2 module
│   ├── outputs.tf                             # Re-exports instance_arn, public_ip
│   ├── envs/dev/dev.tfvars                    # Concrete values for the dev env
│   ├── modules/compute_ec2/
│   │   ├── variables.tf                       # 6 inputs (environment, name, ami_id, instance_type, allowed_cidr_blocks, app_s3_bucket)
│   │   ├── main.tf                            # IAM role + scoped S3 policy + instance profile + SG + EC2
│   │   └── outputs.tf                         # instance_arn, public_ip
│   └── evidence/instance.txt                  # Output of aws ec2 describe-instances
├── .github/workflows/terraform-ci.yml         # PR pipeline: fmt / init / validate / plan + plan comment
└── README.md
```

## Module inputs

| Name                  | Type           | Default      | Required |
|-----------------------|----------------|--------------|----------|
| `environment`         | `string`       | —            | yes      |
| `name`                | `string`       | —            | yes      |
| `ami_id`              | `string`       | —            | yes      |
| `instance_type`       | `string`       | `t3.micro`   | no       |
| `allowed_cidr_blocks` | `list(string)` | —            | yes      |
| `app_s3_bucket`       | `string`       | —            | yes      |

## Module outputs

| Name           | Description                                          |
|----------------|------------------------------------------------------|
| `instance_arn` | ARN of the EC2 instance running the Ruby HTTP server |
| `public_ip`    | Public IPv4 address of the EC2 instance              |

## Usage

```bash
# 1. Upload the application binary
aws s3 cp app/server.rb s3://<your-bucket>/server.rb --region us-west-2

# 2. Set your CIDR in infra/envs/dev/dev.tfvars (e.g. ["$(curl -s ifconfig.me)/32"])

# 3. Apply
cd infra
terraform init
terraform plan  -var-file=envs/dev/dev.tfvars
terraform apply -var-file=envs/dev/dev.tfvars

# 4. Test (use the public_ip output)
curl http://<public_ip>:8080/health
curl -X POST http://<public_ip>:8080/echo \
  -H 'Content-Type: application/json' -d '{"msg":"hello"}'

# 5. Tear down
terraform destroy -var-file=envs/dev/dev.tfvars
```

## CI

`.github/workflows/terraform-ci.yml` runs on every pull request targeting `main`. Steps:

1. `terraform fmt --check -recursive` — fails the PR on formatting drift.
2. `terraform init -backend=false`.
3. `terraform validate`.
4. `terraform plan -var-file=envs/dev/dev.tfvars` — requires AWS credentials from GitHub secrets.
5. Posts the plan output as a collapsible PR comment (non-blocking).

### Required GitHub secrets

| Secret                  | Value                                                    |
|-------------------------|----------------------------------------------------------|
| `AWS_ACCESS_KEY_ID`     | IAM access key with EC2 / IAM / S3 read permissions      |
| `AWS_SECRET_ACCESS_KEY` | Matching secret key                                      |

The region (`us-west-2`) is hardcoded in the workflow — it is not sensitive.

## Notes on AMI / instance type

The PDF lists two reference AMIs for `us-west-2` (AL2023). At apply time:

- `ami-023a34a1153befb51` (arm64, paired with `t4g.nano`) — exists, but `t4g.nano` is not Free Tier eligible. Accounts on a Free Tier restriction will get `InvalidParameterCombination`.
- `ami-05572e392e21e0843` (x86_64, paired with `t3.micro`) — has been deregistered by AWS (`InvalidAMIID.NotFound`).

This deployment uses **`ami-0fa1ce9aa6f270301`** (current AL2023 x86_64 in `us-west-2`) with **`t3.micro`** (Free Tier eligible). Any AL2023 AMI matching the chosen architecture works — swap as needed via `dev.tfvars`.

## Evidence

`aws ec2 describe-instances` output (`infra/evidence/instance.txt`):

```
-----------------------------------------------------
|                 DescribeInstances                 |
+----------------------+----------+-----------------+
|  i-0612676e01cc554ad |  running |  44.243.171.83  |
+----------------------+----------+-----------------+
```

Endpoint checks:

```bash
$ curl http://44.243.171.83:8080/health
{"status":"ok","compute":"ec2"}

$ curl -X POST http://44.243.171.83:8080/echo \
    -H 'Content-Type: application/json' -d '{"msg":"hello"}'
{"msg":"hello","compute":"ec2"}
```

Both responses include the `compute` field with value `ec2`, matching the acceptance criteria. Resources were destroyed with `terraform destroy -var-file=envs/dev/dev.tfvars` after capturing the evidence above.
