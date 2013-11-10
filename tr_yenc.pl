#!/usr/bin/env perl

use strict;
use warnings;

sub yenc_string {
    my $str = $_[0];
    my @esc_positions = get_esc_positions($str);

    #This tr will yenc characters including those that need to be escaped
    $str =~ tr/\x00-\xff/*-\-n\/-<}>-\xff@\x01-\x08IJ\x0b\x0cM\x0e-)/;

    #Now add escape characters
    for my $pos (sort { $b <=> $a } @esc_positions) {
        $str = insert('=', $pos, $str);
    }

    return $str;
}

sub get_esc_positions {
    my $str = $_[0];
    my @pos_list = ();
    my %substrs = ();
    while ($str =~ /[\xd6\xdf\xe0\xe3\x04\x13]/g) {
        push @pos_list, (pos($str) - 1);
    }
    return @pos_list;
}

sub insert {
    my ($chr, $idx, $str) = @_;
    return (substr $str, 0, $idx) . $chr . (substr $str, $idx);
}

my $str = join '', map { chr $_ } (0 .. 255);
my $yenc_str = yenc_string($str);
print $yenc_str;

#vim: et sw=4 ts=4 tw=79 sts=4
