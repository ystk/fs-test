#! /bin/bash
fstestpath="."

find . -name "DATA*" | xargs -i ./log-check.pl -d {}
