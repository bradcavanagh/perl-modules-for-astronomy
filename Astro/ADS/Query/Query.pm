package Astro::ADS::Query;

# ---------------------------------------------------------------------------

#+ 
#  Name:
#    Astro::ADS::Query

#  Purposes:
#    Perl wrapper for the ADS database

#  Language:
#    Perl module

#  Description:
#    This module wraps the ADS online database.

#  Authors:
#    Alasdair Allan (aa@astro.ex.ac.uk)

#  Revision:
#     $Id: Query.pm,v 1.3 2001/11/01 18:02:53 aa Exp $

#  Copyright:
#     Copyright (C) 2001 University of Exeter. All Rights Reserved.

#-

# ---------------------------------------------------------------------------

=head1 NAME

Astro::ADS::Query - Object definining an prospective ADS query.

=head1 SYNOPSIS

  $query = new Astro::ADS::Query( Authors => \@authors );
  
  my $results = $query->querydb();

=head1 DESCRIPTION

Stores information about an prospective ADS query and allows the query to
be made, returning an Astro::ADS::Result object.

=cut

# L O A D   M O D U L E S --------------------------------------------------

use strict;
use vars qw/ $VERSION /;

use LWP::UserAgent;
use Astro::ADS::Result;
use Astro::ADS::Result::Paper;
use Carp;

'$Revision: 1.3 $ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# C O N S T R U C T O R ----------------------------------------------------

=head1 REVISION

$Id: Query.pm,v 1.3 2001/11/01 18:02:53 aa Exp $

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new instance from a hash of options

  $query = new Astro::ADS::Query( Authors => \@authors );

returns a reference to an ADS query object.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # bless the query hash into the class
  my $block = bless { OPTIONS   => {},
                      URL       => undef,
                      USERAGENT => undef,
                      BUFFER    => undef }, $class;

  # If we have arguments configure the object
  $block->configure( @_ ) if @_;

  return $block;

}

# M E T H O D S -----------------------------------------------------------

=back

=head2 Accessor Methods

=over 4

=item B<querydb>

Returns an Astro::ADS::Result object

   $results = $query->querydb();

=cut

sub querydb {
  my $self = shift;
  use Data::Dumper;

  # call the private method to make the actual ADS query
  $self->_make_query();

  # check for failed connect
  return undef unless defined $self->{BUFFER};
   
  # get a local copy of the current BUFFER
  my @buffer = split( /\n/,$self->{BUFFER});
  chomp @buffer;
 
  # create an Astro::ADS::Result object to hold the search results
  my $result = new Astro::ADS::Result();
  
  # create a temporary object to hold papers
  my $paper;
  
  # loop round the returned buffer and stuff the contents into Paper objects
  my ( $line, $next, $counter );
  $next = $counter = 0;
  foreach $line ( 0 ... $#buffer ) {

     #     R     Bibcode
     #     T     Title
     #     A     Author List
     #     F     Affiliations
     #     J     Journal Reference
     #     D     Publication Date
     #     K     Keywords
     #     G     Origin
     #     I     Outbound Links
     #     U     Document URL
     #     O     Object name
     #     B     Abstract
            
     # NEW PAPER
     if( substr( $buffer[$line], 0, 2 ) eq "%R" ) {
                    
        $counter = $line;
        my $tag = substr( $buffer[$counter], 1, 1 );
        
        # grab the bibcode
        my $bibcode = substr( $buffer[$counter], 2 );
        
        # New Astro::ADS::Result::Paper object
        $paper = new Astro::ADS::Result::Paper( Bibcode => $bibcode );
                       
        $counter++;
                
        # LOOP THROUGH PAPER
        my ( @title, @authors );
        while ( substr( $buffer[$counter], 0, 2 ) ne "%R" &&
                $counter < $#buffer ) {
           
           #print "counter $counter\n";
           #print "substring " . substr( $buffer[$counter], 0, 2 ) . "\n";
           #print "buffer: $buffer[$counter]\n";
                         
           # grab the tags
           if( substr( $buffer[$counter], 0, 1 ) eq "%" ) {
              $tag = substr( $buffer[$counter], 1, 1 );
           }
           
           # ckeck for each tag and stuff the contents into the paper object
           
           # TITLE
           # -----
           if( $tag eq "T" ) {
             
              #do we have the start of an title block?
              if ( substr( $buffer[$counter], 0, 1 ) eq "%") {
              
                 # push the end of line substring onto array
                 push ( @title, substr( $buffer[$counter], 3 ) );
                 
              } else {
                 
                 # push the entire line onto the array
                 push (@title, $buffer[$counter] );
                
              }  
           }
           
           # AUTHORS
           # -------
           if( $tag eq "A" ) {
           
              #do we have the start of an author block?
              if ( substr( $buffer[$counter], 0, 1 ) eq "%") {
              
                 # push the end of line substring onto array
                 push ( @authors, substr( $buffer[$counter], 3 ) );
                 
              } else {
                 
                 # push the entire line onto the array
                 push (@authors, $buffer[$counter] );
                
              }
           }
           
           
           

           # increment the line counter
           $counter = $counter + 1;
           # set the next paper increment
           $next = $counter - 1;            
              
        }
        
        # PUSH TITLE INTO PAPER OBJECT
        # ------------------------------
        chomp @title;
        my $title_line = "";
        for my $i ( 0 ... $#title ) {
           # drop it onto one line
           $title_line = $title_line . $title[$i];      
        }
        $paper->title( $title_line );
        
        # PUSH AUTHORS INTO PAPER OBJECT
        # ------------------------------
        chomp @authors;
        my $author_line = "";
        for my $i ( 0 ... $#authors ) {
           # drop it onto one line
           $author_line = $author_line . $authors[$i];      
        }
        # get rid of leading spaces before author names
        $author_line =~ s/;\s+/;/g;
        
        my @paper_authors = split( /;/, $author_line );
        $paper->authors( \@paper_authors );
        
           
     }
        
     # increment the line counter to the correct index for the next paper
     $line = $line + $next;

     #print "line $line, next $next, counter $counter, #buffer $#buffer\n";
     #print Dumper($paper);
  
     # push the new paper onto the Astro::ADS::Result object
     $result->pushpaper($paper) if defined $paper;
     $paper = undef;
     
   }   

   print Dumper($result);
}

