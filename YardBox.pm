#############################################################################
##
##  YardBox.pm 
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

package YardBox;
use vars qw(@ISA @EXPORT %EXPORT_TAGS);
use Exporter;
@ISA = qw(Exporter);
@EXPORT =  qw(yard yard_box);

use strict;
use Yard;
use Error;

my $yard_window;
my $item_factory;
my $accel_group;
my $true = 1;
my $false = 0;

my @menu_items = ( { path        => '/File',
		     type        => '<Branch>' },
		   { path        => '/File/file_tearoff',
		     type        => '<Tearoff>' },
                   { path        => '/File/_Save',
                     accelerator => '<control>S',
                     callback    => sub { print "hello"; } },
                   { path        => '/File/Save _As ...',
		     accelerator => '<alt>A',
		     callback    => sub { print "hello\n"; } },
                   { path        => '/File/file_separator',
                     type        => '<Separator>' },
		   { path        => '/File/_Close',
		     callback    => sub { destroy $yard_window; }},

                   { path        => '/_Edit',
                     type        => '<Branch>' },

                   { path        => '/_Create',
                     type        => '<Branch>' },

                   { path        => '/_Tests',
                     type        => '<Branch>' },

                   { path        => '/_Help',
                     type        => '<LastBranch>' },
                   { path        => '/_Help/Tutorial' },
                   { path        => '/_Help/Shortcuts' } );

######
# YARD
###### 
sub yard {
    
    my ($kernel,$template_dir,$template) = @_;
    my $error;
    
    # Error handling in Yard will take some strategy
    if (!-d $kernel && -f $kernel) {
        $error = kernel_version_check($kernel);  
                                              # Yard: kernel,kernel version
                                              # Becomes $ENV{'RELEASE'}
	return if $error && $error eq "ERROR";
	open(CONTENTS, "<$template_dir$template") or 
        ($error = error("$template_dir$template: $!"));
	return "ERROR"if $error && $error eq "ERROR";
	my @template = <CONTENTS>;
	close(CONTENTS);
	my $stuff = join("",@template);
	yard_box($stuff);

    }
    else {
	error_window("Kernel Selection required");
        return;
    }

    $error = read_contents_file("$template_dir$template");
    return if $error && $error eq "ERROR";
    
##    $error = extra_links("$template_dir$template");
##    return if $error && $error eq "ERROR";

##    $error = hard_links();
##    return if $error && $error eq "ERROR";

##    $error = library_dependencies("$template_dir$template");
##    return if $error && $error eq "ERROR";

##    $error = space_check($filesystem_size, 
##              $lib_strip_check_root->get_active(),
##		$bin_strip_check_root->get_active(), 
##		$module_strip_check_root->get_active(), 
##		$obj_count_root, $tmp);
##    return if $error && $error eq "ERROR";

} # end sub yard

