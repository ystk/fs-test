#!/bin/sh
. ./config.sh

if [ ! $1 ]; then
	echo "Please specify dist_dir"
	echo "Usage: $0 dist_dir"
	exit 0
fi

if [ ! -d $1 ]; then
	mkdir $1
fi

cp $BASE_DIR/result* $1
cp $BASE_DIR/stat* $1 
cp $BASE_DIR/wstat* $1 
cp $BASE_DIR/wstat* $1 
cp $BASE_DIR/log* $1 
cp $BASE_DIR/count* $1 
cp $BASE_DIR/param* $1 
cp -r $BASE_DIR/error $1
