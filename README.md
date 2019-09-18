# KeepalivedOnOCI

Create a Keepalived cluster on an existing Regional Private Subnet with a floating secondary IP.

## Acknowledgement: 
Folks who contributed with code, feedback, ideas, testing etc:
-  Jeet Jagasia

## Pre-requisites
1. [Download and install Terraform](https://www.terraform.io/downloads.html) (v0.11.8 or later v0.11.X versions)

2. Export OCI credentials using guidance at [Export Credentials](https://www.terraform.io/docs/providers/oci/index.html).
You must use an Admin User account to launch this terraform environment. You may update the credentials in env-vars.sh file and run it to set environment variables for this setup.

3. The tenancy used for provisoning must have service limits increased to accomodate the build. 

Refer the link [here](https://github.com/oracle/oci-quickstart-prerequisites) for detailed instructions on setting up terraform.

4. Create or chose existing Regional Public Subnet where Bastion and Regional Private Subnet where ES Master and Data nodes are to be launched. 

5. Tag (freeform-tag) the Regional Public and Private Subnets then update the corresponding variables on terraform.tfvars file:
This module automatically finds the Subnets using the free-form tags you specified on the subnets.

```
# Free Form tags set on your Regional Subnets
RegionalPrivateKey = "<Key>"
RegionalPrivateValue = "<Value>"
RegionalPublicKey = "<Key>"
RegionalPublicValue = "<Value>"
```
Refer: https://docs.cloud.oracle.com/iaas/Content/General/Concepts/resourcetags.htm#workingtags


