#!/bin/bash

if [ -d "/tmp/test-services" ]; then
  rm -rf /tmp/test-services;
fi

mkdir /tmp/test-services -p;

TEAMCITY_AGENT_DIR=/tmp/test-services
TEAMCITY_AGENT_NAME=test-agent
TEAMCITY_SERVER_URL="http://localhost"

docker-compose up;
