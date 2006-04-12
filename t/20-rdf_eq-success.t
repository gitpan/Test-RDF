use strict;
use warnings;
use Test::More;
use Test::RDF;

my @tests = (
    [ turtle => 't/rdf/a0.ttl', turtle => 't/rdf/a0.ttl' ],
    [ turtle => 't/rdf/a0.ttl', turtle => 't/rdf/a1.ttl' ],
    [ turtle => 't/rdf/b0.ttl', turtle => 't/rdf/b1.ttl' ],
    [ turtle => 't/rdf/f0.ttl', turtle => 't/rdf/f0.ttl' ],
    [ turtle => 't/rdf/g0.ttl', turtle => 't/rdf/g0.ttl' ],
);

my @skip = (
    [ 'Fix reflexive bnode statements', turtle => 't/rdf/e0.ttl', turtle => 't/rdf/e0.ttl' ],
);

plan tests => 2*(scalar @tests) + 2*(scalar @skip);

for my $test (@tests) {
    rdf_eq(@{$test}, "$test->[1] eq $test->[3]");
    rdf_eq(@{$test}[2,3], @{$test}[0,1], "$test->[3] eq $test->[1]");
}

for my $test (@skip) {
    SKIP: {
        skip shift(@$test), 2;
        rdf_eq(@{$test}, "$test->[1] eq $test->[3]");
        rdf_eq(@{$test}[2,3], @{$test}[0,1], "$test->[3] eq $test->[1]");
    }
}
