package eSTAR::Database::Manip;

=head1 NAME

eSTAR::Database::Manip - eSTAR object database manipulation

=head1 SYNOPSIS

  use eSTAR::Database::Manip;

  $db = new eSTAR::Database::Manip( DB => new eSTAR::Database::DBbackend );

  $db->add_catalog( $catalog );
  $catalog = $db->cone_search( coords => $coords,
                               radius => $radius,
                               date_range => $range );

  $catalog = $db->queryDB( $query );

=head1 DESCRIPTION

=cut

use 5.006;
use warnings;
use strict;

use Carp;

use eSTAR::Database::Query;

use Astro::Catalog;
use Astro::Catalog::Item::Morphology;
use Astro::HTM::Functions;
use DateTime::Format::Strptime;
use Data::Dumper;

use base qw/ eSTAR::Database::BaseDB /;

our $VERSION = '0.01';
our $OBJECTTABLE = 'tblObject';
our $MEASUREMENTTABLE = 'tblMeasurement';
our $OBSERVATIONTABLE = 'tblObservation';
our $MEASOBSJOINTABLE = 'tblMeasObs';
my $RAD_TO_DEG = 180 / ( atan2( 1, 1 ) * 4 );

our %primary_keys = ( $OBJECTTABLE => 'pklngObjectID',
                      $MEASUREMENTTABLE => 'pklngMeasurementID',
                      $OBSERVATIONTABLE => 'pklngObservationID',
                      $MEASOBSJOINTABLE => 'pklngMeasObsID',
                    );

our %flux_map = ( CORE1_FLUX => 'CORE_FLUX_1',
                  CORE2_FLUX => 'CORE_FLUX_2',
                  CORE3_FLUX => 'CORE_FLUX_3',
                  CORE4_FLUX => 'CORE_FLUX_4',
                  CORE5_FLUX => 'CORE_FLUX_5',
                );

our %flag_lookup = ( 'estar_variable' => 'a',
                     'estar_new' => 'b',
                     'simbad_variable' => 'c',
                     'simbad_ident' => 'd',
                   );

=head1 METHODS

=head2 Public Methods

=over 4

=item B<add_catalog>

Adds a catalog to the database.

  $db->add_catalog( $catalog );

The supplied parameter is an C<Astro::Catalog> object.

=cut

sub add_catalog {
  my $self = shift;

  my $catalog = shift;

  # Make sure our catalog is okay.
  if( ! defined( $catalog ) ) {
    print "catalog not defined\n";
    return;
  }
  if( ! UNIVERSAL::isa( $catalog, "Astro::Catalog" ) ) {
    croak "Argument to eSTAR::Database::Manip->add_catalog() must be an Astro::Catalog object";
  }

  # Lock the database (since we are writing)
  $self->_db_begin_trans;
  $self->_dblock;

  # Write the catalog to database.
  $self->_store_catalog( $catalog );

  # End the transaction.
  $self->_dbunlock;
  $self->_db_commit_trans;
}

=item B<cone_search>

Retrieve all objects within a given radius of a given RA and Dec.

  $catalog = $db->cone_search( $coords, $radius,
                               date_range => $date_range,
                               waveband => $waveband );

This method takes two mandatory parameters. The first must be an
C<Astro::Coords> object denoting the centre of the cone search, and
the second must be the search radius in arcseconds.

The first optional named parameter is a date range that, if defined,
must be a C<DateTime::Span> object. The second optional named parameter
is a waveband that, if defined, must be a C<Astro::WaveBand> object.

This method returns an C<Astro::Catalog> object.

=cut

