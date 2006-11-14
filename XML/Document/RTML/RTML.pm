package XML::Document::RTML;
# ---------------------------------------------------------------------------

#+ 
#  Name:
#    XML::Document::RTML

#  Purposes:
#    Perl module to build and parse RTML documents

#  Language:
#    Perl module

#  Authors:
#    Alasdair Allan (aa@astro.ex.ac.uk)

#  Revision:
#     $Id: RTML.pm,v 1.6 2006/11/14 17:27:55 aa Exp $

#  Copyright:
#     Copyright (C) 200s University of Exeter. All Rights Reserved.

#-

# ---------------------------------------------------------------------------

=head1 NAME

XML::Document::RTML - module which builds and parses RTML documents

=head1 SYNOPSIS

An object instance can be created from an existing RTML document in a 
scalar, or directly from a file on local disk.


   my $object = new XML::Document::RTML( XML => $xml );
   my $object = new XML::Document::RTML( File => $file );
   
or via the build method,

   my $object = new XML::Document::RTML() 
   $document = $object->build( %hash );
   
once instantiated various query methods are supported, e.g.,

   my $object = new XML::Document::RTML( File => $file );
   my $role = $object->role();

=head1 DESCRIPTION

The module can build and parse RTML documents. Currently only version 2.2
of the standard is supported by the module.

=cut
# L O A D   M O D U L E S --------------------------------------------------

use strict;
use vars qw/ $VERSION $SELF /;

#use XML::Parser;
use XML::Simple;
use XML::Writer;
use XML::Writer::String;

use Net::Domain qw(hostname hostdomain);
use File::Spec;
use Carp;
use Data::Dumper;

use Astro::FITS::Header;
use Astro::VO::VOTable;

'$Revision: 1.6 $ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# C O N S T R U C T O R ----------------------------------------------------

=head1 REVISION

$Id: RTML.pm,v 1.6 2006/11/14 17:27:55 aa Exp $

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new instance from a hash of options

  my $object = new XML::Document::RTML( %hash );

returns a reference to an message object.

=cut


sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # bless the query hash into the class
  my $block = bless { DOCUMENT => undef,  # hash generated by XML::Simple
                      WRITER   => undef,  # reference to an XML::Writer
                      BUFFER   => undef,  # reference to an XML::Writer::String
		      DTD      => undef
		    }, $class;

  # Configure the object
  $block->configure( @_ ); 

  return $block;

}

# B U I L D   M E T H O D ------------------------------------------------

sub build {
  my $self = shift;
  my %args = @_;

  # mandatory tags
  unless ( exists $args{Role} ) {
     return undef;
  }         

  # open the document
  $self->{WRITER}->xmlDecl( 'US_ASCII' );
   
  # BEGIN DOCUMENT ------------------------------------------------------- 
  
  $self->{WRITER}->doctype( 'RTML', '', $self->{DTD} );


  # SKELETON DOCUMENT ----------------------------------------------------

  $self->{WRITER}->endTag( 'RTML' );
  $self->{WRITER}->end();

  my $xml = $self->{BUFFER}->value();
  $self->_parse( XML => $xml ); # populates the object with a parsed document
  return $xml;  

}  

# A C C E S S O R   M E T H O D S -------------------------------------------

=back

=head2 Accessor Methods

=over 4

=item B<type>

Return, or set, the type of the RTML document

  my $type = $object->type();
  $object->type( $type );

=cut

sub role {
  my $self = shift;
  if (@_) {
     $self->{DOCUMENT}->{type} = shift;
  }
  return $self->{DOCUMENT}->{type};
}

sub type {
  role( @_ );
}

sub determine_type {
  role( @_ );
}

=item B<version>

Return, or set, the version of the RTML specification used

  my $version = $object->version();
  $object->version( $version );

=cut

sub version {
  my $self = shift;
  if (@_) {
     $self->{DOCUMENT}->{version} = shift;
  }  
  return $self->{DOCUMENT}->{version};
}

sub dtd {
   version( @_ );
}


# S C H E D U L E #########################################################

=back

=head2 Scheduling Methods

=over 4

=item B<group_count>

Return, or set, the group count of the observation

  my $num = $object->group_count();
  $object->group_count( $num );
  
