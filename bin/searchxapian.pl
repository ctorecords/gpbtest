#!/usr/bin/env perl
use lib::abs;
use uni::perl ':dumper';
use Search::Xapian;

my ($dir, $substr) = @ARGV;
die "Usage: $0 /path/to/xapian index_substring\n" unless $dir && $substr;

warn qq{Search for "$substr"};
my $db = Search::Xapian::Database->new($dir);
my $query = Search::Xapian::Query->new("N$substr");

my $enquire = Search::Xapian::Enquire->new($db);
$enquire->set_query($query);

my $mset = $enquire->get_mset(0, 100);

for my $match ($mset->items) {
    my $data = $match->get_document->get_data;
    print "$data\n";
}
