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
use utf8::all;

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

my @s_samples = ( ['Source Name', 'Sample Name', 'Description','Material Type', 'Term Source Ref', 'Term Accession Number', 'Characteristics [sex (EFO:0000695)]', 'Term Source Ref', 'Term Accession Number', 'Characteristics [developmental stage (EFO:0000399)]', 'Term Source Ref', 'Term Accession Number' ] );


my @a_species = ( [ 'Sample Name', 'Assay Name', 'Description', 'Protocol REF', 'Characteristics [species assay result (VBcv:0000961)]', 'Term Source Ref', 'Term Accession Number' ] );

my @a_collection = ( [ 'Sample Name', 'Assay Name', 'Protocol REF', 'Date', 'Characteristics [Collection site (VBcv:0000831)]', 'Term Source Ref', 'Term Accession Number', 'Characteristics [Collection site latitude (VBcv:0000817)]', 'Characteristics [Collection site longitude (VBcv:0000816)]', 'Comment [collection site coordinates]', 'Characteristics [Collection site locality (VBcv:0000697)]', 'Characteristics [Collection site country (VBcv:0000701)]' ] ); # 'Characteristics [Collection site location (VBcv:0000698)]', 'Characteristics [Collection site village (VBcv:0000829)]', 'Characteristics [Collection site locality (VBcv:0000697)]', 'Characteristics [Collection site suburb (VBcv:0000845)]', 'Characteristics [Collection site city (VBcv:0000844)]', 'Characteristics [Collection site county (VBcv:0000828)]', 'Characteristics [Collection site district (VBcv:0000699)]', 'Characteristics [Collection site province (VBcv:0000700)]', 'Characteristics [Collection site country (VBcv:0000701)]' ] );

my @a_IR_WHO = ( ['Sample Name', 'Assay Name','Protocol REF', 'Parameter Value [group1.insecticidal substance]', 'Term Source Ref', 'Term Accession Number', 'Parameter Value [group1.concentration]', 'Unit', 'Term Source Ref', 'Term Accession Number', 'Parameter Value [duration of exposure]', 'Unit', 'Term Source Ref', 'Term Accession Number', 'Characteristics [sample size (VBcv:0000983)]', 'Raw Data File' ] );

my @p_IR_WHO = ( ['Assay Name', 'Phenotype Name', 'Observable', 'Term Source Ref', 'Term Accession Number', 'Attribute', 'Term Source Ref', 'Term Accession Number', 'Comment [note]', 'Value', 'Unit', 'Term Source Ref', 'Term Accession Number'] );



#
# This is the main loop for generating ISA-Tab data
#
#Would like to have sample names as COLLECTION SITE.COLLECTION DATE.INSECTICIDE.PROTOCOL

# sample number counters (for Sample Name) for each sib species
#my %sample_number; # first level key is OHT/WELL/CISTERN (currently in spreaddsheet as other breeding habitat)
                   # second level key is cluster
                   # value stored in the two-level hash is the number
                   #
                   # $sample_number{GENUS}{CLUSTERS}{SOURCE} = 123



# then use a four (!) level hash to remember which Assay Name to use for each combination of Village, Date and Location
my %collection_name;
my %who_dt_name;
#my $collection_counter = 1;

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
    next unless ($row->{'Collection site'}); # skips empty lines

  #  foreach my $genus (qw/ANOPHELES CULEX AEDES/) {

    my $sample_name = tidy_up_name(
				   sprintf "%s.%s",
				   $row->{'Collection site'},
				   $row->{"Collection date"},
				  );


    # create collection assay name
    #To make my assay names for collection
    my $assay_protocol_ref = assay_protocol_ref( $row->{"Protocol"} );
    my $collection_protocol_ref = 'COLL_OVI';
    my $collection_date = $row->{"Collection date"};
    my $a_collection_assay_name = $collection_name{$row->{"Collection site"}}{$row->{"Collection date"}} {$collection_protocol_ref} //= tidy_up_name(sprintf "%s.%s.%s", $row->{"Collection site"}, $row->{"Collection date"}, $collection_protocol_ref);
    my $a_who_dt_assay_name = $who_dt_name{$sample_name} {$assay_protocol_ref} {$row->{"Insecticide"}} //= tidy_up_name(sprintf "%s.%s.%s", $sample_name, $assay_protocol_ref, $row->{"Insecticide"});

    push @a_species, [ $sample_name, "$sample_name.SPECIES", '', 'SPECIES', 'Aedes aegypti', 'VBsp', '0000518' ];

    push @a_collection, [ $sample_name, $a_collection_assay_name, $collection_protocol_ref, "$collection_date-11/$collection_date-12", 'Brazil', 'GAZ', '00002828', $row->{'Coordinates lat'}, $row->{'Coordinates long'}, 'IA', $row->{'Collection site'}, 'Brazil' ];

    push @s_samples, [ $row->{"Source of the data"}, $sample_name, '', 'pool', 'EFO', '0000663', 'female', 'PATO', '0000383', dev_stage($row->{"Mosquitoes tested"}) ];


    my $num_mozzies_total = $row->{"No. Mosquitoes"};
    if (length($num_mozzies_total) > 0 &&
	!looks_like_number($num_mozzies_total)) {
      die "didn't like num mozzies >$num_mozzies_total<\n";
    }
    # so $num_mozzies_total could still be empty string

    my $num_mozzies_WHO = $num_mozzies_total;
    if ($row->{"Mosquitoes tested"} =~ /^.+larvae$/) {
      die "need to half the num mozzie total >$num_mozzies_total<\n";
    }
    # TO DO - decide if all or some mozzies are used in the WHO assay

