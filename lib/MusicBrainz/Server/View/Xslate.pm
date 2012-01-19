package MusicBrainz::Server::View::Xslate;
use Moose;

use MusicBrainz::Server::Data::Utils qw( ref_to_type );
use MusicBrainz::Server::Track;

extends 'Catalyst::View::Xslate';

has '+function' => (
    default => sub { +{
        l => sub { shift },
        ln => sub { shift },
        format_duration => \&MusicBrainz::Server::Track::FormatTrackLength,
        entity_type => \&ref_to_type
    }},
);

1;
