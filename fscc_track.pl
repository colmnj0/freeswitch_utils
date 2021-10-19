#!/usr/bin/perl

# This script uses the no longer doc'ed "callcenter_track" setting in mod_callcenter
#  Setting this prevents the agent receiving calls from the callcenter while being 
#  on an outbound call-command.
#
#  Colm Quinn 2019.
#
#  Usiage:
#     fscc_tracl.pl  [freeswitch esl ip] [fs domain] [-logtofile] [-test]
#

use lib '.';

require ESL;

my $pwd = 'xxxxxx';          <<===== set


###ESL::eslSetLogLevel(7);
my $host = shift;
my $domain = shift;
my $option = shift;
my $testrun = shift;




my $command = shift;
my $args = join(" ", @ARGV);


select(STDERR);
$| = 1;
select(STDOUT); # default
$| = 1;

my $epoch = time();
my $filename_base = "/tmp/$host".'_smartcc_';
my $filename = "$filename_base"."$epoch";


if ($option eq "-logtofile")
{
  open FH, ">",$filename or die "cannot open $filename\n";

  { my $ofh = select FH;
    $| = 1;
    select $ofh;
  }

  print "Logging to $filename\n";
  select FH;
}

my $con = new ESL::ESLconnection($host, "8021", "xxxxxxx");
$con->events("plain", "HEARTBEAT CHANNEL_CREATE CUSTOM callcenter::info ");



if ( $con->connected() ) {
   print 'Yes, we are connected'."\n";
}
else {
   print "Unable to connect to $host\n";
   exit;
}


print  "#####################################################\n";
print  "    Staring checkoint\n";
print  "#####################################################\n";


my @users = ();
my @states = ();

$e = $con->api("callcenter_config", "agent list");

$resp =  $e->getBody();
@rarray = split("\n",$resp);

foreach my $x (@rarray) {
    if ($x =~ /$domain/) {
       print  "$x\n";
    }
}


print  "\n\nAgent List\n";

foreach my $x (@rarray) {
    if ($x =~ /$domain/) {
       my @agent = split(/\|/, $x);

       my @contact = split(/user\//, $agent[4]);
       print  "$agent[0] $contact[1] $agent[5]  $agent[6]\n";
       $users{$contact[1]} = $agent[0];                                      # hash table
       $status{$agent[0]}  = $agent[5];
    }
}


##system("/bin/cat $filename");


print  "\n\n";
print  "#####################################################\n";
print  "    Wait for events\n";
print  "#####################################################\n\n";

my $linecount = 0;

while ( $con->connected() ) {
    my $e = $con->recvEventTimed(0);
    my $ev_name = $e->getHeader("Event-Name");

    ###    print "DEBUG $ev_name\n";

    if ($ev_name eq "CUSTOM") {

       my $ccaction = $e->getHeader("CC-Action");
       my $ccagent  = $e->getHeader("CC-Agent");
       my $ccqueue  = $e->getHeader("CC-Queue");


        if ($ccaction eq "agent-status-get") {
         next; 
       }
       if ($ccaction eq "agent-state-get") {
         next;
       }

       #  change of status

       if ($ccaction eq "agent-add") { 
          my $e_list = $con->api("callcenter_config", "agent list");
          my $e_list_resp =  $e_list->getBody();
          my @list_array = split("\n",$e_list_resp);
          my @list_agent = split(/\|/, $x);

          my @contact = split(/user\//, $list_agent[4]);
          print  "ADD $agent[0] $contact[1] $agent[5]  $agent[6]\n";
          $users{$contact[1]} = $agent[0];                                      # hash table
          $status{$agent[0]}  = $agent[5];
          $linecount++;
       }
       elsif ($ccaction eq "agent-status-change") {
          my $agentstatus = $e->getHeader("CC-Agent-Status");
          $status{$ccagent}  = $agentstatus;
       }
 
    }    ## end of if CUSTOM
	
	# Now look at CHANNEL_CREATEs to see if any come from one of the agents we know about.
    elsif ($ev_name eq "CHANNEL_CREATE") {    
       my $direction =  $e->getHeader("Call-Direction");
       if ($direction eq "inbound") {
         my $context   =  $e->getHeader("Caller-Context");
         my $extension =  $e->getHeader("Caller-Orig-Caller-ID-Number");

         my $contact = "$extension".'@'."$context";

         if ( exists($users{$contact} ) ) {
            my $ccagent  = $users{$contact};

            my $ccstatus = $status{$ccagent};
            if ($ccstatus eq "Available") {
               my $date    = localtime();
               my $uuid = $e->getHeader("Unique-ID");
               print "CMD: $date $uuid callcenter_track $ccagent\n";
               if ($testrun ne "-test") { 
                 my $cmd = 'sendmsg '.$uuid."\n".'call-command: execute'."\n".'execute-app-name: callcenter_track'."\n".'execute-app-arg:'." $ccagent"."\n\n";
                 my $resp = $con->sendRecv($cmd);
               }
               ####print "RESP [\n"."$cmd"."]\n$resp\n";
            }
         }
       } 
    }

    ## if we are using a logfile wrap it at 10,000 records 
    if ($option eq "-logtofile" && $linecount == 10000) {   
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

}

