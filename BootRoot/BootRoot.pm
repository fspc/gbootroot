#!/usr/bin/perl -w

##############################################################################
##
##  BootRoot.pm 
##  Copyright (C) 2000, 2001, 2002  by Jonathan Rosenbaum 
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

package BootRoot::BootRoot;
use vars qw(@ISA @EXPORT %EXPORT_TAGS);
use Exporter;
@ISA = qw(Exporter);
@EXPORT =  qw(start);

use strict;
use POSIX;
use BootRoot::Yard;
use BootRoot::YardBox;
use BootRoot::Error;
use File::Basename;
use File::Find;
use File::Path;

# If you want gBootRoot to do it's stuff somewhere else, change the
# value for $tmp1.
my $tmp1 = "/tmp";              # tmp should be default - Cristian
my $lilo_conf = "/etc/lilo.conf";
my $home = "$ENV{HOME}/.gbootroot";
my $uml_xterm = "xterm -e";

# Don't edit from here, but you can if you want to change the HERE docs
# and/or the contents of initrd (in which case you need to make sure the
# right libraries are copied over to initrd and the size is checked).

# I need to remember to edit this
# and to update scripts/Debian.yard if
# make_debian has been changed,
# and to install -s linux.
my $version = "1.3.5";
my $date = "02.13.2002";
my $gtk_perl_version = "0.7002";
my $pwd = `pwd`; chomp $pwd;
my $home_rootfs = "$home/root_filesystem/";
my $home_uml_kernel = "$home/uml_kernel/";
my $modules_directory = "/lib/modules";

# This is for experimental stuff .. basically so I can test
# the boot fs as a normal user, since it's hard to create a boot disk
# with enough room using genext2fs.
my $busybox;

# Yard Stuff
my $home_yard = "$home/yard";
my $template_dir = "$home_yard/templates/";
my $home_yard_replacements = "$home_yard/Replacements";
$main::global_yard =  $home_yard;
$main::oldroot = "/OLDROOT";
my $global_yard_replacements_arch_indep  = 
    "/usr/share/gbootroot/yard/Replacements";
my $global_yard_replacements_arch_dep = "/usr/lib/bootroot/yard/Replacements";
my $global_yard_templates = "/usr/share/gbootroot/yard/templates";
$ENV{'PATH'} = "$home_yard:" . $ENV{'PATH'};

my $initrd;
my $compress;
my $false = 0;
my $true = 1;

# Helps determine what procedure to follow for the Boot Disk
my $ok; 

my $box2;
my $label;
my $label_advanced;
my $separator;
my $order;
my $text_window;
my $verbosity_window;
#my $colormap;
#my $window;

# Make @container verbose, also look in generate()
my @container;
use constant  METHOD               => 0  ;
use constant  KERNEL               => 1  ;
use constant  ROOT_FS              => 2  ;
use constant  BOOT_DEVICE          => 3  ;
use constant  SIZE                 => 4  ;
use constant  COMPRESS             => 5  ;
use constant  LIB_STRIP            => 6  ;
use constant  BIN_STRIP            => 7  ;
use constant  OBJCOPY_BOOL         => 8  ;
use constant  ABS_DEVICE           => 9  ;
use constant  ABS_OPT_DEVICE       => 10 ;
use constant  ABS_APPEND           => 11 ;

# The Selection values are used for button_fileselect_advanced
# since it shares fileselect and file_ok_sel with button.
#
# ABS: 12=Root_Device_Selection 13=UML_Kernel_Selection 
# UML BOX: 14=Root_Fs_Selection
#
use constant  MOD_STRIP            => 15 ;
#
# ABS: 16=System.map_Selection
 
my @original_container;
my $file_dialog;

my $mtab;
# $old_mount is used for a little swapping magic when a normal user
# is using genext2fs and lilo.
my ($tmp, $mnt, $old_mount);  
my $norm_root_device;
my ($hbox_advanced); 
my $separator_advanced;

my @entry_advanced;
my ($ea1,$ea2,$ea3,$ea4,$ea5,$ea6); # entry advanced boot  
my ($ear1,$ear2,$ear2_save,$ear3,$ear4); # entry advanced root
my ($eab1,$eab2,$eab3,$eab4); # entry advanced uml
my ($mtd_radio, $mtd_fs_type, $mtd_fs_type_combo, @fs_types,
    $mtd_radio_mtdram, $mtd_radio_blkmtd, $mtd_check, $mtd_size,
    $mtd_total_size); # mtd uml box
my $uml_window;
my $table_advanced;
my $table_advanced_root;
my ($spinner_advanced,$spinner_size);
my $button_count = 0;
my $button_count_root = 0;
my $obj_count = 0;
my $obj_count_root = 0;
my ($lib_strip_check,$bin_strip_check,$mod_strip_check);
my ($bz2_toggle,$gz_toggle);
my ($bz2_toggle_root,$gz_toggle_root,$compression_off);
#my ($main::combo); made this totally global
my ($adj2,$adj3);
my @strings;

#######
#######
# Since the restructuring
#######
my $tooltips;
my $vbox_advanced;
my $vbox_advanced_root;
my $entry3;
my $box1;
my $entry5;
my $pbar;
my $rbutton;
my $verbosefn;
my $umid;

# Value set by kernel_modules
my $kernel_version;  

# $entry_advanced[3] is the Root Device
# $filesystem_size and root_device_size are important globals for ARS,
# there weren't put into entry_advanced because they are spin buttons.
# $entry_advanced[4] is the Root Filename 
#
my ($filesystem_size, $root_device_size);
#
# Carrries ARS values to other modules via ars(), another program just has to 
# export ars and it can capture these values
my $ars = {}; # anonymous hash


# My own creation - the roots touch the ground if three lines are added.
       my @xpm_data = (
"32 45 3 1",
"       c None",
".      c SaddleBrown",
"X      c black",
"   ...    ...                   ",
"   ...    ...                   ",
"   ...    ...                   ",
"   ...    ...                   ",
"   ...    ...                   ",
"   ...    ...                   ",
"   ...    ...                   ",
"   ...    ...                   ",
"   ...    ...                   ",
"   ...     ..                   ",
"  ...      ...                  ",
"  ...       ...                 ",
" ....        ...                ",
" ....         ...               ",
" ....          ...              ",
" ....           .............   ",
" .....           .............  ",
" ......           ............. ",
" .......                     ...",
".........                     ..",
"................................",
"................................",
"............................... ",
"......... XXXXX   ............  ",
"........   XXX      ..........  ",
"........   XXX      ........    ",
"         XXXXXX                 ",
"    XXX  XXX   X XX XX          ",
"   X  XXXXX     X   X X         ",
"  XX  XXX       X       XX      ",
" X    XX        X         X     ",
" X    XX        X      XX X     ",
" XX   XX         X    XXXXX     ",
"  X   XXXX XXX    XXXXX   X     ",
" XX   XX      XX    X     XX    ",
" X     X       X    X      X    ",
" X     XX       X   XX     X    ",
" X      XX      XX         X    ",
" X      XX       XXXXXXX XXX    ",
" XX    XX               XXX     ",
"  XX  XX      XXXX     XX XX    ",
"  XX XXX      X  XXXXXXX   X    ",
"  X   XXX     X            XX   ",
"        XX    XXXXXXX       XXX ",
"         X          XX        X ",
"          X          X          "
                        );

sub start {


if ( $> != 0 && -e "/usr/lib/bootroot/genext2fs" ) {
    $main::makefs = "genext2fs -z -r0"; # -i8192 not a good idea
}


$SIG{INT} = \&signal;
$SIG{ABRT} = \&signal;
$SIG{TERM} = \&signal;
$SIG{QUIT} = \&signal;
$SIG{KILL} = \&signal;

(undef,$container[KERNEL],$container[ABS_APPEND]) = gdkbirdaao();


my ($sec,$min,$hour,$day,$month,$year) = (localtime)[0,1,2,3,4,5];
my $time = sprintf("%02d:%02d:%02d-%02d-%02d-%04d", 
		   $hour, $min, $sec, $month+1, $day, $year+1900);

# Here's where stuff gets intersting, non-root users can create root_fs,
# which is great for UML, and a boot disk.

if ( $> == 0 ) {

    if (!-d "$tmp1/gbootroot_tmp$time") {   
	$tmp = "$tmp1/gbootroot_tmp$time" if err_custom_perl(
		"mkdir $tmp1/gbootroot_tmp$time",
		 "gBootRoot: ERROR: Could not make temporary directory") != 2;
    }
    if (!-d "$tmp1/gbootroot_mnt$time") {
	$mnt = "$tmp1/gbootroot_mnt$time" if err_custom_perl(
	       "mkdir $tmp1/gbootroot_mnt$time",
               "gBootRoot: ERROR: Could not make mount directory") != 2;
    }

    # Why?
    $tmp = "$tmp1/gbootroot_tmp$time";

}
else {

    # The Administrator just needs to add a line like the one below to the 
    # fstab for each non-root user who wants to be able to create root_fs.
    # In this example, `id -u` has to be the actual effective numeric user 
    # id,  and the root_fs has to always be named root_fs when it is being
    # made, but it can be renamed afterwards.
    #
    # /tmp/gboot_non_root_`id -u`/root_fs  \ 
    # /tmp/gboot_non_root_`id -u`/loopback \
    # auto   defaults,noauto,user,loop       0       0
    #
    # For the boot/root disks the administrator will have to give the user
    # special su privileges (mknod) to make special devices.  The $sudo 
    # variable can be set to sudo or super, fakeroot won't work.
    # These include: /dev/{console,null,ram0,ram1,tty0}
    # These two lines need to be added to create the boot_fs and the boot/root
    # disk.  In this example the user is locked into using one type of device 
    # for the boot/root
    #
    # /tmp/gboot_non_root_`id -u`/initrd_image \ 
    # /tmp/gboot_non_root_'id -u1`/initrd_mnt  \
    # auto   defaults,noauto,user,loop       0      0
    #
    #
    # For genext2fs this is the only line required, this is so that lilo can 
    # run.
    #
    # /dev/fd0 /tmp/gboot_not_root_mnt_`id -u` auto  defaults,noauto,user 0 0
    

    my $user = $>;

    if (!-d "$tmp1/gboot_non_root_$user") {   
	$tmp = "$tmp1/gboot_non_root_$user" if err_custom_perl(
		"mkdir $tmp1/gboot_non_root_$user",
		 "gBootRoot: ERROR: Could not make temporary directory") != 2;
    }
    $tmp = "$tmp1/gboot_non_root_$user";

    if (!-d "$tmp1/gboot_non_root_mnt_$user") {
	$mnt = "$tmp1/gboot_non_root_mnt_$user" if err_custom_perl(
	       "mkdir $tmp1/gboot_non_root_mnt_$user",
               "gBootRoot: ERROR: Could not make mount directory") != 2;
    }
    $mnt = "$tmp1/gboot_non_root_mnt_$user";

}


# Verbosity is universal for all methods, and controlled by a scale slider. 
# Yard 
#  0 --> only the important messages.
#  1 --> all messages.
my $verbosity = 1; # info & sys use this as Global

## One hard copy log file is saved for the session, and the user can also 
## save from the verbosity box including saving a selection.

$verbosefn = "$tmp/verbose"; # All verbosity
#my $verbosefn = "/tmp/verbose";  # Yard - always logged, but 0&1 = STDOUT

# Need this before everything.
Gtk::Rc->parse("/etc/gbootroot/gbootrootrc");

verbosity_box();
start_logging_output($verbosefn,$verbosity); # Yard "tmp dir name" 
                                             # "verbosity level"

#-------------------------------
# USER DIRECTORIES
# /tmp
home_builder($tmp1);

# $HOME/.gbootroot/root_filesystem
home_builder($home_rootfs);

# $HOME/.gbootroot/uml_kernel
home_builder($home_uml_kernel);
symlink_builder("/usr/bin/linux","$home_uml_kernel/linux");
if (!-e "$home_uml_kernel/.options") {
    open(OPTIONS,">$home_uml_kernel/.options") 
	or die "Couldn't write $home_uml_kernel/.options at $?\n";
    print OPTIONS "umid=bootroot root=/dev/ubd0 mem=16M\n";
    close(OPTIONS);
}

# $HOME/.gbootroot/yard/templates 
home_builder($template_dir);
if ( -d $global_yard_templates ) {
    opendir(DIR,$global_yard_templates) if -d $template_dir;
    # I decided this may be too restrictive, besides, everything
    # is kept in its own directory.
    #my @templates = grep { m,\.yard$, } readdir(DIR); 
    my @templates = grep { m,^\w+, } readdir(DIR); 
    closedir(DIR);
    foreach ( @templates ) {
	if (!-e "$template_dir/$_" && !-l "$template_dir/$_") {
	    symlink_builder("$global_yard_templates/$_","$template_dir/$_");
	}
    }
}

# Arch indep replacements repository
# $HOME/.gbootroot/yard/Replacements 
home_builder($home_yard_replacements);
if ( -d $global_yard_replacements_arch_indep ) {
    if (-d $home_yard_replacements) {
	find sub {  ( my $replacement = 
		       $File::Find::name ) =~ s/$global_yard_replacements_arch_indep\///;
		   if (!-e "$home_yard_replacements/$replacement") {

		       #system "cp -a $File::Find::name $home_yard_replacements/$replacement > /dev/null 2>&1";
		       system "mkdir $home_yard_replacements/$replacement > /dev/null 2>&1" if -d $File::Find::name;
		       symlink_builder( $File::Find::name,"$home_yard_replacements/$replacement") if !-d $File::Find::name;
		   }

	       }, $global_yard_replacements_arch_indep;
		      

    }
}

# Arch dep replacements repository
if ( -d $global_yard_replacements_arch_dep ) {
    if (-d $home_yard_replacements) {
	find sub {  ( my $replacement = 
		       $File::Find::name ) =~ s/$global_yard_replacements_arch_dep\///;
		   if (!-e "$home_yard_replacements/$replacement") {

		       #system "cp -a $File::Find::name $home_yard_replacements/$replacement > /dev/null 2>&1";
		       system "mkdir $home_yard_replacements/$replacement > /dev/null 2>&1" if -d $File::Find::name;
		       symlink_builder( $File::Find::name,"$home_yard_replacements/$replacement") if !-d $File::Find::name;
		   }

	       }, $global_yard_replacements_arch_dep;
		      

    }
}



#-------------------------------

# Gtk::check_version expects different arguments than .7004 so will have
# to check for the version instead.
# Right now >= 0.7002 is o.k.
#if (Gtk::check_version(undef,"1","0","7") =~ /too old/) {

if (Gtk->major_version < 1) {
    et();
}
elsif (Gtk->micro_version < 7) {
    et();
}
elsif (Gtk->minor_version < 2) {
    et();
}


my $window = Gtk::Window->new("toplevel");
# special policy
$window->set_policy( $false, $true, $true );
$window->set_title("gBootRoot");
$window->set_position('none');
$window->signal_connect("destroy",
                        sub {
                          unlink "$verbosefn", "$tmp/initrd_image.gz";
                          rmdir "$tmp/initrd_mnt";
                          rmdir "$tmp";
                          rmdir "$mnt";
                          Gtk->exit(0);
                        });
$window->border_width(1);
$window->realize;

# Do the iconizing thing
# "xpm/circles.xpm" can be @pixmap within file if not create_from_xpm.
my ($circles,$mask) = Gtk::Gdk::Pixmap->create_from_xpm_d($window->window,
                                                        $window->style->white,
                                                        @xpm_data);
$window->window->set_icon(undef, $circles, $mask);
$window->window->set_icon_name("gBootRoot");
# Zas - bug in gtk-perl < .7002 
$window->window->set_decorations(['all', 'menu']); 
$window->window->set_functions(['all', 'resize']); 

$tooltips = Gtk::Tooltips->new();

$box1 = Gtk::VBox->new($false,0);
$window->add($box1);
$box1->show();

# First row
hbox();
my $entry = entry($false,0);

# Menu - later this may be improved if new methods are added.
my $opt = Gtk::OptionMenu->new();
$tooltips->set_tip( $opt, "Choose the Boot method.", "" );
my $menu = Gtk::Menu->new();
my $item = Gtk::MenuItem->new("2 disk compression" );
$item->show();
# Eventually get_menu, or something totally different will be used.
$item->signal_connect( 'activate',
    sub { $entry->set_text("2 disk compression");
	  $container[METHOD] = "2 disk compression";
	  two_disk_compression_check();
          kernel_modules(); });
$menu->append( $item );
$opt->set_menu( $menu );
$box2->pack_start( $opt, $true, $true, 0 );
$opt->show();
$box2->show();

# Second row
# Get to look three places for kernel value
# default ( null|gdkkbirdaao) &&  entry() && fileselect->file_ok_sel 
hbox();
my $entry2 = entry($true,1);
$entry2->set_text($container[KERNEL]);
if ($container[KERNEL]) {
    $ars->{kernel} = $container[KERNEL];
    ars($ars);
    ars2($ars);
}
button("Kernel Selection",$entry2,"Kernel Selection",1);

# Third row
hbox();
$entry3 = entry($true,2);
button("Root Filesystem",$entry3,"Root Filesystem",2,$home_rootfs);

# In the future, if experimenters send in data, there will be two
# different devices.
# Fourth row
hbox();
my $entry4 = entry($true,3);
$container[BOOT_DEVICE] = "/dev/fd0";
$entry4->set_text($container[BOOT_DEVICE]);
button("Device Selection",$entry4,"Device Selection",3,"/dev/fd0");

# Fifth row
hbox("what");
my $adj = Gtk::Adjustment->new( 1440.0, 0.0, 360000000.0, 282.0, 360.0, 0.0 );
my $spinner = Gtk::SpinButton->new( $adj, 0, 0 );
$tooltips->set_tip( $spinner, "Choose the Device Size.\n" .
"Hint:  Many 1440 floppy drives support 1722.\n", "" );
$spinner->set_wrap( $true );
$spinner->set_numeric( $true );
$spinner->set_shadow_type( 'in' );
$spinner->show();
$container[SIZE] = 1440; # A better value - a rtbt trick.
$adj->signal_connect( "value_changed", sub {
    $container[SIZE] = $spinner->get_value_as_int();
    $adj2->set_value($container[SIZE]) if defined $adj2;});
$box2->pack_start( $spinner, $true, $true, 0 );
#label("Device Size");

# gz and bz2 radio buttons
$rbutton = Gtk::RadioButton->new( "gz" );
$tooltips->set_tip( $rbutton, "Choose Compression used on the Filesystem.", "" );
$gz_toggle = $rbutton;
$rbutton->set_active( $true );
$box2->pack_start( $rbutton, $false, $false, 0 );
$rbutton->show();
$rbutton =  Gtk::RadioButton->new( "bz2", $rbutton );
$rbutton->set_usize(1,1);
$tooltips->set_tip( $rbutton, "Choose Compression used on the Filesystem.", "" );
$bz2_toggle = $rbutton;
$box2->pack_start( $rbutton, $true, $true, 0);
$rbutton->show();

# Verbosity adjustment
my $adj1 =  Gtk::Adjustment->new( 2.0, 0.0, 2.0, 0.0, 1.0, 0.0 );
my $verbosity_scale =  Gtk::HScale->new($adj1);
$verbosity_scale->set_value_pos("right");
$verbosity_scale->set_digits(0);
$tooltips->set_tip( $verbosity_scale, "Adjust the Verbosity Level.", "" );
$verbosity_scale->show();
# Verbosity Box can be turned on/off here
$adj1->signal_connect( "value_changed", sub {
    $verbosity = $verbosity_scale->get_adjustment->value - 1; 
    verbosity($verbosity);

    if ($verbosity == -1) {
	if ($verbosity_window) {
	    destroy $verbosity_window if visible $verbosity_window;
	}    
    }
    elsif (!$verbosity_window) {
	close(LOGFILE);
	verbosity_box();
	start_logging_output($verbosefn,$verbosity);	
    }

     } );
$box2->pack_start( $verbosity_scale, $false, $false, 0);

#start_logging_output($yard_temp,$verbosity); 

# Size status entry
$entry5 =  Gtk::Entry->new();
$entry5->set_editable( $false );
$tooltips->set_tip( $entry5, "This shows room remaining on the Device.", "" );
$entry5->set_usize(20,20);
$box2->pack_start( $entry5, $true, $true, 0 );
$entry5->show();


my $button_advanced;
###########################
# The ADVANCED BOOT SECTION 
###########################
# Separator
$separator =  Gtk::HSeparator->new();
$box1->pack_start( $separator, $false, $true, 0 );
$separator->show();

# This is cool how this works.
$vbox_advanced =  Gtk::VBox->new($false,0);
$box1->add($vbox_advanced);
$vbox_advanced->show();

# The Advanced Boot Section button
hbox_advanced($vbox_advanced);
$button_advanced = Gtk::Button->new("Advanced Boot Section");
$tooltips->set_tip( $button_advanced, 
                    "Change settings for the Boot Disk Image.", "" );
$button_advanced->signal_connect("clicked",\&advanced_boot_section );
$hbox_advanced->pack_start( $button_advanced, $true, $true, 0 );
$button_advanced->show();

###########################
# The ADVANCED ROOT SECTION 
###########################
$vbox_advanced_root = Gtk::VBox->new($false,0);
$box1->add($vbox_advanced_root);
$vbox_advanced_root->show();

hbox_advanced($vbox_advanced_root);
$button_advanced = Gtk::Button->new("Advanced Root Section");
$tooltips->set_tip( $button_advanced, 
          "Generate a Root Filesystem and/or use a different Root Device.", "" );
$button_advanced->signal_connect("clicked",\&advanced_root_section );
$hbox_advanced->pack_start( $button_advanced, $true, $true, 0 );
$button_advanced->show();
###########################

#############################
# The ADVANCED KERNEL SECTION 
#############################
my $vbox_advanced_kernel = Gtk::VBox->new($false,0);
$box1->add($vbox_advanced_kernel);
$vbox_advanced_kernel->show();

hbox_advanced($vbox_advanced_kernel);
$button_advanced = Gtk::Button->new("Advanced Kernel Section");
$tooltips->set_tip( $button_advanced, 
          "Retrieve/Make Kernel Sources.", "" );
#$button_advanced->signal_connect("clicked",\&advanced_root_section );
$hbox_advanced->pack_start( $button_advanced, $true, $true, 0 );
$button_advanced->show();
#############################



# Separator
$separator = Gtk::HSeparator->new();
$box1->pack_start( $separator, $false, $true, 0 );
$separator->show();

# Status bar
my $align = Gtk::Alignment->new( 0.5, 0.5, 0, 0 );
$box1->pack_start( $align, $false, $false, 5);
$align->show();
$pbar = Gtk::ProgressBar->new();
$pbar->set_usize(321,10); # 321 10
$align->add($pbar);
$pbar->show();

# Separator
$separator = Gtk::HSeparator->new();
$box1->pack_start( $separator, $false, $true, 0 );
$separator->show();

# Submit button
hbox();
my $sbutton = Gtk::Button->new("Submit");
$sbutton->signal_connect( "clicked", \&submit);
$tooltips->set_tip( $sbutton, "Generate the Boot/Root set.", "" );
$sbutton->show();
$box2->pack_start( $sbutton, $true, $true, 0 );
$box2->show();

# Close button
my $cbutton = Gtk::Button->new("Close");
$cbutton->signal_connect("clicked",
                         sub {
                           unlink "$verbosefn", "$tmp/initrd_image", 
			   "$tmp/initrd_image.gz";
			   system "umount $tmp/initrd_mnt > /dev/null 2>&1";
                           rmdir "$tmp/initrd_mnt";
                           rmdir "$tmp";
                           rmdir "$mnt";
                           Gtk->exit(0);
                         });

$tooltips->set_tip( $cbutton, "Exit gBootRoot.", "" );
$cbutton->show();
$box2->pack_start( $cbutton, $true, $true, 0 );
$box2->show();

# Help button
my $hbutton = Gtk::Button->new("Help");
$hbutton->signal_connect( "clicked", sub { create_text("help") });
$tooltips->set_tip( $hbutton, "Help about gBootRoot.", "" );
$hbutton->show();
$box2->pack_start( $hbutton, $true, $true, 0 );
$box2->show();

$window->show();


} # end start

