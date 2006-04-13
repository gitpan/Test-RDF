package Test::RDF;

use warnings;
use strict;

use Carp;
use Test::Builder;
use RDF::Redland;
use base qw( Exporter );

our $VERSION = '0.0.3';
our @EXPORT  = qw( rdf_ok rdf_eq );

my $Test = Test::Builder->new();
RDF::Redland::set_log_handler(\&_log_handler);

sub rdf_ok {
    my ($format, $rdf_source, $message) = @_;
    croak "RDF serialization format required"  if !$format;
    croak "RDF data source required"           if !$rdf_source;

    my $rdf_by_ref = ref($rdf_source) eq 'SCALAR';
    croak "RDF file '$rdf_source' doesn't exist"
        if !$rdf_by_ref && !-e $rdf_source;

    # try to parse the file
    eval {
        my $parser = RDF::Redland::Parser->new($format);
        my $stream;
        if ( $rdf_by_ref ) {
            $stream = $parser->parse_string_as_stream(
                $$rdf_source,
                RDF::Redland::URI->new('http://example.org/'),
            );
        }
        else {
            my $uri = RDF::Redland::URI->new("file:$rdf_source");
            $stream = $parser->parse_as_stream($uri);
        }
        while ( !$stream->end() ) {
            my $statement = $stream->current();
            $stream->next();
        }
    };

    # determine success or failure
    $Test->ok(!$@, $message);
    $Test->diag($@) if $@;
}

sub rdf_eq {

    # create two RDF models in memory
    my @models;
    for my $model_name (qw( a b )) {
        my $storage = RDF::Redland::Storage->new();
        my $model = RDF::Redland::Model->new($storage);
        push @models, $model;

        # validate the format and filename arguments
        my $format     = shift @_;
        my $rdf_source = shift @_;

        croak "RDF serialization format required for part $model_name"
            if !$format;
        croak "RDF data source required for part $model_name"
            if !$rdf_source;

        my $rdf_by_ref = ref($rdf_source) eq 'SCALAR';
        croak "RDF file '$rdf_source' doesn't exist for part $model_name"
            if !$rdf_by_ref && !-e $rdf_source;

        # parse the file contents into the model
        my $parser = RDF::Redland::Parser->new($format);
        if ( $rdf_by_ref ) {
            $parser->parse_string_into_model(
                $$rdf_source,
                RDF::Redland::URI->new('http://example.org/'),
                $model,
            );
        }
        else {
            my $uri = RDF::Redland::URI->new("file:$rdf_source");
            $parser->parse_into_model( $uri, $uri, $model );
        }
    }

    my $message = shift @_;

    # are the models the same size?
    if ( $models[0]->size() != $models[1]->size() ) {
        $Test->ok(0, $message);
        $Test->diag(
            'Graphs differ in size: '
            . $models[0]->size() . ' vs. ' . $models[1]->size()
        );
        return;
    }

    # start the comparison with blank bnode maps
    _clear_bnode_mappings();

    # check all the statements for equivalence in the second model
    my $stream = $models[0]->as_stream();
    STATEMENT:
    while( !$stream->end() ) {
        my $stmt = $stream->current();
        next STATEMENT if _has_equivalent_statement($models[1], $stmt);
        $Test->ok(0, $message);
        $Test->diag(
            'Model B is missing the statement ' . $stmt->as_string()
        );
        return;
    }
    continue {
        $stream->next();
    }

    $Test->ok(1, $message);
}

sub _has_equivalent_statement {
    my ($model, $stmt) = @_;

    my $subject   = $stmt->subject();
    my $predicate = $stmt->predicate();
    my $object    = $stmt->object();
    my ($subject_is_floating, $object_is_floating) = (0)x2;

    # anchor the subject if possible
    if ( $subject->is_blank() ) {
        $subject_is_floating = 1;
        if ( my $mapped = _get_bnode_mapping($subject) ) {
            $subject = $mapped;
            $subject_is_floating = 0;
        }
    }

    # anchor the object if possible
    if ( $object->is_blank() ) {
        $object_is_floating = 1;
        if ( my $mapped = _get_bnode_mapping($object) ) {
            $object = $mapped;
            $object_is_floating = 0;
        }
    }

    if ( $subject_is_floating && $object_is_floating ) {
        my @candidates = $model->find_statements(
            RDF::Redland::Statement->new( undef, $predicate, undef )
        );
        for my $candidate (@candidates) {
            next if !$candidate->subject->is_blank();
            next if !$candidate->object->is_blank();
            # TODO what if $subject and $object are the same bnode?
            next if !_is_valid_mapping( $subject, $candidate->subject() );
            next if !_is_valid_mapping( $object, $candidate->object() );
            _create_bnode_mapping( $subject, $candidate->subject() );
            _create_bnode_mapping( $object, $candidate->object() );
            $model->remove_statement($candidate);
            return 1;
        }
    }
    elsif ( $subject_is_floating ) {
        my @sources = $model->sources( $predicate, $object );
        for my $source (@sources) {
            next if !$source->is_blank();
            next if !_is_valid_mapping( $subject, $source );
            _create_bnode_mapping( $subject, $source );
            $model->remove_statement( $source, $predicate, $object );
            return 1;
        }
    }
    elsif ( $object_is_floating ) {
        my @targets = $model->targets( $subject, $predicate );
        for my $target (@targets) {
            next if !$target->is_blank();
            next if !_is_valid_mapping( $object, $target );
            _create_bnode_mapping( $object, $target );
            $model->remove_statement( $subject, $predicate, $target );
            return 1;
        }
    }
    else {
        my $anchored_stmt
            = RDF::Redland::Statement->new( $subject, $predicate, $object );
        if ( $model->contains_statement($anchored_stmt) ) {
            $model->remove_statement($anchored_stmt);
            return 1;
        }
    }

    return;  # no equivalent statement found
}

