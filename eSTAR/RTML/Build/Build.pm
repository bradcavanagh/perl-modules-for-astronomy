package eSTAR::RTML::Build;

# ---------------------------------------------------------------------------

#+ 
#  Name:
#    eSTAR::RTML::Build

#  Purposes:
#    Perl module to construct RTML messages

#  Language:
#    Perl module

#  Description:
#    This module creates outgoing RTML messages needed by the intelligent 
#    agent to communicate with the Discovery Node.

#  Authors:
#    Alasdair Allan (aa@astro.ex.ac.uk)

#  Revision:
#     $Id: Build.pm,v 1.2 2002/03/18 12:24:48 aa Exp $

#  Copyright:
#     Copyright (C) 200s University of Exeter. All Rights Reserved.

#-

# ---------------------------------------------------------------------------

=head1 NAME

eSTAR::RTML::Build - module which creates valid RTML messages

=head1 SYNOPSIS

   $message = new eSTAR::RTML::Build( Port => $port,
                                      ID   => $id );
 

=head1 DESCRIPTION

The module builds RTML messages which will be sent over GlobusIO from the
intelligent agent to the dscovery node. Two types of messages can be
constructed, these being score and observation request documents. 

=cut

# L O A D   M O D U L E S --------------------------------------------------

use strict;
use vars qw/ $VERSION /;

use Net::Domain qw(hostname hostdomain);
use File::Spec;
use Carp;

use XML::Writer;
use XML::Writer::String;

'$Revision: 1.2 $ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# C O N S T R U C T O R ----------------------------------------------------

=head1 REVISION

$Id: Build.pm,v 1.2 2002/03/18 12:24:48 aa Exp $

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new instance from a hash of options

  $message = new eSTAR::RTML::Build( Port => $port,
                                     ID   => $id );

returns a reference to an object.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # bless the query hash into the class
  my $block = bless { WRITER  => undef,
                      BUFFER  => undef,
                      OPTIONS => {} }, $class;

  # Configure the object
  $block->configure( @_ );

  return $block;

}

# M E T H O D S -------------------------------------------------------------

=back

=head2 RTML Methods

=over 4

=item B<score_observation>

Build a score document

   $status = $message->score_observation();

=cut

sub score_observation {
  my $self = shift;

  # grab the argument list
  my %args = @_;

  # Loop over the allowed keys and modify the default query options
  for my $key (qw / Target RA Dec Equinox / ) {
      my $method = lc($key);
      $self->$method( $args{$key} ) if exists $args{$key};
  }
  
  # open the document
  $self->{WRITER}->xmlDecl( 'US-ASCII' );
  $self->{WRITER}->doctype( 'RTML', '', ${$self->{OPTIONS}}{DTD} );
 
  # open the RTML document
  # ======================
  $self->{WRITER}->startTag( 'RTML',
                             'version' => '2.1',
                             'type' => 'score' );
  
  # IntelligentAgent Tag
  # --------------------
  
  # grab the fully resolved hostname
  my $hostname = ${$self->{OPTIONS}}{HOST} . "." . 
                 ${$self->{OPTIONS}}{DOMAIN};
  
  # identify the IA               
  $self->{WRITER}->startTag( 'IntelligentAgent', 
                             'host' => $hostname,
                             'port' =>  ${$self->{OPTIONS}}{PORT} ); 
  
  # unique IA identity sting
  $self->{WRITER}->characters( ${$self->{OPTIONS}}{ID} );
  
  $self->{WRITER}->endTag( 'IntelligentAgent' );
  
  # Contact Tag
  # -----------
  $self->{WRITER}->startTag( 'Contact', 'PI' => 'true' );
                             
     $self->{WRITER}->startTag( 'User');                          
     $self->{WRITER}->characters( ${$self->{OPTIONS}}{USER} );
     $self->{WRITER}->endTag( 'User' );
  
     $self->{WRITER}->startTag( 'Name');                          
     $self->{WRITER}->characters( ${$self->{OPTIONS}}{NAME} );
     $self->{WRITER}->endTag( 'Name' );  
      
     $self->{WRITER}->startTag( 'Institution');                          
     $self->{WRITER}->characters( ${$self->{OPTIONS}}{INSTITUTION} );
     $self->{WRITER}->endTag( 'Institution' ); 
      
     $self->{WRITER}->startTag( 'Email');                          
     $self->{WRITER}->characters( ${$self->{OPTIONS}}{EMAIL} );
     $self->{WRITER}->endTag( 'Email' ); 

  $self->{WRITER}->endTag( 'Contact' ); 
  
  # Observation tag
  # ---------------
  $self->{WRITER}->startTag( 'Observation', 'status' => 'ok' );  
  
     $self->{WRITER}->startTag( 'Target', 'type' => 'normal' );
    
        $self->{WRITER}->startTag( 'TargetName' );
        $self->{WRITER}->characters( ${$self->{OPTIONS}}{TARGET} );
        $self->{WRITER}->endTag( 'TargetName' );

        $self->{WRITER}->startTag( 'Coordinates', 'type' => 'equatorial' );
        
           $self->{WRITER}->startTag( 'RightAscension', 
                                    'format' => 'hh mm ss.s', units => 'hms' );
           $self->{WRITER}->characters( ${$self->{OPTIONS}}{RA} );
           $self->{WRITER}->endTag( 'RightAscension' );
           
           $self->{WRITER}->startTag( 'Declination', 
                                    'format' => 'sdd mm ss.s', units => 'dms' );
           $self->{WRITER}->characters( ${$self->{OPTIONS}}{DEC} );
           $self->{WRITER}->endTag( 'Declination' );   

           $self->{WRITER}->startTag( 'Equinox'  );
           $self->{WRITER}->characters( ${$self->{OPTIONS}}{EQUINOX} );
           $self->{WRITER}->endTag( 'Equinox' );

        $self->{WRITER}->endTag( 'Coordinates' );
                               
           
     $self->{WRITER}->endTag( 'Target' );

  $self->{WRITER}->endTag( 'Observation' );  
     
    
  # close the RTML document
  # =======================
  $self->{WRITER}->endTag( 'RTML' );
  $self->{WRITER}->end();

  # return a good status (GLOBUS_TRUE)
  return 1;

}

