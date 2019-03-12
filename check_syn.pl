=comment

Usage:
#adds homographs where necessary and removes \hm Default Value (set to 100) to unique entries.
#hm Default Value is placed in an SFM when using this script with the -u option. Creates log file add_hm.<time>.log
#
	perl check_syn.pl FILENAME.SFM  


#adds homographs where necessary and adds \hm Default Value (set to 100) to unique entries.  
#Creates log file add_hm_u.<time>.log
#
	perl check_syn.pl FILENAME.SFM -u


#input file is an SFM file.  This file will be opl'd, processed and de_opl'd. 
#output file is an SFM file.
#

#########  ASSUMPTIONS  ###############

=cut
#
use utf8;
use open qw/:std :utf8/;
use feature ':5.22';
use strict;
use warnings;
use Data::Dumper qw(Dumper);
use Time::Piece;
use oplStuff;
#
my $date = Time::Piece->new;
$date->time_separator("");
$date->date_separator("");
my $tm = $date->datetime;
#
my $infile ="";
my $scriptname = $0;
my $logfile = "$tm.log";
my %file_hash;
my %scalar_count;
my @dups;
my @tmpRec;
my $DUPLICATE = 0;
my $ADD_HM_TO_UNIQUE = 0;
my $DEFAULT_HM = 100;
my $numargs = $#ARGV + 1;


if ( $numargs == 0 ){
	 die "Usage: perl check_syn.pl FILENAME [-u]"; 
}
elsif ( $numargs == 1 ){
	$infile = $ARGV[0]; 
}
else {
	$infile = $ARGV[0]; 
	if ($ARGV[1] eq "-u"){ $ADD_HM_TO_UNIQUE = 1; }
	else { die "Usage: perl check_syn.pl FILENAME [-u]"; }
}


#open(my $fhlogfile, '>:encoding(UTF-8)', $logfile) 
#	or die "Could not open file '$logfile' $!";

 
#write_to_log("Input file $infile");

#opl the file - i.e. put each record on a line.
my @opld_file = opl_file($infile);

#Create a table of lexemes and syn in the following format
#
#[lexeme][sn][syn][slex_found][syn_recip]
#
#
#create hash of the entire file using lexeme[hm] as key
#
foreach my $line (@opld_file) {
my $hm;
my $key;
my $sn = 1; 
	if ($line =~ /\\lx (.*?)#((.*?)\\hm (\d*?)#)*/){
		$hm = $2 ? $4 : 0;
		$key = $1;
#
		if ($hm != 0){
			$key = $key.$hm;
		}		
#		
		push @{$file_hash{$key}}, 0;
#		
		if ($line =~ /\\syn /)
		{
			#retrieve sense and syn data
			my @fields = split /#/, $line;	
			foreach my $f (@fields){
				if ($f =~ /\\sn (\d+)/){
					$sn = $1;
				}
				elsif ($f =~ /^\\syn\s+(.*)/){
					$f = $1." ".$sn;
					push @{$file_hash{$key}}, $f;
				}
			}
		}
	}	
}
#
#
our @lexemes = keys %file_hash;
our %coll_hash = ();
our $coll_id_incr = 0;
our $coll_id_ref = 0;
our $pri_lex = "";
our $pri_lex_trunc = "";
our $pri_multi = "N";
our $pri_recip = "N";
our $pri_amb = "Y";
our $pri_syn = "";
our $pri_syn_sense = "";
our $pri_syn_trunc = "";
our @sec_lex_array = ();
our $sec_lex = "";
our $sec_syn = "";
our @sec_syn_array = ();
#
our $recip_lex = "";
our $ref_exists = "N";
our $ref_reciprocated = "N";
our $ref_ambiguous = "N";
our $temp_lex = "";
#
our $i = 0;
#
foreach $pri_lex (sort @lexemes) 
{
	$ref_exists = "N";
	$ref_reciprocated = "N";
	$ref_ambiguous = "N";
	$recip_lex = "";
#	
	if ($pri_lex =~ /^(.*)\d$/g)
	{
		$pri_lex_trunc = $1;
	}
	else 
	{
		$pri_lex_trunc = $pri_lex;
	}
#
# Check for synonyms and build collections
#
	if (scalar @{$file_hash{$pri_lex}} > 1)	
	{
		for ($i=1; $i < scalar @{$file_hash{$pri_lex}}; $i++)
		{
# 
			@sec_lex_array = ();
			$pri_syn = @{$file_hash{$pri_lex}}[$i];	
			$pri_syn =~ /^(.*)\s(\d+)/;	
			$pri_syn_trunc = $1;
			$pri_syn_sense = $2;
#
# Find any and all occurrences of the synonym referent
#
			for (my $q=0; $q < scalar @lexemes; $q++)
			{
				if ($lexemes[$q] =~ /^(.*)\d+$/)
				{
					$temp_lex = $1;
				}
				else
				{
					$temp_lex = $lexemes[$q];
				}
#
				if ($temp_lex eq $pri_syn_trunc)		
				{
					push @sec_lex_array, $lexemes[$q]; 	
				}	
			}
#
# No synonym referent - add line under primary 			
#
			if (scalar @sec_lex_array < 1)
			{
				$ref_exists = "N";
				$ref_reciprocated = "N";
				$ref_ambiguous = "N";
				$recip_lex = "NONE";
#				
				if (@{$file_hash{$pri_lex}}[0] == 0)
				{
					$coll_id_ref = ++$coll_id_incr;
				}
				else
				{
					$coll_id_ref = @{$file_hash{$pri_lex}}[0];
				}
#				
				upd_pri_ref();
			}
			else
			{
#
# Reference found
# Single synonym referent - no ambiguity, check reciprocation
#		
				if (scalar @sec_lex_array == 1)
				{
# Only one reference - not ambiguous
					$ref_exists = "Y";
					$ref_ambiguous = "N";	
#				
					is_reciprocal();
				}
				else
				{
# Multiple synonym references, check reciprocity				
					$ref_exists = "Y";
					is_reciprocal();
#
					if (($recip_lex eq "") || ($recip_lex eq "AMBIG"))
					{
						$ref_ambiguous = "Y";
					}
					else
					{
						$ref_ambiguous = "N";
					}
				}
# Was reference ambiguous?
				if ($ref_ambiguous eq "Y")
				{
					$coll_id_ref = ++$coll_id_incr;
					upd_pri_ref();
				}
				else
				{
					if (@{$file_hash{$pri_lex}}[0] > 0)
					{
						$coll_id_ref = @{$file_hash{$pri_lex}}[0];
						upd_pri_ref();
						upd_sec_ref();
					}
					elsif (@{$file_hash{$sec_lex}}[0] > 0)
					{
						$coll_id_ref = @{$file_hash{$sec_lex}}[0];		
						upd_pri_ref();
					}
					else
					{
						$coll_id_ref = ++$coll_id_incr;
						upd_pri_ref();
						upd_sec_ref();
					}
				}
			}
		}
	}
}	
#
our $path = "C:\\Users\\public\\Documents\\common\\sil\\zaza\\ch_syn";
#
our $outfile = "$path\\syn_coll.txt";
our $row = "";
#
open(my $fhoutfile, '>:encoding(UTF-8)', $outfile) 
	or die "Could not open file '$outfile' $!";
