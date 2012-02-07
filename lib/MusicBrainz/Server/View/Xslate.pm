package MusicBrainz::Server::View::Xslate;
use Moose;

use Encode qw( decode );
use MusicBrainz::Server::Data::Utils qw( ref_to_type );
use MusicBrainz::Server::Filters;
use MusicBrainz::Server::Track;
use MusicBrainz::Server::Translation qw( l ln );

extends 'Catalyst::View::Xslate';

has '+function' => (
    default => sub { +{
        l => sub { l(@_) },
        ln => sub { ln(@_) },
        format_duration => \&MusicBrainz::Server::Track::FormatTrackLength,
        entity_type => \&ref_to_type,
        format_wikitext => \&MusicBrainz::Server::Filters::format_wikitext,
        format_user_date => sub {
            my $user = shift;
            my $dt = shift or return;

            my $format;
            if ($user and (my $prefs = $user->preferences)) {
                $dt = $dt->clone();
                $dt->set_time_zone($prefs->timezone);
                $format = $prefs->datetime_format;
            }
            else {
                $format = '%Y-%m-%d %H:%M %Z';
            }

            return $dt->strftime($format);
        }
    }},
);

has '+module' => (
    default => sub {
        ['Text::Xslate::Bridge::Star']
    }
);

# This is pretty much a copy and paste from Catalyst::View::Xslate, except it
# *doesn't* do the mandatory encoding. This is because we already have this
# encoding handled by Catalyst::Plugin::Unicode::Encoding
sub process {
    my ($self, $c) = @_;

    my $stash = $c->stash;
    my $template = $stash->{template} || $c->action . $self->template_extension;

    if (! defined $template) {
        $c->log->debug('No template specified for rendering') if $c->debug;
        return 0;
    }

    my $output = eval {
        $self->render( $c, $template, $stash );
    };
    if (my $err = $@) {
        return $self->_rendering_error($c, $err);
    }

    $c->res->body($output);

    return 1;
}

1;
