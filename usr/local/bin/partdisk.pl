#!/usr/bin/perl
# this script partitions a disk for use in a linux live system.
# see description below
use strict;
use warnings;
use Getopt::Std;

our ($opt_v, $opt_h, $opt_L, $opt_T, $opt_W, $opt_M);
# for verbose option
my $opt = "";

# help message
sub usage {
	print "-L size of LINUXLIVE partition in GB default is 8GB fat32\n";
	print "-W (size in GB) default is 10GB persistence partition\n";
	print "-M size of MACRIUM partition in GB default is 1GB fat32\n";
	print "-T size of MCTREC partition in GB default is 8GB fat32\n";
	print "-v for verbose";
	print "-h display this usage\n";
	exit 0;
}
######################################################
# sub to get total size of disk
# parameters passed: device ie /dev/sda
# parameters returned: size in GB
######################################################
sub getsize {
	# parameter
	my $device = shift @_;

	# get size
	my @list = `lsblk $device -o SIZE`;
	chomp(@list);
	# remove the trailing G
	$list[1] =~ s/G$//;
	return $list[1];
}
######################################################
######################################################
# sub to delete all partitions and make a
# partition 1: default=8G  fat32 for MACRIUM REFLECT label MACRIUM
# partition 2: default=8G  fat32 for LINUXLIVE
# partition 3: default=10GB writable ext4 for persistence partition
# partition 4: 8G fat 32 MCTREC windows media creation tool 2222-2222
# partition 5: rest of disk ntfs LABEL = ele
# all data on the disk is deleted.
# the partitions are also formatted.
# parameters passed: partition 1 LINUXLIVE size GB
#                    partition 2 writable size GB
#                    partition 3 MACRIUM size GB
#                    partition 4 MCTREC size GB
# sub aborts on any error
# requires: disk for MACRIUM to be attached, not mounted
######################################################
sub partitiondisk {
	# get size LINUXLIVE and writable partitions
	my $linuxlivesize = shift @_;
	my $writablesize = shift @_;
	my $macriumsize = shift @_;
	my $mctrecsize = shift @_;
	
	# show devices attached
	print "######################################################\n";
	my $rc = system("lsblk -o PATH,TYPE,MODEL,LABEL,MOUNTPOINT,SIZE");
	die "aborting: error from lsblk\n" unless $rc == 0;
	print "######################################################\n";

	# get the device
	print "\n\nenter device to be formatted: form /dev/sdX\n";

	my $device = <STDIN>;
	chomp($device);

	# get the disk size
	my $devicesize = getsize($device);
	
	# show the device to check
	print "\n######################################################\n";
	$rc = system("parted -s $device print");
	die "aborting: error from parted\n" unless $rc == 0;
	print "######################################################\n";

	# calculate size of last partition
	# size = disk size  - (linuxlivesize + writablesize + mctrecsize)
	my $elesize = $devicesize - ($linuxlivesize + $writablesize + $mctrecsize);
	
	# also show the model no of the disk
	my @model = `lsblk -o MODEL $device`;
	chomp(@model);
	
	print "\n\nThe disk will be partitioned as follows:\n";
	print "Model = $model[1]\nDevice = $device\nDisk size = $devicesize GB\np1: LINUXLIVE partition = $linuxlivesize GB\np2: writable partition = $writablesize GB\np3: MACRIUM partion = $macriumsize GB\np4: MCTREC partition = $mctrecsize GB\np5: ele partition = $elesize GB\n";
	print "\n\nAll data on $device will be deleted: is this correct (yes|no)?\n";
	my $answer = <STDIN>;
	chomp($answer);

	if ($answer =~ /^yes$/i) {
		print "partitioning $device\n";

		# partition 1: LINUXLIVE parition fat32
		# partition 2: writable partition ext4 for persistence
		# partition 3: MACRIUM partition fat32 size is passed as a parameter to this sub
		# partition 4: MCTREC partition media tool creation tool
		# partition 5: ele partition ntfs is up to 100%
		my $p1start = 0;
		my $p1end = $linuxlivesize;
		my $p2start = $p1end;
		my $p2end = $p2start + $writablesize;
		my $p3start = $p2end;
		my $p3end = $p3start + $macriumsize;
		my $p4start = $p3end;
		my $p4end = $p4start + $mctrecsize;
		my $p5start = $p4end;
		my $p5end = "100%";

		# convert p start and end to XXGB string
		$p1start .= "GB";
		$p1end   .= "GB";
		$p2start .= "GB";
		$p2end   .= "GB";
		$p3start .= "GB";
		$p3end   .= "GB";
		$p4start .= "GB";
		$p4end   .= "GB";
		$p5start .= "GB";
		
		# delete all partitions and make new ones
		# p1 = LINUXLIVE/MACRIUM p2 = writable p3 = MCTREC p4 = ele

		$rc = system("parted -s --align optimal $device mktable gpt mkpart p1 fat32 $p1start $p1end mkpart p2 ext4 $p2start $p2end mkpart p3 fat32 $p3start $p3end mkpart p4 fat32  $p4start $p4end mkpart p5 ntfs $p5start $p5end set 1 boot on");
		die "aborting: error partitioning $device\n" unless $rc == 0;

		# format the first partition
		# the sleep is needed to let the disk settle
		# after partitioning. With no sleep formatting fails
		# if partition size is bigger than 12GB
		sleep 2;

		# format parition 1 LINUXLIVE
		print "formatting partition " . $device . "1\n";
		$rc = system("mkfs.vfat $opt -n LINUXLIVE -i 11111111 " . $device . "1");
		die "aborting: error formatting " . $device . "1\n" unless $rc == 0;

		# format parition 2 writable
		print "formatting partition " . $device . "2\n";
		$rc = system("mkfs.ext4 $opt -j -L writable " . $device . "2");
		die "aborting: error formatting " . $device . "2\n" unless $rc == 0;

		# format partition 3 MACRIUM
		print "formatting partition " . $device . "3\n";
		$rc = system( "mkfs.vfat $opt -n MACRIUM -i AED6434E " . $device . "3");
		die "aborting: error formatting " . $device . "3\n" unless $rc == 0;

		# format partition 4 MCTREC
		print "formatting partition " . $device . "4\n";
		$rc = system("mkfs.vfat $opt -n MCTREC -i 44444444 " . $device . "4");
		die "aborting: error formatting " . $device . "4\n" unless $rc == 0;

		# format parition 5 ele
		print "formatting partition " . $device . "5\n";
		$rc = system("mkfs.ntfs $opt -Q -L ele  " . $device . "5");
		die "aborting: error formatting " . $device . "5\n" unless $rc == 0;

	} else {
		print "$device was not partitioned\n";
		exit 1;
	}
}

###############################
# main entry
###############################

# -L is size of LINUXLIVE
# -W is size of writable partition for persitence in GB default is 10GB
# -M is size of  MACRIUM partition in GB default is 2GB
# -T is size of MCRECT partition in GB default is 8GB
# -v for verbose
# set defaults in GB
my $macriumsize = 2;
my $linuxlivesize = 8;
my $writablesize = 10;
my $mctrecsize = 8;

getopts('vL:D:W:M:T:h');

# display help and exit if -h given
usage () if $opt_h;

# for verbose
$opt = "-v" if $opt_v;

# set linuxlive size
$linuxlivesize = $opt_L if $opt_L;

# set writable size
$writablesize = $opt_W if $opt_W;

# set size for microsoft media creation tool 
$mctrecsize = $opt_T if $opt_T;

# set size of macrium partition
$macriumsize = $opt_M if $opt_M;

partitiondisk($linuxlivesize, $writablesize, $macriumsize, $mctrecsize);

