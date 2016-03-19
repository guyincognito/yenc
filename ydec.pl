=head1 ydec_file

C<ydec> method decodes a yencoded string.  It takes an input and an output
filehandle.  It reads from the input file and writes the decoded data to the
output file.  It will filter out any data that's not between the =ybegin/=ypart
and =yend markers.

=over

=item *

C<0x01> through C<0x09> map to C<0xd7> through C<0xdf>

=item *

C<0x0b> maps to C<0xe1>

=item *

C<0x0c> maps to C<0xe2>

=item *

C<0x0e> through C<0x29> map to C<0xe4> through C<0xff>

=item *

C<0x2a> through C<0x3c> map to C<0x00> through C<0x12>

=back

This reverses the yencoding process of taking an ascii character value,
adding C<0x1A> to it and taking its modulus by C<0x100>. If the escape
flag is true, then it will take the escape sequences (C<=}>, C<=J>,
C<=@>, C<=M>, C<=I>, C<=n>), and return the corresponding decoded
characters (C<=> for C<=}>, C<NUL> for C<=@>, C<LF> for C<=J>, C<CR> for
C<=M>, C<TAB> for C<=I>, and C<.> for C<=n>).

=cut

sub ydec_file {
    my $in = $_[0];
    my $out = $_[1];

    my $line;
    my $yenc_data;
    my %esc_map = (

        # Escaped = (since it is the character used to indicate an escape
        # sequence)
        "=}" => "\x13",

        # Escaped NUL
        "=@" => "\xd6",

        # Escaped LF
        "=J" => "\xe0",

        # Escaped CR
        "=M" => "\xe3",

        # Tab characters are not escaped in the latest version of yenc
        "=I" => "\xdf", 

        # Period character only needs to be escaped if it's the first
        # character in a line
        "=n" => "\x04",

        # Space character shouldn't have to be escaped, but it is in some
        # yenc data.
        "=`" => "\xf6",
    );

    sub get_esc_positions {
        my $pos_list = [];
        my $position = 0;
        while (1) {
            my $pos = index ${$_[0]}, '=', $position;
            last if $pos == -1;
            push @$pos_list, $pos;
            $position = $pos + 1;
        }
        return $pos_list;
    }

    sub get_segments {
        my $esc_pos = get_esc_positions($_[0]);
        unless (@$esc_pos) {
            return (${$_[0]});
        }
        my @unpack_list = ();
        while (my ($idx, $pos) = each @$esc_pos) {
            if ($idx == 0) {
                push @unpack_list, "a${pos}a2";
            } else {
                my $diff = $pos - $esc_pos->[$idx - 1] - 2;
                push @unpack_list, "a${diff}a2";
            }
            if ($idx == $#$esc_pos) {
                push @unpack_list, "a*";
            }
        }
        return unpack((join '', @unpack_list), ${$_[0]});
    }

    sub ydec {
        if (length($_[0]) == 2 && index($_[0], '=') != -1 ) {
            return $esc_map{$_[0]};
        }
        $_[0] =~ tr/\x01-\x09\x0b\x0c\x0e-\x29\x2a-\x3c\x3e-\xff/\xd7-\xdf\xe1\xe2\xe4-\xff\x00-\x12\x14-\xd5/;
        return $_[0];
    }

    while ($line = <$in>) {
        if ($line =~ /^=ybegin/) {
            $yenc_data = 1;
            #print "Found ybegin line $line\n";
        } elsif ($yenc_data == 1 && $line =~ /^=ypart/) {
            $yenc_data = 2;
            #print "Found ypart line $line\n";
        } elsif ($line =~ /^=yend/) {
            $yenc_data = 0;
            #print "Found yend line $line\n";
        } elsif ($yenc_data == 1 || $yenc_data == 2) {
            #print "process yenc data with $line\n";
            #$line =~ s/\x0d?\x0a$//;
            $line =~ s/\x0a$//;
            print $out map { ydec $_ } get_segments(\$line);
        } else {
            #print "Skipping $line\n";
        }
    }
}

my $in_file = $ARGV[0];
my $out_file = $ARGV[1];

print "in_file $in_file; out_file $out_file\n";

open my $input, '<', $in_file;
open my $output, '>', $out_file;
ydec_file($input, $output);