sub cone_search {
  my $self = shift;

  # Deal with arguments.
  my $coords = shift;
  if( ! defined( $coords ) ||
      ! UNIVERSAL::isa( $coords, "Astro::Coords" ) ) {
    croak "coords parameter to eSTAR::Database::Manip->cone_search must be defined as an Astro::Coords object";
  }

  my $radius = shift;
  if( ! defined( $radius ) ) {
    croak "radius parameter to eSTAR::Database::Manip->cone_search must be defined in arcseconds";
  }

  # Deal with the rest of the arguments.
  my %args = @_;
  if( defined( $args{'date_range'} ) &&
      ! UNIVERSAL::isa( $args{'date_range'}, "DateTime::Span" ) ) {
    croak "date_range parameter to eSTAR::Database::Manip->cone_search must be a DateTime::Span object";
  }
  my $date_range = $args{'date_range'};

  if( defined( $args{'waveband'} ) &&
      ! UNIVERSAL::isa( $args{'waveband'}, "Astro::WaveBand" ) ) {
    croak "waveband parameter to eSTAR::Database::Manip->cone_search must be a WaveBand object";
  }
  my $waveband = $args{'waveband'};

  my $catalog = $self->_retrieve_catalog( $coords, $radius, date_range => $date_range, waveband => $waveband );

  return $catalog;
}


=item B<queryDB>

Query the database using the supplied query (supplied as a
C<eSTAR::Database::Query> object). Results are returned as
an C<Astro::Catalog> object.

  $catalog = $db->queryDB( $query, $with_flux );

The second optional argument tells the method whether or
not to return flux measurements along with the objects.
Defaults to true (i.e. flux measurements are returned).

=cut

sub queryDB {
  my $self = shift;
  my $query = shift;
  my $with_flux = shift;

  if( ! defined( $with_flux ) ) {
    $with_flux = 1;
  }

  # Get the SQL.
  my $sql = $query->sql( $with_flux );

  # Use this SQL to query the database, returning the results
  # in an array reference.
  my $ref = $self->_db_retrieve_data_ashash( $sql );

  # Convert the data to an Astro::Catalog object.
  my $catalog = $self->_reorganize_results( $ref, $with_flux );

  # And return the catalog.
  return $catalog;
}

=item B<update_flags>

Update a C<Astro::Catalog::Item>'s flags in the database.

  $db->update_flags( $item, \@flags );

This method takes two mandatory arguments, the first being the
C<Astro::Catalog::Item> object to be updated, and the second being
an array reference to a list of strings.

If the given item does not exist in the database, nothing will
happen.

=cut

sub update_flags {
  my $self = shift;

  # Handle arguments.
  my $item = shift;
  if( ! defined( $item ) ||
      ! UNIVERSAL::isa( $item, "Astro::Catalog::Item" ) ) {
    croak "item parameter to eSTAR::Database::Manip->update_flags must be an Astro::Catalog::Item object";
  }

  my $flag_ref = shift;
  if( ! defined( $flag_ref ) ||
      ref( $flag_ref ) ne 'ARRAY' ) {
    croak "flags parameter to eSTAR::Database::Manip->update_flags must be an array reference";
  }

  # Retrieve the item's ID.
  my $db_item = $self->_retrieve_item( $item->coords, 5 );
  if( ! defined( $db_item ) ) {
    return;
  }

  my $id = $db_item->id;
  my $clause = $primary_keys{$OBJECTTABLE} . "=$id";
  my $value = join '', map { $flag_lookup{lc($_)}; } @$flag_ref;
  my $hash_ref = {};
  $hash_ref->{'flag'} = $value;

  # Lock the database (since we are writing)
  $self->_db_begin_trans;
  $self->_dblock;

  # Do the update.
  $self->_db_update_data( $OBJECTTABLE, $hash_ref, $clause );

  # End the transaction.
  $self->_dbunlock;
  $self->_db_commit_trans;

}

=item B<_add_item>

Add an C<Astro::Catalog::Item> object to the database.

  $db->_add_item( $item );

The sole argument is mandatory and must be an
C<Astro::Catalog::Item> object.

