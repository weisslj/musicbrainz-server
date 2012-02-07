package MusicBrainz::Server::View::Xslate;
use Moose;

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

1;
