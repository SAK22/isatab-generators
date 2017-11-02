#!/usr/bin/env perl
#  -*- mode: CPerl -*-

#
# usage ./generate-a_microsat.pl [ -inputfile filename ] > a_microsat.txt
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

my $inputfile = '/home/sakelly/vectorbase/popbio/isatab-generators/gareth-microsat/data/Microsatellite_data.txt';

GetOptions(
	   "inputfile=s"=>\$inputfile,
	  );

my @alleles = qw/MCQ24:A MCQ24:B MCQ16:A MCQ16:B MCQ19:A MCQ19:B MCQ45:A MCQ45:B MCQ3:A MCQ3:B MCQ25:A MCQ25:B MCQ28:A MCQ28:B MCQ39:A MCQ39:B MCQ10:A MCQ10:B MCQ2:A MCQ2:B MCQ4:A MCQ4:B MCQ29:A MCQ29:B MCQ1:A MCQ1:B MCQ22:A MCQ22:B MCQ37:A MCQ37:B MCQ36:A MCQ36:B MCQ23:A MCQ23:B MCQ11:A MCQ11:B MCQ8:A MCQ8:B MCQ9:A MCQ9:B MCQ41:A MCQ41:B MCQ13:A MCQ13:B MCQ31:A MCQ31:B MCQ42:A MCQ42:B MCQ33:A MCQ33:B MCQ20:A MCQ20:B MCQ21:A MCQ21:B MCQ26:A MCQ26:B MCQ34:A MCQ34:B MCQ5:A MCQ5:B/;


#
# INPUT TABULAR DATA
#
#


# Read in the tab delimited data into 
my $lines_aoh = Text::CSV::Hashify->new( {
					   file   => $inputfile,
					   format => 'aoh',
					   %parser_defaults,
					  } )->all;


# print the headers - separated by \t
print "Sample Name\tAssay Name\tProtocol REF\tPerformer\tDate\tComment[note]\tRaw Data File\n";

# this loop processes every line in the file
foreach my $row_ref (@$lines_aoh) {
  my $sample_id = $row_ref->{"Sample ID"};
  if (defined $sample_id) {

    my %done_locus;
    # now do every allele
    foreach my $allele (@alleles) {
      my $length = $row_ref->{$allele};

      # get the AC1 part out of AC1:A
      my ($locus, $a_or_b) = split /:/, $allele;

      # printf prints a formatted 'template' string
      # the variable values follow it
      if ($length > 0 && !$done_locus{$locus}++) {
	printf "%s\t%s.%s\tGENOTYPE\t\t\t\tg_microsat.txt\n", $sample_id, $sample_id, $locus;
      }
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