=cut

sub group_count {
  my $self = shift;
  if (@_) {
     $self->{DOCUMENT}->{Observation}->{Schedule}->{Exposure}->{Count} = shift;
  }  
  return $self->{DOCUMENT}->{Observation}->{Schedule}->{Exposure}->{Count};
}

sub groupcount {
  group_count( @_ );
}  

=item B<exposure_time>

Return, or set, the exposure time of the observation

  my $num = $object->exposure_time();
  $object->exposure_time( $num );
  
=cut

sub exposure_time {
  my $self = shift;
  if (@_) {
     $self->{DOCUMENT}->{Observation}->{Schedule}->{Exposure}->{content} = shift;
     $self->{DOCUMENT}->{Observation}->{Schedule}->{Exposure}->{type} = "time";
     $self->{DOCUMENT}->{Observation}->{Schedule}->{Exposure}->{units} = "seconds";
  }  
  return $self->{DOCUMENT}->{Observation}->{Schedule}->{Exposure}->{content};
}

sub exposuretime {
  exposure_time( @_ );
}  

sub exposure {
  exposure_time( @_ );
}  

=item B<signal_to_noise>

Return, or set, the S/N of the observation

  my $num = $object->signal_to_noise();
  $object->signal_to_noise( $num );
  
=cut

sub signal_to_noise {
  my $self = shift;
  if (@_) {
     $self->{DOCUMENT}->{Observation}->{Schedule}->{Exposure}->{content} = shift;
     $self->{DOCUMENT}->{Observation}->{Schedule}->{Exposure}->{type} = "snr";
  }  
  return $self->{DOCUMENT}->{Observation}->{Schedule}->{Exposure}->{content};
}

sub signaltonoise {
  signal_to_noise( @_ );
}  

sub snr {
  signal_to_noise( @_ );
}  

=item B<exposure_type>

Return, or set, the type of exposure of the observation

  my $string = $object->exposure_type();
  $object->exposure_type( $string );

where $string can have values of "snr" or "time".
  
=cut

sub exposure_type {
  my $self = shift;
  if (@_) {
     my $type = shift;
     if ( $type eq "snr" )  {
        $self->{DOCUMENT}->{Observation}->{Schedule}->{Exposure}->{type} = "snr";
     } else {
        $self->{DOCUMENT}->{Observation}->{Schedule}->{Exposure}->{type} = "time";
        $self->{DOCUMENT}->{Observation}->{Schedule}->{Exposure}->{units} = "seconds";
     }
  }  
  return $self->{DOCUMENT}->{Observation}->{Schedule}->{Exposure}->{type};
}

sub exposuretype {
  exposure_type( @_ );
}  

=item B<series_count>

Return, or set, the series count of the observation

  my $num = $object->series_count();
  $object->series_count( $num );
  
=cut

sub series_count {
  my $self = shift;
  if (@_) {
     $self->{DOCUMENT}->{Observation}->{Schedule}->{SeriesConstraint}->{Count} = shift;
  }  
  return $self->{DOCUMENT}->{Observation}->{Schedule}->{SeriesConstraint}->{Count};
}

sub seriescount {
  series_count( @_ );
}  

=item B<interval>

Return, or set, the interval between a series of observations blocks

  my $num = $object->interval();
  $object->interval( $num );
  
=cut

sub interval {
  my $self = shift;
  if (@_) {
     my $arg = shift;
     unless ( $arg =~ "PT" ) {
       $arg = "PT" . $arg;
     }   
     $self->{DOCUMENT}->{Observation}->{Schedule}->{SeriesConstraint}->{Interval} = $arg;
  }  
  return $self->{DOCUMENT}->{Observation}->{Schedule}->{SeriesConstraint}->{Interval};
}

=item B<tolerance>

Return, or set, the tolerance between a series of observations blocks

  my $num = $object->tolerance();
  $object->tolerance( $num );
  
=cut

sub tolerance {
  my $self = shift;
  if (@_) {
    my $arg = shift;
    unless ( $arg =~ "PT" ) {
       $arg = "PT" . $arg;
    }
    $self->{DOCUMENT}->{Observation}->{Schedule}->{SeriesConstraint}->{Tolerance} = $arg;
  }  
  return $self->{DOCUMENT}->{Observation}->{Schedule}->{SeriesConstraint}->{Tolerance};
}