{
    # map bnodes between models to insure that we get
    # a true bijection when calculating rdf_eq()
    my %a_to_b;
    my %b_to_a;
    sub _clear_bnode_mappings {
        %a_to_b = ();
        %b_to_a = ();
    }
    sub _get_bnode_mapping {
        my ($bnode_a) = @_;
        return $a_to_b{ $bnode_a->blank_identifier() };
    }
    sub _is_valid_mapping {
        my ( $bnode_a, $bnode_b ) = @_;
        return if $a_to_b{ $bnode_a->blank_identifier() };
        return if $b_to_a{ $bnode_b->blank_identifier() };
        return 1;
    }
    sub _create_bnode_mapping {
        my ( $bnode_a, $bnode_b ) = @_;
        die "Invalid mapping" if !_is_valid_mapping( $bnode_a, $bnode_b );
        $a_to_b{ $bnode_a->blank_identifier() } = $bnode_b;
        $b_to_a{ $bnode_b->blank_identifier() } = $bnode_a;
    }
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
 
Test::RDF - Test RDF data for validity and equality
 
 
=head1 VERSION
 
This documentation refers to Test::RDF version 0.0.3
 
 
=head1 SYNOPSIS
 
    use Test::More tests => 3;
    use Test::RDF;
    
    rdf_ok( rdfxml => 'data.rdf', 'data validity' );
    rdf_eq( rdfxml => 'data.rdf', turtle => 'data.ttl', 'XML==Turtle' );
    
    rdf_eq(
        ntriples => \'_:a <http://example.org> "literal .',
        turtle   => \' [] <http://example.org> "literal .',
        'ntriples and turtle blank node equivalence',
    );

=head1 DESCRIPTION

Test::RDF is used for testing RDF data in various formats.  Currently,
Test::RDF exports two functions L</rdf_ok> (check the validity of various RDF
serialization formats) and L</rdf_eq> (check for RDF graph equivalence).

=head1 SUBROUTINES

=head2 rdf_eq

    Arguments: $FORMAT, $SOURCE, $FORMAT, $SOURCE [, $MESSAGE]

Compares the RDF graphs created by the two RDF serializations for graph
equivalence.  RDF graph equivalence is defined by the RDF Concepts and
Abstract Syntax document here:
L<http://www.w3.org/TR/rdf-concepts/#section-graph-equality>.  If the two
graphs are equivalent, the test passes.  If the two graphs are not equivalent,
the test fails with a helpful diagnostic message.

The C<$FORMAT> arguments should be one of: C<rdfxml>, C<turtle> or C<ntriples>
(actually, you can use any format allowed by your version of
L<RDF::Redland::Parser>).  C<$SOURCE> should be either the path to a file or a
reference to a scalar containing RDF data in the specified format.
C<$MESSAGE> is an optional message to use when displaying the "ok" or "not ok"
message.

C<rdf_eq> does not correctly handle reflexive statements involving bnodes.
That is, statements where subject and object are the same blank node.
 
=head2 rdf_ok

    Arguments: $FORMAT, $SOURCE [, $MESSAGE]

C<$FORMAT> specifies the expected format of the RDF file.  It should be one
of: C<rdfxml>, C<turtle> or C<ntriples> (actually, you can use any format
allowed by your version of L<RDF::Redland::Parser> but those three are the
most commonly useful).  C<$SOURCE> should be either the path to a file or a
reference to a scalar containing RDF data in the specified format.
C<$MESSAGE> is an optional message to use when displaying the "ok" or "not ok"
message.
 
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
 
