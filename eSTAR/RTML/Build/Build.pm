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
#     $Id: Build.pm,v 1.1 2002/03/14 23:21:32 aa Exp $

#  Copyright:
#     Copyright (C) 200s University of Exeter. All Rights Reserved.

#-

# ---------------------------------------------------------------------------

=head1 NAME

eSTAR::RTML::Build - module which creates valid RTML messages

=head1 SYNOPSIS

   $message = new eSTAR::RTML::Build(  );
 

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

'$Revision: 1.1 $ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# C O N S T R U C T O R ----------------------------------------------------

=head1 REVISION

$Id: Build.pm,v 1.1 2002/03/14 23:21:32 aa Exp $

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new instance from a hash of options

  $message = new eSTAR::RTML::Build(  );

returns a reference to an RTML object.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # bless the query hash into the class
  my $block = bless {  }, $class;

  # Configure the object
  $block->configure( @_ );

  return $block;

}

# M E T H O D S -------------------------------------------------------------

=back

=head2 Accessor Methods

=over 4

=item B<querydb>

Returns the RTML

   $rtml = $message->build();

=cut

sub build {
  my $self = shift;

}


# C O N F I G U R E -------------------------------------------------------

=back

=head2 General Methods

=over 4

=item B<configure>

Configures the object, takes an options hash as an argument

  $message->configure( %options );

Does nothing if the array is not supplied.

=cut

sub configure {
  my $self = shift;

  # CONFIGURE DEFAULTS
  # ------------------


  # CONFIGURE FROM ARGUEMENTS
  # -------------------------

  # return unless we have arguments
  return undef unless @_;

  # grab the argument list
  my %args = @_;

  # Loop over the allowed keys and modify the default query options
  for my $key (qw /  / ) {
      my $method = lc($key);
      $self->$method( $args{$key} ) if exists $args{$key};
  }

}

# T I M E   A T   T H E   B A R  --------------------------------------------

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