=item B<priority>

Return, or set, the priority of the observation

  my $num = $object->priority();
  $object->priority( $num );
 
Schedule (RTML) priority     Phase II Priority  Phase II GUI
   N/A                       5                  Urgent
   0                         4                  (default) Normal
   1                         3                  High
   2                         2                  Medium
   3                         1                  Normal
   default(other)            1                  Normal
   N/A                       0                  Normal

where: "Schedule (RTML) priority" is the number specified in the RTML:
<Schedule priority="n">, "Phase II Priority" is the number stored in the 
Phase II database and "Phase II GUI" is what is displayed in the Phase II GUI.

Note:
The Phase II priority 4 can be specified by the TEA but cannot be specified 
by the Phase II GUI (and displays as the default "Normal" in the GUI). The 
Phase II priority 5 I<cannot> be specified by the TEA but can be specified by 
the Phase II GUI as Urgent.

=cut

sub priority {
  my $self = shift;
  if (@_) {
     $self->{DOCUMENT}->{Observation}->{Schedule}->{priority} = shift;
  }  
  return $self->{DOCUMENT}->{Observation}->{Schedule}->{priority};
}

sub schedule_priority {
  priority( @_ );
}  

=item B<time_constraint>

Return, or set, the time constraints of the the observation

  my $array_reference = $object->time_constraint();
  $object->exposure_type( \@times );

where it takes and returns a scalar reference to an array of ISO8601
times, e.g. my $array_reference = [ $start, $end ] which maps to,

      <TimeConstraint>
        <StartDateTime>2006-09-10T11:12:51+0100</StartDateTime>
        <EndDateTime>2006-09-12T00:12:51+0100</EndDateTime>
      </TimeConstraint>
  
=cut

sub time_constraint {
  my $self = shift;

  if (@_) {
    
    my $ref = shift;
    my @array = @{$ref};
  
    $self->{DOCUMENT}->{Observation}->{Schedule}->{TimeConstraint}->{StartDateTime} = $array[0];
    $self->{DOCUMENT}->{Observation}->{Schedule}->{TimeConstraint}->{EndDateTime} = $array[1];
  }

  return ( $self->{DOCUMENT}->{Observation}->{Schedule}->{TimeConstraint}->{StartDateTime},
           $self->{DOCUMENT}->{Observation}->{Schedule}->{TimeConstraint}->{EndDateTime} );
	   
}

sub timeconstraint {
   time_constraint( @_ );
}   

sub start_time {
   my $self = shift;
   return $self->{DOCUMENT}->{Observation}->{Schedule}->{TimeConstraint}->{StartDateTime};
}

sub end_time{
   my $self = shift;
   return $self->{DOCUMENT}->{Observation}->{Schedule}->{TimeConstraint}->{EndDateTime};
}

# D E V I C E ##############################################################

=back

=head2 Device Methods

=over 4

=item B<device_type>

Return, or set, the device type for the observation

  my $string = $object->device_type();
  $object->device_type( $string );
  
=cut

sub device_type {
  my $self = shift;
  if (@_) {
     $self->{DOCUMENT}->{Observation}->{Device}->{type} = shift;
  }  
  return $self->{DOCUMENT}->{Observation}->{Device}->{type};
}

sub devicetype {
  device_type( @_ );
}  

sub device {
  device( @_ );
}

=item B<filter_type>

Return, or set, the filter type for the observation

  my $string = $object->filter_type();
  $object->filter_type( $string );
  
=cut

sub filter_type {
  my $self = shift;
  if (@_) {
     $self->{DOCUMENT}->{Observation}->{Device}->{Filter}->{FilterType} = shift;
  }  
  return $self->{DOCUMENT}->{Observation}->{Device}->{Filter}->{FilterType};
}

sub filtertype {
  filter_type( @_ );
}  

sub filter {
  filter( @_ );
} 
 
# T A R G E T ##############################################################

=back

=head2 Target Methods

=over 4

=item B<target_type>

