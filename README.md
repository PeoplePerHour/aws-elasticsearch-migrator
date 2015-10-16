## AWS ElasticSearch Service migrator

A container image and systemd service to ease migration from an ElasticSearch cluster to AWS ElasticSearch service.

### AWS ES migration Details & implementation

Some facts on AWS ES Service - note that these stand since its launch, will change in the future:

#### AWS ES 

* AWS ES is on 1.5.2 
* has Kibana 4.0.3 as a plugin built-in
* supports specific operations via `es:*` actions
* runs via HTTP on port 80, without SSL
* resides in its own VPC, you cannot run it currently in your VPCs
* access to AWS ES can either be done via URL Signing with proper keys that allow operations to the AWS ES arn or
* access is given adding Static IPs whitelist in its Domain Access Policy
* access via IAM instance profiles is not supported

#### Pains

* AWS ES service is "old".
* Kibana 4.2.0 will require ElasticSearch 2.0 (which brings a lot of goodies). We find that it's highly possible that ES 2.0 + Kibana 4.2.0 not supported will be a reason to judge against AWS ES.
* Not having it in your own VPC is a pain in architectures that are confined in-VPC and do not use a set of Public IP + Internet Gateway or a NAT Instance + proper Route Table scheme, or HTTP Proxy/Squid in ASG + proper route table scheme.
* Not supporting SSL is bad.
* Not supporting access via instance profiles is bad.

### Migrating 

We run our ELK stack on ES 1.7.x thus needed to re-index, that does not necessarily hold true for all use cases, but for most clusters running different versions re-indexing is the way to go.

Our approach is to use Logstash with an elasticsearch input fetching from our original ES cluster and an amazon_es output feeding the AWS ES cluster.

Amazon has released a useful Logstash output plugin that automatically signs HTTP requests to AWS ES data sink, naturally this is what we use for output, ensuring we keep the same `document_type`, `document_id` and `index`.

A Docker container image was created in peopleperhour/aws-elasticsearch-migrator that allows specifying via environment variables the following:

```
ES_HOSTS    => a comma-separated list of ES hosts, we use an ELB infront of our original cluster so we point to that ELB, default "localhost"
ES_PORT     => the origin ES listening port, default "9200"
ES_SCAN     => default "true"
ES_SIZE     => document count returned in scan, default "1000"
ES_SCROLL   => scroll time, default "5m"
ES_INDEX    => index to migrate, accepts wildcards, default "logstash-*"

AWS_ES_HOSTS          => a comma-separated host of AWS ElasticSearch service Domains, default "search-elk-setMeInYourEnv.us-east-1.es.amazonaws.com"
AWS_ACCESS_KEY_ID     => Access Key of an IAM that has proper `es:*` actions allowed
AWS_SECRET_ACCESS_KEY => Secret Access Key of an IAM that has proper `es:*` actions allowed
AWS_DEFAULT_REGION    => AWS ElasticSearch service Domain region, default "us-east-1"
```


#### Running the migrator container

```
docker run -it --rm --name=aws-elasticsearch-migrator \
           -e AWS_ACCESS_KEY_ID=foo \
           -e AWS_SECRET_ACCESS_KEY=bar \
           -e ES_HOSTS="url-of-your-current-es-cluster" \
           -e ES_PORT=9200 \
           -e ES_INDEX="logstash-*" \
           -e ES_SCAN=true \
           -e ES_SIZE=1000 \
           -e ES_SCROLL=5m \
           -e AWS_ES_HOSTS="the-endpoint-of-your-aws-es-domain" \
           peopleperhour/aws-elasticsearch-migrator
```

#### systemd service example

```
[Unit]
Description=Migrate ElasticSearch to AWS
After=docker.service

[Service]
User=core
ExecStartPre=/usr/bin/docker pull peopleperhour/aws-elasticsearch-migrator
ExecStart=/usr/bin/docker run --name migrator -e AWS_ACCESS_KEY_ID=foo -e ...  -e ... peopleperhour/aws-elasticsearch-migrator
ExecStop=/usr/bin/docker stop migrator
ExecStopPost=/usr/bin/docker rm migrator

[Install]
WantedBy=local.target
```

### Notes:

With the migrator's default settings, on a cluster of 3 x m4.large nodes with gp2 SSD EBS volumes containing 80 million documents, in 98 shards and 8 indexes at around 72GB size (not counting replication size) migrating to AWS ES cluster in the same region in a Domain of 3 * m3.large nodes with gp2 SSD EBS volumes took about 6hrs.

You can tweak the settings to achieve what you want in a better fashion that suits your use case.


### Contributing

Developed by [PeoplePerHour][] DevOps team to be used in transitioning from our self-managed ElasticSearch cluster AWS ElasticSearch Service handling ELK for
[PeoplePerHour][] and [SuperTasker][] micro-SOA logs.

Contributions are more than welcome.

[PeoplePerHour]: https://www.peopleperhour.com
[SuperTasker]: https://www.supertasker.com
