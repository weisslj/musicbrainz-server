package MusicBrainz::Server::Form::RelationshipEditor;
use HTML::FormHandler::Moose;

extends 'MusicBrainz::Server::Form';
with 'MusicBrainz::Server::Form::Role::Edit';

has '+name' => ( default => 'relationship-editor' );

has_field 'relationships' => (
    type => 'Repeatable'
);

has_field 'relationships.id' => (
    type => 'Integer'
);

has_field 'relationships.types' => (
    type => 'Repeatable'
);

has_field 'relationships.action' => (
    type => 'Select'
);

has_field 'relationships.types.contains' => (
    type => 'Text'
);

has_field 'relationships.entity0' => (
    type => 'Compound'
);

has_field 'relationships.entity0.id' => (
    type => 'Integer'
);

has_field 'relationships.entity1' => (
    type => 'Compound'
);

has_field 'relationships.entity1.id' => (
    type => 'Integer'
);

has_field 'relationships.work' => (
    type => 'Compound',
);

has_field 'relationships.work.name' => (
    type => 'Text'
);

sub options_relationships_action {
    return [
        'remove' => 'Remove',
        'add' => 'Add'
    ]
};

sub edit_field_names { qw() }

1;