If this item exists in the database (meaning there is another object
within one arcsecond of this item's position), then the flux measurements
will be added to this item's light curve. Otherwise, a new object
is added to the database.

=cut

sub _add_item {
  my $self = shift;

  my $item = shift;
  if( ! defined( $item ) ||
      ! UNIVERSAL::isa( $item, "Astro::Catalog::Item" ) ) {
    croak "Item parameter to eSTAR::Database::Manip->_add_item must be defined as an Astro::Catalog::Item object, not " . ref( $item ) . "\n";
  }

  # Find an item that's within one arcsecond of the item we're
  # looking for.
  my $radius = 1;

  my $ret_item = $self->_retrieve_item( $item->coords, $radius );

  my $item_key;
  if( defined( $ret_item ) ) {
    $item_key = $ret_item->id;
  } else {
    $item_key = $self->_retrieve_next_key( $OBJECTTABLE,
                                           $primary_keys{$OBJECTTABLE} );
    $self->_insert_item( $item, $item_key );
  }

  foreach my $fluxes ( $item->fluxes ) {

    # $fluxes is an Astro::Fluxes object. We want the Astro::Flux objects
    # that originally went into it.

    my %fluxes;
    foreach my $flux ( $fluxes->allfluxes ) {
      if( lc($flux->type) eq 'isophotal_flux' ) {
        $fluxes{'iso_flux'} = $flux;
      } elsif( lc($flux->type) eq 'total_flux' ) {
        $fluxes{'total_flux'} = $flux;
      } elsif( lc($flux->type) eq 'core_flux' ) {
        $fluxes{'core_flux'} = $flux;
      } elsif( lc($flux->type) eq 'core1_flux' ) {
        $fluxes{'core1_flux'} = $flux;
      } elsif( lc($flux->type) eq 'core2_flux' ) {
        $fluxes{'core2_flux'} = $flux;
      } elsif( lc($flux->type) eq 'core3_flux' ) {
        $fluxes{'core3_flux'} = $flux;
      } elsif( lc($flux->type) eq 'core4_flux' ) {
        $fluxes{'core4_flux'} = $flux;
      } elsif( lc($flux->type) eq 'core5_flux' ) {
        $fluxes{'core5_flux'} = $flux;
      }
    }

    my %obsid_hash = (); # A list of all of the obsid IDs we've added
                         # to the database.
    $fluxes{'iso_flux'}->obsid( [ "w20050528_00001.sdf" ] );
    if( ! defined( $fluxes{'iso_flux'}->obsid ) ) {
      croak "Flux measurement does not have any obsid values";
    }

    foreach my $obsid ( @{$fluxes{'iso_flux'}->obsid} ) {

      # Check to see if this obsid already exists in the DB. If it
      # does, then keep its key around for future use. If it doesn't,
      # generate its key and insert it in the database.
      my $obsid_key = $self->_retrieve_obsid_key( $obsid );
      if( $obsid_key != 0 ) {
        $obsid_hash{$obsid_key}++;
      } else {
        $obsid_key = $self->_retrieve_next_key( $OBSERVATIONTABLE,
                                                $primary_keys{$OBSERVATIONTABLE} );
        $self->_insert_obsid( $obsid, $obsid_key );
        $obsid_hash{$obsid_key}++;
      }
    } # All done with the obsids.

    # Retrieve the next flux ID, then insert the current flux
    # with that ID into the database, and keep the ID around
    # for future use.
    my $flux_key = $self->_retrieve_next_key( $MEASUREMENTTABLE,
                                              $primary_keys{$MEASUREMENTTABLE} );
    $self->_insert_flux( \%fluxes, $flux_key, $item_key );

    # Now let's link them up.
    foreach my $obsid_key ( keys %obsid_hash ) {

      $self->_insert_measobs( $flux_key, $obsid_key );
    }
  } # Done with this Astro::Fluxes object.

}

=item B<_get_HTM_ranges>

Given central coordinates and a search radius, return a list of ranges of
HTM ids that define the region.

  my @ranges = $db->_get_HTM_ranges( $coords, $radius );

The two parameters are mandatory. The first must be an Astro::Coords object
that defines the central position, and the second must be the search radius
in arcseconds.

This method returns a list of Number::Interval objects.

This method will probably not work properly for a search radius larger than
140 arcseconds.

=cut

sub _get_HTM_ranges {
  my $self = shift;

  my $coords = shift;
  if( ! defined( $coords ) ||
      ! UNIVERSAL::isa( $coords, "Astro::Coords" ) ) {
    croak "coords parameter to eSTAR::Database::Manip->_get_HTM_ranges must be an Astro::Coords object";
  }

  my $radius = shift;
  if( ! defined( $radius ) ) {
    croak "radius paramter to eSTAR::Database::Manip->_get_HTM_ranges must be defined in arcseconds";
  }
  my $radius_deg = $radius / 3600;

  # First, get a list of all of the HTM IDs we need to search for.
  # This will be done by retrieving the HTM ID for twelve points
  # along the circle centred by the central coordinates.
  my %htmids;
  my $steps = 6;
  my $level;
  my $length = 2.5 * $radius;
  if( $length > 178 ) {
    $level = 10;
  } elsif( $length > 89 ) {
    $level = 11;
  } elsif( $length > 45 ) {
    $level = 12;
  } elsif( $length > 22.3 ) {
    $level = 13;
  } elsif( $length > 11.2 ) {
    $level = 14;
  } elsif( $length > 5.58 ) {
    $level = 15;
  } elsif( $length > 2.79 ) {
    $level = 16;
  } elsif( $length > 1.39 ) {
    $level = 17;
  } elsif( $length > 0.697 ) {
    $level = 18;
  } elsif( $length > 0.348 ) {
    $level = 19;
  } else {
    $level = 20;
  }
  my ( $ra, $dec ) = $coords->radec();
  $ra = $ra->degrees;
  $dec = $dec->degrees;

  # First, get the central.
  my $htmid = Astro::HTM::Functions->lookup_radec( $ra, $dec, $level );
  $htmids{$htmid}++;

  # Now go around the circle.
  for( 0..($steps-1) ) {
    my $angle = $_ * 360 / ( 2 * 3.14159265359 ) / $steps;
    my $newra = $ra + $radius_deg * sin( $angle );
    my $newdec = $dec + $radius_deg * cos( $angle );

    my $newhtmid = Astro::HTM::Functions->lookup_radec( $newra, $newdec, $level );
    $htmids{$newhtmid}++;
  }

  # Now convert these HTMIDs, creating level 20 ranges and removing
  # the N and S and replacing them with nothing and -, respectively.
  my @ranges;
  foreach my $htmid ( keys %htmids ) {
    my $low = $htmid . ( 0 x ( 22 - length( $htmid ) ) );
    my $high = $htmid . ( 3 x ( 22 - length( $htmid ) ) );
    $low =~ s/N//;
    $low =~ s/S/-/;
    $high =~ s/N//;
    $high =~ s/S/-/;
    push @ranges, new Number::Interval( Min => $low, Max => $high );
  }

  return @ranges;
}

=item B<_insert_flux>

Insert flux measurements for a given object and epoch into the database.

  $db->_insert_flux( $fluxes, $flux_key, $item_key );

This method takes three mandatory arguments: The first is a reference to a
hash whose keys are 'isophotal_flux', 'core1_flux', 'core2_flux', 'core3_flux',
'core4_flux', and 'core5_flux' and whose values are C<Astro::Flux> objects,
the primary key for the list of flux measurements, and the primary key of
the related C<Astro::Catalog::Item> object.

The epoch of observation is taken from the C<Astro::Flux> object pointed to
by the 'isophotal_flux' key, as is the waveband.

=cut

sub _insert_flux {
  my $self = shift;

  my $fluxes = shift;
  if( ! defined( $fluxes ) ) {
    croak "Must supply flux object to eSTAR::Database::Manip->_insert_flux() as an Astro::Flux object";
  }

  my $flux_key = shift;
  if( ! defined( $flux_key ) ) {
    croak "Must supply flux primary key to eSTAR::Database::Manip->_insert_flux()";
  }

  my $item_key = shift;
  if( ! defined( $item_key ) ) {
    croak "Must supply item primary key to eSTAR::Database::Manip->_insert_flux()";
  }

  my $date = $fluxes->{'iso_flux'}->datetime;
  my $fluxdate;
  if( defined( $date ) ) {
    $fluxdate = $date->strftime("%Y%m%d %T");
  } else {
    my $current = DateTime->now;
    $fluxdate = $current->strftime("%Y%m%d %T");
  }

  my $waveband;
  if( ! defined( $fluxes->{'iso_flux'} ) ) {
    $waveband = 'unknown';
  } else {
    $waveband = $fluxes->{'iso_flux'}->waveband->natural;
  }

  # Insert the data into the table. The columns are:
  # - primary key (integer)
  # - item foreign key (integer)
  # - waveband (varchar(32))
  # - core_flux_1 (float)
  # - core_flux_1_error (float)
  # - core_flux_2 (float)
  # - core_flux_2_error (float)
  # - core_flux_3 (float)
  # - core_flux_3_error (float)
  # - core_flux_4 (float)
  # - core_flux_4_error (float)
  # - core_flux_5 (float)
  # - core_flux_5_error (float)
  # - isophotal_flux (float)
  # - isophotal_flux_error (float)
  # - total_flux (float)
  # - total_flux_error (float)
  # - peak_height (float)
  # - peak_height_error (float)
  # - sky_level (float)
  # - sky_level_error (float)
  # - extraction_flags (binary(32))
  # - datetime (datetime)
  $self->_db_insert_data( $MEASUREMENTTABLE,
                          $flux_key,
                          $item_key,
                          $waveband,
                          ( defined( $fluxes->{'core1_flux'} ) ? $fluxes->{'core1_flux'}->quantity('core1_flux') : undef ),
                          undef,
                          ( defined( $fluxes->{'core2_flux'} ) ? $fluxes->{'core2_flux'}->quantity('core2_flux') : undef ),
                          undef,
                          ( defined( $fluxes->{'core3_flux'} ) ? $fluxes->{'core3_flux'}->quantity('core3_flux') : undef ),
                          undef,
                          ( defined( $fluxes->{'core4_flux'} ) ? $fluxes->{'core4_flux'}->quantity('core4_flux') : undef ),
                          undef,
                          ( defined( $fluxes->{'core5_flux'} ) ? $fluxes->{'core5_flux'}->quantity('core5_flux') : undef ),
                          undef,
                          ( defined( $fluxes->{'iso_flux'} ) ? $fluxes->{'iso_flux'}->quantity('isophotal_flux') : undef ),
                          undef,
                          ( defined( $fluxes->{'total_flux'} ) ? $fluxes->{'total_flux'}->quantity('total_flux') : undef ),
                          undef,
                          undef,
                          undef,
                          undef,
                          undef,
                          undef,
                          $fluxdate );

}

=item B<_insert_measobs>

Insert a record to the join table joining measurements to
observations.

  $db->_insert_measobs( $meas_key, $obsid_key );

This method takes two mandatory arguments, the primary key of the
measurement record and the primary key of the observation.

=cut

sub _insert_measobs {
  my $self = shift;

  my $meas_key = shift;
  if( ! defined( $meas_key ) ) {
    croak "Must supply measurement primary key to eSTAR::Database::Manip->_insert_measobs()";
  }

  my $obsid_key = shift;
  if( ! defined( $obsid_key ) ) {
    croak "Must supply obsid primary key to eSTAR::Database::Manip->_insert_measobs()";
  }

  $self->_db_insert_data( $MEASOBSJOINTABLE,
                          $meas_key,
                          $obsid_key );
}

=item B<_insert_item>

Insert an C<Astro::Catalog::Item> object into the database.

  $db->_insert_item( $item, $item_key );

This method takes two mandatory arguments, the C<Astro::Catalog::Item>
object to insert and that item's primary key.

=cut

sub _insert_item {
  my $self = shift;

  my $item = shift;
  if( ! defined( $item ) ||
      ! UNIVERSAL::isa( $item, "Astro::Catalog::Item" ) ) {
    croak "Must supply item object to eSTAR::Database::Manip->_insert_item() as an Astro::Catalog::Item object";
  }

  my $item_key = shift;
  if( ! defined( $item_key ) ) {
    croak "Must supply item primary key to eSTAR::Database::Manip->_insert_item()";
  }

  my ( $ra, $dec ) = $item->coords->radec();
  my $ra_deg = $ra->degrees;
  my $dec_deg = $dec->degrees;
  my $htmid = Astro::HTM::Functions->lookup_radec( $ra_deg, $dec_deg, 20 );
  $htmid =~ s/N//;
  $htmid =~ s/S/-/;
  my $morphology = $item->morphology;

  $self->_db_insert_data( $OBJECTTABLE,
                          $item_key,
                          $ra->radians,
                          $dec->radians,
                          $htmid,
                          $morphology->ellipticity,
                          undef,
                          $morphology->position_angle_world,
                          undef,
                          undef,
                          undef,
                          $item->quality );

}

=item B<_insert_obsid>

Insert an obsid into the database.

  $db->_insert_obsid( $obsid, $key );

This method takes two mandatory arguments, the obsid and its primary
key.

=cut

sub _insert_obsid {
  my $self = shift;

  my $obsid = shift;
  if( ! defined( $obsid ) ) {
    croak "Must supply obsid to eSTAR::Database::Manip->_insert_obsid()";
  }

  my $obsid_key = shift;
  if( ! defined( $obsid_key ) ) {
    croak "Must supply obsid primary key to eSTAR::Database::Manip->_insert_obsid()";
  }

  $self->_db_insert_data( $OBSERVATIONTABLE,
                          $obsid_key,
                          $obsid );

}

=item B<_retrieve_catalog>

Retrieve an C<Astro::Catalog> object from the database.

  my $catalog = $db->_retrieve_catalog( $coords, $radius,
                                        date_range => $date_range,
                                        waveband => $waveband );

This method takes two mandatory arguments. The first must be an
C<Astro::Coords> object denoting the centre of the search, and the
second is a radius in arcseconds.

This method takes two optional named arguments. If the date_range
argument is defined, it must be a C<DateTime::Span> object. If the
waveband argument is defined, it must be an C<Astro::WaveBand>
object.

This method returns an C<Astro::Catalog> object.

=cut

sub _retrieve_catalog {
  my $self = shift;

  my $coords = shift;
  if( ! defined( $coords ) ||
      ! UNIVERSAL::isa( $coords, "Astro::Coords" ) ) {
    croak "Coords parameter to eSTAR::Database::Manip->_retrieve_catalog must be defined as an Astro::Coords object";
  }

  my $radius = shift;
  if( ! defined( $radius ) ) {
    croak "Radius parameter to eSTAR::Database::Manip->_retrieve_catalog must be defined in arcseconds";
  }

  # Deal with optional arguments.
  my %args = @_;

  if( defined( $args{'date_range'} ) &&
      ! UNIVERSAL::isa( $args{'date_range'}, "DateTime::Span" ) ) {
    croak "Date range parameter to eSTAR::Database::Manip->_retrieve_catalog must be a DateTime::Span object";
  }
  my $date_range = $args{'date_range'};

  if( defined( $args{'waveband'} ) &&
      ! UNIVERSAL::isa( $args{'waveband'}, "Astro::WaveBand" ) ) {
    croak "waveband parameter to eSTAR::Database::Manip->_retrieve_catalog must be an Astro::WaveBand object";
  }
  my $waveband = $args{'waveband'};

  my $with_flux;
  if( defined( $args{'with_flux'} ) ) {
    $with_flux = $args{'with_flux'};
  } else {
    $with_flux = 1;
  }

  my $radius_deg = $radius / 3600;

  # First, get a list of all of the HTM IDs we need to search for.
  my @ranges = $self->_get_HTM_ranges( $coords, $radius );

  # There, now we've got our HTMID ranges to search over. Now we just
  # need to query the DB for items that fall within these ranges.

  # Set up the XML.
  my $xml = "<Query>\n";
  $xml .= ( join "\n", map { "<HTMid><min>" . $_->min . "</min><max>" . $_->max . "</max></HTMid>"; } @ranges );
  if( defined( $date_range ) ) {
    $xml .= "<date><min>" . $date_range->min . "</min><max>" . $date_range->max . "</max></date>";
  }
  if( defined( $waveband ) ) {
    $xml .= "<waveband>" . $waveband->natural . "</waveband>";
  }
  $xml .= "\n</Query>\n";

  # Set up the query.
  my $query = new eSTAR::Database::Query( XML => $xml );

  # Fire it off to queryDB.
  my $catalog = $self->queryDB( $query, $with_flux );

  # Slam the central coordinates into the catalog object.
  $catalog->set_coords( $coords );

  # And the radius.
  $catalog->set_radius( $radius / 60 ); # It's needed in arcminutes, but we have it in arcseconds.

  # And return the catalog.
  return $catalog;

}

=item B<_retrieve_item>

Retrieve an C<Astro::Catalog::Item> object from the database.

  $item = $db->_retrieve_item( $coords, $radius );

This method takes two mandatory arguments. The first must be an
C<Astro::Coords> object denoting the centre of the search, and the
second is a radius in arcseconds.

This method returns one C<Astro::Catalog::Item> object, and will
be the one closest to the centre of the search if multiple items
happen to fall within the search radius.

=cut

sub _retrieve_item {
  my $self = shift;

  my $coords = shift;
  if( ! defined( $coords ) ||
      ! UNIVERSAL::isa( $coords, "Astro::Coords" ) ) {
    croak "Coords parameter to eSTAR::Database::Manip->_retrieve_item must be defined as an Astro::Coords object";
  }

  my $radius = shift;
  if( ! defined( $radius ) ) {
    croak "Radius parameter to eSTAR::Database::Manip->_retrieve_item must be defined in arcseconds";
  }

  # Get a catalog.
  my $catalog = $self->_retrieve_catalog( $coords, $radius,
                                          with_flux => 0 );

  # If the DB doesn't return anything, return undef.
  if( ! defined( $catalog ) ) {
    return undef;
  }

  # Sort the catalog.
  $catalog->sort_catalog( "distance" );

  # Pop off the first Astro::Catalog::Item object.
  my @stars = $catalog->stars();
  my $item = $stars[0];
  if( ! defined( $item ) ) {
    return undef;
  } else {

    # Check the distance.
    my $distance = $item->coords->distance( $catalog->get_coords );
    if( $distance->arcsec <= $radius ) {
      return $item;
    } else {
      return undef;
    }
  }

  # And return that object (even though we can't actually get here...)
  return $item;
}

=item B<_retrieve_next_key>

Returns the next available primary key for a given table.

  my $key = $db->_retrieve_next_key( $table );

Assumes that keys are integers and increment monotonically.

=cut

sub _retrieve_next_key {
  my $self = shift;

  my $table = shift;

  my $max = $self->_db_findmax( $table, $primary_keys{$table} );
  $max++;

  return $max;
}

=item B<_retrieve_obsid_key>

Returns the obsid's primary key if it exists in the database.

  my $key = $db->_retrieve_obsid_key( $obsid );

If the obsid doesn't exist in the database, this method returns
0.

=cut

sub _retrieve_obsid_key {
  my $self = shift;

  my $obsid = shift;
  if( ! defined( $obsid ) ) {
    return 0;
  }

  my $sql = "SELECT pklngObservationID FROM tblObservation where observation_id = '$obsid'";

  my $dbh = $self->_dbhandle;
  croak "Database handle not valid" unless defined $dbh;

  my $sth = $dbh->prepare( $sql )
    or croak "Error preparing max SQL statment";

  $sth->execute
    or croak "DB Error executing max SQL: $DBI::errstr";

  my $key = ($sth->fetchrow_array)[0];

  return ( defined $key ? $key : 0 );
}

=item B<_reorganize_results>

Given the results from a database query (returned as a row
per flux measurement per object), convert this output to an
C<Astro::Catalog> object.

  $catalog = $db->_reorganize_results( $query_output, $with_flux );

The optional second argument tells the routine to keep the Flux
measurements or not. Not keeping them speeds things up. Keeping
the flux measurements is the default.

=cut

sub _reorganize_results {
  my $self = shift;
  my $rows = shift;
  my $with_flux = shift;

  # Return if we don't have anything to reorganize.
  if( ! defined( $rows ) ) {
    return undef;
  }

  if( ! defined( $with_flux ) ) {
    $with_flux = 1;
  }

  my $catalog = new Astro::Catalog;

  my %seen_object_ids;
  my %seen_flux_ids;

  for my $row ( @$rows ) {

    # Convert the keys to upper-case.
    my $newrow;
    for my $key ( keys %$row ) {
      my $uckey = uc( $key );
      $newrow->{$uckey} = $row->{$key};
    }

    # Now, we have to go through this line by line, but each
    # line will probably have information we've seen before (like
    # the actual object -- there'll be as many lines as there are
    # flux measurements for the object, and we don't want to
    # create one Astro::Catalog::Item object per line).
    if( ! $seen_object_ids{$newrow->{uc($primary_keys{$OBJECTTABLE})}} ) {
      # New object, process it.
      $seen_object_ids{$newrow->{uc($primary_keys{$OBJECTTABLE})}}++;

      # Notes for object population:
      # - The query we set up sorts first by item ID, then by flux measurement date.
      #   Because of this, we know that the first time we see an item the datetime
      #   its flux measurement is the epoch of observation for its coordinates, which
      #   are stored in J2000.
      my $coords = new Astro::Coords( ra => $newrow->{"RIGHT_ASCENSION"},
                                      dec => $newrow->{"DECLINATION"},
                                      units => 'radians',
                                      type => 'J2000',
                                    );
      my $strp = new DateTime::Format::Strptime( pattern => "%b%t%d%t%Y%t%I:%M:%S:000%p%n" );
      my $datetime = $strp->parse_datetime( $newrow->{"LONGMEASUREMENTDATE"} );

      $coords->datetime( $datetime );
      my $morphology = new Astro::Catalog::Item::Morphology( ellipticity => $newrow->{'ELLIPTICITY'},
                                                             position_angle_world => $newrow->{'POSITION_ANGLE'},
                                                           );

      my $item = new Astro::Catalog::Item( ID => $newrow->{uc($primary_keys{$OBJECTTABLE})},
                                           Coords => $coords,
                                           Morphology => $morphology,
                                         );

      # Push this item onto the catalog.
      $catalog->pushstar( $item );
    }
    if( $with_flux && ! $seen_flux_ids{$newrow->{uc($primary_keys{$MEASUREMENTTABLE})}} ) {
      # New flux measurement, process it.
      my $fluxes = new Astro::Fluxes;
      foreach my $fluxtype ( qw/ ISOPHOTAL_FLUX TOTAL_FLUX CORE1_FLUX CORE2_FLUX
                                 CORE3_FLUX CORE4_FLUX CORE5_FLUX / ) {
        my $type = $fluxtype;
        if( exists( $flux_map{$fluxtype} ) ) {
          $type = $flux_map{$fluxtype};
        }
        my $flux = new Astro::Flux( $newrow->{$type}, $type,
                                    new Astro::WaveBand( Filter => $newrow->{WAVEBAND} ) );
        $fluxes->pushfluxes( $flux );
      }

      # Now we've got the Fluxes object, time to put it in the proper
      # Astro::Catalog::Item object.
      my $itemid = $newrow->{uc($primary_keys{$OBJECTTABLE})};
      my $itemlist = $catalog->popstarbyid($itemid);
      my $item = $itemlist->[0];
      my $item_fluxes = $item->fluxes;
      if( defined( $item_fluxes ) ) {
        $item_fluxes->merge($fluxes);
      } else {
        $item->fluxes( $fluxes );
      }
      $catalog->pushstar( $item );
    }

  }

  return $catalog;

}

=item B<_store_catalog>

Store the given C<Astro::Catalog> object in the database.

  $db->_store_catalog( $catalog );

=cut

sub _store_catalog {
  my $self = shift;

  my $catalog = shift; # Astro::Catalog;

  foreach my $item ( $catalog->stars ) {

    $self->_add_item( $item );

  }
}

=back

=head1 SEE ALSO

C<eSTAR::Database::Query>

=head1 AUTHORS

Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2005 Particle Physics and Astronomy Research Council.
All Rights Reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the
Free Software Foundation, Inc., 59 Temple Place, Suite 330,
Boston, MA  02111-1307  USA

=cut

1;
