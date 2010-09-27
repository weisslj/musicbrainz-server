package MusicBrainz::Server::MXTypes;
use MooseX::Types -declare => [qw(
    RowID
)];

use MooseX::Types::Moose qw( Int Str );
use MooseX::Types::Structured qw( Dict );

subtype RowID, as Int, where { $_ > 0 };

1;