=item B<Authors>

Return (or set) the current authors defined for the ADS query.

   @authors = $query->authors();
   $first_author = $query->authors();
   $query->authors( \@authors );

if called in a scalar context it will return the first author.

=cut

sub authors {
  my $self = shift;
  
  # SETTING AUTHORS
  if (@_) { 

    # clear the current author list   
    ${$self->{OPTIONS}}{"author"} = "";
    
    # grab the new list from the arguements
    my $author_ref = shift;
    
    # make a local copy to use for regular expressions
    my @author_list = @$author_ref;

    # mutilate it and stuff it into the author list OPTION
    for my $i ( 0 ... $#author_list ) {
       $author_list[$i] =~ s/\s/\+/g;
       
       if ( $i eq 0 ) {
          ${$self->{OPTIONS}}{"author"} = $author_list[$i];
       } else {
          ${$self->{OPTIONS}}{"author"} = 
               ${$self->{OPTIONS}}{"author"} . ";" . $author_list[$i]; 
       }
    }
  }
  
  # RETURNING AUTHORS 
  my $author_line =  ${$self->{OPTIONS}}{"author"};
  $author_line =~ s/\+/ /g;
  my @authors = split(/;/, $author_line);

  return wantarray ? @authors : $authors[0];
}

=item B<AuthorLogic>

Return (or set) the logic when dealing with multiple authors for a search,
possible values for this parameter are OR, AND, SIMPLE, BOOL and FULLMATCH.

   $author_logic = $query->authorlogic();
   $query->authorlogic( "AND" );

=cut

sub authorlogic {
  my $self = shift;

  if (@_) {
  
     my $logic = shift; 
     if ( $logic eq "OR"   || $logic eq "AND" || $logic eq "SIMPLE" ||
          $logic eq "BOOL" || $logic eq "FULLMATCH" ) {

        # set the new logic
        ${$self->{OPTIONS}}{"aut_logic"} = $logic;
     }
  }
  
  return ${$self->{OPTIONS}}{"aut_logic"};
}
   
# C O N F I G U R E -------------------------------------------------------

=back

=head2 General Methods

=over 4

=item B<configure>

Configures the object, takes an options hash as an argument

  $query->configure( %options );

Does nothing if the array is not supplied.

=over 4

=item B<Authors>

A list of authors for the query. By default author logic is set to OR rather
than the potentially more useful AND.

=item B<AuthorLogic>

By default the author logic, i.e. how the author names are combined during
the search, is set to OR. Other options include; AND, combine with AND; SIMPLE, use simple logic (use +,-); BOOL, full boolean logic and FULLMATCH, do an AND query and calculate the score according to how many words in the author field match in the paper.

=cut

