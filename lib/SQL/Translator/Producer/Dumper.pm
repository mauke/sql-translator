package SQL::Translator::Producer::Dumper;

# -------------------------------------------------------------------
# $Id: Dumper.pm,v 1.2 2004-03-09 19:35:40 kycl4rk Exp $
# -------------------------------------------------------------------
# Copyright (C) 2002-4 SQLFairy Authors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; version 2.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
# 02111-1307  USA
# -------------------------------------------------------------------

=head1 NAME

SQL::Translator::Producer::Dumper - SQL Dumper producer for SQL::Translator

=head1 SYNOPSIS

  use SQL::Translator::Producer::Dumper;

  Options:

    db_user         Database username
    db_password     Database password
    dsn             DSN for DBI
    mysql_loadfile  Create MySQL's LOAD FILE syntax instead of INSERTs
    skip=t1[,t2]    Skip tables in comma-separated list
    skiplike=regex  Skip tables in comma-separated list

=head1 DESCRIPTION

This producer creates a Perl script that can connect to a database and
dump the data as INSERT statements (a la mysqldump) or as a file
suitable for MySQL's LOAD DATA command.  If you enable "add-truncate"
or specify tables to "skip" (also using the "skiplike" regular
expression) then the generated dumper script will leave out those
tables.  However, these will also be options in the generated dumper,
so you can wait to specify these options when you dump your database.
The database username, password, and DSN can be hardcoded into the
generated script, or part of the DSN can be intuited from the
"database" argument.

=cut

use strict;
use Config;
use SQL::Translator;
use File::Temp 'tempfile';
use Template;
use vars qw($VERSION);

use Data::Dumper;

$VERSION = sprintf "%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/;

