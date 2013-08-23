package WWW::Scraper::ISBN::BookDepository_Driver;

use strict;
use warnings;

use vars qw($VERSION @ISA);
$VERSION = '0.06';

#--------------------------------------------------------------------------

=head1 NAME

WWW::Scraper::ISBN::BookDepository_Driver - Search driver for The Book Depository online book catalog.

=head1 SYNOPSIS

See parent class documentation (L<WWW::Scraper::ISBN::Driver>)

=head1 DESCRIPTION

Searches for book information from The Book Depository online book catalog

=cut

#--------------------------------------------------------------------------

###########################################################################
# Inheritence

use base qw(WWW::Scraper::ISBN::Driver);

###########################################################################
# Modules

use WWW::Mechanize;

###########################################################################
# Constants

use constant	REFERER	=> 'http://www.bookdepository.co.uk/';
use constant	SEARCH	=> 'http://www.bookdepository.co.uk/search?search=search&searchTerm=';
my ($URL1,$URL2) = ('http://www.bookdepository.co.uk/book/','/[^?]+\?b=\-3\&amp;t=\-26\#Bibliographicdata\-26');

#--------------------------------------------------------------------------

###########################################################################
# Public Interface

=head1 METHODS

=over 4

=item C<search()>

Creates a query string, then passes the appropriate form fields to the 
Book Depository server.

The returned page should be the correct catalog page for that ISBN. If not the
function returns zero and allows the next driver in the chain to have a go. If
a valid page is returned, the following fields are returned via the book hash:

  isbn          (now returns isbn13)
  isbn10        
  isbn13
  ean13         (industry name)
  author
  title
  book_link
  image_link
  description
  pubdate
  publisher
  binding       (if known)
  pages         (if known)
  weight        (if known) (in grammes)
  width         (if known) (in millimetres)
  height        (if known) (in millimetres)

The book_link and image_link refer back to the The Book Depository website.

=back

=cut

