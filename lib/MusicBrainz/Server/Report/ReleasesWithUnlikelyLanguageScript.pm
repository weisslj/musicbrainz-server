package MusicBrainz::Server::Report::ReleasesWithUnlikelyLanguageScript;
use Moose;

extends 'MusicBrainz::Server::Report::ReleaseReport';

sub gather_data
{
    my ($self, $writer) = @_;

    $self->gather_data_from_query($writer, "
        SELECT
            DISTINCT r.gid, rn.name, r.artist_credit AS artist_credit_id,
            musicbrainz_collate(an.name), musicbrainz_collate(rn.name)
        FROM
            release r
            JOIN artist_credit ac ON r.artist_credit = ac.id
            JOIN artist_name an ON ac.name = an.id
            JOIN release_name rn ON r.name = rn.id
            JOIN script ON r.script = script.id
            JOIN language ON r.language = language.id
        WHERE
            script.iso_code != 'Latn' AND
            language.iso_code_3t IN (
              'eng', 'spa', 'deu', 'fra', 'por', 'ita', 'swe', 'nor', 'fin',
              'est', 'lav', 'lit', 'pol', 'nld', 'cat', 'hun', 'ces', 'slk',
              'dan', 'ron', 'slv', 'hrv'
            )
        ORDER BY musicbrainz_collate(an.name), musicbrainz_collate(rn.name)
    ");
}

sub template
{
    return 'report/releases_with_unlikely_language_script.tt';
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=head1 COPYRIGHT

Copyright (C) 2011 MetaBrainz Foundation

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
