#  -*- perl -*-

use Test::More tests => 18;

BEGIN { use_ok("Class::Date", qw(:errors gmdate)) };

$Class::Date::DST_ADJUST=1;

$a = gmdate("195xwerf9");
ok !$a,				"garbage in, error out";
is $a->error, E_UNPARSABLE,	"->error() - E_UNPARSABLE";
is $a->errstr, "Unparsable date or time: 195xwerf9\n", "->errstr()";

$Class::Date::RANGE_CHECK=0;

# hmm, turning off range checking should (IMHO) just store errant
# values in the date object...
$a = gmdate("2001-02-31");
is $a, "2001-03-03",		"non-range check overflowed nicely";

$Class::Date::RANGE_CHECK=1;

$a = gmdate("2001-02-31");
ok !$a,				"bad date refused with range checking";
ok $a ? 0 : 1,			"error is logically false";
is $a->error, E_RANGE,		"->error() - E_RANGE";
is $a->errstr, "Range check on date or time failed\n", "->errstr()";

$a = gmdate("2006-2-6")->clone( month => -1);
ok !$a,				"negative values to clone refused";
ok $a ? 0 : 1,			"error is logically false";

$a = new Class::Date(undef);
ok ! $a,			"undef in, error out";
ok $a ? 0 : 1,			"error is logically false";
is $a->error, E_UNDEFINED,	"->error() - E_UNDEFINED";
is $a->errstr, "Undefined date object\n", "->errstr()";

$a = gmdate("2006-2-6")->clone(month => 16);
ok !$a,				"absurd values to clone refused";
ok $a ? 0 : 1,			"error is logically false";

$a = gmdate("2001-05-04 07:09:09") + [1,-2,-4];
ok $a,			"relative dates may still have negative numbers";
