###########################################################################
##
##  YardBox.pm 
##  Copyright (C) 2000, 2001 by Jonathan Rosenbaum 
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

package BootRoot::YardBox;
use vars qw(@ISA @EXPORT %EXPORT_TAGS);
use Exporter;
@ISA = qw(Exporter);
@EXPORT =  qw(yard ars);

use strict;
use BootRoot::Yard;
use BootRoot::Error;
use BootRoot::lsMode;
use File::Basename;

my $item_factory;
my $true = 1;
my $false = 0;
#my $error;
my ($continue_button,$close_button,$save_button);
my($check,$dep,$space,$create,$test);
my($filename,$filesystem_size,$kernel,$template_dir,$template,$tmp,$mnt);
my ($text, $changed_text, $changed_text_from_template);
my $save_as;
my ($replacements_window, $filesystem_window, $path_window, $tutorial, 
    $shortcut);
my ($search_window, $question_window, $offset);
my $Shortcuts;
my @entry;
my $file_dialog;
my $search_text;

#my $filesystem_type = "ext2";
#my $inode_size = 8192;
my $lib_bool =            1;
my $bin_bool =            1;
my $mod_bool =            1;

my $ars;
sub ars { $ars = $_[0]; 

$filename         = $ars->{filename};
$filesystem_size  = $ars->{filesystem_size};
$kernel           = $ars->{kernel};
$template_dir     = $ars->{template_dir};
$template         = $ars->{template};
$tmp              = $ars->{tmp};
$mnt              = $ars->{mnt};

# Freshmeat comes here so the rest of the program needs
# to be warned when the template is coming from here.
$changed_text = "$template_dir$template" if defined $template;

}


my @menu_items = ( { path        => '/File',
		     type        => '<Branch>' },
		   { path        => '/File/file_tearoff',
		     type        => '<Tearoff>' },
                   { path        => '/File/_New Template',
                     accelerator => '<alt>N',
                     callback    => \&saved,
		     action      =>  100 },
                   { path        => '/File/file_separator',
                     type        => '<Separator>' },
                   { path        => '/File/_Save',
                     accelerator => '<control>S',
                     callback    => \&saved,
		     action      =>  100 },
                   { path        => '/File/Save _As ...',
		     accelerator => '<alt>A',
		     callback    => \&saved,
		     action      => 101 },
                   { path        => '/File/file_separator',
                     type        => '<Separator>' },
		   { path        => '/File/Close',
		     accelerator => '<alt>W',
		     callback    => sub { destroy $main::yard_window; }},
		   
                   { path        => '/_Edit',
                     type        => '<Branch>' },
		   { path        => '/Edit/edit_tearoff',
		     type        => '<Tearoff>' },
		   { path        => '/Edit/Settings/' },
		   { path        => '/Edit/Settings/edit_tearoff',
		     type        => '<Tearoff>' },
		   { path        => '/Edit/Settings/Path', 
		     callback    => \&path },
		   { path        => '/Edit/Settings/Stripping/' },

##		   { path        => '/Edit/Settings/edit_separator',
##                     type        => '<Separator>' },
##		   { path        => '/Edit/Settings/Replacements',
##		     action      => "4",
##		     type        => '<CheckItem>' },
##		   { path        => '/Edit/Settings/Modules',
##		     action      => "5",
##		     type        => '<CheckItem>' },

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

                   { path        => '/Edit/Settings/settings_separator',
                     type        => '<Separator>' },
		   { path        => '/Edit/Settings/NSS Config',
		     action      => "1111",
		     type        => '<CheckItem>' },
                   { path        => '/Edit/Settings/PAM Config',
		     action      => '1112',
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
		   { path        => '/Edit/Replacements',
		     callback    => \&Replacements },
                   { path        => '/Edit/edit_separator',
                     type        => '<Separator>' },
		   { path        => '/Edit/_Search in Page',
                     accelerator => '<alt>S',
		     callback    => \&search },


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
##		   { path        => '/Create/Replacements/rc',
##		     action      => 17,
##		     type        => '<CheckItem>',
##		     callback    => \&check_stage },
##		   { path        => '/Create/Replacements/fstab directory name',
##		     action      => 18,
##		     type        => '<Title>',
##		     callback    => \&check_stage },

			 
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
                   { path        => '/_Help/Tutorial',
		     callback    => \&tutorial },
                   { path        => '/_Help/Shortcuts', 
		     callback    => \&shortcut	} );



######
# YARD
###### 
sub yard {

    my $error;

    # Error handling in Yard will take some strategy
    if (!-d $kernel && -f $kernel) {
        $error = kernel_version_check($kernel);  
                                              # Yard: kernel,kernel version
                                              # Becomes $ENV{'RELEASE'}

	return if $error && $error eq "ERROR";
    }
	open(CONTENTS, "<$changed_text") or 
        ($error = error("$changed_text: $!"));
	return "ERROR"if $error && $error eq "ERROR";
	my @template = <CONTENTS>;
	close(CONTENTS);
	$changed_text_from_template = join("",@template);
	yard_box();

} # end sub yard

###############
# File System #
###############
# This allows the user to choose a different filesystem besides ext2.
# The space_check inode percentage formula can be altered.  Default 2%.
sub file_system {

    if (not defined $filesystem_window) {

	$filesystem_window = Gtk::Window->new("toplevel");
	$filesystem_window->signal_connect("destroy", \&destroy_window,
					     \$filesystem_window);
	$filesystem_window->signal_connect("delete_event", \&destroy_window,
					     \$filesystem_window);
	$filesystem_window->set_policy( $true, $true, $false );
	$filesystem_window->set_title( "Filesystem Box" );
	$filesystem_window->border_width(1);    

	my $main_vbox = Gtk::VBox->new( $false, 0 );
	$filesystem_window->add( $main_vbox );
	$main_vbox->show();

	my $table_filesystem = Gtk::Table->new( 2, 3, $true );
	$main_vbox->pack_start( $table_filesystem, $true, $true, 0 );
	$table_filesystem->show();

	#_______________________________________
	# Editor and execute options
	label("Filesystem Command:",0,1,0,1,$table_filesystem);
	my $fs1 = entry(1,3,0,1,2,$table_filesystem);
	$fs1->set_text($main::makefs);

	$table_filesystem->set_row_spacing( 0, 2);       

	#_______________________________________
	# Submit button
	my $submit_b = button(0,1,1,2,"Submit",$table_filesystem);
	$submit_b->signal_connect( "clicked", sub {
	    if ($entry[2]) {

		# Check to see if it actually exists
		my $executable = (split(/\s+/,$entry[2]))[0];
		if (!find_file_in_path(basename($executable))) {
		    error_window("gBootRoot: ERROR: Enter a valid command");
		    return;
		}
		if ($executable =~ m,/,) {
		    if (! -e $executable) {
			error_window("gBootRoot: ERROR: " .
				     "Enter a valid path for the command.");
			return;
		    }
		}
		$main::makefs = $entry[2];
		info(1,"Filesystem Command is $entry[2]\n");
	    }
	} );

	#_______________________________________
	# Close button
	my $close_b = button(2,3,1,2,"Close",$table_filesystem);
	$close_b->signal_connect("clicked",
				 sub {
				     $filesystem_window->destroy() 
					 if $filesystem_window;
				 } );


    }
    if (!visible $filesystem_window) {
	$filesystem_window->show();
    } 

} # end sub file_system


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
#    print"$strip_bool\n";

}

