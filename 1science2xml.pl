#!/usr/bin/perl -w
#
# 1science2xml.pl - B. Coles.
# Last modified 4/5/2017
#  
# Creates Eprints3 XML records from the 1Science spreadsheet data in tsv format.
# Output is one EP# XML record per spreadsheet row.
#
# 1Science provides spreadsheets containing records that are for open
# access articles that are not yet in CaltechAUTHORS.  This program is used
# to convert the spreadsheet into a form that can be loaded with the EPrints
# 'import' batch command.
#
# To prepare a 1Science spreadsheet for loading, save it as a TSV file (tab-
# delimited format from within Excel.  Then open the file in a competent text
# editor such as Textmate and resave as necessary with character-encoding
# UTF-8 and EOL LF (for Linux).
#
# Expected input format:
#
# First row is column headers.
# Col 1		1science ID	
# Col 2		Title
# Col 3		Authors in non-inverted form, separated by '|'
# Col 4		Journal title
# Col 5		DOI
# Col 6		Year
# Col 7		Volume
# Col 8 	Issue
# Col 9		First page
# Col 10	Last page
# Col 11	ISSN
# Col 12	New article "yes" or "no"
# Col 13	PDF1 URL
# Col 14	PDF2 URL (may be blank)
# Col 15	PDF3 URL (may be blank)
# Col 16 	PDF4 URL (may be blank)
# Col 17	PDF5 URL (may be blank)
# Col 18	PDF6 URL (may be blank)
#
# Input mapping to EP3 XML:
#
# Col 1 (1Science ID) --> EPrints suggestions field (label is "Internal Notes")
# Col 2 (Title)       --> EPrints title field
# Col 3 (Authors)     --> Input is a single string of all authors, non-inverted,
# 				and separated by '|'.  These need to be split up,
# 				inverted, default ID's generated, and placed in
# 				the appropriate EPrints creators_name and
# 				creators_id fields.
# Col 4	(Journal title) --> EPrints publication field
# Col 5 (DOI)		--> EPrints DOI field, plus a related_url field of
# 				type 'DOI' with the full doi.org/<doi> URL.
# Col 6 (Year)		--> EPrints date_year field
# Col 7 (Volume)	--> EPrints volume field
# Col 8 (Issue)		--> EPrints issue field
# Col 9 (First page)	--> see next entry
# Col 10 (Last page)	--> Combined with first page-last page to make
# 				EPrints page_range field
# Col 11 (ISSN)		--> EPrints ISSN field
# Col 12 (New article) 	--> If not 'yes', skip record
# Col 13 (PDF1)		--> URL goes into EPrints <documents><document><files>
# 				<file><url> element, where it will drive retrieval
# 				of the actual PDF when the EPrints record load
# Col 14-18, if present --> Create a related_url element with this data. Leave
# 				type blank
#
# Defaults to be added to all output records:
#
# At EPrint level:
#
# <ispublished> with value "pub"
# <full_text_status> with value "public"
# <refereed> with value "TRUE"
# <rights> with standard "No commercial... etc" boilerplate
# <date_type> with value "published""
#
# At Document level:
#
# <security> with value "public"
# <license> with value "other"
#
#
#############################################################################

use Data::Dumper;
use strict;

#my $debug = 1;
my $debug = 0;
my $line = 1;
my $records_read = 0;

my $records_created = 0;

my %records;
 
my $oneScienceID;
my $title;
my $author_string;
my $journal_title;
my $doi;
my $year;
my $volume;
my $issue;
my $first_page;
my $last_page;
my $issn;
my $new_article_flag;
my $PDF1;
my $PDF2;
my $PDF3;
my $PDF4;
my $PDF5;
my $PDF6;

my $xml_declaration = qq {<?xml version="1.0" encoding="UTF-8"?>\n};

my $ep3xml_begin = qq {<eprints xmlns="http://eprints.org/ep2/data/2.0">\n};

my $ep3xml_end = "</eprints>";

# Default data
my $ispublished = "pub";  # CHECK all for correct values!
my $full_text_status = "public";
my $refereed = "TRUE";
my $date_type = "published";
my $rights = "No commercial reproduction, distribution, display or performance rights in this work are provided.";
my $eprint_status = "inbox";
my $type = "article";
my $metadata_visibility = "show";
my $document_security = "public";
my $document_license = "other";

 
# Open input file for reading
# open(IN, "<", "../one_science_sample_100.txt") or die "*** Cannot open one_science_sample_100.txt for input - terminating\n";
# open(IN, "<", "../one_science_caltech_09152016.txt") or die "*** Cannot open one_science_caltech_09152016.txt for input - terminating\n";
open(IN, "<", "../one_science_caltech_09152016_mod.txt") or die "*** Cannot open one_science_caltech_09152016.txt for input - terminating\n";