sub configure {
  my $self = shift;

  # return unless we have arguments
  return undef unless @_;

  # define the base URL
  $self->{URL} = "http://cdsads.u-strasbg.fr/cgi-bin/nph-abs_connect?";

  # configure the default options
  ${$self->{OPTIONS}}{"db_key"}           = "AST";
  ${$self->{OPTIONS}}{"sim_query"}        = "YES";
  ${$self->{OPTIONS}}{"aut_xct"}          = "NO";
  ${$self->{OPTIONS}}{"aut_logic"}        = "OR";
  ${$self->{OPTIONS}}{"obj_logic"}        = "OR";
  ${$self->{OPTIONS}}{"author"}           = "";
  ${$self->{OPTIONS}}{"object"}           = "";
  ${$self->{OPTIONS}}{"keyword"}          = "";
  ${$self->{OPTIONS}}{"start_mon"}        = "";
  ${$self->{OPTIONS}}{"start_year"}       = "";
  ${$self->{OPTIONS}}{"end_mon"}          = "";
  ${$self->{OPTIONS}}{"end_year"}         = "";
  ${$self->{OPTIONS}}{"ttl_logic"}        = "OR";
  ${$self->{OPTIONS}}{"title"}            = "";
  ${$self->{OPTIONS}}{"txt_logic"}        = "OR";
  ${$self->{OPTIONS}}{"text"}             = "";
  ${$self->{OPTIONS}}{"nr_to_return"}     = "100";
  ${$self->{OPTIONS}}{"start_nr"}         = "1";
  ${$self->{OPTIONS}}{"start_entry_day"}  = "";
  ${$self->{OPTIONS}}{"start_entry_mon"}  = "";
  ${$self->{OPTIONS}}{"start_entry_year"} = "";
  ${$self->{OPTIONS}}{"min_score"}        = "";
  ${$self->{OPTIONS}}{"jou_pick"}         = "ALL";
  ${$self->{OPTIONS}}{"ref_stems"}        = "";
  ${$self->{OPTIONS}}{"data_and"}         = "ALL";
  ${$self->{OPTIONS}}{"group_and"}        = "ALL";
  ${$self->{OPTIONS}}{"sort"}             = "SCORE";
  ${$self->{OPTIONS}}{"aut_syn"}          = "YES";
  ${$self->{OPTIONS}}{"ttl_syn"}          = "YES";
  ${$self->{OPTIONS}}{"txt_syn"}          = "YES";
  ${$self->{OPTIONS}}{"aut_wt"}           = "1.0";
  ${$self->{OPTIONS}}{"obj_wt"}           = "1.0";
  ${$self->{OPTIONS}}{"ttl_wt"}           = "0.3";
  ${$self->{OPTIONS}}{"txt_wt"}           = "3.0";
  ${$self->{OPTIONS}}{"aut_wgt"}          = "YES";
  ${$self->{OPTIONS}}{"obj_wgt"}          = "YES";
  ${$self->{OPTIONS}}{"ttl_wgt"}          = "YES";
  ${$self->{OPTIONS}}{"txt_wgt"}          = "YES";
  ${$self->{OPTIONS}}{"ttl_sco"}          = "YES";
  ${$self->{OPTIONS}}{"txt_sco"}          = "YES";
  ${$self->{OPTIONS}}{"version"}          = "1";

  # Set the data_type option to PORTABLE so our regular expressions work!
  ${$self->{OPTIONS}}{"data_type"}        = "PORTABLE";

  # grab the argument list
  my %args = @_;
  
  # Loop over the allowed keys and modify the default query options
  for my $key (qw / Authors AuthorLogic / ) {
      my $method = lc($key);
      $self->$method( $args{$key} ) if exists $args{$key};
  }  
  
  # Setup the LWP::UserAgent
  $self->{USERAGENT} = new LWP::UserAgent( timeout => 30 ); 

}

# T I M E   A T   T H E   B A R  --------------------------------------------

=back

=end __PRIVATE_METHODS__

=head2 Private methods

These methods are for internal use only.

=over 4

=item B<_make_query>

Private function used to make an ADS query. Should not be called directly,
since it does not parse the results. Instead use the querydb() assessor method.

=cut

sub _make_query {
   my $self = shift;
   
   # grab the user agent
   my $ua = $self->{USERAGENT};
   
   # clean out the buffer
   $self->{BUFFER} = "";
   
   # grab the base URL
   my $URL = $self->{URL};
   my $options = "";
   
   # loop round all the options keys and build the query   
   foreach my $key ( keys %{$self->{OPTIONS}} ) {
      $options = $options . "&$key=${$self->{OPTIONS}}{$key}"; 
   }
     
   # build final query URL
   $URL = $URL . $options;
   
   # build request
   my $request = new HTTP::Request('GET', $URL);
   
   # grab page from web
   my $reply = $ua->request($request);
   
   if ( ${$reply}{"_rc"} eq 200 ) {
      # stuff the page contents into the buffer
      $self->{BUFFER} = ${$reply}{"_content"};
   } else {
      $self->{BUFFER} = undef;
      croak("Error ${$reply}{_rc}: Failed to establish network connection");
   }
}

=item B<_dump_raw>

Private function for debugging and other testing purposes. It will return
the raw output of the last ADS query made using querydb().

=cut

sub _dump_raw {
   my $self = shift;
   
   # split the BUFFER into an array
   my @portable = split( /\n/,$self->{BUFFER});
   chomp @portable;
   
   return @portable;
}

=head1 COPYRIGHT

Copyright (C) 2001 University of Exeter. All Rights Reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Alasdair Allan E<lt>aa@astro.ex.ac.ukE<gt>,

=cut

# L A S T  O R D E R S ------------------------------------------------------

1;                                                                  
