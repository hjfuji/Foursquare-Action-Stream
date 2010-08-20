package ActionStreams::Event::Foursquare;

use strict;
use MT;

use base qw( ActionStreams::Event );

__PACKAGE__->install_properties({
    class_type => 'foursquare_places',
});

__PACKAGE__->install_meta({
    columns => [ qw(
        description
        lat
        lng
        visibility
        thumbnail
    ) ],
});

sub update_events {
    my $class = shift;
    my %profile = @_;
    my ($ident, $author) = @profile{qw( ident author )};

    my $url = "http://feeds.foursquare.com/history/${ident}.kml";

    my $items = $class->fetch_xpath(
            url => $url,
            foreach => '//Placemark',
            get => {
                identifier   => 'published/child::text()',
                title        => 'name/child::text()',
                url          => 'description/a/@href',
                description  => 'description/child::text()',
                created_on   => 'published/child::text()',
                modified_on  => 'updated/child::text()',
                latlng       => 'Point/coordinates/child::text()',
                visibility   => 'visibility/child::text()',
            },
        );
    return if !$items;
    @$items = grep { $_->{visibility} } @$items;

    my $plugin = MT->component('FoursquareActionStream');
    my $api_key = $plugin->get_config_value('fjfsas_apikey');

    my $count = scalar @$items;
    for (my $i = 0; $i < $count; $i++) {
        my $latlng = delete @$items[$i]->{latlng};
        my ($lng, $lat) = split ',', $latlng;
        @$items[$i]->{lat} = $lat;
        @$items[$i]->{lng} = $lng;
        @$items[$i]->{url} = 'http://foursquare.com' . @$items[$i]->{url};
        if ($api_key) {
            @$items[$i]->{thumbnail} = "http://maps.google.com/staticmap?center=${lat},${lng}&amp;zoom=10&amp;size=100x100&amp;maptype=mobile&amp;markers=${lat},${lng}&amp;key=${api_key}";
        }
    }
    $class->build_results( author => $author, items => $items );
}

1;
