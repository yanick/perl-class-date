package Class::Date;
our $AUTHORITY = 'cpan:YANICK';
# ABSTRACT: Class for easy date and time manipulation
$Class::Date::VERSION = '1.1.16';
use 5.006;

use strict;
use vars qw(
  @EXPORT_OK %EXPORT_TAGS @ISA
  $DATE_FORMAT $DST_ADJUST $MONTH_BORDER_ADJUST $RANGE_CHECK
  @NEW_FROM_SCALAR @ERROR_MESSAGES $WARNINGS 
  $DEFAULT_TIMEZONE $LOCAL_TIMEZONE $GMT_TIMEZONE
  $NOTZ_TIMEZONE $RESTORE_TZ
);
use Carp;

use Exporter;
use Time::Local;
use Class::Date::Const;
use Scalar::Util qw(blessed);
use POSIX;

use Class::Date::Rel;
use Class::Date::Invalid;

BEGIN { 
    $WARNINGS = 1 if !defined $WARNINGS;
    *timelocal = *Time::Local::timelocal_nocheck;
    *timegm = *Time::Local::timegm_nocheck;

    @ISA=qw(Exporter);
    %EXPORT_TAGS = ( errors => $Class::Date::Const::EXPORT_TAGS{errors});
    @EXPORT_OK = (qw( date localdate gmdate now @ERROR_MESSAGES), 
        @{$EXPORT_TAGS{errors}});

    *strftime_xs = *POSIX::strftime;
    *tzset_xs = *POSIX::tzset;
    *tzname_xs = *POSIX::tzname;
}

$GMT_TIMEZONE = 'GMT';
$DST_ADJUST = 1;
$MONTH_BORDER_ADJUST = 0;
$RANGE_CHECK = 0;
$RESTORE_TZ = 1;
$DATE_FORMAT="%Y-%m-%d %H:%M:%S";

sub _set_tz { my ($tz) = @_;
    my $lasttz = $ENV{TZ};
    if (!defined $tz || $tz eq $NOTZ_TIMEZONE) {
        # warn "_set_tz: deleting TZ\n";
        delete $ENV{TZ};
        Env::C::unsetenv('TZ') if exists $INC{"Env/C.pm"};
    } else {
        # warn "_set_tz: setting TZ to $tz\n";
        $ENV{TZ} = $tz;
        Env::C::setenv('TZ', $tz) if exists $INC{"Env/C.pm"};
    }
    tzset_xs();
    return $lasttz;
}

sub _set_temp_tz { my ($tz, $sub) = @_;
    my $lasttz = _set_tz($tz);
    my $retval = eval { $sub->(); };
    _set_tz($lasttz) if $RESTORE_TZ;
    die $@ if $@;
    return $retval;
}

tzset_xs();
$LOCAL_TIMEZONE = $DEFAULT_TIMEZONE = local_timezone();
{
    my $last_tz = _set_tz(undef);
    $NOTZ_TIMEZONE = local_timezone();
    _set_tz($last_tz);
}
# warn "LOCAL: $LOCAL_TIMEZONE, NOTZ: $NOTZ_TIMEZONE\n";

# this method is used to determine what is the package name of the relative
# time class. It is used at the operators. You only need to redefine it if
# you want to derive both Class::Date and Class::Date::Rel.
# Look at the Class::Date::Rel::ClassDate also.
use constant ClassDateRel => "Class::Date::Rel";
use constant ClassDateInvalid => "Class::Date::Invalid";

use overload 
  '""'     => "string",
  '-'      => "subtract",
  '+'      => "add",
  '<=>'    => "compare",
  'cmp'    => "compare",
  fallback => 1;

sub date ($;$) { my ($date,$tz)=@_;
  return __PACKAGE__ -> new($date,$tz);
}

sub now () { date(time); }

sub localdate ($) { date($_[0] || time, $LOCAL_TIMEZONE) }

sub gmdate    ($) { date($_[0] || time, $GMT_TIMEZONE) }

sub import {
  my $package=shift;
  my @exported;
  foreach my $symbol (@_) {
    if ($symbol eq '-DateParse') {
      if (!$Class::Date::DateParse++) {
        if ( eval { require Date::Parse } ) {
            push @NEW_FROM_SCALAR,\&new_from_scalar_date_parse;
        } else {
            warn "Date::Parse is not available, although it is requested by Class::Date\n" 
                if $WARNINGS;
        }
      }
    } elsif ($symbol eq '-EnvC') {
      if (!$Class::Date::EnvC++) {
        if ( !eval { require Env::C } ) {
          warn "Env::C is not available, although it is requested by Class::Date\n"
            if $WARNINGS;
        }
      }
    } else {
      push @exported,$symbol;
    }
  };
  $package->export_to_level(1,$package,@exported);
}

sub new { my ($proto,$time,$tz)=@_;
  my $class = ref($proto) || $proto;
  
  # if the prototype is an object, not a class, then the timezone will be
  # the same
  $tz = $proto->[c_tz] 
    if defined($time) && !defined $tz && blessed($proto) && $proto->isa( __PACKAGE__ );

  # Default timezone is used if the timezone cannot be determined otherwise
  $tz = $DEFAULT_TIMEZONE if !defined $tz;

  return $proto->new_invalid(E_UNDEFINED,"") if !defined $time;
  if (blessed($time) && $time->isa( __PACKAGE__ ) ) {
    return $class->new_copy($time,$tz);
  } elsif (blessed($time) && $time->isa('Class::Date::Rel')) {
    return $class->new_from_scalar($time,$tz);
  } elsif (ref($time) eq 'ARRAY') {
    return $class->new_from_array($time,$tz);
  } elsif (ref($time) eq 'SCALAR') {
    return $class->new_from_scalar($$time,$tz);
  } elsif (ref($time) eq 'HASH') {
    return $class->new_from_hash($time,$tz);
  } else {
    return $class->new_from_scalar($time,$tz);
  }
}

sub new_copy { my ($s,$input)=@_;
  my $new_object=[ @$input ];
  # we don't mind $isgmt!
  return bless($new_object, ref($s) || $s);
}

sub new_from_array { my ($s,$time,$tz) = @_;
  my ($y,$m,$d,$hh,$mm,$ss) = @$time;
  my $obj= [
    ($y||2000)-1900, ($m||1)-1, $d||1,
    $hh||0         , $mm||0   , $ss||0
  ];
  $obj->[c_tz]=$tz;
  bless $obj, ref($s) || $s;
  $obj->_recalc_from_struct;
  return $obj;
}

