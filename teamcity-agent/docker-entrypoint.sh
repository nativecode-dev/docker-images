#!/bin/bash

TEAMCITY_AGENT_PATH=/data

if [ ! -z "$TEAMCITY_AGENT_NAME" ]; then
  echo "Starting $TEAMCITY_AGENT_NAME...";
fi

if [ -z "$TEAMCITY_SERVER_URL" ]; then
    echo "TEAMCITY_SERVER_URL variable not set, launch with -e TEAMCITY_SERVER_URL=http://mybuildserver"
    exit 1
fi

if [ ! -d "$TEAMCITY_AGENT_PATH/bin" ]; then
    echo "$TEAMCITY_AGENT_PATH doesn't exist pulling build-agent from server $TEAMCITY_SERVER_URL";
    let waiting=0
    until curl -s -f -I -X GET $TEAMCITY_SERVER_URL/update/buildAgent.zip; do
        let waiting+=3
        sleep 3
        if [ $waiting -eq 120 ]; then
            echo "Teamcity server did not respond within 120 seconds"...
            exit 42
        fi
    done
    wget $TEAMCITY_SERVER_URL/update/buildAgent.zip && unzip -d $TEAMCITY_AGENT_PATH buildAgent.zip && rm buildAgent.zip
    if [ $? -gt 0 ]; then
      echo "Failed to unzip archive for agent."
      exit 1;
    fi
    chmod +x $TEAMCITY_AGENT_PATH/bin/agent.sh
    echo "serverUrl=${TEAMCITY_SERVER_URL}" > $TEAMCITY_AGENT_PATH/conf/buildAgent.properties
    if [ ! -z "$TEAMCITY_AGENT_NAME" ]; then
      echo "Setting agent name to $TEAMCITY_AGENT_NAME"
      echo "name=$TEAMCITY_AGENT_NAME" >> $TEAMCITY_AGENT_PATH/conf/buildAgent.properties
    fi
fi

echo "Starting buildagent..."
chown -R teamcity:teamcity $TEAMCITY_AGENT_PATH

wrapdocker gosu teamcity $TEAMCITY_AGENT_PATH/bin/agent.sh run
