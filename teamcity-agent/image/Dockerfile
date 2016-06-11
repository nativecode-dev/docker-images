# Based on https://github.com/sjoerdmulder/teamcity-agent-docker.git
FROM ubuntu:xenial
MAINTAINER support@nativecode.com

##
# Setup some environment variables we'll need later.
#   GOSU_VERSION            version of gosu to install.
#   NODE_VERSION            version of node js to install.
#   NODE_NPM_VERSION        version of npm to install.
#   TEAMCITY_AGENT_PATH     root of the agent files.
#   TEAMCITY_SERVER_URL     URL where the agent can contact TeamCity.
##
ENV GOSU_VERSION                  1.7
ENV NODE_NPM_VERSION              3.5.2
ENV NODE_VERSION                  4.4.4
ENV TEAMCITY_SERVER_PATH          http://localhost
ENV TERM                          dumb
WORKDIR /data

RUN set -x \
  # Base install updates and dependencies.
  && apt-get update \
  && apt-get -y install \
      apt-utils \
      apt-transport-https \
      aufs-tools \
      ca-certificates \
      cgroup-lite \
      cgroupfs-mount \
      curl \
      dnsutils \
      git-core \
      iputils-ping \
      libltdl7 \
      python-software-properties \
      software-properties-common \
      sudo \
      unzip \
      wget \
      zip \
  # We need a new context for the following commands, so we use a
  # semi-colon before continuing.
  # Add key and repository for the official docker packages.
  ; apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 \
      --recv-keys 58118E89F3A912897C070ADBF76221572C52609D \
  && echo "deb https://apt.dockerproject.org/repo ubuntu-wily main" \
      >> /etc/apt/sources.list.d/docker.list \
  # Make sure we have the repositories indexed.
  && apt-get update \
  # Install depedencies from universe.
  && apt-get -y install \
      build-essential \
      default-jdk \
      default-jre \
      docker-engine \
      mono-complete \
      perl \
      python \
      python-pip \
  # Add a teamcity user and add to the sudo and docker groups.
  && adduser --disabled-password --gecos "" teamcity \
  && sed -i -e "s/%sudo.*$/%sudo ALL=(ALL:ALL) NOPASSWD:ALL/" /etc/sudoers \
  && usermod -a -G docker,sudo teamcity \
  # Generate a list of installed packages for this image version.
  && dpkg --get-selections | grep -v deinstall >> /data/packages.list \
  # Set docker to start when the system starts.
  && systemctl enable docker \
  # Create key for the node js repository.
  && for key in \
    9554F04D7259F04124DE6B476D5A82AC7E37093B \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    0034A06D9D9B0064CE8ADF6BF1747F4AD2306D93 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
  ; do \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
  done \
  # Download and install node.js.
  && curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.gz" \
  && curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --verify SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-x64.tar.gz\$" SHASUMS256.txt.asc | sha256sum -c - \
  && tar -xzf "node-v$NODE_VERSION-linux-x64.tar.gz" -C /usr/local --strip-components=1 \
  && rm "node-v$NODE_VERSION-linux-x64.tar.gz" SHASUMS256.txt.asc \
  # Install nodejs global dependencies.
  && npm install --global "npm@$NODE_NPM_VERSION" \
  && npm install --global \
      grunt-cli gulp-cli \
  && npm cache clear \
  # Install gosu
  && wget -O /usr/local/bin/gosu \
      "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
  && wget -O /usr/local/bin/gosu.asc \
      "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
  && export GNUPGHOME="$(mktemp -d)" \
  && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
  && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
  && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
  && chmod +x /usr/local/bin/gosu \
  && gosu nobody true \
;

# Add files to image and set the entry point, volumes, and posts.
ADD docker-entrypoint.sh /docker-entrypoint.sh
ADD wrapdocker /usr/local/bin/wrapdocker
ENTRYPOINT /docker-entrypoint.sh
VOLUME /var/lib/docker
VOLUME /data
EXPOSE 9090
