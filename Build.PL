use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Test::RDF',
    license             => 'perl',
    dist_version_from   => 'lib/Test/RDF.pm',
    sign                => 1,
    create_makefile_pl  => 'passthrough',
    requires => {
        'RDF::Redland' => '1.000101',  # 1.0.1.1
    },
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'Test-RDF-*' ],
);

$builder->create_build_script();
