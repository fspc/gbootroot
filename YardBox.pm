#############################################################################
##
##  YardBox.pm 
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
@EXPORT =  qw(yard ars);

use strict;
use Yard;
use Error;
use lsMode;

my $yard_window;
my $item_factory;
my $true = 1;
my $false = 0;
my $error;
my ($continue_button,$close_button,$save_button);
my($check,$dep,$space,$create,$test);
my($filename,$filesystem_size,$kernel,$template_dir,$template,$tmp,$mnt);
my ($text, $changed_text);

my $filesystem_type = "ext2";
my $inode_size = 8192;
my $lib_bool =            1;
my $bin_bool =            1;
my $mod_bool =            1;

my $ars;
sub ars { $ars = $_[0]; 

$filename         = $ars->{filename};
$filesystem_size  = $ars->{filesystem_size};
$kernel           = $ars->{kernel};
$template_dir     = $ars->{template_directory};
$template         = $ars->{template};
$tmp              = $ars->{tmp};
$mnt              = $ars->{mnt};

# Freshmeat comes here so the rest of the program needs
# to be warned when the template is coming from here.
$changed_text = "$template_dir$template";

}


my @menu_items = ( { path        => '/File',
		     type        => '<Branch>' },
		   { path        => '/File/file_tearoff',
		     type        => '<Tearoff>' },
                   { path        => '/File/_Save',
                     accelerator => '<control>S',
                     callback    => \&saved,
		     action      =>  100 },
                   { path        => '/File/Save _As ...',
		     accelerator => '<alt>S',
		     callback    => \&saved,
		     action      => 101 },
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
		   { path        => '/Edit/File System',
		     callback    => \&file_system },
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


      # Error handling in Yard will take some strategy
    if (!-d $kernel && -f $kernel) {
        $error = kernel_version_check($kernel);  
                                              # Yard: kernel,kernel version
                                              # Becomes $ENV{'RELEASE'}
	return if $error && $error eq "ERROR";
	open(CONTENTS, "<$changed_text") or 
        ($error = error("$changed_text: $!"));
	return "ERROR"if $error && $error eq "ERROR";
	my @template = <CONTENTS>;
	close(CONTENTS);
	$changed_text = join("",@template);
	yard_box();

    }
    else {
	error_window("Kernel Selection required");
        return;
    }


} # end sub yard

###############
# File System #
###############
# This allows the user to choose a different filesystem besides ext2.
# The space_check inode percentage formula can be altered.  Default 2%.
sub file_system {

    $filesystem_type = "ext2";
    $inode_size = 8192;

}


###########
# OBJCOPY #
###########
# There is a subtle, but important difference between set_active and
# active which makes the next magic possible.  set_active is like actually
# pressing the button.  It's a lot easier to work with checkbuttons than
# with radio buttons, because there is no easy way to establish a group.
# The use of hide() and show() can really create some magic.

my $lib_strip_all;
my $lib_strip_debug;
my $strip_bool = 1;
sub strip_all {

    $lib_strip_debug->active(0);
    $strip_bool = 1;
    print "$strip_bool\n";

}

