#############################################################################
##
##  Error.pm 
##  Copyright (C) 2000 Modifications by the gBootRoot Project
##  Copyright (C) 2000 by Jonathan Rosenbaum
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

package Error;
use vars qw(@ISA @EXPORT %EXPORT_TAGS);
use Exporter;
@ISA = qw(Exporter);
@EXPORT =  qw(error_window errmk errcp errum errm errrm err err_custom
	      err_custom_perl destroy_window);

use strict;
use Yard;

my $true = 1;
my $false = 0;
my $error_window;
my $verbosity_window;


###############
# Error Section
###############
# The biggest problem here is that err? are hardwired, perhaps one
# could be used and message could just be $!, err_custom is nice.
# All err? report errors if $? > 0.

sub error_window {
    my (@error) = @_;
    my $output = join("",@error);

    if (not defined $error_window) {
    $error_window = new Gtk::Dialog;
    $error_window->signal_connect("destroy", \&destroy_window,
                                  \$error_window);
    $error_window->signal_connect("delete_event", \&destroy_window, 
                                  \$error_window);
    $error_window->set_title("gBootRoot ERROR");
    $error_window->border_width(15);
    my $label = new Gtk::Label($output);
    #$label->set_justify("left") if $_[1];
    $error_window->vbox->pack_start( $label, $true, $true, 15 );
    $label->show();
    my $button = new Gtk::Button("OK");
    $button->signal_connect("clicked", sub {destroy $error_window});
    $button->can_default(1);
    $error_window->action_area->pack_start($button, $false, $false,0);
    $button->grab_default;
    $button->show;
   }
     if (!visible $error_window) {
         show $error_window;
     }
     else {
        destroy $error_window;
     }

} # end sub error_window

sub errmk {
   error_window("gBootRoot: ERROR: Could not make important directories") if $? != 0;
   if (defined $error_window) {
       if ($error_window->visible) {
          return 2;
       }
   }
}

sub errcp {
   error_window("gBootRoot: ERROR: Could not copy over important stuff") if $? != 0;
   if (defined $error_window) {
       if ($error_window->visible) {
          return 2;
       }
   }
}


sub errum {
   error_window("gBootRoot: ERROR: Could not umount the device") if $? != 0;
   if (defined $error_window) {
       if ($error_window->visible) {
          return 2;
       }
   }
}

sub errm {
   error_window("gBootRoot: ERROR: Could not mount device") if $? != 0;
   if (defined $error_window) {
       if ($error_window->visible) {
          return 2;
       }
   }
}

sub errrm {
   error_window("gBootRoot: ERROR: Could not remove a directory or file")
                if $? != 0;
   if (defined $error_window) {
       if ($error_window->visible) {
          return 2;
       }
   }
}

sub err {
   error_window("gBootRoot: ERROR: Not enough space after all") if ($? > 0);
   if (defined $error_window) {
       if ($error_window->visible) {
          return 2;
       }
   }
}

sub err_custom {

    if (defined $_[2]) {
         system("$_[0] > /dev/null 2>&1");
    }
    else {
     sys("$_[0]");
    }
    error_window($_[1]) if ($? != 0);
    if (defined $error_window) {
        if ($error_window->visible) {
           return 2;
        }
    }
}

sub err_custom_perl {

   if ((split(/ /, $_[0]))[0] eq "mkdir") {
      my $two = (split(/ /, $_[0]))[1];
      mkdir($two,0755); # Anyone allowed in
    }
    error_window($_[1]) if ($? != 0);
    if (defined $error_window) {
        if ($error_window->visible) {
           return 2;
        }
    }
}

###################
# End Error Section
###################

################
# MISC FUNCTIONS
################
# Can be relocated

# pulled from test.pl
sub destroy_window {
        my($widget, $windowref, $w2) = @_;
        $$windowref = undef;
        $w2 = undef if defined $w2;
        0;
}


1;
