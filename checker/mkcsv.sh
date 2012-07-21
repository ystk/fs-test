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
OUTFILE_TMP="$2-tmp"
echo "Step1: summery"
echo $NAME > $OUTFILE
echo -n "LINES:\t" >> $OUTFILE
find . -name 'lstat.txt' -exec cat {} \; | wc -l >> ${OUTFILE}
echo "$1 Summery\tNG\tFSTR\tELINE\tPL" >> ${OUTFILE}
echo -n '\t' >> $OUTFILE
echo -n `find . -name 'lstat.txt' -exec grep NG {} \; | wc -l` >> ${OUTFILE}
echo -n '\t' >> $OUTFILE
echo -n `find . -name 'result-*.txt' -exec grep -a -A 1 ERROR---- {} \; | grep -a -e FSTR | wc -l` >> ${OUTFILE}
echo -n '\t' >> $OUTFILE
echo -n `find . -name 'result*' -exec grep -a 'LINES' {} \; | wc -l` >> ${OUTFILE}
echo -n '\t' >> $OUTFILE
find . -name 'lstat.txt' -exec grep PL {} \; | wc -l >> ${OUTFILE}
#
# Join lstat.txt
#
echo "Step2: test cases"
if [ -f ${OUTFILE_TMP} ];then
    rm ${OUTFILE_TMP}
fi
for fn in DATA-*
do
    echo "$fn\t999999" >> ${OUTFILE_TMP}
    cat  $fn/lstat.txt >> ${OUTFILE_TMP}
done
echo "TEST CASE($1)\tNG\tFSTR" >> ${OUTFILE}
echo -n 'create\t' >> ${OUTFILE}
echo -n `egrep '^0' $OUTFILE_TMP | grep NG | wc -l` >> ${OUTFILE}
echo -n "\t" >> $OUTFILE
find . -name 'result-*t00*.txt' -exec grep -a -A 1 ERROR---- {} \; | grep -a -e FSTR | wc -l >> ${OUTFILE}
echo -n 'append\t' >> ${OUTFILE}
echo -n `egrep '^1' $OUTFILE_TMP | grep NG | wc -l` >> ${OUTFILE}
echo -n "\t" >> $OUTFILE
find . -name 'result-*t01*.txt' -exec grep -a -A 1 ERROR---- {} \; | grep -a -e FSTR | wc -l >> ${OUTFILE}
echo -n 'overwrite\t' >> ${OUTFILE}
echo -n `egrep '^2' $OUTFILE_TMP | grep NG | wc -l` >> ${OUTFILE}
echo -n "\t" >> $OUTFILE
find . -name 'result-*t02*.txt' -exec grep -a -A 1 ERROR---- {} \; | grep -a -e FSTR | wc -l >> ${OUTFILE}
echo -n 'writeclose\t' >> ${OUTFILE}
echo -n `egrep '^3' $OUTFILE_TMP | grep NG | wc -l` >> ${OUTFILE}
echo -n "\t" >> $OUTFILE
find . -name 'result-*t03*.txt' -exec grep -a -A 1 ERROR---- {} \; | grep -a -e FSTR | wc -l >> ${OUTFILE}
#
# Measured by I/O scheduler and write size
#
echo "\n\n" >> $OUTFILE
echo "I/O scheduler and write size\n\n" >> $OUTFILE
echo "I/O sched and wsize\tNG\tFSTR\tELINES" >> $OUTFILE
for fn in noop deadline cfq anticipatory
do
    echo -n $fn
    for wsize in 128 256 4096 8192 16384
    do
	echo -n $wsize
	dr=DATA-$fn-$wsize
	if [ -d $dr ];then
	    echo -n "${fn}-${wsize}\t" >> $OUTFILE
	    echo -n `find $dr -name 'lstat.txt' -exec grep NG {} \; | wc -l` >> ${OUTFILE}
	    echo -n "\t" >> $OUTFILE
	    echo -n `find $dr -name 'result*' -exec grep -a -A 1 ERROR---- {} \; | grep -a -e FSTR | wc -l` >> ${OUTFILE}
	    echo -n "\t" >> $OUTFILE
	    find $dr -name 'result*' -exec grep -a 'LINES' {} \; | wc -l >> ${OUTFILE}
	fi
    done
    echo ""
done
#
# Measured by I/O scheduler
#
echo "\n\n" >> $OUTFILE
echo "I/O scheduler\n\n" >> $OUTFILE
echo "I/O sched\tNG\tFSTR\tELINES" >> $OUTFILE
for fn in noop deadline cfq anticipatory
do
    echo -n $fn
    echo -n "$fn\t" >> $OUTFILE
    dr=DATA-$fn-*
    echo -n `find $dr -name 'lstat.txt' -exec grep NG {} \; | wc -l` >> ${OUTFILE}
    echo -n "\t" >> $OUTFILE
    echo -n `find $dr -name 'result*' -exec grep -a -A 1 ERROR---- {} \; | grep -a -e FSTR | wc -l` >> ${OUTFILE}
    echo -n "\t" >> $OUTFILE
    find $dr -name 'result*' -exec grep -a 'LINES' {} \; | wc -l >> ${OUTFILE}
    echo ""
done

#
# Measured by size
#
echo "\n\n" >> $OUTFILE
echo "Write size\n\n" >> $OUTFILE
echo "Wsize\tNG\tFSTR\tELINES" >> $OUTFILE
for fn in 128 256 4096 8192 16384
do
    echo -n $fn
    echo -n "$fn\t" >> $OUTFILE
    dr=DATA-*-$fn
    echo -n `find $dr -name 'lstat.txt' -exec grep NG {} \; | wc -l` >> ${OUTFILE}
    echo -n "\t" >> $OUTFILE
    echo -n `find $dr -name 'result*' -exec grep -a -A 1 ERROR---- {} \; | grep -a -e FSTR | wc -l` >> ${OUTFILE}
    echo -n "\t" >> $OUTFILE
    find $dr -name 'result*' -exec grep -a 'LINES' {} \; | wc -l >> ${OUTFILE}
    echo ""
done
#
# join
#
echo "\n\n" >> $OUTFILE
cat  ${OUTFILE_TMP}  >> $OUTFILE

cp $OUTFILE ../../
