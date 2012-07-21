#!/bin/sh
if [ -z $1 ];then
  echo 'Usage: $0 NAME'
  exit
fi
NAME="$1"
OUTFILE_LSTAT="lstat-${NAME}.csv"
OUTFILE_CHK="check-${NAME}.txt"

./mkcheck.sh $NAME $OUTFILE_CHK
./mkcsv.sh $NAME $OUTFILE_LSTAT

# echo -n 'SIZE ERROR in case 0:'
# egrep '^0' $OUTFILE_LSTAT | grep NG | wc -l
# echo -n 'SIZE ERROR in case 1:'
# egrep '^1' $OUTFILE_LSTAT | grep NG | wc -l
# echo -n 'SIZE ERROR in case 2:'
# egrep '^2' $OUTFILE_LSTAT | grep NG | wc -l
# echo -n 'SIZE ERROR in case 3:'
# egrep '^3' $OUTFILE_LSTAT | grep NG | wc -l

cp $OUTFILE_CHK ../../
cp $OUTFILE_LSTAT ../../