sub strip_debug {

    $lib_strip_all->active(0);
    $strip_bool = 0;
#    print "$strip_bool\n";

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
#    print "$stages_bool\n";
    

}

sub stages_continuous {

    $one_by_one->active(0);
    $user_defined->active(0);
    $stages_bool = "continuous";
#    print "$stages_bool\n";

}

sub stages_user_defined {

    $one_by_one->active(0);
    $continuous->active(0);
    $stages_bool = "user-defined";
#    print "$stages_bool\n";
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

#    for (keys %$continue) { print $_, "=>", $continue->{$_}, "\n"; }

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

    my $error = read_contents_file("$template_dir$template", $tmp);
    return if $error && $error eq "ERROR";

}

sub links_deps {

    my $error = extra_links($changed_text);
    return if $error && $error eq "ERROR";

    $error = hard_links();
    return if $error && $error eq "ERROR";

    $error = library_dependencies("$template_dir$template");
    return if $error && $error eq "ERROR";

}

sub space_left {

    $lib_bool = "" if $lib_bool eq 0;
    $bin_bool = "" if $bin_bool eq 0;
    $mod_bool = "" if $mod_bool eq 0;

    my $error = space_check($filesystem_size, 
              $lib_bool, $bin_bool, $mod_bool,
		$strip_bool, $tmp);
    return if $error && $error eq "ERROR";

}

sub create {

    $lib_bool = "" if $lib_bool eq 0;
    $bin_bool = "" if $bin_bool eq 0;
    $mod_bool = "" if $mod_bool eq 0;

#    my $error = create_filesystem($filename,$filesystem_size,$filesystem_type,
#			       $inode_size,$tmp,$lib_bool,$bin_bool,
#			       $mod_bool,$strip_bool);

    my $error = create_filesystem($filename,$filesystem_size,$tmp,$lib_bool,
			       $bin_bool,$mod_bool,$strip_bool);
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
##    print "$label[0]", $tests{$action}{$label[0]} , "\n";

}

sub test { 

    # Need to know whether genext2fs is being used
    my $fs_type = (split(/\s/,$main::makefs))[0];

    if ( $fs_type ne "genext2fs" ) {
	$tests{30}{test_fstab} = 0;
	$tests{31}{test_inittab} = 0;
	$tests{32}{test_scripts} = 0;
    }

    my $error = which_tests(\%tests); 
    return if $error && $error eq "ERROR";
}

#########################
# CHECK STAGE VARIABLES #
#########################

my %checks = (
	    16 => {
		fstab => 0,
	    },
##	    18 => {
##		fstab_directory_name => 0,
##	    },
##	    17 => { 
##		rc => 0,
##	    }	
);

# try show hide & use variables
sub check_stage {

    my ($widget,$action) = @_;

    my @label = keys( %{ $checks{$action} } );
    # off
    if ($checks{$action}{$label[0]} == 1) {
	$checks{$action}{$label[0]} = 0;
##	if ($label[0] eq "fstab") {
##	    $item_factory->delete_item
##		('/Create/Replacements/fstab directory name');
##	}
    }
    # on
    else {
	$checks{$action}{$label[0]} = 1;
	# Fancy, but not quite what I want
##	if ($label[0] eq "fstab") {
##	    $item_factory->delete_item
##		('/Create/Replacements/fstab directory name');
##	    $item_factory->create_item
##		 (['/Create/Replacements/fstab directory name', 
##		    undef, undef, <Item>]);
##	}
    }
#  print "$label[0]", $checks{$action}{$label[0]} , "\n";

    if ($label[0] eq "fstab") {
	if ($checks{$action}{$label[0]} == 1) {

	    create_fstab("$main::global_yard/Replacements/etc/fstab.new");

        }
    }

}


