use ExtUtils::MakeMaker;

WriteMakefile( 
               'NAME'           => 'Astro::VO::VOEvent',
	       'VERSION'        => '0.2',
               'PREREQ_PM'      => {  },
	       'dist'           => { COMPRESS => "gzip -9f"},
	       ($] >= 5.005 ?    ## 
	       ( ABSTRACT       => 'Module designed to parse VOEvent messages',
		 AUTHOR         => 'Alasdair Allan <aa@astro.ex.ac.uk>') : ()),
             );

