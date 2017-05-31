#!/usr/bin/env perl
#  -*- mode: CPerl -*-

#
# usage ./generate-isa-tab.pl -indir dir-with-tsv -outdir isa-tab-dir
#
#
# edit investigation sheet manually in Google Spreadsheets and download as TSV
# into the output directory before loading into Chado
#


use strict;
use warnings;
use feature "switch";

use Text::CSV::Hashify;
use Getopt::Long;
use Scalar::Util qw(looks_like_number);
use DateTime::Format::Strptime;
use Geo::Coordinates::DecimalDegrees;

my %parser_defaults = (binary => 1, eol => $/, sep_char => "\t");
my $indir;
my $outdir;

GetOptions(
	   "indir=s"=>\$indir,
	   "outdir=s"=>\$outdir,
	  );

# check mandatory command line options given
unless (defined $indir && defined $outdir) {
  die "must give -indir AND -outdir options on command line\n";
}

# check input dir exists (with some nasty magic)
if (not -d $indir) {
  die "indir does not exist\n";
}

mkdir $outdir unless (-e $outdir);
die "can't make output directory: $outdir\n" unless (-d $outdir);





# #
# Set up headers for all the output sheets.
#
# each sheet will be an array of rows.
# first row contains the headers
#
#

my @s_samples = ( ['Source Name', 'Sample Name', 'Description','Material Type', 'Term Source Ref', 'Term Accession Number', 'Characteristics [sex (EFO:0000695)]', 'Term Source Ref', 'Term Accession Number', 'Characteristics [developmental stage (EFO:0000399)]', 'Term Source Ref', 'Term Accession Number', 'Characteristics [sample size (VBcv:0000983)]' ] );


my @a_species = ( [ 'Sample Name', 'Assay Name', 'Description', 'Protocol REF', 'Characteristics [species assay result (VBcv:0000961)]', 'Term Source Ref', 'Term Accession Number' ] );

my @a_collection = ( [ 'Sample Name', 'Assay Name', 'Protocol REF', 'Date', 'Characteristics [Collection site (VBcv:0000831)]', 'Term Source Ref', 'Term Accession Number', 'Characteristics [collection duration in days (VBcv:0001009)]', 'Characteristics [Collection site latitude (VBcv:0000817)]', 'Characteristics [Collection site longitude (VBcv:0000816)]', 'Comment [collection site coordinates]', 'Characteristics [Collection site village (VBcv:0000829)]', 'Characteristics [Collection site country (VBcv:0000701)]' ] ); # 'Characteristics [Collection site location (VBcv:0000698)]', 'Characteristics [Collection site village (VBcv:0000829)]', 'Characteristics [Collection site locality (VBcv:0000697)]', 'Characteristics [Collection site suburb (VBcv:0000845)]', 'Characteristics [Collection site city (VBcv:0000844)]', 'Characteristics [Collection site county (VBcv:0000828)]', 'Characteristics [Collection site district (VBcv:0000699)]', 'Characteristics [Collection site province (VBcv:0000700)]', 'Characteristics [Collection site country (VBcv:0000701)]' ] );





#
# This is the main loop for generating ISA-Tab data
#
#Would like to have sample names as GENUS.CLUSTER.SOURCE.NO

# sample number counters (for Sample Name) for each sib species
my %sample_number; # first level key is OHT/WELL/CISTERN (currently in spreaddsheet as other breeding habitat)
                   # second level key is cluster
                   # value stored in the two-level hash is the number
                   #
                   # $sample_number{GENUS}{CLUSTERS}{SOURCE} = 123



# then use a four (!) level hash to remember which Assay Name to use for each combination of Village, Date and Location
my %collection_name;
my $collection_counter = 1;