#----------------------------

sub et {
    error_window("gBootRoot is presently being developed with gtk-perl" . 
                 " version $gtk_perl_version.\nYou are using a" .
                 " version of gtk-perl < $gtk_perl_version." .
                 " You may still be able\n" .
                 " to use this program, but you may encounter problems." .
                 " See the FAQ\nfor places to get a newer gtk-perl version." .
                 " \n\nThe most common error reported:\n\"Can't locate" .
                 "  object  method\"");
                 #,"center");
    print "Using a version of gtk-perl < $gtk_perl_version\n";
}

# Basically so different users get the same things in
# their personal directories.
sub symlink_builder {

    my ($oldfile,$newfile) = @_;


    if (!-e $newfile && !-l $newfile) {
	my $error;
	symlink($oldfile,$newfile) or
	    ($error = error("Can not make symlink to $oldfile
                         from $newfile.\n"));
    }

}

sub home_builder {

    my ($home_builder) = @_; 

    if (!-d $home_builder) {
	if (-e $home_builder) {
	    error_window(
	    "gBootRoot: ERROR: A file exists where $home_builder should be");
	}
	else {
	    my @directory_parts = split(m,/,,$home_builder);
	    my $placement = "/";
	    for (1 .. $#directory_parts) {
		$_ == 1 ? ($placement = "/$directory_parts[$_]")
		    : ($placement = $placement . "/" . $directory_parts[$_]);
		-d $placement or err_custom_perl(
		"mkdir $placement","gBootRoot: ERROR: Could not make $home_builder");
	    }
	}
    }

} # end home_builder


# This works on GNU/Linux
sub signal {

   unlink "$verbosefn", "$tmp/initrd_image.gz";
   system "umount $tmp/initrd_mnt > /dev/null 2>&1";
   rmdir "$tmp/initrd_mnt";
   rmdir "$tmp";
   rmdir "$mnt";

   $SIG{INT} = \&signal;
   $SIG{ABRT} = \&signal;
   $SIG{TERM} = \&signal;
   $SIG{QUIT} = \&signal;
   $SIG{KILL} = \&signal;
   

   Gtk->exit(0);
}


sub hbox_advanced {
    $hbox_advanced = Gtk::HBox->new(1,1 );
    $hbox_advanced->border_width( 2 ); # was 10
    $hbox_advanced->set_usize(321, 20);
    $_[0]->pack_start( $hbox_advanced, $false, $false, 0 );
    show $hbox_advanced;
}

sub objcopy_right_click_advanced {

  my ( @data ) = @_;
  my $event = pop( @data );
          
  if ( ( defined( $event->{'type'} ) ) 
      and ( $event->{'type'} eq 'button_press' ) ) {
      if ( $event->{'button'} == 3 ) {
	  if (defined $lib_strip_check) {
	      if ($obj_count == 0) {
		  $tooltips->set_tip( $lib_strip_check, 
				      "This is generally a good idea." .
				      " Press the right mouse button to" .
				      " change from [objcopy --strip-all]" .
				      " to [objcopy --strip-debug].", "" );
		  $obj_count++;
	      }
	      else {
		  $tooltips->set_tip( $lib_strip_check, 
				      "This is generally a good idea." .
				      " Press the right mouse button to" .
				      " change from [objcopy --strip-debug]". 
				      " to [objcopy --strip-all].", "" );
		  $obj_count--;
	      }
          }
      }
  }

} # end obj_right_click_advanced


sub advanced_boot_section {

    if ($button_count == 0) {  
       #$vbox_advanced->set_usize(321,300);
	my $boolean;

       # The table section
       $table_advanced = Gtk::Table->new( 7, 3, $true );
       $vbox_advanced->pack_start( $table_advanced, $true, $true, 0 );
       $table_advanced->show();

       #_______________________________________        
       # lib_strip_check
       #label_advanced("Stripping:",0,1,0,1,$table_advanced);
       !defined $lib_strip_check ? ($boolean = 1) 
         : ($boolean = $lib_strip_check->get_active());
       $lib_strip_check = Gtk::CheckButton->new("Libraries");
       $lib_strip_check->set_active($boolean);
       $lib_strip_check->signal_connect( "button_press_event", 
                                          \&objcopy_right_click_advanced); 
       $tooltips->set_tip( $lib_strip_check, 
                           "This is generally a good idea.  Press the" .
                           " right mouse button to change from" .
                           " [objcopy --strip-debug] to" . 
                           " [objcopy --strip-all].", "" );
       $table_advanced->attach($lib_strip_check,0,1,0,1, 
                               ['expand'],['fill','shrink'],0,0);
       show $lib_strip_check;

       # bin_strip_check
       !defined $bin_strip_check  ? ($boolean = 1) 
         : ($boolean = $bin_strip_check->get_active());
       $bin_strip_check = Gtk::CheckButton->new("Binaries");
       $bin_strip_check->set_active($boolean);
       $tooltips->set_tip( $bin_strip_check, 
                           "This is generally a good idea." .
                           " [objcopy --strip-all]", "" );
       $table_advanced->attach($bin_strip_check,1,2,0,1, 
                               ['expand'],['fill','shrink'],0,0);
       show $bin_strip_check;


       # mod_strip_check
       !defined $mod_strip_check  ? ($boolean = 1) 
         : ($boolean = $mod_strip_check->get_active());
       $mod_strip_check = Gtk::CheckButton->new("Modules");
       $mod_strip_check->set_active($boolean);
       $tooltips->set_tip( $mod_strip_check, 
                           "This is generally a good idea." .
                           " [objcopy --strip-debug]", "" );
       $table_advanced->attach($mod_strip_check,2,3,0,1, 
                               ['expand'],['fill','shrink'],0,0);
       show $mod_strip_check;


       #_______________________________________ 
       # Development Drive
       label_advanced("Devel Device:",0,1,1,2,$table_advanced);
       $ea1 = entry_advanced(1,2,1,2,0,$table_advanced);
       $tooltips->set_tip( $ea1, "If the device used for development" .
                                 " is different than the actual boot" . 
                                 " device, use this field" .
                                 " to indicate that device." .
                                 "  You will have to run" .
                                 " lilo -v -C brlilo.conf -r" .
                                 " \"device mount point\" manually at a" . 
                                 " later time on the actual" . 
                                 " boot device.",
                                 "" ); 
       $ea1->set_text($container[BOOT_DEVICE]) if defined $container[BOOT_DEVICE];

       #_______________________________________ 
       # Optional Device(s)
       label_advanced("Opt. Device(s)",0,1,2,3,$table_advanced);
       $ea2 = entry_advanced(1,3,2,3,1,$table_advanced);
       $tooltips->set_tip( $ea2, "Add devices to the boot disk which are" .
                                 " necessary for the kernel to function" .
                                 " properly.  Put a space between each" .
                                 " device.  For instance, /dev/fb0 for" .
                                 " frame buffer devices.", 
                                    "");
       $ea2->set_text($entry_advanced[1]) if defined $entry_advanced[1];


       #_______________________________________ 
       # Kernel Module(s)
       label_advanced("Kernel Module(s)",0,1,4,5,$table_advanced);
       $ea3 = entry_advanced(1,3,4,5,11,$table_advanced);
       $tooltips->set_tip( $ea3, "Add the modules found in" .
                                 " /lib/modules/kernel-version which are" .
                               	 " necessary for the Boot Method to work" .
                                 " properly.  Kmod inserts the modules," .
                                 " and kmod needs to be built into the" .
			         " kernel along with initrd and ramdisk." ,
                                    "");	
	$ea3->set_text($entry_advanced[11]) if defined $entry_advanced[11];

	#_______________________________________ 
	# Append Options
	label_advanced("append =",0,1,3,4,$table_advanced);
	$ea4 = entry_advanced(1,3,3,4,2,$table_advanced);
	my $append; (undef,undef,$append) = gdkbirdaao();
	$tooltips->set_tip( $ea4, "Add append options to brlilo.conf.", "");
	# this will only show append if real
	if (!defined $entry_advanced[2]) {
		$ea4->set_text($append) if $append;
	}
	else {
	    $ea4->set_text($entry_advanced[2]) if $entry_advanced[2];
	}

       #_______________________________________ 
       # Kernel Version
       label_advanced("Kernel Version:",0,1,5,6,$table_advanced);
       $ea5 = entry_advanced(1,2,5,6,12,$table_advanced);
     
       $tooltips->set_tip( $ea5, "Override the kernel version number found" .
			         " in the kernel header.  This will change" .
                                 " the /lib/modules/kernel-version directory",
                                    "");
       $ea5->set_text($entry_advanced[12]) if defined $entry_advanced[12];


       #_______________________________________ 
       # System.map
       label_advanced("System.map:",0,1,6,7,$table_advanced);
       $ea6 = entry_advanced(1,2,6,7,13,$table_advanced);
       $tooltips->set_tip( $ea6, "When a non-running kernel is chosen it is " .
			         " important to include a copy of that" .
                                 " kernel's System.map file so that depmod" .
			         " can use the correct set of kernel symbols" .
                                 " to resolve kernel references in each" .
                                 " module.  This can be found in the" .
                                 " kernel's source code after compilation.",
                                    "");
       $ea6->set_text($entry_advanced[13]) if defined $entry_advanced[13];
       button_fileselect_advanced(2,3,6,7,"Selection",$ea6,"Selection",16,
                                  $table_advanced,"/lib/modules/");

       $button_count++;
    }
    else {
       destroy $table_advanced;
       $button_count--;
    }

} # end sub advanced_boot_section

sub advanced_root_section {

    if ($button_count_root == 0) {  
	my $boolean; 


       $table_advanced_root = Gtk::Table->new( 9, 3, $true );
       # temp solution?
       #$table_advanced_root->set_row_spacings( 3 );
       $vbox_advanced_root->pack_start( $table_advanced_root, $true, 
                                        $true, 0 );
       #_______________________________________ 
       # Root Device selection
       # $::device  $device already exist
       label_advanced("Root Device:",0,1,0,1,$table_advanced_root);
       # $_[4] shares with advanced_boot_sections @entry_advanced
       $ear1 = entry_advanced(1,2,0,1,3,$table_advanced_root);
	if ($entry_advanced[3]) {
	    $ear1->set_text($entry_advanced[3]);
	}
	else {
	    $ear1->set_text($container[BOOT_DEVICE]);
        }
       $tooltips->set_tip( $ear1, 
                          "Type in the location of the Root Device to use.",
                          "" );
       # $order is important because it is put in $container[$order]
       button_fileselect_advanced(2,3,0,1,"Selection",$ear1,"Selection",12,
                                  $table_advanced_root,"/dev/fd0");

       #_______________________________________ 
       # Root Device Size
       # gBootRoot methods
       label_advanced("Root Device Size:",0,1,1,2,$table_advanced_root);
       $adj2 = Gtk::Adjustment->new( 1440.0, 0.0, 360000000.0, 282.0, 
                                    360.0, 0.0 );
       $spinner_advanced = Gtk::SpinButton->new( $adj2, 0, 0 );
       $table_advanced_root->attach($spinner_advanced,1,2,1,2,
                            ['shrink','fill','expand'],['fill','shrink'],
                            0,0);
       $tooltips->set_tip( $spinner_advanced, 
                           "Choose the Root Device Size.",
                            "" );
       $spinner_advanced->set_wrap( $true );
       $spinner_advanced->set_numeric( $true );
       $spinner_advanced->set_shadow_type( 'in' );
       $spinner_advanced->show();
       $root_device_size = 1440 if !$root_device_size;
       $adj2->signal_connect( "value_changed", sub {
	       $root_device_size = $spinner_advanced->get_value_as_int();});
        # For some reason $container[SIZE] is tranforming into [3] when
        # device selection is changed. & in ABS devel device doesn't keep 
        # state.
	if ($root_device_size) {
	    $spinner_advanced->set_value($root_device_size);
	}
	else {
	    $adj2->set_value($container[SIZE]) if defined $adj2;
	}    


       #_______________________________________ 
       # Root File Name
       # gBootRoot methods
       label_advanced("Root Filename:",0,1,2,3,$table_advanced_root);
       $ear2 = entry_advanced(1,2,2,3,4,$table_advanced_root);
       $ear2->set_text("root_fs") if !$entry_advanced[4];
       $ars->{filename} = "root_fs" if !$entry_advanced[4];
       $ear2->set_text($entry_advanced[4]) if $entry_advanced[4];
       root_filename($ear2);
       $ars->{filename} = $entry_advanced[4] if $entry_advanced[4];
       ars($ars);       
       $tooltips->set_tip( $ear2, "Give the Root Filesystem file a name.", 
                           "" );
	!defined $ear2_save  ? ($boolean = 1) 
	    : ($boolean = $ear2_save->get_active());
	$ear2_save = Gtk::CheckButton->new("save");
	$ear2_save->set_active($boolean);

#                           "Save Root File.  Press right button to change" .
#                           " the Directory the file is saved in.",
       $tooltips->set_tip( $ear2_save, 
                           "Saves the Root Filesystem in your" .
			   " $ENV{HOME}/.gbootroot/root_filesystem" .
                           " directory.",
                           "" );
       $table_advanced_root->attach($ear2_save,2,3,2,3, 
                               ['expand'],['fill','shrink'],0,0);
       show $ear2_save;


       #_______________________________________ 
       # Filesystem Size
       # $::fs_device
       label_advanced("Filesystem Size:",0,1,3,4,$table_advanced_root);
       $adj3 = Gtk::Adjustment->new( 4096.0, 0.0, 1000000000.0, 128.0, 
                                    1024.0, 0.0 );
       $spinner_size = Gtk::SpinButton->new( $adj3, 0, 0 );
       $table_advanced_root->attach($spinner_size,1,2,3,4,
                            ['shrink','fill','expand'],['fill','shrink'],
                            0,0);
       $tooltips->set_tip( $spinner_size, 
                           "Choose the Filesystem Size.",
                            "" );
       $spinner_size->set_wrap( $true );
       $spinner_size->set_numeric( $true );
       $spinner_size->set_shadow_type( 'in' );
       $spinner_size->show();
       $filesystem_size = 4096 if !$filesystem_size;
       $ars->{filesystem_size} = $filesystem_size;
       ars($ars);
       filesystem_size();
       $adj3->signal_connect( "value_changed", sub {
	       $filesystem_size = $spinner_size->get_value_as_int();
	       $ars->{filesystem_size} = $filesystem_size;
	       ars($ars);
	       filesystem_size();
	   });
       $spinner_size->set_value($filesystem_size) if $filesystem_size;

       my $filesystem_box_b = button_advanced(2,3,3,4,"Filesystem Box",$table_advanced_root);
       $filesystem_box_b->signal_connect("clicked",\&file_system);
       $tooltips->set_tip( $filesystem_box_b, "Open Filesystem Box.", "" );


       #_______________________________________ 
       # Compression
       # gBootRoot methods

       my $hbox_between = Gtk::HBox->new(0,1);
       $table_advanced_root->attach($hbox_between,0,3,4,5,
                              ['fill'],
			      ['fill','shrink'],15,0 );
       $hbox_between->show;

       # label
       my $label_compression = Gtk::Label->new( "Compression:" );
       $label_compression->set_justify( "right" );
       $hbox_between->pack_start( $label_compression, $false, $false, 0 );
       $label_compression->show();

       # gz
       $rbutton = Gtk::RadioButton->new( "gz" );
       $tooltips->set_tip( $rbutton, 
                           "Choose Compression used on the Filesystem.", "" );
       $gz_toggle_root = $rbutton;
       $rbutton->set_active( $true );
       $hbox_between->pack_start( $rbutton, $true, $false, 0 );
       $rbutton->show();

       # bz2
       $rbutton = Gtk::RadioButton->new( "bz2", $rbutton );
       $tooltips->set_tip( $rbutton, 
                           "Choose Compression used on the Filesystem.", "" );
       $bz2_toggle_root = $rbutton;
       $hbox_between->pack_start( $rbutton, $true, $false, 0 );
       $rbutton->show();

       # compression off
	!defined $compression_off  ? ($boolean = 1) 
	    : ($boolean = $compression_off->get_active());
       $compression_off = Gtk::CheckButton->new( "off");
       $tooltips->set_tip( $compression_off, 
                           "Turn Compression off.", "" );
       $hbox_between->pack_start( $compression_off, $true, $false, 0 );
       $compression_off->set_active($boolean);
       $compression_off->show();
       
       #_______________________________________ 
       # UML Kernel 
       label_advanced("UML Kernel:",0,1,5,6,$table_advanced_root);
       # $_[4] shares with advanced_boot_sections @entry_advanced
       $ear3 = entry_advanced(1,2,5,6,5,$table_advanced_root);
       !$entry_advanced[5] ? $ear3->set_text("$home_uml_kernel" . "linux") :
	   $ear3->set_text($entry_advanced[5]);
       $tooltips->set_tip( $ear3, 
                          "If you have a User Mode Linux Kernel, type in" .
                          " the Kernel's location," .
                          " and any Kernel options desired afterwards.",
                          "" );
       button_fileselect_advanced(2,3,5,6,"Selection",$ear3,"Selection",13,
				  $table_advanced_root, $home_uml_kernel);

       #_______________________________________ 
       # Method
       label_advanced("Method:",0,1,6,7,$table_advanced_root);
       $ear4 = entry_advanced(1,2,6,7,6,$table_advanced_root);
       $ear4->set_editable($false);
       $tooltips->set_tip( $ear4, 
                           "Choose the Root Filesystem Generation Method.", 
                           "" );

       my $opt_root = Gtk::OptionMenu->new();
       $tooltips->set_tip( $opt_root, 
                           "Choose the Root Filesystem Generation Method.", 
                           "" );
       my $menu_root = Gtk::Menu->new();

       my $yard = Gtk::MenuItem->new("Yard" );

       $menu_root->append( $yard );

       $yard->signal_connect( 'activate', sub { 
			       $ear4->set_text("yard"); 
			       $entry_advanced[6] = $ear4->get_text();
			       opendir(DIR,$template_dir) if -d $template_dir;
			       #@strings = grep { m,\.yard$, } readdir(DIR); 
			       @strings = grep { m,^\w+, } readdir(DIR); 
			       closedir(DIR);
	                 $main::combo->set_popdown_strings( @strings ) if @strings; 
			        } );

       $ear4->set_text($entry_advanced[6]) if $entry_advanced[6];
       if ($yard) {
	   opendir(DIR,$template_dir) if -d $template_dir; 
	   #@strings = grep { m,\.yard$, } readdir(DIR) if $yard;
	   @strings = grep { m,^\w+, } readdir(DIR) if $yard;
	   closedir(DIR)
       }

       $yard->show();

       $opt_root->set_menu( $menu_root );
       $table_advanced_root->attach($opt_root,2,3,6,7, 
                              ['expand','fill'],['fill','shrink'],0,0);
       $opt_root->show();

       #_______________________________________ 
       # Template
       # $::contents_file
       label_advanced("Template:",0,1,7,8,$table_advanced_root);
       $main::combo = Gtk::Combo->new(); 
       $main::combo->entry->set_text($entry_advanced[7]) if $entry_advanced[7];
        #$button_count_root_open = 1 + $button_count_root_open;
        #print $button_count_root_open;
	#if ($button_count_root_open > 1) {
        #   $main::combo->set_popdown_strings( @strings ) 
        #               if $entry_advanced[7] ne ""; 
        #}
       $tooltips->set_tip( Gtk::Combo::entry($main::combo), 
                           "Choose a Template for the Method.", 
                           "" );
       $entry_advanced[7] = $main::combo->entry->get_text(); # nothing selected
       $main::combo->entry->signal_connect("changed", sub {
	   $entry_advanced[7] = $main::combo->entry->get_text(); 
	   $ars->{template} = $entry_advanced[7];
	   ars($ars);	  
      } );
       $table_advanced_root->attach($main::combo,1,3,7,8, 
                               ['expand','fill'],['fill','shrink'],0,0);
       show $main::combo;

       #_______________________________________ 
       # Generate - UML - Accept buttons
       $table_advanced_root->set_row_spacing( 7, 9);       

       # The Generation process is determined by the method chosen.  Yard -
       #  asks the user if they want to modify the template, and/or save a 
       #  new template with modifications (to be added to Template menu).
       my $generate_b = button_advanced(0,1,8,9,"Generate",$table_advanced_root);
       $generate_b->signal_connect("clicked",\&Generate);
       $tooltips->set_tip( $generate_b, "Generate Root Filesystem.", "" );
       
       my $UML_b = button_advanced(1,2,8,9,"UML",$table_advanced_root);

       $UML_b->signal_connect("clicked", \&uml_box);
       $tooltips->set_tip( $UML_b, "Test Filesystem with User Mode Linux.", 
                            "" );

	# UML kernel doesn't look like a normal kernel
	##if (!-d $entry_advanced[5] && -f $entry_advanced[5]) {
        ##$k_error = kernel_version_check($entry_advanced[5]);  
	##return if $k_error && $k_error eq "ERROR";}
        ## else {
	##error_window("Kernel Selection required");
        ##return; }

       # Will check to make sure that Filesystem fits device.
       # Method determines whether or not compression is used.
       my $accept_b = button_advanced(2,3,8,9,"Accept",$table_advanced_root);
       $accept_b->signal_connect("clicked", \&accept_button, $ear2_save); 
       $tooltips->set_tip( $accept_b, "Accept Filesystem.", "" );


       $table_advanced_root->show();
       $button_count_root++;

    }
    else {
       destroy $table_advanced_root;
       $button_count_root--;
    }


} # end sub advanced_root_section

sub uml_box {

    if (not defined $uml_window) {

	$uml_window = Gtk::Window->new("toplevel");
	$uml_window->signal_connect("destroy", \&destroy_window,
	\$uml_window);
	$uml_window->signal_connect("delete_event", \&destroy_window,
				      \$uml_window);
	##$uml_window->set_usize( 500, 95 );  # 450 175 || 500 600
	$uml_window->set_default_size( 525, 165 );  # 525 95 || 450 175 
                                                   # 525 135 || 500 600
	$uml_window->set_policy( $true, $true, $false );
	$uml_window->set_title( "UML Box" );
	$uml_window->border_width(1);    

	my $main_vbox = Gtk::VBox->new( $false, 0 );
	$uml_window->add( $main_vbox );
	$main_vbox->show();

	##my $table_uml = Gtk::Table->new( 4, 3, $true );
	my $table_uml = Gtk::Table->new( 5, 8, $false );
	##$main_vbox->pack_start( $table_uml, $true, $true, 0 );
	$main_vbox->pack_start( $table_uml, $true, $false, 0 );
	$table_uml->show();

	#_______________________________________
	# Xterm and execute options
	label_advanced("Xterm:",0,1,0,1,$table_uml);
	$eab1 = entry_advanced(1,2,0,1,8,$table_uml); # 1,2
	$eab1->set_text($uml_xterm);
       $tooltips->set_tip( $eab1, 
                           "Choose an xterm with " .
			   "its executable option switch.", 
                           "" );


	#_______________________________________
	# UML options
	label_advanced("Options:",0,1,1,2,$table_uml);
        $eab2 = Gtk::Combo->new();
        $table_uml->attach($eab2,1,5,1,2, 
			  ['expand','fill'],['fill','shrink'],0,0); # 1,3
	open(OPTIONS,"$home_uml_kernel/.options");
	my @initial_options = <OPTIONS>;
	close(OPTIONS); chomp @initial_options;
	$eab2->entry->set_text($initial_options[0]);
	$entry_advanced[9] = $eab2->entry->get_text();
	$eab2->set_popdown_strings( @initial_options ) ;
	$eab2->entry->signal_connect("changed", sub {
	    $entry_advanced[9] = $eab2->entry->get_text();
	    open(OPTIONS,">$home_uml_kernel/.options");
	    $entry_advanced[9] =~ s/\n//g;
	    $entry_advanced[9] =~ s/\s+$//g;
	    print OPTIONS "$entry_advanced[9]\n";
	    foreach (@initial_options) {
		if ($_ ne "$entry_advanced[9]") {
		    print OPTIONS "$_\n";
		}
	    }
	    close(OPTIONS);
	} );
       $tooltips->set_tip( Gtk::Combo::entry($eab2), 
                           "Enter uml command-line options.\n" .
			   "The umid value is used by mconsole to " .
			   "recognize which machine is running. " .
                           "Alter value for each Linux virtual " .
                           "machine invocation, and use the " . 
			   "mconsole's switch options to gain " .
			   "control of the new machine.", 
                           "" );
	$eab2->show();


	#_______________________________________
	# mconsole
	label_advanced("mconsole:",2,3,0,1,$table_uml);
	$eab4 = entry_advanced(3,5,0,1,14,$table_uml);
	$tooltips->set_tip( $eab4, 
                           "Pass commands to the mconsole.\n" .
			    "1.  sysrq [0-9|b|e|i|l|m|p|r|s|t|u]  \n" . 
			    "2.  cad   reboot   halt   \n" .
			    "3.  config <dev>=<config>\n4.  remove <dev>\n" .
			    "5.  switch <umid>\n6.  version   help",
                           "" );
	$eab4->signal_connect("activate",
	      sub {
		  if ( $entry_advanced[9] ) {
		      $entry_advanced[9] =~  
			  m,\s*umid=([\w\d-]+)\s*,;
		      $umid = $1 if !$umid;
		      my @command_parts = split(" ", 
						$entry_advanced
						[14]);
		      

 		      # cad
		      if ( $entry_advanced[14] && 
			   $entry_advanced[14] =~ m,cad, ) {
			  for my $co (0 ..  $#command_parts ) {
			      if ( $command_parts[$co] eq 
				   "cad"
				   ) 
			      {
				  sys( 
				       "uml_mconsole " .
				      $umid .
				       " cad");
				  
			      }
			      
			  }
			  
		      }


 		      # help
		      if ( $entry_advanced[14] && 
			   $entry_advanced[14] =~ m,help, ) {
			  for my $co (0 ..  $#command_parts ) {
			      if ( $command_parts[$co] eq 
				   "help"
				   ) 
			      {
				  sys( 
				       "uml_mconsole " .
				      $umid .
				       " help");
				  
			      }
			      
			  }
			  
		      }


		      
		      # version
		      if ( $entry_advanced[14] && 
			   $entry_advanced[14] =~ m,version, ) {
			  for my $co (0 ..  $#command_parts ) {
			      if ( $command_parts[$co] eq 
				   "version"
				   ) 
			      {
				  sys( 
				       "uml_mconsole " .
				      $umid .
				       " version");
				  
			      }
			      
			  }
			  
		      }



		      # reboot
		      if ( $entry_advanced[14] && 
			   $entry_advanced[14] =~ m,reboot, ) {
			  for my $co (0 ..  $#command_parts ) {
			      if ( $command_parts[$co] eq 
				   "reboot"
				   ) 
			      {
				  system
				       "uml_mconsole " .
				      $umid .
				       " reboot&";
				  
			      }
			      
			  }
			  
		      }

		      # halt
		      if ( $entry_advanced[14] && 
			   $entry_advanced[14] =~ m,halt, ) {
			  for my $co (0 ..  $#command_parts ) {
			      if ( $command_parts[$co] eq 
				   "halt"
				   ) 
			      {
				  system
				       "uml_mconsole " .
				      $umid .
				       " halt&";
				  
			      }
			      
			  }
			  
		      }

		      # sysrq
		      if ( $entry_advanced[14] && 
			   $entry_advanced[14] =~ m,sysrq, ) {
			  for my $co (0 ..  $#command_parts ) {
			      if ( $command_parts[$co] eq 
				   "sysrq"
				   ) 
			      {
				  if ( !$command_parts[$co + 1] || 
				       $command_parts[$co + 1] =~
				       m,^[0-9]{1}$ | ^b$ | ^e$ | ^i$ | ^l$ |
				       ^m$ | ^p$ | ^r$ | ^s$ | ^t$ | ^u$,x ) {
				      system
					  "uml_mconsole " . 
					     $umid .
					  " sysrq $command_parts[$co + 1]&";
				  }
				  else {
				      system
					  "uml_mconsole " . 
					     $umid .
					  " sysrq&";
				  }
			  
			      }
			      
			  }
			  
		      }


		      # switch
		      if ( $entry_advanced[14] && 
			   $entry_advanced[14] =~ m,switch, ) {
			  for my $co (0 ..  $#command_parts ) {
			      if ( $command_parts[$co] eq 
				   "switch"
				   ) 
			      {

				  sys(
				      "uml_mconsole " . 
					 $umid .
					  " switch $command_parts[$co + 1]");
			  
				  $umid = $command_parts[$co + 1];
				  #$eab4->changed();
				  
			      }
			      
			  }
			  
		      }


		      # config
		      if ( $entry_advanced[14] && 
			   $entry_advanced[14] =~ m,config, ) {
			  for my $co (0 ..  $#command_parts ) {
			      if ( $command_parts[$co] eq 
				   "config"
				   ) 
			      {
				  system
				      "uml_mconsole " .
					 $umid .
					      " config " .
						  "$command_parts[$co + 1]&";
 
			      }
			      
			  }

		      }
		      

		      # remove
		      if ( $entry_advanced[14] && 
			   $entry_advanced[14] =~ m,remove, ) {
			  for my $co (0 ..  $#command_parts ) {
			      if ( $command_parts[$co] eq 
				   "remove"
				   ) 
			      {
				  system 
				      "uml_mconsole " .
					 $umid .
					      " remove " .
						  "$command_parts[$co + 1]&";
				  
			      }
			      
			  }
			  
		      }
		  }
		  
	      } );


        #_______________________________________
	# Root Filesystem defaults to generated one if found.
	label_advanced("Root_Fs:",0,1,2,3,$table_uml);
	$eab3 = entry_advanced(1,4,2,3,10,$table_uml); # 1,2 & 2,3
	button_fileselect_advanced(4,5,2,3,"Selection",$eab3,"Selection",14,
				   $table_uml,$home_rootfs);
	$eab3->set_text("ubd0=$tmp/$entry_advanced[4]") 
	    if -e "$tmp/$entry_advanced[4]";
	$tooltips->set_tip( $eab3, 
                           "Choose an uncompressed root filesystem." .
			   "Append with ubd?=.",
                           "" );


        #_______________________________________
	# MTD device emulation - mtdram or blkmtd

        # Which?
	my $mtd_label = label_advanced("MTD",0,1,4,5,$table_uml);
        $mtd_label->set_pattern("___");
        my $mtd_check_on;
        if ( $mtd_check ) {
           if ( $mtd_check->get_active() ) {
	        $mtd_check_on = 1;
           }
        }
        $mtd_check = Gtk::CheckButton->new("On or Off");
	$tooltips->set_tip( $mtd_check, 
                           "Turn MTD emulation on or off.",
                           "" );
        $mtd_check->set_active( $true ) if $mtd_check_on;
        $table_uml->attach($mtd_check,1,2,4,5, 
			  ['expand','shrink'],['fill','shrink'],0,0);
        $mtd_check->show();


       my ($mtdram_on, $blkmtd_on);
       if ( $mtd_radio_mtdram ) {
           if ( $mtd_radio_mtdram->get_active() ) {
	        $mtdram_on = 1;
           } 
           else {
	        $blkmtd_on = 1;
           }
        }

        # mtdram
        $mtd_radio = Gtk::RadioButton->new("mtdram");
        $mtd_radio_mtdram = $mtd_radio;
        $mtd_radio->set_active( $true ) if $mtdram_on;
	$tooltips->set_tip( $mtd_radio, 
                           "Use memory to emulate test mtd device.",
                           "" );
        $table_uml->attach($mtd_radio,2,3,4,5, 
			  ['shrink','expand'],['fill','shrink'],0,0);       
        $mtd_radio->show();

        # blkmtd
        $mtd_radio = Gtk::RadioButton->new("blkmtd", $mtd_radio);
        $mtd_radio_blkmtd = $mtd_radio;
        $mtd_radio->set_active( $true ) if $blkmtd_on;
	$tooltips->set_tip( $mtd_radio, 
                           "Use block device to emulate test mtd device.",
                           "" );
        $table_uml->attach($mtd_radio,3,4,4,5, 
			  ['shrink','expand'],['fill','shrink'],0,0);   
        $mtd_radio->show();


        # fs_type - users can define their own, but this won't be remembered.
        $mtd_fs_type_combo = Gtk::Combo->new();
	$tooltips->set_tip( Gtk::Combo::entry($mtd_fs_type_combo), 
                           "Choose filesystem type used by root filesystem.",
                           "" );
        $table_uml->attach($mtd_fs_type_combo,4,5,4,5, 
			  ['shrink','expand','fill'],['fill','shrink'],20,0);
        if ( !$mtd_fs_type ) {
            @fs_types = qw(jffs2 jffs ext2 ext3 minix cramfs romfs reiserfs);
            $mtd_fs_type_combo->entry->set_text( $fs_types[0] );
            $mtd_fs_type_combo->set_popdown_strings( @fs_types );
        }
        else {
            $mtd_fs_type_combo->entry->set_text( $mtd_fs_type );
            $mtd_fs_type_combo->set_popdown_strings( @fs_types );
        }
        $mtd_fs_type_combo->entry->signal_connect("changed", sub {
	            $mtd_fs_type = $mtd_fs_type_combo->entry->get_text();
		    if ( $mtd_fs_type =~ /$fs_types[0]/ || 
			 $fs_types[0] =~ /$mtd_fs_type/ ) {
			shift(@fs_types);
		    } 
		    unshift(@fs_types,$mtd_fs_type);
	} );
        $mtd_fs_type_combo->set_usize(20,0);
        $mtd_fs_type_combo->show();

	my $mtd_emul = label_advanced("Emulator",0,1,5,6,$table_uml);
        $mtd_emul->set_pattern("________");

        # total size
        label_advanced("total size:",1,2,5,6,$table_uml);
        my $mtd_adj = Gtk::Adjustment->new( 8192.0, 0.0, 1000000000.0, 128.0, 
                                    1024.0, 0.0 );
        $mtd_size = Gtk::SpinButton->new( $mtd_adj, 0, 0 );
        $table_uml->attach($mtd_size,2,3,5,6,
                            ['shrink','fill','expand'],['fill','shrink'],
                            0,0);
        $tooltips->set_tip( $mtd_size, 
                           "Choose the total size for the mtd device.",
                            "" );
        $mtd_size->set_wrap( $true );
        $mtd_size->set_numeric( $true );
        $mtd_size->set_shadow_type( 'in' );
        $mtd_size->show();
        # Watch size if an actual file on open
        if ( -f  "$tmp/$entry_advanced[4]" ) {
               my $stat_size =  (stat("$tmp/$entry_advanced[4]"))[12]/2; 
	       my $blocks  = ($stat_size + ( $stat_size * 0.30 ))/1024;
	       $blocks = sprintf("%.f",$blocks);
	       $mtd_total_size = $blocks * 1024;
	}
        $eab3->signal_connect( "changed", sub {
	   my $root_fs = (split(/ubd0=/,$entry_advanced[10]))[1];
	   if ( -f  $root_fs ) {
	       my $stat_size =  (stat("$root_fs"))[12]/2; 
	       my $blocks  = ($stat_size + ( $stat_size * 0.30 ))/1024;
	       $blocks = sprintf("%.f",$blocks);
	       $mtd_total_size = $blocks * 1024;
	   }
	   if ( $mtd_size ) {
	       $mtd_size->set_value($mtd_total_size) if $mtd_total_size;
	   }
        });
        $mtd_adj->signal_connect( "value_changed", sub {
	       $mtd_total_size = $mtd_size->get_value_as_int();
	   });
        $mtd_size->set_value($mtd_total_size) if $mtd_total_size;


        # erasure size $entry_advanced[15]
	label_advanced("erasure size:",3,4,5,6,$table_uml);
	my $mtd_erasure = entry_advanced(4,5,5,6,15,$table_uml);
        $mtd_erasure->set_text( $entry_advanced[15] ) if $entry_advanced[15];
        $tooltips->set_tip( $mtd_erasure, 
                           "Choose the erasure size for the mtd device.",
                            "" );


        #----------------------------------
        # Separators
        my $mtd_separator1 =  Gtk::HSeparator->new();
        $table_uml->attach($mtd_separator1,0,5,3,4,
                            ['shrink','fill','expand'],['fill','shrink'],
                            0,5);
        $mtd_separator1->show();
        

        my $mtd_separator2 =  Gtk::HSeparator->new();
        $table_uml->attach($mtd_separator2,0,5,6,7,
                            ['shrink','fill','expand'],['fill','shrink'],
                            0,5);
        $mtd_separator2->show();


        $table_uml->set_row_spacing( 6, 8);       


	#_______________________________________
	# Submit Button
        my $submit_b = button_advanced(0,1,7,8,"Submit",$table_uml);
	$tooltips->set_tip( $submit_b, 
                           "Start uml kernel processes.",
                           "" );
        $submit_b->signal_connect("clicked",
                                  sub {  
				      # UML kernel = $entry_advanced[5]
				      # xterm -e linux ubd#=root_fs 
                                      # root=/dev/ubd# 
				      open(OPTIONS,"$home_uml_kernel/.options");
				      @initial_options = <OPTIONS>;
				      close(OPTIONS); chomp @initial_options;
				      $eab2->set_popdown_strings( @initial_options ) ;

				      my $pid; 
				      if ($entry_advanced[8] && 
					  $entry_advanced[10]) {

					  # Check to see if it actually exists
					  my $executable = 
					      (split(/\s+/,$entry_advanced[8]))[0];
					  if (!find_file_in_path(basename($executable))) {
					      error_window("gBootRoot Error: " .
					      "Enter a valid xterm, and " .
					      "executable option.");
					      return;
					  }
					  if ($executable =~ m,/,) {
					      if (! -e $executable) {
						  error_window("gBootRoot Error: " .
							       "Enter a valid path for the xterm.");
						  return;
					      }
				          }
					  
					  # MTD?
					  #########
					  if ( $mtd_check->get_active() ) {

					      # Everything becomes an option for Initrd to parse
					      # and is put on the options[9] line

					      my ($initrd, $ram, $mem, $root, $ramdisk_size);

					      for ( $entry_advanced[10],$entry_advanced[9] ) {


						  # Check for the existence of root=/dev/ram0
						  if ( m,root=/dev/ram, ) {
						      $ram = 1;
						  }

						  # Check for the existence of root=/dev/ram0
						  if ( m,ramdisk_size=, ) {
						      $ramdisk_size = 1;
						  }

						  # Check for the existence of root=
						  if ( m,root=, ) {
						      $root = 1;
						  }
						  
						  # Check for the existence of initrd=
						  if ( m,initrd=, ) {
						      m,(initrd=[/\d\w-]+),;
						      $initrd = $1;
						  }

						  if ( $mtd_radio_mtdram->get_active() ) {

						      # Check for the existence mem=
						      if ( m,mem=, ) {
							  $mem = 1;
						      }

						  }

					      }

					      my ($total_size, $fs_type, $erasure_size);
						  
					      # total size
					      $total_size = $mtd_size->get_value_as_int();

					      # what type of fs.
					      $fs_type = $mtd_fs_type_combo->entry->get_text();

					      # Pass on erasure size if it exists
					      if ( $entry_advanced[15] ) {
						  $erasure_size = $entry_advanced[15]
					      }

					      # Set a ram block if necessary
					      if ( !$ram ) {
						  for ( $entry_advanced[10],$entry_advanced[9] ) {
						      if ( m,root=, ) {
							  s,(root=[/\d\w-]+),root=/dev/ram0,;
						      }
						  }
					      }
					      if ( !$root ) {						  
						  $entry_advanced[9] = "root=/dev/ram0 " . $entry_advanced[9];
					      }
					      
					      
					      # Decide what to do with initrd
					      if ( !$initrd ) {
						  
						  $initrd = "initrd=Initrd";
						  
					      }
					      else {						  
						  undef $initrd;
					      }



					      # Will use this format 
					      # initrd=Initrd mem=? mtd=type,fs_type,size,erasure

					      # Tell initrd whether it is mtdram or blkmtd, and 
					      if ( $mtd_radio_mtdram->get_active() ) {
						  
						  # ramdisk_size
						  if ( !$ramdisk_size ) {
						      $ramdisk_size = "ramdisk_size=$total_size";
						  }
						  else {
						      undef $ramdisk_size;
						  }

						  # Memory needs to be figure out in 8192K blocks
						  # otherwise it fails, and it needs to be at least 16384 
						  # for uml.

						  # mem
						  my $mem_size;
						  if ( $total_size < 16384 ) {
						      $mem_size = 16384;
						  }
						  else {
						      $mem_size = 8192 * ceil($mtd_total_size / 8192);
						  }
						  
						  if ( !$mem ) {
						      $mem = "mem=$mem_size" . "K";
						  }
						  else {
						      undef $mem;
						  }

						      $entry_advanced[9] = "$initrd $mem $ramdisk_size " .
							  "mtd=mtdram,$fs_type,$total_size,$erasure_size " .
							      $entry_advanced[9]; 

					      }

					      # blkmtd
					      else {

						  $entry_advanced[9] = "$initrd " .
						      "mtd=blkmtd,$fs_type,$total_size,$erasure_size " .
							  $entry_advanced[9]; 

					      }

					      #info(0,"$entry_advanced[9]\n$entry_advanced[10]\n");

					  } # mtd preparations
					  #############


					  unless ($pid = fork) {
					      unless (fork) {
						  if ($pid == 0) {
						      sys("$entry_advanced[8] $entry_advanced[5] $entry_advanced[9] $entry_advanced[10]");
						      Gtk->_exit($pid);
						  }
						  
					      }
					  
					  }
					  waitpid($pid,0);
					  
				      }
				      else {


					  # MTD .. testing location

					  if (!$entry_advanced[8]) {
					      error_window("gBootRoot Error: " .
							   "Enter an xterm, and executable " .
							   "option.");
					      return;
					  }
					  if (!$entry_advanced[10]) {
					      error_window("gBootRoot Error: " .
							   "Enter the ubd?=Root_Filesystem " .
							   "and its location.");
					      return;
					  }

				      }
				      
				  } );


        #_______________________________________
        # Abort Button
        # This is the hard kill when all else fails, it also cleans up
        # lingering processess, but is considered a last resort, and
        # can be dangerous, it has even taken down a WM.
        my $abort_b = button_advanced(3,4,7,8,"Abort",$table_uml);
	$tooltips->set_tip( $abort_b, 
                           "Abort uml kernel processes." .
                           "This serves three purposes:\n" .
                           "1.  Your creation doesn't boot.\n" .
                           "2.  Your creation does work and" . 
			   " you use something like" . 
                           " `shutdown -h now`.  When you are all done use" .
                           " Abort because it provides an excellent" .
                           " way to kill any ghost processes.\n" .
                           "3.  Your creation gets weird, and you need to " .
                           "Abort its processes to shut it down. ",
                           "" );
	$abort_b->signal_connect("clicked",
				 sub {
				     if ($entry_advanced[10]) {
				     # Most stuff
				     remove_matching_process($entry_advanced[10]);
				     # Debian
				     remove_matching_process("Virtual Console");
				     # Good to remove uml_\w*
				     remove_matching_process('uml_\w*');
				     # Again for good measure :)
				     remove_matching_process($entry_advanced[10]);
				     }
				 } );


	#_______________________________________
	# Reboot Button - mconsole
	my $reboot_b = button_advanced(1,2,7,8,"Reboot",$table_uml);
	$tooltips->set_tip( $reboot_b, 
                           "Passes the reboot command to the mconsole.",
                           "" );
	$reboot_b->signal_connect("clicked",
				 sub {
				     # use first one found
				     $entry_advanced[9] =~  
					 m,\s*umid=([\w\d-]+)\s*,; 
				     $umid = $1 if !$umid;
				     system 
					 "uml_mconsole $umid" .
					     " reboot&"; 
				 } );


	#_______________________________________
	# Halt Button - mconsole
	my $halt_b = button_advanced(2,3,7,8,"Halt",$table_uml);
	$tooltips->set_tip( $halt_b, 
                           "Passes the halt command to the mconsole. " .
                           "If this fails use the Abort button.",
                           "" );
	$halt_b->signal_connect("clicked",
				 sub {
				     # use first one found
				     $entry_advanced[9] =~  
					 m,\s*umid=([\w\d-]+)\s*,; 
				     $umid = $1 if !$umid;
					 system 
					     "uml_mconsole $umid" .
						 " halt&"; 
				 } );

	#_______________________________________
	# Cancel button also kills UML kernel if still open
	my $cancel_b = button_advanced(4,5,7,8,"Close",$table_uml);
	$tooltips->set_tip( $cancel_b, 
                           "Close uml box.",
                           "" );
	$cancel_b->signal_connect("clicked",
				 sub {
				     $uml_window->destroy() if $uml_window;
				 } );

   }
   if (!visible $uml_window) {
       $uml_window->show();
   } else {
       $uml_window->destroy;
   }

}  # sub uml_box

# Someday .. like today .. this will be switched to using mconsole as the 
# first means of cleaning processes:
# uml_mconsole /tmp/uml/debian/mconsole (reboot|halt)
sub remove_matching_process {

    my ($match_word) = @_;

    # Just an overkill
    if ($match_word =~ m,/,) {
	$match_word =~ s,/,\\/,g;
    }

    my $ps = "ps auxw|";
    open(P,"$ps");
    while(<P>) {
	# friendly approach
	if (m,$match_word,) {
	    my $process = (split(/\s+/,$_,))[1];
	    system "kill $process";
	    # not so friendly approach
	    system "kill -9 $process";
	}
    }
    close(P);

} # end remove_matching_process

sub accept_button { 

    my ($widget,$ear2_save) = @_;

    my($tool,$value);
    if (-e "$tmp/$entry_advanced[4]" ) {
	if (!$compression_off->active) {
	    if ($gz_toggle_root->active) {
		$compress = "gzip";
		open(F,"file $tmp/$entry_advanced[4] |"); 
		while (<F>) {
		    if (/gzip/) {
			info(0, "Already gzip compressed.\n");
		    }
		    elsif (/bzip2/) {
			info(0, "Already bzip2 compressed.\n");
		    }
		    else {


			info(0,"Compressing $entry_advanced[4] with $compress\n");
			system "$compress -c9 $tmp/$entry_advanced[4] > $tmp/$entry_advanced[4].gz&";


			$, = "";
			my @ps_check = `ps w -C $compress 2> /dev/null`;
			$, = "\n";

			my @pids;
			foreach my $line ( @ps_check ) {
			    if ( $line =~ 
				 m,$compress -c $tmp/$entry_advanced[4]$, ) {

				my $pid = (split(" ",$line))[0];
				push(@pids,$pid);
			    }

			}

			foreach my $pid ( @pids ) {
			    do {
				while (Gtk->events_pending) 
				{ Gtk->main_iteration; }
			    } while -d "/proc/$pid"; 
			}

			info(0,"Done compressing $entry_advanced[4] with $compress\n");
			
			# Actually, keeping the original value is much nicer.
                        #$entry_advanced[4] = "$entry_advanced[4].gz";
                        $entry3->set_text("$tmp/$entry_advanced[4].gz");
			
		    }
		}
		close(F);
		if ($ear2_save->active) {
		    if (-f "$home_rootfs/$entry_advanced[4]") {
			save_as($entry_advanced[4]);
		    }
		    else {
			return if errcp(sys("cp -a $tmp/$entry_advanced[4] $home_rootfs")) == 2;
		    }
		}
		else {
		    $ear2->set_text("$entry_advanced[4]");
		}
	    }
	    elsif ($bz2_toggle_root->active) {
		$compress = "bzip2";
		open(F,"file $tmp/$entry_advanced[4] |"); 
		while (<F>) {
		    if (/gzip/) {
			info(0, "Already gzip compressed.\n");
		    }
		    elsif (/bzip2/) {
			info(0, "Already bzip2 compressed.\n");
		    }
		    else {
    
			info(0,"Compressing $entry_advanced[4] with $compress\n");


			system "$compress -c $tmp/$entry_advanced[4] > $tmp/$entry_advanced[4].bz2&";

			$, = "";
			my @ps_check = `ps w -C $compress 2> /dev/null`;
			$, = "\n";

			my @pids;
			foreach my $line ( @ps_check ) {
			    if ( $line =~ 
				 m,$compress -c $tmp/$entry_advanced[4]$, ) {

				my $pid = (split(" ",$line))[0];
				push(@pids,$pid);
			    }

			}

			foreach my $pid ( @pids ) {
			    do {
				while (Gtk->events_pending) 
				{ Gtk->main_iteration; }
			    } while -d "/proc/$pid"; 
			}

			info(0,"Done compressing $entry_advanced[4] with $compress\n");



			# Actually, keeping the original value is much nicer.
                        #$entry_advanced[4] = "$entry_advanced[4].bz2";
                        $entry3->set_text("$tmp/$entry_advanced[4].bz2");

		    }
		}
		close(F);
		if ($ear2_save->active) {
		    if (-f "$home_rootfs/$entry_advanced[4]") {
			save_as($entry_advanced[4]);
		    }
		    else {
			return if errcp(sys("cp -a $tmp/$entry_advanced[4] $home_rootfs")) == 2;
		    }
		}
		else {
		    $ear2->set_text("$entry_advanced[4]");
		}
	    }
	}
	else {  # off
	    $entry3->set_text("$tmp/$entry_advanced[4]");
	    if ($ear2_save->active) {
		if (-f "$home_rootfs/$entry_advanced[4]") {
		    save_as($entry_advanced[4]);
		}
		else {
		    return if errcp(sys("cp -a $tmp/$entry_advanced[4] $home_rootfs")) == 2;
		}
	    }
	}
    }
    else {
	error("$entry_advanced[4] doesn't exist; create it first.\n");
    }

} # end accept_button

my ($save_as);
sub save_as {

# Will just use a dialog box.

    my ($template) = @_;
    #my ($button);

    if (not defined $save_as) {
    $save_as = Gtk::Dialog->new();
    $save_as->signal_connect("destroy", \&destroy_window, \$save_as);
    $save_as->signal_connect("delete_event", \&destroy_window, \$save_as);
    $save_as->signal_connect("key_press_event", sub {
	my $event = pop @_; 
	if ($event->{'keyval'}) {
	    if ($event->{'keyval'} == 65307) {
		$save_as->destroy;
	    }
	}
    },
			     );
    $save_as->set_title("Save As");
    $save_as->border_width(12);
    $save_as->set_position('center');

    # If compression was on we will use that compression
    if (!$compression_off->active) {
	if ( $gz_toggle_root->active ) {
	    $template  = "$template.gz";
	}
	elsif ( $bz2_toggle_root->active ) {
	    $template  = "$template.bz2";
	}

    }


    my $new_template = $template;
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
    $label->set_text("$template already exists, " . 
	    	      "do\nyou want to write over it, " .
		      "or\nsave $new_template with a different name?");
    $save_as->vbox->pack_start( $label, $false, $false, 2 );
    $label->show();
 
    my $button = Gtk::Button->new("OK");
    my $event_count = 0;
    my $new_template_tmp = "nothing";
    $button->signal_connect("clicked", sub {

	$entry_advanced[4] = $new_template;
	$ars->{filename} = $new_template;
	ars($ars);       

	# This is a renaming deal and this time doesn't exist in the archive
        # or $tmp.
	if (!-f "$home_rootfs/$new_template") {
	    if ($template ne $new_template) {
		return if err_custom("mv $tmp/$template $tmp/$new_template",
		"gBootRoot: ERROR: Could not rename $template to " .
				     "$new_template") == 2;
	    }

	    return if errcp(sys("cp -a $tmp/$new_template $home_rootfs")) == 2;
	    $ear2->set_text($new_template);
	    $entry3->set_text("$tmp/$new_template");
	    $save_as->destroy;
	}

	# This is a write-over situation .. exists in $tmp and archive
	elsif (-e "$tmp/$new_template" && -f "$tmp/$new_template" 
	       && -f "$home_rootfs/$new_template" )  {
	    return if errcp(sys("cp -a $tmp/$new_template $home_rootfs")) == 2;
	    $ear2->set_text($new_template);
	    $entry3->set_text("$tmp/$new_template");
	    $save_as->destroy;
	}

	# Here the file trying to be renamed already exists in the archive
	# but doesn't exist in $tmp
	else {

	    $label->set_text("$new_template already exists, " . 
			     "do\nyou want to write over it, " .
			     "or\nsave $template with a different name?");

	    $event_count++;
	    my $event = pop(@_);

	    if ($new_template eq $new_template_tmp) {
	    if ($event_count >= 2 && $event && $event eq "clicked") {
		if ("$tmp/$template" ne "$tmp/$new_template") {
		return if err_custom("mv $tmp/$template $tmp/$new_template",
		    "gBootRoot: ERROR: Could not rename $template to " .
				     "$new_template") == 2;
	        }

		return if errcp(sys("cp -a $tmp/$new_template $home_rootfs"))
		    == 2;
		$event_count = 0;
		$ear2->set_text($new_template);
		$entry3->set_text("$tmp/$new_template");
		$save_as->destroy;
	    }	    
	    }
	    $new_template_tmp = $new_template;
	}
    },"clicked");
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
     }

} # end sub save_as

# Coming - .config storage, auto-matic kernel locus, all stages 
# /usr/src/linux*  Possible integration with other Projects .. modules
# will be in the logical place.  Before ABS.
sub advanced_kernel_section {


} # end sub advanced_kernel_section

# Stuff univeral for all root filesystem methods
# Compression, UML Kernel, and Method only need to be known by the Dock.


sub Generate {

    # @entry_advanced
    # 0 = Development Drive
    # 1 = Optional Devices
    # 2 = Append Options
    #------------------
    # 3 = Root Device
    # 4 = Root Filename
    # 5 = UML Kernel
    my $method = $entry_advanced[6];         # 6 = Method
    # 7 = Template
    # 8 = UML xterm
    # 9 = UML options
    # 10 = UML root_fs
    #------------------
    # 11 = Kernel Modules  .. from the Boot Method
    # 12 = Kernel Version  .. from the Boot Method
    # 13 = System.map      .. from the Boot Method
    # 14 = mcosole         .. from the UML Box
    # 15 = erasure size    .. from the UML Box

    # $root_device_size;
    # $filesystem_size;

    # File select: function order: non-table = button->fileselect->file_ok_sel
    #              table = button_fileselect_advanced->fileselect->file_ok_sel

    $ars->{device}         = $entry_advanced[3];
    $ars->{device_size}    = $root_device_size;
    $ars->{tmp}            = $tmp;
    $ars->{mnt}            = $mnt;
    $ars->{template_dir}   = $template_dir; # static right now.
    ars($ars);


    my $template = $ars->{template};
    my $root_device = $ars->{device};
    my $root_filename = $ars->{filename};

    if (!$root_device || $root_device eq "") {
	error_window("gBootRoot: ERROR: Root Device not defined");	
	return;
    }
    # devfs may change this .. it did, this is silly.
##    if (!-b $root_device) {
##	error_window("gBootRoot: ERROR: Not a valid Block Device");	
##	return;
##    }    

    if (!$root_filename || $root_filename eq "") {
	error_window("gBootRoot: ERROR: Root Filename not given");	
	return;
    } 
    if (!$method || $method eq "") {
	error_window("gBootRoot: ERROR: Method must be supplied");	
	return;
    }
    if (!$template || $template eq "") {
	error_window("gBootRoot: ERROR: Template name not given");	
	return;
    }


    if ($method eq "yard") {
	if (!$main::yard_window) {
	    ##$ars->{kernel} = "" if !$entry2->get_text();
	    ##ars($ars);
	    yard();
        }
    }


} # end sub Generate

sub button_advanced {

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

sub button_fileselect_advanced {

    # cretzu should like this
    # $order does matter because it fills in $container[$order].
    my ($left_attach,$right_attach,$top_attach,$bottom_attach,$text,$ent,
        $name,$order,$widget,$device) = @_;

    my $button = Gtk::Button->new($text);
    $widget->attach($button,$left_attach,$right_attach,
		    $top_attach,$bottom_attach, 
		    ['shrink','fill','expand'],['fill','shrink'],2,2);

    # example
    if ($order == 12) {
      $tooltips->set_tip( $button, "Select the Root Device.", "" );
    }
    elsif ($order == 13) {
      $tooltips->set_tip( $button, "Select the UML Kernel.", "" );
    }
    elsif ($order == 14) {
      $tooltips->set_tip( $button, "Select the Root Filesystem.", "" );
    }
    elsif ($order == 16) {
      $tooltips->set_tip( $button, "Select the System.map.", "" );	
    }


    $button->signal_connect( "clicked",\&fileselect,$ent,$name,$order,$device);
    $button->show();


} # end sub button_fileselect_advanced


sub entry_advanced {

    my $numa = $_[4];
    my $entry_advanced = Gtk::Entry->new();
    $entry_advanced->set_editable( $true );

    if ( $numa != 14 ) {

	$entry_advanced->signal_connect( "changed", sub {
	    $entry_advanced[$numa] = $entry_advanced->get_text();
	    if ($numa == 4) {
		$ars->{filename} = $entry_advanced[$numa];
		ars($ars);
	    }
	    if ( $numa == 12 ) {
		$ars->{kernel_version_choice} = $entry_advanced[$numa];
		ars($ars);	    
		ars2($ars);
	    }
	} );

    }
    else {

	$entry_advanced->signal_connect( "activate", sub {
	    $entry_advanced[$numa] = $entry_advanced->get_text();
	} );

    }

    $entry_advanced->set_usize(100,20);
    $_[5]->attach($entry_advanced,$_[0],$_[1],$_[2],$_[3], 
                            ['shrink','fill','expand'],['fill','shrink'],0,0);
    show $entry_advanced;
    return $entry_advanced;

}

sub separator_advanced {

    $separator_advanced = Gtk::HSeparator->new();
    $_[0]->pack_start( $separator_advanced, $false, $true, 0 );
    $separator_advanced->show();

}

sub label_advanced {

    my($text) = @_;

    $label_advanced = Gtk::Label->new( $text );
    $label_advanced->set_justify( "fill" );
    $_[5]->attach($label_advanced,$_[1],$_[2],$_[3],$_[4], ['expand'],['fill','shrink'],0,0);
    $label_advanced->show();
    return $label_advanced;

}

# I created two of these, one for help (eventually there may be a different
# approach), and one for verbosity.  I am sure there is a better OO way to
# do it, though.
sub create_text {

      if (not defined $text_window) {
       $text_window = Gtk::Window->new("toplevel");
       $text_window->signal_connect("destroy", \&destroy_window,
                                    \$text_window);
       $text_window->signal_connect("delete_event", \&destroy_window,
                                    \$text_window);
       $text_window->set_title("Help");
       $text_window->set_usize( 500, 600 );
       $text_window->set_policy( $true, $true, $false );
       $text_window->set_title( "gBootRoot Help" );
       $text_window->border_width(0);

       my $main_vbox = Gtk::VBox->new( $false, 0 );
       $text_window->add( $main_vbox );
       $main_vbox->show();

       my $vbox = Gtk::VBox->new( $false, 10 );
       $vbox->border_width( 10 );
       $main_vbox->pack_start( $vbox, $true, $true, 0 );
       $vbox->show();

       my $table = Gtk::Table->new( 2, 2, $false );
       $table->set_row_spacing( 0, 2 );
       $table->set_col_spacing( 0, 2 );
       $vbox->pack_start( $table, $true, $true, 0 );
       $table->show( );

       # Create the GtkText widget
       my $text = Gtk::Text->new( undef, undef );
       $text->set_editable($false);
       $table->attach( $text, 0, 1, 0, 1,
                       [ 'expand', 'shrink', 'fill' ],
                       [ 'expand', 'shrink', 'fill' ],
                       0, 0 );
       $text->grab_focus();
       $text->show();

       # Add a vertical scrollbar to the GtkText widget
       my $vscrollbar = Gtk::VScrollbar->new( $text->vadj );
       $table->attach( $vscrollbar, 1, 2, 0, 1, 'fill',
                       [ 'expand', 'shrink', 'fill' ], 0, 0 );
       #my $logadj = $vscrollbar->get_adjustment();
       #logadj($logadj);
       #$vscrollbar->show();

       $text->freeze();
       $text->insert( undef, undef, undef, help() );
       $text->thaw();

       my $separator = Gtk::HSeparator->new();
       $main_vbox->pack_start( $separator, $false, $true, 0 );
       $separator->show();

       $vbox = Gtk::VBox->new( $false, 10 );
       $vbox->border_width( 10 );
       $main_vbox->pack_start( $vbox, $false, $true, 0 );
       $vbox->show();

       my $button = Gtk::Button->new( "Close" );
       $button->signal_connect( 'clicked', sub { destroy $text_window; } );
       $vbox->pack_start( $button, $true, $true, 0 );
       $button->can_default( $true );
       $button->grab_default();
       $button->show();
       }
       if (!visible $text_window) {
                show $text_window;
       } else {
                destroy $text_window;
       }

} # end sub create_text

# This monster needs different behavior than create_text.
sub verbosity_box {

    
       $verbosity_window = Gtk::Window->new("toplevel");
       $verbosity_window->signal_connect("destroy", \&destroy_window,
                                    \$verbosity_window);
       $verbosity_window->signal_connect("delete_event", \&destroy_window,
                                    \$verbosity_window);
       $verbosity_window->set_usize( 450, 175 );  # 500 600
       $verbosity_window->set_policy( $true, $true, $false );
       $verbosity_window->set_title( "Verbosity Box" );
       $verbosity_window->border_width(0);

       my $main_vbox = Gtk::VBox->new( $false, 0 );
       $verbosity_window->add( $main_vbox );
       $main_vbox->show();

       my $vbox = Gtk::VBox->new( $false, 10 );
       $vbox->border_width( 10 );
       $main_vbox->pack_start( $vbox, $true, $true, 0 );
       $vbox->show();

       my $table = Gtk::Table->new( 2, 2, $false );
       $table->set_row_spacing( 0, 2 );
       $table->set_col_spacing( 0, 2 );
       $vbox->pack_start( $table, $true, $true, 0 );
       $table->show( );

       # Create the GtkText widget
       my $text = Gtk::Text->new( undef, undef );
       $text->set_editable($false);
       $table->attach( $text, 0, 1, 0, 1,
                       [ 'expand', 'shrink', 'fill' ],
                       [ 'expand', 'shrink', 'fill' ],
                       0, 0 );
       $text->grab_focus();
       $text->show();
       my $red  = Gtk::Gdk::Color->parse_color("red");
       my $blue  = Gtk::Gdk::Color->parse_color("blue");
       text_insert($text,$red,$blue); # yard thing

       # Add a vertical scrollbar to the GtkText widget
       my $vscrollbar = Gtk::VScrollbar->new( $text->vadj );
       $table->attach( $vscrollbar, 1, 2, 0, 1, 'fill',
                       [ 'expand', 'shrink', 'fill' ], 0, 0 );
       my $logadj = $vscrollbar->get_adjustment();
       logadj($logadj);
       $vscrollbar->show();

       my $separator = Gtk::HSeparator->new();
       $main_vbox->pack_start( $separator, $false, $true, 0 );
       $separator->show();

       $vbox = Gtk::VBox->new( $false, 10 );
       $vbox->border_width( 10 );
       $main_vbox->pack_start( $vbox, $false, $true, 0 );
       $vbox->show();

       #my $button = Gtk::Button->new( "Close" );
       #$button->signal_connect( 'clicked', 
       #				sub { destroy $verbosity_window; } );
       #$vbox->pack_start( $button, $true, $true, 0 );
       #$button->can_default( $true );
       #$button->grab_default();
       #$button->show();

       show $verbosity_window;

} # end sub verbosity_box

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


# Get the selected filename and print it to the text widget
sub file_ok_sel {

    my( $widget, $file_selection,$entry,$order) = @_;
    my $file = $file_selection->get_filename();
    if ($order != 14) {
	$entry->set_text($file);
    }
    else {
	$entry->set_text("ubd0=$file");
    }
    $container[$order] = $file;
    if ($order == 1) {
	$ars->{kernel} = $container[$order];
	ars($ars);
	ars2($ars);
    }

    # auto-detect compression if system has file
    if ($container[ROOT_FS]) {
        my $file = sys("which file > /dev/null 2>&1");
        if ($file == 0) {
           open(F,"file $container[ROOT_FS] |"); # no error check 
	                                                   # here
             while (<F>) {
                if (/gzip/) {
                  $gz_toggle->set_active( $true );
                }
                elsif (/bzip2/) {
                  $bz2_toggle->set_active( $true );
                }
		else {
		    info(0, "Neither gz or bz2 compression found\n");
		}
             }
	   close(F);
        }
    }

    destroy $file_dialog;

}

sub hbox {
    my $homogeneous;
    defined $_[0] ? ($homogeneous = 0) : ($homogeneous = 1);
    $box2 = Gtk::HBox->new( $homogeneous, 5 );
    $box2->border_width( 2 ); # was 10
    $box1->pack_start( $box2, $true, $true, 0 );
    #$box1->pack_start( $box2, $false, $true, 0 );
    $box2->show();
}

sub label {

    my($text) = @_;

    $label = Gtk::Label->new( $text );
    $label->set_justify( "fill" );
    $box2->pack_start( $label, $false, $false, 5 );
    $label->show();

}

sub entry {

    my($edit,$num) = @_;

    my $entry = Gtk::Entry->new();
 
    $entry->set_editable( $false ) if $edit == 0;

    if ($num == 0) {
        $entry->signal_connect( "activate", sub {
                $container[$num] = $entry->get_text();}); 
    }
    else {
         $entry->signal_connect( "changed", sub {
                 $container[$num] = $entry->get_text();
		 if ($num == 1) {
		     $ars->{kernel} = $container[$num];
		     ars($ars);
		     ars2($ars);
		 }
                 # here's where types in entry3, types other places
                 if (defined $ea1 and $num == 3) { 
                     $ea1->set_text($container[$num]); 
                 } 
                 if (defined $ear1 and $num == 3) { 
                     $ear1->set_text($container[$num]); 
                 }                  
     
                 # auto-detect compression if system has file
                 if ($num == 2) {
                     my $file = sys("which file");
                     if ($file == 0) {
		       if ($container[ROOT_FS]) {
                       open(F,"file $container[ROOT_FS] |"); # no error check here 
                          while (<F>) {
                             if (/gzip/) {
                               $gz_toggle->set_active( $true );
                             }
                             elsif (/bzip2/) {
                               $bz2_toggle->set_active( $true );
                             }
			     else {
				 info(0, 
				      "Neither gz or bz2 compression found\n");
			     }
                          }
		       close(F);
                       }  
                     }
                 }
                                                 });
     }
    if (defined $num and $num != 0) {
     my $todo;
     if ($num == 1) {
         $todo = "the Kernel";
     }
     elsif ($num == 2) {
         $todo = "the Compressed Filesystem";
     }
     else {
         $todo = "the Block Device to use";
     }
     $tooltips->set_tip( $entry,
       "Type in the location of $todo.", "" );
    }
    $box2->pack_start( $entry, $true, $true, 0 );
    $entry->show();

    return $entry;

}

sub button {

    my ($text,$ent,$name,$order,$device) = @_;

    my $button = Gtk::Button->new($text);
    if ($order == 1) {
      $tooltips->set_tip( $button, "Select the Kernel.", "" );
    }
    elsif ($order == 2) {
      $tooltips->set_tip( $button, "Select the Root Filesystem.", "" );
    }
    else {
      $tooltips->set_tip( $button, "Select the Device.", "" );
    }
    $button->signal_connect( "clicked",\&fileselect,$ent,$name,$order,$device);
    $button->show();
    $box2->pack_start( $button, $true, $true, 0 );
    $box2->show();

}

sub submit {
    
      my($kernel, $root_image, $device, $size);
      
      # comment this out for testing
      # Since only one filehandle is now used, this won't work
      # anymore.
      #unlink("$verbosefn");
      open (MTAB, "/etc/mtab") or die "no mtab!\n";
      while (<MTAB>) {
	  if (m,$mnt,) {
	      sys("umount $mnt");
	  }
      }
      close(MTAB);
      $entry5->set_text("");
      pb("boot",0);

      if ($gz_toggle->active) {
	  $compress = "gzip";
      }
      elsif ($bz2_toggle->active) {
	  $compress = "bzip2";
      }

      # Run some checks
      if (!defined $container[METHOD]) {
	  error_window("gBootRoot: ERROR: No Method supplied");
	  return;
      }
      else {
	  if ( $container[METHOD] eq "2 disk compression" ) {
	      my $rt = two_disk_compression_check();
	      return if $rt;
	  }
      }


if (defined $container[KERNEL] && -e $container[KERNEL] && 
    !-d $container[KERNEL]) {
    $kernel = $container[KERNEL];    
    # Better be sure it isn't in the mount directory
    if ($kernel =~ m,^$mnt,) {
      error_window("gBootRoot: ERROR: Kernel found below Device mount point: $mnt");
      return;
    }

}
elsif (defined $container[METHOD])  {
    error_window("gBootRoot: ERROR: Kernel not found");
    return;
}
if (defined $container[ROOT_FS] && -e $container[ROOT_FS] && 
    !-d $container[ROOT_FS] ) {
    $root_image = $container[ROOT_FS];
    if ($root_image =~ m,^$mnt,) {
      # Bug revealed by Cristian Ionescu-Idbohrn <cii@axis.com>
      error_window(
          "gBootRoot: ERROR: Rootimage found below Device mount point: $mnt");
      return;
    }
}
elsif (defined $container[METHOD] && defined $container[KERNEL]) {
    error_window("gBootRoot: ERROR: Root Filesystem not found");
    return;
}
# we need to check for this, too.
if (defined $container[BOOT_DEVICE] && -b $container[BOOT_DEVICE]) {
         $device = $container[BOOT_DEVICE];
}
elsif (defined $container[METHOD] && defined $container[KERNEL]
       && defined $container[ROOT_FS]) {
    error_window("gBootRoot: ERROR: Not a valid Block Device");
    return;
}
if (defined $container[SIZE]) {
          $size = $container[SIZE];
}

# pretty unlikely
elsif (defined $container[METHOD] && defined $container[KERNEL] &&
       defined $container[ROOT_FS] && defined $container[BOOT_DEVICE]) {
    error_window("gBootRoot: ERROR: No size specified");
    return;
}

 # kernel value can change without effecting initrd
 # no sense doing this until important stuff is filled in
 if (defined $kernel && defined $root_image &&
     defined $device && defined $size) {
     $container[COMPRESS] = $compress;
 
     # 1 .. 4 - its a hash .. not too simple     
     !defined $lib_strip_check  ? ($container[LIB_STRIP] = 1) 
       : ($container[LIB_STRIP] = $lib_strip_check->get_active());
     !$container[LIB_STRIP]     ? ($container[LIB_STRIP] = 2) 
	                        : ($container[LIB_STRIP] = 1);  

     !defined $bin_strip_check  ? ($container[BIN_STRIP] = 3) 
	                        : ($container[BIN_STRIP] = 
				   $bin_strip_check->get_active());
     !$container[BIN_STRIP]     ? ($container[BIN_STRIP] = 4) 
	                        : ($container[BIN_STRIP] = 3); 

     !defined $mod_strip_check  ? ($container[MOD_STRIP] = 7) 
	                        : ($container[MOD_STRIP] = 
				   $mod_strip_check->get_active());
     !$container[MOD_STRIP]     ? ($container[MOD_STRIP] = 8) 
	                        : ($container[MOD_STRIP] = 7); 


      if ($container[LIB_STRIP] == 1) {     
        $obj_count == 0 ? ($container[OBJCOPY_BOOL] = 5) 
	                : ($container[OBJCOPY_BOOL] = 6);
     }

     
     if (!defined $entry_advanced[0]) {
        $container[ABS_DEVICE] = $device . "ea1"; 
	$entry_advanced[0] = $device;
     }
     else {
	 $container[ABS_DEVICE] = $entry_advanced[0] . "ea1";
     }

     # If ARS was never opened, root device defaults to boot device.
     # This keeps the logic in the right place.
     $entry_advanced[3] = $container[BOOT_DEVICE] if !$entry_advanced[3];


     # Works now .. whoosh!
     if ($container[ABS_OPT_DEVICE]) {
        if ($container[ABS_OPT_DEVICE] ne "") {
            $container[ABS_OPT_DEVICE] = $entry_advanced[1] 
		if $entry_advanced[1];
        }
        if (defined $entry_advanced[1] and $entry_advanced[1] eq "") {
            $container[ABS_OPT_DEVICE] = "";
        }
        elsif ($container[ABS_OPT_DEVICE] eq "") {
           push(@original_container,$entry_advanced[1]);         
        }
     }
     else { 
           push(@original_container,$entry_advanced[1]) 
           if $entry_advanced[1];         
     }

     # pretty complex and works properly even for !-e lilo.conf
     if ($container[ABS_APPEND]) {
        if ($container[ABS_APPEND] ne "") {
            $container[ABS_APPEND] = $entry_advanced[2] 
		if $entry_advanced[2];
        }
        if (defined $entry_advanced[2] and $entry_advanced[2] eq "") {
            $container[ABS_APPEND] = "";
        }
        elsif ($container[ABS_APPEND] eq "") {
           push(@original_container,$entry_advanced[2]);         
        }
     }
     else { 
           push(@original_container,$entry_advanced[2]) 
           if $entry_advanced[2];         
      }

     if (@original_container) { # defined array deprecate Perl 5.6 -  zas@metaconcept.com
         # a hash check isn't perfect for two values which are the same
         # no need to check all the values

         my @temp_container = @container;

         # Got it! - how to deal with fields with no init value
         if (defined $container[ABS_OPT_DEVICE] and 
	     $container[ABS_OPT_DEVICE] eq "") {
	     $container[ABS_OPT_DEVICE] = $entry_advanced[1];
         }
         if (!defined $container[ABS_OPT_DEVICE]) {
	     $container[ABS_OPT_DEVICE] = $entry_advanced[1];
         }
         if (defined $container[ABS_APPEND] and 
	     $container[ABS_APPEND] eq "") {
	     $container[ABS_APPEND] = $entry_advanced[2];
         }
         if (!defined $container[ABS_APPEND]) {
	     $container[ABS_APPEND] = $entry_advanced[2];
         }

         # no sense looking at undef values
         my (@temp_container2,@original_container2);
	 for (@temp_container) {
             if ($_) {
		 push(@temp_container2,$_);
             }       
         }
	 for (@original_container) {
             if ($_) {
		 push(@original_container2,$_);
             }       
         }

	 @temp_container = @temp_container2;
	 @original_container = @original_container2;

         splice(@temp_container,1,1);

         # A test which I've had to run too often
         #print "BEFORE @temp_container\nAFTER  @original_container\n";

         my %diff;
         grep($diff{$_}++,@temp_container);
         my @diff = grep(!$diff{$_},@original_container);

         if ($#diff >= 0) {
         # unlink initrd_image.gz, do initrd_size()
             $ok = 1;
             $initrd = "initrd_image";
         }
         else {
             $ok = 0;
         }
     }
     else {
         $ok = 2; # this is actually first (1 = diff, 0 = same)
         $initrd = "initrd_image";
     }

     # reset
     @original_container = (  $container[METHOD],
			      $root_image,
			      $device,
			      $size,
                              $compress,
			      $container[LIB_STRIP],
			      $container[BIN_STRIP],
			      $container[MOD_STRIP],
			      $container[OBJCOPY_BOOL],
			      $container[ABS_DEVICE],
			      $container[ABS_OPT_DEVICE],
			      $container[ABS_APPEND]
			    );

     kernel_modules();
     lilo();  # This is the default now, and the value for
              # METHOD doesn't matter now.
 }

} # end sub submit

sub lilo {

  # Do a little cleanup just in case
  sys("rm $tmp/initrd_image.gz") if $ok == 1;
  sys("umount $tmp/initrd_mnt");

  my $kernel = $container[KERNEL];
  my $root_fs = $container[ROOT_FS];
  my $device = $container[BOOT_DEVICE];
  my $size = $container[SIZE];

  if ($ok == 1 || $ok == 2) {
    my $value = initrd($kernel,$root_fs,$device,$size);
    mtab(0) if defined $value;
  }
  elsif ($ok == 0) {
    mtab(0);
  }

} # end sub lilo

sub lilo_put_it_together {

  my $B = "boot";
  my $fs_type = (split(/\s/,$main::makefs))[0];

  # Time to do a little calculations
  my $device_size;
##  if ( $fs_type ne "genext2fs" ) {
  if ( $> == 0 ) {
      $device_size = (split(/\s+/,`df $mnt`))[8];
  }
  else {
      $device_size = $container[SIZE];
  }
  my $boot_size = (stat($container[KERNEL]))[12]/2 + 
      (stat("$tmp/$initrd"))[12]/2;
  my $remain_boot = $device_size - $boot_size;
  pb($B,1);

  # A little output
  if ($remain_boot  =~ /^-+\d+$/) {
      error_window("gBootRoot: ERROR: Not enough room: boot stuff = $boot_size k, device = $device_size k");
      return;
  }
  else {
      $entry5->set_text("$remain_boot k");
  }


  # If genext2fs is being used clean $tmp/bootdisk if any garbage is found,
  # and temporarily rename $mnt to that directory.
  #my $old_mount;
##  if ( $fs_type eq "genext2fs" ) {
  if ( $> != 0 ) {
      if (-d "$tmp/bootdisk") {
	  sys("rm -rf $tmp/bootdisk");
      }    
      if (!-d "$tmp/bootdisk") {
	  return if errmk(sys("mkdir $tmp/bootdisk")) == 2;
      }
      $old_mount = $mnt;
      $mnt = "$tmp/bootdisk/";
  }

  # Here everything is copied over either to the device or the the $mnt
  # directory if genext2fs is used. 
  info(0, "Copy over initrd ramdisk\n");
  info(0, "Copy over initrd ramdisk .. $tmp/$initrd $mnt/$initrd\n");
  return if err_custom("cp $tmp/$initrd $mnt/$initrd",
		       "gBootRoot: ERROR: Could not copy over initrd") == 2;
  pb($B,2);

  info(0, "Copying over kernel\n");
##  if ( $fs_type ne "genext2fs" ) {
  if ( $> == 0 ) {
      return if
	  err_custom("rm -rf $mnt/lost+found; cp $container[KERNEL] $mnt/kernel", "gBootRoot: ERROR: Could not copy over the kernel") == 2;
  }
  else {
      return if
	  err_custom("cp $container[KERNEL] $mnt/kernel", "gBootRoot: ERROR: Could not copy over the kernel") == 2;
  }
  pb($B,3);

  info(0, "Making stuff for lilo\n");
   # will be 0 if mkdir fails, but 0 if cp succeeds ?
  return if err(sys("mkdir $mnt/{boot,dev}")) == 2; 

  # DEVICES SECTION
  my @devices;
  my $device_table  = "$tmp/boot_device_table.txt";
##  if ( $fs_type eq "genext2fs" ) {
  if ( $> != 0 ) {
	info(0, "Making $device_table for genext2fs\n");
	my $error;
	unlink( $device_table ) if -e $device_table;

	#<path> <type> <mode> <uid> <gid> <major> <minor> <start><inc><count> 
	# /dev is always needs to be made automatically
	open(BootRoot::Yard::DEVICE_TABLE, ">$device_table") or
	    ($error = error("$device_table: $!"));
	return "ERROR"if $error && $error eq "ERROR";
	
	print BootRoot::Yard::DEVICE_TABLE 
	    "# <path>\t<type>\t<mode>\t<uid>\t<gid>\t<major>\t<minor>" .
		"\t<start>\t<inc>\t<count>\n"; 
	print BootRoot::Yard::DEVICE_TABLE "/dev\t\td\t0755\t-\t-\t-\t-\t-\t-\t-\n";

	# Keep a record of the devices required
	@devices = qw(/dev/null /dev/fd0 /dev/fd1 /dev/hda1);
	for ( split(" ", $container[BOOT_DEVICE] ) ) {
	    my @existing_device_test = grep ( /$_/, @devices );
	    if ( !@existing_device_test ) {
		push(@devices, $_ ) if $_;
	    }
	}

	# This adds that next device if found in lilo.conf
	($norm_root_device) = gdkbirdaao();
	if ( $norm_root_device ) {
	    my @existing_device_test = 
		grep ( /\/dev\/$norm_root_device/, @devices );
	    if ( !@existing_device_test ) {
		push( @devices, "/dev/$norm_root_device" );
	    }
	}

	# For frame buffer devices and the like.
	if ( $entry_advanced[1] ) {
	    for ( split(" ", $entry_advanced[1] ) ) {
		my @existing_device_test = grep ( /$_/, @devices );
		if ( !@existing_device_test ) {
		    push(@devices, $_ ) if $_;
		}
	    }
	}


	device_table( @devices );
	close(BootRoot::Yard::DEVICE_TABLE);

  }
  else {

      info(0, "Copying over devices to $mnt/dev\n");

      return if err(sys("cp -a /dev/{null,fd?,hda1} $mnt/dev")) == 2;

      # Hopefully, this works, but have never tested it -- o.k I did
      if ($container[BOOT_DEVICE] !~ m,/dev/fd\d{1}$,) {
	  return if err(sys("cp -a $container[BOOT_DEVICE] $mnt/dev")) == 2;
      }

      # This adds that next device if found in lilo.conf
      ($norm_root_device) = gdkbirdaao();
      if (!-e "$mnt/dev/$norm_root_device") {
	  return if err(sys("cp -a /dev/$norm_root_device $mnt/dev")) == 2;
      }

      # For frame buffer devices and the like.
      if ($entry_advanced[1]) {
	  return if errcp(sys("cp -a $entry_advanced[1] $mnt/dev")) == 2;
      }


  } # end DEVICES SECTION

  info(0, "Copy over important lilo stuff\n");
  return if
  err_custom("cp /boot/boot.b $mnt/boot",
  "gBootRoot: ERROR: Not enough space or can't find /boot/boot.b") == 2;
  pb($B,4);
  # 3k sort of accounts for dev & dirs assuming dev is reasonable
  $remain_boot = $remain_boot - (stat("/boot/boot.b"))[12]/2  - 3;
  $entry5->set_text("$remain_boot k");

  # Write out the HEREDOCS
  open(LC, ">$mnt/brlilo.conf") or die "Couldn't write $mnt/brlilo.conf\n";
  if ( $> == 0 ) {
      print LC brlilo($container[BOOT_DEVICE]); close(LC);
  }
  else {
      print LC brlilo_non_root($container[BOOT_DEVICE]); close(LC);      
  }

  open(M, ">$mnt/message") or die "Couldn't write $mnt/message\n";
  print M message(); close(M);
  pb($B,5);
  $remain_boot = $remain_boot - ( (stat("$mnt/brlilo.conf"))[12]/2 +
				  (stat("$mnt/message"))[12]/2 );
  $entry5->set_text("$remain_boot k");

  # Got to umount,mount, and umount again to make sure everything is
  # copied over before doing lilo unless genext2fs in being used.
##  if ( $fs_type ne "genext2fs" ) {
  if ( $> == 0 ) {
      return if errum(sys("umount $mnt")) == 2;
      info(0, "Umount device\n");
      info(0, "Remount device\n");
  }
  pb($B,6);
  

##  if ( $fs_type eq "genext2fs" ) {
  if ( $> != 0 ) {
      my $error;

      # When creating a fs on floppy, specifying -i causes genext2fs to fail, 
      # its better to just let the program figure out the inode size for now.
      if (
	  sys("/usr/lib/bootroot/$main::makefs -b $device_size -d  $mnt -D $device_table $entry_advanced[0]") !~ 
	  /^0$/ ) {
	  $error = error("Cannot $fs_type filesystem.\n");
	  return "ERROR" if $error && $error eq "ERROR";
      }

  }


##  if ( $fs_type eq "genext2fs" ) {
  if ( $> != 0 ) {
      $mnt = $old_mount;
  }

  # Real device
  if ( $> == 0 ) {
      return if errm(sys("mount -t ext2 $entry_advanced[0] $mnt")) == 2;
  }
  else {
      my $errm_value = errm(sys("mount $mnt"));
##      if ( $errm_value == 2 && $fs_type eq "genext2fs" ) {
      if ( $errm_value == 2 && $> != 0 ) {
	  info(0, "Ask your administrator to add this line to the" . 
	       " fstab file:\n");
	  info(0, "\n$entry_advanced[0]\t$mnt\tauto\tdefaults,noauto," .
	       "user\t0\t0\n\n");
	}
      else {
	  return if $errm_value  == 2;
      }
  }


  info(0, "Configuring lilo\n");
  pb($B,7);
  chdir("$mnt"); #"boot_root: ERROR: Could not change directories\n";

  # This enforces that lilo is only wil run on a bootable drive,
  # otherwise the user has to do it manually.
  if ($container[BOOT_DEVICE] eq $entry_advanced[0]) {

      # root can happily chroot
      if ( $> == 0 ) {

	  if ( err_custom("lilo -v -C brlilo.conf -r $mnt",
			  "gBootRoot: ERROR: lilo failed") == 2 ) {
	      chdir($pwd); 
	      return;          
	  }

      }

      # At this point the normal user needs to be asked first if they have
      # root lilo power, before going on.
      else {


	  # Ask the user if they have su lilo priviliges.
	  # Hopefully, password free, but that can be incorporated.
	  mtab(3);
	  do {
		  if ( $mtab == 2 ) {
		      undef $mtab;
		      chdir($pwd); 
		      return if errum(sys("umount $mnt")) == 2;
		      return;
		  }
	      while (Gtk->events_pending) { Gtk->main_iteration; }
	  } while $mtab;

	  # It's o.k. if lilo fails.
	  if ( err_custom("$main::sudo lilo -v -C $mnt/brlilo.conf -b $entry_advanced[0]", "gBootRoot: ERROR: lilo failed") == 2 ) {
	      chdir($pwd); 
	  }

      }

  }


  $remain_boot = $remain_boot - (stat("$mnt/boot/map"))[12]/2;
  $entry5->set_text("$remain_boot k");
  pb($B,8);

  chdir($pwd); # or die "boot_root: ERROR: Could not change directories\n";

  info(0, "Umounting $mnt\n");
  my $um = errum(sys("umount $mnt"));
  pb($B,10);

  if ($ok == 1 || $ok == 2) {
##      if ( $fs_type ne "genext2fs" ) {
      if ( $> == 0 ) {
	  return if
	      errrm(sys("rmdir $tmp/initrd_mnt")) == 2;
      }
  }

# Here's where we copy over that compressed filesystem
# We could separate $container[BOOT_DEVICE] = boot,root allowing two
# different devices to be used. -- now there is $entry_advanced[3] which
# is the ROOT_DEVICE
if ($um == 0 ) {
    mtab(1);
}
else {
    error_window("gBootRoot: ERROR: Boot disk was never umounted");
}  # copy over the compressed

} # end sub lilo_put_it_together

sub device2 {

    my $fs_type = (split(/\s/,$main::makefs))[0];

    # Time to do a little calculations
    my $device_size;
##    if ( $fs_type ne "genext2fs" ) {
    if ( $> == 0 ) {
	$device_size = (split(/\s+/,`df $mnt`))[8];
    }
    else {
	if ( !$root_device_size ) {
	    $device_size = $container[SIZE];
	}
	else {
	    $device_size = $root_device_size;
	}
    }
    
    my $root_image_size = (stat($container[ROOT_FS]))[12]/2;
    my $remain_root = $device_size - $root_image_size;

    if ($remain_root  =~ /^-+\d+$/) {
	error_window("gBootRoot: ERROR: Not enough room: root stuff = $root_image_size k, device = $device_size k");
    }
    else {
	$entry5->set_text("$remain_root k");
    }
    
    info(0, "Copy over the compressed filesystem\n");
##    if ( $fs_type ne "genext2fs" ) {
    if ( $> == 0 ) {
	return if errrm(sys("rmdir $mnt/lost+found")) == 2;
    }
    my $broot_image = basename($container[ROOT_FS]);

    # Status output, use FH, or genext2fs to create disk.
    #----------------------------------------------------
    my $FS = "filesystem";
    my $line_count = `wc -l < $container[ROOT_FS]`; chomp $line_count;
    my $half_line_count = $line_count/2;
    my $count = 1;

##    if ( $fs_type ne "genext2fs" ) {
    if ( $> == 0 ) {
	open(CF, ">$mnt/$broot_image") or error_window(
       "gBootRoot: ERROR: Could not copy over the root filesystem") and return;
    
	open(CR, "$container[ROOT_FS]") or error_window(
       "gBootRoot: ERROR: Could not copy over the root filesystem") and return;

	while (<CR>) {
	    print CF $_;
	    pb($FS,$count,$line_count) if $count < $half_line_count;
	    $count++;
	}
	close(CF); 
	close(CR);
    }

    # genext2fs
    else {

	my $error;

	# If genext2fs is being used clean $tmp/rootdisk if any garbage is 
	# found.
##	if ( $fs_type eq "genext2fs" ) {
	if ( $> != 0 ) {
	    if (-d "$tmp/rootdisk") {
		sys("rm -rf $tmp/rootdisk");
	    }    
	    if (!-d "$tmp/rootdisk") {
		return if errmk(sys("mkdir $tmp/rootdisk")) == 2;
	    }
	}

	return if errcp( sys("cp -a $container[ROOT_FS] $tmp/rootdisk") ) == 2;
	
	for ( $count .. $half_line_count ) {
	    pb($FS,$count,$line_count) if $count < $half_line_count;
	    $count++;
	}
	

	if (
	  sys("/usr/lib/bootroot/$main::makefs -b $device_size -d $tmp/rootdisk $entry_advanced[3]") !~ 
	    /^0$/ ) {
	    info( 0, "/usr/lib/bootroot/$main::makefs -b $device_size -d $tmp/rootdisk $entry_advanced[3]\n");
	    $error = error("Cannot $fs_type filesystem.\n");
	    return "ERROR" if $error && $error eq "ERROR";
	}
	

    }
    #------------------------------------------------------

##    if ( $fs_type ne "genext2fs" ) {
    if ( $> == 0 ) {
	return if
	    err_custom("umount $mnt",
	    "gBootRoot: ERROR: Root disk did not properly umount") == 2;
    }

    $line_count = $line_count * 2;
    pb($FS,$count,$line_count);
    info(0, "Finished!\n");

} # end sub device 2

# Checks if lib or bin is stripped, if not proceeds to strip.  Returns
# full file path and strip result.  Right now this is specific to initrd.
sub stripper {
    
    # stripper (program,bin|lib|mod);
    if ((!defined $lib_strip_check && !defined $bin_strip_check 
	 && !defined $mod_strip_check) or
        ($lib_strip_check->active || $bin_strip_check->active 
	 || $mod_strip_check->active)) {

    # DON'T DO THIS >/dev/null 2>&1`;
    my $not_stripped = `file $_[0] 2> /dev/null`; 
    my $filename = basename($_[0]);

     if ($not_stripped =~ m,not stripped,) {
	 if (($_[1] eq "lib" && !defined $lib_strip_check) or
             ($_[1] eq "lib" && $lib_strip_check->active)) {
             # --strip-all works for initrd
             if ($obj_count == 0) {
	           sys("objcopy --strip-debug -p $_[0] $tmp/$filename"); 
		   info(1,"--strip-debug $filename\n");
	           return ( "$tmp/$filename", 1 );
             }
             elsif ($obj_count == 1) {
	           sys("objcopy --strip-all -p $_[0] $tmp/$filename"); 
		   info(1,"--strip-all $filename\n");
	           return ( "$tmp/$filename", 1 );
	     }
         }
         elsif (($_[1] eq "bin" && !defined $bin_strip_check) or
                ($_[1] eq "bin" && $bin_strip_check->active)) {
	     sys("objcopy --strip-all -p $_[0] $tmp/$filename"); 
	     info(1,"--strip-all $filename\n");
	     return ( "$tmp/$filename", 1 );
         }
         elsif (($_[1] eq "mod" && !defined $mod_strip_check) or
                ($_[1] eq "mod" && $mod_strip_check->active)) {
	     sys("objcopy --strip-debug -p $_[0] $tmp/$filename"); 
	     info(1,"--strip-debug $filename\n");
	     return ( "$tmp/$filename", 1 );
         }
     }
     else {
	 return ( $_[0], 0 );
     }
    }
    return ( $_[0], 0);

} # end sub stripper

sub two_disk_compression_check {

    my ($ash,$lilo,$bzip2,$file);

    if ( !find_file_in_path("ash") ) {
	$ash = "ash";	
    }

    if ( !find_file_in_path("lilo") ) {
	$lilo = "lilo";	
    }

    if ( !find_file_in_path("bzip2") ) {
	$bzip2 = "bzip2";	
    }

    if ( !find_file_in_path("file") ) {
	$file = "file";	
    }

    if ( $ash || 
	 
	 $lilo || 
	 
	 $bzip2 ||

	 $ash

	 ) {

	error_window(
	    "Program(s) required by this method:  $lilo  $ash  $bzip2  $file"
		     );
	
	return 1;
    }


} # end sub two_disk_compression_check

sub kernel_modules {

    my (@modules, @modules_found);

    my $module_choices = $ea3->get_text() if $ea3;
    my $kernel_version_choice = $ea5->get_text() if $ea5;
    undef $kernel_version_choice if defined $kernel_version_choice eq "";
    undef $kernel_version_choice if !$kernel_version_choice;

    $kernel_version = kernel_version_check($container[KERNEL],
					   $kernel_version_choice);
    #-----------------------------
    # METHOD -> 2 DISK COMPRESSION
    #-----------------------------
    if ( $container[METHOD] eq "2 disk compression" ) {

	$entry_advanced[11] = "floppy";
	
	if ($ea3) {
	    if ($module_choices eq "") {
		$ea3->set_text("floppy");
		$module_choices = "floppy";
	    }
	    else {
		$ea3->set_text($ea3->get_text() . " floppy") 
		    if $ea3->get_text() !~ /\s*floppy\s*/;
		$module_choices = $ea3->get_text();
	    }
	}
	else {
	    $module_choices = "floppy";
	}

	@modules = split(/\s+/, $module_choices);
	
    }

    info(1, "Modules:  @modules\n");

    
    # Figure out modules path.
    if ( @modules ) {
	foreach my $module (@modules) {
	    finddepth sub { if ( $File::Find::name =~ m,/$module\.o$, ) {
		push(@modules_found,$File::Find::name);
	    } },
	    "$modules_directory/$kernel_version";  

	} 
    }

    $, = "  ";
    info(1,"Modules found:\n@modules_found\n");
    $, = "";

    return @modules_found;


} # end sub kernel_modules


sub initrd_size {

    info(0,"Boot Method: 2 disk\n", 
	 "Type: initrd boot disk with LILO/root filesystem disk\n");

    my ($linuxrc_size) = @_;
    my ($what,$lib);
    my ($path,$value);
    info(0, "Checking size needed for initrd\n");

    # the size of the loop device should be at least 1.63% larger than what
    # it will contain (i.e. 8192 inode), but to keep on the safe size it will
    #  be 2.00% larger.

    # Unforturnately, stat is being done on
    # the actual live fs, whereas the loop filesystem may be different.  In
    # general the check is quite conservative and will always leave room.
    # Stat seems to view things differently based on the situation, and
    # -s file has another opinion, for now stat will be used and perhaps
    # the actual filesystem in the future.  Better extra room than too little.

    # 9 dirs  = 1024 each (increase if modified)
    # {ash,gzip,mount,umount} (required executables)
    # bzip2 if $compress eq bzip2 (optional)
    # 1 for ld.so.cache
    
    # change dir size if needed
    my $dir_size = 9 + 1;
    my $initrd_size = $dir_size + $linuxrc_size;

    # clean initrd_mnt if any garbage is found.
    if (-d "$tmp/initrd_mnt") {
	sys("rm -rf $tmp/initrd_mnt");
    }    
    if (!-d "$tmp/initrd_mnt") {
	return if errmk(sys("mkdir $tmp/initrd_mnt")) == 2;
    }

    # modules - see CVS:1.65 for previous non-size check.
    my @modules = kernel_modules();
    if (@modules) {

	my $tool;

	# dirs sizes, just assuming 1024
	my $ds = mkpath("$tmp/initrd_mnt/lib/modules/$kernel_version");
	$initrd_size = $initrd_size + ($ds - 1);

	# copy over the modules
	foreach my $stuff (@modules) {
	    ($path,$value) = stripper($stuff,"mod");

	    $value == 0 ? ($tool = "cp -a") : ($tool = "mv"); 
	    if (!$path) {
		info(1,"gBootRoot Error: Couldn't find $stuff\n");
	    }	    

	    # copy stuff to proper directory and unlink size tester
	    return if 
		errcp(sys("$tool $path $tmp/initrd_mnt/lib/modules/$kernel_version")) == 2;
	    unlink($path) if $value == 1;
	}    

	# Do the depmod operation

	if ($entry_advanced[13] && $entry_advanced[13] ne "") {

	    if ( $> == 0 ) {

		return if err_custom("depmod -ae -F $entry_advanced[13] -b $tmp/initrd_mnt $kernel_version", "gBootRoot: ERROR: depmod failed") == 2;

	    }
	    else {
		
		    return if err_custom("depmod -aer -F $entry_advanced[13] -b $tmp/initrd_mnt $kernel_version", "gBootRoot: ERROR: depmod failed") == 2;
		    
	    
		}
			
	    } # $entry_advanced[13] defined

	    else {

		if ( $> == 0 ) {

		    return if err_custom("depmod -ae -b $tmp/initrd_mnt $kernel_version", "gBootRoot: ERROR: depmod failed") == 2;
		    
		}
		else {

		    return if err_custom("depmod -aer -b $tmp/initrd_mnt $kernel_version", "gBootRoot: ERROR: depmod failed") == 2;

		}

	    }


	# Check all the files in the dirctory for their size, and unlink them.
	opendir(DIR,"$tmp/initrd_mnt/lib/modules/$kernel_version") 
	    or info(1,"Failed to open $tmp/initrd_mnt/$kernel_version");
	my @module_stuff = grep { /\w+/ } readdir(DIR);
	close(DIR);

	# Figure out the size for all the stuff created by depmod and the
	# modules included.
	foreach my $stuff (@module_stuff) {
	    $initrd_size =  $initrd_size + 
		((stat("$tmp/initrd_mnt/lib/modules/$kernel_version/$stuff"))[12]/2);
	    unlink("$tmp/initrd_mnt/lib/modules/$kernel_version/$stuff");
	}


	# The modules directory has to be removed here.
	return if 
        errrm(sys("rmdir $tmp/initrd_mnt/lib/modules/$kernel_version")) == 2;
	return if 
        errrm(sys("rmdir $tmp/initrd_mnt/lib/modules")) == 2;
	return if 
        errrm(sys("rmdir $tmp/initrd_mnt/lib/")) == 2;


    } # end if (@modules)


    # This and libs should be user accessible
    # add other executables here
    my @initrd_stuff;
    if (@modules) {
	@initrd_stuff = qw(ash gzip mount umount modprobe insmod);
    }
    else {
	@initrd_stuff = qw(ash gzip mount umount);
    }

    foreach (@initrd_stuff) {
	    if ( !readlink($_) ) {
		($path,$value) = stripper(find_file_in_path($_),"bin");
		$initrd_size =  $initrd_size + ((stat($path))[12]/2);
		unlink($path) if $value == 1;
	    }
	    else {
		$initrd_size = $initrd_size + 
		    length(readlink(find_file_in_path($_)));
	    }
    }

    if ($compress eq "bzip2" && -e find_file_in_path($compress)) {
	($path,$value) = stripper(find_file_in_path($compress),"bin");
	$initrd_size = $initrd_size + ((stat($path))[12]/2);
	unlink($path) if $value == 1;
    }

    my $lib_tester;
    if ($bz2_toggle->active && -x find_file_in_path("bzip2") ) {
	
	$lib_tester = find_file_in_path("bzip2");

    }
    else {

	$lib_tester = find_file_in_path("init");

    }

    my $dir;

    # lib sizes  This is going to be improved later with library_dependencies
    open(L,"ldd $lib_tester|") or die "Oops, no init could be found :)\n"; # safe to use ldd
    while (<L>) {
	my $place;
	($lib,$place) = (split(/=>/,$_))[0,1];
	$place = (split(" ",$place))[0];
	$lib =~ s/\s+//;
	$lib = basename($lib);
	$lib =~ s/\s+$//;
        $dir = dirname($place);	

	open (SL,"ls -l $dir/$lib|") or die "humm: $!\n";
        while (<SL>) {
	    # symbolic link
	    if (-l "$dir/$lib") {
		$what = (split(/\s+/,$_))[10];
		$initrd_size = $initrd_size + 1;
		($path,$value) = stripper("$dir/$lib","lib");
		$initrd_size = $initrd_size + ((stat($path))[12]/2);
		unlink($path) if $value == 1;
	    }
	    # no symbolic link
	    else {
		($path,$value) = stripper("$dir/$lib","lib");
		$initrd_size = $initrd_size + ((stat($path))[12]/2);
		unlink($path) if $value == 1;
	    }
        }
    }
    close(SL);
    close(L);
    

    $initrd_size = $initrd_size + ($initrd_size * 0.02);

    # For perfection 1 (rounded up) is o.k., but for safety 10 would be
    # better
    $initrd_size = sprintf("%.f",$initrd_size) + 10;
    return $initrd_size;
    
} # end sub initrd_size

sub pb {

    # Will have to count by hand
    if ($_[0] eq "initrd") {
        $pbar->configure( 10, 0, 10 );
    }
    elsif ($_[0] eq "boot") {
        $pbar->configure( 10, 0, 10 );
    }
    elsif ($_[0] eq "filesystem") {
        $pbar->configure($_[2], 0, $_[2]);
    }

    $pbar->set_value($_[1]);
    # Found this at Gnome ..
    # http://www.uk.gnome.org/mailing-lists/archives/gtk-list/
    # 1999-October/0401.shtml
    # Also, http://www.gtk.org/faq/  5.14
    while (Gtk->events_pending) { Gtk->main_iteration; }

}

sub initrd {

    my($kernel,$root_image,$device,$size) = @_;
    my($lib,$what,$path,$value,$tool);
    my $I = "initrd";

    # Basically this means the ARS was never opened or edited and the
    # default behavior is to use the same device.
    if ( !$entry_advanced[3] ) {
	$device = $container[BOOT_DEVICE];
    }
    else {
	$device = $entry_advanced[3];
    }


    my $fs_type = (split(/\s/,$main::makefs))[0];

##    if ( $fs_type eq "genext2fs" ) {
    if ( $> != 0 ) {
	# Assuming busybox is being used, so bzip2 should still be standard
	# just another link .. just for testing.
	##if ( $compress eq "bzip2" ) {
	##    $compress  = "bunzip2";
	##}
    }

    my $broot_image = basename($root_image);
    open(LC, ">$tmp/linuxrc") or die "Couldn't write linuxrc to loop device\n";
    print LC initrd_heredoc($broot_image,$device); close(LC);
    pb($I,1);
    my $size_needed = initrd_size((stat("$tmp/linuxrc"))[12]/2);
    unlink("$tmp/linuxrc");


##    if ( $fs_type ne "genext2fs" ) {
    if ( $> == 0 ) {
	info(0, "Using loop device to make initrd\n");
	info(0, "Make sure you have loop device capability" . 
	     " in your running kernel\n");
	sys("dd if=/dev/zero of=$tmp/$initrd bs=1024 count=$size_needed");
	pb($I,2);
	# no need to enter y every time .. could use -F
	my $error;
	open(T,"|mke2fs -F -m0 -i8192 $tmp/$initrd >/dev/null 2>&1") or 
	    ($error = error("Can not make ext2 filesystem on initrd.\n")); 
	return "ERROR" if $error && $error eq "ERROR";
	print T "y\n"; close(T);
	pb($I,3);
	info(0, "Mounting initrd in $tmp/initrd_mnt\n");

    }

    # clean initrd_mnt if any garbage is found.
    if (-d "$tmp/initrd_mnt") {
	sys("rm -rf $tmp/initrd_mnt");
    }    
    if (!-d "$tmp/initrd_mnt") {
	return if errmk(sys("mkdir $tmp/initrd_mnt")) == 2;
    }

   
    # Here the loop device is made on tmp, not mnt
##    if ( $fs_type eq "genext2fs" ) {
    if ( $> != 0 ) {
	info(0, "Using genext2fs to make initrd rather than a loop device\n");
    }

    else {
	if ( $> == 0 )  {
	    return if errm(sys("mount -o loop -t ext2 $tmp/$initrd $tmp/initrd_mnt")) == 2;    
	}
	else {
	    return if errm(sys("mount $tmp/initrd_mnt")) == 2;
	}	
    }
    pb($I,4);

    info(0, "Putting everything together\n");
##    if ( $fs_type eq "genext2fs" ) {
    if ( $> != 0 ) {
	open(LC, ">$tmp/initrd_mnt/linuxrc") or die "Couldn't write linuxrc to $tmp/initrd_mnt\n";
    }
    else { 
	open(LC, ">$tmp/initrd_mnt/linuxrc") or die "Couldn't write linuxrc to loop device\n";
    }
    print LC initrd_heredoc($broot_image,$device); close(LC);
    # I could test this but somebody's system may do permissions differently
    sys("chmod 0755 $tmp/initrd_mnt/linuxrc");
##    if ($fs_type ne "genext2fs" ) {
    if ( $> == 0 ) {
	sys("rmdir $tmp/initrd_mnt/lost+found");
    }
    pb($I,5);

    info(0, "... the dirs\n");
    return if errmk(
    sys("mkdir $tmp/initrd_mnt/{bin,dev,etc,lib,mnt,proc,sbin,usr}")) == 2; 
    return if errmk(sys("mkdir $tmp/initrd_mnt/usr/lib")) == 2;
    pb($I,6);

    # Hopefully, this works, but have never tested it - o.k I did
##    if ( $fs_type ne "genext2fs" ) {
    if ( $> == 0 ) {
	if ($container[BOOT_DEVICE] !~ m,/dev/fd\d{1}$,) {
	    return if err(sys("cp -a $container[BOOT_DEVICE] $mnt/dev")) == 2;
	}
    }

    # DEVICES SECTION
    my @devices;
    my $device_table  = "$tmp/initrd_device_table.txt";
##    if ( $fs_type eq "genext2fs" ) {
    if ( $> != 0 ) {
	info(0, "Making $device_table for genext2fs\n");
	my $error;
	unlink( $device_table ) if -e $device_table;

	#<path> <type> <mode> <uid> <gid> <major> <minor> <start><inc><count> 
	# /dev is always needs to be made automatically
	open(BootRoot::Yard::DEVICE_TABLE, ">$device_table") or
	    ($error = error("$device_table: $!"));
	return "ERROR"if $error && $error eq "ERROR";
	
	print BootRoot::Yard::DEVICE_TABLE 
	    "# <path>\t<type>\t<mode>\t<uid>\t<gid>\t<major>\t<minor>" .
		"\t<start>\t<inc>\t<count>\n"; 
	print BootRoot::Yard::DEVICE_TABLE "/dev\t\td\t0755\t-\t-\t-\t-\t-\t-\t-\n";

	# Keep a record of the devices required
	@devices = qw(/dev/console dev/null /dev/ram0 /dev/ram1 /dev/tty0);
	for ( split(" ", $container[BOOT_DEVICE] ) ) {
	    push(@devices, $_ ) if $_;
	}

	device_table( @devices );
	close(BootRoot::Yard::DEVICE_TABLE);

    }

    else {

	if ( $> == 0 ) {
	    info(0, "Copying over devices to $tmp/initrd_mnt/dev\n");
	    return if errcp(		    
	    sys("cp -a /dev/{console,null,ram0,ram1,tty0} $tmp/initrd_mnt/dev")
                ) == 2;
	   return if errcp(
            sys("cp -a $container[BOOT_DEVICE] $tmp/initrd_mnt/dev")) == 2;
	}
	else {
	    info(0, "Mknod devices at $tmp/initrd_mnt/dev\n");
	    # This could be replaced by a devfs.
	    sys("$main::sudo mknod c 5 1 $tmp/initrd_mnt/dev/console");
	    sys("$main::sudo mknod c 1 3 $tmp/initrd_mnt/dev/null");
	    sys("$main::sudo mknod b 1 0 $tmp/initrd_mnt/dev/ram0");
	    sys("$main::sudo mknod b 1 1 $tmp/initrd_mnt/dev/ram1");
	    sys("$main::sudo mknod c 4 0 $tmp/initrd_mnt/dev/tty0");
	    sys("$main::sudo mknod b 2 0 $tmp/initrd_mnt/dev/fd0");
	}

    } # end DEVICES SECTION

    pb($I,7);

    # This and libs should be user accessible
    info(0, ".. the modules\n");
    my @modules = kernel_modules();

    if (@modules) {

	mkpath("$tmp/initrd_mnt/lib/modules/$kernel_version");

	foreach my $stuff (@modules) {
	    ($path,$value) = stripper($stuff,"mod");
	    $value == 0 ? ($tool = "cp -a") : ($tool = "mv"); 
	    if (!$path) {
		info(1,"gBootRoot Error: Couldn't find $stuff\n");
	    }	    
	    return if 
		errcp(sys("$tool $path $tmp/initrd_mnt/lib/modules/$kernel_version")) == 2;
	}    

	if ($entry_advanced[13] && $entry_advanced[13] ne "") {

	    if ( $> == 0 ) {

		info(1, "depmod -ae -F $entry_advanced[13] -b $tmp/initrd_mnt/lib/modules/$kernel_version $kernel_version\n");
		return if err_custom("depmod -ae -F $entry_advanced[13] -b $tmp/initrd_mnt $kernel_version", "gBootRoot: ERROR: depmod failed") == 2;

	}
	    else {

		info(1, "depmod -aer -F $entry_advanced[13] -b $tmp/initrd_mnt/lib/modules/$kernel_version $kernel_version\n");
		return if err_custom("depmod -aer -F $entry_advanced[13] -b $tmp/initrd_mnt $kernel_version", "gBootRoot: ERROR: depmod failed") == 2;

	    }

	} # $entry_advanced[13] defined
	else {

	    if ( $> == 0 ) {

		info(1, "depmod -ae -b $tmp/initrd_mnt/lib/modules/$kernel_version $kernel_version\n");
		return if err_custom("depmod -ae -b $tmp/initrd_mnt $kernel_version", "gBootRoot: ERROR: depmod failed") == 2;

	    }
	    else {

		info(1, "depmod -aer -b $tmp/initrd_mnt/lib/modules/$kernel_version $kernel_version\n");
		return if err_custom("depmod -aer -b $tmp/initrd_mnt $kernel_version", "gBootRoot: ERROR: depmod failed") == 2;

	    }

	}

    }

    info(0, ".. the bins\n");
    my @initrd_stuff;
    if (@modules) {
	@initrd_stuff = qw(ash gzip mount umount modprobe insmod);
    }
    else {
	@initrd_stuff = qw(ash gzip mount umount);
    }

    # Will put the stuff in sbin because the is where the kernel looks for
    # modprobe.
    if ( ! $busybox ) {

	foreach (@initrd_stuff) {
	    ($path,$value) = stripper(find_file_in_path($_),"bin");
	    $value == 0 ? ($tool = "cp -a") : ($tool = "mv"); 
	    if (!$path) {
		info(1,"gBootRoot Error: Couldn't find $_\n");
	    }
	    return if errcp(sys("$tool $path $tmp/initrd_mnt/sbin")) == 2;
	}

    if ($compress eq "bzip2" && -e find_file_in_path($compress)) {
	($path,$value) = stripper(find_file_in_path($compress),"bin");
	$value == 0 ? ($tool = "cp -a") : ($tool = "mv"); 
	return if errcp(sys("$tool $path $tmp/initrd_mnt/sbin")) == 2;
    }

	# Testing if init is sufficient for grabbing the correct libraries for the
	# executables immediately above.  This could be modified to test a
	# list of executables.  Now bzip2 uses libbz2.so.1.0, so if bzip2 is
	# present on the system this will be the tester instead, and size
	# has to be figured out differently.
	info(0, ".. the libs\n");

	my $lib_tester;
	if ($bz2_toggle->active && -x find_file_in_path("bzip2") ) {
	    
	    $lib_tester = find_file_in_path("bzip2");
	
	}
	else {
	
	    $lib_tester = find_file_in_path("init");

	}

	my $dir;

	open(L,"ldd $lib_tester|") or die "Oops, no $lib_tester could be found :)\n"; # safe to use ldd, this is going to be fixed later with library_dependencies
	while (<L>) {
	    my $place;
	    ($lib,$place) = (split(/=>/,$_))[0,1];
	    $place = (split(" ",$place))[0];
	    $lib =~ s/\s+//;
	    $lib = basename($lib); 
	    $lib =~ s/\s+$//;
	    $dir = dirname($place);	
	    info(0,"$dir/$lib\n");
	    open (SL,"ls -l $dir/$lib|") or die "humm: $!\n";
	    while (<SL>) {
		# symbolic link
		if (-l "$dir/$lib") {
		    $what = (split(/\s+/,$_))[10];
		    ($path,$value) = stripper("$dir/$lib","lib");
		    $value == 0 ? ($tool = "cp -a") : ($tool = "mv"); 
		    return if errcp(sys("$tool $path $tmp/initrd_mnt$dir")) == 2;
		    ($path,$value) = stripper("$dir/$what","lib");
		    $value == 0 ? ($tool = "cp -a") : ($tool = "mv"); 
		    return if errcp(sys("$tool $path $tmp/initrd_mnt$dir")) == 2;
		}
		# no symbolic link
		else {
		    ($path,$value) = stripper("$dir/$lib","lib");
		    return if errcp(sys("cp -a $path $tmp/initrd_mnt$dir")) == 2;
		}
	    }
	}
	
    } # not busybox
    
    else {

	my $error;

	# busybox binary
	$tool = "cp -a";
	$path = "/home/mttrader/busybox/busybox/busybox";
	return if errcp(sys("$tool $path $tmp/initrd_mnt/sbin")) == 2;	

        #Currently defined functions:
        #        [, ash, bunzip2, busybox, echo, false, gzip, insmod, modprobe,
        #        mount, sh, test, true, umount
	
	my $target = "$tmp/initrd_mnt/sbin/busybox";
	my @busystuff = qw(ash sh bunzip2 echo gzip insmod modprobe mount 
			   umount);
	chdir("$tmp/initrd_mnt/sbin/");
	foreach ( @busystuff ) {

	    symlink("busybox", "$tmp/initrd_mnt/sbin/$_" );

	}

	# uClibc
	mkpath("$tmp/initrd_mnt/usr/i386-linux-uclibc/lib");
	$path = "/usr/i386-linux-uclibc/lib/libuClibc-0.9.5.so";
	return if errcp(sys("$tool $path $tmp/initrd_mnt/usr/i386-linux-uclibc/lib")) == 2;
	sys("chmod 0755  $tmp/initrd_mnt/usr/i386-linux-uclibc/lib/libuClibc-0.9.5.so");
	chdir("$tmp/initrd_mnt/lib");
	symlink("../usr/i386-linux-uclibc/lib/libuClibc-0.9.5.so", "$tmp/initrd_mnt/lib/libc.so.0" );

	$path = "/usr/i386-linux-uclibc/lib/ld-uClibc-0.9.5.so";
	return if errcp(sys("$tool $path $tmp/initrd_mnt/usr/i386-linux-uclibc/lib")) == 2;
	sys("chmod 0755  $tmp/initrd_mnt/usr/i386-linux-uclibc/lib/ld-uClibc-0.9.5.so");
	chdir("$tmp/initrd_mnt/usr/i386-linux-uclibc/lib");
	symlink("ld-uClibc-0.9.5.so", "$tmp/initrd_mnt/usr/i386-linux-uclibc/lib/ld-uClibc.so.0" ); 

    }


    info(0, "Determine run-time link bindings\n");
    # Has a return code of 0 regardless
    # Also, produces false alarms even when it is working.  
    info(1, "Ignore warnings about missing directories\n");
    sys("ldconfig -v -r $tmp/initrd_mnt");

    
##    if ( $fs_type eq "genext2fs" ) {
    if ( $> != 0 ) {
	info(0, "Using genext2fs to contruct the initrd\n");
	# The -D option is unique to the newest unreleased version of 
	# genextfs modified by BusyBox maintainer Erick Andersen
	# August 20, 2001.

	my $error;
	
	# genext2fs doesn't make accurate sized filesystems.
	# this will be user adjustable in the future.
	$size_needed = $size_needed + 1000;

	if (
	    sys("/usr/lib/bootroot/$main::makefs -b $size_needed -d  $tmp/initrd_mnt -D $device_table $tmp/$initrd") !~ 
	    /^0$/ ) {
	    $error = error("Cannot $fs_type filesystem.\n");
	    return "ERROR" if $error && $error eq "ERROR";
	}
	
    }

    else {
	chdir($pwd); 
	info(0, "Umounting loop device, and compressing initrd\n");
	return if errum(sys("umount $tmp/initrd_mnt")) == 2;    
    }

    info(0, "Compressing initrd\n");
    sys("gzip -f9 $tmp/$initrd");

    pb($I,10); # This takes the longest.

    $initrd = $initrd . ".gz";

} # end sub initrd

# This was submitted by Cristian "cretzu."
sub gdkbirdaao  {

    # Guess Default Kernel Boot Image Root Device And Append Options 
    #(gdbirdaao)
    #
    # We return a list with 3 elements:
    #
    #   root device, kernel boot image path and append options
    #
    # The last list element (append options) could be returned as a list
    # of options, but it probably might be cleaner if the caller splitted it.
    #
    # this should cover the following cases:
    #
    # 1. we have a 'root=...' somewhere above the 'image=...' block(s), and
    #    the image block may or may not have a root specified
    #
    # 2. there is no default label, in which case, we take the first one
    #
    # 3. there is a default label, and that's what we pick up
    #

    my $ret_image_path = '';
    my $ret_root_dev = '';
    my $ret_append = '';


    # enough of the annoying "perhaps you are not root"
    # ofcourse this test is always ran assuming lilo is used.
    if ( $> == 0 ) {

	if ( !$container[METHOD] || 
	     $container[METHOD] eq "2 disk compression" ) {

	    if (-e $lilo_conf and !-d $lilo_conf) {

		my @lilo_lines;
		open(LIL, $lilo_conf) or 
		    warn "*** $lilo_conf not found\n";
		@lilo_lines = <LIL>;
		close(LIL);
		chomp(@lilo_lines);

		my $default_label = '';
		my %image_blocks;
		my $image_block_name_prefix = 'ImageBlock';
		my $image_block_no = 1;
		my $image_block_name = '';
		my $root_dev = '';

		for (@lilo_lines) {
		    # ignore comment lines
		    next if m/^\s*[#]/;

				   # cleanup whitespace
				   s/\s*//;
				   s/\s*$//;
				   s/\s*=\s*/=/;

				   # 'default=whatever' returns just a label
				   if (m/default=(.+)\s*/) {
				       $default_label = $1;
				   }
				   # start of a new 'image=<kernel path>' 
				   # image block or similar
				   elsif (m/(image|other)=(.+)\s*/) {
				       $image_block_name = 
					   sprintf("%s%02d",
						   $image_block_name_prefix,
						   $image_block_no);
				       $image_blocks{$image_block_name}
				       {'kernel_image_path'} = $2;
				       $image_blocks{$image_block_name}
				       {'root_device'} = $root_dev;
				       $image_block_no += 1;
				   }
				   # image block label
				   elsif (m/label=(.+)\s*/) {
				       $image_blocks{$image_block_name}
				       {'block_label'} = $1;
				   }
				   # 'root=<root device>'
				   elsif (m#root=/dev/(.+)\s*#) {
					  # inside an image block
					  if ($image_block_name and
					      defined($image_blocks
						      {$image_block_name}
						      {'root_device'})) {
					      $image_blocks{$image_block_name}
					      {'root_device'} = $1;
					  }
					  # loose
					  else {
					      $root_dev = $1 if !$root_dev;
					  }
				      }
				   elsif (m#append=\"(.+)\"#) {
					  $image_blocks{$image_block_name}
					  {'append'} = $1;
				      }
				   else {
				       # Ignore everything else
				   }
			       }

		    # we'll now find the kernel image and root device
		    foreach $image_block_name (sort keys %image_blocks) {
			# Assume there's no specified default label; 
			# take the first
			$ret_root_dev = 
			    $image_blocks{$image_block_name}{'root_device'}
			if !$ret_root_dev;
			$ret_image_path = 
			    $image_blocks{$image_block_name}
			{'kernel_image_path'}
			if !$ret_image_path;
			$ret_append = 
			    $image_blocks{$image_block_name}{'append'}
			if !$ret_append;

			# do we have a default kernel?
			if (defined $image_blocks{$image_block_name}
			    {'block_label'}) {
			    if ($image_blocks{$image_block_name}
				{'block_label'} eq $default_label) {
				# Found the block match for the default label
				$ret_root_dev = 
				    $image_blocks{$image_block_name}
				{'root_device'};
				$ret_image_path = 
				    $image_blocks{$image_block_name}
				{'kernel_image_path'};
				$ret_append = $image_blocks
				{$image_block_name}{'append'};
				last;
			    }
			}
		    }
		}


	    }  # if METHOD eq 2 disk compression

	}  # if not root
  
	# and some a small portion of paranoia
	$ret_root_dev = 'hda1' if !$ret_root_dev;

	return ($ret_root_dev, $ret_image_path, $ret_append);

} # end sub gdkbirdaao

###########
# Mtab area
###########

sub mtab_window {
# Will just use a dialog box.
    my ($dialog,$error,$count,$pattern) = @_;

    if (not defined $mtab) {
    $mtab = Gtk::Dialog->new();
    $mtab->signal_connect("destroy", \&destroy_window, \$mtab);
    $mtab->signal_connect("delete_event", \&destroy_window, \$mtab);
    $mtab->set_title("gBootRoot: Device check");
    $mtab->border_width(15);
    $mtab->set_position('center');
    my $label = Gtk::Label->new($dialog);
    $label->set_justify( 'left' );
    $label->set_pattern("_________") if $pattern == 9;
    $label->set_pattern("_____") if $pattern == 5;
    $mtab->vbox->pack_start( $label, $true, $true, 15 );
    $label->show();
    my $button = Gtk::Button->new("OK");
    $button->signal_connect("clicked", \&mtab_check, $count);
    $button->can_default(1);
    $mtab->action_area->pack_start($button, $false, $false,0);
    $button->grab_default;
    $button->show;
    $button = Gtk::Button->new("Cancel");
    $button->signal_connect("clicked", sub { destroy $mtab; 
					     $mtab = 2 if $count == 3; } );
    $mtab->action_area->pack_start($button, $false, $false,0);
    $button->show;
    }
     if (!visible $mtab) {
         show $mtab;
     }
     else {
        destroy $mtab;
        mtab_window($dialog,$error,$count) if $error == 0;
     }

} # end sub mtab_window

sub mtab {

# /proc/mount could be used, but maybe there is no /proc
# Press OK when drive and storage medium are ready.  The drive should not
# be mounted.

  if ($_[0] == 0) {
    my $dialog = "BOOTDISK:\n"
             ."Press OK when the drive and its storage medium is ready.\n"
             ."The Boot Disk will now be made.  All data already on\n"
                 ."the storage medium will be erased.";
    mtab_window($dialog,1,$_[0],9);
  }
  elsif ($_[0] == 1) {
    my $dialog = "ROOTDISK:\n"
             ."Press OK when the drive and its storage medium is ready.\n"
             ."The Root Disk will now be made.  All data already on\n"
                 ."the storage medium will be erased.";
    mtab_window($dialog,1,$_[0],9);
  }
  elsif ( $_[0] == 3 ) {
    my $dialog = "LILO:\n"
             ."Lilo will now be executed.  In order for the bootloader\n"
             ."to work properly you need superuser privileges to run lilo.\n"
             ."See FAQ for ways to accomplish this.  Even if you don't have\n"
	     ."privileges, the program will continue to make a boot disk.\n"
             ."Lilo may be ran as root at a later time on the boot disk.";
    mtab_window($dialog,3,$_[0],5);
  }


} # end sub mtab


sub mtab_check {

    my($widget,$count) = @_;

    my $dialog;
    my $error = 1;
    
    my $fs_type = (split(/\s/,$main::makefs))[0];

# Check to see if $device is mounted

    if ( $count < 3 ) {
	open (MTAB, "/etc/mtab") or die "no mtab!\n";
	while (<MTAB>) {

	    if  ($count == 1) {
		
		# ROOT_DEVICE
		if ( m,$entry_advanced[3], ) {
		    # Safety Check:
		    $dialog = 
			"Please umount the device first.\nPress OK when you are ready.";
		    $error = 0;
	    }
		
	    }

	    elsif ( $count == 0  ) {

		# BOOT_DEVICE
		if (m,$entry_advanced[0],) {
		    # Safety Check:
		    $dialog = 
			"Please umount the device first.\nPress OK when you are ready.";
		    $error = 0;
		}
		
	    }
	    
	}
	close(MTAB);
	
    }

    mtab_window($dialog,$error,$count) if $error == 0;

    # Make sure the drive and storage medium are accessible
    # Keep asking until they are.
##    if ( $error == 1 && $fs_type ne "genext2fs" ) {
    if ( $error == 1 && $> == 0 ) {
	destroy $mtab;

	# $size has to be determined by boot disk or root disk

	# ROOT_DEVICE - test with a loop device
	if ($count == 1) {
	    sys("mke2fs -F -m0 -i8192 $entry_advanced[3] $root_device_size");
	}
	
	
	# BOOT_DEVICE
        elsif ($count == 0) {
	    sys("mke2fs -F -m0 -i8192 $entry_advanced[0] $container[SIZE]");
	}
	
	if ($? != 0) {
	    $dialog = "gBootRoot: ERROR: You need to insert a disk\n";
	    mtab_window($dialog,$error,$count);
	    return;
	}
	
	# ROOT_DEVICE
	if ($count == 1) {
	    if ( $> == 0 ) {
		return if errm(sys("mount -t ext2  $entry_advanced[3] $mnt")) == 2;
	    }
	    else {
		return if errm(sys("mount $mnt")) == 2;
	    }
	}
	
	# BOOT_DEVICE
	elsif ($count == 0) {
	    if ( $> == 0 ) {
		return if errm(sys("mount -t ext2  $entry_advanced[0] $mnt")) == 2;
	    }
	    else {
		return if errm(sys("mount $mnt")) == 2;
	    }
	}


	lilo_put_it_together() if $count == 0;  # mtab(1) runs from here
	device2() if $count == 1;

    } # if $error == 1

##    if ( $fs_type eq "genext2fs" && $error == 1 ) {
    if ( $> != 0 && $error == 1 ) {

	destroy $mtab;
	lilo_put_it_together() if $count == 0;  # mtab(1) runs from here
	device2() if $count == 1;

    }

    # Warned the user about something
    if ( $error == 3 ) {
	$mtab->destroy;
    }


} # end sub mtab_check

##################
# Here Doc Section
##################

# This should be user accessible
# This should be called linuxrc.
sub initrd_heredoc {

    my($broot_image,$root_device) = @_;

# Here's where the initrd is put together using a loop device
# HEREDOC
my $initrd_exec = << "INITRD";
#!/sbin/ash

export PATH=/bin:/sbin:/usr/bin:

echo Preparing to setup ramdisk.

# Before busybox experimentation this was the state of things:
# mount -o remount,rw / 2>/dev/null
# echo Mounting proc...
# mount -t proc none /proc

echo Mounting proc...
mount -t proc none /proc

echo Mounting $root_device readable-writable
mount -o remount,rw $root_device / 

echo -n 'Please insert the root floppy, and press [Enter]: '
read ENTER

echo Mounting $root_device readonly ...

# -t causes busybox to fail here, -o doesn't help much either.
#mount -o ro -t ext2 $root_device /mnt
mount $root_device /mnt

echo -n Copying new root to ramdisk .. please wait ...
$compress -cd /mnt/$broot_image > /dev/ram1
echo done.

echo -n Unmounting $root_device ...
umount /mnt
echo done.

# Using change_root, eventually may change to pivot_root or
# give the user the choice.

echo Changing to the new root.
echo 257 >/proc/sys/kernel/real-root-dev

echo -n Unmounting proc ...
umount /proc
echo done.

echo Continuing normal boot procedure from ramdisk.
INITRD

    return $initrd_exec;

} # end sub initrd_heredoc

sub brlilo {

    my ($device) = @_;
    $entry_advanced[2] ? $entry_advanced[2] = $entry_advanced[2] 
                       : $entry_advanced[2] = $container[ABS_APPEND];

# HEREDOC
my $brlilo = << "LILOCONF";
boot = $device
message = message
delay = 50
vga = normal
install = /boot/boot.b
map = /boot/map
backup = /dev/null
compact

# bootdisk
image = kernel
append = "load_ramdisk=1 debug $entry_advanced[2]"
initrd = $initrd
root = $device
label = bootdisk
read-write

# normalboot
image = kernel
append = "$entry_advanced[2]"
root = /dev/$norm_root_device
label = normalboot
read-only
LILOCONF

    return $brlilo;

} # end sub brlilo


sub brlilo_non_root {

    my ($device) = @_;
    $entry_advanced[2] ? $entry_advanced[2] = $entry_advanced[2] 
                       : $entry_advanced[2] = $container[ABS_APPEND];

# HEREDOC
my $brlilo = << "LILOCONF";
boot = $device
message = $old_mount/message
delay = 50
vga = normal
install = $old_mount/boot/boot.b
map = $old_mount/boot/map
backup = /dev/null
compact

# bootdisk
image = $old_mount/kernel
append = "load_ramdisk=1 debug $entry_advanced[2]"
initrd = $old_mount/$initrd
root = $device
label = bootdisk
read-write

# normalboot
#image = kernel
#append = "$entry_advanced[2]"
#root = /dev/$norm_root_device
#label = normalboot
#read-only
LILOCONF

    return $brlilo;

} # end sub brlilo_non_root


sub message {
# HEREDOC
my $message = << "MESSAGE";

gBootRoot $version $date GNU GPL
mailto:  Jonathan Rosenbaum <freesource\@users.sourceforge.net>

Press [Ctrl] to see the lilo prompt.

Press [Tab] to see a list of boot options.

bootdisk   = This will boot a compressed root filesystem
             on another floppy.
normalboot = This will boot up a specified filesystem.
             default: /dev/$norm_root_device
             Use root=/dev/(h or s)dXX
                                 h = IDE Drive
                                 s = SCSI Drive

Trouble:  Do not forget boot: option single
Fix a filesystem:  e2fsck /dev/(h or s)dXX
Bad superblock:    e2fsck -b 8192 /dev/(h or s)dXX

MESSAGE

    return $message;

} # end sub message

sub help {

<< "HELP";

gBootRoot $version $date GNU GPL

Email contact -> Jonathan Rosenbaum <freesource\@users.sourceforge.net>

Homepage -> http://gbootroot.sourceforge.net
Submit a Bug -> http://sourceforge.net/bugs/?group_id=9513
Devel. & Releases  -> http://sourceforge.net/projects/gbootroot

Places to talk:

gbootroot-{devel,user} mailing lists -> http://sourceforge.net/mail/?group_id=9513
Help forum -> http://sourceforge.net/forum/forum.php?forum_id=29639
Open forum -> http://sourceforge.net/forum/forum.php?forum_id=29638

gbootroot documentation and FAQ:

/usr/share/doc/gbootroot/html/index.html

How to Use gBootRoot:

The most important button to familiarize yourself with is the Submit button 
which starts the whole process; dialogs are presented as the process 
continues asking you if you want to continue "OK" or stop "Cancel".

The first row allows you to choose a Boot Method.  Clicking on the menu on 
the right selects the Boot Method.

The second row allows you to select the kernel for the Boot/Root set.  You
may either use the file selector button on the right hand side, or you may
type in the location on the left hand side.

The third row allows you to select the compressed filesystem you are
providing, using either of the two ways mentioned before.  You may use a
pre-made root filesystem or you may create one using one of the Methods 
provided in the Advanced Root Section.

The fourth row allows you to select the device you want to use.  The default
device is the first floppy disk (/dev/fd0).

The fifth row allows you to choose the size of the device being used.  The
default size of 1440 assumes you are using a floppy drive (Note: You may want 
to experiment with 1722 which works fine with many floppy drives.), but can
be used with other sized devices like tape drives.   Click on the 
appropriate radio button to choose either gzip or bzip2 compression if the 
program doesn't automatically detect it.

The slider bar on the right allows the output of the verbosity box to be 
changed from the highest (2) to the lowest setting (1) or to be turned off (0)
or on again.  At times it may be advantageous to turn off the verbosity box 
since large quantities of output to this box may cause gbootroot to use too 
much cpu power; however, output may still be found in the text file "verbose" 
in /tmp/gbootroot_tmp'time-date'.  

Advanced Boot Section:

Libraries & Binaries & Modules check boxes:  Turn off and on the
stripping of symbols.   The stripping behavior for libraries may be
changed by clicking on the right mouse button to change --strip-debug
to --strip-all.   Binaries default to --strip-all and Modules default to
--strip-debug.

"Devel Device"  If the device used for development is different than the 
actual boot device, use this field to indicate that device.  You will have to 
run lilo -v -C brlilo.conf -r "device mount point" manually at a later time 
on the actual boot device.

"Opt. Device"  Add devices to the boot disk which are necessary for the
kernel to function properly.  Put a space between each device.  For instance,
/dev/fb0 for frame buffer devices.

"append ="  Add append options to brlilo.conf.  If you are using a frame
buffer device you could add something like video=matrox:vesa:402,depth:16.

"Kernel Module"  Add the modules found in /lib/modules/kernel-version 
which are necessary for the Boot Method to work properly.   If these 
modules aren't found in the modules directory it is assumed that they 
either are in the kernel or they do not exist.   In the case of 2 disk 
compression, floppy needs to be included in the kernel or included as a 
module.    Kmod inserts the modules, and kmod needs to be built into the 
kernel along with initrd and ramdisk."

"Kernel Version"  Override the kernel version number found in the
kernel header.  This will change the /lib/modules/kernel-version
directory.

System.map:  When a non-running kernel is chosen it is important to 
include a copy of that kernel's System.map file so that depmod can
use the correct set of kernel symbols to resolve kernel references 
in each module.  This can be found in the kernel's source code after
compilation. 

Advanced Root Section:

"Root Device"  This is the device used for the root filesystem when 
constructing the Boot/Root set.  You may choose a device which is different 
than the Boot device, but presently only floppy devices are supported.

"Root Device Size"  The size of the actual media used for the Root Device.

"Root Filename"  The name give to the root filesystem when initially made
in the temporary creation location.  The save button allows the creation to
be saved in the permanent default location when the Accept button is pressed. 

"Filesystem Size"  Root Methods make the filesystem the size which is 
specified here.

"Compression"  Off by default to allow user-mode-linux testing.  Turn on 
compression when you are ready to use a Boot Method which requires compression.

"Method"  The root filesystem creation method.

"Template"  The template associated with a Root Method.  Not all Root Methods
have templates.

"Generate"  This puts the chosen Root Method in action.

"UML"  Abbreviation for user-mode-linux.  This is a linux kernel which runs on
top of the host system's linux kernel and allows a you run a live root 
filesystem.  

"Accept"  This accepts the created root filesystem if it is found in the 
temporary creation directory.  The UML box and the main section will now 
reflect the path to this root filesystem.  You can now test with the UML 
button or put together a complete Boot/Root set with the Submit button.

Advanced Kernel Section:

Still in development.


Little things you may want to know:

* gBootRoot requires ash for initrd.  Ash is a feather weight version of Bash.

HELP

}

1;
