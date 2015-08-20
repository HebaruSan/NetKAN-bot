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

# Config
$test->create_config(nogh => 1);
my $config = App::KSP_CKAN::Tools::Config->new(
  file => $test->tmp."/.ksp-ckan",
);

# CKAN-meta
$test->create_repo("CKAN-meta");
my $ckan = App::KSP_CKAN::Tools::Git->new(
  remote => $test->tmp."/data/CKAN-meta",
  local => $config->working,
  clean => 1,
);
$ckan->pull;

# Netkan
$test->create_repo("NetKAN");
my $netkan_git = App::KSP_CKAN::Tools::Git->new(
  remote => $test->tmp."/data/NetKAN",
  local => $config->working,
  clean => 1,
);
$netkan_git->pull;

# netkan.exe
my $http = App::KSP_CKAN::Tools::Http->new();
$http->mirror( url => $config->netkan_exe, path => $test->tmp."/netkan.exe", exe => 1);

use_ok("App::KSP_CKAN::Tools::NetKAN");
my $netkan = App::KSP_CKAN::Tools::NetKAN->new(
  config    => $config, 
  netkan    => $test->tmp."/netkan.exe",
  cache     => $test->tmp."/cache", # TODO: Test default cache location
  ckan_meta => $ckan,
  file => $config->working."/NetKAN/NetKAN/DogeCoinFlag.netkan"
);

# TODO: Fix this on travis.
TODO: {
  local $TODO = "This appears to broken on travis" if $ENV{TRAVIS};
  
  my $md5 = $netkan->_output_md5;
  isnt($md5, undef, "MD5 '$md5' generated");
  is( $netkan->inflate, 0, "Return success correctly" );
  isnt($md5, $netkan->_output_md5, "MD5 Hash updated when new file generated");

  my @files = glob($config->working."/CKAN-meta/DogeCoinFlag/*");
  is( -e $files[0], 1, "Meta Data inflated" );
  is( $files[0], $netkan->_newest_file, "'".$netkan->_newest_file."' returned as the newest file");
  
  $netkan = App::KSP_CKAN::Tools::NetKAN->new( 
    config    => $config, 
    netkan    => $test->tmp."/netkan.exe",
    cache     => $test->tmp."/cache",
    ckan_meta => $ckan,
    file => $config->working."/NetKAN/NetKAN/DogeCoinFlag-broken.netkan"
  );
  isnt( $netkan->inflate, 0, "Return failure correctly" );
}

# Test Error Parsing
is (
  $netkan->_parse_error("8194 [1] FATAL CKAN.NetKAN.Program (null) - Could not find CrowdSourcedScience directory in zipfile to install"),
  "Could not find CrowdSourcedScience directory in zipfile to install",
  "Zipfile Error Parsing Success"
);

is (
  $netkan->_parse_error("2142 [1] FATAL CKAN.NetKAN.Program (null) - JSON deserialization error"),
  "JSON deserialization error",
  "JSON Error Parsing Success"
);

is (
  $netkan->_parse_error("No error"),
  undef,
  "Return undef when no error parsed"
);

my $error = <<EOF;
Unhandled Exception:
CKAN.Kraken: Cannot find remote and ID in kref: http://dl.dropboxusercontent.com/u/7121093/ksp-mods/KSP%5B1.0.2%5DWasdEditorCamera%5BMay20%5D.zip
  at CKAN.NetKAN.MainClass.FindRemote (Newtonsoft.Json.Linq.JObject json) [0x00000] in <filename unknown>:0 
  at CKAN.NetKAN.MainClass.Main (System.String[] args) [0x00000] in <filename unknown>:0 
[ERROR] FATAL UNHANDLED EXCEPTION: CKAN.Kraken: Cannot find remote and ID in kref: http://dl.dropboxusercontent.com/u/7121093/ksp-mods/KSP%5B1.0.2%5DWasdEditorCamera%5BMay20%5D.zip
  at CKAN.NetKAN.MainClass.FindRemote (Newtonsoft.Json.Linq.JObject json) [0x00000] in <filename unknown>:0 
  at CKAN.NetKAN.MainClass.Main (System.String[] args) [0x00000] in <filename unknown>:0 
EOF

is (
  $netkan->_parse_error( $error ),
  "FATAL UNHANDLED EXCEPTION: CKAN.Kraken: Cannot find remote and ID in kref: http://dl.dropboxusercontent.com/u/7121093/ksp-mods/KSP%5B1.0.2%5DWasdEditorCamera%5BMay20%5D.zip",
  "Generic Error Parsing Success"
);
ok( -d $test->tmp."/cache", "NetKAN Cache path set correctly");

# Cleanup after ourselves
$test->cleanup;

done_testing();
__END__