sub new_from_hash { my ($s,$time,$tz) = @_;
  $s->new_from_array(_array_from_hash($time),$tz);
}

sub _array_from_hash { my ($val)=@_;
  [
    $val->{year} || ($val->{_year} ? $val->{_year} + 1900 : 0 ), 
    $val->{mon} || $val->{month} || ( $val->{_mon} ? $val->{_mon} + 1 : 0 ), 
    $val->{day}   || $val->{mday} || $val->{day_of_month},
    $val->{hour},
    exists $val->{min} ? $val->{min} : $val->{minute},
    exists $val->{sec} ? $val->{sec} : $val->{second},
  ];
}

sub new_from_scalar { my ($s,$time,$tz)=@_;
  for (my $i=0;$i<@NEW_FROM_SCALAR;$i++) {
    my $ret=$NEW_FROM_SCALAR[$i]->($s,$time,$tz);
    return $ret if defined $ret;
  }
  return $s->new_invalid(E_UNPARSABLE,$time);
}

sub new_from_scalar_internal { my ($s,$time,$tz) = @_;
  return undef if !$time;

  if ($time eq 'now') {
    # now string
    my $obj=bless [], ref($s) || $s;
    $obj->[c_epoch]=time;
    $obj->[c_tz]=$tz;
    $obj->_recalc_from_epoch;
    return $obj;
  } elsif ($time =~ /^\s*(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)\d*\s*$/) { 
    # mysql timestamp
    my ($y,$m,$d,$hh,$mm,$ss)=($1,$2,$3,$4,$5,$6);
    return $s->new_from_array([$y,$m,$d,$hh,$mm,$ss],$tz);
  } elsif ($time =~ /^\s*( \-? \d+ (\.\d+ )? )\s*$/x) {
    # epoch secs
    my $obj=bless [], ref($s) || $s;
    $obj->[c_epoch]=$1;
    $obj->[c_tz]=$tz;
    $obj->_recalc_from_epoch;
    return $obj;
  } elsif ($time =~ m{ ^\s* ( \d{0,4} ) - ( \d\d? ) - ( \d\d? ) 
     ( (?: T|\s+ ) ( \d\d? ) : ( \d\d? ) ( : ( \d\d?  ) (\.\d+)?)? )? }x) {
    my ($y,$m,$d,$hh,$mm,$ss)=($1,$2,$3,$5,$6,$8);
    # ISO(-like) date
    return $s->new_from_array([$y,$m,$d,$hh,$mm,$ss],$tz);
  } else {
    return undef;
  }
}

push @NEW_FROM_SCALAR,\&new_from_scalar_internal;

sub new_from_scalar_date_parse { my ($s,$date,$tz)=@_;
    my $lt;
    my ($ss, $mm, $hh, $day, $month, $year, $zone) =
        Date::Parse::strptime($date);
    $zone = $tz if !defined $zone;
    if ($zone eq $GMT_TIMEZONE) {
        _set_temp_tz($zone, sub {
            $ss     = ($lt ||= [ gmtime ])->[0]  if !defined $ss;
            $mm     = ($lt ||= [ gmtime ])->[1]  if !defined $mm;
            $hh     = ($lt ||= [ gmtime ])->[2]  if !defined $hh;
            $day    = ($lt ||= [ gmtime ])->[3] if !defined $day;
            $month  = ($lt ||= [ gmtime ])->[4] if !defined $month;
            $year   = ($lt ||= [ gmtime ])->[5] if !defined $year;
        });
    } else {
        _set_temp_tz($zone, sub {
            $ss     = ($lt ||= [ localtime ])->[0]  if !defined $ss;
            $mm     = ($lt ||= [ localtime ])->[1]  if !defined $mm;
            $hh     = ($lt ||= [ localtime ])->[2]  if !defined $hh;
            $day    = ($lt ||= [ localtime ])->[3] if !defined $day;
            $month  = ($lt ||= [ localtime ])->[4] if !defined $month;
            $year   = ($lt ||= [ localtime ])->[5] if !defined $year;
        });
    }
    return $s->new_from_array( [$year+1900, $month+1, $day, 
        $hh, $mm, $ss], $zone);
}

sub _check_sum { my ($s) = @_;
  my $sum=0; $sum += $_ || 0 foreach @{$s}[c_year .. c_sec];
  return $sum;
}

sub _recalc_from_struct { 
    my $s = shift;
    $s->[c_isdst] = -1;
    $s->[c_wday]  = 0;
    $s->[c_yday]  = 0;
    $s->[c_epoch] = 0; # these are required to suppress warinngs;
    eval {
        local $SIG{__WARN__} = sub { };
        my $timecalc = $s->[c_tz] eq $GMT_TIMEZONE ?
            \&timegm : \&timelocal;
        _set_temp_tz($s->[c_tz],
            sub {
                $s->[c_epoch] = $timecalc->(
                    @{$s}[c_sec,c_min,c_hour,c_day,c_mon], 
                    $s->[c_year] + 1900);
            }
        );
    };
    return $s->_set_invalid(E_INVALID,$@) if $@;
    my $sum = $s->_check_sum;
    $s->_recalc_from_epoch;
    @$s[c_error,c_errmsg] = (($s->_check_sum != $sum ? E_RANGE : 0), "");
    return $s->_set_invalid(E_RANGE,"") if $RANGE_CHECK && $s->[c_error];
    return 1;
}

sub _recalc_from_epoch { my ($s) = @_;
    _set_temp_tz($s->[c_tz],
        sub {
            @{$s}[c_year..c_isdst] = 
                ($s->[c_tz] eq $GMT_TIMEZONE ?
                    gmtime($s->[c_epoch]) : localtime($s->[c_epoch]))
                    [5,4,3,2,1,0,6,7,8];
        }
    )
}

my $SETHASH = {
    year   => sub { shift->[c_year] = shift() - 1900 },
    _year  => sub { shift->[c_year] = shift },
    month  => sub { shift->[c_mon] = shift() - 1 },
    _month => sub { shift->[c_mon] = shift },
    day    => sub { shift->[c_day] = shift },
    hour   => sub { shift->[c_hour] = shift },
    min    => sub { shift->[c_min] = shift },
    sec    => sub { shift->[c_sec] = shift },
    tz     => sub { shift->[c_tz] = shift },
};
$SETHASH->{mon}    = $SETHASH->{month};
$SETHASH->{_mon}   = $SETHASH->{_month};
$SETHASH->{mday}   = $SETHASH->{day_of_month} = $SETHASH->{day};
$SETHASH->{minute} = $SETHASH->{min};
$SETHASH->{second} = $SETHASH->{sec};

