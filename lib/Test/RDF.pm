package Test::RDF;

use warnings;
use strict;

use Carp;
use Test::Builder;
use RDF::Redland;
use base qw( Exporter );

our $VERSION = '0.0.1';
our @EXPORT  = qw( rdf_ok );

my $Test = Test::Builder->new();
RDF::Redland::set_log_handler(\&_log_handler);

sub rdf_ok {
    my ($format, $filename, $message) = @_;
    croak "RDF serialization format required"  if !$format;
    croak "RDF filename required"              if !$filename;
    croak "RDF file '$filename' doesn't exist" if !-e $filename;
    $message ||= '';

    # try to parse the file
    eval {
        my $parser = RDF::Redland::Parser->new($format);
        my $uri = RDF::Redland::URI->new("file:$filename");
        my $stream = $parser->parse_as_stream($uri);
        while ( $stream && !$stream->end() ) {
            my $statement = $stream->current();
            $stream->next();
        }
    };

    # determine success or failure
    $Test->ok(!$@, $message);
    $Test->diag($@) if $@;
}

# Handle error and warning messages from Redland, cleaning
# up the messages as necessary
sub _log_handler {
    my (
        $code,   $level, $facility, $message, $line,
        $column, $byte,  $file,     $uri
    ) = @_;

    die "$message\n";
}

1;

__END__

=head1 NAME
 
Test::RDF - test the validity of RDF data
 
 
=head1 VERSION
 
This documentation refers to Test::RDF version 0.0.1
 
 
=head1 SYNOPSIS
 
    use Test::More tests => 1;
    use Test::RDF;
    
    rdf_ok( rdfxml => 'data.rdf', 'data validity' );

=head1 DESCRIPTION

Test::RDF is used for testing RDF data in various formats.  Currently,
Test::RDF exports a single function C<rdf_ok> which checks the validity of an
RDF file.  See L<rdf_ok> for details.

=head1 SUBROUTINES
 
=head2 rdf_ok $FORMAT, $FILENAME [, $MESSAGE]

C<$FORMAT> specifies the expected format of the RDF file.  It should be one
of: rdfxml, turtle or ntriples.  C<$FILENAME> should be the path to a file
containing RDF data in the specified format.  C<$MESSAGE> is an optional
message to use when displaying the "ok" or "not ok" message.
 
=head1 CONFIGURATION AND ENVIRONMENT
 
Test::RDF requires no configuration files or environment variables.
 
=head1 DEPENDENCIES
 
=over

=item *

RDF::Redland

=back
 
=head1 INCOMPATIBILITIES
 
None known
 
=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to
C<bug-test-rdf at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-RDF>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::RDF

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Test-RDF>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Test-RDF>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Test-RDF>

=item * Search CPAN

L<http://search.cpan.org/dist/Test-RDF>

=back

=head1 ACKNOWLEDGEMENTS

Dave Beckett for Redland.

=head1 AUTHOR

Michael Hendricks  <michael@palmcluster.org>

=head1 LICENSE AND COPYRIGHT
 
Copyright (c) 2006 Michael Hendricks (<michael@palmcluster.org>). All rights
reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
 
