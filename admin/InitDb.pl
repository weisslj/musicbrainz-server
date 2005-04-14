#!/home/httpd/musicbrainz/mb_server/cgi-bin/perl -w
#____________________________________________________________________________
#
#   MusicBrainz -- the open internet music database
#
#   Copyright (C) 2002 Robert Kaye
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
#   $Id$
#____________________________________________________________________________

use FindBin;
use lib "$FindBin::Bin/../cgi-bin";

use MusicBrainz;
use DBDefs;

my $SYSTEM = MusicBrainz::Server::Database->get("SYSTEM");
my $READWRITE = MusicBrainz::Server::Database->get("READWRITE");
my $READONLY = MusicBrainz::Server::Database->get("READONLY");

my $isrep = &DBDefs::DB_IS_REPLICATED;
my $opts = $READWRITE->shell_args;
my $psql = "psql";
my $with_replication = 0;
my $path_to_pending_so;

use Getopt::Long;
use strict;

my $fEcho = 0;
my $fQuiet = 0;

my $sqldir = "$FindBin::Bin/sql";
-d $sqldir or die "Couldn't find SQL script directory";

sub RunSQLScript
{
	my ($file, $startmessage) = @_;
	$startmessage ||= "Running sql/$file";
	print localtime() . " : $startmessage ($file)\n";

	my $echo = ($fEcho ? "-e" : "");
	my $stdout = ($fQuiet ? ">/dev/null" : "");

	open(PIPE, "$psql $echo -f $sqldir/$file $opts 2>&1 $stdout |")
		or die "exec '$psql': $!";
	while (<PIPE>)
	{
		print localtime() . " : " . $_;
	}
	close PIPE;

	die "Error during sql/$file" if ($? >> 8);
}

sub CreateReplicationFunction
{
	# Register a new database connection as the system user, but to the MB
	# database
	my $sys_db = MusicBrainz::Server::Database->get("SYSTEM");
	my $wr_db = MusicBrainz::Server::Database->get("READWRITE");
	my $sysmb_mb = $sys_db->modify(database => $wr_db->database);
	MusicBrainz::Server::Database->register("SYSMB", $sysmb_mb);

	# Now connect to that database
	my $mb = MusicBrainz->new;
	$mb->Login(db => "SYSMB");
	my $sql = Sql->new($mb->{DBH});

	$sql->AutoCommit;
	$sql->Do(
		"CREATE FUNCTION \"recordchange\" () RETURNS trigger
		AS ?, 'recordchange' LANGUAGE 'C'",
		$path_to_pending_so,
	);
}

{
	my $mb;
	my $sql;
	sub get_system_sql
	{
		return $sql if $sql;
		$mb = MusicBrainz->new;
		$mb->Login(db => "SYSTEM");
		$sql = Sql->new($mb->{DBH});
	}
}

sub Create 
{
	# Check we can find these programs on the path
	for my $prog (qw( createuser createdb createlang ))
	{
		next if `which $prog` and $? == 0;
		die "Can't find '$prog' on your PATH\n";
	}

	my $system_sql = get_system_sql();

	# Check the cluster uses the C locale
	{
		my $locale = $system_sql->SelectSingleValue(
			"select setting from pg_settings where name = 'lc_collate'",
		);

		unless ($locale eq "C")
		{
			die <<EOF;
It looks like your Postgres database cluster was created with locale '$locale'.
MusicBrainz needs the "C" locale instead.  To rectify this, re-run "initdb"
with the option "--locale=C".
EOF
		}
	}

	for my $db (MusicBrainz::Server::Database->all)
	{
		my $username = $db->username;
		
		$system_sql->SelectSingleValue(
			"SELECT 1 FROM pg_shadow WHERE usename = ?", $username,
		) and next;

		my $passwordclause = "";
		$passwordclause = "PASSWORD '$_'"
			if local $_ = $db->password;

		$system_sql->AutoCommit;
		$system_sql->Do(
			"CREATE USER $username $passwordclause NOCREATEDB NOCREATEUSER",
		);
	}

	my $dbname = $READWRITE->database;
	print localtime() . " : Creating database '$dbname'\n";
	$system_sql->AutoCommit;
	my $dbuser = $READWRITE->username;
	$system_sql->Do("CREATE DATABASE $dbname WITH OWNER = $dbuser ENCODING = 'UNICODE'");

	# You can do this via CREATE FUNCTION, CREATE LANGUAGE; but using
	# "createlang" is simpler :-)
	my $sys_in_rw = $SYSTEM->modify(database => $READWRITE->database);
	my @opts = $sys_in_rw->shell_args;
	splice(@opts, -1, 0, "-d");
	push @opts, "plpgsql";
	system "createlang", @opts;
	die "\nFailed to create language\n" if ($? >> 8);
}

