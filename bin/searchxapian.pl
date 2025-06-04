#!/usr/bin/env perl
use lib::abs;
use uni::perl ':dumper';
use lib::abs '../lib';
use GPBExim;
use Search::Xapian;

my ($dir, $substr) = @ARGV;
#($dir, $substr) = qw{temp/xapian_tests yomlvprts};
die "Usage: $0 /path/to/xapian index_substring\n" unless $dir && $substr;

warn qq{Search for "$substr"};
my $db = Search::Xapian::Database->new($dir);
my $doc_count = $db->get_doccount;
warn "Total documents in index: $doc_count\n";

my $query = Search::Xapian::Query->new("N$substr");

my $enquire = Search::Xapian::Enquire->new($db);
$enquire->set_query($query);

my $mset = $enquire->get_mset(0, 100);

my %r;
for my $match ($mset->items) {
    my $data = $match->get_document->get_data;
    $r{$data}=1;
}
warn dumper(\%r);