sub clone {
    my $s = shift;
    my $new_date = $s->new_copy($s);
    while (@_) {
        my $key = shift;
        my $value = shift;
        $SETHASH->{$key}->($value,$new_date);
    };
    $new_date->_recalc_from_struct;
    return $new_date;
}

*set = *clone; # compatibility

sub year     { shift->[c_year]  +1900 }
sub _year    { shift->[c_year]  }
sub yr       { shift->[c_year]  % 100 }
sub mon      { shift->[c_mon]   +1 }
*month       = *mon;
sub _mon     { shift->[c_mon]   }
*_month      = *_mon;
sub day      { shift->[c_day]   }
*day_of_month= *mday = *day;
sub hour     { shift->[c_hour]  }
sub min      { shift->[c_min]   }
*minute      = *min;
sub sec      { shift->[c_sec]   }
*second      = *sec;
sub wday     { shift->[c_wday]  + 1 }
sub _wday    { shift->[c_wday]  }
*day_of_week = *_wday;
sub yday     { shift->[c_yday]  }
*day_of_year = *yday;
sub isdst    { shift->[c_isdst] }
*daylight_savings = \&isdst;
sub epoch    { shift->[c_epoch] }
*as_sec      = *epoch; # for compatibility
sub tz       { shift->[c_tz] }
sub tzdst    { shift->strftime("%Z") }

sub monname  { shift->strftime('%B') }
*monthname   = *monname;
sub wdayname { shift->strftime('%A') }
*day_of_weekname= *wdayname;

sub error { shift->[c_error] }
sub errmsg { my ($s) = @_;
    sprintf $ERROR_MESSAGES[ $s->[c_error] ]."\n", $s->[c_errmsg] 
}
*errstr = *errmsg;

sub new_invalid { my ($proto,$error,$errmsg) = @_;
    bless([],ref($proto) || $proto)->_set_invalid($error,$errmsg);
}

sub _set_invalid { my ($s,$error,$errmsg) = @_;
    bless($s,$s->ClassDateInvalid);
    @$s = ();
    @$s[ci_error, ci_errmsg] = ($error,$errmsg);
    return $s;
}

sub ampm { my ($s) = @_;
    return $s->[c_hour] < 12 ? "AM" : "PM"; 
}

sub meridiam { my ($s) = @_;
    my $hour = $s->[c_hour] % 12;
    if( $hour == 0 ) { $hour = 12; }
    sprintf('%02d:%02d %s', $hour, $s->[c_min], $s->ampm);
}

sub hms { sprintf('%02d:%02d:%02d', @{ shift() }[c_hour,c_min,c_sec]) }

sub ymd { my ($s)=@_;
  sprintf('%04d/%02d/%02d', $s->year, $s->mon, $s->[c_day])
}

sub mdy { my ($s)=@_;
  sprintf('%02d/%02d/%04d', $s->mon, $s->[c_day], $s->year)
}

sub dmy { my ($s)=@_;
  sprintf('%02d/%02d/%04d', $s->[c_day], $s->mon, $s->year)
}

sub array { my ($s)=@_;
  my @return=@{$s}[c_year .. c_sec];
  $return[c_year]+=1900;
  $return[c_mon]+=1;
  @return;
}

sub aref { return [ shift()->array ] }
*as_array = *aref;

sub struct {
  return ( @{ shift() }
    [c_sec,c_min,c_hour,c_day,c_mon,c_year,c_wday,c_yday,c_isdst] )
}

sub sref { return [ shift()->struct ] }

sub href { my ($s)=@_;
  my @struct=$s->struct;
  my $h={};
  foreach my $key (qw(sec min hour day _month _year wday yday isdst)) {
    $h->{$key}=shift @struct;
  }
  $h->{epoch} = $s->[c_epoch];
  $h->{year} = 1900 + $h->{_year};
  $h->{month} = $h->{_month} + 1;
  $h->{minute} = $h->{min};
  return $h;
}

*as_hash=*href;

sub hash { return %{ shift->href } }

# Thanks to Tony Olekshy <olekshy@cs.ualberta.ca> for this algorithm
# ripped from Time::Object by Matt Sergeant
sub tzoffset { my ($s)=@_;
    my $epoch = $s->[c_epoch];
    my $j = sub { # Tweaked Julian day number algorithm.
        my ($s,$n,$h,$d,$m,$y) = @_; $m += 1; $y += 1900;
        # Standard Julian day number algorithm without constant.
        my $y1 = $m > 2 ? $y : $y - 1;
        my $m1 = $m > 2 ? $m + 1 : $m + 13;
        my $day = int(365.25 * $y1) + int(30.6001 * $m1) + $d;
        # Modify to include hours/mins/secs in floating portion.
        return $day + ($h + ($n + $s / 60) / 60) / 24;
    };
    # Compute floating offset in hours.
    my $delta = _set_temp_tz($s->[c_tz],
        sub {
            24 * (&$j(localtime $epoch) - &$j(gmtime $epoch));
        }
    );
    # Return value in seconds rounded to nearest minute.
    return int($delta * 60 + ($delta >= 0 ? 0.5 : -0.5)) * 60;
}

sub month_begin { my ($s) = @_;
  my $aref = $s->aref;
  $aref->[2] = 1;
  return $s->new($aref);
}

sub month_end { my ($s)=@_;
  return $s->clone(day => 1)+'1M'-'1D';
}

sub days_in_month {
  shift->month_end->mday;
}

sub is_leap_year { my ($s) = @_;
    my $new_date;
    eval {
        $new_date = $s->new([$s->year, 2, 29],$s->tz);
    } or return 0;
    return $new_date->day == 29;
}

sub strftime { my ($s,$format)=@_;
  $format ||= "%a, %d %b %Y %H:%M:%S %Z";
  my $fmt = _set_temp_tz($s->[c_tz], sub { strftime_xs($format,$s->struct) } );
  return $fmt;
}

sub string { my ($s) = @_;
  $s->strftime($DATE_FORMAT);
}