=item B<dump_rtml>

Dumps the contents of the RTML buffer in memory to a scalar

   $string = $message->dump_rtml();

=cut

sub dump_rtml {
  my $self = shift;
  return $self->{BUFFER}->value();

}

# A C C E S S O R   M  E T H O D S ------------------------------------------ 
=back

=head2 Accessor Methods

=over 4

=item B<port>

Sets (or returns) the port which the Discovey Node should send RTML 
messages to

   $message->port( '2000' );
   $port = $message->port();

defautls to 2220.

=cut

sub port {
  my $self = shift;

  if (@_) {
    ${$self->{OPTIONS}}{PORT} = shift;
  }

  # return the current port
  return ${$self->{OPTIONS}}{PORT};
}   

=item B<id>

Sets (or returns) the unique ID for the Intelligent Agent request

   $message->id( 'IATEST0001:CT1:0013' );
   $id = $message->id();

note that there is NO DEFAULT, a unique ID for the score/observing 
request must be supplied, see the eSTAR Communications and the ERS 
command set documents for further details.

=cut

sub id {
  my $self = shift;

  if (@_) {
    ${$self->{OPTIONS}}{ID} = shift;
  }

  # return the current ID
  return ${$self->{OPTIONS}}{ID};
} 
 
=item B<user>

Sets (or returns) the user name of the observer

   $message->user( 'aa' );
   $user = $message->user();

=cut

sub user {
  my $self = shift;

  if (@_) {
    ${$self->{OPTIONS}}{USER} = shift;
  }

  # return the current ID
  return ${$self->{OPTIONS}}{USER};
}  
 
=item B<name>

Sets (or returns) the name of the observer

   $message->name( 'Alasdair Allan' );
   $name = $message->name();

=cut

sub name {
  my $self = shift;

  if (@_) {
    ${$self->{OPTIONS}}{NAME} = shift;
  }

  # return the current ID
  return ${$self->{OPTIONS}}{NAME};
}  
 
=item B<institution>

Sets (or returns) the Institution of the observer

   $message->institution( 'University of Exeter' );
   $dept_name = $message->institution();

=cut

sub institution {
  my $self = shift;

  if (@_) {
    ${$self->{OPTIONS}}{INSTITUTION} = shift;
  }

  # return the current ID
  return ${$self->{OPTIONS}}{INSTITUTION};
}  
 
