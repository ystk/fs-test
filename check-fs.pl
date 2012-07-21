#!/usr/bin/perl
#
# (C) Copyright 2010-2012 TOSHIBA CORPORATION
#
# This source code is licensed under the GNU General Public License,
# Version 2.  See the file COPYING for more details.
#

use File::Path;
use Getopt::Std;
use File::Copy;

#
# configuration
#

require("./config.pl");

#
# Get options
#

open(PARMS, "$base_dir/params.txt") 
  or dprint("open error $base_dir/params.txt");
($type, $num_proc, $base_fsize, $num_file, $gran, $s_char) = split /\t/, <PARMS>, 6;
chomp($s_char);
print "(TYPE:$type, THRS:$num_proc, FSIZE:$base_fsize, FILES:$num_file, GRAN:$gran, CHAR:$s_char)\n";
close(PARMS);

#
# Set characters to be used
#
$s_pos      = index($ascii, $s_char);
$s_char1    = substr($ascii, $s_pos + 1, 1);
$s_char2    = substr($ascii, $s_pos + 2, 1);
#
# Make a string
#
$str1       =  sprintf("%127s\n");
$str2       =  sprintf("%127s\n");
$str3       =  sprintf("%127s\n");
$str1       =~ s/ /$s_char/g;
$str2       =~ s/ /$s_char1/g;
$str3       =~ s/ /$s_char2/g;

#
# Statistics
#
$st_lost     = 0;	# File lost???
$st_esize    = 0;	# Size Error
$st_econtent = 0;	# Contents Error
$st_min      = 1000000; # Minimum number
$st_max      = 0;       # Maximum number
$st_checked  = 0;       # Number of checked files
$st_ftotal   = 0;       # Sum of file numbers

# Make a directory to store corrupted files
if (! -d "$base_dir/error" ){
        mkpath("$base_dir/error", 0, 0755);
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
	$t_type  = 0;
}

$res_file =
  sprintf("%s/result-t%02d-%04d.txt", $base_dir, $t_type, $t_count);
$wstat_file =
  sprintf("%s/wstat-t%02d-%04d.txt", $base_dir, $t_type, $t_count);
print "Check results($t_type, $t_count, $res_file)";
open(RESULT, ">$res_file") or dprint("open error $res_file");
open(WSTAT, ">$wstat_file") or dprint("open error $wstat_file");
for ($i=1; $i<$num_proc + 1; $i++) {
        $st_checked = 0;
	for ($j=0; $j<$num_file; $j++) {
		$subdir   = int($j / 100);
		$filename = sprintf("%s/%04d/%04d/%04d.txt",
				    $base_dir, $i, $subdir, $j);
		# print ".";
                print RESULT "$filename";
		if ( -f $filename) {
                        print RESULT "\n";
			#
			# check file status
			#
                        $st_checked++;
			$error = check_str();
                        if ($error != 0){
                                backup_errfile($filename , $base_dir, $t_type, $t_count, $i, $j);
                        }
		}else{
                        print RESULT "(File not found)\n";
                }
	}
        if ($st_checked > $st_max) {
                $st_max = $st_checked;
        }
        if ($st_checked < $st_min) {
                $st_min = $st_checked;
        }
        $st_ftotal = $st_ftotal + $st_checked;
}
close(RESULT);
close(WSTAT);
print "Done\n";

#
# Create STAT file
#
print "Writing to statfile...";
$stat_file = sprintf("%s/stat-t%02d-%04d.txt",
		     $base_dir, $t_type, $t_count);
open(STATISTICS, ">$stat_file") or dprint("open error $stat_file");
print STATISTICS "$t_type\t$t_count\t$num_proc\t$base_fsize\t$num_file\t$st_ftotal\t$st_min\t$st_max\t$st_esize\t$st_econtent\n";
close(STATISTICS);
print "Done\n";

exit 0;

#
# subroutines
#
sub check_str()
{
        local $fchar;
        local $fchar_prev;
        local $remain;
        local $mode;
        local $k;
        local $c       = 0;
        local $str_c   = 0;
        local $l_error = 0;
        local $l_len   = 0;
        local @err_msg = ();

        open(TEST, $filename) or dprint("open error $filename");
        ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,
         $blksize,$blocks) = stat($filename);

        if ($base_fsize == 0) {
                $base_fsize = $size;
        }

        if ($base_fsize != $size) {
                $remain = $size % ($base_fsize / (1 << $gran));
                if ($remain != 0) {
                        push (@err_msg, "ERROR:WSIZE($size)");
                        $l_error = 1;
                        $st_esize++;
                }
        }

        $cm     = 0;
        $p_mode = 0;
        while (<TEST>) {
                $c++;
                $str_c++;

                $l_len = length($l_len);

                if ($_ eq $str1) {
                        $mode = 0;
                } elsif ($_ eq $str2) {
                        $mode = 1;
                } elsif ($_ eq $str3) {
                        $mode = 2;
                } else {
                        push(@err_msg, "FSTR:$_");
                        $l_error = 1;
                        $st_econtent = $st_econtent + 1;
                }

                if ($mode == 2 || $mode == 1){
                        $cm++;
                }

                if ($mode != $p_mode) {
                        #
                        # Count number of lines
                        #
                        if ($type == 1 && $str_c != ($base_fsize / 128) + 1) { # 1024 + 1
                                push(@err_msg, "ERROR(LINES:$str_c)");
                                $l_error = 1;
                                $st_esize++;
                        }

                        if ($type == 2 && $str_c != ($base_fsize / (1 << $gran)) / 128 + 1) {
                                push(@err_msg, "ERROR(LINES:$str_c)");
                                $l_error = 1;
                                $st_esize++;
                        }

                        $str_c  = 1;
                        $p_mode = $mode;
                }
        }
        close TEST;

        if ($l_error != 0) {
                unshift (@err_msg, 
                         'ERROR----------------------------------------------');
                push    (@err_msg,
                         '---------------------------------------------------');
                print_emsg(@err_msg);
        }

        print WSTAT "$filename\t$t_type\t$t_count\t$base_fsize\t$size\t$c\t$cm\n";
        # print "($st_econtent, $st_esize)\n";
        return $l_error;
}

#
# subroutines
#
sub print_emsg()
{
        local @l_msg = @_;
        local $l_line;

        # print "\n";
        while ($l_line = shift(@l_msg)) {
                print RESULT "$l_line\n";
        }
}

sub backup_errfile()
{
        local ($l_src, $l_base, $l_type, $l_count, $l_i, $l_j) = @_;
        local $l_dist;

        $l_dist = sprintf("%s/error/efile-t%02d-%04d-p%02d-%04d.txt",
                          $l_base, $l_type, $l_count, $l_i, $l_j);
        print "COPY: $l_src -> $l_dist\n";
        copy($l_src, $l_dist);
}

sub check_val()
{
        local ($cv)  = @_;
        local $l_val = '';

        chomp($cv);
        if ($cv eq '') {
                $l_val = 'n';
        } else {
                $l_val = $cv;
        }
        return $l_val;
}

sub dprint()
{
        local ($msg) = @_;
        print "$msg";
        exit -1;
}