sub strip_debug {

    $lib_strip_all->active(0);
    $strip_bool = 0;
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


my $continue = {
    check      => 0,
    dep        => 0,
    space      => 0,
    create     => 0,
    test       => 0,
    };

my @check_boxes;

# Makes main checkbuttons act like radiobuttons
# Applies to both one_by_one & continuous,
# otherwise just normal click capabilities (expert mode).
sub which_stage {

    my($widget,$name) = @_;
    my ($thing,$name_cmp);
    @check_boxes = ($check, $dep, $space, $create, $test);

    if ($stages_bool eq "one-by-one" or $stages_bool eq "continuous") {
	foreach $thing (@check_boxes) {
	    if ($thing ne $widget) {
		$thing->hide();
		$thing->active($false);
		$thing->show();
	    }
	}   

	# Finally we just reset %continue to reflect the button pressed.
	# Either  the user can back up when doing one-by-one or it 
	# automatically starts again if the text has been modified.
	# 0 0 0 0 0
	# 1 0 0 0 0
	# 1 1 0 0 0
	# 1 1 1 0 0
	# 1 1 1 1 0
	# 1 1 1 1 1

	# 0 everything
	if ($name eq "check") {
	    foreach $name_cmp (%$continue) {
		$continue->{$name_cmp} = 0;	
	    }
	}
	# 1 0 0 0 0
	elsif ($name eq "dep") {
	    foreach $name_cmp (%$continue) {
		if ($name_cmp ne "check") {
		    $continue->{$name_cmp} = 0;	
		}
	    }
	}
	elsif ($name eq "space") {
	    foreach $name_cmp (%$continue) {
		if ($name_cmp ne "check" && $name_cmp ne "dep") {
		    $continue->{$name_cmp} = 0;	
		}
	    }
	}
	elsif ($name eq "create") {
	    foreach $name_cmp (%$continue) {
		if ($name_cmp ne "check" && $name_cmp ne "dep" && 
		    $name_cmp ne "space") {
		    $continue->{$name_cmp} = 0;	
		}
	    }
	}
	elsif ($name eq "test") {
	    foreach $name_cmp (%$continue) {
		if ($name_cmp ne "check" && $name_cmp ne "dep" && 
		    $name_cmp ne "space" && $name_cmp ne "create") {
		    $continue->{$name_cmp} = 0;	
		}
	    }
	}

    for (keys %$continue) { print $_, "=>", $continue->{$_}, "\n"; }

    } # end if one-by-one or continuous



}

sub continue {

    my $thing;

    # This has to go sequentially, but backwards is o.k.
    if ($stages_bool eq "one-by-one" || $stages_bool eq "continuous") {
        if ( $continue->{check} == 0 ) {
	    check();
	    foreach $thing (@check_boxes) {
		$thing->hide();
		$thing->active($false);
		$thing->show();
	    }   
	    $dep->hide();
	    $dep->active($true);
	    $dep->show();
	    $continue->{check} = 1;
	    return if $stages_bool eq "one-by-one";
	}
        if ( $continue->{dep} == 0 ) {
	    links_deps();
	    foreach $thing (@check_boxes) {
		$thing->hide();
		$thing->active($false);
		$thing->show();
	    }   
	    $space->hide();
	    $space->active($true);
	    $space->show();
	    $continue->{dep} = 1;
	    return if $stages_bool eq "one-by-one";
	}
        if ( $continue->{space} == 0 ) {
	    space_left();
	    foreach $thing (@check_boxes) {
		$thing->hide();
		$thing->active($false);
		$thing->show();
	    }   
	    $create->hide();
	    $create->active($true);
	    $create->show();
	    $continue->{space} = 1;
	    return if $stages_bool eq "one-by-one";
	}
        if ( $continue->{create} == 0 ) {
	    create();
	    foreach $thing (@check_boxes) {
		$thing->hide();
		$thing->active($false);
		$thing->show();
	    }   
	    $test->hide();
	    $test->active($true);
	    $test->show();
	    $continue->{create} = 1;
	    return if $stages_bool eq "one-by-one";
	}
        if ( $continue->{test} == 0 ) {
	    test();
	    foreach $thing (@check_boxes) {
		$thing->hide();
		$thing->active($false);
		$thing->show();
	    }   
	    $continue->{test} = 1;
	    return if $stages_bool eq "one-by-one";
	}	

    }
    elsif ($stages_bool eq "user-defined") {

	if ($check->get_active()) {
	    check();
	    $check->hide();
	    $check->active($false);
	    $check->show();
	}
	if ($dep->get_active()) {
	    links_deps();
	    $dep->hide();
	    $dep->active($false);
	    $dep->show();
	}
	if ($space->get_active()) {
	    space_left();
	    $space->hide();
	    $space->active($false);
	    $space->show();
	}
	if ($create->get_active()) {
	    create();
	    $create->hide();
	    $create->active($false);
	    $create->show();
	}
	if ($test->get_active()) {
	    test();
	    $test->hide();
	    $test->active($false);
	    $test->show();
	}

    }

}

sub check {
    
    $error = read_contents_file($changed_text);
    return if $error && $error eq "ERROR";

}

sub links_deps {

    $error = extra_links($changed_text);
    return if $error && $error eq "ERROR";

    $error = hard_links();
    return if $error && $error eq "ERROR";

    $error = library_dependencies($changed_text);
    return if $error && $error eq "ERROR";

}

sub space_left {

    $lib_bool = "" if $lib_bool eq 0;
    $bin_bool = "" if $bin_bool eq 0;
    $mod_bool = "" if $mod_bool eq 0;

    $error = space_check($filesystem_size, 
              $lib_bool, $bin_bool, $mod_bool,
		$strip_bool, $tmp);
    return if $error && $error eq "ERROR";

}

sub create {

    $lib_bool = "" if $lib_bool eq 0;
    $bin_bool = "" if $bin_bool eq 0;
    $mod_bool = "" if $mod_bool eq 0;

    $error = create_filesystem($filename,$filesystem_size,$filesystem_type,
			       $inode_size,$mnt,$lib_bool,$bin_bool,
			       $mod_bool,$strip_bool);
    return if $error && $error eq "ERROR";

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

    my @label = keys( % { $tests{$action} } );
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

sub test { 

    $error = which_tests(\%tests); 
    return if $error && $error eq "ERROR";
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

# try show hide & use variables
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
my $replacement_bool =    1;
my $module_bool =         1;
my $start_length;
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
				        if ($lib_bool eq "") {
					    $lib_bool = 0;
				        }
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
				         if ($bin_bool eq "") {
					    $bin_bool = 0;
				         }
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
				         if ($mod_bool eq "") {
					     $mod_bool = 0;
				         }
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
       $text = new Gtk::Text( undef, undef );
       $text->set_editable($true);
       $text->signal_connect("activate", sub { 
	   my $new_length =  $text->get_length();
	   $changed_text = $text->get_chars(0,$new_length);
       } );
       $table->attach( $text, 0, 1, 0, 1,
                       [ 'expand', 'shrink', 'fill' ],
                       [ 'expand', 'shrink', 'fill' ],
                       0, 0 );
       $text->grab_focus();
       $text->show();

       $text->freeze();
       $text->insert( undef, undef, undef, $changed_text);
       $text->thaw();

       $start_length = $text->get_length();

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

       $check = new Gtk::CheckButton("Check");
       $check->signal_connect("clicked", \&which_stage, "check"); 
       $vbox->pack_start( $check, $true, $true, 10 );
       show $check;       

       $dep = new Gtk::CheckButton("Links & Deps");
       $dep->signal_connect("clicked", \&which_stage, "dep"); 
       $vbox->pack_start( $dep, $true, $true, 0 );
       show $dep;       

       $space = new Gtk::CheckButton("Space Left");
       $space->signal_connect("clicked", \&which_stage, "space"); 
       $vbox->pack_start( $space, $true, $true, 0 );
       show $space;       

       $create = new Gtk::CheckButton("Create");
       $create->signal_connect("clicked", \&which_stage, "create"); 
       $vbox->pack_start( $create, $true, $true, 0 );
       show $create;       

       $test = new Gtk::CheckButton("Test");
       $test->signal_connect("clicked", \&which_stage, "test"); 
       $vbox->pack_start( $test, $true, $true, 0 );
       show $test;       

       # sets up default radiobutton behavior
       which_stage("check","check");
       $check->active($true);

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
       $continue_button->signal_connect( 'clicked', \&continue);
       $vbox->pack_start( $continue_button, $true, $true, 0 );
       $continue_button->show();

       $close_button = new Gtk::Button( "Close" );
       $close_button->signal_connect( 'clicked', 
       				sub { destroy $yard_window; } );
       $vbox->pack_start( $close_button, $true, $true, 0 );
       $close_button->show();

       $save_button = new Gtk::Button( "Save" );
       # This sub can be used by all the saved buttons
       $save_button->signal_connect( 'clicked', \&saved, 102);
       $vbox->pack_start( $save_button, $true, $true, 0 );
       $save_button->show();
    
       show $yard_window;

} # end sub yard_box

sub saved {

    my ($widget,$whoami) = @_;
    my $error;
    
    $text->activate();

    # It's not necessary to use lsMode, but it's a cool program by MJD.
    if  ($whoami == 100 || $whoami == 102 ) {
	if ( file_mode("$template_dir$template") !~ /w/ ) {
	    error_window("gBootRoot: ERROR: $template_dir$template is not " .
			 "writable.\nUse [ File->Save As ] or " .
			 "[Alt-S] with the yard suffix.");		     
	}
	else {
	    # Here's where we get to undef Yard variable and start over at 
	    # check
	    my $new = "$template_dir$template" . ".new";
	    open(NEW,">$new") or 
		($error = error("gBootRoot: ERROR: Can't create $new"));
		return if $error && $error eq "ERROR";    
	        print NEW $changed_text;
	        close(NEW);
	    rename($new, "$template_dir$template") or
		($error = error("gBootRoot: ERROR: Can't rename $new to " .
				"$template_dir$template"));
	    return if $error && $error eq "ERROR"; 
	}
    }
    elsif ($whoami == 101) {
	print "Getting there\n";
    }

}

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
