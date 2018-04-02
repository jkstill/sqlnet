#!/usr/local/bin/perl -w

# template for DBI programs

use warnings;
use FileHandle;
use DBI;
use strict;
use Time::HiRes qw( usleep);


my($db, $username, $password) = 
(
	'//192.168.1.49:1521/js03',
	'scott',
	'tiger'
) ;


my $dbh = DBI->connect(
	'dbi:Oracle:' . $db, 
	$username, $password, 
	{ 
		RaiseError => 1, 
		AutoCommit => 0
	} 
);

# array size of 1
$dbh->{RowCacheSize} = 1;

printf "\n\nPlease press <ENTER> when ready:\n";
my $dummy=<>;
printf "Thank you\n";

my $sql='select level id from dual connect by level <= 1000000';

my $sth = $dbh->prepare($sql);
$sth->execute;

while ( my ($id) = @{$sth->fetchrow_arrayref}) {

	print "ud: $id\n";

	usleep(500000); # us
}

die "Connect to  $db failed \n" unless $dbh;

$dbh->disconnect;

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



