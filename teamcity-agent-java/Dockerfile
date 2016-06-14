FROM java:9-jdk
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
ENV TEAMCITY_SERVER_URL           http://localhost
ENV TERM                          dumb
WORKDIR /data