sub search {
	my $self = shift;
	my $isbn = shift;
	$self->found(0);
	$self->book(undef);

	my $mech = WWW::Mechanize->new();
    $mech->agent_alias( 'Windows IE 6' );
    $mech->add_header( 'Accept-Encoding' => undef );
    $mech->add_header( 'Referer' => REFERER );

    eval { $mech->get( SEARCH . $isbn ) };
    return $self->handler("The Book Depository website appears to be unavailable.")
	    if($@ || !$mech->success() || !$mech->content());

    my $pattern = $isbn;
    if(length $isbn == 10) {
        $pattern = '978' . $isbn;
        $pattern =~ s/.$/./;
    }

    my $content = $mech->content;
    my ($link) = $content =~ m!($URL1$pattern$URL2)!si;
#print STDERR "\n# search=[".SEARCH."$isbn]\n";
#print STDERR "\n# link1=[$URL1$pattern$URL2]\n";
#print STDERR "\n# link2=[$link]\n";
#print STDERR "\n# content1=[\n$content\n]\n";
#print STDERR "\n# is_html=".$mech->is_html().", content type=".$mech->content_type()."\n";
#print STDERR "\n# dump headers=".$mech->dump_headers."\n";

	return $self->handler("Failed to find that book on The Book Depository website. [$isbn]")
		if(!$link || $content =~ m!Sorry, there are no results for!si);

    $link =~ s/&amp;/&/g;
#print STDERR "\n# link3=[$link]\n";

    eval { $mech->get( $link ) };
    return $self->handler("The Book Depository website appears to be unavailable.")
	    if($@ || !$mech->success() || !$mech->content());

	# The Book page
    my $html = $mech->content();

	return $self->handler("Failed to find that book on The Book Depository website. [$isbn]")
		if($html =~ m!Sorry, there are no results for!si);
    
    $html =~ s/&amp;/&/g;
#print STDERR "\n# content2=[\n$html\n]\n";

    my $data;
    ($data->{isbn13})           = $html =~ m!<span class="isbn13"><strong>ISBN 13:</strong><span property="dc:identifier">([^<]+)</span>!si;
    ($data->{isbn10})           = $html =~ m!<span class="isbn10"><strong>ISBN 10:</strong><span>([^<]+)</span>!si;
    ($data->{publisher})        = $html =~ m!<li class='publisherName'><strong>Publisher:</strong>\s*<span class='linkSurround publisherName'><a property='dc:publisher' href='[^>]+'>([^<]+)</a></span></li>!si;
    ($data->{pubdate})          = $html =~ m!<li class='publishDate'><strong>Published:</strong>\s*<span property='dc:available'>([^<]+)</span></li>!si;
    ($data->{title})            = $html =~ m!<span property='dc:title'>([^<]+)!si;
    ($data->{binding})          = $html =~ m!<li class='format'><strong>Format:</strong>\s*<span property="dc:format">([^<]+)!si;
    ($data->{pages})            = $html =~ m!<span property='dc:SizeOrDuration'>\s*(\d+) pages</span>!si;
    ($data->{width})            = $html =~ m!<em>Width:</em>\s*([\d.]+)\s*mm<br/>!si;
    ($data->{height})           = $html =~ m!<em>Height:</em>\s*([\d.]+)\s*mm<br/>!si;
    ($data->{author})           = $html =~ m!<a property="dc:creator" rel="nofollow" href="[^"]+" title="[^"]+">([^<]+)</a>!si;
    ($data->{image})            = $html =~ m!"(http://\w+.bookdepository.co.uk/assets/images/book/large/\d+/\d+/\d+.jpg)"!si;
    ($data->{thumb})            = $html =~ m!"(http://\w+.bookdepository.co.uk/assets/images/book/medium/\d+/\d+/\d+.jpg)"!si;
    ($data->{description})      = $html =~ m!<p class="shortDescription" property="dc:description"><strong>Short Description[^<]+</strong>([^<]+)!si;
    ($data->{weight})           = $html =~ m!<em>Weight:</em>([^<]+)g<br/>!s;

    $data->{publisher} =~ s/&#0?39;/'/g;
    $data->{width}  = int($data->{width})   if($data->{width});
    $data->{height} = int($data->{height})  if($data->{height});
    $data->{weight} = int($data->{weight})  if($data->{weight});

#use Data::Dumper;
#print STDERR "\n# " . Dumper($data);

	return $self->handler("Could not extract data from The Book Depository result page.")
		unless(defined $data);

	# trim top and tail
	foreach (keys %$data) { 
        next unless(defined $data->{$_});
        $data->{$_} =~ s!&nbsp;! !g;
        $data->{$_} =~ s/^\s+//;
        $data->{$_} =~ s/\s+$//;
    }

    my $url = $mech->uri();
    $url =~ s/\?.*//;

	my $bk = {
		'ean13'		    => $data->{isbn13},
		'isbn13'		=> $data->{isbn13},
		'isbn10'		=> $data->{isbn10},
		'isbn'			=> $data->{isbn13},
		'author'		=> $data->{author},
		'title'			=> $data->{title},
		'book_link'		=> $url,
		'image_link'	=> $data->{image},
		'thumb_link'	=> $data->{thumb},
		'description'	=> $data->{description},
		'pubdate'		=> $data->{pubdate},
		'publisher'		=> $data->{publisher},
		'binding'	    => $data->{binding},
		'pages'		    => $data->{pages},
		'weight'		=> $data->{weight},
		'width'		    => $data->{width},
		'height'		=> $data->{height}
	};

#use Data::Dumper;
#print STDERR "\n# book=".Dumper($bk);

    $self->book($bk);
	$self->found(1);
	return $self->book;
}

1;

__END__

=head1 REQUIRES

Requires the following modules be installed:

L<WWW::Scraper::ISBN::Driver>,
L<WWW::Mechanize>

=head1 SEE ALSO

L<WWW::Scraper::ISBN>,
L<WWW::Scraper::ISBN::Record>,
L<WWW::Scraper::ISBN::Driver>

=head1 BUGS, PATCHES & FIXES

There are no known bugs at the time of this release. However, if you spot a
bug or are experiencing difficulties that are not explained within the POD
documentation, please send an email to barbie@cpan.org or submit a bug to the
RT system (http://rt.cpan.org/Public/Dist/Display.html?Name=WWW-Scraper-ISBN-BookDepository_Driver).
However, it would help greatly if you are able to pinpoint problems or even
supply a patch.

Fixes are dependant upon their severity and my availablity. Should a fix not
be forthcoming, please feel free to (politely) remind me.

=head1 AUTHOR

  Barbie, <barbie@cpan.org>
  Miss Barbell Productions, <http://www.missbarbell.co.uk/>

=head1 COPYRIGHT & LICENSE

  Copyright (C) 2010-2013 Barbie for Miss Barbell Productions

  This module is free software; you can redistribute it and/or
  modify it under the Artistic Licence v2.

=cut
