# Astro::ADS::Result::Paper test harness

# strict
use strict;

#load test
use Test;
BEGIN { plan tests => 45 };

# load modules
use Astro::ADS::Result::Paper;

# T E S T   H A R N E S S --------------------------------------------------

# test the test system
ok(1);

my ( $bibcode, $title, @authors, @affil, $journal, $published, @keywords,
     $origin, @links, $URL, @abstract, $object );

# Set the test paper meta-data
$bibcode = "1998MNRAS.295..167A";
$title = "ASCA X-ray observations of EX Hya - Spin-resolved spectroscopy";

$authors[0] = "Allan, Alasdair";
$authors[1] = "Hellier, Coel";
$authors[2] = "Beardmore, Andrew";
$affil[0] = "Keele Univ. 0";
$affil[1] = "Keele Univ. 1";
$affil[2] = "Keele Univ. 2";

$journal = "Royal Astronomical Society, Monthly Notices, vol. 295, p. 167";
$published = "3/1998";

$keywords[0] = "WHITE DWARF STARS";
$keywords[1] = "X RAY ASTRONOMY";
$keywords[2] = "SPECTRAL RESOLUTION";
$keywords[3] = "ASTRONOMICAL"; 
$keywords[4] = "SPECTROSCOPY";
$keywords[5] = "ACCRETION DISKS";
$keywords[6] = "ASTRONOMICAL MODELS";
$keywords[7] = "TEMPERATURE"; 
$keywords[8] = "DISTRIBUTION";
$keywords[9] = "SHOCK WAVES";

$origin = "STI";

$links[0] = "ABSTRACT";
$links[1] = "EJOURNAL";
$links[2] = "ARTICLE";
$links[3] = "GIF";
$links[4] = "REFERENCES";
$links[5] = "CITATIONS";
$links[6] = "SIMBAD";

$URL =
 "http://cdsads.u-strasbg.fr/cgi-bin/nph-bib_query?bibcode=1998MNRAS.295..167A";

@abstract = <DATA>;
chomp @abstract;

$object = "EX Hya";

# create an Astro::ADS::Result::Paper object from the meta-data
my $paper = new Astro::ADS::Result::Paper( Bibcode   => $bibcode,
                                           Title     => $title,
                                           Authors   => \@authors,
                                           Affil     => \@affil,
                                           Journal   => $journal,
                                           Published => $published,
                                           Keywords  => \@keywords,
                                           Origin    => $origin,
                                           Links     => \@links,
                                           URL       => $URL,
                                           Abstract  => \@abstract,
                                           Object    => $object );

# compare bibcodes  
ok( $paper->bibcode(), $bibcode );

# compare titles
ok( $paper->title(), $title );

# check its got all the authors
my @ret_authors = $paper->authors();
for my $i (0 .. $#authors) {
   ok( $ret_authors[$i], $authors[$i] );
}

# check scalar context call
my $first_author = $paper->authors();
ok( $first_author, $authors[0] );

# check its got all the author affiliations
my @ret_affil = $paper->affil();
for my $j (0 .. $#affil) {
   ok( $ret_affil[$j], $affil[$j] );
}

# check scalar context call
my $first_author_affil = $paper->affil();
ok( $first_author_affil, $affil[0] );

# compare journal ref
ok( $paper->journal(), $journal );

# compare publication dates
ok( $paper->published(), $published );

# check its got all the keywords
my @ret_keys = $paper->keywords();
for my $k (0 .. $#keywords) {
   ok( $ret_keys[$k], $keywords[$k] );
}

# check scalar context call
my $num_keys = $paper->keywords();
ok( $num_keys, $#keywords );

# compare origin
ok( $paper->origin(), $origin );

# check its got all the outbound links
my @ret_urls = $paper->links();
for my $l (0 .. $#links) {
   ok( $ret_urls[$l], $links[$l] );
}

# check scalar context call
my $num_urls = $paper->links();
ok( $num_urls, $#links );

# check its got the abstract
my @ret_abs = $paper->abstract();
for my $m (0 .. $#abstract) {
   ok( $ret_abs[$m], $abstract[$m] );
}

# check scalar context call
my $lines = $paper->abstract();
ok( $lines, $#abstract );

exit;

# D A T A   B L O C K  ----------------------------------------------------

__DATA__
We analyze the spectral changes over the spin modulation in the 
intermediate polar EX Hya using archival ASCA data. We find that the 
modulation can be modelled as either (1) the effect of occultation of 
the accretion poles by the limb of the white dwarf, or (2) the effect of 
phase-dependent photoelectric absorption. We argue, on the basis of the 
partial X-ray eclipse, that the accretion columns in the system are 
tall, with shock height Rwd, and hence that the spin modulation is 
caused mainly by occultation. We find that the temperature distribution 
along the accretion shocks is incompatible with the calculations of 
Aizu, except for a restricted parameter regime with a high Mwd. Hence 
the material in the shock must cool faster than predicted by theory. 