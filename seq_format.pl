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
