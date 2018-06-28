use strict;
use warnings;
use utf8;
use File::Spec;
use File::Basename;
use lib File::Spec->catdir(dirname(__FILE__), 'extlib', 'lib', 'perl5');
use lib File::Spec->catdir(dirname(__FILE__), 'lib');
use Amon2::Lite;
use Data::Dumper;
{
    package Data::Dumper;
    sub qquote { return shift; }
}
$Data::Dumper::Useperl = 1;
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

our $VERSION = '0.13';

# put your configuration here
sub load_config {
    my $c = shift;

    my $mode = $c->mode_name || 'development';
    my $db_config = {
        'host' => $ENV{'ISHOCON2_DB_HOST'} || 'localhost',
        'port' => $ENV{'ISHOCON2_DB_PORT'} || 3306,
        'username' => $ENV{'ISHOCON2_DB_USER'} || 'isocon',
        'password' => $ENV{'ISHOCON2_DB_PASSWORD'} || 'ishocon',
        'database' => $ENV{'ISHOCON2_DB_NAME'} || 'ishocon2',
    };

    +{
        'DBI' => [
            "dbi:mysql:host=" . $db_config->{'host'} . ";port=" . $db_config->{'port'} . ";database=" . $db_config->{'database'} . ";",
            $db_config->{'username'},
            $db_config->{'password'},
            +{
                mysql_enable_utf8 => 1,
            },
        ],
    }

}

sub election_results {
    my $c = shift;
    my $query = <<'SQL';
SELECT c.id, c.name, c.political_party, c.sex, v.count
FROM candidates AS c
LEFT OUTER JOIN
  (SELECT candidate_id, COUNT(*) AS count
  FROM votes
  GROUP BY candidate_id) AS v
ON c.id = v.candidate_id
ORDER BY v.count DESC
SQL
    my $sth = $c->dbh->prepare($query);
    $sth->execute();
    my $rows = $sth->fetchall_arrayref({});
    return $rows;
}

sub voice_of_supporter {
    my ($c, $candidate_ids) = @_;
    my $query = <<'SQL';
SELECT keyword
FROM votes
WHERE candidate_id IN (?)
GROUP BY keyword
ORDER BY COUNT(*) DESC
LIMIT 10
SQL
    my $sth = $c->dbh->prepare($query);
    $sth->execute($candidate_ids);
    
    my $rows = $sth->fetchall_arrayref([0]);
    return $rows;
}


get '/' => sub {
};

get '/political_parties/{name}' => sub {
    my ($c, $args) = @_;
    my $votes = 0;
    my $rows = &election_results($c);
    foreach my $row (@$rows){
        $votes += $row->{'count'} || 0 if $row->{'political_party'} eq $args->{name};
    }
    my $sth = $c->dbh->prepare('SELECT * FROM candidates WHERE political_party = ?');
    $sth->execute($args->{name});
    my $candidates = $sth->fetchall_arrayref({});
    print Dumper $candidates;
    my $candidate_ids = map { $_->{'id'} } @$candidates;
    my $keywords = voice_of_supporter($c, $candidate_ids);
    
    return $c->create_response(200, ['Content-Type' => 'text/html; charset=utf-8'], Encode::encode_utf8(Dumper $keywords));
};


# load plugins
__PACKAGE__->load_plugin('Web::CSRFDefender' => {
    post_only => 1,
});
__PACKAGE__->load_plugin('DBI');
# __PACKAGE__->load_plugin('Web::FillInFormLite');
# __PACKAGE__->load_plugin('Web::JSON');

__PACKAGE__->enable_session();

__PACKAGE__->to_app(handle_static => 1);

__DATA__

@@ index.tt
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title>ishocon2</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js"></script>
    <script type="text/javascript" src="[% uri_for('/static/js/main.js') %]"></script>
    <link href="//netdna.bootstrapcdn.com/twitter-bootstrap/2.3.1/css/bootstrap-combined.min.css" rel="stylesheet">
    <script src="//netdna.bootstrapcdn.com/twitter-bootstrap/2.3.1/js/bootstrap.min.js"></script>
    <link rel="stylesheet" href="[% uri_for('/static/css/main.css') %]">
</head>
<body>
    <div class="container">
        <header><h1>ishocon2</h1></header>
        <section class="row">
            This is a ishocon2
        </section>
        <footer>Powered by <a href="http://amon.64p.org/">Amon2::Lite</a></footer>
    </div>
</body>
</html>

@@ /static/js/main.js

@@ /static/css/main.css
footer {
    text-align: right;
}
