#!/usr/bin/perl
require ESL;

use lib '.';

my $ESLPORT = "8021";
my $ESLPASSWORD = "xxxxxxxx";


my $ha = shift;

###ESL::eslSetLogLevel(7);


my $args = join(" ", @ARGV);


my $timestamp = time();
my $filename = '/tmp/'.$ha.'_jitter.log';

open FH, ">>",$filename or die "cannot open $filename\n";


select(STDERR);
$| = 1;
select(STDOUT); # default
$| = 1;



##my $con = new ESL::ESLconnection("localhost", "8021", "ClueCon");
my $con = new ESL::ESLconnection($host, $ESLPORT, $ESLPASSWORD);
$con->events("plain","HEARTBEAT");



if ( $con->connected() ) {
   print 'Yes, we are connected'."\n";
}

my $heartbeat   = 0;

print "wait for events\n";

print FH "      DATETIME,              sessions,       sessions_high,    sessions_high_per_sec       idle\n";

while ( $con->connected() ) {
    my $date    = localtime();

    my $e = $con->api("timer_test", "20 240");
    my $resp =  $e->getBody();
   #### print  "$date\t$resp\n";

    ##### Avg: 20.000ms Total Time: 100.001ms

    my ($t1, $t2) = ($resp =~ /^Avg: (\d{2}).(\d{3})ms Total Time:/);
  
    my $t3 = $t1.$t2;

    my $jitter = abs($t3 - 20000);
    print " $date jitter:  $jitter   ($t3)\n";
    print FH  " $date jitter:  $jitter   ($t3)\n";
    if ($jitter > 20000) {
       print "$resp\n";
       print "FH $resp\n";
    } 

    $heartbeat++;
    if ($heartbeat > 12) {
        close FH;
        exit;
    }

}

exit;