###########
# YARDBOX #
###########
# cut little booleans for Gtk::CheckMenuItem
my $replacement_bool =    1;
my $module_bool =         1;
my $start_length;
sub yard_box {


    $main::yard_window = new Gtk::Window "toplevel";
    $main::yard_window->signal_connect("destroy", \&destroy_window, 
				       \$main::yard_window);
    $main::yard_window->signal_connect("delete_event",\&destroy_window,
				       \$main::yard_window);
    $main::yard_window->signal_connect("destroy", sub { 
	$search_window->destroy if $search_window; } );
    $main::yard_window->signal_connect("delete_event", sub { 
	$search_window->destroy if $search_window; });
    $main::yard_window->set_usize( 525, 450 );
    $main::yard_window->set_policy( $true, $true, $false );
    $main::yard_window->set_title( "Yard Box - $template" );
    $main::yard_window->border_width(0);

    my $main_vbox = new Gtk::VBox( $false, 0 );
    $main::yard_window->add( $main_vbox );
    $main_vbox->show();

    my $vbox = new Gtk::VBox( $false, 0 );
    $vbox->border_width( 0 );
    $main_vbox->pack_start( $vbox, $false, $true, 0 );
    $vbox->show();

    #_______________________________________ 
    # Item::Factory
    my $menubar = yard_menu($main::yard_window);
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
    ## These next two were removed, because there isn't any
    ## script to make rc, and I can't remember what the
    # fstab directory name entry was for. :*?
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
				    #print "$lib_bool\n";
				} ); 

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
					 #print "$bin_bool\n";
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
					 #print "$mod_bool\n";
				     }
				 ); 


       # Checking - Replacements and/or Modules?

       # Replacements
##       my $replacement_check = $item_factory->get_item
##	   ('/Edit/Settings/Replacements');
##      $replacement_check->active($true);
##       $replacement_check->signal_connect( "activate", 
##				   sub { 
					 # off
##					 if ($replacement_bool == 1) {
##					     $replacement_bool--;
##				         }
					 # on
##					 else {
##					     $replacement_bool++;
##					 }
##					 print "$replacement_bool\n";
##				     }
##				 );        

       # Modules
##       my $modules_check = $item_factory->get_item('/Edit/Settings/Modules');
##       $modules_check->active($true);
##       $modules_check->signal_connect( "activate", 
##				   sub { 
					 # off
##					 if ($module_bool == 1) {
##					     $module_bool--;
##				         }
					 # on
##					 else {
##					     $module_bool++;
##					 }
##					 print "$module_bool\n";
##				     }
##				 );        

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
       #$text->signal_connect("activate", sub { 
       $text->signal_connect("changed", sub { 
	   my $new_length =  $text->get_length();
	   $changed_text_from_template = $text->get_chars(0,$new_length);
       } );

       $table->attach( $text, 0, 1, 0, 1,
                       [ 'expand', 'shrink', 'fill' ],
                       [ 'expand', 'shrink', 'fill' ],
                       0, 0 );
       $text->grab_focus();
       $text->show();

       $text->freeze();
       $text->insert( undef, undef, undef, $changed_text_from_template);
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
       				sub { destroy $main::yard_window; } );
       $vbox->pack_start( $close_button, $true, $true, 0 );
       $close_button->show();

       $save_button = new Gtk::Button( "Save" );
       # This sub can be used by all the saved buttons
       $save_button->signal_connect( 'clicked', \&saved, 102);
       $vbox->pack_start( $save_button, $true, $true, 0 );
       $save_button->show();

       # chrooted tests not wanted for non-root user
       if ( $> != 0 ) {
             $item_factory->delete_item('/Tests/fstab');
             $item_factory->delete_item('/Tests/inittab');
             $item_factory->delete_item('/Tests/scripts');	
       }

        show $main::yard_window;

} # end sub yard_box

sub saved {

    my ($widget,$whoami) = @_;
    my $error;
    
    $text->activate();

    # It's not necessary to use lsMode, but it's a cool program by MJD.
    if  ($whoami == 100 || $whoami == 102 ) {
	if ( file_mode("$template_dir$template") =~ /l/ ) {
	    error_window("gBootRoot: ERROR: " . 
			 "$template_dir$template is not " .
			 "writable.\nUse [ File->Save As ] or " .
			 "[Alt-A] with the yard suffix.");		     
	}
	elsif ( file_mode("$template_dir$template") !~ /w/ ) {
	    error_window("gBootRoot: ERROR: " . 
			 "$template_dir$template is not " .
			 "writable.\nUse [ File->Save As ] or " .
			 "[Alt-A] with the yard suffix.");		     
	}
	else { 
	    # Here's where we get to undef Yard variable and start over at 
	    # check
	    my $new = "$template_dir$template" . ".new";
	    open(NEW,">$new") or 
		($error = error("Can't create $new"));
	    return if $error && $error eq "ERROR";    
	    print NEW $changed_text_from_template;
	    close(NEW);
	    rename($new, "$template_dir$template") or
		($error = error("Can't rename $new to " .
				"$template_dir$template"));
	    return if $error && $error eq "ERROR"; 
	}
    }
    elsif ($whoami == 101) {
	save_as();
    }

} # end sub saved


