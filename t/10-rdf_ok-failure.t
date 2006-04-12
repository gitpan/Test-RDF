use strict;
use warnings;
use Test::More tests => 5;
use Test::Builder::Tester;
use Test::RDF;

{
    my $file = 't/bad/not-RDF.rdf';
    test_out("not ok 1 - message");
    test_fail(+2);
    test_diag('XML parser error - Document is empty');
    rdf_ok( rdfxml => $file, 'message' );
    test_test('not remotely RDF');
}

{
    my $file = 't/bad/malformed.rdf';
    test_out("not ok 1 - message");
    test_fail(+2);
    test_diag('XML parser error - Opening and ending tag mismatch: rdf:Seq line 0 and rdf:Bag');
    rdf_ok( rdfxml => $file, 'message' );
    test_test('malformed RDF/XML');
}

# provide no file format
eval { rdf_ok( undef, 'filename' ) };
like( $@, qr/RDF serialization format required/, 'no format' );

# provide no filename
eval { rdf_ok( rdfxml => undef ) };
like( $@, qr/RDF filename required/, 'no filename' );

# provide a filename to a nonexistant file
eval { rdf_ok( rdfxml => 'no_such_file_as_this' ) };
like( $@, qr/RDF file 'no_such_file_as_this' doesn't exist/, 'file does not exist' );