=item B<email>

Sets (or returns) the email address of the observer

   $message->email( 'aa@astro.ex.ac.uk' );
   $email_address = $message->email();

=cut

sub email {
  my $self = shift;

  if (@_) {
    ${$self->{OPTIONS}}{EMAIL} = shift;
  }

  # return the current ID
  return ${$self->{OPTIONS}}{EMAIL};
}  
 
=item B<target>

Sets (or returns) the target name

   $message->email( 'EX Hya' );
   $target_name = $message->target();

=cut

sub target {
  my $self = shift;

  if (@_) {
    ${$self->{OPTIONS}}{TARGET} = shift;
  }

  # return the current target ID
  return ${$self->{OPTIONS}}{TARGET};
}  

 
=item B<ra>

Sets (or returns) the target RA

   $message->ra( '12 35 65.0' );
   $ra = $message->ra();

must be in the form HH MM SS.S.

=cut

sub ra {
  my $self = shift;

  if (@_) {
    ${$self->{OPTIONS}}{RA} = shift;
  }

  # return the current target RA
  return ${$self->{OPTIONS}}{RA};
}  
 
=item B<dec>

Sets (or returns) the target DEC

   $message->dec( '+60 35 32' );
   $dec = $message->dec();

must be in the form SDD MM SS.S.

=cut

sub dec {
  my $self = shift;

  if (@_) {
    ${$self->{OPTIONS}}{DEC} = shift;
  }

  # return the current target DEC
  return ${$self->{OPTIONS}}{DEC};
}  

=item B<equinox>

Sets (or returns) the equinox of the target co-ordinates

   $message->equinox( 'B1950' );
   $equnox = $message->equinox();

default is J2000, currently the telescope expects J2000.0 coordinates, no
translation is currently carried out by the library before formatting the
RTML message. It is therefore suggested that the user therefoer provides 
their coordinates in J2000.0 as this is merely a placeholder routine.

=cut

sub equinox {
  my $self = shift;

  if (@_) {
    ${$self->{OPTIONS}}{EQUINOX} = shift;
  }

  # return the current co-ord equinox
  return ${$self->{OPTIONS}}{EQUINOX};
}  


# C O N F I G U R E -------------------------------------------------------

=back

=head2 General Methods

=over 4

=item B<configure>

Configures the object, takes an options hash as an argument

  $message->configure( %options );

does nothing if the hash is not supplied.

=cut

sub configure {
  my $self = shift;

  # Create the RTML::Writer object
  # ------------------
  $self->{BUFFER} = new XML::Writer::String();
  $self->{WRITER} = new XML::Writer( OUTPUT      => $self->{BUFFER},
                                     DATA_MODE   => 1, 
                                     DATA_INDENT => 4 );
  
  # DEFAULTS
  # --------
  
  # use the RTML Namespace as defined by the v2.1 DTD
  ${$self->{OPTIONS}}{DTD} = "http://www.astro.livjm.ac.uk/HaGS/rtml2.1.dtd"; 
  ${$self->{OPTIONS}}{HOST} = hostname();
  ${$self->{OPTIONS}}{DOMAIN} = hostdomain(); 
  ${$self->{OPTIONS}}{PORT} = '2220';
  
  ${$self->{OPTIONS}}{EQUINOX} = 'J2000';
  
    
  # ARGUEMENTS
  # ----------

  # return unless we have arguments
  return undef unless @_;

  # grab the argument list
  my %args = @_;

  # Loop over the allowed keys and modify the default query options
  for my $key (qw / Port ID User Name Institution Email / ) {
      my $method = lc($key);
      $self->$method( $args{$key} ) if exists $args{$key};
  }

}

# T I M E   A T   T H E   B A R  --------------------------------------------

=back

=head1 COPYRIGHT

Copyright (C) 2002 University of Exeter. All Rights Reserved.

This program was written as part of the eSTAR project and is free software;
you can redistribute it and/or modify it under the terms of the GNU Public
License.

=head1 AUTHORS

Alasdair Allan E<lt>aa@astro.ex.ac.ukE<gt>,

=cut

# L A S T  O R D E R S ------------------------------------------------------

1;                                                                  
