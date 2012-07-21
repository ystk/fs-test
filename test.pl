#!/usr/bin/perl
#
# (C) Copyright 2010-2012 TOSHIBA CORPORATION
#
# This source code is licensed under the GNU General Public License,
# Version 2.  See the file COPYING for more details.
#

use File::Path;
use File::Copy;

#
# configuration
#
require './config.pl';

# set ioscheduler
if ($iosched eq ''){
        $iosched = 'noop';
}

#
# Get counter
#
if (! -d "$base_dir" ){
        mkpath("$base_dir", 0, 0755);
}

if ( -f "$apl_dir/testcase.txt") {
        open(TESTCASE, "$apl_dir/testcase.txt") 
          or dprint("open error $apl_dir/testcase.txt for READ");
        open(TESTCASEBAK, ">$apl_dir/testcase-bak.txt") 
          or dprint("open error $apl_dir/testcase-bak.txt for WRITE");
        $i    = 0;
        $flag = 0;
        while(<TESTCASE>){
                if ($i == 0){
                        ($tc_count, $tc_num, $tc_iosched) = split /\t/, $_;
                        chomp($tc_count);
                        chomp($tc_num);
                        chomp($tc_iosched);
                        if ($tc_count == 0){
                                $flag = 1;
                                $tc_count++;
                                print TESTCASEBAK "$tc_count\t$tc_num\t$tc_iosched\n";
                        }else{
                                last;
                        }
                }elsif ($i == 1){
                        print TESTCASEBAK $_;
                        ($tc_gran, $tc_iosched) = split /\t/, $_;
                        chomp($tc_gran);
                        chomp($tc_iosched);
                }else{
                        print TESTCASEBAK $_;
                }
                $i++;
        }
        close(TESTCASE);
        close(TESTCASEBAK);

        if ($flag == 1){
                update_config($tc_gran, $tc_iosched);
                system("rm -fr $base_dir/*");
                system("mv $apl_dir/testcase-bak.txt $apl_dir/testcase.txt");
                system("/sbin/shutdown -r now");
        }
}

if ( -f "$base_dir/counter.txt") {
        open(COUNTER, "$base_dir/counter.txt") 
          or dprint("open error $base_dir/counter.txt for READ");
        ($t_count, $t_type) = split /\t/, <COUNTER>, 2;
        chomp($t_count);
        chomp($t_type);
        close(COUNTER);
} else {
        $t_count = 0;
        $t_type  = $test_type;
}

$t_count++;

#
# Check result
#
if ($t_count > 1) {
        system("$apl_dir/check-fs.pl");
}

if ($t_count > $test_num) {
        if ($t_type == $etest_type) {
                if ($server_ip ne ''){
                        print "$apl_dir/send-sep -g $gran -i $server_ip -z $iosched\n";
                        system("$apl_dir/send-sep -g $gran -i $server_ip -z $iosched");
                        print "Deleting previous data\n";
                        system("$apl_dir/c-up.sh");
                        print "BACKUP DATA FOLDER:";
                        $gran  = 1 << $gran;
                        $wsize = $file_size / $gran;
                        chdir("$base_dir/..");
                        system("mv DATA DATA-$iosched-$wsize");
                        system("$tar czvf $apl_dir/results-$iosched-$wsize.tar.gz DATA-$iosched-$wsize");
                        system("rm -fr DATA-$iosched-$wsize/*");
                        system("rmdir DATA-$iosched-$wsize");
                        if ( -f "$apl_dir/testcase.txt") {
                                open(TESTCASE, "$apl_dir/testcase.txt") 
                                  or dprint("open error $apl_dir/testcase.txt for READ");
                                open(TESTCASEBAK, ">$apl_dir/testcase-bak.txt") 
                                  or dprint("open error $apl_dir/testcase-bak.txt for WRITE");
                                $i    = 0;
                                $flag = 0;
                                while(<TESTCASE>){
                                        if ($i == 0){
                                                ($tc_count, $tc_num, $tc_iosched) = split /\t/, $_;
                                                chomp($tc_count);
                                                chomp($tc_num);
                                                chomp($tc_iosched);
                                                if ($tc_count == $tc_num){
                                                        $flag = 1;
                                                }else{
                                                        $tc_count++;
                                                }
                                                print TESTCASEBAK "$tc_count\t$tc_num\t$tc_iosched\n";
                                        }else{
                                                if ($i == $tc_count){
                                                        ($tc_gran, $tc_iosched) = split /\t/, $_;
                                                        chomp($tc_gran);
                                                        chomp($tc_iosched);
                                                }
                                                print TESTCASEBAK $_;
                                        }
                                        $i++;
                                }
                                close(TESTCASE);
                                close(TESTCASEBAK);
                                if ($flag == 0){
                                        update_config($tc_gran, $tc_iosched);
                                        system("mv $apl_dir/testcase-bak.txt $apl_dir/testcase.txt");
                                        system("/sbin/shutdown -r now");
                                }
                        }
                }
                print "ALL DONE\n";
                exit 0;
        } else {
                $t_count = 1;
                $t_type++;
        }
}

print "Deleting previous data.......";
system("$apl_dir/c-up.sh");
print "Done\n";

#
# Write test counter
#
open(COUNTER, ">$base_dir/counter.txt") 
  or dprint("open error $base_dir/counter.txt for WRITE");
print COUNTER "$t_count\t$t_type";
close(COUNTER);

print "Change IOsched $iosched\n";
system ("echo $iosched > $iosched_sys");

# Sleep for time to sync
print "Waiting for Sync\n";
sleep 21;

$s_index = (($t_count - 1) * 3 % 21) + $t_type;
$s_char  = substr($ascii, $s_index, 1);
$wait_ms = $WAIT_SEC * 1000000 + $t_count * 10000;

if ($server_ip eq ''){
        print "$apl_dir/fs-test -n $num_proc -f $num_file -t $t_type -c $s_char -g $gran -r $wait_ms -a $t_count\n";
        system("$apl_dir/fs-test -n $num_proc -f $num_file -t $t_type -c $s_char -g $gran -r $wait_ms -a $t_count");
}else{
        print "$apl_dir/fs-test -n $num_proc -f $num_file -t $t_type -c $s_char -g $gran -r $wait_ms -i $server_ip -a $t_count\n";
        system("$apl_dir/fs-test -n $num_proc -f $num_file -t $t_type -c $s_char -g $gran -r $wait_ms -i $server_ip -a $t_count");
}

#
# NEVER REACHED
#
print "Why???\n";
exit 0;

sub update_config()
{
        local ($l_gran, $l_iosched) = @_;
        local $l_parm;
        local $l_cfile;
        local $l_ncfile;

	#print "Inside $l_gran,$l_iosched\n";
        $l_cfile = "$apl_dir/config.pl";
        $l_ncfile = "$apl_dir/nconfig.pl";
        open(CONF, "$l_cfile") or dprint("open error $l_cfile");
        open(NEWCONF, ">$l_ncfile") or dprint("open error $l_ncfile");
        while(<CONF>){
                ($val, $other) = split /\t| /, $_, 2;
                if ($val eq "\$gran"){
                        print NEWCONF "\$gran\t= $l_gran;\n";
                }elsif ($val eq "\$iosched"){
                        print NEWCONF "\$iosched\t= \'$l_iosched\';\n";
                }else{
                        print NEWCONF $_;
                }
        }
        close(CONF);
        close(NEWCONF);
        copy($l_ncfile, $l_cfile);
}

sub dprint()
{
        local ($msg) = @_;
        print "$msg";
        exit -1;
}