sub subtract { my ($s,$rhs)=@_;
  if (blessed($rhs) && $rhs->isa( __PACKAGE__ )) {
    my $dst_adjust = 0;
    $dst_adjust = 60*60*( $s->[c_isdst]-$rhs->[c_isdst] ) if $DST_ADJUST;
    return $s->ClassDateRel->new($s->[c_epoch]-$rhs->[c_epoch]+$dst_adjust);
  } elsif (blessed($rhs) && $rhs->isa("Class::Date::Rel")) {
    return $s->add(-$rhs);
  } elsif ($rhs) {
    return $s->add($s->ClassDateRel->new($rhs)->neg);
  } else {
    return $s;
  }
}

sub add { my ($s,$rhs)=@_;
  local $RANGE_CHECK;
  $rhs=$s->ClassDateRel->new($rhs) unless blessed($rhs) && $rhs->isa('Class::Date::Rel');
	
  return $s unless blessed($rhs) && $rhs->isa('Class::Date::Rel');

  # adding seconds
  my $retval= $rhs->[cs_sec] ? 
    $s->new_from_scalar($s->[c_epoch]+$rhs->[cs_sec],$s->[c_tz]) :
    $s->new_copy($s);

  # adjust DST if necessary
  if ( $DST_ADJUST && (my $dstdiff=$retval->[c_isdst]-$s->[c_isdst]))  {
    $retval->[c_epoch] -= $dstdiff*60*60;
    $retval->_recalc_from_epoch;
  }
  
  # adding months
  if ($rhs->[cs_mon]) {
    $retval->[c_mon]+=$rhs->[cs_mon];
    my $year_diff= $retval->[c_mon]>0 ? # instead of POSIX::floor
      int ($retval->[c_mon]/12) :
      int (($retval->[c_mon]-11)/12);
    $retval->[c_mon]  -= 12*$year_diff;
    my $expected_month = $retval->[c_mon];
    $retval->[c_year] += $year_diff;
    $retval->_recalc_from_struct;

    # adjust month border if necessary
    if ($MONTH_BORDER_ADJUST && $retval && $expected_month != $retval->[c_mon]) {
      $retval->[c_epoch] -= $retval->[c_day]*60*60*24;
      $retval->_recalc_from_epoch;
    }
  }
  
  # sigh! We have finished!
  return $retval;
}

sub trunc { my ($s)=@_;
  return $s->new_from_array([$s->year,$s->month,$s->day,0,0,0],$s->[c_tz]);
}

*truncate = *trunc;

sub get_epochs {
  my ($lhs,$rhs,$reverse)=@_;
  unless (blessed($rhs) && $rhs->isa( __PACKAGE__ )) {
    $rhs = $lhs->new($rhs);
  }
  my $repoch= $rhs ? $rhs->epoch : 0;
  return $repoch, $lhs->epoch if $reverse;
  return $lhs->epoch, $repoch;
}

sub compare {
  my ($lhs, $rhs) = get_epochs(@_);
  return $lhs <=> $rhs;
}

sub local_timezone {
    return (tzname_xs())[0];
}

sub to_tz { my ($s, $tz) = @_;
    return $s->new($s->epoch, $tz);
}
1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Class::Date - Class for easy date and time manipulation

=head1 VERSION

version 1.1.16

