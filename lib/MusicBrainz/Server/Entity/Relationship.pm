package MusicBrainz::Server::Entity::Relationship;
use Moo;

use DateTime::Format::Pg;
use Readonly;
use Carp qw( croak );
use MusicBrainz::Server::Entity::Types;
use MusicBrainz::Server::Validation;
use Sub::Quote;
use Scalar::Util qw( looks_like_number );

Readonly our $DIRECTION_FORWARD  => 1;
Readonly our $DIRECTION_BACKWARD => 2;

has 'last_updated' => (
    is => 'rw',
    coerce => sub { DateTime::Format::Pg->parse_datetime(shift) }
);

has 'id' => (
    is => 'rw',
    isa => sub { croak 'id muts be an Int' unless looks_like_number(shift) }
);

has 'edits_pending' => (
    is => 'rw',
    isa => sub { croak 'edits_pending muts be an Int' unless looks_like_number(shift) }
);

has 'link_id' => (
    is => 'rw',
    isa => sub { croak 'link_id must be an Int' unless looks_like_number(shift) }
);

has 'link' => (
    is => 'rw',
    isa => sub { croak 'link must be a Link object' unless shift->isa('MusicBrainz::Server::Entity::Link') },
);

has 'direction' => (
    is => 'rw',
    isa => sub { croak 'direction must be an Int' unless looks_like_number(shift) },
    default => sub { $DIRECTION_FORWARD }
);

has 'entity0_id' => (
    is => 'rw',
    isa => sub { croak 'entity0_id must be an Int' unless looks_like_number(shift) },
);

has 'entity0' => (
    is => 'rw',
    isa => sub { croak 'entity0_id must be an Int' unless shift->does('MusicBrainz::Server::Entity::Role::Linkable') },
);

has 'entity1_id' => (
    is => 'rw',
    isa => sub { croak 'entity1_id must be an Int' unless looks_like_number(shift) },
);

has 'entity1' => (
    is => 'rw',
    isa => sub { croak 'entity1 must be an Int' unless shift->does('MusicBrainz::Server::Entity::Role::Linkable') },
);

has 'phrase' => (
    is => 'ro',
    builder => '_build_phrase',
    lazy => 1
);

has 'verbose_phrase' => (
    is => 'ro',
    builder => '_build_verbose_phrase',
    lazy => 1
);

sub source
{
    my ($self) = @_;
    return ($self->direction == $DIRECTION_FORWARD)
        ? $self->entity0 : $self->entity1;
}

sub source_type
{
    my ($self) = @_;
    return ($self->direction == $DIRECTION_FORWARD)
        ? $self->link->type->entity0_type
        : $self->link->type->entity1_type;
}

sub source_key
{
    my ($self) = @_;
    return ($self->source_type eq 'url')
        ? $self->source->url
        : $self->source->gid;
}

sub target
{
    my ($self) = @_;
    return ($self->direction == $DIRECTION_FORWARD)
        ? $self->entity1 : $self->entity0;
}

sub target_type
{
    my ($self) = @_;
    return ($self->direction == $DIRECTION_FORWARD)
        ? $self->link->type->entity1_type
        : $self->link->type->entity0_type;
}

sub target_key
{
    my ($self) = @_;
    return ($self->target_type eq 'url')
        ? $self->target->url
        : $self->target->gid;
}

sub _join_attrs
{
    my @attrs = map { $_ } @{$_[0]};
    if (scalar(@attrs) > 1) {
        my $a = pop(@attrs);
        my $b = join(", ", @attrs);
        return "$b and $a";
    }
    elsif (scalar(@attrs) == 1) {
        return $attrs[0];
    }
    return '';
}

sub _build_phrase {
    my ($self) = @_;
    $self->_interpolate(
        $self->direction == $DIRECTION_FORWARD
            ? $self->link->type->link_phrase
            : $self->link->type->reverse_link_phrase
    );
}

sub _build_verbose_phrase {
    my ($self) = @_;
    $self->_interpolate($self->link->type->short_link_phrase);
}

sub _interpolate
{
    my ($self, $phrase) = @_;

    my @attrs = $self->link->all_attributes;
    my %attrs;
    foreach my $attr (@attrs) {
        my $name = lc $attr->root->name;
        my $value = $attr->name;
        if (exists $attrs{$name}) {
            push @{$attrs{$name}}, $value;
        }
        else {
            $attrs{$name} = [ $value ];
        }
    }

    my $replace_attrs = sub {
        my ($name, $alt) = @_;
        if (!$alt) {
            return '' unless exists $attrs{$name};
            return _join_attrs($attrs{$name});
        }
        else {
            my ($alt1, $alt2) = split /\|/, $alt;
            return $alt2 || '' unless exists $attrs{$name};
            my $attr = _join_attrs($attrs{$name});
            $alt1 =~ s/%/$attr/eg;
            return $alt1;
        }
    };
    $phrase =~ s/{(.*?)(?::(.*?))?}/$replace_attrs->(lc $1, $2)/eg;
    MusicBrainz::Server::Validation::TrimInPlace($phrase);

    return $phrase;
}

1;

=head1 COPYRIGHT

Copyright (C) 2009 Lukas Lalinsky

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=cut
