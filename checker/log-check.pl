#!/usr/bin/perl
#
# (C) Copyright 2010-2012 TOSHIBA CORPORATION
#
# This source code is licensed under the GNU General Public License,
# Version 2.  See the file COPYING for more details.
#

use Getopt::Std;

#
# configuration (dummy)
#
require ('./config.pl');

#
# options
#
getopts("d:" , \%opt);

if ($opt{d} eq '') {
    dprint("Please specify source directory.\n");
    exit 1;
};
$base_dir = $opt{d};

@lfile_list = `ls -1 $base_dir/log*`;
@rfile_list = `ls -1 $base_dir/result-*`;
@sfile_list = `ls -1 $base_dir/stat-*`;
@wfile_list = `ls -1 $base_dir/wstat-*`;

#
# Get parameter
#
open(PARMS, "$base_dir/params.txt")
  or dprint("open error $base_dir/params.txt");
($type, $num_proc, $base_fsize, $num_file, $gran, $s_char) = split /\t/, <PARMS>, 6;
chomp($s_char);
close(PARMS);

#
# Check log file to determine the write count
#
foreach (@lfile_list){
        $lfile = $_;
        open (LOG, "$lfile") or dprint("open error $lfile");

        for($i = 0; $i < 100; $i++){
                $l_index[$i]  = 0;
                $l_tcount[$i] = 1;
        }
        $id_min = 1000;
        $id_max = -1;

        $type_flag = 0;
        $type_count = 0;

        while(<LOG>){
                ($type, $id, $num, $lcount, $bsize) = split /\t|\s+/, $_, 5;
                $type =~ s/\s+//g;
                $type =~ s/\t//g;
                $id   =~ s/\s+//g;
                $id   =~ s/\t//g;

                #
                $searchindex = rindex $type, 9999;
                if ($searchindex  == -1){
                        $type_len   = length($type);
                        $type = substr($type, $type_len - 1, $type_len);
                }else{
                        substr($type, 0, length $type, 9999);
                }

                if($id eq ''){ $id = 0; }
                chomp($bsize);
                if ($type == 9999){
                        # Fields: [9999], type, tcount, id, 0
                        # id     -> tcount
                        # lcount -> id
                        # num    -> lcount
                        if ($type_flag == 0 && $type_count > 100){
                                for($i = $id_min; $i <= $id_max; $i++){
                                        if ($l_index[$i] != 0){ 
                                                $str = sprintf "%d\t%d\t%d\t%d\t%d\t%d\n",
                                                  $l_type[$i], $l_tcount[$i], $l_id[$i], $l_num[$i], $l_lcount[$i], $l_bsize[$i];
                                                push @last_log, $str;
                                                $l_index[$i] = 0;
                                                print $str;
                                        }
                                        $l_tcount[$i] = $num;  # num = tcount
                                }
                                $type_flag = 1;
                                $type_count = 0;
                        }
                }elsif($type ne '' and $id ne '' and $num ne '' and $lcount ne '' and $bsize ne ''){
                        if ($type_count > 100) {
                                $l_type[$id]   = $type;
                                $l_id[$id]     = $id;
                                $l_num[$id]    = $num;
                                $l_lcount[$id] = $lcount;
                                $l_bsize[$id]  = $bsize;
                                $l_index[$id]++;
                                if($id_min > $id) {
                                        $id_min = $id;
                                }
                                if($id_max < $id) {
                                        $id_max = $id;
                                }
                                $type_flag = 0;
                        }
                        $type_count++;
                }
        }

        for($i = $id_min; $i <= $id_max; $i++){
                $str = sprintf "%d\t%d\t%d\t%d\t%d\t%d\n",
                  $l_type[$i], $l_tcount[$i], $l_id[$i], $l_num[$i], $l_lcount[$i], $l_bsize[$i];
                push @last_log, $str;
                print $str;
        }
        close(LOG);
}

$lstat_file = sprintf("%s/lstat.txt", $base_dir);
open (LSTAT, ">$lstat_file") or dprint("Failed to open ($lstat_file)");
foreach (@last_log){
        ($l_type, $l_tcount, $l_id, $l_num, $l_lcount, $l_bsize) = split /\t/, $_, 6;
        chomp($l_bsize);
        $wstat_file = sprintf("%s/wstat-t%02d-%04d.txt", $base_dir, $l_type, $l_tcount);

        open (WSTAT, "$wstat_file") or dprint("Failed to open ($wstat_file)");
        while(<WSTAT>){
                ($w_fname, $w_type, $w_tcount, $w_bsize, $w_fsize, $w_lines, $w_cl) = split /\t/, $_, 7;
                @fpath = split /\//, $w_fname;
                $tmp    = $fpath[$#fpath];            # File name
                ($w_fnum, $dummy) = split /\./, $tmp; #
                $w_id   = $fpath[$#fpath - 2];        # Thread ID
                chomp($w_cl);

                if ( $l_id == $w_id and $l_num == $w_fnum){
                        if ($l_type == 0){
                                if ($w_fsize ==  $l_bsize * $l_lcount or $w_fsize ==  $l_bsize * ($l_lcount + 1)){
                                        $w_result = "OK";
                                }elsif ($w_fsize >  $l_bsize * ($l_lcount + 1)){
                                        $w_result = "PL";
                                }else{
                                        $w_result = "NG";
                                }
                        }elsif($l_type == 1){ # Append
                                if ($w_fsize ==  $w_bsize + $l_bsize * $l_lcount or $w_fsize ==  $w_bsize + $l_bsize * ($l_lcount + 1)){
                                        $w_result = "OK";
                                }elsif ($w_fsize >  $w_bsize + $l_bsize * ($l_lcount + 1)){
                                        $w_result = "PL";
                                }else{
                                        $w_result = "NG";
                                }
                        }elsif($l_type == 2){ # Overwrite
                                if ($w_cl ==  $l_bsize * $l_lcount / $line_len or $w_cl == $l_bsize * ($l_lcount + 1) / 128){
                                        $w_result = "OK";
                                }elsif ($w_cl > $l_bsize * ($l_lcount + 1) / 128){
                                        $w_result = "PL";
                                }else{
                                        $w_result = "NG";
                                }
                        }elsif($l_type == 3){ # Append-Close
                                if ($w_fsize ==  $l_bsize * $l_lcount or $w_fsize ==  $l_bsize * ($l_lcount + 1)){
                                        $w_result = "OK";
                                }elsif ($w_fsize >  $l_bsize * ($l_lcount + 1)){
                                        $w_result = "PL";
                                }else{
                                        $w_result = "NG";
                                }
                        }else{
                                dprintf("ERROR\n");
                        }
                        print LSTAT "$l_type\t$l_tcount\t$l_id\t$l_num\t$l_lcount\t$l_bsize\t$w_bsize\t$w_fsize\t$w_lines\t$w_cl\t$w_result\n";
                }
        }
        close(WSTAT);
}
close(LSTAT);

exit 0;

sub dprint()
{
        local ($msg) = @_;
        print "$msg";
        exit -1;
}