# do a wildcard file "search" - results are a list of filenames that match
foreach my $filename (glob "$indir/*.{txt,tsv}") {

  # read in the whole file into an (reference to an) array of hashes
  # where the keys in the hash are the column names (from the input file)
  # and the values are the values from 
  my $lines_aoh = Text::CSV::Hashify->new( {
					    file   => $filename,
					    format => 'aoh',
					    %parser_defaults,
					   } )->all;

  # now loop through each line of this file
  foreach my $row (@$lines_aoh) {
    next unless ($row->{CLUSTERS}); # skips empty lines

    foreach my $genus (qw/ANOPHELES CULEX AEDES/) {

      my $sample_count = $row->{"$genus SUM"};
	#$genus eq 'ANOPHELES' ? $row->{"ANOPHELES SUM"} : $genus eq 'AEDES' ? $row->{"AEDES SUM"} : $row->{"CULEX SUM"};

      my $sample_name = tidy_up_name(
				     sprintf "%s.%s.%s.%03d",
				     $genus,
				     $row->{CLUSTERS},
				     $row->{"SOURCE"},
				     ++$sample_number{$genus}{$row->{CLUSTERS}}{$row->{"SOURCE"}} # Perl automatically fills previously non-existent hash values with zero before doing any maths on them
				    );


      # print "Made a sample (count $sample_count) '$sample_name' from date '$row->{Date}'\n";

# $x = 7
# print ++$x
# (prints 8, $x is now 8)
# $x++
# (prints 8, $x is now 9)



      # create collection assay name
      #To make my assay names for collection
      my $a_collection_assay_name = $collection_name{$row->{CLUSTERS}}{$row->{Date}}{$row->{'SOURCE'}}{$row->{"SENTINEL/RANDOM"} || 'X'} //= tidy_up_name(sprintf "%s.%s.%s.%s.%04d", $row->{CLUSTERS}, $row->{Date}, $row->{'SOURCE'}, ($row->{"SENTINEL/RANDOM"} || ''), $collection_counter++);

      my $collection_protocol_ref = collection_protocol_ref($row->{'SOURCE'});
      push @a_species, [ $sample_name, "$sample_name.SPECIES", '', 'SPECIES', morpho_species_term($genus) ];

      push @a_collection, [ $sample_name, $a_collection_assay_name, $collection_protocol_ref, fix_date($row->{Date}), 'Chennai', 'GAZ', '00003776', '1', $row->{LATITUDE}, $row->{LONGITUDE}, 'IA', $row->{CLUSTERS}, 'India' ];

      push @s_samples, [ '2017-icemr-chennai', $sample_name, '', 'pool', 'EFO', '0000663', 'mixed sex', 'PATO', '0001338', 'F0 larvae;pupa', 'MIRO;IDOMAL', '30000028;0000654', $row->{"$genus SUM"} ];
    }
  }
}



# printing an array with tab separators
# print join("\t", @headings)."\n";




write_table("$outdir/s_samples.txt", \@s_samples);
write_table("$outdir/a_species.txt", \@a_species);
write_table("$outdir/a_collection.txt", \@a_collection);
#


#
# LOOKUP SUBS
#
# return lists, often (term_name, ontology, accession number)
#
#



sub morpho_species_term {
  my $input = shift;
  given ($input) {
    when (/^ANOPHELES$/) {
      return ('genus Anopheles', 'VBsp', '0000015')
    }
    when (/^CULEX$/) {
      return ('genus Culex', 'VBsp', '0002423')
    }
    when (/^AEDES$/) {
      return ('genus Aedes', 'VBsp', '0000253')
    }
    default {
      die "fatal error: unknown morpho_species_term >$input<\n";
    }
  }
}

sub pcr_species_term {
  my $input = shift;
  given ($input) {
    when (/^BCE$/) {
      return ('Anopheles culicifacies BCE subgroup', 'VBsp', '0000645')
    }
    when (/^AD$/) {
      return ('Anopheles culicifacies AD subgroup', 'VBsp', '0000471')
    }
    when (/^S$/) {
      return ('Anopheles fluviatilis S', 'VBsp', '0000647')
    }
    when (/^T$/) {
      return ('Anopheles fluviatilis T', 'VBsp', '0000650')
    }
    default {
      die "fatal error: unknown pcr_species_term >$input<\n";
    }
  }
}

sub collection_protocol_ref {
  my $input = shift;
  given ($input) {
    when (/^OTHER$/) {
      return ('COLL_CISTERN')
    }
    when (/^WELL$/) {
      return ('COLL_WELL')
    }
    when (/^OHT$/) {
      return ('COLL_OHT')
    }
    default {
      die "fatal error: unknown protocol_ref >$input<\n";
    }
  }
}



sub positive_negative_term {
  my $input = shift;
  given ($input) {
    when (/^Posi?tive$/) {
      return ('present', 'PATO', '0000467');
    }
    when (/^Negative$/) {
      return ('absent', 'PATO', '0000462');
    }
    default {
      die "fatal error: unknown positive_negative_term >$input<\n";
    }
  }
}




#
# usage $hashref = hashify_by_multiple_keys($arrayref, ':', 'HH ID', 'Collection Date')
#
# builds and returns a new hashref by iterating through the hashref elements of arrayref
# using the provided keys, it joins their values using the delimiter and uses
# the result as the key in the new hashref - which points to the arrayref rows
# make sense??
#
# it's as if Text::CSV::Hashify had a multiple keys option

sub hashify_by_multiple_keys {
  my ($arrayref, $delimiter, @keys) = @_;
  my $hashref = {};

  foreach my $row (@$arrayref) {
    my $newkey = join $delimiter, @$row{@keys};
    die "non-unique multiple key (@keys): >$newkey<\n" if exists $hashref->{$newkey};
    $hashref->{$newkey} = $row;
  }

  return $hashref;
}

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

sub tidy_up_name {
  my ($input) = @_;
  $input =~ s/\s+/_/g;
  # replace dot dot with dot
  $input =~ s/\.+/./g;
  return $input;
}

sub fix_date {
  my ($input) = @_;
  $input =~ s|/|-|g;
  return $input;
}
