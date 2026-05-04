# Deployment of three FortiGate-VMs (BYOL/PAYG) on AWS with GWLB integration in Cross-AZ scenario
## Introduction
A Terraform script to deploy three FortiGate-VMs in three different AZs on AWS with Gateway Load Balancer integration.

## Requirements
* [Terraform](https://learn.hashicorp.com/terraform/getting-started/install.html) >= 1.0.0
* Terraform Provider AWS >= 3.63.0
* Terraform Provider Template >= 2.2.0
* Terraform Provider Null >= 3.2.0
* FOS Version >= 6.4.4
* Create an ssh key for FortiGate VM, update the keyname in terraform.tfvars
* AWS CLI configured with SSO profile (`aws sso login --profile fortinet-admin`) or switch to use accesskey secretkey in provider

## Deployment overview
Terraform deploys the following components:
   * 2 AWS VPCs
        - Customer VPC with 3 public subnets and 3 private subnets split across three different AZs
           - 1 Internet Gateway
           - 1 Route table with edge association with Internet Gateway, and 3 internal routes with target to Gateway Load Balancer Endpoint.
           - 3 Route tables with private subnets association for each AZ, and default route with target to each AZ's Gateway Load Balancer Endpoint.
           - 1 Route table with public subnet association, and default route with target to Internet Gateway.
        - FGT VPC with 3 public and 3 private subnets in three different AZs. 
           - 1 Internet Gateway
           - 3 Route tables with private subnets association for each AZ, and default route with target to each AZ's FortiGate private port.
           - 1 Route table with public subnets association, and default route with target to Internet Gateway. 
   * Three FortiGate-VM each instance with 2 NICs
     - port1 on public subnet and port2 on private subnet in different AZ.
     - port2 will be in its own FG-traffic vdom.
     - Three GENEVE interfaces will be created base on port2 during bootstrap and this will be the interface where traffic will received from the Gateway Load Balancer.
   * Two Network Security Group rules: one for external, one for internal.
   * One Gateway Load Balancer with three targets to three FortiGates (one per AZ).
   * Optional: Customer VPC deployment can be skipped by setting `deploy_customer_vpc = false`

### AWS SSO Authentication

This project uses AWS SSO profile for authentication. Before deploying:

1. Ensure AWS CLI is configured with your SSO profile
2. Login with: `aws sso login --profile fortinet-admin`
3. Verify credentials: `aws sts get-caller-identity --profile fortinet-admin`

To use a different SSO profile, update the `profile` setting in `provider.tf`.


## Topology overview
Customer VPC (20.1.0.0/16)  
   * public-az1   (20.1.0.0/24)
   * private-az1  (20.1.1.0/24)
   * public-az2   (20.1.2.0/24)
   * private-az2  (20.1.3.0/24)
   * public-az3   (20.1.4.0/24)
   * private-az3  (20.1.5.0/24)
   
Security VPC (10.1.0.0/16)
   * public-az1   (10.1.0.0/24)
   * private-az1  (10.1.1.0/24)
   * public-az2   (10.1.2.0/24)
   * private-az2  (10.1.3.0/24)
   * public-az3   (10.1.4.0/24)
   * private-az3  (10.1.5.0/24)

FortiGate VMs are deployed in Security VPC on both public and private subnets.
One FortiGate VM is deployed in each AZ (3 total). 
Server(s) are deployed in the private subnet in the Customer VPC in different AZ.

Ingress traffic to the Server(s) located in the private subnet in Customer VPC will be routed to GWLB, redirect to FortiGate-VM's GENEVE interface and send back out to GWLB endpoint.
Egress traffic from the Server(s) located in the private subnet in Customer VPC will be routed to GWLB and redirect to FortiGate-VM's GENEVE interface and send back out to GWLB endpoint.

**GWLB Health Check Settings:**
- Protocol: TCP
- Port: 8008 (FortiGate health check port)
- Interval: 5 seconds
- Unhealthy threshold: 2
- Healthy threshold: 2

![gwlb-az-architecture](./aws-gwlb-crossaz.png?raw=true "GWLB Architecture")

## Deployment
To deploy the FortiGate-VMs to AWS:

1. **Login with AWS SSO:**
   ```sh
   aws sso login --profile fortinet-admin
   ```

2. Clone the repository.

3. Customize variables in the `terraform.tfvars.example` and `variables.tf` file as needed. And rename `terraform.tfvars.example` to `terraform.tfvars`.
> [!NOTE]    
> In the license_format variable, there are two different choices.   
> Either token or file. Token is FortiFlex token, and file is FortiGate-VM license file.
3. Initialize the providers and modules:
   ```sh
   $ cd XXXXX
   $ terraform init
    ```
4. Submit the Terraform plan:
   ```sh
   $ terraform plan
   ```
5. Verify output.
6. Confirm and apply the plan:
   ```sh
   $ terraform apply
   ```
7. If output is satisfactory, type `yes`.

### Customer VPC Deployment Control

Use the `deploy_customer_vpc` variable to control whether Customer VPC resources are deployed:

**For Testing/Development (deploy_customer_vpc = true):**
- Deploys both FGT VPC and Customer VPC with Apache web server
- Useful for verifying GWLB traffic routing
- Apache server serves as a test target for traffic inspection

**For Production (deploy_customer_vpc = false):**
- Deploys only FGT VPC with FortiGate VMs and GWLB
- Skip this if Customer VPC already exists
- Integrate with existing Customer VPC by configuring GWLB endpoints manually

Example for production deployment:
```sh
$ terraform apply -var="deploy_customer_vpc=false"
```

### Syslog Proxy Setup

The syslog proxy collects FortiGate logs and forwards them to a cross-account S3 bucket. Set `deploy_syslog_proxy = true` in `terraform.tfvars` and fill in the required variables.

#### Target Account Setup (Required)

Before deploying, the **target AWS account** must create an S3 bucket (if not already created) and an IAM role to allow the syslog proxy VM to upload logs:

1. **Create the S3 bucket** (if not already existing):
   - Open the **S3 Console** in the target account
   - Create a bucket with server-side encryption enabled (SSE-KMS recommended)
   - If using KMS, note the KMS key ARN — you'll need it in step 4

2. Open the **IAM Console** in the target account
3. Go to **Roles** → **Create role**
4. Select **Another AWS account** and enter the source account ID (the account running this Terraform)
5. Do **not** attach any managed policies — skip to step 6
6. Name the role (default: `SyslogLogUploader`) and create it
7. Edit the role's **Trust relationships** policy to:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::<SOURCE_ACCOUNT_ID>:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
      }
    }
  ]
}
```

8. Add an **inline policy** to the role (assumes SSE-KMS encryption):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:ListBucket",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::<BUCKET_NAME>",
        "arn:aws:s3:::<BUCKET_NAME>/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:GenerateDataKey",
        "kms:Decrypt"
      ],
      "Resource": "*"
    }
  ]
}
```

