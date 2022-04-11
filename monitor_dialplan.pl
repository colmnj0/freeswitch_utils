#!/usr/bin/perl

use lib '.';
use lib '/mnt/nas/tools/';

use hatoip;

require ESL;


###ESL::eslSetLogLevel(7);
##my $host = shift;

my $ha = shift;
my $extension = shift;

my $extension_l = length($extension);

print "extension length = $extension_l\n";


if ($extension eq "any") {
   if ($#ARGV < 0) {
      print "A domain is required if logging all numbers $#ARGV \n";
      exit;
   } 
}

my $domain = "any";

if ($#ARGV > -1) {
   $domain = shift;
}

if ($domain eq "any" && $extension_l < 5) {
   print "A domain is required if logging not logging a DID number \n";
   exit;
}


my $host = hatoip($ha);

select(STDERR);
$| = 1;
select(STDOUT); # default
$| = 1;

my $epoch = time();
my $filename_base = "/tmp/$extension".'_'.$domain.'_dialplan_';
my $filename = "$filename_base"."$epoch";


open FH, ">",$filename or die "cannot open $filename\n";

{ my $ofh = select FH;
  $| = 1;
  select $ofh;
}

print "Extension: $extension  Domain: $domain   Host: $host\n";
print "Logging to $filename\n";


my $con = new ESL::ESLconnection($host, $ESLPORT, $ESLPASSWORD);
$con->events("plain", "CHANNEL_CREATE CHANNEL_DESTROY PRIVATE_COMMAND CHANNEL_EXECUTE");



if ( $con->connected() ) {
   print 'Yes, we are connected'."\n";
}
else {
   print "Unable to connect to $host\n";
   exit;
}

my %uuids = ();


$linecount = 0;


while ( $con->connected() ) {

   my $e = $con->recvEventTimed(0);

   my $date    = localtime();
   my $uuid   = $e->getHeader("Unique-ID");

   my $evname = $e->getHeader("Event-Name"); 
   my $context = $e->getHeader("Caller-Context");

#####   print "$evname  $uuid $context\n"; 

   if ($evname eq "CHANNEL_CREATE") {
	  my $direction = $e->getHeader("Call-Direction");	
      if ($direction eq "inbound") {
         my $number   = $e->getHeader("Caller-Destination-Number");
         if ( ($extension eq "any" && $context eq $domain)      ||
              ($extension eq $number &&  $context eq "any")     ||
              ($extension eq $number &&  $context eq "public")  ||
              ($extension eq $number &&  $context eq $domain)  ) { 
                 $uuids{$uuid} = "REPORT ".$number."       ".$uuid."\n"; 
                 print "Create $uuid $context\n";          
         }
      }	
   }  
   elsif ($evname eq "CHANNEL_DESTROY") {
      if (exists ($uuids{$uuid} )) {
         print "Destroy $uuid $context\n";
         my $plan =  $uuids{$uuid};
         print FH $plan."\n";
         delete $uuids{$uuid};
         $linecount++;
         if ($linecount > 100) {
            exit;
         }   
      }
   }
   elsif ($evname eq "CHANNEL_EXECUTE") {
      if (exists ( $uuids{$uuid} )) {
         my $app      =  $e->getHeader("Application");
         my $app_data =  $e->getHeader("Application-Data");
         my $plan  = $uuids{$uuid};
         my $plan2 = $plan."Dialplan ".$app."=".$app_data."\n";
         #####print "EXEC $uuid $app\n";
         $uuids{$uuid} = $plan2; 
      }
   }
   elsif ($evname eq "PRIVATE_COMMAND") {
      if (exists ( $uuids{$uuid} )) {
         my $cmd      =  $e->getHeader("call-command");
         my $app      =  $e->getHeader("execute-app-name");
         my $app_data =  $e->getHeader("execute-app-arg");
         ##### print "CMD  $uuid $app\n";
         my $plan  = $uuids{$uuid};
         my $plan2 = $plan."Command  ".$cmd."=".$app." ".$app_data."\n";
         $uuids{$uuid} = $plan2;
      }
   }

}  ## end while




