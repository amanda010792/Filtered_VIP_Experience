# Filtered_VIP_Experience
Tutorial of VIP Experience Using ksqlDB and Flink 

## Pre-Requisites 

###### Login to confluent cloud 
```
confluent login --save
```

###### Ensure Terraform 0.14+ is installed

Install Terraform version manager [tfutils/tfenv](https://github.com/tfutils/tfenv)

Alternatively, install the [Terraform CLI](https://learn.hashicorp.com/tutorials/terraform/install-cli?_ga=2.42178277.1311939475.1662583790-739072507.1660226902#install-terraform)

To ensure you're using the acceptable version of Terraform you may run the following command:
```
terraform version
```
Your output should resemble: 
```
Terraform v0.14.0 # any version >= v0.14.0 is OK
```
###### Create a Cloud API Key 

1. Open the Confluent Cloud Console
2. In the top right menu, select "API Keys"
3. Choose "Add API Key"
4. Under Account, select "Service Account" and "New Service Account", naming it "<YOUR_NAME>-terraform-vip-tutorial" and click "Next"
5. For Resource Scope, select "Cloud Resource Management" and click "Next"
6. Click Complete
7. In the top right menu, select "Accounts and Access"
8. Under "Access" select your Organization and and select "Add Role Assignment"
9. Select the Service Account created above and grant the resource "OrganizationAdmin" rights.
10. Optionally, add a name for the API Key and click "Create API Key and Download". Save your key details and insert them into the env.sh script

###### Source Environment Variables 

Once you have added the API Key and Secret you created above to your env.sh script, run the following command to source the variables: 
```
source env.sh
```

## Run Remaining Lab 

Once your prerequisites are complete, navigate to the ksql and/or flink directories to run the tutorial(s) of choice. 