=head1 SYNOPSIS

  use Class::Date qw(:errors date localdate gmdate now -DateParse -EnvC);
  
  # creating absolute date object (local time)
  $date = Class::Date->new( [$year,$month,$day,$hour,$min,$sec]);
  $date = date [$year,$month,$day,$hour,$min,$sec]; 
    # ^- "date" is an exportable function, the same as Class::Date->new
  $date = date { year => $year, month => $month, day => $day,
    hour => $hour, min => $min, sec => $sec };
  $date = date "2001-11-12 07:13:12";
  $date = localdate "2001-12-11";
  $date = now;                      #  the same as date(time)
  $date = date($other_date_object); # cloning
  ...

  # creating absolute date object (GMT)
  $date = Class::Date->new( [$year,$month,$day,$hour,$min,$sec],'GMT');
  $date = gmdate "2001-11-12 17:13";
  ...

  # creating absolute date object in any other timezone
  $date = Class::Date->new( [$year,$month,$day,$hour,$min,$sec],'Iceland' );
  $date = date "2001-11-12 17:13", 'Iceland';
  $date2 = $date->new([$y2, $m2, $d2, $h2, $m2, $s2]); 
    # ^- timezone is inherited from the $date object

  # creating relative date object
  # (normally you don't need to create this object explicitly)
  $reldate = Class::Date::Rel->new( "3Y 1M 3D 6h 2m 4s" );
  $reldate = Class::Date::Rel->new( "6Y" );
  $reldate = Class::Date::Rel->new( $secs );  # secs
  $reldate = Class::Date::Rel->new( [$year,$month,$day,$hour,$min,$sec] );
  $reldate = Class::Date::Rel->new( { year => $year, month => $month, day => $day,
    hour => $hour, min => $min, sec => $sec } );
  $reldate = Class::Date::Rel->new( "2001-11-12 07:13:12" );
  $reldate = Class::Date::Rel->new( "2001-12-11" );

  # getting values of an absolute date object
  $date;              # prints the date in default output format (see below)
  $date->year;        # year, e.g: 2001
  $date->_year;       # year - 1900, e.g. 101
  $date->yr;          # 2-digit year 0-99, e.g 1
  $date->mon;         # month 1..12
  $date->month;       # same as prev.
  $date->_mon;        # month 0..11
  $date->_month;      # same as prev.
  $date->day;         # day of month
  $date->mday;        # day of month
  $date->day_of_month;# same as prev.
  $date->hour;
  $date->min;
  $date->minute;      # same as prev.
  $date->sec;
  $date->second;      # same as prev.
  $date->wday;        # 1 = Sunday
  $date->_wday;       # 0 = Sunday
  $date->day_of_week; # same as prev.
  $date->yday;        
  $date->day_of_year; # same as prev.
  $date->isdst;       # DST?
  $date->daylight_savings; # same as prev.
  $date->epoch;       # UNIX time_t
  $date->monname;     # name of month, eg: March
  $date->monthname;   # same as prev.
  $date->wdayname;    # Thursday
  $date->day_of_weekname # same as prev.
  $date->hms          # 01:23:45
  $date->ymd          # 2000/02/29
  $date->mdy          # 02/29/2000
  $date->dmy          # 29/02/2000
  $date->meridiam     # 01:23 AM
  $date->ampm         # AM/PM
  $date->string       # 2000-02-29 12:21:11 (format can be changed, look below)
  "$date"             # same as prev.
  $date->tzoffset     # timezone-offset
  $date->strftime($format) # POSIX strftime (without the huge POSIX.pm)
  $date->tz           # returns the base timezone as you specify, eg: CET
  $date->tzdst        # returns the real timezone with dst information, eg: CEST

  ($year,$month,$day,$hour,$min,$sec)=$date->array;
  ($year,$month,$day,$hour,$min,$sec)=@{ $date->aref };
  # !! $year: 1900-, $month: 1-12

  ($sec,$min,$hour,$day,$mon,$year,$wday,$yday,$isdst)=$date->struct;
  ($sec,$min,$hour,$day,$mon,$year,$wday,$yday,$isdst)=@{ $date->sref };
  # !! $year: 0-, $month: 0-11

  $hash=$date->href; # $href can be reused as a constructor
  print $hash->{year}."-".$hash->{month}. ... $hash->{sec} ... ;
  
  %hash=$date->hash;
  # !! $hash{year}: 1900-, $hash{month}: 1-12

  $date->month_begin  # First day of the month (date object)
  $date->month_end    # Last day of the month
  $date->days_in_month # 28..31

  # constructing new date based on an existing one:
  $new_date = $date->clone;
  $new_date = $date->clone( year => 1977, sec => 14 );
  # valid keys: year, _year, month, mon, _month, _mon, day, mday, day_of_month,
  #             hour, min, minute, sec, second, tz
  # constructing a new date, which is the same as the original, but in 
  # another timezone:
  $new_date = $date->to_tz('Iceland');

  # changing date format
  {
    local $Class::Date::DATE_FORMAT="%Y%m%d%H%M%S";
    print $date       # result: 20011222000000
    $Class::Date::DATE_FORMAT=undef;
    print $date       # result: Thu Oct 13 04:54:34 1994
    $Class::Date::DATE_FORMAT="%Y/%m/%d"
    print $date       # result: 1994/10/13
  }

  # error handling
  $a = date($date_string);
  if ($a) { # valid date
    ...
  } else { # invalid date
    if ($a->error == E_INVALID) { ... }
    print $a->errstr;
  }

  # adjusting DST in calculations  (see the doc)
  $Class::Date::DST_ADJUST = 1; # this is the default
  $Class::Date::DST_ADJUST = 0;

  # "month-border adjust" flag 
  $Class::Date::MONTH_BORDER_ADJUST = 0; # this is the default
  print date("2001-01-31")+'1M'; # will print 2001-03-03
  $Class::Date::MONTH_BORDER_ADJUST = 1;
  print date("2001-01-31")+'1M'; # will print 2001-02-28

  # date range check
  $Class::Date::RANGE_CHECK = 0; # this is the default
  print date("2001-02-31"); # will print 2001-03-03
  $Class::Date::RANGE_CHECK = 1;
  print date("2001-02-31"); # will print nothing

  # getting values of a relative date object
  $reldate;              # reldate in seconds (assumed 1 month = 2_629_744 secs)
  $reldate->year;
  $reldate->mon;
  $reldate->month;       # same as prev.
  $reldate->day;
  $reldate->hour;
  $reldate->min;
  $reldate->minute;      # same as prev.
  $reldate->sec;         # same as $reldate
  $reldate->second;      # same as prev.
  $reldate->sec_part;    # "second" part of the relative date
  $reldate->mon_part;    # "month"  part of the relative date

  # arithmetic with dates:
  print date([2001,12,11,4,5,6])->truncate; 
                               # will print "2001-12-11"
  $new_date = $date+$reldate;
  $date2    = $date+'3Y 2D';   # 3 Years and 2 days
  $date3    = $date+[1,2,3];   # $date plus 1 year, 2 months, 3 days
  $date4    = $date+'3-1-5'    # $date plus 3 years, 1 months, 5 days

  $new_date = $date-$reldate;
  $date2    = $date-'3Y';      # 3 Yearss
  $date3    = $date-[1,2,3];   # $date minus 1 year, 2 months, 3 days
  $date4    = $date-'3-1-5'    # $date minus 3 years, 1 month, 5 days

  $new_reldate = $date1-$date2;
  $reldate2 = Class::Date->new('2000-11-12')-'2000-11-10';
  $reldate3    = $date3-'1977-11-10';

  $days_between = (Class::Date->new('2001-11-12')-'2001-07-04')->day;

  # comparison between absolute dates
  print $date1 > $date2 ? "I am older" : "I am younger";

  # comparison between relative dates
  print $reldate1 > $reldate2 ? "I am faster" : "I am slower";

  # Adding / Subtracting months and years are sometimes tricky:
  print date("2001-01-29") + '1M' - '1M'; # gives "2001-02-01"
  print date("2000-02-29") + '1Y' - '1Y'; # gives "2000-03-01"

  # Named interface ($date2 does not necessary to be a Class::Date object)
  $date1->string;               # same as $date1 in scalar context
  $date1->subtract($date2);     # same as $date1 - $date2
  $date1->add($date2);          # same as $date1 + $date2
  $date1->compare($date2);      # same as $date1 <=> $date2

  $reldate1->sec;               # same as $reldate1 in numeric or scalar context
  $reldate1->compare($reldate2);# same as $reldate1 <=> $reldate2
  $reldate1->add($reldate2);    # same as $reldate1 + $reldate2
  $reldate1->neg                # used for subtraction

  # Disabling Class::Date warnings at load time
  BEGIN { $Class::Date::WARNINGS=0; }
  use Class::Date;

=head1 DESCRIPTION

This module is intended to provide a general-purpose date and datetime type
for perl. You have a Class::Date class for absolute date and datetime, and have 
a Class::Date::Rel class for relative dates.

You can use "+", "-", "<" and ">" operators as with native perl data types.

Note that this module is fairly ancient and dusty. You 
might want to take a look at L<DateTime> and its related 
modules for a more standard, and maintained, Perl date
manipulation solution.

=head1 USAGE

If you want to use a date object, you need to do the following:

  - create a new object
  - do some operations (+, -, comparison)
  - get result back

=head2 Creating a new date object

