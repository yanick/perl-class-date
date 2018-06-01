package Class::Date::Invalid;
use strict;
use warnings;

use Class::Date::Const;

use overload 
  '0+'     => "zero",
  '""'     => "empty",
  '<=>'    => "compare",
  'cmp'    => "compare",
  '+'      => "zero",
  '!'      => "true",
  fallback => 1;
                
sub empty { "" }
sub zero { 0 }
sub true { 1 }

sub compare { return ($_[1] ? 1 : 0) * ($_[2] ? -1 : 1) }

sub error { shift->[ci_error]; }

sub errmsg { my ($s) = @_;
    no warnings; # sometimes we need the errmsg, sometimes we don't
    # should be 'no warnings 'redundant'', but older perls don't
    # understand that warning
    sprintf $ERROR_MESSAGES[ $s->[ci_error] ]."\n", $s->[ci_errmsg] 
}
*errstr = *errmsg;

sub AUTOLOAD { undef }

1;

