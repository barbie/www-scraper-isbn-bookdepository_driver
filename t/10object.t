#!/usr/bin/perl -w
use strict;

use lib './t';
use Test::More tests => 40;
use WWW::Scraper::ISBN;

###########################################################

my $DRIVER          = 'BookDepository';
my $CHECK_DOMAIN    = 'www.google.com';

my %tests = (
    '0552557803' => [
        [ 'is',     'isbn',         '9780552557801'     ],
        [ 'is',     'isbn10',       '0552557803'        ],
        [ 'is',     'isbn13',       '9780552557801'     ],
        [ 'is',     'ean13',        '9780552557801'     ],
        [ 'is',     'title',        'Nation'            ],
        [ 'is',     'author',       'Terry Pratchett'   ],
        [ 'is',     'publisher',    'Random House Children\'s Books'    ],
        [ 'is',     'pubdate',      '24 September 2009' ],
        [ 'is',     'binding',      'Paperback'         ],
        [ 'is',     'pages',        '432'               ],
        [ 'is',     'width',        '111'               ],
        [ 'is',     'height',       '178'               ],
        [ 'is',     'weight',       undef               ],
        [ 'like',   'image_link',   qr|/assets/images/book/large/9780/5525/9780552557801.jpg|       ],
        [ 'like',   'thumb_link',   qr|/assets/images/book/medium/9780/5525/9780552557801.jpg|      ],
        [ 'like',   'description',  qr|When a giant wave destroys his entire Nation|                ],
        [ 'like',   'book_link',    qr|http://www.bookdepository.co.uk/book/9780552557801/Nation|   ]
    ],
    '9780571239566' => [
        [ 'is',     'isbn',         '9780571239566'     ],
        [ 'is',     'isbn10',       '0571239560'        ],
        [ 'is',     'isbn13',       '9780571239566'     ],
        [ 'is',     'ean13',        '9780571239566'     ],
        [ 'is',     'title',        'Touching from a Distance'  ],
        [ 'is',     'author',       'Deborah Curtis'    ],
        [ 'is',     'publisher',    'Faber and Faber'   ],
        [ 'is',     'pubdate',      '04 October 2007'   ],
        [ 'is',     'binding',      'Paperback'         ],
        [ 'is',     'pages',        240                 ],
        [ 'is',     'width',        129                 ],
        [ 'is',     'height',       198                 ],
        [ 'is',     'weight',       200                 ],
        [ 'like',   'image_link',   qr|/assets/images/book/large/9780/5712/9780571239566.jpg|   ],
        [ 'like',   'thumb_link',   qr|/assets/images/book/medium/9780/5712/9780571239566.jpg|  ],
        [ 'like',   'description',  qr|Ian Curtis left behind a legacy rich in artistic genius| ],
        [ 'like',   'book_link',    qr|http://www.bookdepository.co.uk/book/9780571239566/Touching-from-a-Distance| ]
    ],
);

my $tests = 0;
for my $isbn (keys %tests) { $tests += scalar( @{ $tests{$isbn} } ) + 2 }


###########################################################

my $scraper = WWW::Scraper::ISBN->new();
isa_ok($scraper,'WWW::Scraper::ISBN');

SKIP: {
	skip "Can't see a network connection", $tests+1   if(pingtest($CHECK_DOMAIN));

	$scraper->drivers($DRIVER);

    # this ISBN doesn't exist
	my $isbn = "0987654321";
    my $record;
    eval { $record = $scraper->search($isbn); };
    if($@) {
        like($@,qr/Invalid ISBN specified/);
    }
    elsif($record->found) {
        ok(0,'Unexpectedly found a non-existent book');
    } else {
		like($record->error,qr/Failed to find that book on The Book Depository website|website appears to be unavailable/);
    }

    for my $isbn (keys %tests) {
        eval { $record = $scraper->search($isbn) };
        my $error = $@ || $record->error || '';

        SKIP: {
            skip "Website unavailable", scalar(@{ $tests{$isbn} }) + 2   
                if($error =~ /website appears to be unavailable/);
            skip "Book unavailable", scalar(@{ $tests{$isbn} }) + 2   
                if($error =~ /Failed to find that book/ || !$record->found);

            unless($record && $record->found) {
                diag("error=$error, record error=".$record->error);
            }

            is($record->found,1);
            is($record->found_in,$DRIVER);

            my $book = $record->book;
            for my $test (@{ $tests{$isbn} }) {
                if($test->[0] eq 'ok')          { ok(       $book->{$test->[1]},             ".. '$test->[1]' found [$isbn]"); } 
                elsif($test->[0] eq 'is')       { is(       $book->{$test->[1]}, $test->[2], ".. '$test->[1]' found [$isbn]"); } 
                elsif($test->[0] eq 'isnt')     { isnt(     $book->{$test->[1]}, $test->[2], ".. '$test->[1]' found [$isbn]"); } 
                elsif($test->[0] eq 'like')     { like(     $book->{$test->[1]}, $test->[2], ".. '$test->[1]' found [$isbn]"); } 
                elsif($test->[0] eq 'unlike')   { unlike(   $book->{$test->[1]}, $test->[2], ".. '$test->[1]' found [$isbn]"); }

            }

            #use Data::Dumper;
            #diag("book=[".Dumper($book)."]");
        }
    }
}

###########################################################

# crude, but it'll hopefully do ;)
sub pingtest {
    my $domain = shift or return 0;
    my $cmd =   $^O =~ /solaris/i                           ? "ping -s $domain 56 1" :
                $^O =~ /dos|os2|mswin32|netware|cygwin/i    ? "ping -n 1 $domain "
                                                            : "ping -c 1 $domain >/dev/null 2>&1";

    eval { system($cmd) }; 
    if($@) {                # can't find ping, or wrong arguments?
        diag();
        return 1;
    }

    my $retcode = $? >> 8;  # ping returns 1 if unable to connect
    return $retcode;
}
