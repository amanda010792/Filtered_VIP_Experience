## Set Up Tutorial Resources 
In the setup of the workshop you will be provisioning the following resources: 
- An environment called "vip_dev_ksql_env"
- A Kafka cluster 
- A ksqlDB cluster 
- Two topics 
- Two Datagen Source connectors to simulate mock data in the topics you created. 
- Necessary service accounts, API keys and ACLs. 


Install the confluent providers from the configuration.
```
terraform init
```

Apply terraform changes to deploy instructor environment
```
terraform apply
```
