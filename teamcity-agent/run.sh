#!/bin/bash

if [ -d "/tmp/test-services" ]; then
  rm -rf /tmp/test-services;
fi

mkdir /tmp/test-services -p;

export TEAMCITY_AGENT_DIR=/tmp/test-services
export TEAMCITY_AGENT_NAME=test-agent
export TEAMCITY_SERVER_URL="http://localhost"

case $1 in
    "run")
        docker-compose run
        exit $?
        ;;
    *)
        docker-compose build
        ;;
esac
