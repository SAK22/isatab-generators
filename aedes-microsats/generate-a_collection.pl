#!/usr/bin/env perl
#  -*- mode: CPerl -*-

#
# usage ./generate-a_collection.pl data/collection-template.txt data/Kotsakiozi.txt > some/path/to/Kotsakiozi-isa-tab/a_collection.txt
#
#
#

use strict;
use warnings;
use feature "switch";

use Text::CSV::Hashify;
use Getopt::Long;
use Scalar::Util qw(looks_like_number);
use DateTime::Format::Strptime;
use Geo::Coordinates::UTM;

my %parser_defaults = (binary => 1, eol => $/, sep_char => "\t");

my $collectionfile = shift @ARGV; # get the first commandline arg
my $inputfile = shift @ARGV; # get the second commandline argument

#
# INPUT TABULAR DATA
#
#

# 1. read in the collection template lines

my @collection_templates;
open(COLL, $collectionfile) || die "can't read $collectionfile";
my $header = <COLL>;
while (my $line = <COLL>) {
  push @collection_templates, $line;
}
close(COLL);

print $header;




# 2.
# Read in the tab delimited 'sample data'
my $lines_aoh = Text::CSV::Hashify->new( {
					   file   => $inputfile,
					   format => 'aoh',
					   %parser_defaults,
					  } )->all;




# this loop processes every line in the file
foreach my $row_ref (@$lines_aoh) {
  my $sample_id = $row_ref->{"Sample ID"};
  my $population = $row_ref->{Population};
  my $country = $row_ref->{Country};
  my $year = $row_ref->{Year};

  if (defined $sample_id) {
    # search for the unique line in @collection_templates that matches population, country and year

    my @matches = grep {
      (!defined $year || /$year/) &&
	/$country/ &&
	  /$population/
    } @collection_templates;

    # clean up for debugging output only
    $year //= 'NOYEAR';
    my $num_matches = @matches;

    print "$sample_id has $num_matches matches for >$year< >$population< >$country<\n";

    if ($num_matches == 1) {
      my $output_line = shift @matches;
      $output_line =~ s/^[^\t]+/$sample_id/;

      print $output_line;
    }


  } else {
    print "problem reading row\n";
  }
}


#
# the following unused function writes "proper" CSV/TSV but
# we don't need it for this simple task
#
sub write_table {
  my ($filename, $arrayref) = @_;
  my $handle;
  open($handle, ">", $filename) || die "problem opening $filename for writing\n";
  my $tsv_writer = Text::CSV->new ( \%parser_defaults );
  foreach my $row (@{$arrayref}) {
    $tsv_writer->print($handle, $row);
  }
  close($handle);
  warn "sucessfully wrote $filename\n";
}

