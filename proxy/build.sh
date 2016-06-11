#!/bin/bash

case $1 in
    -d|--delete)
        echo "Delete"
        docker stop proxy;
        docker rm proxy;
        docker rmi proxy;
        docker rmi nativecode/proxy;
        docker rmi $(docker images --quiet --filter "dangling=true");
    ;;

    *)
        echo "Create"
        docker build -t nativecode/proxy:latest . ;
        docker run --name proxy -p 90:90 --rm \
            -v /var/run/docker.sock:/tmp/docker.sock:ro \
            nativecode/proxy:latest;
        docker exec -it proxy /bin/bash;
    ;;
esac
