# -*- perl -*-

use Test::More tests => 73;

BEGIN { use_ok("Class::Date", qw(localdate date)) }

$Class::Date::DST_ADJUST=1;

# Class::Date::new

my $date1=Class::Date->new([2000,11,11,0,1,2]);
is($date1, "2000-11-11 00:01:02", "Class::Date->new([])");

my $date2=localdate [2000,10,5];
is($date2,"2000-10-05 00:00:00", "localdate([])");

my $date3=date({ 
  year => 2001, month => 03, day => 11, 
  hour =>   12,   min => 13, sec => 55
});
is($date3, "2001-03-11 12:13:55", "date({})");

my $date4=localdate({
  year => 2001, month => 03, day => 11
});
is($date4, "2001-03-11 00:00:00", "localdate({}) - date only");

my $date5=localdate("2001-2-21 13:11:10.123456");
is($date5, "2001-02-21 13:11:10", 'localdate("") - extra precision ignored');

my $date6=localdate("2001-2-21 13:11:06");
is($date6, "2001-02-21 13:11:06", "localdate('') - sloppy ISO");

my $date7=localdate("2000-11-11 0:0:0");
is($date7,"2000-11-11", "localdate('') - sloppy ISO 2, partial compare");

my $date8=localdate("2001011312220112");
is($date8, "2001-01-13 12:22:01", "localdate('') - MySQL variant");

my $date9=localdate("2001-5-11");
is($date9,"2001-05-11 00:00:00", "localdate('') - sloppy ISO 3");

my $date10=$date9->new($date9);
is($date10, "2001-05-11", "->new() - clone, comparing incomplete dates");

# Class::Date::Rel::new

my $reldate1=Class::Date::Rel->new('1D');
is($reldate1, "0000-00-01 00:00:00", "Class::Date::Rel->new('') - simple");

my $reldate2=Class::Date::Rel->new('1Y 1M 15h 20m');
is($reldate2, "0001-01-00 15:20:00", "Class::Date::Rel->new('') - mixed");

my $reldate3=Class::Date::Rel->new('3Y 3M 5D 13h 20m 15s');
is($reldate3, "0003-03-05 13:20:15", "Class::Date::Rel->new('') - complete");

my $reldate4=Class::Date::Rel->new({ year => 5, day => 7});
is($reldate4, "0005-00-07 00:00:00", "Class::Date::Rel->new({}) - partial");

my $reldate5=Class::Date::Rel->new({ 
  year => 9, month => 8,    day => 7,
  hour => 6, min   => 65,   sec => 55,
});
is($reldate5, "0009-08-07 07:05:55", "Class::Date::Rel->new({}) - complete");

my $reldate6=Class::Date::Rel->new([9,8,7,6,65,55]);
is($reldate6, "0009-08-07 07:05:55", "Class::Date::Rel->new([]) - complete");

my $reldate7=Class::Date::Rel->new("7-8-6 07:11:10");
is($reldate7, "0007-08-06 07:11:10", "Class::Date::Rel->new('') - date form");

my $reldate8=$reldate5->new($reldate7);
is($reldate8, "7Y 8M 6D 7h 11m 10s",
   "->new() - clone, compare with ISO-ish period");

# Class::Date::add

is $date1+$reldate1,"2000-11-12 00:01:02", "overloaded `+'; ::Date + ::Rel";
is $date7+$reldate3,"2004-02-16 13:20:15", "overloaded `+'; DST adjust";
is $date1+"2Y",     "2002-11-11 00:01:02", "overloaded `+'; ::Date + period";
is $date1+"2-0-0",  "2002-11-11 00:01:02", "overloaded `+'; ::Date + date";

# Class::Date::subs
  
is $date1-$reldate1,"2000-11-10 00:01:02", "overloaded `-'; ::Date - ::Rel";
is $date7-$reldate3+$reldate3,$date7,      "overloaded `-'; identity check";
is $date3-$date1,'120D 12h 12m 53s', "overloaded `-'; ::Date-::Date = ::Rel";
is $date1-'1D',  "2000-11-10 0:1:2", "overloaded `-'; ::Date-'period'";
is $date1-[0,0,1],  "2000-11-10 0:1:2", "overloaded `-'; ::Date-[period]";

# Class::Date Comparison

