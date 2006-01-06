use Test::More;
use Test::RDF;

my @test_files = _find_test_files();
plan skip_all => "Couldn't find any test files" if !@test_files;
plan tests => (scalar @test_files);

for my $file (@test_files) {
    my $format = _determine_format($file);
    rdf_ok( $format => $file, $file );
}

sub _find_test_files {
    return glob 't/good/*';
}

sub _determine_format {
    my ($filename) = @_;
    my ($ext) = $filename =~ m/.* [.] (\w*)\z/xms;
    return if !$ext;
    return {
        ttl => 'turtle',
        nt  => 'ntriples',
        rdf => 'rdfxml',
    }->{$ext};
}
