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
		"genext2fs-dir=s",            #  /usr/lib/bootroot/
		"no-stdout",

		# hidden options for package making or for people who
		# read the source Luke.  Path's relative to `pwd`.

		# home by itself allows the GUI to be tested in it's 
		# immediate directory, this overcomes the need to always
		# install stuff locally to test it.
		# It translates to gui_mode and lets the program know that
		# Initrd.gz, genext2fs, linuxbr, and  root_fs_helper
		# be used in the directory specified.  
		# So "perl -I . ./gbootroot --home ."  will test in the
		# immediate directory.  Good for CVS development, and
		# testing for those who don't want to install.
		# Also output will go to stdout which is cool.
		# "home" with "template" needs the additional options to
		# choose immediate dir., for instance, genext2fs.

		"home=s",                  # by itself = GUI
		                           # path relative to `pwd` usually "."
		"root-fs-helper-location=s", # full path or rel path 
		                             # in Yard $ubd0
		"expect-program=s",          # i.e. ./expect_uml

		);

}

1;




