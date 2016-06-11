#!/bin/bash

cd /opt/sinopia;

if [ ! -f "/data/sinopia/config.yaml" ]; then
  cat /opt/sinopia/conf.d/config.yaml | sed -e 's@{{PREFIX}}@'"$SINOPIA_PREFIX"'@' >> /data/sinopia/config.yaml;
fi

if [ ! -d "/data/sinopia/cache" ]; then
  mkdir -p /data/sinopia/cache;
  chown daemon:root /data/sinopia/cache;
  cat /opt/sinopia/conf.d/.sinopia-db.json >> /data/sinopia/cache/.sinopia-db.json;
fi

if [ ! -d "/data/sinopia/logs" ]; then
  mkdir -p /data/sinopia/logs;
  chown daemon:root /data/sinopia/logs;
fi

if [ ! -d "/data/sinopia/htpasswd" ]; then
  echo "admin:`mkpasswd --method=sha-512 admin`" >> /data/sinopia/htpasswd
  chown daemon:root /data/sinopia/htpasswd;
  chmod u=rw,g=rw,o=rw /data/sinopia/htpasswd;
  cat /data/sinopia/htpasswd;
fi

if [ ! -L "/opt/sinopia/htpasswd" ]; then
  ln -s /data/sinopia/htpasswd /opt/sinopia/htpasswd;
fi

echo "***********************************************************************************"
echo "***********************************************************************************"
cat /data/sinopia/config.yaml;
echo "***********************************************************************************"
echo "***********************************************************************************"

echo "Starting Sinopia..."
su - daemon -s /bin/bash -c "sinopia -c /data/sinopia/config.yaml";