push @a_IR_WHO, [ $sample_name, $a_who_dt_assay_name, $assay_protocol_ref, insecticide_term($row->{"Insecticide"}), $row->{"Concentration"}, concentration_unit_term( $row->{"Units"}), duration_and_units($row->{"Duration"}), $num_mozzies_WHO, 'p_IR_WHO.txt' ];

    push @p_IR_WHO, [ $a_who_dt_assay_name, "Mortality percentage:$row->{'Percent mortality'},$row->{'Concentration'}% insecticide_term($row->{'Insecticide'})", 'insecticide resistance', 'MIRO', '00000021', 'mortality rate', 'VBcv', '0000703', 'IA', $row->{"Percent mortality"}, 'percent', 'UO', '0000187'];
  }
 }


# printing an array with tab separators
# print join("\t", @headings)."\n";




write_table("$outdir/s_samples.txt", \@s_samples);
write_table("$outdir/a_species.txt", \@a_species);
write_table("$outdir/a_collection.txt", \@a_collection);
write_table("$outdir/a_IR_WHO.txt", \@a_IR_WHO);
write_table("$outdir/p_IR_WHO.txt", \@p_IR_WHO);

#
# LOOKUP SUBS
#
# return lists, often (term_name, ontology, accession number)
#
#
sub dev_stage {
  my $input = shift;
  given ($input) {
    when (/^f1 ?- ?larvae$/i) {
      return ('F1 larvae bred from field collected mosquitoes', 'MIRO', '30000030')
    }
    when (/^f1 ?- ?adult$/i) {
      return ('F1 larvae from field collected mosquitoes', 'MIRO', '30000031')
    }
    when (/^Lab ?- ?larvae$/i) {
      return ('larval laboratory population', 'MIRO', '30000001')
    }
    when (/^Lab ?- ?adult$/i) {
      return ('adult laboratory population', 'MIRO', '30000003')
    }
    when (/^f2 ?- ?larvae$/i) {
      return ('F2 larvae', 'IRO', '0000130')
    }
    when (/^f2 ?- ?adult$/i) {
      return ('F2 adults', 'IRO', '0000129')
    }
    when (/^$/i) {
      return ('adult laboratory population', 'MIRO', '30000003')
    }
    default {
      die "fatal error: unknown dev_stage >$input<\n";
    }
  }
}

sub assay_protocol_ref {
  my $input = shift;
  given ($input) {
    when (/^WHO ?1981 ?bioassay$/i) {
      return ('IR_WHO_1981')
    }
    when (/^WHO ?2016 ?bioassay$/i) {
      return ('IR_WHO_2016')
    }
    when (/^CDC ?bottle ?assay$/i) {
      return ('IR_CDC_BOTTLE')
    }
    default {
      die "fatal error: unknown who_protocol_ref >$input<\n";
    }
  }
}
sub num_mozzies {
  my $input = shift;
  if (looks_like_number($input)) {
    return $input;
  }else{
    when (/^$/i) {
      die "unexpected value '$input' for num_mozzies";
    }
  }
}
sub concentration_unit_term {
  my $input = shift;
  given ($input) {
    when ("mg/L") {
      return ('mg/L', 'UO', '0000273')
    }
    when (" mg i.a./m2") {
      return ('milligram per square meter', 'UO', '0000309')
    }
    when (/^%$/i) {
      return ('percent', 'UO', '0000187')
    }
   when (/^µg$/i) {
      return ('microgram', 'UO', '0000023')
    }
    default {
      die "fatal error: unknown concentration_unit_term >$input<\n";
    }
  }
}

sub insecticide_term {
  my $input = shift;
  given ($input) {
    when (/^pyriproxyphen$/i) {
      return ('pyriproxyfen', 'MIRO', '10000190')
    }
    when (/^malathion$/i) {
      return ('malathion', 'MIRO','10000065')
    }
    when (/^cypermeth?rin$/i) {
      return ('cypermethrin', 'MIRO', '10000127')
    }
    when (/^deltameth?rin$/i) {
      return ('deltamethrin', 'MIRO', '10000133')
    }
    when (/^temephos$/i) {
      return ('temephos', 'MIRO', '10000093')
    }
    when (/^diflubenzuron$/i) {
      return ('diflubenzuron', 'MIRO', '10000243')
    }
    when (/^alfacypermetrin$/i) {
      return ('alpha-cypermethrin', 'MIRO', '10000128')
    }
    when (/^fenitrothion$/i) {
      return ('fenitrothion', 'MIRO', '10000056')
    }
    when (/^ethophemprox$/i) {
      return ('etofenprox', 'MIRO', '10000136')
    }
    when (/^bendiocarb$/i) {
      return ('bendiocarb', 'MIRO', '10000006')
    }
    when (/^permeth?rin$/i) {
      return ('permethrin', 'MIRO', '10000144')
    }
    default {
      die "fatal error: unknown insecticide >$input<\n";
    }
  }
}

sub duration_and_units {
  my $input = shift;
  given ($input) {
    when ("adult emergence on control") {
      return ('', '', '', '');
    }
  }

  my ($duration_amount,$duration_unit) = $input =~ /(\d+)\s*(\w+)/;
  die "unrecognised format in duration_and_units >$input<\n" unless (defined $duration_unit);
  given ($duration_unit) {
    when (/^hs$/i) {
      return ($duration_amount, 'hour', 'UO', '0000032')
    }
    when (/^min$/i) {
      return ($duration_amount, 'minute', 'UO', '0000031')
    }
    default {
      die "missing unit abbreviation in '$input' duration" unless (defined $duration_unit);
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
