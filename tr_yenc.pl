#!/usr/bin/env perl

use strict;
use warnings;
use String::CRC32;

sub yenc {

    # Take an input file handle and write to output file handle
    my $input = $_[0];
    my $output = $_[1];

    my $line = '';
    my $bytes_processed = 0;
    my $crc = 0;
    my $eq = "=";
    my $crlf = "\r\n";
    my @esc_pos = ();
    my @enc_section = ();
    my @remaining_section = ();
    while (my $cnt = read($input, $line, 128) || length $remaining_section[0]) {
        $line = join "", (@remaining_section, $line) if @remaining_section;
        @remaining_section = ();
        $bytes_processed += $cnt;
        $crc = crc32($line, $crc);
        @esc_pos = get_esc_positions(\$line);
        if (@esc_pos) {
            my $enc_length = 0;
            my @section = unpack get_unpack_str(\@esc_pos), $line;
            while (my ($idx, $section) = each @section) {
                $enc_length += length $section;
                if ($idx == 0) {
                    if ($enc_length > 127) {
                        # Split at character 128
                        my ($f, $s) = unpack "a128 a*", $section;
                        push @enc_section, (yenc_string(\$f), \$crlf);
                        push @remaining_section, $s;
                        last;
                    }
                    push @enc_section, yenc_string(\$section);
                } else {
                    # Account for escape character
                    ++$enc_length;
                    if ($enc_length > 127) {
                        my $diff = 127 - $enc_length + (length $section) + 1;

                        # If the difference between 127 and the encoded length
                        # so far plus the length of the next section with its
                        # escape character is zero, that means that the line
                        # ends with an escape character and the character after
                        # that should be included when encoding this section.
                        ++$diff if $diff == 0;
                        my ($f, $s) = unpack "a$diff a*", $section;
                        push @enc_section, (\$eq, yenc_string(\$f), \$crlf);
                        push @remaining_section, $s;
                        last;
                    }
                    push @enc_section, (\$eq, yenc_string(\$section));

                    # If we're on the last section and the encoded lenght is
                    # less than or equal to 127, then append a CRLF
                    if ($enc_length <= 127 && $idx == $#section) {
                        push @enc_section, \$crlf;
                    }
                }
            }
        } else {
            my ($f, $s) = unpack "a128 a*", $line;
            push @enc_section, yenc_string(\$f), \$crlf;
            push @remaining_section, $s;
        }
        print map $$_, @enc_section;
        @enc_section = ();
    }
    return ($bytes_processed, $crc);
}

sub get_esc_positions {

    my $str = $_[0];

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
    return @pos_list;
}


sub get_unpack_str {

    my $pos_list = $_[0];

    my @diff_list = ();
    my ($first, $second) = (0, 1);
    while ($second <= $#{$pos_list}) {
        push @diff_list, "a" . ($$pos_list[$second] - $$pos_list[$first]);
        ++$first;
        ++$second;
    }
    my $unpack_str = "a$$pos_list[0] ";
    $unpack_str .= join " ", @diff_list;
    $unpack_str .= " a*";
    return $unpack_str;
}


sub yenc_string {

    my $str = $_[0];

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


sub main {

    print yenc_header(128, 0, "unknown");
    my ($size, $crc) = yenc(*STDIN, *STDOUT);
    print yenc_footer($size, $crc);
}

__PACKAGE__->main() unless caller;

# vim: et sw=4 ts=4 tw=79 sts=4
