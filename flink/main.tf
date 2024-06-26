# Configure the Confluent Provider
terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "1.77.0"
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

# spin up environment called "vip_dev_flink_env"
resource "confluent_environment" "vip_dev_flink_env" {
  display_name = "vip_dev_flink_env"
}

# spin up kafka cluster called "basic" in vip dev envrionment (above)
resource "confluent_kafka_cluster" "basic" {
  display_name = "vip_transformations"
  availability = "SINGLE_ZONE"
  cloud        = "AWS"
  region       = "us-east-2"
  basic {}

  environment {
    id = confluent_environment.vip_dev_flink_env.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

data "confluent_schema_registry_region" "sr_region" {
  cloud   = "AWS"
  region  = "us-east-2"
  package = "ESSENTIALS"
}

resource "confluent_schema_registry_cluster" "essentials" {
  package = data.confluent_schema_registry_region.sr_region.package

  environment {
    id = confluent_environment.vip_dev_flink_env.id
  }

  region {
    id = data.confluent_schema_registry_region.sr_region.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

# create a service account called topic manager 
resource "confluent_service_account" "flink-topic-manager" {
  display_name = "flink-topic-manager"
  description  = "Service account to manage Kafka cluster topics"
}

# create a role binding for topic manager service account (created above) that has cloud cluster admin access to basic cluster (created above)
resource "confluent_role_binding" "flink-topic-manager-kafka-cluster" {
  principal   = "User:${confluent_service_account.flink-topic-manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.basic.rbac_crn
}

# create an api key for the topic manager service account (created above) 
resource "confluent_api_key" "flink-topic-manager-kafka-api-key" {
  display_name = "flink-topic-manager-kafka-api-key"
  description  = "Kafka API Key that is owned by 'flink-topic-manager' service account"
  owner {
    id          = confluent_service_account.flink-topic-manager.id
    api_version = confluent_service_account.flink-topic-manager.api_version
    kind        = confluent_service_account.flink-topic-manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.basic.id
    api_version = confluent_kafka_cluster.basic.api_version
    kind        = confluent_kafka_cluster.basic.kind

    environment {
      id = confluent_environment.vip_dev_flink_env.id
    }
  }

  depends_on = [
    confluent_role_binding.flink-topic-manager-kafka-cluster
  ]
}


# create a topic called ratings using the api key (created above)
resource "confluent_kafka_topic" "ratings" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  topic_name    = "ratings"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.flink-topic-manager-kafka-api-key.id
    secret = confluent_api_key.flink-topic-manager-kafka-api-key.secret
  }
}

# create a kafka topic called users using the api key (created above)
resource "confluent_kafka_topic" "users" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  topic_name    = "users"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.flink-topic-manager-kafka-api-key.id
    secret = confluent_api_key.flink-topic-manager-kafka-api-key.secret
  }
}

# create a service account called "flink-connect-manager"
resource "confluent_service_account" "flink-connect-manager" {
  display_name = "flink-connect-manager"
  description  = "Service account to manage Kafka cluster"
}

# create a role binding to the flink-connect-manager service account (created above) to give it cluster admin access for basic cluster (created above)
resource "confluent_role_binding" "flink-connect-manager-kafka-cluster" {
  principal   = "User:${confluent_service_account.flink-connect-manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.basic.rbac_crn
}

# create an api key for the flink-connect-manager service account (created above)
resource "confluent_api_key" "flink-connect-manager-kafka-api-key" {
  display_name = "flink-connect-manager-kafka-api-key-instructor"
  description  = "Kafka API Key that is owned by 'flink-connect-manager' service account"
  owner {
    id          = confluent_service_account.flink-connect-manager.id
    api_version = confluent_service_account.flink-connect-manager.api_version
    kind        = confluent_service_account.flink-connect-manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.basic.id
    api_version = confluent_kafka_cluster.basic.api_version
    kind        = confluent_kafka_cluster.basic.kind

    environment {
      id = confluent_environment.vip_dev_flink_env.id
    }
  }

  depends_on = [
    confluent_role_binding.flink-connect-manager-kafka-cluster
  ]
}

# create a service account called "flink-application-connector"
resource "confluent_service_account" "flink-application-connector" {
  display_name = "flink-application-connector"
  description  = "Service account for Datagen Connectors"
}

# create an api key tied to the flink-application-connector service account (created above)
resource "confluent_api_key" "flink-application-connector-kafka-api-key" {
  display_name = "flink-application-connector-kafka-api-key"
  description  = "Kafka API Key that is owned by 'flink-application-connector' service account"
  owner {
    id          = confluent_service_account.flink-application-connector.id
    api_version = confluent_service_account.flink-application-connector.api_version
    kind        = confluent_service_account.flink-application-connector.kind
  }
 managed_resource {
    id          = confluent_kafka_cluster.basic.id
    api_version = confluent_kafka_cluster.basic.api_version
    kind        = confluent_kafka_cluster.basic.kind

    environment {
      id = confluent_environment.vip_dev_flink_env.id
    }
  }
}