sub produce {
    my $t              = shift;
    my $args           = $t->producer_args;
    my $schema         = $t->schema;
    my $add_truncate   = $args->{'add_truncate'}   || 0; 
    my $skip           = $args->{'skip'}           || '';
    my $skiplike       = $args->{'skiplike'}       || '';
    my $db_user        = $args->{'db_user'}        || 'db_user';
    my $db_pass        = $args->{'db_password'}    || 'db_pass';
    my $parser_name    = $t->parser_type;
    my %skip           = map { $_, 1 } map { s/^\s+|\s+$//; $_ } 
                         split (/,/, $skip);
    my $sqlt_version   = $t->version;

    if ( $parser_name  =~ /Parser::(\w+)$/ ) { 
        $parser_name = $1 
    }

    my %type_to_dbd    = (
        MySQL          => 'mysql',
        Oracle         => 'Oracle',
        PostgreSQL     => 'Pg',
        SQLite         => 'SQLite',
        Sybase         => 'Sybase',
    );
    my $dbd            = $type_to_dbd{ $parser_name } || 'DBD';
    my $dsn            = $args->{'dsn'} || "dbi:$dbd:";
    if ( $dbd eq 'Pg' && ! $args->{'dsn'} ) {
        $dsn .= 'dbname=dbname;host=hostname';
    }
    elsif ( $dbd eq 'Oracle' && ! $args->{'dsn'} ) {
        $db_user = "$db_user/$db_pass@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)" .
            "(HOST=hostname)(PORT=1521))(CONNECT_DATA=(SID=sid)))";
        $db_pass = '';
    }
    elsif ( $dbd eq 'mysql' && ! $args->{'dsn'} ) {
        $dsn .= 'dbname';
    }

    my $template      = Template->new;
    my $template_text = template();
    my $out;
    $template->process( 
        \$template_text, 
        { 
            translator     => $t,
            schema         => $schema,
            db_user        => $db_user,
            db_pass        => $db_pass,
            dsn            => $dsn,
            perl           => $Config{'startperl'},
            skip           => \%skip,
            skiplike       => $skiplike,
        }, 
        \$out 
    ) or die $template->error;

    return $out;
}

# -------------------------------------------------------------------
sub template {
#
# Returns the template to be processed by Template Toolkit
#
    return <<'EOF';
[% perl || '#!/usr/bin/perl' %]
[% USE date %]
#
# Generated by SQL::Translator [% translator.version %]
# [% date.format( date.now, "%Y-%m-%d" ) %]
# For more info, see http://sqlfairy.sourceforge.net/
#

use strict;
use Cwd;
use DBI;
use Getopt::Long;
use File::Spec::Functions 'catfile';

my ( $help, $add_truncate, $skip, $skiplike, $no_comments, $mysql_loadfile );
GetOptions(
    'add-truncate'   => \$add_truncate,
    'h|help'         => \$help,
    'no-comments'    => \$no_comments,
    'mysql-loadfile' => \$mysql_loadfile,
    'skip:s'         => \$skip,
    'skiplike:s'     => \$skiplike,
);

if ( $help ) {
    print <<"USAGE";
Usage:
  $0 [options]

  Options:
    -h|--help          Show help and exit
    --add-truncate     Add "TRUNCATE TABLE" statements
    --mysql-loadfile   Create MySQL's LOAD FILE syntax, not INSERTs
    --no-comments      Suppress comments
    --skip=t1[,t2]     Comma-separated list of tables to skip
    --skiplike=regex   Comma-separated list of tables to skip

USAGE
    exit(0);
}

$no_comments = 1 if $mysql_loadfile;

[%-
SET table_defs = [];
SET max_field  = 0;

FOREACH table IN schema.get_tables;
    SET table_name = table.name;
    NEXT IF skip.$table_name;
    NEXT IF skiplike AND table_name.match("(?:$skiplike)");

    SET field_names = [];
    SET types       = {};
    FOR field IN table.get_fields;
        field_name = field.name;
        fname_len  = field.name.length;
        max_field  = fname_len > max_field ? fname_len : max_field;
        types.$field_name = field.data_type.match( '(char|str|long|text)' )
            ? 'string' : 'number';
        field_names.push( field_name );
    END;

    table_defs.push({
        name   => table_name,
        types  => types,
        fields => field_names,
    });
END 
-%]

my $db     = DBI->connect(
    '[% dsn %]', 
    '[% db_user %]', 
    '[% db_pass %]', 
    { RaiseError => 1 }
);
my %skip   = map { $_, 1 } map { s/^\s+|\s+$//; $_ } split (/,/, $skip);
my @tables = (
[%- FOREACH t IN table_defs %]
    {
        table_name  => '[% t.name %]',
        fields      => [ qw/ [% t.fields.join(' ') %] / ],
        types       => {
            [%- FOREACH fname IN t.types.keys %]
            '[% fname %]' => '[% t.types.$fname %]',
            [%- END %]
        },
    },
[%- END %]
);

for my $table ( @tables ) {
    my $table_name = $table->{'table_name'};
    next if $skip{ $table_name };
    next if $skiplike && $table_name =~ qr/$skiplike/;

    my ( $out_fh, $outfile );
    if ( $mysql_loadfile ) {
        $outfile = catfile( cwd(), "$table_name.txt" );
        open $out_fh, ">$outfile" or 
            die "Can't write LOAD FILE to '$table_name': $!\n";
    }

    print "--\n-- Data for table '$table_name'\n--\n" unless $no_comments;

    if ( $add_truncate ) {
        print "TRUNCATE TABLE $table_name;\n";
    }

    my $data = $db->selectall_arrayref(
        'select ' . join(', ', @{ $table->{'fields'} } ) . " from $table_name",
        { Columns => {} }
    );

    for my $rec ( @{ $data } ) {
        my @vals;
        for my $fld ( @{ $table->{'fields'} } ) {
            my $val = $rec->{ $fld };
            if ( $table->{'types'}{ $fld } eq 'string' ) {
                if ( defined $val ) {
                    $val =~ s/'/\\'/g;
                    $val = qq['$val']
                }
                else {
                    $val = qq[''];
                }
            }
            else {
                $val = defined $val ? $val : $mysql_loadfile ? '\N' : 'NULL';
            }
            push @vals, $val;
        }        

        if ( $mysql_loadfile ) {
            print $out_fh join("\t", @vals), "\n";
        }
        else {
            print "INSERT INTO $table_name (".
                join(', ', @{ $table->{'fields'} }) . 
                ' VALUES (', join(', ', @vals), ");\n";
        }
    }

    if ( $out_fh ) {
        print "LOAD DATA INFILE '$outfile' INTO TABLE $table_name ",
            "FIELDS OPTIONALLY ENCLOSED BY '\\'';\n";
        close $out_fh or die "Can't close filehandle: $!\n";
    }
    else {
        print "\n";
    }
}
EOF
}

1;

# -------------------------------------------------------------------
# To create a little flower is the labour of ages.
# William Blake
# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

=cut