# rindex and index makes things easy
# This can be added to other widgets.
sub search {

    if (not defined $search_window) {

	$search_window = Gtk::Window->new("toplevel");
	$search_window->set_transient_for($main::yard_window);
	$search_window->signal_connect("destroy", \&destroy_window,
					     \$search_window);
	$search_window->signal_connect("delete_event", \&destroy_window,
					     \$search_window);
	$search_window->signal_connect("key_press_event", sub {
	    my $event = pop @_; 
	    if ($event->{'keyval'}) {
		if ($event->{'keyval'} == 65307) {
		    $search_window->destroy;
		    undef $offset;
		}
	    }
	},
	);

	$search_window->set_policy( $true, $true, $false );
	$search_window->set_title( "gBootRoot:  Search" );
	$search_window->border_width(1);    
	$search_window->set_position('mouse');

	my $main_vbox = Gtk::VBox->new( $false, 0 );
	$search_window->add( $main_vbox );
	$main_vbox->show();

	my $table_search = Gtk::Table->new( 4, 3, $true );
	$main_vbox->pack_start( $table_search, $true, $true, 0 );
	$table_search->show();

	#_______________________________________
	# Search keywords
	label("Search:",0,1,0,1,$table_search);
	my $search1 = entry(1,3,0,1,0,$table_search);
	$search1->signal_connect("changed", sub { 
	    $search_text = $search1->get_text(); });
	$search1->set_text($search_text) if defined $search_text;
	$search1->select_region(0,length($search1->get_text));


	#_______________________________________
	# Case Sensitive

	my $case_sensitive = new Gtk::CheckButton("Case Sensitive");
	$table_search->attach($case_sensitive,1,2,1,2, 
		     ['shrink','fill','expand'],['fill','shrink'],0,0);
	$case_sensitive->show();


	#_______________________________________
	# Search Backwards

	my $search_backwards = new Gtk::CheckButton("Search Backwards");
	$table_search->attach($search_backwards,2,3,1,2, 
		     ['shrink','fill','expand'],['fill','shrink'],0,0);
	$search_backwards->show();

	#_______________________________________
	# Separator	
	my $separator = new Gtk::HSeparator(); 
	$table_search->attach($separator,0,3,2,3, 
		     ['shrink','fill','expand'],['fill','shrink'],0,0);
	$separator->show();

	#_______________________________________
	# Search button

	my ($keywords, $old_keywords, $before_offset);
	my ($tmp_ct, $tmp_k);

	my $submit_b = button(0,1,3,4,"Search",$table_search);
	$search1->signal_connect("key_press_event", sub {
	    my $event = pop @_;
	    if ($event->{'keyval'} == 65293) {
		$submit_b->clicked();
	    }
	});
	$submit_b->can_default(1);
	$search_window->set_default($submit_b);
	$submit_b->grab_default;
	$submit_b->signal_connect( "clicked", sub {

	    my $keywords = $search1->get_text();
	    $before_offset = $offset if $offset != -1;

	    if ($old_keywords ne $keywords) {
		undef $before_offset;
	    }

      	    # rindex
	    if ($search_backwards->active) {

		if (!$offset) {
		    if(!$case_sensitive->active) {
			if (!$tmp_ct && !$tmp_k) {
			    ($tmp_ct = $changed_text_from_template) =~ 
				tr/A-Z/a-z/;
			    ($tmp_k = $keywords) =~ tr/A-Z/a-z/;
			}
			if ($tmp_k && $tmp_k ne $keywords) {
			    ($tmp_k = $keywords) =~ tr/A-Z/a-z/;
			}
			if ($tmp_ct 
			    && $tmp_ct ne $changed_text_from_template) {
			    ($tmp_ct = $changed_text_from_template) =~ 
				tr/A-Z/a-z/;
			}
			$offset = rindex($tmp_ct, $tmp_k);

		    }
		    else {
			$offset = rindex($changed_text_from_template, 
					 $keywords);
		    }
		    if ($offset != -1) {
			my $length = length($keywords);
			$text->set_position($offset);
			$text->get_chars($offset, $length);
			$length = $length + $offset;
			$text->select_region($offset, $length);
		    }

		    # Here is an initial search and nothing is found
		    if (!$before_offset && $offset == -1) {
			error_window("Search string \'$keywords\' not found.");
			undef $offset;
			undef $before_offset;
			return;
		    }

		}
		else {
		    $offset = $offset - 1;

		    if(!$case_sensitive->active) {
			if (!$tmp_ct && !$tmp_k) {
			    ($tmp_ct = $changed_text_from_template) =~ 
				tr/A-Z/a-z/;
			    ($tmp_k = $keywords) =~ tr/A-Z/a-z/;
			}
			if ($tmp_k && $tmp_k ne $keywords) {
			    ($tmp_k = $keywords) =~ tr/A-Z/a-z/;
			}
			if ($tmp_ct 
			    && $tmp_ct ne $changed_text_from_template) {
			    ($tmp_ct = $changed_text_from_template) =~ 
				tr/A-Z/a-z/;
			}
			$offset = rindex($tmp_ct, $tmp_k, $offset);
		    }
		    else {
			$offset = rindex($changed_text_from_template, 
					 $keywords, $offset);
		    }
		    if ($offset != -1) {
			my $length = length($keywords);
			$text->set_position($offset);
                        $text->get_chars($offset, $length);
			$length = $length + $offset;
			$text->select_region($offset,$length);

		    }
		    else {
			$offset = "";
			my $tmp_offset;
			if (!$case_sensitive->active) {
			    $tmp_offset = rindex($tmp_ct, $tmp_k);
			}
			else {
			    $tmp_offset = rindex($changed_text_from_template,
						 $keywords);
			}
			question_window("Beginning of document reached; " . 
					"continue from end?", 
					$search_window, $submit_b,
					-1);
		    }
		}

	    }

	    # index
	    else {
		if (!$offset) {
		    if(!$case_sensitive->active) {
			if (!$tmp_ct && !$tmp_k) {
			    ($tmp_ct = $changed_text_from_template) =~ 
				tr/A-Z/a-z/;
			    ($tmp_k = $keywords) =~ tr/A-Z/a-z/;
			}
			if ($tmp_k && $tmp_k ne $keywords) {
			    ($tmp_k = $keywords) =~ tr/A-Z/a-z/;
			}
			if ($tmp_ct 
			    && $tmp_ct ne $changed_text_from_template) {
			    ($tmp_ct = $changed_text_from_template) =~ 
				tr/A-Z/a-z/;
			}
			$offset = index($tmp_ct, $tmp_k);
		    }
		    else {
			$offset = index($changed_text_from_template, 
					 $keywords);
		    }

		    if ($offset != -1) {
			my $length = length($keywords);
			$text->set_position($offset);
			$text->get_chars($offset, $length);
			$length = $length + $offset;
			$text->select_region($offset, $length);
		    }

		    # Here is an initial search and nothing is found
		    if (!$before_offset && $offset == -1) {
			error_window("Search string \'$keywords\' not found.");
			undef $offset;
			undef $before_offset;
			return;
		    }
		}
		else {
		    $offset = $offset + 1;

		    if(!$case_sensitive->active) {
			if (!$tmp_ct && !$tmp_k) {
			    ($tmp_ct = $changed_text_from_template) =~ 
			    tr/A-Z/a-z/;
			    ($tmp_k = $keywords) =~ tr/A-Z/a-z/;
			}
			if ($tmp_k && $tmp_k ne $keywords) {
			    ($tmp_k = $keywords) =~ tr/A-Z/a-z/;
			}
			if ($tmp_ct 
			    && $tmp_ct ne $changed_text_from_template) {
			    ($tmp_ct = $changed_text_from_template) =~ 
				tr/A-Z/a-z/;
			}
			$offset = index($tmp_ct, $tmp_k, $offset);
		    }
		    else {
			$offset = index($changed_text_from_template, 
					 $keywords, $offset);
		    }
		    if ($offset != -1) {
			my $length = length($keywords);
			$text->set_position($offset);
                        $text->get_chars($offset, $length);
			$length = $length + $offset;
			$text->select_region($offset,$length);
		    }
		    elsif (!$before_offset && $offset == -1) {
			# Here is a continued search and nothing is found
			# We want the question_window to come up first
			# Then pop this error box.
			question_window("End of document reached;"
					. " continue from beginning?", 
					$search_window,$submit_b,
					length($changed_text_from_template));
			$before_offset = -100;
		    }
		    # The previous elsif continues.
		    elsif ($before_offset && $before_offset == -100) {
			    error_window("Search string \'$keywords\' not" .
					 " found.");
			    undef $offset;
			    undef $before_offset;
			    return;		   
		    }
		    else {

			question_window("End of document reached;"
					. " continue from beginning?", 
					$search_window,$submit_b,
					length($changed_text_from_template));
		    }
		}

	    }
	    $old_keywords = $keywords;	    

	} );

	#_______________________________________
	# Cancel button
	my $close_b = button(2,3,3,4,"Cancel",$table_search);
	$close_b->signal_connect("clicked",
				 sub {
				     undef $offset;
				     $search_window->destroy() 
					 if $search_window;
				 } );

   }
   if (!visible $search_window) {
       $search_window->show();
   } 

} # end sub search