Return, or set, the type of target for the observation

  my $string = $object->target_type();
  $object->target_type( $string );

there are two types of valid target type; "normal" or "toop". A normal 
observation is placed into the queue
  
=cut

sub target_type {
  my $self = shift;
  if (@_) {
     $self->{DOCUMENT}->{Observation}->{Target}->{type} = shift;
  }  
  return $self->{DOCUMENT}->{Observation}->{Target}->{type};
}

sub targettype {
  target_type( @_ );
}  


=item B<target_ident>

Return, or set, the type identifier of target for the observation

  my $string = $object->target_ident();
  $object->target_ident( $string );

The target identity is used by the eSTAR system to choose post-observation
processing blocks, e.g.

  <Target type="normal" ident="ExoPlanetMonitor">
  
signifies a normal queued observation which is part of the exo-planet
monitoring programme on Robonet-1.0.

=cut

sub target_ident {
  my $self = shift;
  if (@_) {
     $self->{DOCUMENT}->{Observation}->{Target}->{ident} = shift;
  }  
  return $self->{DOCUMENT}->{Observation}->{Target}->{ident};
}

sub targetident {
  target_ident( @_ );
}  

sub identity {
  target_ident( @_ );
}  

=item B<target_name>

Return, or set, the target name for the observation

  my $string = $object->target_name();
  $object->target_name( $string );

=cut

sub target_name {
  my $self = shift;
  if (@_) {
     $self->{DOCUMENT}->{Observation}->{Target}->{TARGETNAME} = shift;
  }  
  return $self->{DOCUMENT}->{Observation}->{Target}->{TARGETNAME};
}

sub targetname {
  target_name( @_ );
}  

sub target {
  target_name( @_ );
}  


=item B<ra>

Sets (or returns) the target RA

   my $ra = $object->ra();
   $object->ra( '12 35 65.0' );

must be in the form HH MM SS.S.

=cut

sub ra {
  my $self = shift;

  if (@_) {
    $self->{DOCUMENT}->{Observation}->{Target}->{Coordinates}->{RightAscension}->{content} = shift;
  }
  return $self->{DOCUMENT}->{Observation}->{Target}->{Coordinates}->{RightAscension}->{content};
}  
 
sub ra_format {
  my $self = shift;

  if (@_) {
    $self->{DOCUMENT}->{Observation}->{Target}->{Coordinates}->{RightAscension}->{format} = shift;
  }
  return $self->{DOCUMENT}->{Observation}->{Target}->{Coordinates}->{RightAscension}->{format};
}
 
sub ra_units {
  my $self = shift;

  if (@_) {
    $self->{DOCUMENT}->{Observation}->{Target}->{Coordinates}->{RightAscension}->{units} = shift;
  }
  return $self->{DOCUMENT}->{Observation}->{Target}->{Coordinates}->{RightAscension}->{units};
} 

=item B<dec>

Sets (or returns) the target DEC

   my $dec = $object->dec();
   $object->dec( '+60 35 32' );

must be in the form SDD MM SS.S.

=cut

sub dec {
  my $self = shift;

  if (@_) {
    $self->{DOCUMENT}->{Observation}->{Target}->{Coordinates}->{Declination}->{content} = shift;
  }
  return $self->{DOCUMENT}->{Observation}->{Target}->{Coordinates}->{Declination}->{content};
}  
 
sub dec_format {
  my $self = shift;

  if (@_) {
    $self->{DOCUMENT}->{Observation}->{Target}->{Coordinates}->{Declination}->{format} = shift;
  }
  return $self->{DOCUMENT}->{Observation}->{Target}->{Coordinates}->{Declination}->{format};
}
   
sub dec_units {
  my $self = shift;

  if (@_) {
    $self->{DOCUMENT}->{Observation}->{Target}->{Coordinates}->{Declination}->{units} = shift;
  }
  return $self->{DOCUMENT}->{Observation}->{Target}->{Coordinates}->{Declination}->{units};
} 


=item B<equinox>

Sets (or returns) the equinox of the target co-ordinates

   my $equnox = $object->equinox();
   $object->equinox( 'B1950' );

default is J2000, currently the telescope expects J2000.0 coordinates, no
translation is currently carried out by the library before formatting the
RTML message. It is therefore suggested that the user provides their 
coordinates in J2000.0 as this is merely a placeholder routine.

