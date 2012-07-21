#!/bin/sh
if [ -z $1 ];then
  echo 'Usage: $0 NAME OUTFILE'
  exit
fi
if [ -z $2 ];then
  echo 'Usage: $0 NAME OUTFILE'
  exit
fi

NAME="$1"
OUTFILE="$2"
echo '----------------------------------------------------' > $OUTFILE
echo $NAME >> $OUTFILE
echo '----------------------------------------------------' >> $OUTFILE
echo -n 'LINES: ' >> $OUTFILE
find . -name 'lstat.txt' -exec cat {} \; | wc -l >> ${OUTFILE}
echo -n 'NG   : ' >> $OUTFILE
find . -name 'lstat.txt' -exec grep NG {} \; | wc -l >> ${OUTFILE}
echo -n 'PL   : ' >> $OUTFILE
find . -name 'lstat.txt' -exec grep PL {} \; | wc -l >> ${OUTFILE}
echo -n 'grep ERROR : ' >> $OUTFILE
find . -name 'result*' -exec grep -a ERROR---- {} \; | wc -l >> ${OUTFILE}
echo -n 'grep LINES : ' >> $OUTFILE
find . -name 'result*' -exec grep -a 'LINES' {} \; | wc -l >> ${OUTFILE}
echo '----------------------------------------------------' >> $OUTFILE
echo ' DETAILS' >> $OUTFILE
echo '----------------------------------------------------' >> $OUTFILE
for fn in DATA-*
do
	echo $fn/lstat.txt >> $OUTFILE
	grep NG $fn/lstat.txt >> ${OUTFILE}
done

cp $OUTFILE ../..