sub yard_box {
    
       $yard_window = new Gtk::Window "toplevel";
       $yard_window->signal_connect("destroy", \&destroy_window,
                                    \$yard_window);
       $yard_window->signal_connect("delete_event", \&destroy_window,
                                    \$yard_window);
       $yard_window->set_usize( 525, 450 );
       $yard_window->set_policy( $true, $true, $false );
       $yard_window->set_title( "Yard Box" );
       $yard_window->border_width(0);

       my $main_vbox = new Gtk::VBox( $false, 0 );
       $yard_window->add( $main_vbox );
       $main_vbox->show();

       my $vbox = new Gtk::VBox( $false, 0 );
       $vbox->border_width( 0 );
       $main_vbox->pack_start( $vbox, $false, $false, 0 );
       $vbox->show();

       # Item::Factory
       my $menubar = yard_menu($yard_window);
       $vbox->pack_start( $menubar, $false, $true, 0 );
       $menubar->show();
       
       $vbox = new Gtk::VBox( $false, 10 );
       $vbox->border_width( 10 );
       $main_vbox->pack_start( $vbox, $true, $true, 0 );
       $vbox->show();

       my $table = new Gtk::Table( 2, 2, $false );
       $table->set_row_spacing( 0, 2 );
       $table->set_col_spacing( 0, 2 );
       $vbox->pack_start( $table, $true, $true, 0 );
       $table->show( );

       # Create the GtkText widget
       my $length;
       my $text = new Gtk::Text( undef, undef );
       $text->set_editable($true);
       my $start_length = $text->get_length();
       my $beginning_text = $text->get_chars(0,$length);
       $text->signal_connect("changed", sub { 
	   $length =  $text->get_length();
	   #my $changed_text = $text->get_chars(0,$length);
	   print "$length\n"; } );
       $table->attach( $text, 0, 1, 0, 1,
                       [ 'expand', 'shrink', 'fill' ],
                       [ 'expand', 'shrink', 'fill' ],
                       0, 0 );
       $text->grab_focus();
       $text->show();

       $text->freeze();
       $text->insert( undef, undef, undef, $_[0]);
       $text->thaw();

       # Add a vertical scrollbar to the GtkText widget
       my $vscrollbar = new Gtk::VScrollbar( $text->vadj );
       $table->attach( $vscrollbar, 1, 2, 0, 1, 'fill',
                       [ 'expand', 'shrink', 'fill' ], 0, 0 );
       $vscrollbar->show();

       #_______________________________________ 
       # Separator
       my $separator = new Gtk::HSeparator();
       $main_vbox->pack_start( $separator, $false, $true, 0 );
       $separator->show();

       #_______________________________________ 
       # Check stage boxes
       # check | links & deps | space | create | test
       $vbox = new Gtk::HBox( $false, 0 );
       $vbox->border_width( 0 );
       $main_vbox->pack_start( $vbox, $false, $true, 0 );
       $vbox->show();

       my $check = new Gtk::CheckButton("Check");
       $vbox->pack_start( $check, $true, $true, 10 );
       show $check;       

       my $dep = new Gtk::CheckButton("Links & Deps");
       $vbox->pack_start( $dep, $true, $true, 0 );
       show $dep;       

       my $space = new Gtk::CheckButton("Space Left");
       $vbox->pack_start( $space, $true, $true, 0 );
       show $space;       

       my $create = new Gtk::CheckButton("Create");
       $vbox->pack_start( $create, $true, $true, 0 );
       show $create;       

       my $test = new Gtk::CheckButton("Test");
       $vbox->pack_start( $test, $true, $true, 0 );
       show $test;       

       #_______________________________________ 
       # Separator
       $separator = new Gtk::HSeparator();
       $main_vbox->pack_start( $separator, $false, $true, 0 );
       $separator->show();

       #_______________________________________ 
       # Continue - Cancel - Save Buttons
       $vbox = new Gtk::HBox( $false, 10 );
       $vbox->border_width( 10 );
       $main_vbox->pack_start( $vbox, $false, $true, 0 );
       $vbox->show();

       my $button = new Gtk::Button( "Continue" );
       $button->signal_connect( 'clicked', 
       				sub { destroy $yard_window; } );
       $vbox->pack_start( $button, $true, $true, 0 );
       $button->show();

       $button = new Gtk::Button( "Close" );
       $button->signal_connect( 'clicked', 
       				sub { destroy $yard_window; } );
       $vbox->pack_start( $button, $true, $true, 0 );
       $button->show();

       $button = new Gtk::Button( "Save" );
       $button->signal_connect( 'clicked', 
       				sub { destroy $yard_window; } );
       $vbox->pack_start( $button, $true, $true, 0 );
       $button->show();
    
       show $yard_window;

} # end sub yard_box

sub print_hello { 
    my ($menu_item, $action, $date) = @_;

    $menu_item->set_active($true);
    print $menu_item; 


}

sub yard_menu {

    my ($window) = @_;

    $accel_group = new Gtk::AccelGroup();
    $item_factory = new Gtk::ItemFactory( 'Gtk::MenuBar', '<main>', 
                                             $accel_group );
    $accel_group->attach($window);
    $item_factory->create_items(@menu_items);

    # Manipulate Gtk::ItemFactory - The trick here is to use the real path.
    ##my $checkbox = $item_factory->get_item("/File/CheckBox");
    ##$checkbox->set_active($true);

    return ( $item_factory->get_widget( '<main>' ) );

} 

1;



