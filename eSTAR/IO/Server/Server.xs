#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "string.h"
#include "globus_common.h"
#include "globus_io.h"
#include "estar_io.h"
#include "client.h"

MODULE = eSTAR::IO::Server  PACKAGE = eSTAR::IO::Server	  PREFIX = eSTAR_IO_	

int
eSTAR_IO_Close_Server()