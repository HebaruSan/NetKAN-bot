#!/usr/bin/env perl -w

use lib 't/lib/';

use strict;
use warnings;
use Test::Most;
use Test::Warnings ':no_end_test';
use App::KSP_CKAN::Test;
use App::KSP_CKAN::Tools::Http;
use App::KSP_CKAN::Tools::Git;
use App::KSP_CKAN::Tools::Config;

## Setup our environment
my $test = App::KSP_CKAN::Test->new();

# CKAN-meta
$test->create_repo("CKAN-meta");
my $ckan = App::KSP_CKAN::Tools::Git->new(
  remote => $test->tmp."/data/CKAN-meta",
  local => $test->tmp,
  clean => 1,
);
$ckan->pull;

# Netkan
$test->create_repo("NetKAN");
my $netkan_git = App::KSP_CKAN::Tools::Git->new(
  remote => $test->tmp."/data/NetKAN",
  local => $test->tmp,
  clean => 1,
);
$netkan_git->pull;

# Config
$test->create_config(nogh => 1);
my $config = App::KSP_CKAN::Tools::Config->new(
  file => $test->tmp."/.ksp-ckan",
);

# netkan.exe
my $http = App::KSP_CKAN::Tools::Http->new();
$http->mirror( url => $config->netkan_exe, path => $test->tmp."/netkan.exe", exe => 1);

use_ok("App::KSP_CKAN::Tools::NetKAN");
my $netkan = App::KSP_CKAN::Tools::NetKAN->new(
  config    => $config, 
  netkan    => $test->tmp."/netkan.exe",
  cache     => $test->tmp."/cache", # TODO: Test default cache location
  ckan_meta => $test->tmp."/CKAN-meta",
  file => $test->tmp."/NetKAN/NetKAN/DogeCoinFlag.netkan"
);

# TODO: Fix this on travis.
TODO: {
  local $TODO = "This appears to broken on travis", 4 if $ENV{TRAVIS};
  is( $netkan->inflate, 0, "Return success correctly" );

  my @files = glob($test->tmp."/CKAN-meta/DogeCoinFlag");
  is( -e $files[0], 1, "Meta Data inflated" );
  
  $netkan = App::KSP_CKAN::Tools::NetKAN->new( 
    config    => $config, 
    netkan    => $test->tmp."/netkan.exe",
    cache     => $test->tmp."/cache",
    ckan_meta => $test->tmp."/CKAN-meta",
    file => $test->tmp."/NetKAN/NetKAN/DogeCoinFlag-broken.netkan"
  );
  isnt( $netkan->inflate, 0, "Return failure correctly" );
}

ok( -d $test->tmp."/cache", "NetKAN Cache path set correctly");

# Cleanup after ourselves
$test->cleanup;

done_testing();
__END__