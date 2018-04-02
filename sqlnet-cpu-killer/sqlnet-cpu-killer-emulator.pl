#!/u01/app/oracle/product/11.2.0/db/perl/bin/perl

# template for DBI programs

use warnings;
use FileHandle;
use DBI;
use strict;

my($localDB, $remoteDB, $username, $password) = 
(
	'js03',
	'js02',
	'scott',
	'tiger'
) ;


my $localDBH = DBI->connect(
	'dbi:Oracle:' . $localDB, 
	$username, $password, 
	{ 
		RaiseError => 1, 
		AutoCommit => 0
	} 
);

die "Connect to  $localDB failed \n" unless $localDBH;

my $remoteDBH = DBI->connect(
	'dbi:Oracle:' . $remoteDB, 
	$username, $password, 
	{ 
		RaiseError => 1, 
		AutoCommit => 0
	} 
);

die "Connect to  $remoteDB failed \n" unless $remoteDBH;

sleep 99999;

$localDBH->disconnect;
$remoteDBH->disconnect;

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