ok $date1>$date2,		"overloaded `>' - positive (::Date)";
ok $date1>=$date1,		"overloaded `>=' - positive (::Date)";
ok ! ($date1<"2000-01-01"),	"overloaded `<' - negative, imm. (::Date)";
ok ! ("2000-01-01">$date1),	"overloaded `>' - neg've, rev, imm. (::Date)";
is "2000-01-02" <=> $date1, -1,	"overloaded `<=>' - -1, rev, imm. (::Date)";
is "2001-01-02" cmp $date1,  1 ,"overloaded `cmp' - 1, rev, imm. (::Date)";
is $date1 <=> "2000-01-02",  1,	"overloaded `<=>' - 1, imm. (::Date)";
is $date1 cmp "2001-01-02", -1,	"overloaded `cmp' - -1, imm. (::Date)";

# Class::Date::Rel Comparison

ok $reldate1<$reldate2,		"overloaded `<' - positive (::Rel)";
ok $reldate2<'2Y',		"overloaded `<' - positive, imm. (::Rel)";
ok '2Y'<$reldate3,		"overloaded `<' - positive, imm, rev (::Rel)";
is '2Y' <=> $reldate3, -1,	"overloaded `<=>' - -1, imm, rev (::Rel)";
is $reldate3 <=> '2Y',  1,	"overloaded `<=>' - 1, imm (::Rel)";

# Class::Date field methods;

is $date1->year,2000,		"::Date->year()";
is $date1->mon,11,		"::Date->mon()";
is $date1->day,11,		"::Date->day()";
is $date1->hour,0,		"::Date->hour()";
is $date1->min,1,		"::Date->min()";
is $date1->sec,2,		"::Date->sec()";

# Default values for hash initialization

my $date11=new Class::Date { year => 2001 };
is $date11,"2001-01-01 00:00:00", "::Date->new({}) - defaults (only year)";

my $date12=new Class::Date { month => 2   };
is $date12,"2000-02-01 00:00:00", "::Date->new({}) - defaults (only month)";

my $date13=localdate [1998];
is $date13,"1998-01-01", "localdate([]) - defaults (only year)";

my $reldate9=Class::Date::Rel->new( { year => 4 });
is $reldate9, "4-0-0 0:0:0", "::Rel->new({}) - defaults (only year)";

my $reldate10=Class::Date::Rel->new( { month => 5 });
is $reldate10, "0-5-0 0:0:0", "::Rel->new({}) - defaults (only month)";

is_deeply([$date1->array], [2000, 11, 11, 0, 1, 2], "::Date->array()");

# undef comparison
$^W = 1;
$SIG{__WARN__} = sub { fail("saw warning") };

ok $date11 > undef() ? 1 : 0, "overloaded `>' - +ve, undef";
ok undef() > $date11 ? 0 : 1, "overloaded `>' - -ve, rev, undef";
ok $date13 < undef() ? 0 : 1, "overloaded `<' - -ve, undef";
ok undef() < $date13 ? 1 : 0, "overloaded `<' - +ve, rev, undef";

is $date1->month_begin,"2000-11-01 00:01:02",	"::Date->month_begin()";
is $date1->month_end  ,"2000-11-30 00:01:02",	"::Date->month_end()";
is $date1->days_in_month,30,			"::Date->days_in_month() - 30";
is $date2->days_in_month,31,			"::Date->days_in_month() - 31";
is $date5->days_in_month,28,			"::Date->days_in_month() - 28";
is localdate("2000-02-01")->days_in_month, 29,  "::Date->days_in_month() - 29";

is $date1->truncate,"2000-11-11 00:00:00",	"::Date->truncate()";
is $date1->trunc,"2000-11-11 00:00:00",		"::Date->trunc()";
is $date1,"2000-11-11 00:01:02",		"no side effects so far";

{
  local $Class::Date::MONTH_BORDER_ADJUST = 0;
  my $date11 = date("2001-05-31");
  is $date11+'4M',"2001-10-01", "no MONTH_BORDER_ADJUST - add";
  is $date11-'3M',"2001-03-03", "no MONTH_BORDER_ADJUST - sub";
  $Class::Date::MONTH_BORDER_ADJUST = 1;
  is $date11+'4M',"2001-09-30", "MONTH_BORDER_ADJUST - add";
  is $date11-'3M',"2001-02-28", "MONTH_BORDER_ADJUST - sub";
}

my $date14 = date("2001-12-18");
is $date14->days_in_month, 31, "::Date->days_in_month() - 31";

is date([2001,11,17])->is_leap_year ? 1 : 0, 0, "::Date->is_leap_year() - +ve";
is date([2004,03,05])->is_leap_year ? 1 : 0, 1, "::Date->is_leap_year() - -ve";
