package App::KSP_CKAN::Status::NetKAN;

use v5.010;
use strict;
use warnings;
use Method::Signatures 20140224;
use POSIX qw(strftime);
use JSON;
use Moo;
use namespace::clean;

# ABSTRACT: A NetKAN Status Object

# VERSION: Generated by DZP::OurPkg:Version

=head1 SYNOPSIS

  use App::KSP_CKAN::Status::NetKAN;

  my $netkan = App::KSP_CKAN::Tools::NetKAN->new( name => "BaconLabs" );

=head1 DESCRIPTION

Provides simple methods for setting status of the current NetKAN
being inflated.

=cut

has 'name'            => ( is => 'ro', );
has 'last_inflated'   => ( is => 'rw', default => sub { JSON::null } );
has 'last_indexed'    => ( is => 'rw', default => sub { JSON::null } );
has 'last_checked'    => ( is => 'rw', default => sub { JSON::null } );
has 'last_error'      => ( is => 'rw', default => sub { JSON::null } );
has 'failed'          => ( is => 'rw', default => sub { JSON::false } );

method _current_utc {
  return strftime "%FT%H:%M:%SZ", gmtime;
}

method _failure {
  $self->failed(JSON::true);
}

=method checked
  
  $status->checked;

Sets last_checked to current time utc, ISO8601 compliant.

=cut

method checked {
  $self->last_checked($self->_current_utc);
}

=method inflated
  
  $status->inflated;

Sets last_inflated to current time utc, ISO8601 compliant.

=cut

method inflated {
  $self->last_inflated($self->_current_utc);
}

=method indexed
  
  $status->indexed;

Sets last_indexed to current time utc, ISO8601 compliant. Also
sets the 'failed' field to false and clears 'last_error'.

=cut

method indexed {
  $self->last_indexed($self->_current_utc);
  $self->success;
}

=method success
  
  $status->success;

Clears 'last_error' and sets 'failed' to false.

=cut

method success {
  $self->failed(JSON::false);
  $self->last_error(JSON::null);
}

=method failure
  
  $status->failure($reason);

Sets 'last_error' to $reason and sets failed to true.

=cut

method failure($reason) {
  $self->last_error($reason);
  $self->_failure;
}

# Internal method that returns a clean perl data structure
# for encode_json
method TO_JSON {
  my $data = {
    last_inflated => $self->last_inflated,
    last_indexed  => $self->last_indexed,
    last_checked  => $self->last_checked,
    last_error    => $self->last_error,
    failed        => $self->failed,
  };
  return $data;
}

1;
