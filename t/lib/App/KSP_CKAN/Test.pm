package App::KSP_CKAN::Test;

use v5.010;
use strict;
use warnings;
use autodie;
use Method::Signatures 20140224;
use Try::Tiny;
use File::Temp qw(tempdir);
use File::Path qw(remove_tree mkpath);
use File::chdir;
use File::Copy::Recursive qw(dircopy dirmove);
use Capture::Tiny qw(capture);
use Moo;
use namespace::clean;

# ABSTRACT: There is a bunch of common environment setup for testing.

# VERSION: Generated by DZP::OurPkg:Version

=head1 SYNOPSIS

  use App::KSP_CKAN::Test;

  my $test = App::KSP_CKAN::Test->new();

=head1 DESCRIPTION

This is a helper lib to make setting up our test environment quicker.

'tmp' can be used as a named argument to provide your own temp path.

=cut

has 'tmp'     => ( is => 'ro', lazy => 1, builder => 1 );
has '_tmp'    => ( is => 'ro', lazy => 1, builder => 1 );

method _build_tmp {
  return File::Temp::tempdir();
}

method _build__tmp {
  # Populate our test data
  dircopy("t/data", $self->tmp."/data");

  return $self->tmp;
}

=method create_tmp

  $test->create_tmp;

This will deploy our temp environment. Only required if we 
aren't creating a repo (one will be built on demand).

=cut

method create_tmp {
  $self->_tmp;
  return;
}

=method create_repo

  $test->create_repo('CKAN-meta');

Turns the named repo into a working local remote.

=cut

method create_repo($repo) {
  local $CWD = $self->_tmp."/data/$repo";
  capture { system("git", "init") }; 
  capture { system("git", "add", "-A") };
  capture { system("git", "commit", "-a", "-m", "Commit ALL THE THINGS!") };
  chdir("../");
  dirmove("$repo", "$repo-tmp");
  capture { system("git", "clone", "--bare", "$repo-tmp", "$repo") };
  return;
}

=method create_ckan
  
  $test->create_ckan(file => "/path/to/file");

Creates an example ckan that would pass validation at the specified
path.

Takes an optional extra argument, that if set to false will create
a ckan that won't pass schema validation.
  
  $test->create_ckan( file => "/path/to/file", valid => 0);

=over

=item file

Path and file we are creating.

=item valid

Defaults to true. False value will create a CKAN that will fail
validation against the schema.

=item kind

Allows us to specify a different kind of package. 'metadata' is the 
only accepted one at the moment.

=item license

Allows us to specify a different license.

=back

=cut

method create_ckan(
  :$file, 
  :$valid     = 1, 
  :$random    = 1, 
  :$kind      = "package",
  :$license   = '"CC-BY-NC-SA"',
  :$download  = "https://example.com/example.zip",
) {
  my $identifier = $valid ? "identifier" : "invalid_schema";

  # Allows us against a metapackage. TODO: make into valid metapackage
  my $package;
  if ( $kind eq "metapackage" ) {
    $package = '"kind": "metapackage"';
  } else {
    $package = "\"download\": \"$download\"";
  }

  # Lets us generate CKANs that are different.
  # http://www.perlmonks.org/?node_id=233023
  my @chars = ("A".."Z", "a".."z");
  my $rand;
  if ( $random ) {
    $rand .= $chars[rand @chars] for 1..8;
  } else {
    $rand = "random";
  }

  # Create the CKAN
  open my $in, '>', $file;
  print $in qq|{"spec_version": 1, "$identifier": "ExampleKAN", "license": $license, "ksp_version": "0.90", "name": "Example KAN", "abstract": "It's a $rand example!", "author": "Techman83", "version": "1.0.0.1", $package, "resources": { "homepage": "https://example.com/homepage", "repository": "https://example.com/repository" }}|;
  close $in;
  return;
}

=method cleanup
  
  $test->cleanup;

Does what it says on the tin, cleans up our mess.

=cut

=method create_config
  
  $test->create_config( optional => 0 );

Creates a dummy config file for testing. The 'optional'
defaults to true if unspecified, generating a test config 
with optional values.

=cut

method create_config(:$optional = 1, :$nogh = 0) {
  open my $in, '>', $self->_tmp."/.ksp-ckan";
  print $in "CKAN_meta=".$self->_tmp."/data/CKAN-meta\n";
  print $in "NetKAN=".$self->_tmp."/data/NetKAN\n";
  print $in "netkan_exe=https://ckan-travis.s3.amazonaws.com/netkan.exe\n";
  print $in "ckan_validate=https://raw.githubusercontent.com/KSP-CKAN/CKAN/master/bin/ckan-validate.py\n";
  print $in "ckan_schema=https://raw.githubusercontent.com/KSP-CKAN/CKAN/master/CKAN.schema\n";
  print $in "IA_access=12345678\n";
  print $in "IA_secret=87654321\n";
  
  # TODO: This is a little ugly.
  if ($optional) {
    print $in "GH_token=123456789\n" if ! $nogh;
    print $in "working=".$self->_tmp."/working\n";
  }

  close $in;
  return;
}

=method cleanup
  
  $test->cleanup;

Does what it says on the tin, cleans up our mess.

=cut

method cleanup {
  if ( -d $self->_tmp ) {
    remove_tree($self->_tmp);
  }
  return;
}

1;
