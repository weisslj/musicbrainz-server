package MusicBrainz::Server::Edit::Recording::AddEchoprints;
use Moose;
use MooseX::Types::Moose qw( ArrayRef Int Str );
use MooseX::Types::Structured qw( Dict );
use MusicBrainz::Server::Constants qw( $EDIT_RECORDING_ADD_ECHOPRINTS );
use MusicBrainz::Server::Translation qw( l ln );

extends 'MusicBrainz::Server::Edit';
with 'MusicBrainz::Server::Edit::Recording';

use aliased 'MusicBrainz::Server::Entity::Recording';

sub edit_name { l('Add Echoprints') }
sub edit_type { $EDIT_RECORDING_ADD_ECHOPRINTS }

has '+data' => (
    isa => Dict[
        client_version => Str,
        echoprints => ArrayRef[Dict[
            echoprint    => Str,
            recording    => Dict[
                id => Int,
                name => Str
            ]
        ]]
    ]
);

sub recording_ids { map { $_->{recording}{id} } @{ shift->data->{echoprints} } }

sub related_entities
{
    my $self = shift;
    return { recording => [ $self->recording_ids ] };
}

sub foreign_keys
{
    my $self = shift;
    return {
        Recording => { map {
            $_->{recording}{id} => ['ArtistCredit']
        } @{ $self->data->{echoprints} } }
    }
}

sub build_display_data
{
    my ($self, $loaded) = @_;
    return {
        client_version => $self->data->{client_version},
        echoprints => [ map { +{
            echoprint => $_->{echoprint},
            recording => $loaded->{Recording}{ $_->{recording}{id} }
                || Recording->new( name => $_->{recording}{name} )
        } } @{ $self->data->{echoprints} } ]
    }
}

sub allow_auto_edit { 1 }

sub accept
{
    my $self = shift;

    my @insert = @{ $self->data->{echoprints} };
    my %echoprint_id = $self->c->model('Echoprint')->find_or_insert(
        $self->data->{client_version},
        map { $_->{echoprint} } @insert
    );

    my @submit = map +{
        recording_id => $_->{recording}{id},
        echoprint_id => $echoprint_id{ $_->{echoprint} }
    }, @insert;

    $self->c->model('RecordingEchoprint')->insert(
        @submit
    );
}

__PACKAGE__->meta->make_immutable;
no Moose;