# Just a universal dialog box with OK and Cancel
sub question_window {

    my ($output,$widget, $widget_button, $tmp_offset) = @_;
    my ($ok_button, $c_button);

    if (not defined $question_window) {
    $question_window = new Gtk::Dialog;
    $question_window->set_modal($true);
    $question_window->set_transient_for($widget);
    $question_window->signal_connect("destroy", \&destroy_window,
                                  \$question_window);
    $question_window->signal_connect("delete_event", \&destroy_window, 
                                  \$question_window);
    $question_window->signal_connect("key_press_event", sub {
	    my $event = pop @_; 
	    if ($event->{'keyval'}) {
		    if ($event->{'keyval'} == 65307) {
			$offset = $tmp_offset;
			$question_window->destroy 
		    }
		    elsif ($event->{'keyval'} == 65293) {
			$widget_button->clicked;
			$question_window->destroy;
		    }
	    }
    });
    $question_window->set_title("gBootRoot Question?");
    $question_window->border_width(15);
    my $label = new Gtk::Label($output);
    #$label->set_justify("left") if $_[1];
    $question_window->vbox->pack_start( $label, $true, $true, 15 );
    $label->show();

    # OK button
    #----------------------------------------
    $ok_button = new Gtk::Button("OK");
    $ok_button->signal_connect("clicked", sub {
	$widget_button->clicked;
	$question_window->destroy;
    });
    $ok_button->can_default(1);
    $question_window->action_area->pack_start($ok_button, $false, $false,0);
    $ok_button->grab_default;
    $ok_button->show;

    # Cancel button
    #----------------------------------------
    $c_button = new Gtk::Button("Cancel");
    $c_button->signal_connect("clicked", sub {
	$offset = $tmp_offset;
	$question_window->destroy if $question_window;
    });
    $question_window->action_area->pack_start($c_button, $false, $false,0);
    $c_button->show;

   }
     if (!visible $question_window) {
         $question_window->show;
     }

    return ($ok_button,$c_button);

} # end sub question_window


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