You can create a date object by the "date", "localdate" or "gmdate" function, 
or by calling the Class::Date constructor.

"date" and "Class::Date->new" are equivalent, both has two arguments: The
date and the timezone.

  $date1= date [2000,11,12];
  $date2= Class::Date->new([2000,06,11,13,11,22],'GMT');
  $date2= $date1->new([2000,06,11,13,11,22]);

If the timezone information is omitted, then it first check if "new" is 
called as an object method or a class method. If it is an object method,
then it inherits the timezone from the base object, otherwise the default
timezone is used ($Class::Date::DEFAULT_TIMEZONE), which is usually set to
the local timezone (which is stored in $Class::Date::LOCAL_TIMEZONE). These
two variables are set only once to the value, which is returned by the
Class::Date::local_timezone() function. You can change these values
whenever you want.

"localdate $x" is equivalent to "date $x, $Class::Date::LOCAL_TIMEZONE", 
"gmdate $x" is equivalent to "date $x, $Class::Date::GMT_TIMEZONE".

$Class::Date::GMT_TIMEZONE is set to 'GMT' by default.

  $date1= localdate [2000,11,12];
  $date2= gmdate [2000,4,2,3,33,33];

  $date = localdate(time);

The format of the accepted input date can be:

=over 4

=item [$year,$month,$day,$hour,$min,$sec]

An array reference with 6 elements. The missing elements have default
values (year: 2000, month, day: 1, hour, min, sec: 0)

=item { year => $year, month => $month, day => $day, hour => $hour, min => $min, sec => $sec }

A hash reference with the same 6 elements as above.

=item "YYYYMMDDhhmmss"

A mysql-style timestamp value, which consist of at least 14 digit.

=item "973897262"

A valid 32-bit integer: This is parsed as a unix time.

=item "YYYY-MM-DD hh:mm:ss"

A standard ISO(-like) date format. Additional ".fraction" part is ignored, 
":ss" can be omitted.

=item additional input formats

You can specify "-DateParse" as  an import parameter, e.g:

  use Class::Date qw(date -DateParse);

With this, the module will try to load Date::Parse module, and if it find it then all 
these formats can be used as an input. Please refer to the Date::Parse
documentation.

=back

=head2 Operations

=over 4

=item addition

You can add the following to a Class::Date object:

  - a valid Class::Date::Rel object
  - anything, that can be used for creating a new Class::Date::Rel object

It means that you don't need to create a new Class::Date::Rel object every
time when you add something to the Class::Date object, it creates them
automatically:

  $date= Class::Date->new('2001-12-11')+Class::Date::Rel->new('3Y');

is the same as:

  $date= date('2001-12-11')+'3Y';

You can provide a Class::Date::Rel object in the following form:

=over 4

=item array ref

The same format as seen in Class::Date format, except the default values are
different: all zero.

=item hash ref

The same format as seen in Class::Date format, except the default values are
different: all zero.

=item "973897262"

A valid 32-bit integer is parsed as seconds.

=item "YYYY-MM-DD hh:mm:ss"

A standard ISO date format, but this is parsed as relative date date and time,
so month, day and year can be zero (and defaults to zero).

=item "12Y 6M 6D 20h 12m 5s"

This special string can be used if you don't want to use the ISO format. This
string consists of whitespace separated tags, each tag consists of a number and
a unit. The units can be:

  Y: year
  M: month
  D: day
  h: hour
  m: min
  s: sec

The number and unit must be written with no space between them.

=back

=item substraction

The same rules are true for substraction, except you can substract 
two Class::Date object from each other, and you will get a Class::Date::Rel
object:

  $reldate=$date1-$date2;
  $reldate=date('2001-11-12 12:11:07')-date('2001-10-07 10:3:21');

In this case, the "month" field of the $reldate object will be 0,
and the other fields will contain the difference between two dates;

=item comparison

You can compare two Class::Date objects, or one Class::Date object and
another data, which can be used for creating a new Class::Data object.

It means that you don't need to bless both objects, one of them can be a
simple string, array ref, hash ref, etc (see how to create a date object).

  if ( date('2001-11-12') > date('2000-11-11') ) { ... }

or 

  if ( date('2001-11-12') > '2000-11-11' ) { ... }

=item truncate

You can chop the time value from this object (set hour, min and sec to 0)
with the "truncate" or "trunc" method. It does not modify the specified
object, it returns with a new one.

=item clone

You can create new date object based on an existing one, by using the "clone"
method. Note, this DOES NOT modify the base object.

  $new_date = $date->clone( year => 2001, hour => 14 );

The valid keys are: year, _year, month, mon, _month, _mon, day, mday, 
day_of_month, hour, min, minute, sec, second, tz.

There is a "set" method, which does the same as the "clone", it exists 
only for compatibility.

=item to_tz

You can use "to_tz" to create a new object, which means the same time as
the base object, but in the different timezone.

Note that $date->clone( tz => 'Iceland') and $date->to_tz('Iceland') is not
the same! Cloning a new object with setting timezone will preserve the
time information (hour, minute, second, etc.), but transfer the time into
other timezone, while to_tz usually change these values based on the
difference between the source and the destination timezone.

=item Operations with Class::Date::Rel

The Class::Date::Rel object consists of a month part and a day part. Most
people only use the "day" part of it. If you use both part, then you can get
these parts with the "sec_part" and "mon_part" method. If you use "sec",
"month", etc. methods or if you use this object in a mathematical context,
then this object is converted to one number, which is interpreted as second.
The conversion is based on a 30.436 days month. Don't use it too often,
because it is confusing...

If you use Class::Date::Rel in an expression with other Class::Date or
Class::Date::Rel objects, then it does what is expected: 

  date('2001-11-12')+'1M' will be '2001-12-12'

and

  date('1996-02-11')+'2M' will be '1996-04-11'

=back

=head2 Accessing data from a Class::Date and Class::Date::Rel object

You can use the methods methods described at the top of the document 
if you want to access parts of the data
which is stored in a Class::Date and Class::Date::Rel object.

=head2 Error handling

If a date object became invalid, then the object will be reblessed to
Class::Date::Invalid. This object is false in boolean environment, so you can
test the date validity like this:

  $a = date($input_date);
  if ($a) { # valid date
      ...
  } else { # invalid date
      if ($a->error == E_INVALID) { ... }
      print $a->errstr;
  }

