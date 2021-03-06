package App::KSP_CKAN::WebHooks;

use Dancer2 appname => "xKanHooks";
use App::KSP_CKAN::WebHooks::InflateNetKAN;
use App::KSP_CKAN::WebHooks::MirrorCKAN;
use Method::Signatures 20140224;
use Digest::SHA qw(hmac_sha1_hex);
use File::Basename 'basename';
use List::MoreUtils 'none';
use AnyEvent::Util;
use Try::Tiny;
use File::Touch;

# ABSTRACT: Webhook Routes for ckan-webhooks

# VERSION: Generated by DZP::OurPkg:Version

##############
### Routes ###
##############

post '/inflate' => sub {
  my @identifiers;
  
  try {
    @identifiers = @{from_json(request->body)->{identifiers}};
  };

  if ($#identifiers == -1) {
    info("No identifiers received"); 
    send_error "An array of identifiers is required", 400;
  }

  inflate_netkans(identifiers => \@identifiers);

  status(204);
  return;
};

post '/gh/:task' => sub {
  my $signature = request->header('x-hub-signature');
  my $body = request->content;
  my $task = params->{task};

  if ( ! defined $signature ) {
    send_error("Post header 'x-hub-signature required'", 400);
  }

  if ( ! $body ) {
    send_error("post content required", 400);
  }

  if ( $signature ne calc_gh_signature( body => $body) ) { 
    send_error("Signature mismatch", 400);
  } 

  my @commits;
  my $sender;
  my $json;
  try {
    $json = from_json(request->body);
    @commits = @{$json->{commits}};
    $sender = $json->{sender}{login};
  };

  if ( $#commits == -1 && $task ne "release" ) {
    info("No commits received"); 
    return { "message" => "No add/remove commits received" };
  }

  if ( defined $sender && $sender eq 'kspckan-crawler' ) {
    info("Commits sent by crawler, skipping on demand mirror");
    status(204);
    return;
  }

  if ( $task eq "inflate" ) {
    inflate_github(commits => \@commits);
  } elsif ( $task eq "mirror" ) {
    mirror_github(commits => \@commits);
  } elsif ( $task eq "release" ) {
    send_error("param 'indentifier' required. eg http://netkan.ksp-ckan.org/gh/release?identifier=AwesomeMod", 400) unless defined params->{identifier};
    my @identifiers = params->{identifier};
    inflate_netkans(identifiers => \@identifiers);
  } else {
    send_error "Unknown task '".$task."', accepted tasks are 'inflate' and 'mirror'", 400;
  }

  status(204);
  return;
};

######################
### Mirror Methods ###
######################

method mirror_github($commits) {
  my @files;
  foreach my $commit (@{$commits}) {
    push(@files, (@{$commit->{added}},@{$commit->{modified}}));
  }
  
  if ($#files == -1) {
    info("Nothing add/modified");
    return;
  }

  my @ckans;
  foreach my $file (@files) {
    # Lets only try to only mirror actual ckans.
    # Also only do each one once
    if ($file =~ /\.ckan$/ && (none { $_ eq $file } @ckans)) {
      push(@ckans, $file);
    }
  }
  
  if ($#ckans == -1) {
    info("No ckans found in file list");
    return;
  }

  mirror_ckans(identifiers => \@ckans);
}

method mirror_ckans($ckans) {
  fork_call {
    my $mirror = App::KSP_CKAN::WebHooks::MirrorCKAN->new();

    while (-e "/tmp/xKan_mirror.lock" ) {
      debug("Waiting for lock release");
      sleep 5;
    }
    
    # TODO: Do something better, this doesn't handle stale
    #       locks at all. Also if following requests come in
    #       at exactly 5 seconds apart we could still fork
    #       twice simultaneously.
    debug("Locking environment");
    touch("/tmp/xKan_mirror.lock");
    
    info("Mirroring: ".join(", ", @{$ckans}));
    $mirror->mirror(\@{$ckans});
    info("Completed: ".join(", ", @{$ckans}));

    return;
  } sub {
    debug("Unlocking environment");
    unlink("/tmp/xKan_mirror.lock");
    return;
  };
  return;
}

#######################
### Inflate Methods ###
#######################

method inflate_github($commits) {
  my @files;
  foreach my $commit (@{$commits}) {
    push(@files, (@{$commit->{added}},@{$commit->{modified}}));
  }
  
  if ($#files == -1) {
    info("Nothing add/modified");
    return;
  }

  my @netkans;
  foreach my $file (@files) {
    # Lets only try to send NetKAN actual netkans.
    # Also only do each one once
    my $netkan = basename($file,".netkan");
    if ($file =~ /\.netkan$/ && (none { $_ eq $netkan } @netkans)) {
      push(@netkans, basename($file,".netkan"));
    }
  }
  
  if ($#netkans == -1) {
    info("No netkans found in file list");
    return;
  }

  inflate_netkans(identifiers => \@netkans);
}

method inflate_netkans($identifiers) {
  fork_call {
    my $inflater = App::KSP_CKAN::WebHooks::InflateNetKAN->new();

    while (-e "/tmp/xKan_netkan.lock" ) {
      debug("Waiting for lock release");
      sleep 5;
    }
    
    # TODO: Do something better, this doesn't handle stale
    #       locks at all. Also if following requests come in
    #       at exactly 5 seconds apart we could still fork
    #       twice simultaneously.
    debug("Locking environment");
    touch("/tmp/xKan_netkan.lock");
    
    info("Inflating: ".join(", ", @{$identifiers}));
    $inflater->inflate(\@{$identifiers});
    info("Completed: ".join(", ", @{$identifiers}));

    return;
  } sub {
    debug("Unlocking environment");
    unlink("/tmp/xKan_netkan.lock");
    return;
  };
  return;
}

########################
### Shortcut Methods ###
########################

method calc_gh_signature($body) {
  return 'sha1='.hmac_sha1_hex($body, $ENV{XKAN_GHSECRET});
}

1;
