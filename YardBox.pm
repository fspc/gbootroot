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
my $true = 1;
my $false = 0;
my ($continue_button,$close_button,$save_button);

my @menu_items = ( { path        => '/File',
		     type        => '<Branch>' },
		   { path        => '/File/file_tearoff',
		     type        => '<Tearoff>' },
                   { path        => '/File/_Save',
                     accelerator => '<control>S',
                     callback    => sub { print "hello"; } },
                   { path        => '/File/Save _As ...',
		     accelerator => '<alt>S',
		     callback    => sub { print "hello\n"; } },
                   { path        => '/File/file_separator',
                     type        => '<Separator>' },
		   { path        => '/File/Close',
		     accelerator => '<alt>W',
		     callback    => sub { destroy $yard_window; }},
		   
                   { path        => '/_Edit',
                     type        => '<Branch>' },
		   { path        => '/Edit/edit_tearoff',
		     type        => '<Tearoff>' },
		   { path        => '/Edit/Settings/' },
		   { path        => '/Edit/Settings/edit_tearoff',
		     type        => '<Tearoff>' },
		   { path        => '/Edit/Settings/Path' },
		   { path        => '/Edit/Settings/Stripping/' },
		   { path        => '/Edit/Settings/Stripping/edit_tearoff',
		     type        => '<Tearoff>' },
		   { path        => '/Edit/Settings/Stripping/Libraries',
		     action      => "1",
		     type        => '<CheckItem>' },
		   { path        =>  '/Edit/Settings/Stripping/settings/' },
		   { path        => '/Edit/Settings/Stripping/settings/strip-all',
		     action      => "10",
		     type        => '<RadioItem>',
		     callback    => \&strip_all },
                   { path        => '/Edit/Settings/Stripping/settings/strip-debug',
		     action      => '11',
                     type        => '<RadioItem>', 
		     callback    => \&strip_debug },
		     
		   { path        => '/Edit/Settings/Stripping/Binaries',
		     action      => "2",
		     type        => '<CheckItem>' },
                   { path        => '/Edit/Settings/Stripping/Modules',
		     action      => '3',
                     type        => '<CheckItem>' },
                   { path        => '/Edit/Settings/edit_separator',
                     type        => '<Separator>' },
		   { path        => '/Edit/Settings/Replacements',
		     action      => "4",
		     type        => '<CheckItem>' },
		   { path        => '/Edit/Settings/Modules',
		     action      => "5",
		     type        => '<CheckItem>' },
		   { path        => '/Edit/Stages/' },
		   { path        => '/Edit/Stages/one-by-one',
		     action      => 13,
		     type        => '<RadioItem>', 
		     callback    => \&stages_one_by_one },
		   { path        => '/Edit/Stages/continuous',
		     action      => 14,
		     type        => '<RadioItem>', 
		     callback    => \&stages_continuous },
		   { path        => '/Edit/Stages/user defined',
		     action      => 15,
		     type        => '<RadioItem>',
		     callback    => \&stages_user_defined },
		   { path        => '/Edit/File System' },
		   { path        => '/Edit/Replacements' },

                   { path        => '/_Create',
                     type        => '<Branch>' },
		   { path        => '/Create/create_tearoff',
		     type        => '<Tearoff>' },
		   { path        => '/Create/Replacements/' },
		   { path        => '/Create/Replacements/replacement_tearoff',
		     type        => '<Tearoff>' },
		   { path        => '/Create/Replacements/fstab',
		     action      => 16,
		     type        => '<CheckItem>',
		     callback    => \&check_stage },
		   { path        => '/Create/Replacements/rc',
		     action      => 17,
		     type        => '<CheckItem>',
		     callback    => \&check_stage },
		   { path        => '/Create/Replacements/fstab directory name',
		     action      => 18,
		     type        => '<Title>',
		     callback    => \&check_stage },

			 
		   { path        => '/_Tests',
                     type        => '<Branch>' },
		   { path        => '/Tests/tests_tearoff',
		     type        => '<Tearoff>' },
		   { path        => '/Tests/fstab',
		     action      => 30,
		     type        => '<CheckItem>', 
		     callback    => \&tests },
		   { path        => '/Tests/inittab',
		     action      => 31,
		     type        => '<CheckItem>',
		     callback    => \&tests },
		   { path        => '/Tests/scripts',
		     action      => 32,
		     type        => '<CheckItem>',
		     callback    => \&tests },
		   { path        => '/Tests/links',
		     action      => 33,
		     type        => '<CheckItem>',
		     callback    => \&tests },
		   { path        => '/Tests/passwd',
		     action      => 34,
		     type        => '<CheckItem>',
		     callback    => \&tests },
		   { path        => '/Tests/pam',
		     action      => 35,
		     type        => '<CheckItem>',
		     callback    => \&tests },
		   { path        => '/Tests/nss',
		     action      => 36,
		     type        => '<CheckItem>',
		     callback    => \&tests },

                   { path        => '/_Help',
                     type        => '<LastBranch>' },
		   { path        => '/Help/help_tearoff',
		     type        => '<Tearoff>' },
                   { path        => '/_Help/Tutorial' },
                   { path        => '/_Help/Shortcuts' } );