=cut

sub equinox {
  my $self = shift;

  if (@_) {
    $self->{DOCUMENT}->{Observation}->{Target}->{Coordinates}->{Equinox} = shift;
  }
  return $self->{DOCUMENT}->{Observation}->{Target}->{Coordinates}->{Equinox};
}

 
# A G E N T ##############################################################

=back

=head2 Agent Methods

=over 4

=item B<host>

Return, or set, the host to return asynchronous messages to regarding the
status of the observation, see also C<port( )>.

  my $string = $object->host();
  $object->host( $string );

defaults to the current machine's IP address
  
=cut

sub host {
  my $self = shift;
  if (@_) {
     $self->{DOCUMENT}->{IntelligentAgent}->{host} = shift;
  }  
  return $self->{DOCUMENT}->{IntelligentAgent}->{host};
}

sub host_name {
  host( @_ );
}  

sub agent_host {
  host( @_ );
}   

=item B<port>

Return, or set, the port to return asynchronous messages to regarding the
status of the observation, see also C<host( )>.

  my $string = $object->port();
  $object->port( $string );

defaults to 8000.
  
=cut

sub port {
  my $self = shift;
  if (@_) {
     $self->{DOCUMENT}->{IntelligentAgent}->{port} = shift;
  }  
  return $self->{DOCUMENT}->{IntelligentAgent}->{port};
}

sub port_number {
  port( @_ );
} 

sub portnumber {
  port( @_ );
} 

=item B<id>

Sets (or returns) the unique ID for the observation request

   my $id = $object->id();
   $object->id( 'IATEST0001:CT1:0013' );

note that there is NO DEFAULT, a unique ID for the score/observing 
request must be supplied, see the eSTAR Communications and the TEA 
command set documents for further details.

Note: This is I<not> the same thing as the I<target identity> for the
observation.

=cut

sub id {
  my $self = shift;

  if (@_) {
    ${$self->{OPTIONS}}{IntelligentAgent}->{content} = shift;
  }

  # return the current ID
  return ${$self->{OPTIONS}}{IntelligentAgent}->{content};
} 
 
sub unique_id {
  id( @_ );
}   

 
# C O N A C T ##############################################################

=back

=head2 Contact Methods

=over 4

=item B<name>

Return, or set, the name of the observer

  my $string = $object->name();
  $object->name( $string );

  
=cut

sub name {
  my $self = shift;
  if (@_) {
     $self->{DOCUMENT}->{Contact}->{Name} = shift;
  }  
  return $self->{DOCUMENT}->{Contact}->{Name};
}

sub observer_name {
  name( @_ );
}  

sub real_name {
  name( @_ );
}   

=item B<user>

Return, or set, the user name of the observer

  my $string = $object->user();
  $object->user( $string );

e.g. PATT/keith.horne
  
=cut

sub user {
  my $self = shift;
  if (@_) {
     $self->{DOCUMENT}->{Contact}->{User} = shift;
  }  
  return $self->{DOCUMENT}->{Contact}->{User};
}

sub user_name {
  user( @_ );
} 

=item B<institution>

Return, or set, the institutional affliation of the observer

  my $string = $object->institution();
  $object->institution( $string );

e.g. University of Exeter
  
=cut

sub institution {
  my $self = shift;
  if (@_) {
     $self->{DOCUMENT}->{Contact}->{Institution} = shift;
  }  
  return $self->{DOCUMENT}->{Contact}->{Institution};
}

sub institution_affiliation {
  institution( @_ );
}


=item B<project>

Return, or set, the user name of the observer

  my $string = $object->user();
  $object->user( $string );

e.g. PATT/keith.horne
  
=cut

sub project {
  my $self = shift;
  if (@_) {
     $self->{DOCUMENT}->{Project} = shift;
  }  
  return $self->{DOCUMENT}->{Project};
}

 
# S C O R I N G  ##############################################################

=back

=head2 Scoring Methods

=over 4

=item B<score>

Sets (or returns) the target score

   my $score = $object->score();
   $object->score( $score );

the score will be between 0.0 and 1.0

=cut

