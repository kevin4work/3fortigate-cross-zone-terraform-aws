# Deployment of three FortiGate-VMs (BYOL/PAYG) on AWS with GWLB integration in Cross-AZ scenario
## Introduction
A Terraform script to deploy three FortiGate-VMs in three different AZs on AWS with Gateway Load Balancer integration.

## Requirements
* [Terraform](https://learn.hashicorp.com/terraform/getting-started/install.html) >= 1.0.0
* Terraform Provider AWS >= 3.63.0
* Terraform Provider Template >= 2.2.0
* Terraform Provider Null >= 3.2.0
* FOS Version >= 6.4.4

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
   * One Apache web server in Customer VPC private subnet for testing traffic routing through GWLB.
   * Optional: Customer VPC deployment can be skipped by setting `deploy_customer_vpc = false`


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
1. Clone the repository.
2. Customize variables in the `terraform.tfvars.example` and `variables.tf` file as needed.  And rename `terraform.tfvars.example` to `terraform.tfvars`.
> [!NOTE]    
> In the license_format variable, there are two different choices.   
> Either token or file.  Token is FortiFlex token, and file is FortiGate-VM license file.
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

Output will include the information necessary to log in to the FortiGate-VM instances:
```sh
Outputs:

CustomerVPC = <Customer VPC>
FGT1PublicIP = <FGT1 Public IP>
FGT2PublicIP = <FGT2 Public IP>
FGT3PublicIP = <FGT3 Public IP>
FGTVPC = <FGT VPC>
LoadBalancerPrivateIP = <Private Load Balancer IP>
Password_for_FGT1 = <FGT1 Password>
Password_for_FGT2 = <FGT2 Password>
Password_for_FGT3 = <FGT3 Password>
Username = <FGT Username>
ApacheServerPublicIP = <Apache Server Public IP>
ApacheServerPrivateIP = <Apache Server Private IP>

```

## Destroy the instance
To destroy the instance, use the command:
```sh
$ terraform destroy
```