# created an ACL called "flink-application-connector-describe-on-cluster" that grants the flink-application-connector service account describe permission on the basic cluster (created above)
resource "confluent_kafka_acl" "flink-application-connector-describe-on-cluster" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "CLUSTER"
  resource_name = "kafka-cluster"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.flink-application-connector.id}"
  host          = "*"
  operation     = "DESCRIBE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.flink-connect-manager-kafka-api-key.id
    secret = confluent_api_key.flink-connect-manager-kafka-api-key.secret
  }
}

# created an ACL called "flink-application-connector-write-on-ratings" that grants the flink-application-connector service account write permission on the ratings topic (created above)
resource "confluent_kafka_acl" "flink-application-connector-write-on-ratings" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.ratings.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.flink-application-connector.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.flink-connect-manager-kafka-api-key.id
    secret = confluent_api_key.flink-connect-manager-kafka-api-key.secret
  }
}

# created an ACL called "flink-application-connector-write-on-users" that grants the flink-application-connector service account write permission on the users topic (created above)
resource "confluent_kafka_acl" "flink-application-connector-write-on-users" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.users.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.flink-application-connector.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.flink-connect-manager-kafka-api-key.id
    secret = confluent_api_key.flink-connect-manager-kafka-api-key.secret
  }
}

# created an ACL called "flink-application-connector-create-on-data-preview-topics" that grants the application-connector service account create permission on the preview topics 
resource "confluent_kafka_acl" "flink-application-connector-create-on-data-preview-topics" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  resource_name = "data-preview"
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.flink-application-connector.id}"
  host          = "*"
  operation     = "CREATE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.flink-connect-manager-kafka-api-key.id
    secret = confluent_api_key.flink-connect-manager-kafka-api-key.secret
  }
}

# created an ACL called "flink-application-connector-write-on-data-preview-topics" that grants the application-connector service account write permission on the preview topics 
resource "confluent_kafka_acl" "flink-application-connector-write-on-data-preview-topics" {
  count = length(confluent_kafka_cluster.basic)
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  resource_name = "data-preview"
  pattern_type  = "PREFIXED"
  principal     = "User:${confluent_service_account.flink-application-connector.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.flink-connect-manager-kafka-api-key.id
    secret = confluent_api_key.flink-connect-manager-kafka-api-key.secret
  }
}

# create a connector called "ratings_source" that creates a datagen connector called "DatagenSourceConnector_ratings" using the ratings quickstart of datagen and writes to the ratings topic (depends on acls above)
resource "confluent_connector" "ratings_source" {
  environment {
    id = confluent_environment.vip_dev_flink_env.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }

  config_nonsensitive = {
    "connector.class"          = "DatagenSource"
    "name"                     = "DatagenSourceConnector_ratings"
    "kafka.auth.mode"          = "SERVICE_ACCOUNT"
    "kafka.service.account.id" = confluent_service_account.flink-application-connector.id
    "kafka.topic"              = confluent_kafka_topic.ratings.topic_name
    "output.data.format"       = "AVRO"
    "quickstart"               = "RATINGS"
    "tasks.max"                = "1"
  }

  depends_on = [
    confluent_kafka_acl.flink-application-connector-describe-on-cluster,
    confluent_kafka_acl.flink-application-connector-write-on-ratings,
    confluent_kafka_acl.flink-application-connector-create-on-data-preview-topics,
    confluent_kafka_acl.flink-application-connector-write-on-data-preview-topics,
  ]
}


# create a connector called "users_source" that creates a datagen connector called "DatagenSourceConnector_users" using the users quickstart of datagen and writes to the users topic (depends on acls above)
resource "confluent_connector" "users_source" {
  environment {
    id = confluent_environment.vip_dev_flink_env.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }

  config_nonsensitive = {
    "connector.class"          = "DatagenSource"
    "name"                     = "DatagenSourceConnector_users"
    "kafka.auth.mode"          = "SERVICE_ACCOUNT"
    "kafka.service.account.id" = confluent_service_account.flink-application-connector.id
    "kafka.topic"              = confluent_kafka_topic.users.topic_name
    "output.data.format"       = "AVRO"
    "quickstart"               = "CLICKSTREAM_USERS"
    "tasks.max"                = "1"
  }

  depends_on = [
    confluent_kafka_acl.flink-application-connector-describe-on-cluster,
    confluent_kafka_acl.flink-application-connector-write-on-users,
    confluent_kafka_acl.flink-application-connector-create-on-data-preview-topics,
    confluent_kafka_acl.flink-application-connector-write-on-data-preview-topics,
  ]
}

resource "confluent_flink_compute_pool" "main" {
  display_name     = "standard_compute_pool"
  cloud            = "AWS"
  region           = "us-east-2"
  max_cfu          = 10
  environment {
    id = confluent_environment.vip_dev_flink_env.id
  }
}
