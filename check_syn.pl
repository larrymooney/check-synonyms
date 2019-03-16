=comment

Rules for matching synonym or antonym referents:
1. Is the it found as a headword? (If so, Ref Fnd = "Y")
2. Is the it reciprocated? Does a similar marker exist under the headword for the original headword? (If so, Reciprocal = Headword.Homograph)
3. Is the it ambiguous? 
   a. Are there multiple headword referents with no reciprocals? (If so, Ambiguous = "Y")
   b. Are there multiple headword referents with multiple reciprocals? (If so, Ambiguous = "Y")   

#########  ASSUMPTIONS  ###############

Homographs and sense numbers are present and explicit. 

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
use Config::Tiny;
use Path::Tiny qw(path);
#
# Read and process .ini file
#
our $config = Config::Tiny->read( 'ChkSyn.ini' );
#
die "Couldn't find the INI file\nQuitting" if !$config;
# Language
our $language = $config->{ChkSyn}->{lang};
# File path
our $fpath = $config->{ChkSyn}->{fpath};
# Log file 
our $flog = $config->{ChkSyn}->{flog};
# SFM input file
our $ifsfm = $config->{ChkSyn}->{ifsfm};
# Report output file 
our $ofrpt = $config->{ChkSyn}->{ofrpt};
# Lexeme marker
our $lexmarker = $config->{ChkSyn}->{lexmarker};
# Homograph marker
our $hommarker = $config->{ChkSyn}->{hommarker};
# Synonym marker
our $synmarker = $config->{ChkSyn}->{synmarker};
# Sense marker
our $snsmarker = $config->{ChkSyn}->{snsmarker};
#
#
our $date = Time::Piece->new;
$date->time_separator("");
$date->date_separator("");
our $tm = $date->datetime;
#
our $scriptname = $0;
our %file_hash;
our %scalar_count;
our @dups;
our @tmpRec;
our $DUPLICATE = 0;
our $ADD_HM_TO_UNIQUE = 0;
our $DEFAULT_HM = 100;
our $numargs = @ARGV;
#
# USE <STDIN> entered file names if entered, otherwise use .ini file values
#
if ( $numargs > 0 )
{
	$fpath = "";
	$ifsfm = $ARGV[0]; 
	if ( $numargs > 1 )
	{
		if ($ARGV[1] eq "-u")
		{ 
			$ADD_HM_TO_UNIQUE = 1; 
			if ( $numargs > 2 )
			{
				$ofrpt = $ARGV[2] 		
			}
		}
		else 
		{ 
			$ofrpt = $ARGV[1] 
		}
	}
}	
#
open(our $fhlogfile, '>:encoding(UTF-8)', $fpath.$flog) 
	or die "Could not open file '$flog' $!";
