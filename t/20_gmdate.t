#  -*- perl -*-

use Test::More tests => 51;

BEGIN { use_ok("Class::Date", qw(gmdate date)) };

$Class::Date::DST_ADJUST=1;

# Class::Date::new

my $date1=gmdate([2000,11,11,0,1,2]);
is($date1, "2000-11-11 00:01:02", "gmdate([])");

my $date2=date [2000,10,5],1;
is($date2, "2000-10-05 00:00:00", "date([],1)");

my $date3=gmdate({ 
  year => 2001, month => 03, day => 11,
  hour =>   12,   min => 13, sec => 55
});
is($date3, "2001-03-11 12:13:55", "gmdate({})");

my $date4=gmdate({
  year => 2001, month => 03, day => 11
});
is($date4, "2001-03-11 00:00:00", "gmdate({}) - date only");

my $date5=gmdate("2001-2-21 13:11:10.123456");
is($date5, "2001-02-21 13:11:10", 'gmdate("") - extra precision ignored');

my $date6=gmdate("2001-2-21 13:11:06");
is($date6, "2001-02-21 13:11:06", "gmdate('') - sloppy ISO");

my $date7=gmdate("973897200");
is($date7, "2000-11-10 23:00:00", "gmdate('') - Un*x epoch seconds");

my $date8=gmdate("2001011312220112");
is($date8, "2001-01-13 12:22:01", "gmdate('') - MySQL variant");

my $date9=gmdate("2001-5-11");
is($date9, "2001-05-11 00:00:00", "gmdate('') - sloppy ISO 2");

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

is($date1+$reldate1, "2000-11-12 00:01:02", "overloaded `+'; ::Date + ::Rel");
is($date7+$reldate3, "2004-02-16 12:20:15", "overloaded `+'; ::Date + ::Rel");
is($date1+"2Y", "2002-11-11 00:01:02", "overloaded `+'; ::Date + period");
is($date1+"2-0-0", "2002-11-11 00:01:02", "overloaded `+'; ::Date + date");

# Class::Date::subs

is($date1-$reldate1, "2000-11-10 00:01:02", "overloaded `-'; ::Date - ::Rel");
is($date7-$reldate3+$reldate3, $date7, "overloaded `-'; identity check");
is($date3-$date1, '120D 12h 12m 53s', "overloaded `-'; ::Date-::Date = ::Rel");

# Class::Date Comparison

ok($date1>$date2,		"overloaded `>' - positive (::Date)");
ok($date1>=$date1,		"overloaded `>=' - positive (::Date)");
ok(!($date1<"2000-01-01"),	"overloaded `<' - negative, imm. (::Date)");
ok(!("2000-01-01">$date1),	"overloaded `>' - neg've, rev, imm. (::Date)");
is("2000-01-02" <=> $date1, -1, "overloaded `<=>' - -1, rev, imm. (::Date)");
is("2001-01-02" cmp $date1,  1, "overloaded `cmp' - 1, rev, imm. (::Date)");
is($date1 <=> "2000-01-02",  1, "overloaded `<=>  - 1, normal, imm. (::Date)");
is($date1 cmp "2001-01-02", -1, "overloaded `cmp' - 1, normal, imm. (::Date)");

# Class::Date::Rel Comparison

ok($reldate1<$reldate2,		"overloaded `<' - positive (Rel)");
ok($reldate2<'2Y',		"overloaded `<' - positive, imm. (Rel)");
ok('2Y'<$reldate3,		"overloaded `<' - positive, rev, imm. (Rel)");
is('2Y' <=> $reldate3, -1,	"overloaded `<=>' - -1, rev, imm. (Rel)");
is($reldate3 <=> '2Y',  1,	"overloaded `<=>' - 1, imm.  (Rel)");

# Class::Date field methods;

is($date1->year,2000,		"Class::Date->year()");
is($date1->mon,11,		"Class::Date->mon()");
is($date1->mday,11,		"Class::Date->mday()");
is($date1->hour,0,		"Class::Date->hour()");
is($date1->min,1,		"Class::Date->min()");
is($date1->sec,2,		"Class::Date->sec()");

# Default values for hash initialization

my $date11=new Class::Date { year => 2001 };
is($date11,"2001-01-01 00:00:00", "::Date->new() - hash defaults (only year)");

my $date12=new Class::Date { month => 2   };
is($date12,"2000-02-01 00:00:00",
   "::Date->new() - hash defaults (only month)");

my $date13=gmdate [1998];
is($date13,"1998-01-01", "::Date->new() - array defaults (only month)");

my $reldate9=Class::Date::Rel->new( { year => 4 });
is($reldate9, "4-0-0 0:0:0", "::Rel->new() - hash defaults (only year)");

my $reldate10=Class::Date::Rel->new( { month => 5 });
is($reldate10, "0-5-0 0:0:0", "::Rel->new() - hash defaults (only month)");

is_deeply([$date1->array], [2000, 11, 11, 0, 1, 2], "::Date->array()");
