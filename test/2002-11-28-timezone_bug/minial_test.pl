#!/usr/bin/perl
use strict;
use POSIX qw(strftime tzset tzname);
my $time = 1020463262;
delete $ENV{LANG};
$ENV{TZ}="CET";
tzset();
my @time_array = localtime($time);
print strftime("%Z", @time_array) eq "CEST" ? "ok" : "not ok";