sub score {
  my $self = shift;

  if (@_) {
     $self->{DOCUMENT}->{Score} = shift;
  }

  # return the current target score
  return $self->{DOCUMENT}->{Score};
}

  
=item B<completion_time>

Sets (or returns) the target completion time

   my $time = $object->completion_time();
   $object->completion_time( $time );

the completion time should be of the format YYYY-MM-DDTHH:MM:SS

=cut

sub completion_time {
  my $self = shift;

  if (@_) {
    $self->{DOCUMENT}->{CompletionTime} = shift;
  }

  # return the current target score
  return $self->{DOCUMENT}->{CompletionTime};
} 

sub completiontime {
   completion_time( @_ );
}

sub time {
   completion_time( @_ );
}

 
# D A T A  ################################################################

=back

=head2 Data Methods

=over 4

=item B<data>

Sets (or returns) the data associated with the observation

   my @data = $object->data( );
   $object->data( @data );

Takes an array of hashes where,

   @data = [ { Catalogue => ' ', Header => ' ', URL => ' ' },
             { Catalogue => ' ', Header => ' ', URL => ' ' },
	           .
	           .
	           .
             { Catalogue => ' ', Header => ' ', URL => ' ' } ];

and the value of the Catalogue hash entry is a URL pointing to a VOTavle, 
the Header hash entry is a FITS header block and the URL is either points 
to a FITS file, or other associated data product. You can I<not> append
data to an existing memory structure, any data passed via this routine 
will overwrite any existing data structure in memory.

The routine returns a similar array when queried. This array will be 
populated either by calling C<build( )>, or through parsing a document.

=cut

sub data {
  my $self = shift;

  if (@_) {
     my @array = @_;
     $self->{DOCUMENT}->{Observation}->{ImageData} = [];
     foreach my $i ( 0 ... $#array ) {
        my %hash = %{$array[$i]};

	# Images
	if ( defined $hash{URL} ) {
	   $self->{DOCUMENT}->{Observation}->{ImageData}[$i]->{content} = $hash{URL};
	   $self->{DOCUMENT}->{Observation}->{ImageData}[$i]->{delivery} = "url";
	   $self->{DOCUMENT}->{Observation}->{ImageData}[$i]->{type} = "FITS16";
	   $self->{DOCUMENT}->{Observation}->{ImageData}[$i]->{reduced} = "true";
	}
	   
	# Catalogues
        if( defined $hash{Catalogue} ) {
	   $self->{DOCUMENT}->{Observation}->{ImageData}[$i]->{ObjectList}->{content} = $hash{Catalogue};
	   if( $hash{Catalogue} =~ "http" && $hash{Catalogue} =~ "votable" ) {
	      $self->{DOCUMENT}->{Observation}->{ImageData}[$i]->{ObjectList}->{type} = "votable-url";
	   } else {
	      $self->{DOCUMENT}->{Observation}->{ImageData}[$i]->{ObjectList}->{type} = "unknown";
	   }   
        }
	
	# FITS Headers
        if( defined $hash{Catalogue} ) {
	   $self->{DOCUMENT}->{Observation}->{ImageData}[$i]->{FITSHeader}->{content} = $hash{Header};
	   $self->{DOCUMENT}->{Observation}->{ImageData}[$i]->{FITSHeader}->{type} = "all";
        }
		
     } # end of foreach loop
  } # end of if ( @_ ) block

  
}

sub headers {
}
sub imageuri {
}
sub catalogue {
}



    
# G E N E R A L ------------------------------------------------------------

=back

=head2 General Methods

=over 4

=item B<dump_buffer>

Dumps the contents of the RTML buffer in memory to a scalar,

   my $object = new XML::Document::RTML();
   $object->build( %hash );
   my $document = $object->dump_buffer();

If C<build( )> has not been called this function will return an undef.

=cut

sub dump_buffer {
  my $self = shift;
  
  if ( defined $self->{BUFFER} ){
     return $self->{BUFFER}->value();
  } else {
     return undef;
  }
}

sub dump_rtml {
  dump_buffer( @_ );
} 

sub buffer {
  dump_buffer( @_ );
}   

=item B<dump_tree>

