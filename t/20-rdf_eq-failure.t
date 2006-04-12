use strict;
use warnings;
use Test::More;
use Test::Builder::Tester;
use Test::RDF;

my @tests = (
    [
        turtle => 't/rdf/a0.ttl',
        turtle => 't/rdf/b0.ttl',
        'Graphs differ in size: 6 vs. 2',
    ],
    [
        turtle => 't/rdf/b0.ttl',
        turtle => 't/rdf/a0.ttl',
        'Graphs differ in size: 2 vs. 6',
    ],
    [  # differ only in a single language type
        turtle => 't/rdf/a0.ttl',
        turtle => 't/rdf/c0.ttl',
        'Model B is missing the statement {[http://example.org/a.rdf#one], [http://example.org/a.rdf#two], "four@en"}'
    ],
    [  # too few unique blank nodes
        turtle => 't/rdf/b0.ttl',
        turtle => 't/rdf/d0.ttl',
        undef, # diag message changes
    ],
    [  # too few unique blank nodes
        turtle => 't/rdf/d0.ttl',
        turtle => 't/rdf/b0.ttl',
        undef,  # diag message changes
    ],
);
plan tests => (scalar @tests);

for my $test (@tests) {
    test_out("not ok 1 - message");
    test_fail(+2);
    test_diag($test->[4]) if defined $test->[4];
    rdf_eq( @{$test}[0 .. 3], 'message' );
    test_test(
        name     => "$test->[1] eq $test->[3]",
        skip_err => !defined($test->[4]),
    );
}

