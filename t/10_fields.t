#  -*- perl -*-

use Test::More tests => 18;
use strict;

BEGIN { use_ok("Class::Date", qw(gmdate)) };

$a = gmdate("2001-07-26 16:15:23");

is($a->set(year  => 2002), "2002-07-26 16:15:23", "->set() - year");
is($a, "2001-07-26 16:15:23", "->set() returns new object");

is($a->set(_year =>  105), "2005-07-26 16:15:23", "->set() - _year");

is($a,"2001-07-26 16:15:23", "->set() still returns new object");
is( $a->set(month =>    4), "2001-04-26 16:15:23", "->set() - month");
is( $a->set(mon   =>    9), "2001-09-26 16:15:23", "->set() - mon");
is( $a->set(_month=>    7), "2001-08-26 16:15:23", "->set() - _month");
is( $a->set(_mon  =>    2), "2001-03-26 16:15:23", "->set() - _mon");
is( $a->set(day   =>   12), "2001-07-12 16:15:23", "->set() - day");
is( $a->set(mday  =>   21), "2001-07-21 16:15:23", "->set() - mday");
is( $a->set(day_of_month=>5), "2001-07-05 16:15:23", "->set() - day_of_month");
is( $a->set(hour  =>   14), "2001-07-26 14:15:23", "->set() - hour");
is( $a->set(min   =>   34), "2001-07-26 16:34:23", "->set() - min");
is( $a->set(minute=>   19), "2001-07-26 16:19:23", "->set() - minute");
is( $a->set(sec   =>   49), "2001-07-26 16:15:49", "->set() - sec");
is( $a->set(second=>   44), "2001-07-26 16:15:44", "->set() - second");
is( $a->set(year => 1985, day => 16), "1985-07-16 16:15:23", "->set() - year + day");

