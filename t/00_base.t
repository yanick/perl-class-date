#  -*- perl -*-

use Test::More tests => 6;

BEGIN { use_ok("Class::Date", qw(now gmdate)); };

my $t = gmdate(315532800); # 00:00:00 1/1/1980

is($t->year, 1980, "->year()");
is($t->hour, 0,    "->hour()");
is($t->mon, 1,      "->mon()");
cmp_ok(now, ">", "1970-1-1", "overloaded date compare");
cmp_ok(gmdate("now"), ">",  "1970-1-1", "overloaded date compare");
