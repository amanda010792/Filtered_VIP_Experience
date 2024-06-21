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
# ksqlDB Workshop 

## Introduction 

Apache Flink® is a powerful, scalable stream processing framework for running complex, stateful, low-latency streaming applications on large volumes of data. Flink excels at complex, high-performance, mission-critical streaming workloads and is used by many companies for production stream processing applications. Flink is the de facto industry standard for stream processing.

Confluent Cloud provides a cloud-native, serverless service for Flink that enables simple, scalable, and secure stream processing that integrates seamlessly with Apache Kafka®. Your Kafka topics appear automatically as queryable Flink tables, with schemas and metadata attached by Confluent Cloud.

Confluent Cloud for Apache Flink currently supports Flink SQL.  

## testing the setup

First things first, let’s get connected to the lab environment and make sure we have access to everything we need.     

### Open the Confluent Cloud Dashboard 

Prior to the workshop you should have recieved an email to login to Confluent Cloud. To ensure you have the necessary access, navigate to the [Confluent Cloud Dashboard](https://confluent.cloud/) and confirm the following:     
- There is an environment created entitled "vip_dev_flink_env"     
- Ensure there is a cluster called "vip_transformations" 
- Open the cluster and ensure you have the appropriate Connectors (2 datagen connectors) and topics (2 topics) set up.    
- In the "vip_dev_flink_env" ensure there is a Flink Compute pool set up.    

### Syntax Reference

You will find it helpful to keep a copy of the [Flink Syntax Guide](https://docs.confluent.io/cloud/current/flink/reference/overview.html)

## Flink

### Looking Around

You will see 3 tabs in the Flink UI: 
- Compute Pools: A compute pool in Confluent Cloud for Apache Flink® represents a set of compute resources bound to a region that is used to run your SQL statements. The resources provided by a compute pool are shared between all statements that use it. The statements using a compute pool can only read and write Apache Kafka® topics in the same region as the compute pool.
- Flink Statements: A statement represents a high-level resource that’s created by Confluent Cloud when you enter a SQL query.
- API Keys: Programmatic way of interacting with Confluent Cloud for Apache Flink®

To perform queries on the UI, we can enter into the SQL workspace by going to our Compute Pool and clicking "Open SQL Workspace". In the top right corner of the workspace you will Use "vip_dev_flink_env" for your catalog (this is equivalent to an environment in Confluent Cloud) and "vip_transformations" as your database (this is equivalent to a cluster in Confluent Cloud). 

On the left-hand menu of the workspace we see our Catalogs (automatically imported from our clusters). We can also see that in our VIP transformations database we already have our users and ratings topics imported as tables. 


### See available kafka topics and data 

To see all available tables in the current database, run the following command: 
```
show tables;
```

The list of topics you see here is exactly the same as you would see in the 'Topics' section of Cloud Dashboard.      

We can also investigate some data from those topics before working with them:      
```
select * from ratings;
select * from users;
```
The event stream driving this example (the data in the ratings topic) is a simulated stream of events representing the ratings left by users on a mobile app or website, with fields including the device type that they used, the star rating (a score from 1 to 5), and an optional comment associated with the rating.     
  


## Explore the data  

### Filter iOS data
We can filter out ratings data to see only iOS data by running the following query: 
```
select *
from ratings
where channel like 'iOS%';
```

### Filter only VIP users
In our users data we have a "level" field that indicates which users are VIP (or "Platinum" level): 
```
select *
from users
where level like 'Platinum';
```

### Identify the Unhappy Customers

Now that we have both our ratings and our user data, we can join them together to find out details about the users who are posting negative reviews, and see if any of them are our valued platinum customers. We start by finding just the low-scoring ratings (play around with the where clause conditions to experiment).     

```
select * from ratings where stars < 3 and channel like 'iOS%' limit 5;
```

We can create a table where we will store these poor ratings: 
```
CREATE TABLE poor_ratings(
  key BYTES,
  rating_id BIGINT NOT NULL,
  user_id INT NOT NULL,
  stars INT NOT NULL,
  route_id INT NOT NULL,
  rating_time BIGINT NOT NULL,
  channel STRING NOT NULL,
  message STRING NOT NULL);
```

Next, let's insert into our poor_ratings stream based on our query above
```
INSERT INTO poor_ratings SELECT * FROM ratings WHERE stars < 3 and channel like 'iOS%';

```
We can see data in our poor_ratings stream by querying our new table: 
```
SELECT * FROM poor_ratings;
```
How can we see the users who posted a poor rating? To answer this we need to join our users table:     
```
select r.user_id, u.first_name, u.last_name, u.level, r.stars
from poor_ratings r
left join users_tbl u
on r.user_id = u.user_id;
```

Next, to identify our vip users posting poor ratings, we can run the following query: 

```
select r.user_id, u.first_name, u.last_name, u.level, r.stars
from poor_ratings r
inner join users u
on r.user_id = u.user_id
where u.level like 'Platinum';
```

We can store this into a table called unhappy_vips by creating a table and then inserting our query results into it: 
```
CREATE TABLE unhappy_vips(
  user_id INT NOT NULL,
  first_name STRING NOT NULL,
  last_name STRING NOT NULL,
  level STRING NOT NULL,
  stars INT NOT NULL);

INSERT INTO unhappy_vips
SELECT r.user_id, u.first_name, u.last_name, u.level, r.stars
FROM poor_ratings r
INNER JOIN users u
ON r.user_id = u.user_id
WHERE u.level like 'Platinum';
```

Query the unhappy_vips table to get a feel for the data in it: 
```
select * from unhappy_vips;
```

We now have a topic with unhappy vip customers (called unhappy_vips) that we can use to connect a downstream application that offers a customer service reward to repair the relationship with these unhappy customers. 