#### Source Account Configuration

In `terraform.tfvars`, set:

```hcl
deploy_syslog_proxy          = true
syslog_s3_bucket_name        = "your-logs-bucket-name"
syslog_s3_bucket_region      = "ap-east-1"
syslog_target_account_id     = "123456789012"
syslog_cross_account_role_name = "SyslogLogUploader"
```

> **Note:** `syslog_cross_account_role_name` must match the role name created in the target account.

#### How It Works

- FortiGate VMs forward traffic and UTM logs to the syslog proxy via TCP 514 (reliable mode)
- syslog-ng on the proxy receives logs and writes them to `/var/log/fortigate/<FGT-IP>/fortigate.log`
- Every 10 minutes, a cron job rotates the active log file, uploads it to S3 using AssumeRole credentials, and deletes the local copy
- Log files are stored in S3 at: `s3://<bucket>/fortigate-logs/<FGT-IP>/fortigate_YYYYMMDD_HHMM`

Output will include the information necessary to log in to the FortiGate-VM instances:
```sh
Outputs:

CustomerVPC = <Customer VPC ID>              # Only when deploy_customer_vpc = true
FGT1PublicIP = <FGT1 Public IP>
FGT2PublicIP = <FGT2 Public IP>
FGT3PublicIP = <FGT3 Public IP>
FGTVPC = <FGT VPC ID>
LoadBalancerPrivateIPAZ1 = <Private Load Balancer AZ1 IP>
LoadBalancerPrivateIPAZ2 = <Private Load Balancer AZ2 IP>
LoadBalancerPrivateIPAZ3 = <Private Load Balancer AZ3 IP>
Password_for_FGT1 = <FGT1 Password>
Password_for_FGT2 = <FGT2 Password>
Password_for_FGT3 = <FGT3 Password>
Username = <FGT Username>
ApacheServerPublicIP = <Apache Server Public IP>   # Only when deploy_customer_vpc = true
ApacheServerPrivateIP = <Apache Server Private IP> # Only when deploy_customer_vpc = true
SyslogProxyPrivateIP = <Syslog Proxy Private IP>   # Only when deploy_syslog_proxy = true
SyslogProxyInstanceId = <Syslog Proxy Instance ID> # Only when deploy_syslog_proxy = true

```

## Destroy the instance
To destroy the instance, use the command:
```sh
$ terraform destroy
```
