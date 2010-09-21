package MusicBrainz::Server::Controller::List;
use Moose;

BEGIN { extends 'MusicBrainz::Server::Controller' };

__PACKAGE__->config(
    entity_name => 'list',
    model       => 'List',
);

sub base : Chained('/') PathPart('list') CaptureArgs(0) { }
after 'load' => sub
{
    my ($self, $c) = @_;
    my $list = $c->stash->{list};

    # Load editor
    $c->model('Editor')->load($list);
};

sub add : Chained('load') RequireAuth
{
    my ($self, $c) = @_;

    my $list = $c->stash->{list};
    my $release_id = $c->request->params->{release};

    $c->model('List')->add_releases_to_list($list->id, $release_id);

    $c->response->redirect(
        $c->uri_for_action($self->action_for('show'), [ $list->gid ]));
    $c->detach;
}

sub remove : Chained('load') RequireAuth
{
    my ($self, $c) = @_;

    my $list = $c->stash->{list};
    my $release_id = $c->request->params->{release};

    $c->model('List')->remove_releases_from_list($list->id, $release_id);

    $c->response->redirect(
        $c->uri_for_action($self->action_for('show'), [ $list->gid ]));
    $c->detach;
}

sub show : Chained('load') PathPart('')
{
    my ($self, $c) = @_;

    my $list = $c->stash->{list};

    my $user = $list->editor;
    $c->detach('/error_404')
        if ((!$c->user_exists || $c->user->id != $user->id) && !$list->public);

    my $order = $c->req->params->{order} || 'date';

    my $releases = $self->_load_paged($c, sub {
        $c->model('Release')->find_by_list($list->id, shift, shift, $order);
    });
    $c->model('ArtistCredit')->load(@$releases);
    $c->model('Medium')->load_for_releases(@$releases);
    $c->model('MediumFormat')->load(map { $_->all_mediums } @$releases);
    $c->model('Country')->load(@$releases);
    $c->model('ReleaseLabel')->load(@$releases);
    $c->model('Label')->load(map { $_->all_labels } @$releases);

    $c->stash(
        list => $list,
        order => $order,
        releases => $releases,
        template => 'list/index.tt'
    );
}

sub _form_to_hash
{
    my ($self, $form) = @_;

    return map { $form->field($_)->name => $form->field($_)->value } $form->edit_field_names;
}

sub create : Local RequireAuth
{
    my ($self, $c) = @_;

    my $form = $c->form( form => 'List' );

    if ($c->form_posted && $form->submitted_and_valid($c->req->params)) {
        my %insert = $self->_form_to_hash($form);

        my $list = $c->model('List')->insert($c->user->id, \%insert);

        $c->response->redirect(
            $c->uri_for_action($self->action_for('show'), [ $list->gid ]));
    }
}

sub edit : Chained('load') RequireAuth
{
    my ($self, $c) = @_;

    my $list = $c->stash->{list};

    my $user = $list->editor;
    $c->detach('/error_404') if ($c->user->id != $user->id);

    my $form = $c->form( form => 'List', init_object => $list );

    if ($c->form_posted && $form->submitted_and_valid($c->req->params)) {
        my %update = $self->_form_to_hash($form);

        $c->model('List')->update($list->id, \%update);

        $c->response->redirect(
            $c->uri_for_action($self->action_for('show'), [ $list->gid ]));
    }
}

sub delete : Chained('load') RequireAuth
{
    my ($self, $c) = @_;

    my $list = $c->stash->{list};

    my $user = $list->editor;
    $c->detach('/error_404') if ($c->user->id != $user->id);

    if ($c->form_posted) {
        $c->model('List')->delete($list->id);

        $c->response->redirect(
            $c->uri_for_action('/user/lists', [ $c->user->name ]));
    }
}

1;

=head1 COPYRIGHT

Copyright (C) 2009 Lukas Lalinsky
Copyright (C) 2010 Sean Burke

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