#!/usr/bin/env perl

use strict;
use warnings;
use String::CRC32;

sub yenc {

    # Take an input file handle and write to output file handle
    my $input = $_[0];
    my $output = $_[1];

    my $line = '';
    my $enc_line = '';
    my $bytes_processed = 0;
    my $crc = 0;
    my $crlf = "\r\n";
    my @esc_pos = ();
    while (my $cnt = read($input, $line, 128) || $enc_line ne '') {
        $bytes_processed += $cnt;
        $crc = crc32($line, $crc);
        $enc_line = "$enc_line${yenc_string(\$line)}";
        my $insert_idx;

        if (length($enc_line) < 128) {
            $insert_idx = length($enc_line);
            $enc_line = insert(\$crlf, $insert_idx, \$enc_line);
        } else {
            # Determine where to insert the CRLF. If (zero-based)
            # position 127 is an '=' character, then add CRLF at
            # position 129. Otherwise, add it at position 128.
            my $end_chr = unpack "x127 a1", $enc_line;
            $insert_idx = $end_chr eq '=' ? 129 : 128;
            $enc_line = insert(\$crlf, $insert_idx, \$enc_line);
        }

        # Print the line
        my $eol = $insert_idx + 2;
        print $output unpack "a$eol", $enc_line;
        last if length($enc_line) < 128;
        $enc_line = unpack "x$eol a*", $enc_line;
    }
    return ($bytes_processed, $crc);
}


sub yenc_string {

    my $str = $_[0];

    my $eq = '=';
    my @pos_list = ();

    # These ascii codes in the original string will result in characters
    # that need to be escaped in the encoded string
    # \xd6 -> 214 + 42 = 256 % 256 = 0 (NUL)
    # \xe0 -> 224 + 42 = 266 % 256 = 10 (LF)
    # \xe3 -> 227 + 42 = 269 % 256 = 13 (CR)
    # \x13 -> 19 + 42 = 61 % 256 = 61 (=)
    while ($$str =~ /[\xd6\xe0\xe3\x13]/g) {
        push @pos_list, (pos($$str) - 1);
    }

    # This tr will yenc characters including those that need to be
    # escaped yenc is ascii (value + 42) % 256.
    # If the resulting value is one of 0 (NUL), 10 (LF), 13 (CR), or 61
    # (=), then add 64 and mod by 256
    #
    # How it works
    # ascii 0 through 18 -> ascii 42 through 60
    # ascii 19 -> ascii 125 (ascii 61 (=) + 64) (=})
    # ascii 20 through 213 -> ascii 62 through 255
    # ascii 214 -> ascii 64 (ascii 0 (NUL) + 64) (=@)
    # ascii 215 through 223 -> ascii 1 through 9
    # ascii 224 -> ascii 74 (ascii 10 (LF) + 64) (=J)
    # ascii 225 through 226 -> ascii 11 through 12
    # ascii 227 -> ascii 77 (ascii 13 (CR) + 64) (=M)
    # ascii 228 through 255 -> ascii 14 through 41
    $$str =~ tr/\x00-\xff/*-<}>-\xff@\x01-\x09J\x0b\x0cM\x0e-)/;

    # Now add escape characters
    # for my $pos (sort { $b <=> $a } @$esc_positions) {
    for my $pos (sort { $b <=> $a } @pos_list) {
        $$str = insert(\$eq, $pos, $str);
    }
    return $str;
}

sub yenc_header {

    my ($line, $size, $name) = @_;
    return "=ybegin line=$line size=$size name=$name\r\n";
}

sub yenc_footer {

    my ($size, $crc32) = @_;
    return "=yend size=$size crc32=" . sprintf "08%x", $crc32 . "\r\n";
}


sub insert {
    my ($chr, $idx, $str) = @_;

    my ($first, $second) = unpack "a$idx a*", $$str;
    return join '', ($first, $$chr, $second);
}


sub main {

    print yenc_header(128, 0, "unknown");
    my ($size, $crc) = yenc(*STDIN, *STDOUT);
    print yenc_footer($size, $crc);
}

__PACKAGE__->main() unless caller;

# vim: et sw=4 ts=4 tw=79 sts=4
