package SQL::Translator::Producer::XML;

# -------------------------------------------------------------------
# $Id: XML.pm,v 1.15 2003-08-22 22:51:51 kycl4rk Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>.
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

=pod

=head1 NAME

SQL::Translator::Producer::XML - Alias to XML::SQLFairy producer

=head1 DESCRIPTION

Previous versions of SQL::Translator included an XML producer, but the 
namespace has since been further subdivided.  Therefore, this module is 
now just just an alias to the XML::SQLFairy producer.

=head1 SEE ALSO

SQL::Translator::Producer::XML::SQLFairy.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

=cut

# -------------------------------------------------------------------

use strict;
use vars qw[ $VERSION $DEBUG ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.15 $ =~ /(\d+)\.(\d+)/;
$DEBUG = 1 unless defined $DEBUG;

use SQL::Translator::Producer::XML::SQLFairy;

*produce = \&SQL::Translator::Producer::XML::SQLFairy::produce;

1;