# This will just be a simple dialog
my $write_over;
sub save_as {

# Will just use a dialog box.
    my ($error,$count,$pattern) = @_;

    if (not defined $save_as) {
    $save_as = Gtk::Dialog->new();
    $save_as->signal_connect("destroy", \&destroy_window, \$save_as);
    $save_as->signal_connect("delete_event", \&destroy_window, \$save_as);
    $save_as->set_title("Save As");
    $save_as->border_width(12);
    $save_as->set_position('center');

    my $new_template;
    my $entry = Gtk::Entry->new();
    $entry->set_editable( $true );
    $entry->set_text($template) if $template;
    $entry->signal_connect( "changed", sub {
	$new_template = $entry->get_text();
    }); 
    $save_as->vbox->pack_start( $entry, $false, $false, 0);
    $entry->show();

    my $label = Gtk::Label->new();
    $label->set_justify( 'left' );
    #$label->set_pattern("_________") if defined $pattern;
    $save_as->vbox->pack_start( $label, $false, $false, 2 );
    $label->show();
    my $button = Gtk::Button->new("OK");
    my $new_template_tmp = "nothing";
    my $event_count = 0;
    $button->signal_connect("clicked", sub {

	# Here's where we get to undef Yard variable and start over at 
	# check
	my $new = "$template_dir$new_template" if $new_template;

	if (!$new_template) {
	    if ( file_mode("$template_dir$template") =~ /l/ ) {
		error_window("gBootRoot: ERROR: " . 
			     "$template_dir$template is not " .
			     "writable.\nUse [ File->Save As ] or " .
			     "[Alt-S] with the yard suffix.");		     
		$save_as->destroy;
		return;
	    }
	    elsif ( file_mode("$template_dir$template") !~ /w/ ) {
		error_window("gBootRoot: ERROR: " . 
			     "$template_dir$template is not " .
			     "writable.\nUse [ File->Save As ] or " .
			     "[Alt-S] with the yard suffix.");		     
		$save_as->destroy;
		return;
		#save_as();
	    }
	}

	# An open template should just be saved not saved_as.
	if (!$new_template) {
	    error_window("gBootRoot: ERROR: $template already exists, " . 
			 "use Save instead.");
	    $save_as->destroy;
	    return;
	}

	# An existing file shouldn't be written over unless the user wants
	# this to happen.
	if (!-f $new) {

	    open(NEW,">$new") or 
		($error = error("Can't create $new"));
	    return if $error && $error eq "ERROR";    
	    print NEW $changed_text_from_template;
	    close(NEW);
	    $template = $new_template;

	    opendir(DIR,$template_dir) if -d $template_dir; 
	    my @templates = grep { m,\.yard$, } readdir(DIR) if $template_dir;
	    closedir(DIR);
	    $main::combo->set_popdown_strings( @templates ) if @templates; 
	    $main::combo->entry->set_text($new_template);
	    $main::yard_window->set_title( "Yard Box - $template" );
	    $save_as->destroy;
	}
	else { 

	    
	    if ( file_mode("$new") =~ /l/ ) {
		error_window("gBootRoot: ERROR: " . 
			     "$new is not " .
			     "writable.\nUse [ File->Save As ] or " .
			     "[Alt-S] with the yard suffix.");		     
		$save_as->destroy;
		return;
	    }
	    elsif ( file_mode("$new") !~ /w/ ) {
		error_window("gBootRoot: ERROR: " . 
			     "$new is not " .
			     "writable.\nUse [ File->Save As ] or " .
			     "[Alt-S] with the yard suffix.");		     
		$save_as->destroy;
		return;
	    }


	    $label->set_text("$new_template already exists, " . 
			     "do\nyou want to write over it, " .
			     "or\nsave $template with a different name?");

	    $event_count++;
	    my $event = pop(@_);

	    if ($new_template eq $new_template_tmp) {
	    if ($event_count >= 2 && $event && $event eq "clicked") {

		open(NEW,">$new") or 
		    ($error = error("Can't create $new"));
		return if $error && $error eq "ERROR";    
		print NEW $changed_text_from_template;
		close(NEW);
		$template = $new_template;

		opendir(DIR,$template_dir) if -d $template_dir; 
		my @templates = grep { m,\.yard$, } readdir(DIR) 
		    if $template_dir;
		closedir(DIR);
		$main::combo->set_popdown_strings( @templates ) if @templates; 
		$main::combo->entry->set_text($new_template);
		$main::yard_window->set_title( "Yard Box - $template" );

		$event_count = 0;
		$save_as->destroy;
	    }	    
	    }
	    $new_template_tmp = $new_template;
	}

    }, "clicked");

    $button->can_default(1);
    $save_as->action_area->pack_start($button, $false, $false,0);
    $button->grab_default;
    $button->show;

    $button = Gtk::Button->new("Cancel");
    $button->signal_connect("clicked", sub { destroy $save_as} );
    $save_as->action_area->pack_start($button, $false, $false,0);
    $button->show;
    }
     if (!visible $save_as) {
        show $save_as;
     }
     else {
        destroy $save_as;
        #save_as($error,$count) if $error == 0;
     }

} # end sub save_as

