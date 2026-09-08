#!/usr/bin/perl
# this script partitions a disk for use in a linux live system.
# There are 2 options:
# 1: p1 EFILIVE vfat; p2 LINUXLIVE ext4; p3 writable ext4; p4 MACRIUM vfat; p5 MCTREC vfat; p6 data ntfs
# 2: p1 LINUXLIVEv vfat; p2 writable ext4; p3 MACRIUM vfat; p4 MCTREC vfat; p5 data ntfs
# switch -e choses option 1
# swtich -f choses options2
# there is no default. -e or -f must be given.
# if both -e and -f are given a fatal error occurs
# if neither -e nor -f are given a fatal error occurs.
use strict;
use warnings;
use Getopt::Std;

our ($opt_e, $opt_f, $opt_v, $opt_h, $opt_U, $opt_E, $opt_L, $opt_T, $opt_W, $opt_M);

# default sizes for the paritions
# LINUXLIVE partition 1 UUID for grub.cfg
# only for ext4 option
my $linuxliveuuiddefault = "12345678-1234-1234-1234-123456789012";
my $linuxlivevolumeiddefault = "11111111";

# default sizes
# efisize is not used when -f vfat option is given
my $efisize = 1;
my $macriumsize = 2;
my $linuxlivesize = 8;
my $writablesize = 10;
my $mctrecsize = 8;


