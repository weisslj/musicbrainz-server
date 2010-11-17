package MusicBrainz::Server::Form::Role::CheckDuplicates;
use HTML::FormHandler::Moose::Role;
use namespace::autoclean;

requires 'dupe_model';

has_field 'not_dupe' => (
    type => 'Boolean',
);

has 'duplicates' => (
    traits => [ 'Array' ],
    isa => 'ArrayRef',
    is => 'rw',
    default => sub { [] },
    handles => {
        has_duplicates => 'count'
    }
);

after 'validate' => sub
{
    my $self = shift;

    # Don't check for dupes if the not_dupe checkbox is ticked, or the
    # user hasn't changed the entity's name
    return if $self->field('not_dupe')->value;
    return if $self->init_object && $self->init_object->name eq $self->field('name')->value;

    $self->duplicates([ $self->dupe_model->find_by_name($self->field('name')->value) ]);

    $self->field('not_dupe')->required($self->has_duplicates ? 1 : 0);
    $self->field('not_dupe')->validate_field;
};

1;