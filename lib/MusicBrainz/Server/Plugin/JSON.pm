package MusicBrainz::Server::Plugin::JSON;

use strict;
use warnings;

use JSON;

use base 'Template::Plugin';

use Time::Duration;

sub new {
    my ($class, $context) = @_;
    return bless {}, $class;
}

sub encode {
    my ($self, $v) = @_;
    return JSON->new->latin1->encode($v);
}

1;
