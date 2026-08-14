#!/usr/bin/perl
# this script partitions a disk for use in a linux live system.
# see description below
use strict;
use warnings;
use Getopt::Std;

our ($opt_h, $opt_D, $opt_W, $opt_M);

# help message
sub usage {
	print "-D size of LINUXLIVE partition in GB default is 8GB fat32\n";
	print "-W (size in GB) default is 10GB persistence partition\n";
	print "-M size of MCTREC partition in GB default is 8GB fat32\n";
	print "-h display this usage\n";
	exit 0;
}

######################################################
# sub to delete all partitions and make a
# partition 1: default=15G  fat32 for MACRIUM REFLECT LABEL = MACRIUM uuid = AED6-434E and LINUXLIVE
# partition 2: 8G fat 32 MCTREC windows media creation tool 2222-2222
# partition 3: default=10GB writable ext4 for persistence partition
# partition 4: rest of disk ntfs LABEL = ele
# all data on the disk is deleted.
# the partitions are also formatted.
# parameters passed: partition 1 LINUXLIVE/MACRIUM size in GB, partition 3 writable size in GB
# sub aborts on any error
# requires: disk for MACRIUM to be attached, not mounted
######################################################
sub partitiondisk {
	# get size LINUXLIVE and writable partitions
	my $linuxlivesize = shift @_;
	my $writablesize = shift @_;
	my $mctrecsize = shift @_;
	
	# show devices attached
	print "######################################################\n";
	my $rc = system("lsblk -o PATH,TYPE,MODEL,LABEL,MOUNTPOINT");
	die "aborting: error from lsblk\n" unless $rc == 0;
	print "######################################################\n";

	# get the device
	print "\n\nenter device to be formatted: form /dev/sdX\n";

	my $device = <STDIN>;
	chomp($device);

	# show the device to check
	print "\n######################################################\n";
	$rc = system("parted -s $device print");
	die "aborting: error from parted\n" unless $rc == 0;
	print "######################################################\n";

	print "\n\n$device will be partitioned as follows:\n";
	print "LINUXLIVE partition = $linuxlivesize: writable partion = $writablesize: MCTREC partition = $mctrecsize: ele partition = rest of disk\n";
	print "\n\nAll data on $device will be deleted: is this correct (yes|no)?\n";
	my $answer = <STDIN>;
	chomp($answer);

	if ($answer =~ /^yes$/i) {
		print "partitioning $device\n";

		# partition 1: LINUXLIVE partition fat32 size is passed as a parameter to this sub
		# partition 2: MCTREC size is 8GB fat32 media tool creation tool
		# partition 3: writable partition ext4 for persistence
		# partition 4: ele partition ntfs is up to 100%
		my $p1start = 0;
		my $p1end = $linuxlivesize;
		my $p2start = $p1end;
		my $p2end = $p2start + $mctrecsize; 
		my $p3start = $p2end;
		my $p3end = $p3start + $writablesize;
		my $p4start = $p3end;
		my $p4end = "100%";

		# convert p start and end to XXGB string
		$p1start .= "GB";
		$p1end   .= "GB";
		$p2start .= "GB";
		$p2end   .= "GB";
		$p3start .= "GB";
		$p3end   .= "GB";
		$p4start .= "GB";
		
		# delete all partitions and make new ones
		# p1 = LINUXLIVE/MACRIUM p2 = MCTREC p3 = writable p4 = ele

		$rc = system("parted -s --align optimal $device mktable gpt mkpart p1 fat32 $p1start $p1end mkpart p2 fat32 $p2start $p2end mkpart p3 ext4 $p3start $p3end mkpart p4 ntfs  $p4start $p4end set 1 boot on");
		die "aborting: error partitioning $device\n" unless $rc == 0;

		# format the first partition
		# the sleep is needed to let the disk settle
		# after partitioning. With no sleep formatting fails
		# if partition size is bigger than 12GB
		sleep 2;

		# format partition 1 LINUXLIVE/MACRIUM
		print "formatting partition " . $device . "1\n";
		$rc = system( "mkfs.vfat -v -n LINUXLIVE -i AED6434E " . $device . "1");
		die "aborting: error formatting " . $device . "1\n" unless $rc == 0;

		# format partition 2 MCTREC
		print "formatting partition " . $device . "2\n";
		$rc = system("mkfs.vfat -v -n MCTREC -i 22222222 " . $device . "2");
		die "aborting: error formatting " . $device . "2\n" unless $rc == 0;

		# format parition 3 writable
		print "formatting partition " . $device . "3\n";
		$rc = system("mkfs.ext4 -v -j -L writable " . $device . "3");
		die "aborting: error formatting " . $device . "3\n" unless $rc == 0;

		# format parition 4 ele
		print "formatting partition " . $device . "4\n";
		$rc = system("mkfs.ntfs -v -Q -L ele  " . $device . "4");
		die "aborting: error formatting " . $device . "4\n" unless $rc == 0;

	} else {
		print "$device was not partitioned\n";
		exit 1;
	}
}

###############################
# main entry
###############################

# -W is size of writable partition for persitence in GB default is 10GB
# -D is size of LINUXLIVE partition in GB default is 8GB
# -M is size of MCRECT partition in GB default is 8GB
# set defaults in GB
my $linuxlivesize = 8;
my $writablesize = 10;
my $mctrecsize = 8;

getopts('D:W:M:h');

# display help and exit if -h given
usage () if $opt_h;

# set linuxlive size
$linuxlivesize = $opt_D if $opt_D;

# set writable size
$writablesize = $opt_W if $opt_W;

# set size for microsoft media creation tool 
$mctrecsize = $opt_M if $opt_M;

partitiondisk($linuxlivesize, $writablesize, $mctrecsize);

