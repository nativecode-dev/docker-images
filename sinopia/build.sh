#!/bin/bash

if [ -d "/tmp/test-services" ]; then
  rm -rf /tmp/test-services;
fi

mkdir /tmp/test-services -p;
chown daemon:root /tmp/test-services -R;

echo "Building container..."
docker build -t test/sinopia:latest .;

echo "Running container..."
docker run --name test-sinopia \
    -e SINOPIA_PREFIX="https://www.test.com" \
    --volume /tmp/test-services:/data/sinopia \
    --rm test/sinopia:latest;

docker rm test-sinopia;