Returns a refence to the parsed RTML document hash currently held in memory,

   my $object = new XML::Document::RTML( XML => $xml );
   my $hash_reference = $object->dump_tree();

should return an undefined value if that tree is empty. This error will occur 
if we haven't called C<build( )> to create a document, or populated the tree using 
the object creator by calling the XML or File methods to read in a document.

=cut

sub dump_tree {
  my $self = shift;
  
  if ( defined $self->{DOCUMENT} ){
     return $self->{DOCUMENT};
  } else {
     return undef;
  }
}

sub dump_hash {
  dump_tree( @_ );
}  

sub tree {
  dump_tree( @_ );
} 


# C O N F I G U R E ---------------------------------------------------------

=item B<configure>

Configures the object, takes an options hash as an argument

  $message->configure( %options );

Does nothing if the hash is not supplied. This is called directly from
the constructor during object creation

=cut


sub configure {
  my $self = shift;

  # BLESS XML WRITER
  # ----------------
  $self->{BUFFER} = new XML::Writer::String();  
  $self->{WRITER} = new XML::Writer( OUTPUT      => $self->{BUFFER},
                                     DATA_MODE   => 1, 
                                     DATA_INDENT => 4 );
				     
  # DEFAULTS
  # --------
  
  # use the RTML Namespace as defined by the v2.2 DTD
  $self->{DTD} = "http://www.estar.org.uk/documents/rtml2.2.dtd"; 
  
  $self->{DOCUMENT}->{IntelligentAgent}->{host} = "127.0.0.1";
  $self->{DOCUMENT}->{IntelligentAgent}->{port} = '8000';
  
  $self->{DOCUMENT}->{Observation}->{Target}->{Coordinates}->{Equinox} = 'J2000';
  
  $self->{DOCUMENT}->{Observation}->{Target}->{Coordinates}->{RightAscension}->{format} = 'hh mm ss.ss';
  $self->{DOCUMENT}->{Observation}->{Target}->{Coordinates}->{RightAscension}->{units} = 'hms';
  
  $self->{DOCUMENT}->{Observation}->{Target}->{Coordinates}->{Declination}->{format} = 'dd mm ss.ss';
  $self->{DOCUMENT}->{Observation}->{Target}->{Coordinates}->{Declination}->{units}  = 'dms';
  
  $self->{DOCUMENT}->{Observation}->{Target}->{type} = 'normal';
  $self->{DOCUMENT}->{Observation}->{Target}->{ident} = 'SingleExposure';
  
  $self->{DOCUMENT}->{Observation}->{Device}->{type} = 'camera';

  # CONFIGURE FROM ARGUEMENTS
  # -------------------------

  # return unless we have arguments
  return undef unless @_;

  # grab the argument list
  my %args = @_;
				        
  # Loop over the keys that mean we're parsing a document
  for my $key (qw / File XML / ) {
     if ( lc($key) eq "file" && exists $args{$key} ) { 
        $self->_parse( File => $args{$key} );
	last;
	
     } elsif ( lc($key) eq "xml"  && exists $args{$key} ) {
        $self->_parse( XML => $args{$key} );
	last;
	      
     }  
  }	
  
  # Loop over the rest of the keys
  for my $key (qw / / ) {
      my $method = lc($key);
      $self->$method( $args{$key} ) if exists $args{$key};
  }
  
  # Nothing to configure...
  return undef;

}


# P R I V A T E   M E T H O D S ------------------------------------------

sub _parse {
  my $self = shift;

  # return unless we have arguments
  return undef unless @_;

  # grab the argument list
  my %args = @_;

  my $xs = new XML::Simple( );

  # Loop over the allowed keys
  for my $key (qw / File XML / ) {
     if ( lc($key) eq "file" && exists $args{$key} ) { 
	$self->{DOCUMENT} = $xs->XMLin( $args{$key} );
	last;
	
     } elsif ( lc($key) eq "xml"  && exists $args{$key} ) {
	$self->{DOCUMENT} = $xs->XMLin( $args{$key} );
	last;
	
     }  
  }
  
  #print Dumper( $self->{DOCUMENT} );      
  return;
}

# L A S T  O R D E R S ------------------------------------------------------

1;                                                                  
