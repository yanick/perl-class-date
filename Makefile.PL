use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Class::Date',
    'VERSION_FROM'	=> 'lib/Class/Date.pm',	    # finds $VERSION
    'dist'              => { 
	PREOP => $^X.' -MPod::Text -e "pod2text(q(lib/Class/Date.pod))" > README'
    }
)