# help message
sub usage {
	print "-f LINUXLIVEv is vfat and contains efi/boot\n";
	print "-e LINUXLIVE is ext4 and efi is a separate partition\n";
	print "-E size of EFI partition in GB default is $efisize " . "GB fat32\n";
	print "-L size of LINUXLIVE partition in GB default is $linuxlivesize " . "GB ext4\n";
	print "-W size of writable partition in GB default is $writablesize " . "GB ext4 persistence partition\n";
	print "-M size of MACRIUM partition in GB default is $macriumsize " . "GB fat32\n";
	print "-T size of MCTREC partition in GB default is $mctrecsize ". "GB fat32\n";
	print "-U uuid of LINUXLIVE partition:\n\text4 default: $linuxliveuuiddefault\n\tvfat default: $linuxlivevolumeiddefault\n";
	print "-v verbose operation\n";
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
#                    partition 1 EFI size 1GB or "" for vfat option
#                    partition 2 LINUXLIVE size GB
#                    partition 3 writable size GB
#                    partition 4 MACRIUM size GB
#                    partition 5 MCTREC size GB
# 					 format options -v; or -q for ext4, "" for vfat
# sub aborts on any error
# requires: disk for MACRIUM to be attached, not mounted
######################################################
sub partitiondisk {
	# get uuid and size of partitions
	my $linuxliveuuid = shift @_;
	
	# for the vfat case efisize = ""
	my $efisize = shift @_;
	my $linuxlivesize = shift @_;
	my $writablesize = shift @_;
	my $macriumsize = shift @_;
	my $mctrecsize = shift @_;
	my $formatoptions = shift @_;

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
	$rc = system("lsblk -o PATH,LABEL,FSTYPE,SIZE $device");
	die "aborting: error from lsblk\n" unless $rc == 0;
	print "######################################################\n";

	# also show the model no of the disk
	my @model = `lsblk -o MODEL $device`;
	chomp(@model);
		
	# calculate size of data partition partition -- last partition
	# size = disk size  - (linuxlivesize + writablesize + mctrecsize)
	if ($efisize ne "") {
		# partitioning for ext4 option
		my $datasize = $devicesize - ($efisize + $linuxlivesize + $writablesize + $mctrecsize);
		
		print "\n\nThe disk will be partitioned as follows:\n";
		print "Model = $model[1]\nDevice = $device\nDisk size = $devicesize GB\np1: EFI parition = $efisize GB\np2: LINUXLIVE partition = $linuxlivesize GB uuid = $linuxliveuuid\np3: writable partition = $writablesize GB\np4: MACRIUM partion = $macriumsize GB\np5: MCTREC partition = $mctrecsize GB\np6: ele partition = $datasize GB\n";
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
			print "\n+++++++++++++++++++++++++++++++++++++++++++++++\n";
			print "formatting partition EFILIVE " . $device . "1\n";
			$rc = system( "mkfs.vfat $formatoptions -n EFILIVE " . $device . "1");
			die "aborting: error formatting " . $device . "1\n" unless $rc == 0;
			print "\n+++++++++++++++++++++++++++++++++++++++++++++++\n";

			# format parition 2 LINUXLIVE
			print "\n+++++++++++++++++++++++++++++++++++++++++++++++\n";
			print "formatting partition LINUXLIVE " . $device . "2\n";
			# only for ext4 formatting : no verbose -q; verbose -v
			my $ext4options;
			if ($formatoptions eq "") {
				$ext4options = "-q";
			} else {
				# -v was given
				$ext4options = "-v";
			}
			$rc = system("mkfs.ext4 $ext4options -j -L LINUXLIVE -U $linuxliveuuid " . $device . "2");
			die "aborting: error formatting " . $device . "2\n" unless $rc == 0;
			print "\n+++++++++++++++++++++++++++++++++++++++++++++++\n";

			# format parition 3 writable
			print "\n+++++++++++++++++++++++++++++++++++++++++++++++\n";
			print "formatting partition writable " . $device . "3\n";
			$rc = system("mkfs.ext4 $ext4options -j -L writable " . $device . "3");
			die "aborting: error formatting " . $device . "3\n" unless $rc == 0;
			print "\n+++++++++++++++++++++++++++++++++++++++++++++++\n";

			# format partition 4 MACRIUM
			print "\n+++++++++++++++++++++++++++++++++++++++++++++++\n";
			print "formatting partition MACRIUM " . $device . "4\n";
			$rc = system( "mkfs.vfat $formatoptions -n MACRIUM -i AED6434E " . $device . "4");
			die "aborting: error formatting " . $device . "4\n" unless $rc == 0;
			print "\n+++++++++++++++++++++++++++++++++++++++++++++++\n";

			# format partition 5 MCTREC
			print "\n+++++++++++++++++++++++++++++++++++++++++++++++\n";
			print "formatting partition MCTREC " . $device . "5\n";
			$rc = system("mkfs.vfat $formatoptions -n MCTREC -i 44444444 " . $device . "5");
			die "aborting: error formatting " . $device . "5\n" unless $rc == 0;
			print "\n+++++++++++++++++++++++++++++++++++++++++++++++\n";

			# format parition 6 data
			print "\n+++++++++++++++++++++++++++++++++++++++++++++++\n";
			print "formatting partition data " . $device . "6\n";
			$rc = system("mkfs.ntfs $formatoptions -Q -L data  " . $device . "6");
			die "aborting: error formatting " . $device . "6\n" unless $rc == 0;
			print "\n+++++++++++++++++++++++++++++++++++++++++++++++\n";

		} else {
			print "$device was not partitioned\n";
			exit 1;
		}
	} else {
		# for vfat option
		# calculate size of last partition
		# size = disk size  - (linuxlivesize + writablesize + mctrecsize)
		my $datasize = $devicesize - ($linuxlivesize + $writablesize + $mctrecsize);

		print "\n\nThe disk will be partitioned as follows:\n";
		print "Model = $model[1]\nDevice = $device\nDisk size = $devicesize GB\np1: LINUXLIVE partition = $linuxlivesize GB\np2: writable partition = $writablesize GB\np3: MACRIUM partion = $macriumsize GB\np4: MCTREC partition = $mctrecsize GB\np5: ele partition = $datasize GB\n";
		print "\n\nAll data on $device will be deleted: is this correct (yes|no)?\n";
		my $answer = <STDIN>;
		chomp($answer);

		if ($answer =~ /^yes$/i) {
			print "partitioning $device\n";

			# partition 1: LINUXLIVEv parition fat32
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

			# format parition 1 LINUXLIVEv
			print "\n+++++++++++++++++++++++++++++++++++++++++++++++\n";
			print "formatting partition " . $device . "1\n";
			$rc = system("mkfs.vfat $formatoptions -n LINUXLIVEV -i $linuxliveuuid " . $device . "1");
			die "aborting: error formatting " . $device . "1\n" unless $rc == 0;

			# format parition 2 writable
			# for ext4 only no verbose = -q; verbose = -v
			print "\n+++++++++++++++++++++++++++++++++++++++++++++++\n";
			my $ext4options;
			if ($formatoptions eq "") {
				$ext4options = "-q";
			} else {
				# -v was given
				$ext4options = "-v";
			}

			print "formatting partition " . $device . "2\n";
			$rc = system("mkfs.ext4 $ext4options -j -L writable " . $device . "2");
			die "aborting: error formatting " . $device . "2\n" unless $rc == 0;
			print "\n+++++++++++++++++++++++++++++++++++++++++++++++\n";

			# format partition 3 MACRIUM
			print "\n+++++++++++++++++++++++++++++++++++++++++++++++\n";
			print "formatting partition " . $device . "3\n";
			$rc = system( "mkfs.vfat $formatoptions -n MACRIUM -i AED6434E " . $device . "3");
			die "aborting: error formatting " . $device . "3\n" unless $rc == 0;
			print "\n+++++++++++++++++++++++++++++++++++++++++++++++\n";

			# format partition 4 MCTREC
			print "\n+++++++++++++++++++++++++++++++++++++++++++++++\n";
			print "formatting partition " . $device . "4\n";
			$rc = system("mkfs.vfat $formatoptions -n MCTREC -i 44444444 " . $device . "4");
			die "aborting: error formatting " . $device . "4\n" unless $rc == 0;
			print "\n+++++++++++++++++++++++++++++++++++++++++++++++\n";

			# format parition 5 ele
			print "\n+++++++++++++++++++++++++++++++++++++++++++++++\n";
			print "formatting partition " . $device . "5\n";
			$rc = system("mkfs.ntfs $formatoptions -Q -L data  " . $device . "5");
			die "aborting: error formatting " . $device . "5\n" unless $rc == 0;
			print "\n+++++++++++++++++++++++++++++++++++++++++++++++\n";

		} else {
			print "$device was not partitioned\n";
			exit 1;
		}

	}	
}

