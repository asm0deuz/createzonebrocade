#!/usr/bin/perl
#
#Teoman ONAY 15/09/2012
#Generates commands to create new zones on Brocade switches
# parameters are :
# -a alias
# -h hostname
# -w wwn
# -t aix/open/iseries/vnx
# -l bxla/drpa/bxla/bxlb
# -f input file
#
#
# Only the following combinations are possible :
# newzone.pl -a alias -t aix/open/iseries -l bxl/drp
# newzone.pl -h host -w wwn -t aix/open/series -l bxl/drp
# newzone.pl -f inputfilename
# inputfilename format :
#
# a;alias;aix;drp
# h;host;wwn;aix;drp
#
# a means alias and h means host.
#
# Add lowercase wwn
# check eof
#

use strict;
use warnings;

use Getopt::Std;

my %options = ();
getopts("a:f:h:l:t:w:",\%options);
if ($options{f}) {
    open ALIASA, ">aliasa.txt" or die $!;
    open ALIASB, ">aliasb.txt" or die $!;
    open ZONEA, ">zonesa.txt" or die $!;
    open ZONEB, ">zonesb.txt" or die $!;
    
    my $inputFile = $options{f};
    open CSV, "<", $inputFile or die $!;
    
    my @configA;
    my @configB;
    my $prodConfA = "DEGROOF_PROD";
    my $prodConfB = "IRIS_IM0_23032012";
    while (<CSV>) {
        chomp;
        my @temp = split (",", $_);
        if ($temp[0] eq "h") {
            #create alias files
            my $curAlias = &generateAlias($temp[1],$temp[2]);
            if ($temp[4] eq "bxla" or $temp[4] eq "drpa") {
                print ALIASA "alicreate \"".$curAlias."\",\"".$temp[2]."\"\n";
            } else {
                print ALIASB "alicreate \"".$curAlias."\",\"".$temp[2]."\"\n";
            }
            #create zone files
            if ($temp[4] eq "bxla") {
                @configA = (@configA, &writeZones(\@temp,$curAlias));
            }
            if ($temp[4] eq "bxlb") {
                @configB = (@configB, &writeZones(\@temp,$curAlias));
            }
            if ($temp[4] eq "drpa") {
                @configA = (@configA, &writeZones(\@temp,$curAlias));
            }
            if ($temp[4] eq "drpb") {
                @configB = (@configB, &writeZones(\@temp,$curAlias));
            }
        }
    }

    close $inputFile;
    close ALIASA;
    close ALIASB;
    open ZONEA, ">>zonesa.txt" or die $!;
    open ZONEB, ">>zonesb.txt" or die $!;
    print ZONEA &addToConfig($prodConfA,@configA); 
    print ZONEB &addToConfig($prodConfB,@configB); 
    close ZONEB;
    close ZONEA;

}

# Given host & wwn generates alias
sub generateAlias {
    my ($host, $wwn) = @_;
    $host = &cleanName($host);
    my $alias;
    my $prefix = "a_";
    $wwn =~ s/://g;
    $wwn = substr $wwn, -4;
    $alias = $prefix.$host."_".$wwn;
}

sub generateZoneName {
    my ($hostAlias, $storageAlias) = @_;
    my $zoneName;
    my $prefix = "z_";
    my $host = substr $hostAlias, 2;
    my $stor = substr $storageAlias, 2;
    $zoneName = $prefix.$host."_".$stor;
}

#check if the wwn is well formatted
sub checkWwn {
    my $wwn = shift;
    $wwn =~ m/^([0-9a-fA-F]{2}[:]){7}([0-9a-fA-F]{2})$/ 
}

sub writeZones {
    my $line = shift;
    my $curAlias = shift;
   
    my @zones;
    open FILE, $line->[4].".txt" or die $!;
    while (<FILE>) {
        my @temp = split (",", $_);
        if ( $temp[0] eq $line->[3]) {
            my $zoneName = &generateZoneName($curAlias,$temp[1]);
            my $destStor = $temp[1];
            chomp($zoneName);
            chomp($destStor);
            if (substr($line->[4],-1,1) eq "a") {
                print ZONEA "zonecreate ".$zoneName.",\"".$curAlias.";".$destStor."\"\n";
            } else {
                print ZONEB "zonecreate ".$zoneName.",\"".$curAlias.";".$destStor."\"\n";
            }
            push(@zones, $zoneName);
        }
    }
    close FILE;
    return @zones;
}

sub addToConfig {
    my $config = shift;
    my @zones = @_;

    my $command .= "cfgadd ".$config.",\"";
    foreach my $zoneToAdd (@zones) {
         $command .= $zoneToAdd.";";
    }
    $command =~ s/;$/"\n/;
    return $command;
}

#convert to lowercase & replaces - by _
sub cleanName {
    my $name = shift;

    $name =~ s/-/_/g;
    $name = lc $name;
}