sub CreateRelations
{
	my $import = shift;

	RunSQLScript("CreateTables.sql", "Creating tables ...");

	if ($import)
    {
		local $" = " ";
        system($^X, "$FindBin::Bin/MBImport.pl", "--ignore-errors", @$import);
        die "\nFailed to import dataset.\n" if ($? >> 8);
    } else {
		RunSQLScript("InsertDefaultRows.sql", "Adding default rows ...");
	}

	RunSQLScript("CreatePrimaryKeys.sql", "Creating primary keys ...");
	RunSQLScript("CreateIndexes.sql", "Creating indexes ...");
	RunSQLScript("CreateFKConstraints.sql", "Adding foreign key constraints ...")
	    if ! &DBDefs::DB_IS_REPLICATED;

    print localtime() . " : Setting initial sequence values ...\n";
    system($^X, "$FindBin::Bin/SetSequences.pl");
    die "\nFailed to set sequences.\n" if ($? >> 8);

	RunSQLScript("CreateViews.sql", "Creating views ...");
	RunSQLScript("CreateFunctions.sql", "Creating functions ...");
	RunSQLScript("CreateTriggers.sql", "Creating triggers ...")
	    if ! &DBDefs::DB_IS_REPLICATED;

	if ($with_replication)
	{
		CreateReplicationFunction();
		RunSQLScript("CreateReplicationTriggers.sql", "Creating replication triggers ...");
	}

    print localtime() . " : Optimizing database ...\n";
    system("echo \"vacuum analyze\" | $psql $opts");
    die "\nFailed to optimize database\n" if ($? >> 8);

    print localtime() . " : Initialized and imported data into the database.\n";
}

sub GrantSelect
{
	my $mb = MusicBrainz->new;
	$mb->Login(db => "READWRITE");
	my $dbh = $mb->{DBH};
	$dbh->{AutoCommit} = 1;

	my $username = $READONLY->username;

	my $sth = $dbh->table_info("", "public") or die;
	while (my $row = $sth->fetchrow_arrayref)
	{
		my $tablename = $row->[2];
		next if $tablename =~ /^(Pending|PendingData)$/;
		$dbh->do("GRANT SELECT ON $tablename TO $username")
			or die;
	}
	$sth->finish;
}

sub SanityCheck
{
    die "The postgres psql application must be on your path for this script to work.\n"
       if not -x $psql and (`which psql` eq '');

	if ($with_replication)
	{
		defined($path_to_pending_so) or die <<EOF;
If you specify --with-replication, you must also specify the path to "pending.so"
using --with-pending=PATH
EOF
		if (not -f $path_to_pending_so)
		{
			warn <<EOF;
Warning: $path_to_pending_so not found.
This might be OK for example if you simply don't have permission to see that
file, or if the database server is on a remote host.
EOF
		}
	}
}

sub Usage
{
   die <<EOF;
Usage: InitDb.pl [options] [file] ...

Options are:
     --psql=PATH        Specify the path to the "psql" utility
     --postgres=NAME    Specify the name of the system user
     --createdb         Create the database, PL/PGSQL language and user
  -i --import           Prepare the database and then import the data from 
                        the given files
  -c --clean            Prepare a ready to use empty database
     --[no]echo         When running the various SQL scripts, echo the commands
                        as they are run
  -q, --quiet           Don't show the output of any SQL scripts
  -h --help             This help
     --with-replication Activate the replication triggers (if you want to
                        be a master database to someone else's slave).
                        This option cannot be used if this database is being
                        up to be a replication slave by setting 
                        DB_IS_REPLICATED to 1 in DBDefs.pm.
  --with-pending=PATH   If you specify --with-replication, you MUST also specify
                        this option, where PATH is the path to "pending.so"
                        (on the database server).

After the import option, you may specify one or more MusicBrainz data dump
files for importing into the database. Once this script runs to completion
without errors, the database will be ready to use. Or it *should* at least.

Since all non-option arguments are passed directly to MBImport.pl, you can
pass additional options to that script by using "--".  For example:

  InitDb.pl --createdb --echo --import -- --tmp-dir=/var/tmp *.tar.bz2

EOF
}

my $fCreateDB;
my $mode = "MODE_IMPORT";

GetOptions(
	"psql=s"			=> \$psql,
	"createdb"			=> \$fCreateDB,
	"empty-database"	=> sub { $mode = "MODE_NO_TABLES" },
	"import|i"			=> sub { $mode = "MODE_IMPORT" },
	"clean|c"			=> sub { $mode = "MODE_NO_DATA" },
	"with-replication!"	=> \$with_replication,
	"with-pending=s"	=> \$path_to_pending_so,
	"echo!"				=> \$fEcho,
	"quiet|q"			=> \$fQuiet,
	"help|h"			=> \&Usage,
) or exit 2;

Usage() if $isrep and $with_replication;

SanityCheck();

print localtime() . " : InitDb.pl starting\n";
my $started = 1;

Create() if $fCreateDB;

if ($mode eq "MODE_NO_TABLES") { } # nothing to do
elsif ($mode eq "MODE_NO_DATA") { CreateRelations() }
elsif ($mode eq "MODE_IMPORT") { CreateRelations(\@ARGV) }

GrantSelect() if $isrep;

END {
	print localtime() . " : InitDb.pl "
		. ($? == 0 ? "succeeded" : "failed")
		. "\n"
		if $started;
}

# vi: set ts=4 sw=4 :
