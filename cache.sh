#!/bin/bash
# ex URL=http://172.30.0.36:80/video/hello_src/index.m3u8 STREAM=hello ./cache.sh

docker run -it --rm -p 8080:80 -e URL=${URL} -e STREAM=${STREAM} vod:ubuntu18.04 supervisord -c /cache.conf
