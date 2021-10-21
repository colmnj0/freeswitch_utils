#!/usr/bin/perl

#
# Monitor a callcenter
#  ./fscc_monitor.pl [host] [domain]
#  report written to /tmp/[domain]_cc_[timestamp]
#
#


require ESL;

my $ESLPORT = "8021";
my $ESLPASSWORD = "xxxxxxxx";


###ESL::eslSetLogLevel(7);
my $host = shift;
my $domain = shift;


my $args = join(" ", @ARGV);


select(STDERR);
$| = 1;
select(STDOUT); # default
$| = 1;

my $epoch = time();
my $filename_base = "/tmp/$domain".'_cc_';
my $filename = "$filename_base"."$epoch";

open FH, ">",$filename or die "cannot open $filename\n";

{ my $ofh = select FH;
  $| = 1;
  select $ofh;
}

print "Logging to $filename\n";




my $con = new ESL::ESLconnection($host, $ESLPORT, $ESLPASSWORD);
$con->events("plain", "CUSTOM callcenter::info");


if ( $con->connected() ) {
   print 'Yes, we are connected'."\n";
}
else {
   print "Unable to connect to $host\n";
   exit;
}


print FH "#####################################################\n";
print FH "    Staring checkoint\n";
print FH "#####################################################\n";


my @users = ();

my $e = $con->api("show", "registrations");
my $resp =  $e->getBody();
my @users = split("\n",$resp);
print FH $#users."\n";
print FH "$users[0]\n";

foreach my $x (@users) {
    if ($x =~ /$domain/) {
       print FH "$x\n";
       my @u = split(/,/, $x);
       print FH  "$u[0]\n";
    }
}

print FH "\n\n";
print FH "\n Call centers \n";

my @qs = ();

$e = $con->api("callcenter_config", "queue list");
$resp =  $e->getBody();
@qs = split("\n",$resp);
print FH $#qs."\n";
print FH "$qs[0]\n";

foreach my $x (@qs) {
    if ($x =~ /$domain/) {
       print FH "$x\n";
    }
}

print FH "\n\n";
print FH "\n Call center agents \n";

$e = $con->api("callcenter_config", "agent list");
##print $e->getBody();
$resp =  $e->getBody();
@rarray = split("\n",$resp);
print FH $#rarray."\n";
print FH "$rarray[0]\n";
foreach my $x (@rarray) {
    if ($x =~ /$domain/) {
       print FH "$x\n";
    }
}

print FH "\n\n";
print FH "\n Call centers tiers \n";

$e = $con->api("callcenter_config", "tier list");
$resp =  $e->getBody();
my @tiers = split("\n",$resp);
print FH $#tiers."\n";
print FH "$tiers[0]\n";

foreach my $x (@tiers) {
    if ($x =~ /$domain/) {
       print FH "$x\n";
    }
}


print FH "\n\nRegistered Users\n";

foreach my $x (@users) {
    if ($x =~ /$domain/) {
       my @u = split(/,/, $x);
       print FH "$u[0]\n";
    }
}

print FH "\n\nAgent List\n";

foreach my $x (@rarray) {
    if ($x =~ /$domain/) {
       my @agent = split(/\|/, $x);
       print FH "$agent[0] $agent[5]  $agent[6]\n";
    }
}

print FH "\n\nQueue->Agent\n";

foreach my $x (@tiers) {
    if ($x =~ /$domain/) {
       my @t = split(/\|/, $x);
       print FH "$t[0]   ==>  $t[1]      $t[3] $t[4]\n";
    }
}

print FH "\n\n Available agents by queue \n";

foreach my $x  (@qs) {
    if ($x =~ /$domain/) {
       my @t = split(/\|/, $x);
       $e = $con->api("callcenter_config", "queue list agents $t[0] Available");
       $resp =  $e->getBody();
       my @avails = split("\n",$resp);
       print FH "$t[0]\n";
       foreach $available (@avails) {
          if ($available =~ /$domain/) {
             my @t2 = split(/\|/, $available);
             print FH "       $t2[0]\n";
          }
       }
       print FH "\n";
    }
}





