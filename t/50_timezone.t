#   -*- perl -*-

use Test::More tests => 11;

BEGIN { use_ok("Class::Date", qw(date gmdate)); }

$Class::Date::DST_ADJUST=1;

# Class::Date::new

# warning - time zone codes considered harmful, eg Australia use the
# same TimeZone as Eastern US for one of their time zones.  Stick to
# rfc822 codes on input only.
my $date1=Class::Date->new([2002,05,04,0,1,2],'CET');
is $date1, "2002-05-04 00:01:02",	"->new([],'tz')";
is $date1->tz, 'CET',			"->tz";
is $date1->tzdst, 'CEST',		"->tzdst";
is $date1->epoch, 1020463262,		"->epoch";

my $date2 = $date1->to_tz('GMT');
is $date2, "2002-05-03 22:01:02",	"->to_tz('')";
is $date2->tz, 'GMT',			"->tz";
is $date2->tzdst, 'GMT',		"->tzdst";
is $date1->epoch, 1020463262,		"->epoch";

my $date3 = $date1->clone(tz => 'GMT');
is $date3->epoch, 1020470462,		"->clone(tz => '') doesn't convert TZ";
is $date3, gmdate([2002,05,04,0,1,2]),  "it just changes the recorded zone";
