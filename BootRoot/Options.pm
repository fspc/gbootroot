############################################################################
##
##  Options.pm 
##  Copyright (C) 2000, 2001, 2002 by Jonathan Rosenbaum
##                              <freesource@users.sourceforge.net>
##
##  This program is free software; you may redistribute it and/or modify
##  it under the terms of the GNU General Public License as published by
##  the Free Software Foundation; either version 2 of the License, or
##  (at your option) any later version.
##
##  This program is distributed in the hope that it will be useful,
##  but WITHOUT ANY WARRANTY; without even the implied warranty of
##  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##  GNU General Public License for more details.
## 
##  You should have received a copy of the GNU General Public License
##  along with this program; if not, write to the Free Software
##  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
##
##############################################################################

package BootRoot::Options;
use vars qw(@ISA @EXPORT %EXPORT_TAGS);
use Exporter;
use Getopt::Long;

@ISA = qw(Exporter);
@EXPORT =  qw(option %option);

sub option {

  Getopt::Long::config("bundling","no_auto_abbrev");
    GetOptions (
		
		\%option,
		"h",
		"help",
		"root-filename=s",
		"uml-kernel=s", 
		"method=s",
		"template=s",           # The only required argument
		"filesystem-size=s",
		"filesystem-command=s",
		"uml-exclusively=s",    # on/off
		"preserve-ownership=s",
		"kernel=s",
		"kernel-version=s",
		"no-stdout"		
		
		);

}

1;




