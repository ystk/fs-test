#!/bin/sh
. ./config.sh
rsync -atv log/log.txt root@$TARGET_IP:~/results/log-`date '+%Y%m%d%H%M'`.txt