Note even the date is invalid, the expression "defined $a" always returns
true, so the following is wrong:

  $a = date($input_date);
  if (defined $a) ... # WRONG!!!!

You can test the error by getting the $date->error value. You might import
the ":errors" tag:

  use Class::Date qw(:errors);

Possible error values are:

=over 4

=item E_OK

No errors.

=item E_INVALID

Invalid date. It is set when some of the parts of the date are invalid, and
Time::Local functions cannot convert them to a valid date.

=item E_RANGE

This error is set, when parts of the date are valid, but the whole date is
not valid, e.g. 2001-02-31. When the $Class::Date::RANGE_CHECK is not set, then
these date values are automatically converted to a valid date: 2001-03-03,
but the $date->error value are set to E_RANGE. If $Class::Date::RANGE_CHECK
is set, then a date "2001-02-31" became invalid date.

=item E_UNPARSABLE

This error is set, when the constructor cannot be created from a scalar, e.g:

  $a = date("4kd sdlsdf lwekrmk");

=item E_UNDEFINED

This error is set, when you want to create a date object from an undefined
value:

  $a = Class::Date->new(undef);

Note, that localdate(undef) will create a valid object, because it calls
$Class::Date(time).

=back

You can get the error in string form by calling the "errstr" method.

=head1 DST_ADJUST

$DST_ADJUST is an important configuration option.

If it is set to true (default), then the module adjusts the date and time
when the operation switches the border of DST. With this setting, you are
ignoring the effect of DST.

When $DST_ADJUST is set to false, then no adjustment is done, the
calculation will be based on the exact time difference.

You will see the difference through an example:

  $Class::Date::DST_ADJUST=1;

  print date("2000-10-29", "CET") + "1D";
  # This will print 2000-10-30 00:00:00

  print date("2001-03-24 23:00:00", "CET") + "1D";
  # This will be 2001-03-25 23:00:00

  print date("2001-03-25", "CET") + "1D";
  # This will be 2001-03-26 00:00:00


  $Class::Date::DST_ADJUST=0;

  print date("2000-10-29", "CET") + "1D";
  # This will print 2000-10-29 23:00:00

  print date("2001-03-24 23:00:00", "CET") + "1D";
  # This will be 2001-03-26 00:00:00

=head1 MONTHS AND YEARS

If you add or subtract "months" and "years" to a date, you may get wrong 
dates, e.g when you add one month to 2001-01-31, you expect to get
2001-02-31, but this date is invalid and converted to 2001-03-03. Thats' why

  date("2001-01-31") + '1M' - '1M' != "2001-01-31"

This problem can occur only with months and years, because others can 
easily be converted to seconds.

=head1 MONTH_BORDER_ADJUST

$MONTH_BORDER_ADJUST variable is used to switch on or off the 
month-adjust feature. This is used only when someone adds months or years to
a date and then the resulted date became invalid. An example: adding one
month to "2001-01-31" will result "2001-02-31", and this is an invalid date.

When $MONTH_BORDER_ADJUST is false, this result simply normalized, and
becomes "2001-03-03". This is the default behaviour.

When $MONTH_BORDER_ADJUST is true, this result becomes "2001-02-28". So when
the date overflows, then it returns the last day insted.

Both settings keep the time information.

=head1 TIMEZONE SUPPORT

Since 1.0.11, Class::Date handle timezones natively on most platforms (see
the BUGS AND LIMITATIONS section for more info).

When the module is loaded, then it determines the local base timezone by
calling the Class::Date::local_timezone() function, and stores these values
into two variables, these are: $Class::Date::LOCAL_TIMEZONE and
$Class::Date::DEFAULT_TIMEZONE. The first value is used, when you call the
"localdate" function, the second value is used, when you call the "date"
function and you don't specify the timezone. There is
a $Class::Date::GMT_TIMEZONE function also, which is used by the "gmdate"
function, this is set to 'GMT'.

You can query the timezone of a date object by calling the $date->tz
method. Note this value returns the timezone as you specify, so if you
create the object with an unknown timezone, you will get this back. If you
want to query the effective timezone, you can call the $date->tzdst method.
This method returns only valid timezones, but it is not necessarily the
timezone which can be used to create a new object. For example
$date->tzdst can return 'CEST', which is not a valid base timezone, because
it contains daylight savings information also. On Linux systems, you can
see the possible base timezones in the /usr/share/zoneinfo directory.

In Class::Date 1.1.6, a new environment variable is introduced:
$Class::Date::NOTZ_TIMEZONE. This variable stores the local timezone, which
is used, when the TZ environment variable is not set. It is introduced,
because there are some systems, which cannot handle the queried timezone
well. For example the local timezone is CST, it is returned by the tzname()
perl function, but when I set the TZ environment variable to CST, it
works like it would be GMT.  The workaround is NOTZ_TIMEZONE: if a date
object has a timezone, which is the same as NOTZ_TIMEZONE, then the TZ
variable will be removed before each calculation. In normal case, it would
be the same as setting TZ to $NOTZ_TIMEZONE, but some systems don't like
it, so I decided to introduce this variable. The
$Class::Date::NOTZ_TIMEZONE variable is set in the initialization of the
module by removing the TZ variable from the environment and querying the
tzname variable.

=head1 INTERNALS

This module uses operator overloading very heavily. I've found it quite stable,
but I am afraid of it a bit.

A Class::Date object is an array reference.

A Class::Date::Rel object is an array reference, which contains month and
second information. I need to store it as an array ref, because array and month
values cannot be converted into seconds, because of our super calendar.

You can add code references to the @Class::Date::NEW_FROM_SCALAR and
@Class::Date::Rel::NEW_FROM_SCALAR. These arrays are iterated through when a
scalar-format date must be parsed. These arrays only have one or two values
at initialization. The parameters which the code references got are the same 
as the "new" method of each class. In this way, you can personalize the date
parses as you want.

As of 0.90, the Class::Date has been rewritten. A lot of code and design
decision has been borrowed from Matt Sergeant's Time::Object, and there will
be some incompatibility with the previous public version (0.5). I tried to
keep compatibility methods in Class::Date. If you have problems regarding
this, please drop me an email with the description of the problem, and I will
set the compatibility back.

Invalid dates are Class::Date::Invalid objects. Every method call on this
object and every operation with this object returns undef or 0.

=head1 DEVELOPMENT FOCUS

