#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define BUFFER_SIZE 100
char buffer[BUFFER_SIZE];
struct tm x;

void print_it(const char *text)
{
    strftime(buffer, BUFFER_SIZE-1, "%Z", &x);
    printf("%20s: %4s,%4s, %02d:%02d:%02d, %02d-%02d-%03d %1d,%03d,%1d,%s:%s\n",
        text, tzname[0], tzname[1], 
        x.tm_sec, x.tm_min, x.tm_hour, x.tm_mday, x.tm_mon, x.tm_year, x.tm_wday, x.tm_yday,x.tm_isdst,
        asctime(&x), buffer);
}

int main (int argc, char** argv)
{
    time_t t = 1020463262;

    unsetenv("LANG");
    localtime_r(&t, &x);
    print_it("Default");

    setenv("TZ","GMT",1);
    tzset();
    localtime_r(&t, &x);
    print_it("GMT");

    unsetenv("TZ");
    tzset();
    localtime_r(&t, &x);
    print_it("Without TZ");

    setenv("TZ","CET",1);
    tzset();
    localtime_r(&t, &x);
    print_it("Without TZ");

    return 0;
}