print FH "\n\n";
print FH "#####################################################\n";
print FH "    Wait for events\n";
print FH "#####################################################\n\n";

my $linecount = 0;

while ( $con->connected() ) {
    my $e = $con->recvEventTimed(0);
    my $ccaction = $e->getHeader("CC-Action");
    my $ccagent  = $e->getHeader("CC-Agent");
    my $ccqueue  = $e->getHeader("CC-Queue");
  

    my $epoch1   = $e->getHeader("Event-Date-Timestamp");
##    my $epoch      = substr($epoch1, 0, 10);

###    my $epoch   = time();
###    my $date    = localtime($epoc);
    my $date    = localtime();
###    print "$date\n";

    if ($ccaction eq "agent-status-get") {
       next; 
    }
    if ($ccaction eq "agent-state-get") {
       next;
    }

###    print "$epoch1 $epoch $date\n";
##    print "test - $ccagent $ccaction\n";

    if ($ccagent =~ /$domain/ || $ccqueue =~ /$domain/) { 

#  change of status

       if ($ccaction eq "agent-add") { 
          print FH "ADD: $date addagent     $ccagent\n";
       }
       elsif ($ccaction eq "agent-status-change") {
          my $agentstatus = $e->getHeader("CC-Agent-Status");
          print FH "STATUS: $date $ccagent     $agentstatus\n"; 
       }
       elsif ($ccaction eq "agent-max-no-answer") {
          print FH "STATUS: $date max-no-answer  $ccagent\n";
       }   
       elsif ($ccaction eq "agent-state-change") {
          my $state = $e->getHeader("CC-Agent-State");
          print FH "STATE: $date  $state  $ccagent\n";
       }
#  call joins a queue
       elsif ($ccaction eq "member-queue-start") {
          my $cid     =  $e->getHeader("CC-Member-CID-Number"); 
          print FH "START: $date $ccqueue $cid\n";
       }
      elsif ($ccaction eq "member-queue-resume") {
          my $cid     =  $e->getHeader("CC-Member-CID-Number");
          my $reason  =  $e->getHeader("CC-Hangup-Cause");
          print FH "START: $date $ccqueue $cid (resume)\n";
      }
#  call an agent
      elsif  ($ccaction eq "agent-offering") {
          my $cid     =  $e->getHeader("CC-Member-CID-Number");
          print FH "CALL: $date $ccagent $ccqueue $cid\n";
      }
# answer
      elsif ($ccaction eq "bridge-agent-start") {
          my $cid     =  $e->getHeader("CC-Member-CID-Number");
          print FH "BRIDGE: $date $ccagent $ccqueue $cid\n";   
      }
# fails
      elsif ($ccaction eq "bridge-agent-fail") {
          my $reason  =  $e->getHeader("CC-Hangup-Cause");
          my $cid     =  $e->getHeader("CC-Member-CID-Number"); 
          print FH "FAILED: $date $ccqueue  $ccagent $reason $cid\n";          
      }    
# call hits/leaves the call center
      elsif ($ccaction eq "member-queue-end") {
          my $cid     =  $e->getHeader("CC-Member-CID-Number");
          my $reason  =  $e->getHeader("CC-Hangup-Cause");
          print FH "END: $date $ccqueue  $reason $cid\n";
      }
# count 
      elsif ($ccaction eq "members-count") {
          my $cccount =  $e->getHeader("CC-Count");
          print FH "COUNT: $date $ccqueue $cccount\n";
      }
      else {
          print FH "$ccaction: $date $ccqueue $ccagent\n"; 
      } 

      $linecount++;
      if ($linecount == 10000) {
        $epoch = time();
        $filename = "$filename_base"."$epoch";
        close FH;
        open FH, ">",$filename or die "cannot open $filename\n";
        { my $ofh = select FH;
           $| = 1;
           select $ofh;
        }
        print "Logging to $filename\n";
        $linecount = 0;
      }


    }   ## end of domain match
}


# ha0  192.58.0.220
# ha4  192.58.0.40 
# ha9  172.16.2.10
# ha10 172.16.2.13
