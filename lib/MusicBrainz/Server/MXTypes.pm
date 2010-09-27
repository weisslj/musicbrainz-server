package MusicBrainz::Server::MXTypes;
use MooseX::Types -declare => [qw(
    ArtistEntity

    NatInt
)];

use MooseX::Types::Moose qw( Int Str );
use MooseX::Types::Structured qw( Dict );

class_type ArtistEntity, { class => 'MusicBrainz::Server::Entity::Artist' };

subtype NatInt, as Int, where { $_ > 0 };

1;
