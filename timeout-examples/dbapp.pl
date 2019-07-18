#!/usr/bin/env perl

# template for DBI programs

use warnings;
use FileHandle;
use DBI;
use strict;
use English;
use Data::Dumper;

use Getopt::Long;

my %optctl = ();

my($killDBH, $db, $username, $password, $connectionMode,$sleep) = (0,'','','',0,60);

Getopt::Long::GetOptions(
	\%optctl, 
	"database=s" => \$db,
	"username=s" => \$username,
	"password=s" => \$password,
	"sleep=s" => \$sleep,
	"kill-dbh!" => \$killDBH,
	"sysdba!" ,
	"z","h","help");

if ( $optctl{sysdba} ) { $connectionMode = 2 }

if ( ! $db ) {
	usage(1);
}

if ( ! $username ) {
	usage(2);
}

if ( ! $password ) {
	usage(3);
}


#print "USERNAME: $username\n";
#print "DATABASE: $db\n";
#print "PASSWORD: $password\n";
#print "CONNECT MODE: $connectionMode\n";
#exit;

my $dbh = DBI->connect(
	'dbi:Oracle:' . $db, 
	$username, $password, 
	{ 
		RaiseError => 1, 
		AutoCommit => 0,
		ora_session_mode => $connectionMode
	} 
	);

die "Connect to  $db failed \n" unless $dbh;
$dbh->{RowCacheSize} = 100;

my $sql=q{select
	s.username,
	s.sid,
	s.serial#,
	p.spid spid,
	to_char(logon_time, 'yyyy-mm-dd hh24:mi:ss') logon_time
from v$session s, v$process p
where userenv('SESSIONID') = s.audsid
	and p.addr(+) = s.paddr};


my $sth = $dbh->prepare($sql);
$sth->execute;
my ($logonName,$sid,$serial,$pid,$logonTime) = $sth->fetchrow_array;
$sth->finish;

print qq{
        User: $logonName
         SID: $sid
      Serial: $serial
  Logon Date: $logonTime
      OS PID: $pid
};

if ($killDBH){ undef $dbh }

sleep $sleep;

if (! $killDBH ) { $dbh->disconnect }

sub usage {
	my $exitVal = shift;
	$exitVal = 0 unless defined $exitVal;
	use File::Basename;
	my $basename = basename($0);
	print qq/

usage: $basename

  -database      target instance
  -username      target instance account name
  -password      target instance account password
  -sysdba        logon as sysdba
  -sysoper       logon as sysoper

  example:

  $basename -database dv07 -username scott -password tiger -sysdba 
/;
   exit $exitVal;
};



