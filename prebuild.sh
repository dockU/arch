#!/usr/bin/env bash

cd $(dirname "${BASH_SOURCE[0]}")
docker.io run -privileged -t -i -v $(pwd):/opt/mkimage docku/arch /opt/mkimage/mkimage.sh