sub tutorial {

   if (not defined $tutorial) {
    $tutorial = Gtk::Dialog->new();
    $tutorial->signal_connect("destroy", \&destroy_window, \$tutorial);
    $tutorial->signal_connect("delete_event", \&destroy_window, \$tutorial);
    $tutorial->set_title("Tutorial");
    $tutorial->border_width(12);
    $tutorial->set_position('center');

    my $label = Gtk::Label->
	new("Tutorial is in /usr/share/doc/gbootroot/html/index.html.");
    $label->set_justify( 'left' );
#    $label->set_pattern("_________");
    $tutorial->vbox->pack_start( $label, $false, $false, 2 );
    $label->show();
 
    my $button = Gtk::Button->new("OK");
    $button->signal_connect("clicked", sub {

	    $tutorial->destroy;
    });
    $button->can_default(1);
    $tutorial->action_area->pack_start($button, $false, $false,0);
    $button->grab_default;
    $button->show;


    }
     if (!visible $tutorial) {
         $tutorial->show();
     }
     else {
        $tutorial->destroy();
     }

} # end sub tutorial
 
sub shortcut {

   if (not defined $shortcut) {
    $shortcut = Gtk::Dialog->new();
    $shortcut->signal_connect("destroy", \&destroy_window, \$shortcut);
    $shortcut->signal_connect("delete_event", \&destroy_window, \$shortcut);
    $shortcut->set_title("Shortcuts");
    $shortcut->border_width(12);
    $shortcut->set_position('center');

    my $label = Gtk::Label->new($Shortcuts);
    $label->set_justify( 'left' );
#    $label->set_pattern("_________");
    $shortcut->vbox->pack_start( $label, $false, $false, 2 );
    $label->show();
 
    my $button = Gtk::Button->new("OK");
    $button->signal_connect("clicked", sub {

	    $shortcut->destroy;
    });
    $button->can_default(1);
    $shortcut->action_area->pack_start($button, $false, $false,0);
    $button->grab_default;
    $button->show;


    }
     if (!visible $shortcut) {
         $shortcut->show();
     }
     else {
        $shortcut->destroy();
     }

}


$Shortcuts = << "SHORTCUTS";
Motion Shortcuts 

 Ctrl-A    Beginning of line 
 Ctrl-E    End of line 
 Ctrl-N    Next Line 
 Ctrl-P    Previous Line 
 Ctrl-B    Backward one character 
 Ctrl-F    Forward one character 
 Alt-B     Backward one word 
 Alt-F     Forward one word 
 Ctrl-Home Beginning of buffer
 Ctrl-End  End of buffer

 Editing Shortcuts 

 Ctrl-H  Delete Backward Character (Backspace) 
 Ctrl-D  Delete Forward Character (Delete) 
 Ctrl-W  Delete Backward Word 
 Alt-D   Delete Forward Word 
 Ctrl-K  Delete to end of line 
 Ctrl-U  Delete line 

Selection Shortcuts 

 Ctrl-X  Cut to clipboard 
 Ctrl-C  Copy to clipboard 
 Ctrl-V  Paste from clipboard

Searching Shortcuts

 Alt-S Search Template

File Shortcuts

 Alt-N  New Template  
 Ctrl-S Save File
 Alt-A  Save As File
SHORTCUTS

sub path {

    if (not defined $path_window) {

	$path_window = Gtk::Window->new("toplevel");
	$path_window->signal_connect("destroy", \&destroy_window,
					     \$path_window);
	$path_window->signal_connect("delete_event", \&destroy_window,
					     \$path_window);
	$path_window->set_policy( $true, $true, $false );
	$path_window->set_title( "Path Box" );
	$path_window->set_usize( 450, "" );
	$path_window->border_width(1);    

	my $main_vbox = Gtk::VBox->new( $false, 0 );
	$path_window->add( $main_vbox );
	$main_vbox->show();

	my $table_path = Gtk::Table->new( 2, 3, $true );
	$main_vbox->pack_start( $table_path, $true, $true, 0 );
	$table_path->show();

	#_______________________________________
	# Editor and execute options
	label("Extra Path(s):",0,1,0,1,$table_path);
	my $path11 = entry(1,3,0,1,3,$table_path);
	#$fs1->set_text(":");

	$table_path->set_row_spacing( 0, 2);       

	#_______________________________________
	# Submit button
	my $submit_b = button(0,1,1,2,"Submit",$table_path);
	$submit_b->signal_connect( "clicked", sub {
	    if ($entry[3]) {

		my @pathlist = split(':', $ENV{'PATH'});
		@main::additional_dirs = split(/:|\s+|,/,$entry[3]);
		my @additional_dirs;

		# Check to see if this path doesn't already exist.
		foreach my $alt_path ( @main::additional_dirs ) {
		    my $add_path = grep(/$alt_path/,$ENV{'PATH'});
		    if ($add_path == 0) {
			push(@additional_dirs, $alt_path);
		    }
		}

		info(1, "Search path is now:\n", 
		     join(" ", @additional_dirs), " ",
		     join(" ", @pathlist), "\n");
	    }
	} );

	#_______________________________________
	# Close button
	my $close_b = button(2,3,1,2,"Close",$table_path);
	$close_b->signal_connect("clicked",
				 sub {
				     $path_window->destroy() 
					 if $path_window;
				 } );


    }
    if (!visible $path_window) {
	$path_window->show();
    } else {
       $path_window->destroy;
    }

}