###############################
# main entry
###############################

# -E is size of EFI partition only for ext4 option
# -L is size of LINUXLIVE
# -W is size of writable partition for persitence in GB default is 10GB
# -M is size of  MACRIUM partition in GB default is 2GB
# -T is size of MCRECT partition in GB default is 8GB
# -U is for the uuid of the LINUXLIVE partition
# -v verbose option

# set uuid
# set defaults in GB
getopts('efvU:E:L:D:W:M:T:h');

# display help and exit if -h given
usage () if $opt_h;

# set defaults
# formating options for vfat and ext4
my $formatoptions = "";
my $linuxliveuuid;

$formatoptions = "-v" if $opt_v;

if ($opt_e) {
	# values for ext4 option
	$linuxliveuuid = $linuxliveuuiddefault;
	$efisize = $opt_E if $opt_E;

} elsif ($opt_f) {
	# values for vfat option
	$linuxliveuuid = $linuxlivevolumeiddefault;
	$efisize = "";
	
} else {
	# -e and -f were not given
	die "One of -e or -f must be given\n";
}

# die if -e and -f given.
die "-e ext4 and -f vfat cannot both be given\n" if $opt_e and $opt_f;


# set uuid ext4 or volume id vfat if -U given
$linuxliveuuid = $opt_U if $opt_U;

# set linuxlive size
$linuxlivesize = $opt_L if $opt_L;

# set writable size
$writablesize = $opt_W if $opt_W;

# set size for microsoft media creation tool 
$mctrecsize = $opt_T if $opt_T;

# set size of macrium partition
$macriumsize = $opt_M if $opt_M;

print "format options: $formatoptions linuxuuid: $linuxliveuuid efi size: $efisize\n";

# partition disk, efsize set for ext4 and set to "" for vfat case
partitiondisk($linuxliveuuid, $efisize, $linuxlivesize, $writablesize, $macriumsize, $mctrecsize, $formatoptions);