This module tries to be as full-featured as can be. It currently lacks
business-day calculation, which is planned to be implemented in the 1.0.x
series.

I try to keep this module not to depend on other modules and I want this
module usable without a C compiler.

Currently the module uses the POSIX localtime function very extensively.
This makes the date calculation a bit slow, but provides a rich interface,
which is not provided by any other module. When I tried to redesign the
internals to not depend on localtime, I failed, because there are no other
way to determine the daylight savings information.

=head1 SPEED ISSUES

There are two kind of adjustment in this module, DST_ADJUST and
MONTH_BORDER_ADJUST. Both of them makes the "+" and "-" operations slower. If
you don't need them, switch them off to achieve faster calculations.

In general, if you really need fast date and datetime calculation, don't use 
this module. As you see in the previous section, the focus of development is 
not the speed in 1.0.  For fast date and datetime calculations, use 
Date::Calc module instead.

=head1 THREAD SAFETY and MOD_PERL

This module is NOT thread-safe, since it uses C library functions, which
are not thread-safe. Using this module in a multi-threaded environment can
cause timezones to be messed up. I did not put any warning about it, you
have to make sure that you understand this!

Under some circumstances in a mod_perl environment, you require the Env::C
module to set the TZ variable properly before calling the time functions. I
added the -EnvC import option to automatically load this module if it is
not loaded already. Please read the mod_perl documentation about the
environment variables and mod_perl to get the idea why it is required
sometimes:

  http://perl.apache.org/docs/2.0/user/troubleshooting/troubleshooting.html#C_Libraries_Don_t_See_C__ENV__Entries_Set_by_Perl_Code

You are sure have this problem if the $Class::Date::NOTZ_TIMEZONE variable
is set to 'UTC', althought you are sure that your timezone is not that. Try
-EnvC in this case, but make sure that you are not using it in a
multi-threaded environment!

=head1 OTHER BUGS AND LIMITATIONS

=over 4

=item *

Not all date/time values can be expressed in all timezones. For example:

  print date("2010-10-03 02:00:00", "Australia/Sydney")
  # it will print 2010-10-03 03:00:00

No matter how hard you try you, you are not going to be able to express the
time in the example in that timezone. If you don't need the timezone
information and you want to make sure that the calculations are always
correct, please use GMT as a timezone (the 'gmdate' function can be a
shortcut for it). In this case, you might also consider turning off
DST_ADJUST to speed up the calculation.

=item *

I cannot manage to get the timezone code working properly on ActivePerl
5.8.0 on win XP and earlier versions possibly have this problem also. If
you have a system like this, then you will have only two timezones, the
local and the GMT. Every timezone, which is not equal to
$Class::Date::GMT_TIMEZONE is assumed to be local. This seems to be caused
by the win32 implementation of timezone routines. I don't really know how
to make this thing working, so I gave up this issue. If anyone know a
working solution, then I will integrate it into Class::Date, but until
then, the timezone support will not be available for these platforms.

=item *

Perl 5.8.0 and earlier versions has a bug in the strftime code on some
operating systems (for example Linux), which is timezone related. I
recommend using the strftime, which is provided with Class::Date, so don't
try to use the module without the compiled part. The module will not work
with a buggy strftime - the test is hardcoded into the beginning of the
code. If you anyway want to use the module, remove the hardcoded "die" from
the module, but do it for your own risk.

=item *

This module uses the POSIX functions for date and
time calculations, so it is not working for dates beyond 2038 and before 1902.

I don't know what systems support dates in 1902-1970 range, it may not work on
your system. I know it works on the Linux glibc system with perl 5.6.1
and 5.7.2. I know it does not work with perl 5.005_03 (it may be the bug of
the Time::Local module). Please report if you know any system where it does
_not_ work with perl 5.6.1 or later.

I hope that someone will fix this with new time_t in libc. If you really need
dates over 2038 and before 1902, you need to completely rewrite this module or
use Date::Calc or other date modules.

=item *

This module uses Time::Local, and when it croaks, Class::Date returns
"Invalid date or time" error message. Time::Local is different in the 5.005
and 5.6.x (and even 5.7.x) version of perl, so the following code will
return different results:

  $a = date("2006-11-11")->clone(year => -1);

In perl 5.6.1, it returns an invalid date with error message "Invali date or
time", in perl 5.005 it returns an invalid date with range check error. Both
are false if you use them in boolean context though, only the error message
is different, but don't rely on the error message in this case. It however
works in the same way if you change other fields than "year" to an invalid
field.

=back

=head1 SUPPORT

Class::Date is free software. IT COMES WITHOUT WARRANTY OF ANY KIND.

If you have questions, you can send questions directly to me:

  dlux@dlux.hu

=head1 WIN32 notes

You can get a binary win32 version of Class::Date from Chris Winters' .ppd
repository with the following commands:

For people using PPM2:

  c:\> ppm
  PPM> set repository oi http://openinteract.sourceforge.net/ppmpackages/
  PPM> set save
  PPM> install Class-Date

For people using PPM3:

  c:\> ppm
  PPM> repository http://openinteract.sourceforge.net/ppmpackages/
  PPM> install Class-Date

The first steps in PPM only needs to be done at the first time. Next time
you just run the 'install'.

=head1 COPYRIGHT

Copyright (c) 2001 Szabó, Balázs (dLux)

All rights reserved. This program is free software; you can redistribute it 
and/or modify it under the same terms as Perl itself.

Portions Copyright (c) Matt Sergeant

=head1 CREDITS

  - Matt Sergeant <matt@sergeant.org>
    (Lots of code are borrowed from the Time::Object module)
  - Tatsuhiko Miyagawa <miyagawa@cpan.org> (bugfixes)
  - Stas Bekman <stas@stason.org> (suggestions, bugfix)
  - Chris Winters <chris@cwinters.com> (win32 .ppd version)
  - Benoit Beausejour <bbeausej@pobox.com>
    (Parts of the timezone code is borrowed from his Date::Handler module)

=head1 SEE ALSO

perl(1).
Date::Calc(3pm).
Time::Object(3pm).
Date::Handler(3pm).

=head1 AUTHORS

=over 4

=item *

dLux (Szabó, Balázs) <dlux@dlux.hu>

=item *

Gabor Szabo <szabgab@gmail.com>

=item *

Yanick Champoux <yanick@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2018, 2014, 2010, 2003 by Balázs Szabó.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
