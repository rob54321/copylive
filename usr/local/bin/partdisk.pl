#!/usr/bin/perl
# this script partitions a disk for use in a linux live system.
# see description below
use strict;
use warnings;
use Getopt::Std;

our ($opt_h, $opt_U, $opt_E, $opt_L, $opt_T, $opt_W, $opt_M);

# default sizes for the paritions
# LINUXLIVE partition 1 UUID for grub.cfg
my $linuxliveuuid = "12345678-1234-1234-1234-123456789012";
my $efisize = 1;
my $macriumsize = 2;
my $linuxlivesize = 8;
my $writablesize = 10;
my $mctrecsize = 8;

# uuid for LINUXLIVE partition
my $uuid = "12345678-1234-1234-1234-123456789012";

# help message
sub usage {
	print "-E size of EFI partition in GB default is $efisize " . "GB fat32\n";
	print "-L size of LINUXLIVE partition in GB default is $linuxlivesize " . "GB ext4\n";
	print "-W size of writable partition in GB default is $writablesize " . "GB ext4 persistence partition\n";
	print "-M size of MACRIUM partition in GB default is $macriumsize " . "GB fat32\n";
	print "-T size of MCTREC partition in GB default is $mctrecsize ". "GB fat32\n";
	print "-U uuid of LINUXLIVE partition: format hex digits: $linuxliveuuid\n";
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
# partition 1: default=200M	fat32 for EFILIVE
# partition 2: default=8G  ext4 LINUXLIVE
# partition 3: default=10G  ext4 writable
# partition 4: default=2G fat32 MACRIUM
# partition 5: default=8G fat32 MCTREC windows media creation tool 2222-2222
# partition 6: rest of disk ntfs LABEL = ele
# all data on the disk is deleted.
# the partitions are also formatted.
# parameters passed: uuid of LINUXLIVE partition
#                    partition 1 EFI size 200M
#                    partition 2 LINUXLIVE size GB
#                    partition 3 writable size GB
#                    partition 4 MACRIUM size GB
#                    partition 5 MCTREC size GB
# sub aborts on any error
# requires: disk for MACRIUM to be attached, not mounted
######################################################
sub partitiondisk {
	# get uuid and size of partitions
	my $linuxliveuuid = shift @_;
	my $efisize = shift @_;
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
	print "Selected disk has the following data on it\n";
	system("lsblk -o PATH,LABEL,FSTYPE,SIZE $device");
#	$rc = system("parted -s $device print");
	die "aborting: error from parted\n" unless $rc == 0;
	print "######################################################\n";

	# calculate size of last partition
	# size = disk size  - (linuxlivesize + writablesize + mctrecsize)
	my $elesize = $devicesize - ($efisize + $linuxlivesize + $writablesize + $mctrecsize);
	
	# also show the model no of the disk
	my @model = `lsblk -o MODEL $device`;
	chomp(@model);
	
	print "\n\nThe disk will be partitioned as follows:\n";
	print "Model = $model[1]\nDevice = $device\nDisk size = $devicesize GB\np1: EFI parition = $efisize GB\np2: LINUXLIVE partition = $linuxlivesize GB uuid = $linuxliveuuid\np3: writable partition = $writablesize GB\np4: MACRIUM partion = $macriumsize GB\np5: MCTREC partition = $mctrecsize GB\np6: ele partition = $elesize GB\n";
	print "\n\nAll data on $device will be deleted: is this correct (yes|no)?\n";
	my $answer = <STDIN>;
	chomp($answer);

	if ($answer =~ /^yes$/i) {
		print "partitioning $device\n";

		# partition 1: EFILIVE partition fat32
		# partition 2: LINUXLIVE parition ext4
		# partition 3: writable partition ext4 for persistence
		# partition 4: MACRIUM partition fat32 size is passed as a parameter to this sub
		# partition 5: MCTREC partition media tool creation tool
		# partition 6: ele partition ntfs is up to 100%
		my $p1start = 0;
		my $p1end = $efisize;
		my $p2start = $p1end;
		my $p2end = $p2start + $linuxlivesize;
		my $p3start = $p2end;
		my $p3end = $p3start + $writablesize;
		my $p4start = $p3end;
		my $p4end = $p4start + $macriumsize;
		my $p5start = $p4end;
		my $p5end = $p5start + $mctrecsize;
		my $p6start = $p5end;
		my $p6end = "100%";

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
		$p5end   .= "GB";
		$p6start .= "GB";
		
		# delete all partitions and make new ones

		$rc = system("parted -s --align optimal $device mktable gpt mkpart p1 fat32 $p1start $p1end mkpart p2 ext4 $p2start $p2end mkpart p3 ext4 $p3start $p3end mkpart p4 fat32  $p4start $p4end mkpart p5 fat32 $p5start $p5end mkpart p6 ntfs $p6start $p6end set 1 boot on");
		die "aborting: error partitioning $device\n" unless $rc == 0;

		# format the first partition
		# the sleep is needed to let the disk settle
		# after partitioning. With no sleep formatting fails
		# if partition size is bigger than 12GB
		sleep 2;

		# format partition 1 EFILIVE
		print "formatting partition " . $device . "1\n";
		$rc = system( "mkfs.vfat -v -n EFILIVE " . $device . "1");
		die "aborting: error formatting " . $device . "1\n" unless $rc == 0;

		# format parition 2 LINUXLIVE
		print "formatting partition " . $device . "2\n";
		$rc = system("mkfs.ext4 -v -j -L LINUXLIVE -U $linuxliveuuid " . $device . "2");
		die "aborting: error formatting " . $device . "2\n" unless $rc == 0;

		# format parition 3 writable
		print "formatting partition " . $device . "3\n";
		$rc = system("mkfs.ext4 -v -j -L writable " . $device . "3");
		die "aborting: error formatting " . $device . "3\n" unless $rc == 0;

		# format partition 4 MACRIUM
		print "formatting partition " . $device . "4\n";
		$rc = system( "mkfs.vfat -v -n MACRIUM -i AED6434E " . $device . "4");
		die "aborting: error formatting " . $device . "4\n" unless $rc == 0;

		# format partition 5 MCTREC
		print "formatting partition " . $device . "5\n";
		$rc = system("mkfs.vfat -v -n MCTREC -i 44444444 " . $device . "5");
		die "aborting: error formatting " . $device . "5\n" unless $rc == 0;

		# format parition 6 ele
		print "formatting partition " . $device . "6\n";
		$rc = system("mkfs.ntfs -v -Q -L ele  " . $device . "6");
		die "aborting: error formatting " . $device . "6\n" unless $rc == 0;

	} else {
		print "$device was not partitioned\n";
		exit 1;
	}
}

###############################
# main entry
###############################

# -E is size of EFI partition
# -L is size of LINUXLIVE
# -W is size of writable partition for persitence in GB default is 10GB
# -M is size of  MACRIUM partition in GB default is 2GB
# -T is size of MCRECT partition in GB default is 8GB
# -U is for the uuid of the LINUXLIVE partition
# set defaults in GB
getopts('U:E:L:D:W:M:T:h');

# display help and exit if -h given
usage () if $opt_h;

# set uuid if given
$linuxliveuuid = $opt_U if $opt_U;
# set efi size
$efisize = $opt_E if $opt_E;

# set linuxlive size
$linuxlivesize = $opt_L if $opt_L;

# set writable size
$writablesize = $opt_W if $opt_W;

# set size for microsoft media creation tool 
$mctrecsize = $opt_T if $opt_T;

# set size of macrium partition
$macriumsize = $opt_M if $opt_M;

partitiondisk($linuxliveuuid, $efisize, $linuxlivesize, $writablesize, $macriumsize, $mctrecsize);