######
# YARD
###### 
sub yard {
    
    my ($ars) = @_;

    my $error;
    my $device           = $ars->{device};
    my $device_size      = $ars->{device_size};
    my $filename         = $ars->{filename};
    my $filename_size    = $ars->{filename_size};
    my $kernel           = $ars->{kernel};
    my $template_dir     = $ars->{template_directory};
    my $template         = $ars->{template};
    my $tmp              = $ars->{tmp};
    my $mnt              = $ars->{mnt};
    
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


###########
# OBJCOPY #
###########
# There is a subtle, but important difference between set_active and
# active which makes the next magic possible.  set_active is like actually
# pressing the button.  It's a lot easier to work with checkbuttons than
# with radio buttons, because there is no easy way to establish a group.

my $lib_strip_all;
my $lib_strip_debug;
my $strip_bool = "strip-all";
sub strip_all {

    $lib_strip_debug->active(0);
    $strip_bool = "strip-all";
    print "$strip_bool\n";

}

sub strip_debug {

    $lib_strip_all->active(0);
    $strip_bool = "strip-debug";
    print "$strip_bool\n";

}

##########
# STAGES #
##########

my $stages_bool = "one-by-one";
my $one_by_one;
my $continuous;
my $user_defined;
sub stages_one_by_one {

    $continuous->active(0);
    $user_defined->active(0);
    $stages_bool = "one-by-one";
    print "$stages_bool\n";

}

sub stages_continuous {

    $one_by_one->active(0);
    $user_defined->active(0);
    $stages_bool = "continuous";
    print "$stages_bool\n";

}

sub stages_user_defined {

    $one_by_one->active(0);
    $continuous->active(0);
    $stages_bool = "user-defined";
    print "$stages_bool\n";
}


#########
# TESTS #
#########
my %tests = (
	    30 => {
		test_fstab => 1,
	    },
	    31 => {
		test_inittab => 1,
	    },
	    32 => { 
		test_scripts => 1,
	    },
	    33 => { 
		test_links => 1,
            },
	    34 => {
		test_passwd => 1,
            },
	    35 => {
		test_pam => 1,
            },
	    36 => {
		test_nss => 1,
	    },
);

sub tests {

    my ($widget,$action) = @_;

    my @label = keys( %{ $tests{$action} } );
    # off
    if ($tests{$action}{$label[0]} == 1) {
	$tests{$action}{$label[0]} = 0;
    }
    # on
    else {
	$tests{$action}{$label[0]} = 1;
    }
    print "$label[0]", $tests{$action}{$label[0]} , "\n";

}

#########################
# CHECK STAGE VARIABLES #
#########################

my %checks = (
	    16 => {
		fstab => 0,
	    },
	    18 => {
		fstab_directory_name => 0,
	    },
	    17 => { 
		rc => 0,
	    }	
);

sub check_stage {

    my ($widget,$action) = @_;

    my @label = keys( %{ $checks{$action} } );
    # off
    if ($checks{$action}{$label[0]} == 1) {
	$checks{$action}{$label[0]} = 0;
	if ($label[0] eq "fstab") {
	    $item_factory->delete_item
		('/Create/Replacements/fstab directory name');
	}
    }
    # on
    else {
	$checks{$action}{$label[0]} = 1;
	# Fancy, but not quite what I want
	if ($label[0] eq "fstab") {
	    $item_factory->delete_item
		('/Create/Replacements/fstab directory name');
	    $item_factory->create_item
		(['/Create/Replacements/fstab directory name', 
		  undef, undef, <Item>]);
	}
    }
    print "$label[0]", $checks{$action}{$label[0]} , "\n";

}

###########
# YARDBOX #
###########
# cut little booleans for Gtk::CheckMenuItem
my $lib_bool =            1;
my $bin_bool =            1;
my $mod_bool =            1;
my $replacement_bool =    1;
my $module_bool =         1;
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
       $main_vbox->pack_start( $vbox, $false, $true, 0 );
       $vbox->show();

       #_______________________________________ 
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

       #_______________________________________ 
       # Manipulate Gtk::ItemFactory - 
       # The trick here is to use the real path.

       #     GUIDE TO VARIABLES AND THEIR VALUES 
       #
       #          objcopy <RadioItem>
       #          -------------------
       # $strip_bool  strip-all (default)
       #              strip-debug
       #
       #          stages <RadioItem>  
       #          ------------------
       #               one-by-one (default)
       # $stages_bool  continuous
       #               user-defined
       #
       #          stripping <CheckItem>
       #          ---------------------
       #                      on           off
       #                      --           ---
       # $lib_bool             1 (default)  0
       # $bin_bool             1 (default)  0
       # $mod_bool             1 (default)  0
       #
       #           Checking Settings <CheckItem>
       #           -----------------------------
       # $replacement_bool     1 (default)  0
       # $module_bool          1 (default)  0
       #
       #            Check Stage Variables HOH = %checks
       #            -----------------------------------
       # 16 fstab              1            0 (default)
       # 17 rc                 1            0 (default
       # 18 'fstab directory name'  if fstab == 0
       #
       #            Tests  <CheckItem> HOH = %tests
       #            --------------------------------
       # 30 test_fstab          1 (default)  0
       # 31 test_inittab        1 (default)  0
       # 32 test_scripts        1 (default)  0
       # 33 test_links          1 (default)  0
       # 34 test_passwd         1 (default)  0
       # 35 test_pam            1 (default)  0
       # 36 test_nss            1 (default)  0

       # Stages
       $one_by_one =  $item_factory->get_item('/Edit/Stages/one-by-one');
       $continuous = $item_factory->get_item('/Edit/Stages/continuous');
       $user_defined = $item_factory->get_item('/Edit/Stages/user defined');
       $continuous->active(0);
       $user_defined->active(0);

       # Stripping

       # Libraries
       my $lib_strip = $item_factory->get_item
	   ('/Edit/Settings/Stripping/Libraries');
       
       $lib_strip->active($true);
       $lib_strip->signal_connect( "activate", 
				   sub {  
				       # off   
				       if ($lib_bool == 1) {
					     $lib_bool--;
				         }
					 # on
					 else {
					     $lib_bool++;               
					 }
					 print "$lib_bool\n";
				     }
                                   ); 

           # objcopy parameters for Libraries
           $lib_strip_all = $item_factory->get_item
               ('/Edit/Settings/Stripping/settings/strip-all');
           $lib_strip_debug = $item_factory->get_item
	       ('/Edit/Settings/Stripping/settings/strip-debug');
           $lib_strip_debug->active(0);

       # Binaries
       my $bin_strip = $item_factory->get_item
	   ('/Edit/Settings/Stripping/Binaries');
       $bin_strip->active($true);
       $bin_strip->signal_connect( "activate", 
				   sub { 
					 # off
					 if ($bin_bool == 1) {
					     $bin_bool--;
				         }
					 # on
					 else {
					     $bin_bool++;
					 }
					 print "$bin_bool\n";
				     }
				 ); 


       # Modules
       my $mod_strip = $item_factory->get_item
	   ('/Edit/Settings/Stripping/Modules');
       $mod_strip->active($true);
       $mod_strip->signal_connect( "activate", 
				   sub { 
					 # off
					 if ($mod_bool == 1) {
					     $mod_bool--;
				         }
					 # on
					 else {
					     $mod_bool++;
					 }
					 print "$mod_bool\n";
				     }
				 ); 


       # Checking - Replacements and/or Modules?

       # Replacements
       my $replacement_check = $item_factory->get_item
	   ('/Edit/Settings/Replacements');
       $replacement_check->active($true);
       $replacement_check->signal_connect( "activate", 
				   sub { 
					 # off
					 if ($replacement_bool == 1) {
					     $replacement_bool--;
				         }
					 # on
					 else {
					     $replacement_bool++;
					 }
					 print "$replacement_bool\n";
				     }
				 );        

       # Modules
       my $modules_check = $item_factory->get_item('/Edit/Settings/Modules');
       $modules_check->active($true);
       $modules_check->signal_connect( "activate", 
				   sub { 
					 # off
					 if ($module_bool == 1) {
					     $module_bool--;
				         }
					 # on
					 else {
					     $module_bool++;
					 }
					 print "$module_bool\n";
				     }
				 );        

       # Tests
       my $test_fstab = $item_factory->get_item('/Tests/fstab'); 
       $test_fstab->active(1);
       my $test_inittab = $item_factory->get_item('/Tests/inittab');  
       $test_inittab->active(1);
       my $test_scripts = $item_factory->get_item('/Tests/scripts'); 
       $test_scripts->active(1);
       my $test_links = $item_factory->get_item('/Tests/links'); 
       $test_links->active(1);
       my $test_passwd = $item_factory->get_item('/Tests/passwd'); 
       $test_passwd->active(1);
       my $test_pam = $item_factory->get_item('/Tests/pam'); 
       $test_pam->active(1);
       my $test_nss = $item_factory->get_item('/Tests/nss');
       $test_nss->active(1);

       #_______________________________________ 
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
       $check->set_active($true);
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
       # Continue - Close - Save Buttons
       $vbox = new Gtk::HBox( $false, 10 );
       $vbox->border_width( 10 );
       $main_vbox->pack_start( $vbox, $false, $true, 0 );
       $vbox->show();

       $continue_button = new Gtk::Button( "Continue" );
       $continue_button->signal_connect( 'clicked', 
       				sub { destroy $yard_window; } );
       $vbox->pack_start( $continue_button, $true, $true, 0 );
       $continue_button->show();

       $close_button = new Gtk::Button( "Close" );
       $close_button->signal_connect( 'clicked', 
       				sub { destroy $yard_window; } );
       $vbox->pack_start( $close_button, $true, $true, 0 );
       $close_button->show();

       $save_button = new Gtk::Button( "Save" );
       $save_button->signal_connect( 'clicked', 
       				sub { destroy $yard_window; } );
       $vbox->pack_start( $save_button, $true, $true, 0 );
       $save_button->show();
    
       show $yard_window;

} # end sub yard_box

sub print_hello { 
    my ($menu_item, $action, $date) = @_;

    $menu_item->set_active($true);
    print $menu_item; 


}

sub yard_menu {

    my ($window) = @_;

    my $accel_group = new Gtk::AccelGroup();
    $item_factory = new Gtk::ItemFactory( 'Gtk::MenuBar', '<main>', 
                                             $accel_group );
    $accel_group->attach($window);
    $item_factory->create_items(@menu_items);
    ##$item_factory->delete_item('/File/Checkbox');
    ##$item_factory->create_item(['/File/Checkbox', undef, undef, <Item>]);

    return ( $item_factory->get_widget( '<main>' ) );

} 

1;
