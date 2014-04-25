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

package NeedRestart::UI::Dialog;

use strict;
use warnings;

use parent qw(NeedRestart::UI);
use NeedRestart qw(:ui);
use UI::Dialog;

needrestart_ui_register(__PACKAGE__, NEEDRESTART_PRIO_MEDIUM);

sub new {
    my $class = shift;
    my $debug = shift;

    return bless {
	debug => $debug,
	dialog => new UI::Dialog(backtitle => 'needrestart'),
    }, $class;
}

sub progress_prep($$$$) {
    my $self = shift;
    my ($max, $out, $pass) = @_;

    $|++;

    print "$out";
}

sub progress_step($$) {
    my $self = shift;
    my $bin = shift;

    print '.' if($bin);
}

sub progress_fin($) {
    my $self = shift;

    print "\n";

    $|--;
}


sub announce {
    my $self = shift;
    my $kversion = shift;
    my $kmessage = shift;

    $self->{dialog}->msgbox(title => 'Pending kernel upgrade', text => "Running kernel version:\n  ${kversion}\n\nDiagnostics:\n  ${kmessage}\n\nYou should consider to reboot this machine to activate the pending kernel upgrade. You need to reboot MANUALLY! [Return]\n");
}


sub notice($$) {
    my $self = shift;
    my $out = shift;

    $self->{dialog}->msgbox(title => 'Notice', text => $out);
}


sub query_pkgs($$$$$) {
    my $self = shift;
    my $out = shift;
    my $def = shift;
    my $pkgs = shift;
    my $cb = shift;

    # prepare checklist array
    my @l = sort keys %$pkgs;

    # get selected rc.d script
    my @s = $self->{dialog}->checklist(text => $out, list => \@l);

    # restart each selected service
    &$cb($_) for @s;
}

1;
