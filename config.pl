#!/usr/bin/perl

$apl_dir    = '/opt/fs-test';
$base_dir   = '/home2/DATA';
$test_num   = 2;                 # how many times for each test type
$test_type  = 0;                 # Start Type: 0: write  1: append  2: overwrite 3: open-write-close
$etest_type = 3;                 # End Type  : same as above
$num_proc   = 10;
$num_file   = 30;
$file_size  = 256 * 1024;
$base_fsize = 0;
$s_char     = '';
$server_ip  = '192.168.1.2';
$WAIT_SEC   = 20;
$gran	= 11;
$iosched	= 'cfq';
$iosched_sys= '/sys/block/sdb/queue/scheduler';
#
# FIXED
#
$ascii      = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
$line_len   = 128;
$tar        = '/bin/tar';
1;
