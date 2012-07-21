#!/bin/sh
if [ -z $1 ];then
  echo "Usage: $0 NAME"
  exit
fi
NAME="$1"
ln -s ../log/fs-test/config.pl .
ln -s ../log/fs-test/log*.txt .
ln -s ../results/fs-test/result*.tar.gz .
./cplog.sh
./check.sh $NAME
