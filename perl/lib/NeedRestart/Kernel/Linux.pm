# needrestart - Restart daemons after library updates.
#
# Authors:
#   Thomas Liske <thomas@fiasko-nw.net>
#
# Copyright Holder:
#   2013 - 2014 (C) Thomas Liske [http://fiasko-nw.net/~thomas/]
#
# License:
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this package; if not, write to the Free Software
#   Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
#

package NeedRestart::Kernel::Linux;

use strict;
use warnings;
use NeedRestart::Utils;
use NeedRestart::Strings;
use POSIX qw(uname);
use Sort::Naturally;
use Fcntl qw(SEEK_SET);

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(
    nr_linux_check
    nr_linux_version_x86
);

my $LOGPREF = '[Kernel/Linux]';

sub nr_linux_version_x86($$) {
    my $debug = shift;
    my $fn = shift;

    my $fh;
    unless(open($fh, '<', $fn)) {
	print STDERR "$LOGPREF Could not open kernel image ($fn): $!\n" if($debug);
	return undef;
    }
    binmode($fh);

    my $buf;

    # get kernel_version address from header
    seek($fh, 0x20e, SEEK_SET);
    read($fh, $buf, 2);
    my $offset = unpack 'v', $buf;

    # get kernel_version string
    seek($fh, 0x200 + $offset, SEEK_SET);
    read($fh, $buf, 128);
    close($fh);

    $buf =~ s/\000.*$//;
    return undef if($buf eq '');

    unless($buf =~ /^\d+\.\d+/) {
	print STDERR "$LOGPREF Got garbage from kernel image header ($fn): '$buf'\n" if($debug);
	return undef;
    }

    return $buf;
}

sub nr_linux_check($$) {
    my $debug = shift;
    my $ui = shift;

    my ($sysname, $nodename, $release, $version, $machine) = uname;

    my @kfiles = reverse nsort </boot/vmlinu*>;
    $ui->progress_prep(scalar @kfiles, 'Scanning kernel images...');

    my %kernels;
    foreach my $fn (@kfiles) {
	$ui->progress_step;
	my $stat = nr_stat($fn);

	if($stat->{size} < 1000000) {
	    print STDERR "$LOGPREF $fn seems to be too small\n" if($debug);
	    next;
	}

	my $verstr = nr_linux_version_x86($debug, $fn);
	unless(defined($verstr)) {
	    $verstr = nr_strings($debug, qr/^(Linux version )?\d\.\d+\S*\s/, $fn);

	    unless(defined($verstr)) {
		print STDERR "$LOGPREF Could not get version string from $fn.\n" if($debug);
		next;
	    }
	}

	my $iversion = $verstr;
	$iversion =~ s/^Linux version //;
	chomp($iversion);
	$iversion =~ s/\s.+$//;
	$kernels{$iversion} = (index($verstr, $release) != -1 && index($verstr, $version) != -1);

	print STDERR "$LOGPREF $fn => $verstr [$iversion]".($kernels{$iversion} ? '*' : '')."\n" if($debug);
    }
    $ui->progress_fin;

    return (undef, "Did not find any kernel images (/boot/vmlinu*)!")
	unless(scalar keys %kernels);

    my ($eversion) = reverse nsort keys %kernels;
    print STDERR "$LOGPREF Expected kernel version: $eversion\n" if($debug);

    return ($release, qq(Not running the expected kernel version $eversion.))
	if($release ne $eversion);

    return ($release, qq(Running kernel has an ABI compatible upgrade pending.))
	unless($kernels{$release});

    return ($release, undef);
}

1;
