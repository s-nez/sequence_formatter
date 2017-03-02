#!/usr/bin/perl
use strict;
use warnings;
use feature qw[ say state ];
use autodie;
use Getopt::Long;
use Term::ANSIColor qw[ color colorvalid ];

my ($limit, $color_base, $color_complement) = (20);
my @ind_to_highlight;
GetOptions(
    'limit=i'            => \$limit,
    'color-base=s'       => \$color_base,
    'color-complement=s' => \$color_complement,
    'highlight=i'        => \@ind_to_highlight,
) or die "Invalid arguments\n";

# Validate options
die "--limit must be a positive integer\n" unless $limit > 0;
die "--highlight must be a positive integer\n"
  foreach grep { $_ <= 0 } @ind_to_highlight;

foreach my $color ($color_base, $color_complement) {
    die "Invalid color: $color\n" if defined $color and not colorvalid($color);
    die "Bold colors not supported with --highlight\n"
      if defined $color
      and @ind_to_highlight
      and index($color, 'bold') != -1;
}
die "Specify a single input filename\n" unless @ARGV == 1;
my ($filename) = @ARGV;

my @buffer;
open my $fh_seq, '<', $filename;
while (<$fh_seq>) {
    chomp;
    push @buffer, map { { val => $_, highlight => 0 } } /([ATCG]{3})/g;
    print_chunk(\@buffer, $limit) while @buffer >= $limit;
}

print_chunk(\@buffer, scalar @buffer) if @buffer;

sub print_chunk {
    my ($buffer_ref, $limit) = @_;

    my @print_set = splice @$buffer_ref, 0, $limit;
    mark_highlight(@print_set);

    print_colored(\@print_set, $color_base);
    $_->{val} =~ tr/ATCG/TAGC/ foreach @print_set;
    print_colored(\@print_set, $color_complement);
    print "\n";

    return;
}

sub print_colored {
    my ($set_ref, $color) = @_;

    print color($color) if defined $color;
    say join ' ', map { highlight_entry($_, $color) } @$set_ref;
    print color('reset') if defined $color;

    return;
}

sub highlight_entry {
    my ($entry_ref, $base_color) = @_;
    return $entry_ref->{val} unless $entry_ref->{highlight};
    my $colored_entry = color('bold') . $entry_ref->{val} . color('reset');
    $colored_entry .= color($base_color) if defined $base_color;
    return $colored_entry
}

sub mark_highlight {
    my @buffer = @_;
    return unless @ind_to_highlight;
    
    state $index_offset = 0;
    my $range_limit = $index_offset + $#buffer;

    my %highlight =
      map { $_ => 1 }
      grep { $index_offset <= $_ and $_ <= $range_limit } @ind_to_highlight;

    foreach my $ind (keys @buffer) {
        my $total_ind = $index_offset + $ind;
        $buffer[$ind]{highlight} = 1 if $highlight{$total_ind};
    }

    $index_offset += @buffer;

    return;
}

__END__
=pod

=head1 NAME

seq_format.pl - display DNA sequences with complements

=head1 DESCRIPTION

This script reads a file containing DNA sequences and outputs it
in a readable way, with the sequences split into codons.
It also adds the complementary line and allows for custom coloring
and highlighting of selected codons.

=head2 File format

The file needs to contain three letter sequences of the letters:
B<A>, B<T>, B<C> and B<G>. They can be separated by different
characters or appear continuously, so all of those are valid formats:

    ATC HCT CGA CGT CAT CGC AGC ATT

    ATCHCTCGACGTCATCGCAGCATT

    ATC:HCT:CGACGTCATCGC:AGC,ATT

Note that there can be no other characters between members of the same
codon, so the following format is not acceptable:

    A T C H C T CG CAG C ATT

=head2 Example use

The script allows highlighting of chosen codons. Let's assume a file
seq.txt with the following content:

    GCTAGCGTTTAAACTTAAGCTTGGTACCACCATGAGGACTCTGAACACCTCTGCCATGGA
    CGGGACTGGGCTGGTGGTGGAGAGGGACTTCTCTGTTCGTATCCTCACTGCCTGTTTCCT
    GTCGCTGCTCATCCTGTCCACGCTCCTGGGGAACACGCTGGTCTGTGCTGCCGTTATCAG
    GTTCCGACACCTGCGGTCCAAGGTGACCAACTTCTTTGTCATCTCCTTGGCTGTGTCAGA
    TCTCTTGGTGGCCGTCCTGGTCATGCCCTGGAAGGCAGTGGCTGAGATTGCTGGCTTCTG

To display the sequence, 15 codons per line and find the 27th codon,
we could use:

    perl seq_format.pl --limit 15 seq.txt

The output would look like this:

    GCT AGC GTT TAA ACT TAA GCT TGG TAC CAC CAT GAG GAC TCT GAA
    CGA TCG CAA ATT TGA ATT CGA ACC ATG GTG GTA CTC CTG AGA CTT

    CAC CTC TGC CAT GGA CGG GAC TGG GCT GGT GGT GGA GAG GGA CTT
    GTG GAG ACG GTA CCT GCC CTG ACC CGA CCA CCA CCT CTC CCT GAA

    CTC TGT TCG TAT CCT CAC TGC CTG TTT CCT GTC GCT GCT CAT CCT
    GAG ACA AGC ATA GGA GTG ACG GAC AAA GGA CAG CGA CGA GTA GGA

    GTC CAC GCT CCT GGG GAA CAC GCT GGT CTG TGC TGC CGT TAT CAG
    CAG GTG CGA GGA CCC CTT GTG CGA CCA GAC ACG ACG GCA ATA GTC

    GTT CCG ACA CCT GCG GTC CAA GGT GAC CAA CTT CTT TGT CAT CTC
    CAA GGC TGT GGA CGC CAG GTT CCA CTG GTT GAA GAA ACA GTA GAG

    CTT GGC TGT GTC AGA TCT CTT GGT GGC CGT CCT GGT CAT GCC CTG
    GAA CCG ACA CAG TCT AGA GAA CCA CCG GCA GGA CCA GTA CGG GAC

    GAA GGC AGT GGC TGA GAT TGC TGG CTT CTG
    CTT CCG TCA CCG ACT CTA ACG ACC GAA GAC

If we wanted to find out which codon is the 27th one, we could
highlight it with:

    perl seq_format.pl --limit 15 --highlight 27 seq.txt

Then, the second line of codons in the output above would change to:

=for comment
I couldn't find a better way to preserve the layout
and add bold at the same time.

=over 4

=item CAC CTC TGC CAT GGA CGG GAC TGG GCT GGT GGT GGA B<GAG> GGA CTT

=item GTG GAG ACG GTA CCT GCC CTG ACC CGA CCA CCA CCT B<CTC> CCT GAA

=back


=head1 SYNOPSIS

    seq_format.pl -h 56 --color-base blue --color-complement red seq.txt
    seq_format.pl --limit 10 --highlight 15 --highlight 26 seq.txt

=head1 ARGUMENTS

=head2 --limit [INT]

Limit how many codons to display per line (Default: 20).

=head2 --highlight [INT]

Highlight specified codons in the sequence for easy identification.
Can be specified more than once. For example, to highlight
the third and 12th codon in sequence.txt:

    perl seq_format.pl -h 3 -h 12 sequence.txt

=head2 --color-base [STRING]

Specify the color to use for the base line. Can be one of:

=over 4

=item * black

=item * red

=item * green

=item * yellow

=item * blue

=item * magenta

=item * cyan

=item * white

=back

=head2 --color-complement [STRING]

Specify the color to use for the complementary line. Accepts the same
set of values as --color-base.

=cut
