#  -*- perl -*-

use strict;
use Test::More tests => 69;

# test the API in the man page
BEGIN {
    $ENV{TZ} = "Pacific/Auckland";   # :-P
    use_ok "Class::Date", qw(date localdate gmdate now -DateParse)
}

my ($year, $month, $day, $hour, $min, $sec) = split /\D/,"1979-01-17T11:02:42";
my ($date);

  # creating non-timezones date object ('floating' time)
  $date = new Class::Date [$year,$month,$day,$hour,$min,$sec];
is $date, "$year-$month-$day $hour:$min:$sec", "Class::Date->new([])";
  $date = date [$year,$month,$day,$hour,$min,$sec];
is $date, "$year-$month-$day $hour:$min:$sec", "date([])";
  $date = date { year => $year, month => $month, day => $day,
	         hour => $hour, min   => $min,   sec => $sec };
is $date, "$year-$month-$day $hour:$min:$sec", "date({})";

  $date = date "2001-11-12 07:13:12";  # or any ISO-8601 format
is $date, "2001-11-12 07:13:12", "date('')";

  # add a month to it:
  #$date += "1M";
is $date+"1M", "2001-12-12 07:13:12", "overloaded `+': string period";
  #$date += "P1M";         # ISO-8601 Periods supported
is $date+"P1M", "2001-12-12 07:13:12", "overloaded `+': ISO-8601 period";
  #$date += [0,1,0,0,0,0]; # above formats supported
is $date+[0,1,0,0,0,0], "2001-12-12 07:13:12", "overloaded `+': array period";
  #$date += 31*24*60*60;   # seconds
is $date+31*24*60*60, "2001-12-13 07:13:12", "overloaded `+': seconds";

my ($days_between);

  # intuitive arithmetic between dates:
  $days_between = ( date('2001-11-12')
                    - date('2001-07-04') )->day; # prints 131

is($days_between, 131, "::Rel ->day()");

is($date->tz, undef, "`Floating' times assumed");
  # creating date object in local timezone
  $date = localdate "2001-12-11";      # force local time
is($date->tz, 'NZST', "localdate() returns zoned times");
is($date, "2001-12-11 00:00:00", "localdate() returns a date");
  $date = now;                         # the same as date(time)
like($date->tz, qr/NZ[SD]?T/, "now() returns zoned times");
like($date, qr/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/,
     "localdate() returns a date");

my ($yyyy,$mm,$dd,$HH,$MM,$SS)
    = ($year, $month, $day, $hour, $min, $sec);

  # creating absolute date object (UTC)
  $date = new Class::Date [$yyyy,$mm,$dd,$HH,$MM,$SS], 'UTC';
is $date, "$year-$month-$day $hour:$min:$sec", 'Class::Date->new([],$tz)';
is $date->tz, "UTC", '->tz()';
  $date = gmdate "2001-11-12 17:13";
is $date, "2001-11-12 17:13", 'gmdate("")';
is $date->tz, "UTC", '->tz()';

  # creating absolute date object in any other timezone
  $date = date [$year,$month,$day,$hour,$min,$sec], 'Iceland';
is $date, "$year-$month-$day $hour:$min:$sec", 'Class::Date->new([],$tz)';
is $date->tz, "Iceland", "->tz() - Iceland";
  $date = date "2001-11-12 17:13", 'Iceland';
is $date->tz, "Iceland", "->tz() - Iceland";

  # getting parts out - comprehensive methods available
  my $year = $date->year;     # full
is($year, "2001", "->year()");
  my $year_C = $date->_year;  # year - 1900 (or 1904 on Mac?)
diag("The C library returned a value that wasn't 101 for 2001.
This is probably because the C library does not work the same way on
your system as a normal UNIX environment.  Please mail the author
to report this, so that they may adjust the code and tests for your
platform.") if $year_C != 101;
is($year_C, "101", "->year()");
  my $month = $date->mon;     # 1..12
is($month, 11, "->month()");
  my $month_C = $date->_mon;  # 0..11
is($month, 10, "->_mon()");
  ($year,$month,$day,$hour,$min,$sec)=$date->array;
is_deeply([$year,$month,$day,$hour,$min,$sec],
	  [2001, 11, 12, 17, 13, 0], "->array()");
  #print date([2001,12,11,4,5,6])->truncate;
                               # will print "2001-12-11"
is("".date([2001,12,11,4,5,6])->truncate,
   "2001-12-11",
   "->truncate() slices off date");

my ($new_date);

  # constructing new date based on an existing one:
  $new_date = $date->clone;
is($new_date, $date, "->clone()");
SKIP:{
eval { require Scalar::Util;
isnt(Scalar::Util::refaddr($new_date),
     Scalar::Util::refaddr($date),
     "->clone() returns a new object");
};
skip 3, "Scalar::Util not installed ($@)" if $@;
  $new_date->set( year => 1977, sec => 14);
is($new_date->year, 1977, "->set() affects current object");
  $new_date = $date->clone( year => 1977, sec => 14 );
is($date->year, 2001, "->clone() doesn't affect current object");
is($new_date, "1977-11-12 17:13:14",
   "->clone() sets everything OK");
}

  # constructing a new date, which is the same absolute time as
  # the original, but expressed in another timezone:
  $new_date = $date->to_tz('Iceland');
is($new_date, "2001-11-12 17:13:00", "->to_tz() clone constructor");

my ($date1, $date2);

  # comparison between absolute dates
  print $date1 > $date2 ? "I am older" : "I am younger";

my ($reldate1, $reldate2);

  # comparison between relative dates
  print $reldate1 > $reldate2 ? "I am faster" : "I am slower";

  # Adding / Subtracting months and years are sometimes tricky:
  print date("2001-01-29") + '1M' - '1M'; # gives "2001-02-01"
  print date("2000-02-29") + '1Y' - '1Y'; # gives "2000-03-01"
