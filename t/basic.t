#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use Test::DZil;

my $tzil = Builder->from_config( { dist_root => 'corpus/DZ' } );

$tzil->build;

my $got = $tzil->slurp_file('build/t/basic.t');

my $expected = <<'HERE';
#!/usr/bin/perl
use 5.008;
use strict;
use warnings;

use if $ENV{AUTOMATED_TESTING}, 'Test::DiagINC';
use Test::More;
use File::Find;
HERE

is( $got, $expected, "Test::DiagINC line inserted" );

ok( $tzil->prereqs, "got prereqs" );
diag explain $tzil->prereqs;

done_testing;