sub Replacements {
    
    if (not defined $replacements_window) {

	$replacements_window = Gtk::Window->new("toplevel");
	$replacements_window->signal_connect("destroy", \&destroy_window,
					     \$replacements_window);
	$replacements_window->signal_connect("delete_event", \&destroy_window,
					     \$replacements_window);
	$replacements_window->set_policy( $true, $true, $false );
	$replacements_window->set_title( "Replacements Box" );
	$replacements_window->border_width(1);    

	my $main_vbox = Gtk::VBox->new( $false, 0 );
	$replacements_window->add( $main_vbox );
	$main_vbox->show();

	my $table_replacements = Gtk::Table->new( 3, 3, $true );
	$main_vbox->pack_start( $table_replacements, $true, $true, 0 );
	$table_replacements->show();

	#_______________________________________
	# Editor and execute options
	label("Editor:",0,1,0,1,$table_replacements);
	my $repl1 = entry(1,3,0,1,0,$table_replacements);
	$repl1->set_text($main::editor);

#my $tooltips = Gtk::Tooltips->new();
#    $tooltips->set_tip( $repl1, 
#			"Choose an editory with " .
#			"its executable option switch.", 
#			"" );

	#_______________________________________
	# Replacement file
	label("Replacement:",0,1,1,2,$table_replacements);
	my $repl2 = entry(1,2,1,2,1,$table_replacements);
	button_fileselect(2,3,1,2,"Selection",$repl2,"Selection",0,
			  $table_replacements,
			  "$main::global_yard/Replacements/");
	$repl2->set_text("$main::global_yard/Replacements/") 
	    if -e "$main::global_yard/Replacements/";

	$table_replacements->set_row_spacing( 1, 3);       


	#_______________________________________
	# Submit button
	my $submit_b = button(0,1,2,3,"Submit",$table_replacements);
	$submit_b->can_default($true);
	$submit_b->grab_default();
	$submit_b->signal_connect( "clicked", sub {
	    if ($entry[0] && $entry[1]) {

		# Check to see if it actually exists
		my $executable = (split(/\s+/,$entry[0]))[0];
		if (!find_file_in_path(basename($executable))) {
		    error_window("gBootRoot: ERROR: Enter a valid editor.");
		    return;
		}
		if ($executable =~ m,/,) {
		    if (! -e $executable) {
			error_window("gBootRoot: ERROR: " . 
				     "Enter a valid path for the editor.");
			return;
		    }
		}

		my $pid; 
		unless ($pid = fork) {
		    unless (fork) {
			if ($pid == 0) {
			    sys("$entry[0] $entry[1]");
			    Gtk->_exit($pid);
			}
		    }
		}
		waitpid($pid,0);
	    }

	} );

	#_______________________________________
	# Close button
	my $close_b = button(2,3,2,3,"Close",$table_replacements);
	$close_b->signal_connect("clicked",
				 sub {
				     $replacements_window->destroy() 
					 if $replacements_window;
				 } );

   }
   if (!visible $replacements_window) {
       $replacements_window->show();
   }

}

# Just label_advanced
sub label {

    my($text) = @_;

    my $label = Gtk::Label->new( $text );
    $label->set_justify( "fill" );
    $_[5]->attach($label,$_[1],$_[2],$_[3],$_[4], ['expand'],['fill','shrink'],0,0);
    $label->show();

}

# Just entry_advanced
sub entry {

    my $numa = $_[4];
    my $entry = Gtk::Entry->new();
    $entry->set_editable( $true );
    $entry->signal_connect( "changed", sub {
    $entry[$numa] = $entry->get_text();
#          if ($numa == 4) {
#	     $ars->{filename} = $entry[$numa];
#	      ars($ars);
#	 }
     } );
    $entry->set_usize(100,20);
    $_[5]->attach($entry,$_[0],$_[1],$_[2],$_[3], 
                            ['shrink','fill','expand'],['fill','shrink'],0,0);
    show $entry;
    return $entry;

}

sub button {

    # cretzu should like this
    my ($left_attach,$right_attach,$top_attach,
                     $bottom_attach,$text,$widget) = @_;
    my $button = Gtk::Button->new($text);
    $widget->attach($button,$left_attach,$right_attach,
                                 $top_attach,$bottom_attach, 
                            ['shrink','fill','expand'],['fill','shrink'],2,2);
    show $button;
    return $button;

}

sub button_fileselect {

    # cretzu should like this
    # $order does matter because it fills in $container[$order].
    my ($left_attach,$right_attach,$top_attach,$bottom_attach,$text,$ent,
        $name,$order,$widget,$device) = @_;

    my $button = Gtk::Button->new($text);
    $widget->attach($button,$left_attach,$right_attach,
                                 $top_attach,$bottom_attach, 
                            ['shrink','fill','expand'],['fill','shrink'],2,2);

    $button->signal_connect( "clicked",\&fileselect,$ent,$name,$order,$device);
    $button->show();


} # end sub button_fileselect

sub fileselect {

    my ($widget,$ent,$name,$order,$device) = @_;

    if (not defined $file_dialog) {
        # Create a new file selection widget
        $file_dialog = Gtk::FileSelection->new( "$name" );
        $file_dialog->signal_connect( "destroy",
                                     \&destroy_window, \$file_dialog);
        $file_dialog->signal_connect( "delete_event",
                                     \&destroy_window, \$file_dialog);

        # Connect the ok_button to file_ok_sel function
        $file_dialog->ok_button->signal_connect( "clicked",
                                         \&file_ok_sel,
                                         $file_dialog,$ent,$order);

        # Connect the cancel_button to destroy the widget
        $file_dialog->cancel_button->signal_connect( "clicked",
                                              sub { destroy $file_dialog } );
         $file_dialog->set_filename( $device ) if defined $device;
         $file_dialog->set_position('mouse');

     }
     if (!visible $file_dialog) {
         show $file_dialog;
     }
     else {
        destroy $file_dialog;
     }

} # end sub fileselect


sub file_ok_sel {

    my( $widget, $file_selection,$entry,$order) = @_;
    my $file = $file_selection->get_filename();
    $entry->set_text($file);
    destroy $file_dialog;

}

###### Replacement Stuff


1;












