#!/usr/bin/env perl

=head1 Usage

Usage: ./run_all_patches.pl -u <dbuser> -p <dbpassword> -h <dbhost> -d <dbname> -e <editinguser> [-s <startfrom>] [--test]

-e, --editinguser=  user to write as patch executor
-s, --startfrom=0   start patches from folder # (Default: 0)
-p, --patchpath=    directory containing patches # (Default: script directory)
-n, --nodie         Do not die if a patch fails
-t, --test          Do not make permanent changes.

e.g. `./run_all_patches.pl -u postgres -p postgres -h localhost -d fixture -e janedoe -s 00085 -t`
e.g. `./run_all_patches.pl -e admin -s 150`

=cut

use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use File::Basename qw(dirname);
use Cwd qw(abs_path);

my $editinguser;
my $startfrom = 0;
my $test;
my $db_patch_path = dirname(abs_path($0));
my $nodie;

GetOptions(
    "editinguser=s" => \$editinguser,
    "startfrom:i"   => \$startfrom,
    "test"          => \$test,
    "patchpath=s"   => \$db_patch_path,
    "nodie"         => \$nodie,
);

chdir($db_patch_path);

my @folders = grep /[0-9]{5}/, (split "\n", `ls -d */`);

my $cmd = "psql -h \$PGHOST -U \$PGUSER -d \$PGDATABASE -t -c \"select patch_name from Metadata.md_dbversion\"";
my @installed = grep {!/^$/} map {s/^\s+|\s+$//gr} `$cmd`;

for (my $i = 0; $i < (scalar @folders); $i++) {
    if (($folders[$i] =~ s/\/$//r) >= $startfrom) {
        chdir($db_patch_path);
        chdir($folders[$i]);
        my @patches = grep {!($_ ~~ @installed)} map {s/.pm//r} (split "\n", `ls`);
        
        for (my $j = 0; $j < (scalar @patches); $j++) {
            my $patch = $patches[$j];

            if ($patch =~ /\~$/) {
                print STDERR "Ignoring $patch...\n";
                next;
            }

            my $cmd = "echo -ne \"\$PGUSER\\n\$PGPASSWORD\" | mx-run $patch -H \$PGHOST -D \$PGDATABASE -u $editinguser" . ($test ? ' -t' : '');
            print STDERR $cmd . "\n";
            system("bash -c '$cmd'");

            if (($? >> 8) == 255) { #execution error
                if ($nodie) {
                    print STDERR "Failed executing patch: $patch";
                } else {
                    die "Failed executing patch: $patch";
                }
            }

            print STDERR "\n\n\n";
        }
    }
}

print STDERR "DB patching complete, database is up to date\n";