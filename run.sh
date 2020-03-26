#!/bin/bash

docker run -it --rm -p 1935:1935 -p 80:80 vod:ubuntu18.04 $@
