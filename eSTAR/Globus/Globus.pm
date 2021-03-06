package eSTAR::Globus;

require 5.005_62;
use strict;
use warnings;
use vars qw/ $VERSION /;

require Exporter;
require DynaLoader;

our @ISA = qw(Exporter DynaLoader);
our %EXPORT_TAGS = ( 'all' => [ qw / GLOBUS_SUCCESS GLOBUS_FAILURE
                                     GLOBUS_TRUE GLOBUS_FALSE GLOBUS_NULL / ] ); our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw / /;
'$Revision: 1.3 $ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

bootstrap eSTAR::Globus $VERSION;

# Error Constants
use constant GLOBUS_SUCCESS => 0;
use constant GLOBUS_FAILURE => 1;

# Logic Constants
use constant GLOBUS_TRUE    => 1;
use constant GLOBUS_FALSE   => 0;
use constant GLOBUS_NULL    => 0;

1;
__END__

