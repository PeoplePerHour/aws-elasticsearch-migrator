#!/bin/bash
envsubst < /logstash.conf.example > /logstash.conf
exec logstash -f /logstash.conf