# Open output file for writing
# open(EPRINTS_OUT, ">", "../" . "ep3xml_out.xml") or die "***Cannot open " . "ep3xml_out.xml" . " for writing.\n\n";
open(EPRINTS_OUT, ">", "../" . "ep3xml_out_mod.xml") or die "***Cannot open " . "ep3xml_out.xml" . " for writing.\n\n";

# Print the opening lines for the output file
print EPRINTS_OUT $xml_declaration;
print EPRINTS_OUT $ep3xml_begin;


while(<IN>)	# loop through input records

{
	if($debug)
	{
		 print "DEBUG Record: " . $_ . "\n\n";
	}

    $_ =~ s/(.*)\r\n$/$1/;      # Remove carriage return at the end of the line

    if($_ !~ m/^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$/)
	{
#        	die "*** Line $line is invalid: $_\n";
	}
	else
	{
		$oneScienceID = $1;
		$title = $2;
		$author_string = $3;
		$journal_title = $4;
		$doi = $5;
		$year = $6;
		$volume = $7;
		$issue = $8;
		$first_page = $9;
		$last_page = $10;
		$issn = $11;
		$new_article_flag = $12;
		$PDF1 = $13;
		$PDF2 = $14;
		$PDF3 = $15;
		$PDF4 = $16;
		$PDF5 = $17;
		$PDF6 = $18;
	}

	# Do some cleanup and sanity checking
	# We must have title, and the value of $new_article_flag must be "yes"
	if($title eq "")
	{
		die "*** Line $line is missing required title: $_\n";
	}

	if($debug)
	{
		print "Title = " . $title . "\n";
		if($PDF1 ne "")
		{
			print "PDF1 = " . $PDF1 . "\n\n";
		}
	}

	# Title and journal title may contain ampersands or other special
	# chars that the XML parser will object to.  Make them entities.
	$title =~ s/\&/\&amp;/g;
	$title =~ s/\</\&lt;/g;
	$title =~ s/\>/\&gt;/g;
	$journal_title =~ s/\&/\&amp;/g;
	$journal_title =~ s/\</\&lt;/g;
        $journal_title =~ s/\>/\&gt;/g;

	# Title and authors may contain double quotes. Remove them.
	$title =~ s/\"//g;
	$author_string =~ s/\"//g;

	# Process the data into EP3XML output here
	# Line 1 is column headers so skip it.
	#
	if( $line > 1 )
	{
		$records_read++;
		
		# by convention, all records that reach this stage of
		# processing should have "yes" in the new_article_flag
        	if ( lc($new_article_flag) ne "yes")
        	{
                	die "*** New article flag not yes on input record: $_\n";
        	}
 
		# build opening <eprint> element
		my $output_record = "<eprint>\n";
	
		# build the <documents> element and its sub-elements,
		# placing the first PDF URL in the <url> to be
		# retrieved by EPrints upon loading
		# First, extract the filename from the end of the $PDF1 string
		# Both filename and url must be handled as CDATA to avoid parsing
		# errors from XML for special characters that may occur in
		# parameter strings.
		my @url_array = split '/', $PDF1;
		my $filename = $url_array[$#url_array];
		if ( lc(substr($filename,length($filename)-4,4)) ne ".pdf" ) {
			$filename .= ".pdf";
		}
		$output_record .= "<documents>\n";
		$output_record .= "<document>\n";
		$output_record .= "<format>application/pdf</format>\n";
                # add default license and security elements
                $output_record .= "<license>" . "other" . "</license>\n";
                $output_record .= "<security>" . "public" . "</security>\n";
		$output_record .= "<files>\n";
		$output_record .= "<file>\n";
		$output_record .= "<filename><![CDATA[" . $filename . "]]></filename>\n";
		$output_record .= "<url><![CDATA[" . $PDF1 . "]]></url>\n";
		$output_record .= "</file>\n";
		$output_record .= "</files>\n";
		$output_record .= "</document>\n";
		$output_record .= "</documents>\n";

		# add default eprints_status element.  Note that this is
		# currently "inbox" so that records go into a user work area 
		# for the user specified on the command line when the import
		# is invoked.
		$output_record .= "<eprint_status>" . $eprint_status . "</eprint_status>\n";

		# add default type element.  We assume article for these.
		$output_record .= "<type>" . $type . "</type>\n";

		# add default metadata_visibility element
		$output_record .= "<metadata_visibility>" . $metadata_visibility . "</metadata_visibility>\n";

		# build creators (authors) elements
		# First write the creators container 
		$output_record .= "<creators>\n";
		# now loop through for each author
		my @authors = split (/\|\|/, $author_string);
		# Most author strings have authors in regular order, but a few have
		# them in inverted order. Look for these and fix them to conform.
		foreach my $author (@authors) {
			# if author contains a comma, fix the order now  #TODO
			my $comma = index($author, ", ");
			if ( $comma > 0 ) {
				my $first_part = substr($author,$comma+2);
				my $second_part = substr($author,0,$comma);
				$author = $first_part . " " . $second_part;
			}
			my $i = rindex($author, " ");
			my $name_given = substr($author,0,$i);
			my $name_family = substr($author,$i+1);
			my $id = $name_family . "-" . $name_given;
			$id =~ s/\s/-/g;
			$id =~ s/\.//g;
			# now build the item element
			$output_record .= "<item>\n";
			$output_record .= "<name>\n";
			$output_record .= "<family>" . $name_family . "</family>\n";
			$output_record .= "<given>" . $name_given . "</given>\n";
			$output_record .= "</name>\n";
			$output_record .= "<id>" . $id . "</id>\n";
			$output_record .= "</item>\n";
		}
		# close the creators container element
		$output_record .= "</creators>\n";
			
		# build title element
		$output_record .= "<title>" . $title . "</title>\n";

		# add default ispublished element
		$output_record .= "<ispublished>" . $ispublished . "</ispublished>\n"; 
		
		# add default full_text_status element
		$output_record .= "<full_text_status>" . $full_text_status . "</full_text_status>\n";

		# add default date_type element
		$output_record .= "<date_type>" . $date_type . "</date_type>\n";

		# add publication if present
		if ( $journal_title ) {
			$output_record .= "<publication>" . $journal_title . "</publication>\n";
		}

		# add volume if present
		if ( $volume ) {
			$output_record .= "<volume>" . $volume . "</volume>\n";
		}		

		# add issue if present
                if ( $issue ) {
                        $output_record .= "<number>" . $issue . "</number>\n";         
                }

		# if present, construct and add pagerange element
		if ( $first_page && $last_page ) {
			$output_record .= "<pagerange>" . $first_page . "-" . $last_page . "</pagerange>\n";
		}
 
		# add default refereed element
		$output_record .= "<refereed>" . $refereed . "</refereed>\n";

		# add issn if present
		$output_record .= "<issn>" . $issn . "</issn>\n";

		# add doi if present
		$output_record .= "<doi>" . $doi . "</doi>\n";

		# add related url elements. The first of these should be built
		# with 'type' doi, using the $doi data.  If there are any values
		# in PDF2 through PDF6, build a related_url for each one.
		# Write the opening related_url tag
		$output_record .= "<related_url>\n";
		# Now build the first item, for the DOI used above in DOI element
		$output_record .= "<item>\n";
		$output_record .= "<url>" . "https://doi.org/" . $doi . "</url>\n";
		$output_record .= "<type>doi</type>\n";
		$output_record .= "<description>Article</description>\n";
		$output_record .= "</item>\n";
		# Now build related urls for any additional PDF links beyond the first
		if ($debug) {
			print "PDF2:" . $PDF2 . "\n";
                        print "PDF3:" . $PDF3 . "\n";
                        print "PDF4:" . $PDF4 . "\n";
                        print "PDF5:" . $PDF5 . "\n";
                        print "PDF6:" . $PDF6 . "\n";
		}
		my @addl_urls = ($PDF2, $PDF3, $PDF4,
			 $PDF5, $PDF6);
		foreach my $addl_url (@addl_urls) {
			# some have whitespace at end. Remove it
			$addl_url =~ s/\s+$//;
			if ($debug) {
				print "Addl_URL:" . $addl_url . "---\n";
			}
			# URLs must be marked as CDATA, otherwise the XML
			# parser will object to possible special characters
			# that may occur in parameter strings
			if ($addl_url) {
				$output_record .= "<item>\n";
				$output_record .= "<url><![CDATA[" . $addl_url . "]]></url>\n";
				$output_record .= "</item>\n";	
			}
		}
		# Close the related_url container elemment
		$output_record .= "</related_url>\n";
		
		# add rights element boilerplate
		$output_record .= "<rights>" . $rights . "</rights>\n";

		# add 1science ID in suggestions element (label is "internal notes")
		if ( $oneScienceID ) {
			$output_record .= "<suggestions>1Science ID: " . $oneScienceID . "</suggestions>\n";
		}

 
		# add the closing </eprint> end tag
		$output_record .= "</eprint>\n";
		
		$records_created++;
	 
		# Write the EP3XML record
	
		if($debug)	# just print to STDOUT
		{
			print $output_record . "\n\n\n";
		}
		else		# write to the EP3XML output file
		{
		
			# Write EPRINTS XML file
			print EPRINTS_OUT $output_record;
		}		

	}

	$line++;

}

# write the closing tag for the file;
print EPRINTS_OUT $ep3xml_end;


close(IN);
close(EPRINTS_OUT);
 
print "Number of records processed:	$records_read\n\n";
print "Number of EPRINTS records created:	$records_created\n";




		
