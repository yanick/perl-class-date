#!/usr/bin/perl -I../..
use POSIX qw(strftime tzset tzname);
delete $ENV{lang};
$time = 1020463262;
@time_array = localtime($time);
POSIX::tzset();
print_it("Default");
local $ENV{TZ}="GMT";
POSIX::tzset();
@time_array = localtime($time);
print_it("GMT");
delete $ENV{TZ};
POSIX::tzset();
@time_array = localtime($time);
print_it("Without TZ");
$ENV{TZ}="CET";
POSIX::tzset();
@time_array = localtime($time);
print_it("CET TZ");

sub print_it {
    printf "%20s: %4s,%4s, %02d:%02d:%02d, %02d-%02d-%03d %1d,%03d,%1d,%s:%s\n",
        shift(), POSIX::tzname(),@time_array, "".localtime($time),
        POSIX::strftime("%Z %Y%m%d",(@time_array)[0..5],-1,-1,-1);
}

