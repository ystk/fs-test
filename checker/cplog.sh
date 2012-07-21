#! /bin/bash
fstestpath="."

find . -name "*tar.gz" | xargs -i tar xvfz {}

logfile=`find . -name "log*.txt"`

for lf  in $logfile ; do
	cpdir="DATA-"`echo $lf | cut -d- -f2-3 -`
	cpdir=`echo $cpdir | cut -d. -f1 -`
	cp $lf $cpdir
done	

ln -s $fstestpath"/log-check.pl" log-check

find . -name "DATA*" | xargs -i ./log-check -d {}