#
# Print collections out as CSV
#
print $fhoutfile "Collection#Lexeme#Synonym#Ref Fnd#Reciprocal#Ambiguous\n";
# 
# Sort by collection number, then lexeme
#
foreach $coll_id_ref (sort {$a <=> $b} keys %coll_hash)
{
	foreach $pri_lex (sort keys %{$coll_hash{$coll_id_ref}})
	{
		foreach $row (@{$coll_hash{$coll_id_ref}{$pri_lex}})
		{
			$row =~ /^###(.*)###(.*)###(.*)###(.*)###$/;
			print $fhoutfile "$coll_id_ref#$pri_lex#$1#$2#$3#$4\n"; 
		}	
	}
}
#
close $fhoutfile;
#
say "Hey";
#
#print Dumper \%file_hash;
#write_to_log ("Duplicate \\hm values have been found. SFM file must be corrected.");
#print ("Duplicate homograph numbers found.  No data has been written. See details in log file.\n");

#close $fhlogfile;
######################  SUBROUTINES #################################

sub write_to_log{

        my ($message) = @_;
	#print $fhlogfile "$message\n";
}
#
sub is_reciprocal
{
	$recip_lex = "";
	my $temp_syn = "";
#	
	for (my $t=0; $t < scalar @sec_lex_array; $t++)
	{
		$sec_lex = $sec_lex_array[$t];
#	
		for (my $v=0; $v < scalar @{$file_hash{$sec_lex}}; $v++)
		{
			if (${$file_hash{$sec_lex}}[$v] =~ /^(.*?)\s+\d+$/)
			{
				$temp_syn = $1;
			}
			else 
			{
				$temp_syn = ${$file_hash{$sec_lex}}[$v];
			}
#			
			if ($pri_lex_trunc eq $temp_syn)
			{
				if ($recip_lex eq "")
				{
					$recip_lex = $sec_lex;
				}
				else
				{
					$recip_lex = "AMBIG";
				}
			}
		}
	}
#
	if (($recip_lex eq "") || ($recip_lex eq "AMBIG"))	
	{}
	else
	{
		$sec_lex = $recip_lex;
	}
#	
	return;
}				
#
sub	upd_pri_ref
{
# Update file_hash 
	if ($recip_lex eq "") 
	{
		$recip_lex = "NONE";
	}	
#	
	if ($ref_ambiguous eq "N")
	{
		@{$file_hash{$pri_lex}}[0] = $coll_id_ref;
	}
# Update collection_hash
	push @{$coll_hash{$coll_id_ref}{$pri_lex}}, "###$pri_syn_trunc###$ref_exists###$recip_lex###$ref_ambiguous###";	
#	
	return;
}
#
sub upd_sec_ref
{
	@{$file_hash{$sec_lex}}[0] = $coll_id_ref;
#	push @{$coll_hash{$coll_id_ref}{$sec_lex}}, "###NOSYN###";	
	return;
}
