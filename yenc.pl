#!/usr/bin/env perl

use strict;
use warnings;

#These characters will result in characters that need to be further
#encoded and escaped (ascii 0, tab, LF, CR, ., =)
#(223 + 42) % 256 = 9
#(224 + 42) % 256 = 10 
#(227 + 42) % 256 = 13 
#(4 + 42)   % 256 = 46
#(19 + 42)  % 256 = 61

my @esc_list = (0, 9, 10, 13, 46, 61);
my @esc_char = sort {
    $a <=> $b 
} map $_ > 42 ? $_ - 42 : $_ + 214, @esc_list;
my @yenc_list = map $_ ~~ @esc_list ? "=" . chr(($_ + 64) % 256) : chr($_), 
    map (($_ + 42) % 256, (0 .. 255));
my %yenc_map = ();
@yenc_map{map chr($_), 0 .. 255} = @yenc_list;
my %ydec_map = reverse %yenc_map;

sub yenc_line {
    my ($line, $line_length, @esc_char) = @_;
    my @line_list = split '', $line;
    my $esc_ct = grep ord($_) ~~ @esc_char,  @line_list;
    return join '', map $yenc_map{$_}, (
    	@line_list + $esc_ct > $line_length ? 
    	@line_list[0 .. $#line_list - $esc_ct] : @line_list
    );
}

sub ydec_line {
    #Empty lists don't affect the outcome
    no warnings qw(uninitialized);
    my $line = shift;
    my @segment = split '=', $line;
    return join '', ((map $ydec_map{$_}, split '', $segment[0]), map { 
	my @code = split '', $_;
	join '', ($ydec_map{"=$code[0]"}, (map $ydec_map{$_}, @code[1 .. $#code]));
    } @segment[1 .. $#segment]);
}
