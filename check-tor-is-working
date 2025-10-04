#!/usr/bin/env perl
# Check TOR is working
# apt install libjson-perl libwww-perl

use feature 'say';

sub download {
    my ( $uri, $fn ) = @_;
    use LWP::Simple;
    my $content;
    unless ( defined( $content = get $uri) ) {
        die "Couldn't get $uri";
    }
    return $content;
}

my $json_text = download("https://check.torproject.org/api/ip");

use JSON;
my $json = JSON->new->allow_nonref;
my $perl_scalar = $json->decode( $json_text );

if (!JSON::is_bool($perl_scalar->{IsTor})) {
	die "Nor JSON::true nor JSON::false";
}

if ($perl_scalar->{IsTor}) {
	exit 0;
} else {
	say "This connection is NOT routed through TOR!";
	exit 1;
}