#
write_to_log("Input file $ifsfm");
#
# opl the file - i.e. put each record on a line.
#
our @opld_file = opl_file($fpath.$ifsfm);
#
# Create a table of lexemes and syn in the following format
#
# Create hash of synonyms under lexeme[hm] as key
#
foreach my $line (@opld_file) 
{
	my $hm;
	my $key;
	my $sn = 1; 
#	
	if ($line =~ /\Q$lexmarker\E\s+(.*?)#((.*?)\Q$hommarker\E\s+(\d*?)#)*/)
	{
		$hm = $2 ? $4 : 0;
		$key = $1;
#
		if ($hm != 0)
		{
			$key = $key.$hm;
		}		
#		
		push @{$file_hash{$key}}, 0;
#
		if ($line =~ /\Q$synmarker\E\s+/)
		{
			#retrieve sense and syn data
			our @fields = split /#/, $line;	
			foreach my $f (@fields)
			{
				if ($f =~ /\Q$snsmarker\E\s+(\d+)/)
				{
					$sn = $1;
				}
				elsif ($f =~ /^\Q$synmarker\E\s+(.*)/)
				{
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
our @ref_lex_array = ();
our $ref_lex = "";
our $ref_syn = "";
our @ref_syn_array = ();
#
our $ref_exists = "N";
our $ref_reciprocated = "";
our $ref_ambiguous = "";
our $temp_lex = "";
our $proposed_upd = "";
our $temp_syn = "";
our @recip_fnd_array = ();	
our $recip_lex = "";
#
our $i = 0;
#
foreach $pri_lex (sort @lexemes) 
{
	$ref_exists = "N";
	$ref_reciprocated = "";
	$ref_ambiguous = "";
	$ref_lex = "";
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
			@ref_lex_array = ();
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
					push @ref_lex_array, $lexemes[$q]; 	
				}	
			}
#
# No synonym referent - add line under primary 			
#
			if (scalar @ref_lex_array < 1)
			{
				$ref_exists = "N";
				$ref_reciprocated = "N";
				$ref_ambiguous = "N";
				$recip_lex = "NONE";
				$proposed_upd = "NONE";
#				
				if (@{$file_hash{$pri_lex}}[0] == 0)
				{
					$coll_id_ref = ++$coll_id_incr;
					@{$file_hash{$pri_lex}}[0] = $coll_id_ref;
				}
				else
				{
					$coll_id_ref = @{$file_hash{$pri_lex}}[0];
				}
#		
				push @{$coll_hash{$coll_id_ref}{$pri_lex}}, 
					"###$pri_syn_sense###$pri_syn_trunc###$ref_exists###$recip_lex###$ref_ambiguous###";			
			}
			else
			{
#
# Reference found
# Check to see if reference is reciprocated
#		
				$ref_exists = "Y";
				@recip_fnd_array = ();
#	
				for (my $t=0; $t < scalar @ref_lex_array; $t++)
				{
					$ref_lex = $ref_lex_array[$t];
#	
					for (my $v=0; $v < scalar @{$file_hash{$ref_lex}}; $v++)
					{
						if (${$file_hash{$ref_lex}}[$v] =~ /^(.*?)\s+\d+$/)
						{
							$temp_syn = $1;
						}
						else 
						{
							$temp_syn = ${$file_hash{$ref_lex}}[$v];
						}
#			
						if ($pri_lex_trunc eq $temp_syn)
						{
							push @recip_fnd_array, $ref_lex;
						}
					}
				}
#
# Flag reciprocity
#
				if (scalar @recip_fnd_array == 0)
				{
					$ref_reciprocated = "N";
					$recip_lex = "NONE";
				}
				else
				{
					$ref_reciprocated = "Y";
					($recip_lex) = @recip_fnd_array;
				}
#
# Flag ambiguity	
#
				if (scalar @ref_lex_array > 1 && $ref_reciprocated eq "N")	
				{
					$ref_ambiguous = "Y";
				}
				else
				{
					$ref_ambiguous = "N";
				}
#				
# If reference is ambiguous, create unique collection, add to table
#
				if ($ref_ambiguous eq "Y")
				{
					$coll_id_ref = ++$coll_id_incr;
					@{$file_hash{$pri_lex}}[0] = $coll_id_ref;
					$proposed_upd = "NONE";
#					
					push @{$coll_hash{$coll_id_ref}{$pri_lex}}, 
						"###$pri_syn_sense###$pri_syn_trunc###$ref_exists###$recip_lex###$ref_ambiguous###";	
				}
# Non-ambiguous reference, update collection IDs in primary & referent				
				else
				{
					if (@{$file_hash{$pri_lex}}[0] > 0)
					{
						$coll_id_ref = @{$file_hash{$pri_lex}}[0];
						@{$file_hash{$ref_lex}}[0] = $coll_id_ref;
					}
					elsif (@{$file_hash{$ref_lex}}[0] > 0)
					{
						$coll_id_ref = @{$file_hash{$ref_lex}}[0];		
						@{$file_hash{$pri_lex}}[0] = $coll_id_ref;
					}
					else
					{
						$coll_id_ref = ++$coll_id_incr;
						@{$file_hash{$pri_lex}}[0] = $coll_id_ref;		
						@{$file_hash{$ref_lex}}[0] = $coll_id_ref;
					}
#					
					push @{$coll_hash{$coll_id_ref}{$pri_lex}}, 
						"###$pri_syn_sense###$pri_syn_trunc###$ref_exists###$recip_lex###$ref_ambiguous###";	
				}
			}
		}
	}
}	
#
our $row = "";
#
open(my $fhoutfile, '>:encoding(UTF-8)', $fpath.$ofrpt) 
	or die "Could not open file '$ofrpt' $!";
#
# Print collections out as CSV
#
print $fhoutfile "Collection#Lexeme#Sense#Synonym#Ref Fnd#Reciprocal#Ambiguous#Proposed Update\n";
# 
# Sort by collection number, then lexeme
#
foreach $coll_id_ref (sort {$a <=> $b} keys %coll_hash)
{
	foreach $pri_lex (sort keys %{$coll_hash{$coll_id_ref}})
	{
		foreach $row (@{$coll_hash{$coll_id_ref}{$pri_lex}})
		{
			$row =~ /^###(.*)###(.*)###(.*)###(.*)###(.*)###$/;
			print $fhoutfile "$coll_id_ref#$pri_lex#$1#$2#$3#$4#$5\n"; 
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
#
close $fhlogfile;
#
######################  SUBROUTINES #################################

sub write_to_log{

    my ($message) = @_;
	print $fhlogfile "$message\n";
}
