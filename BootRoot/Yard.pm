#############################################################################
##
##  Yard.pm combining
##  MAKE_ROOT_FS, CHECK_ROOT_FS, and YARD_UTILS.PL by Tom Fawcett
##  Copyright (C) 1996,1997,1998  Tom Fawcett (fawcett@croftj.net)
##  Copyright (C) 2000,2001 Modifications by the gBootRoot Team
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
#####
##
##  This is a heavily modified version of several scripts from the Yard
##  Suite (v2.0) by Tom Fawcett.  The modifications allow gBootRoot to use 
##  Yard as a Method.
##
##############################################################################

package BootRoot::Yard;
use vars qw(@ISA @EXPORT %EXPORT_TAGS);
use Exporter;
@ISA = qw(Exporter);
@EXPORT =  qw(start_logging_output info kernel_version_check verbosity 
              read_contents_file extra_links library_dependencies hard_links 
              space_check create_filesystem find_file_in_path sys 
              text_insert error logadj *LOGFILE which_tests create_fstab); 

use strict;
use File::Basename;
use File::Path;
use FileHandle;
use Cwd; #  I am not even sure if this is being used here now
use English;  # I think this can be ditched for portability
use File::Find; # used by check_root_fs
use BootRoot::Error; 

my (%Included, %replaced_by, %links_to, %is_module, %hardlinked, 
    %strippable, %lib_needed_by, @Libs);
my $cf_line = 0;
my $BLKGETSIZE_ioctl = 4704; 
my $BLKFLSBUF_ioctl  = 4705; 
my $EXT2_BLOCK_SIZE  = 1024; 
my $INODE_SIZE       = 1024;
my $objcopy = "objcopy";
my($Warnings) = 0;
my $verbosity;
my ($text_insert,$red,$blue); 
my $logadj;
my ($device, $mount_point);
my $contents_file_tmp; # Checks for template name change

# This solves an annoying problem with the new Perl-5.6 built in glob,
# allowing earlier versions of Perl to run.
# But the new glob is a good thing for this program since it doesn't have to
# depend on outside programs, making Tom's test_glob() history.
BEGIN {
    if ($] =~ /006/) {
	require File::Glob;
    }
}

STDOUT->autoflush(1);

$SIG{__WARN__} = 
    sub { warn @_ unless $_[0] =~ /Subroutine [\w:]+ redefined/io };

sub warning {
  info(0, "Warning: ", @_);
  $Warnings++;
}

sub verbosity { $verbosity = $_[0]; }
sub text_insert { $text_insert = $_[0]; $red = $_[1]; $blue = $_[2]; }
sub logadj { $logadj = $_[0]; }

## REQUIRES $kernel opt. $kernel_version
sub kernel_version_check {

    my($kernel,$kernel_version) = @_;
    
    if (defined($kernel_version)) {
	#  Check to see if it agrees
	my($version_guess) = kernel_version($kernel);
	if ($version_guess ne $kernel_version) {
            ## Is this really necessary, it can be assumed a person knows
            ## what they are doing.
	    info(0, 
          "You declared kernel $kernel to be version $kernel_version\n",
	    "even though a probe says $version_guess.",
	    "  I'll assume you're right.\n")
	}
	$ENV{'RELEASE'} = $kernel_version;

    } elsif (defined($ENV{'RELEASE'} = kernel_version($kernel))) {
	info(0, "\nVersion probe of $kernel returns: $ENV{'RELEASE'}\n");
    } else {
	warning "Can't determine kernel version of $kernel\n";
	my($release) = `uname -r`;
	if ($release) {
	    chomp($release);
	    info(0, "Will use version of current running kernel ($release)\n",
		 "Make sure this is OK\n");
	    $ENV{'RELEASE'} = $release;
	} else {
	    my $error = error(
            "And can't determine running kernel's version either!\n");
	     return "ERROR" if $error && $error eq "ERROR";
	}
    }

} # end sub kernel_version_check 

## This checks lib/modules/$version for rd.o, ext2.o, floppy.o
## Perhaps just extra stuff, this could be made real fancy, too.
#@@warn_about_module_dependencies($ENV{'RELEASE'});

############################
#####  READ IN CONTENTS FILE
############################
## Uses info, error, cf_warn, make_link_absolute, make_link_relative, 
## cf_die, must_be_abs, replaced_by, yard_glob 
## REQUIRES $contents_file
sub read_contents_file {

    my ($contents_file) = @_;
    my $error;

    # It's a good idea to clear the text buffer in the verbosity box
    $text_insert->backward_delete($text_insert->get_length());

    # If the template changes it is time to clear all the values.
    if ($contents_file_tmp && $contents_file_tmp ne $contents_file) {
	undef %Included; 
	undef %replaced_by;
	undef %links_to;
	undef %is_module;
	undef %hardlinked;
	undef %strippable;
	undef %lib_needed_by;
	undef @Libs;
    }
    $contents_file_tmp = $contents_file;

    info(0, "\n\nPASS 1:  Reading $contents_file");
    info(0, "\n");

    open(CONTENTS, "<$contents_file") or 
        ($error = error("$contents_file: $!"));
    return "ERROR"if $error && $error eq "ERROR";

    my($line);

  LINE: while (defined($line = <CONTENTS>)) {

      my(@files);
      $cf_line++;
      chomp $line;
      $line =~ s/[\#%].*$//;	# Kill comments
      next if $line =~ /^\s*$/;	# Ignore blank/empty line

      $line =~ s/^\s+//;		# Delete leading/trailing whitespace
      $line =~ s/\s+$//;

      if ($line =~ /->/) {	#####  EXPLICIT LINK
	  if ($line =~ /[\*\?\[]/) {
	      cf_warn($line, "Can't use wildcards in link specification!");
	      next LINE;
	  }

	  ## I decided to switch this from ($file,$link) to ($link,$file)
	  ## to make this more intuitive for users so something like
	  ## ls -l /bin/sh which ='s /bin/sh -> /bin/bash is literal 
	  ## .. before it was backwards.

	  my($link, $file) = $line =~ /^(\S+)\s*->\s*(\S+)\s*$/;
	  if (!defined($link)) {
	      cf_warn($line, "Can't parse this link");
	      next LINE;
	  }
	  #####  The '->' supersedes file structure on the disk, so don't
	  #####  call include_file until pass two after all explicit links
	  #####  have been seen.

	  ## find_file_in_path($file) changed to find_file_in_path($link)

	  my($abs_file) = find_file_in_path($link);
	  $Included{$abs_file} = 1 if $abs_file;

	  ####   Have to be careful here.  Record the rel link for use
	  ####   in setting up the root fs, but use the abs_link in @files
	  ####   so next loop gets any actual files.
	  my($abs_link) = make_link_absolute($abs_file, $link);
	  my($rel_link) = make_link_relative($abs_file, $link);
	  $links_to{$abs_file} = $rel_link if $abs_file;
	  info(1, "$line links $abs_file to $rel_link\n") if $abs_file;
	  @files = ($abs_link);
	  
      } elsif ($line =~ /<=/) {	#####  REPLACEMENT SPEC
	  $error = cf_die($contents_file, $line, 
              "Can't use wildcard in replacement specification") if
	       $line =~ /[\*\?\[]/;
	  return "ERROR" if $error && $error eq "ERROR";

	  my($file, $replacement) = $line =~ /^(\S+)\s*<=\s*(\S+)\s*$/;
	  #$replacement = "$main::global_yard/$replacement";

	  if (!defined($replacement)) {
	      cf_warn($contents_file, $line, 
                      "Can't parse this replacement spec");
	      next LINE;

	  } else {
	      must_be_abs($file);
	      (-d $file) and cf_warn($contents_file, $line, 
                                     "left-hand side can't be directory");
	      my($abs_replacement) = find_file_in_path($replacement,$main::global_yard);
	      if (!(defined($abs_replacement) and -e $abs_replacement)) {
		  cf_warn($contents_file, $line, "Can't find $replacement");
		  
	      } elsif ($replacement =~ m|^/dev/(?!null)|) {
		#  Allow /dev/null but no other devices
		cf_warn($contents_file, $line, 
                        "Can't replace a file with a device");

	      } else {
		  $replaced_by{$file} = $abs_replacement;
		  $Included{$file} = 1;
          }

      next LINE;
    } #  End of replacement spec

    } elsif ($line =~ /(<-|=>)/) {
    cf_warn($contents_file, $line, "Not a valid arrow.");
    next LINE;

    } else {

	@files = ();
	my($expr);
	for $expr (split(' ', $line)) {
	    my(@globbed) = yard_glob($expr);
	    if ($#globbed == -1) {
		cf_warn($contents_file, $expr, 
                        "Warning: No files matched $expr");
	    } elsif (!($#globbed == 0 and $globbed[0] eq $expr)) {
		info(1, "Expanding $expr to @globbed\n");
	    }
	    push(@files, @globbed);
	}
    }

      my($file);

    FILE: foreach $file (@files) {

	if ($file =~ m|^/|) {	#####  Absolute filename

	    # This complains for non-existent $files for some reason.
	    # like /dev/pilot, but can't replicate
	    if (-l $file and readlink($file) =~ m|^/proc/|) {
		info(1, "Recording proc link $file -> ", readlink($file), 
                     "\n");
		$Included{$file} = 1;
		$links_to{$file} = readlink($file);

	    } elsif (-e $file) {

		$Included{$file} = 1;

	    } elsif ($file =~ m|^$::oldroot/(.*)$|o and -e "/$1") {
		### Don't complain about links to files that will be mounted
		### under $oldroot, the hard disk root mount point.
		next FILE;

	    } else {
		cf_warn($contents_file, $line, 
                        "Absolute filename $file doesn't exist");
	    }

	} else {		##### Relative filename
	    my($abs_file) = find_file_in_path($file);
	    if ($abs_file) {
		info(1, "Found $file at $abs_file\n");
		$Included{$abs_file} = 1;
	    } else {
		cf_warn($contents_file, $line, 
                        "Didn't find $file anywhere in path");
	    }
	}
    }				# End of FILE loop
  }				# End of LINE loop

    info(0, "\nDone with $contents_file\n\n");
    close(CONTENTS) or ($error = error("close on $contents_file: $!"));
    return "ERROR"if $error && $error eq "ERROR";

} # end read_contents_file


# Uses include_file
sub extra_links {

    my ($contents_file) = @_;
    
    info(0, "PASS 2:  Picking up extra files from links...\n");

    for (keys %Included) {
        # watch for "" - GBteam
	include_file($contents_file, $_) if $_ ne "";
    }

    info(0, "Done.\n\n");
}


sub library_dependencies {

    my ($contents_file) = @_;
    my $error;

    info(0, "PASS 4:  Checking library dependencies...\n");
    info(1, "(Ignore any 'statically linked' messages.)\n");

    #  Normal file X:  X in %Included.
    #  X -> Y:  X in %links_to, Y in %Included
    #  X <= Y:  X in %Included and %replaced_by

    my($file);
    foreach $file (keys %Included) {

	##### Use replacement file if specified
	$file = $replaced_by{$file} if defined($replaced_by{$file});

	##### Skip links (target will be checked)
	next if defined($links_to{$file}); # Symbolic (declared)
	next if -l $file;		     # Symbolic (on disk)

	my($file_line) = `file $file`;
	#####  See whether it's strippable and make a note.
	#####  This will prevent us from wasting time later running objcopy
	#####  on binaries that are already stripped.
	if ($file_line =~ m/not stripped/) {
	    $strippable{$file} = 1;
	}
	#####  See whether it's a module and mark the info for later
	#####  so that we strip it correctly.
	if ($file_line =~ m/relocatable/) {
	    info(1, "Marking $file as a module\n");
	    $is_module{$file} = 1;

	} elsif ($file_line =~ m/shared object/) {
	    #####  Any library (shared object) seen here was explicitly 
            #####  included by the user.

	    push(@{$lib_needed_by{$file}}, "INCLUDED BY USER");
	}

	if (-f $file and -B _ and -x _ and $file_line =~ /executable/) {

	    #####  EXECUTABLE LOADABLE BINARY
	    #####  Run ldd to get library dependencies.
	    my $line;
	    foreach $line (`ldd $file`) {
		my($lib) = $line =~ / => (\S+)/;
		next unless $lib;
		my($abs_lib) = $lib;

		if ($lib =~ /not found/) {
		    warning "File $file needs library $lib," . 
                            " which does not exist!";
		} else {

		    #####  Right-hand side of the ldd output may be 
                    #####  a symbolic link.

		    #####  Resolve the lib absolutely.
		    #####  include_file follows links and adds each file;
		    #####  the while loop makes sure we get the last.
		    $abs_lib = $lib;
		    include_file($contents_file, $lib);
		    while (1) {
			if (defined($links_to{$abs_lib})) {
			    $abs_lib = make_link_absolute($abs_lib,
			    $links_to{$abs_lib});
			}
			if (defined($replaced_by{$abs_lib})) {
			    $abs_lib = $replaced_by{$abs_lib};
			}
			last unless -l $abs_lib;
			my($link) = readlink($abs_lib) or
			    ($error = error("readlink($abs_lib): $!"));
			return "ERROR"if $error && $error eq "ERROR";
			$abs_lib = make_link_absolute($abs_lib, $link);

		    }
		}
		if (!defined($lib_needed_by{$abs_lib})) {
		    info(0, "\t$abs_lib\n");
		}
		push(@{$lib_needed_by{$abs_lib}}, $file);
	    }
	}
    }

    ####################################
    #####  Check libraries and loader(s)
    ####################################
    (@Libs) = keys %lib_needed_by;

    my($seen_ELF_lib, $seen_AOUT_lib);
    my(%full_name);

    if (@Libs) {
	info(1, "\nYou need these libraries:\n");

	my($lib);
	foreach $lib (@Libs) {
	    my($size)      = bytes_to_K(-s $lib);
	    my($line)      = " " x 15;
	    my($file_output) = `file $lib`;

	    if ($file_output =~ m/symbolic link/) {
		$error = error(
                      "Yiiiiii, library file $lib is a symbolic link!\n",
		      "This shouldn't happen!\n",
		      "Please report this error(to the Yard author\n");
		 return "ERROR"if $error && $error eq "ERROR";
	    }

	    my($lib_type)  = $file_output =~ /:\s*(ELF|Linux)/m;

	    #####  All libraries are strippable
	    $strippable{$lib} = 1;

	    info(1, "$lib (type $lib_type, $size K) needed by:\n");

	    my($binary);
	    for $binary (sort map(basename($_), @{$lib_needed_by{$lib}})) {
		if (length($line) + length($binary) > 78) {
		    info(1, $line, "\n");
		    $line = " " x 15;
		}
		$line .= $binary . " ";
	    }
	    info(1, $line, "\n") if $line;

	    if (!($seen_ELF_lib and $seen_AOUT_lib)) {

		#####  Check library to make sure we have the right loader.
		#####  (A better way is to do "ldconfig -p" and parse the output)
		#####  Strings from /usr/lib/magic of file 3.19

		if (!defined($lib_type)) {
		    $error = error(
                          "Didn't understand `file` output for $lib:\n",
			  `file $lib`, "\n");
		     return "ERROR"if $error && $error eq "ERROR";

		} elsif ($lib_type eq 'ELF') {
		    $seen_ELF_lib = 1;

		} elsif ($lib_type eq 'Linux') { # ie, a.out
		    $seen_AOUT_lib = 1;
		}
	    }

	    #####  See if some other version of this library file is
	    #####  being loaded, eg libc.so.3.1.2 and libc.so.5.2.18.
	    #####  Not an error, but worth warning the user about.

	    my($lib_stem) = basename($lib) =~ /^(.*?\.so)/;
	    if (defined($full_name{$lib_stem})) {
		warning "You need both $lib and $full_name{$lib_stem}\n",
		"Check log file for details.\n";
	    } else {
		#####  eg, $full_name{"libc.so"} = "/lib/libc.so.5.2.18"
		$full_name{$lib_stem} = $lib;
	    }
	}
    }

    info(1, "\n");
    if ($seen_ELF_lib) {
	#  There's no official way to get the loader file, AFAIK.
	#  This expression should get the latest version, and Yard will grab any
	#  hard-linked file.
	my($ld_file) = (yard_glob("/lib/ld-linux.so.?"))[-1];	# Get last one
	if (defined($ld_file)) {
	    info(1, "Adding loader $ld_file for ELF libraries\n");
	    include_file($contents_file, $ld_file);
	} else {
	    info(0, "Can't find ELF loader /lib/ld-linux.so.?");
	}
    }
    if ($seen_AOUT_lib) {
	#  Was: yard_glob("/lib/ld.so*")
	#  Same as above, but ld.so seems to have no version number appended.
	my($ld_file);
	foreach $ld_file (yard_glob("/lib/ld.so")) {
	    info(1, "Adding loader $ld_file for a.out libraries\n");
	    include_file($contents_file, $ld_file);
	}
    }

    info(0, "Done\n\n");

} # end sub library_dependencies

sub hard_links {

    info(0, "PASS 3:  Recording hard links...\n");

    #####  Finally, scan all files for hard links.

    my($file);
    foreach $file (keys %Included) {

	next if $links_to{$file} or $replaced_by{$file};
	#####  $file is guaranteed to be absolute and not symbolically linked.

	#####  Record hard links on plain files
	if (-f $file) {
	    my($dev, $inode, $mode, $nlink) = stat(_);
	    if ($nlink > 1) {
		info(1,"$file is hardlinked\n");
		$hardlinked{$file} = "$dev/$inode";
	    }
	}
    }

    info(0, "Done.\n\n");

} # end sub hard_links

##########################

# GBteam added stripped file size check.
sub space_check {

    
    info(0, "Checking space needed.\n");

    # For libs [obj_count  1 = "all" 0 = "debug"]
    my ($fs_size, $strip_lib, $strip_bin, 
        $strip_module, $obj_count, $tmp) = @_;

    my($total_bytes) = 0;
    my(%counted);

    # %Included synopsis
    # /path/file (1|symlink)
    # %replaced_by /path/file /path/file .. <= 
    # %links_to    /path/file-symnlink   actual-file
    # %hardlinked  /path/file  dev/inode -> stat()

    my ($file);
    foreach $file (keys %Included) {

	my $not_stripped = `file $file`;
	my $filename = basename($file);
      
	my($replacement, $devino);
	if ($replacement = $replaced_by{$file}) { 
	    ## strip count for replace
	    ## Check for libraries %lib_needed_by, modules %is_module, 
	    ## and everything else if strippable, and strip is chosen
	    ## and for lib two states are possible
	    #####  Use the replacement file instead of this one.  In the
	    #####  future, improve this so that replacement is resolved WRT
	    #####  %links_to
	    if ($strip_lib) {
		my $not_stripped = `file $file`;
		if ($not_stripped =~ m,not stripped,) {
		    if ($obj_count == 0) {
			if ($lib_needed_by{$replacement}) {
			    my $tmp_strip = "$tmp/" . basename($replacement);
			 sys("objcopy --strip-debug $replacement $tmp_strip");
			    info(1, 
                            "Counting bytes of replacement $replacement", 
			     " (STRIPPED DEBUG)\n"); 
			    $total_bytes += bytes_allocated($tmp_strip);
			    unlink($tmp_strip);
			    next;
			}
		    }
		    elsif ($obj_count == 1) {
			if ($lib_needed_by{$replacement}) {
			    my $tmp_strip = "$tmp/" . basename($replacement);
			 sys("objcopy --strip-debug $replacement $tmp_strip");
			    info(1, 
                            "Counting bytes of replacement $replacement",
			    " (STRIPPED ALL)\n"); 
			    $total_bytes += bytes_allocated($tmp_strip);
			    unlink($tmp_strip);
			    next;
			}
		    }
	        }
	    }

	    if ($strip_module) {
		my $not_stripped = `file $replacement`;
		if ($not_stripped =~ m,not stripped,) {
			if ($is_module{$replacement}) {
			    my $tmp_strip = "$tmp/" . basename($replacement);
			 sys("objcopy --strip-debug $replacement $tmp_strip");
			    info(1, 
                            "Counting bytes of replacement $replacement",
			    " (STRIPPED DEBUG)\n"); 
			    $total_bytes += bytes_allocated($tmp_strip);
			    unlink($tmp_strip);
			    next;
			}
	        }
	    }

	    if ($strip_bin) {
		my $not_stripped = `file $replacement`;
		if ($not_stripped =~ m,not stripped,) {
		    my $tmp_strip = "$tmp/" . basename($replacement);
		    sys("objcopy --strip-all $replacement $tmp_strip");
		    info(1, "Counting bytes of replacement $replacement",
		    " (STRIPPED ALL)\n"); 
		    $total_bytes += bytes_allocated($tmp_strip);
		    unlink($tmp_strip);
		    next;
	        }
	    }
	    info(1, "Counting bytes of replacement $replacement\n");
	    $total_bytes += bytes_allocated($replacement);

	} elsif (-l $file or $links_to{$file}) { ## no strip
	    #####  Implicit or explicit symbolic link.  Only count link size.
	    #####  I don't think -l test is needed.
	    my($size) = (-l $file) ? length(readlink($file))
		: length($links_to{$file});
	    info(1, "$file (link) size $size\n");
	    $total_bytes += $size;
	} elsif ($devino = $hardlinked{$file}) {
	    #####  This file is hard-linked to another.  We don't necessarily
	    #####  know that the others are going to be in the file set.  
            #####  Count the first and mark the dev/inode so we don't count 
            #####  it again.  .. pretty cool
	    if (!$counted{$devino}) {  ## 1 strip for hardlinked file
		if ($strip_bin) {
		    my $not_stripped = `file $file`;
		    if ($not_stripped =~ m,not stripped,) {
			my $tmp_strip = "$tmp/" . basename($file);
			sys("objcopy --strip-all $file $tmp_strip");
			info(1, "Counting ", -s $tmp_strip, 
			     " bytes of hard-linked file $tmp_strip",
			     " (STRIPPED ALL)\n");      
			$total_bytes += bytes_allocated($tmp_strip);
			unlink($tmp_strip);
			next;
		    }
		}
		info(1, "Counting ", -s _, 
		     " bytes of hard-linked file $file\n");      
		$total_bytes += bytes_allocated($file);
		$counted{$devino} = 1;
	    } else {
		info(1, "Not counting bytes of hard-linked file $file\n");
	    }

	} elsif (-d $file) { ## no strip
	    $total_bytes += $INODE_SIZE;
	    info(1, "Directory $file = ", $INODE_SIZE, " bytes\n");
	} elsif ($file =~ m|^/proc/|) { ## no strip
	    #####  /proc files screw us up (eg, /proc/kcore), and there's no
	    #####  Perl file test that will detect them otherwise.
	    next;

	} elsif (-f $file) { ## 
	    ## At this point hardlinked, dirs, replaced_by and /proc have
	    ## been filtered out.  If strip is chosen
	    ## check for libraries (%lib_needed_by), modules (%is_module), 
	    ## and everything else if strippable.  For lib two states are
	    ## posible
	    #####  Count space for plain files
	    if ($strip_lib) {
		my $not_stripped = `file $file`;
		if ($not_stripped =~ m,not stripped,) {
		    if ($obj_count == 0) {
			if ($lib_needed_by{$file}) {
			    my $tmp_strip = "$tmp/" . basename($file);
			    sys("objcopy --strip-debug $file $tmp_strip");
			    info(1, "$file size ", 
                                 -s $tmp_strip, " (LIB STRIPPED DEBUG)\n");
			    $total_bytes += bytes_allocated($tmp_strip);
			    unlink($tmp_strip);
			    next;
			}
		    }
		    elsif ($obj_count == 1) {
			if ($lib_needed_by{$file}) {
			    my $tmp_strip = "$tmp/" . basename($file);
			    sys("objcopy --strip-debug $file $tmp_strip");
			    info(1, "$file size ", 
                                 -s $tmp_strip, " (LIB STRIPPED ALL)\n");
			    $total_bytes += bytes_allocated($tmp_strip);
			    unlink($tmp_strip);
			    next;
			}
		    }
	        }
	    }

	    if ($strip_module) {
		my $not_stripped = `file $file`;
		if ($not_stripped =~ m,not stripped,) {
			if ($is_module{$file}) {
			    my $tmp_strip = "$tmp/" . basename($file);
			    sys("objcopy --strip-debug $file $tmp_strip");
			    info(1, "$file size ", 
                                 -s $tmp_strip, " (MODULE STRIPPED)\n");
			    $total_bytes += bytes_allocated($tmp_strip);
			    unlink($tmp_strip);
			    next;
			}
	        }
	    }


	    if ($strip_bin) {
		my $not_stripped = `file $file`;
		if ($not_stripped =~ m,not stripped,) {
		    my $tmp_strip = "$tmp/" . basename($file);
		    sys("objcopy --strip-all $file $tmp_strip");
		    info(1, "$file size ", 
                         -s $tmp_strip, " (BIN STRIPPED)\n");
		     $total_bytes += bytes_allocated($tmp_strip);
		     unlink($tmp_strip);
		     next;
	        }
	    }

	    info(1, "$file size ",  -s $file, "\n");
	    $total_bytes += bytes_allocated($file);

	}
    }

    #  Libraries are already included in the count

    info(0, "Total space needed is ", bytes_to_K($total_bytes), " Kbytes\n");

    ## One interesting thought:  This isn't looking at the penalty for
    ## ext2 filesystem info .. and other filesystems may be allowed in the
    ## future.  8192 inodes == 1.63% penalty or at iso9660
    if (bytes_to_K($total_bytes) > $fs_size) {
	info(0, "This is more than the $fs_size Kbytes allowed.\n");
            return;
    }

    info(0, "\n");

} # end sub space_check

########################
#####  Create filesystem
########################


sub create_filesystem {

    my ($filename, $fs_size, $mnt, $strip_lib, 
	$strip_bin, $strip_module, $obj_count) = @_;

    $device = "$mnt/$filename";
    $mount_point = "$mnt/loopback";

    my $file;
    my $error;

    info(0, "Creating root filesystem.\n");
    info(0, "Description:  $fs_size K ext2 file system\n");
    info(0, "Where:  $device\n");

    sync();
    sys("dd if=/dev/zero of=$device bs=1k count=$fs_size");
    sync();

    if (-f $device) {
	#####  If device is a plain file, it means we're using some loopback
	#####  device.  Use -F switch in mke2fs so it won't complain.
	## Options here can be changed.
	## Originally, this was -b 1024 switched with the inode approach.
	    if (sys("$main::makefs $device $fs_size") !~ 
		/^0$/ ) {
		my $fs_type = (split(/\s/,$main::makefs))[0];
		$error = error("Can not $fs_type filesystem.");
		return "ERROR" if $error && $error eq "ERROR";

	    }
    } else {
	    if (sys("$main::makefs $device $fs_size") !~ 
		/^0$/ ) {
		my $fs_type = (split(/\s/,$main::makefs))[0];
		$error = error("Can not $fs_type filesystem.");
		return "ERROR" if $error && $error eq "ERROR";
	    }
    }

    if (!-d $mount_point) {
       return "ERROR" if errmk(sys("mkdir $mount_point")) == 2;
    }

    return "ERROR" if errm(mount_device($device,$mount_point)) == 2;
    ##### lost+found on a ramdisk is pointless
    sys("rm -rf $mount_point/lost+found");

    sync();

    #####  Setting up the file structure is tricky.  Given a tangled set
    #####  of symbolic links and directories, we have to create the
    #####  directories, symlinks and files in the right order so that no
    #####  dependencies are missed.

    #####  First, create directories for symlink targets that are supposed
    #####  to be directories.  Symlink targets can't be superseded so
    #####  sorting them by path length should give us a linear ordering.
    info(0, "Creating directories for symlink targets\n");

    for $file (sort { path_length($a) <=> path_length($b) }
	       keys %links_to) {
	my($link_target) = $links_to{$file};
	my($abs_file) = make_link_absolute($file, $link_target);
	if (-d $abs_file) {
	    my($floppy_file) = $mount_point . $abs_file;
	    my($newdir);
	    foreach $newdir (mkpath($floppy_file)) {
		info(1, "\tCreating $newdir as a link target for $file\n");
	    }
	}
    }


    #####  Next, set up actual symlinks, plus any directories that weren't
    #####  created in the first pass.  Sorting by path length ensures that
    #####  parent symlinks get set up before child traversals.
    info(0, "Creating symlinks and remaining directories.\n");
    for $file (sort { path_length($a) <=> path_length($b) }
	       keys %Included) {

	my($target);
	if (defined($target = $links_to{$file})) {
	    my($floppy_file) = $mount_point . $file;
	    mkpath(dirname($floppy_file));
	    info(1, "\tLink\t$floppy_file -> $target\n");
	    symlink($target, $floppy_file) or
		($error = error("symlink($target, $floppy_file): $!\n"));
	    return "ERROR"if $error && $error eq "ERROR";
	    delete $Included{$file}; # Get rid of it so next pass doesn't copit

	} elsif (-d $file) {
	    my($floppy_file) = $mount_point . $file;
	    my($newdir);
	    foreach $newdir (mkpath($floppy_file)) {
		info(1, "\tCreate\t$newdir\n");
	    }
	    delete $Included{$file}; # Get rid of it so next pass doesn't copy it
	}
    }


    #####  Tricky stuff is over with, now copy the remaining files.

    info(0, "\nCopying files to $device\n");

    my(%copied);

    while (($file) = each %Included) {
	my($floppy_file) = $mount_point . $file;

	my($replacement);
	if (defined($replacement = $replaced_by{$file})) {
	    $file = $replacement;
	}

	if ($file =~ m|^/proc/|) {
	    #####  Ignore /proc files
	    next;

	} elsif (-f $file) {
	    #####  A normal file.
	    ## File::Path likes to die when the device runs out of space,
	    ## something which will have to be worked on.
	    mkpath(dirname($floppy_file));

	    #####  Maybe a hard link.
	    my($devino, $firstfile);
	    if (defined($devino = $hardlinked{$file})) {
		#####  It's a hard link - see if the linked file is already
		#####  on the root filesystem.
		if (defined($firstfile = $copied{$devino})) {
		    #####  YES - just hard link it to existing file.
		    info(1, "Hard linking $floppy_file to $firstfile\n");
		    sys("ln $firstfile $floppy_file");
		    next;		# Skip copy

		} else {
		    #####  NO - copy it.
		    $copied{$devino} = $floppy_file;
		}
	    }
	    info(1, "$file -> $floppy_file\n");
	    copy_strip_file($file, $floppy_file, $obj_count, $strip_lib, 
			    $strip_bin, $strip_module);

	} elsif (-d $file) {
	    #####  A directory.
	    info(1, "Creating directory $floppy_file\n");
	    mkpath($floppy_file);

	} elsif ($file eq '/dev/null' and
		 $floppy_file ne "$mount_point/dev/null") { # I hate this
	    info(1, "Creating empty file $floppy_file\n");
	    mkpath(dirname($floppy_file));
	    sys("touch $floppy_file");

	} else {
	    #####  Some special file.
	    info(1, "Copying special $file to $floppy_file\n");
	    mkpath(dirname($floppy_file));
	    #  The 'R' flag here allows cp command to handle devices and FIFOs.
	    sys("cp -dpR $file $floppy_file");
	}
    }


    info(0, "\nFinished creating root filesystem.\n");

    if (@Libs) {

	info(0, "Re-generating /etc/ld.so.cache on root fs.\n");
	info(1, "Ignore warnings about missing directories\n");

	sys("ldconfig -v -r $mount_point");
    }

    ## Probably will want to umount here
    return "ERROR" if errum(sys("umount $mount_point")) == 2;

    info(0, "\nDone making the root filesystem.  $Warnings warnings.\n",
	 "$device is now umounted from $mount_point\n\n");

    #info(0, "All done!\n");
    #info(0, "You can run more tests with the UML kernel\n", 
    #     "or construct a distribution by using this root\n",
    #     "filesystem with a boot method.");
    
} # end sub create_filesystem

#######################################
#####  Utility subs for make_root_fs.pl
#######################################

#####  Add file to the file set.  File has to be an absolute filename.
#####  If file is a symlink, add it and chase the link(s) until a file is
#####  reached.
sub include_file {
    my($contents_file, $file) = @_;
    my $error;

    must_be_abs($file);
    if (onto_proc_filesystem($file)) {
	info(1, "File $file points into proc filesystem -- not pursued.\n");
	return;
    }

    $Included{$file} = 1;

    #####  If we have links   A -> B -> C -> D -> E
    #####  on disk and   A -> D  is set explicitly, then we pick up
    #####  files A and D in pass 1, and E on pass 2.

    while (!defined($links_to{$file}) and !defined($replaced_by{$file})
	   and -l $file) {

	#####  SYMBOLIC LINK on disk, not overridden by explicit link or
	#####  replacement.  Relativize the link for use later, but also
	#####  check and resolve the target so it gets onto the rescue disk.
	my($link)         = readlink($file) or ($error = error("readlink($file): $!"));
	return "ERROR"if $error && $error eq "ERROR";
	my($rel_link)     = make_link_relative($file, $link);
	$links_to{$file}  = $rel_link;

	my($abs_target)   = make_link_absolute($file, $link);
	if (onto_proc_filesystem($abs_target)) {
	    info(1, "$file points to $abs_target, on proc filesystem\n");
	    last;
	}

	if (!$Included{$abs_target}) {
	    info(1, "File $file is a symbolic link to $link\n");
	    #info(1, "\t(which resolves to $abs_target),\n"
	    #	if $link ne $abs_target);
	    info(1, "\twhich was not included in $contents_file.\n");
	    if (-e $abs_target) {
		info(1, "\t ==> Adding it to file set.\n\n");
		$Included{$abs_target} = $file;
	    } else {
		info(0, "\t ==> $abs_target does not exist.  Fix this!\n");
	    }
	}
	$file = $abs_target;	# For next iteration of while loop
    }
}

#####  More informative versions of warn and die, for the contents file
sub cf_die {
  my($contents_file, $line, @msgs) = @_;
  info(0, "$contents_file($cf_line): $line\n");
  foreach (@msgs) { info(0, "\t$_\n"); }
  my $output = join("\n",@msgs);
  error_window("gBootRoot: ERROR: ", $output);
  return "ERROR";
}

sub cf_warn {
  my($contents_file, $line, @msgs) = @_;
  info(0, "$contents_file($cf_line): $line\n");
  $Warnings++;
  foreach (@msgs) { info(0, "\t$_\n"); }
}


## Modified for user chosen defaults
#  Copy a file, possibly stripping it.  Stripping is done if the file
#  is strippable and stripping is desired by the user, and if the
#  objcopy program exists.
sub copy_strip_file {
    
    my($from, $to, $strip_objfiles, 
       $strip_lib, $strip_bin, $strip_module) = @_;
    my $error;

    if ($strippable{$from}) {

        #  Copy it stripped
	if ($strip_lib) {
	    if (defined($lib_needed_by{$from})) {	
		#  It's a library
		if ($strip_objfiles == 1) {
		    info(1, "Copy/stripping library $from to $to\n");
		    sys("$objcopy --strip-all $from $to");
		}
		elsif ($strip_objfiles == 0) {
		    info(1, "Copy/stripping library $from to $to\n");
		    sys("$objcopy --strip-debug $from $to");
		}
	    }   
	}
	if ($strip_module) {
	    if (defined($is_module{$from})) {
		info(1, "Copy/stripping module $from to $to\n");
		sys("$objcopy --strip-debug $from $to");
	    }
	} 
	if ($strip_bin) {
	    if (!defined($is_module{$from}) && 
		!defined($lib_needed_by{$from})) {
		#  It's a binary executable
		info(1, "Copy/stripping binary executable $from to $to\n");
		sys("$objcopy --strip-all $from $to");
	    }
	}
	else { # fallback just in case
	#  Normal copy, no strip
	info(1, "Copying $from to $to\n");
	sys("cp -a $from $to");
	}

	# Copy file perms and owner
	my($mode, $uid, $gid);
	(undef, undef, $mode, undef, $uid, $gid) = stat $from;
	my $from_base = basename($from);
	chown($uid, $gid, $to) or ($error = 
				   error("chown: $! \($from_base\)\n"));
	return "ERROR"if $error && $error eq "ERROR";
	chmod($mode, $to)      or ($error = 
				   error("chmod: $! \($from_base\)\n"));
        return "ERROR"if $error && $error eq "ERROR";
    }
    else {
	#  Normal copy, no strip
	info(1, "Copying $from to $to\n");
	sys("cp -a $from $to");
    }

}


#####  End of make_root_fs

########################################################
##
##      YARD_UTILS.PL -- Utilities for the Yard scripts.
##
########################################################

# Get device number of /proc filesystem
## not a sub
my($proc_dev) = (stat("/proc"))[0];

sub info {
  my($level, @msgs) = @_;
  
  if ($level != 3) {
      print LOGFILE @msgs; 
  }
  $level = 0 if $level == 3;

  my $output = join("",@msgs);
  if ($verbosity >= $level) {
      if ($text_insert) {
	  $text_insert->freeze();
	  if ($level == 0) {
	      $text_insert->insert( undef, $blue, undef, $output );
	  }
	  elsif ($level == 1) {
	      $text_insert->insert( undef, $red, undef, $output );
	  }    
	  $text_insert->thaw();
	  $logadj->set_value($logadj->upper - $logadj->page_size);
	  while (Gtk->events_pending) { Gtk->main_iteration; }
      }
  }

}

## This will produce red.
sub error {

  print LOGFILE "Error: ", @_;
  info(0, "Error: ", @_);
  error_window("gBootRoot: ERROR: ", @_);
  return "ERROR";

}

sub start_logging_output {

  my ($yard_temp,$verb_level) = @_;
  my $logfile;
  $verbosity = $verb_level;

  if (defined($yard_temp) and $yard_temp) {
    $logfile = $yard_temp;
  }
  # ERRORCHECK
  ## If logfile doesn't open in /tmp there is some type of fatal problem.
  open(LOGFILE, ">>$logfile") or error("open($logfile): $!\n");
  # &::verbosity_box() if !visible $verbosity_window;
  info(1, "Logging output to $logfile\n")
}

#####  Same as system() but obeys $verbosity setting for both STDOUT
#####  and STDERR.
sub sys {
    my $error;
    
    # when using sys on yard_chrooted_tests
    my $dont = pop @_;
    if ($dont ne "TESTING") {
	push @_, $dont; 
    }

    open(SYS, "@_ 2>&1 |") or ($error = error("open on sys(@_) failed: $!"));
    return "ERROR"if $error && $error eq "ERROR";
    while (<SYS>) {
	if ($dont ne "TESTING") {
	    print LOGFILE unless $_ =~ m,\/.*file\n$,;
	}
	if ($verbosity > 0) {
	    if ($dont ne "TESTING") {
		info(1,$_) unless $_ =~ m,\/.*file\n$,;
	    }
	    else {
		info(3,$_) unless $_ =~ m,\/.*file\n$,;		
	    }
	}	
    }
    close(SYS) or return $?; 
    0;				# like system()
}

# This is history, simply because the mount point is unique to
# the session, and umount is always used between stages, and
# there are checks in place for it's failure.
# Just need to add error_window.
my (%mounted, %fs_type); 
sub load_mount_info {
  undef %mounted;
  undef %fs_type;

  open(MTAB, "</etc/mtab") or die "Can't read /etc/mtab: $!\n";
  while (<MTAB>) {
    my($dev, $mp, $type) = split; 
    next if $dev eq 'none';
    $mounted{$dev} = $mp;
    $mounted{$mp}  = $dev;
    $fs_type{$dev} = $type;
  }
  close(MTAB);
}

sub mount_device_if_necessary {
  load_mount_info();

  # obviously these should be lexical to the whole package.
  my ($device,$mount_point); 
                            
  if (defined($mounted{$device})) {

    if ($mounted{$device} eq $mount_point) {
      info(0, "Device $device already mounted on $mount_point\n");

    } else {
      info(0, "$device is mounted \(on ", $mounted{$device}, "\)\n");
      info(0, "Can't mount it under $mount_point.\n");
    }

  } elsif ($mounted{$mount_point} eq $device) {
    info(0, "Another device \(", $mounted{$mount_point},
	 "\) is already mounted on $mount_point\n");
  }
}


sub must_be_abs {
  my($file) = @_;
  #  Matches / or ./ or ../
  $file =~ m|^\.{0,2}/|
      or info(0, "file $file must be absolute but isn't.\n");
}


sub sync {
  #  Parts of unix are still a black art
  system("sync") and error("Couldn't sync!");
  system("sync") and error("Couldn't sync!");
}

## Need to put error() checking here
## This is used for ./Replacements  config_dest == /etc/yard
#  find_file_in_path(file, path)
#  Finds filename in path.  Path defaults to @pathlist if not provided.
#  If file is relative, file is resolved relative to config_dest and lib_dest.
my(@pathlist);
sub find_file_in_path {

  my($file, @path) = @_;

  if (!@path) {
    #####  Initialize @pathlist if necessary
    if (!@pathlist) {
      @pathlist = split(':', $ENV{'PATH'});
      if (defined(@::additional_dirs)) {
	unshift(@pathlist, @::additional_dirs);
	###  Changed this to work as documented
	$ENV{"PATH"} = join(":", @::additional_dirs) .
	    ":$ENV{'PATH'}";
      }
      info(1, "Using search path:\n", join(" ", @pathlist), "\n");
    }
    @path = @pathlist;
  }


  if ($file) {

    #####  Relative filename, search for it
    my($dir);
    ## foreach $dir (@path, $config_dest, $lib_dest
    foreach $dir (@path) {
      my($abs_file) = "$dir/$file";
      return $abs_file if -e $abs_file;
    }
#    if ( !-e "$path[$#path]/$file") {
#	info(1,"gBootRoot Error: Couldn't find $file\n");
#    }
    undef;
  }

}

#  Note that this does not verify existence of the returned file.
sub make_link_absolute {
  my($file, $target) = @_;

  if ($target =~ m|^/|) {
    $target;			# Target is absolute, just return it
  } else {
    cleanup_link(dirname($file) . "/$target");
  }
}


sub cleanup_link {
  my($link) = @_;
  # Collapse all occurrences of /./
  1 while $link =~ s|/\./|/|g;
  # Cancel occurrences of /somedir/../
  # Make sure somedir isn't ".."
  1 while $link =~ s|/(?!\.\.)[^/]+/\.\./|/|g;
  $link
}


#  Given an absolute file name and a symlink, make the symlink relative
#  if it's not already.
sub make_link_relative {
  my($abs_file, $link) = @_;
  my($newlink);

  if ($abs_file) {
  if ($link =~ m|^/(.*)$|) {
    #  It's absolute -- we have to relativize it
    #  The abs_file guaranteed not to have any funny
    #  stuff like "/./" or "/foo/../../bar" already in it.

      ## This is an experimental solution to an annoying tendency
      ## for this to happen ../../../../ for files/dirs .. basically
      ## this occurs when called from include_file() called from
      ## extra_links() .. the reason for relativing links like this
      ## doesn't make sense.
      if (!-f $link && !-d $link) {
	  $newlink = ("../" x path_length($abs_file)) . $1;
      }

  } else {
    #  Already relative
    $newlink = $link;
  }
  if ($newlink) {
     cleanup_link($newlink) 
  }
  else {
      return $link;
  }

  }
}

#  I don't know if this information is worth caching.
my(%path_length);
sub path_length {
  my($path) = @_;

  if ($path) {
      return $path_length{$path} if defined($path_length{$path});
      my($length) = -1;
      while ($path =~ m|/|g) { $length++ } # count slashes
      $path_length{$path} = $length;
      $length
  }
}


sub bytes_to_K {
  my($bytes) = @_;
  int($bytes / 1024) + ($bytes % 1024 ? 1 : 0);
}



#  Device capacity in K
sub get_device_size_K  {
  my($device) = @_;
  my($DEV_BSIZE)  = 512;	# Blocksize, from sys/param.h

  my($result) = pack("L", 0);
  open(FD, $device) or die "open($device): $!";
  my($return) = ioctl(FD, $BLKGETSIZE_ioctl, $result);
  close(FD);
  if ($return) {
    my($bytes) = unpack("L", $result) * $DEV_BSIZE;
    bytes_to_K( $bytes );
  } else {
    warn "Can't get size of $device";
    undef;
  }
}

#####  Thanks to Rick Lyons for this: "If you do a BLKFLSBUF on a device, you
#####  get a sync (via fsync()) as well as an invalidation of all of the
#####  buffers.  That is, anything stored in the buffer cache for that device
#####  is tossed out and any accesses to the device needs to go to the
#####  hardware.  BLKFLSBUF is slightly different for /dev/ram in that no
#####  dirty buffers are written (since there's no corresponding hardware),
#####  and the buffer invalidation causes all of the memory allocated to the
#####  ramdisk to be unlocked and made available for reuse."
sub flush_device_buffer_cache {
  my($device) = @_;
  my($junk) = "stuff";

  open(FD, $device) && ioctl(FD, $BLKFLSBUF_ioctl, $junk);
  close(FD);
}

#####  This is a kludge but is probably the best way to check for
#####  module support.
sub warn_about_module_dependencies {
  my($version)        = @_;

  if (defined($version)) {

    my($ramdisk_module) = "/lib/modules/$version/block/rd.o";
    my($ext2fs_module)  = "/lib/modules/$version/fs/ext2.o";
    my($floppy_module)  = "/lib/modules/$version/block/floppy.o";

    if (-e $ramdisk_module) {
      info(0, "***** Warning:  Chosen kernel ($version) may have\n",
      "      modular ramdisk support.  ($ramdisk_module exists)\n",
      "      The kernel used for the ",
      " rescue disk must have BUILT-IN ramdisk support.\n");
    }
    if (-e $ext2fs_module) {
      info(0, "***** Warning:  Chosen kernel ($version) may have\n",
      "      modular ext2 fs support.  ($ext2fs_module exists)\n",
      "      The kernel used for the ",
      " rescue disk must have BUILT-IN ext2 fs support.\n");
    }
    if (-e $floppy_module) {
      info(0, "***** Warning:  Chosen kernel ($version) may have\n",
      "      modular floppy support.  ($floppy_module exists)\n",
      "      The kernel used for the ",
      " rescue disk must have BUILT-IN floppy support.\n");
    }
  }
}


#####  This is a hack but there's no system command to return a
#####  (non-running) kernel version.  Returns undef if it can't
#####  determine the version.
# sub kernel_version {
#   my($image)  = @_;

#   my($str)	       = "phlogiston";
#   my($version_start)   = 1164;
#   my($version_length)  = 10;

#   open(DATA, $image) or return(undef);
#   seek(DATA, $version_start, 0);
#   read(DATA, $str, $version_length);
#   close(DATA);
#   ######  Do careful matching in case we got some random string.
#   my($version) = $str =~ /^(\d+\.\d+\.\d+)\s/;
#   $version
# }


# kernel_version supplied by Andreas Degert <ad@papyrus.hamburg.com>.
# This procedure is tested with kernels v2.0.33 and v2.1.103 on i386
# Returns undef if it can't determine the version (or bails out with error)
sub kernel_version {
  my($image)  = @_;
  my $error;

  # check if we have a normal file (-f dereferences symbolic links)
  if (!-f $image) {
    $error = error("Kernel image ($image) is not a plain file.\n");
    return "ERROR"if $error && $error eq "ERROR";

  } else {
    my($str)	       = "";
    my($version_start) = "";

    open(DATA, $image) or ($error = error("can't open $image.\n"));
    return "ERROR"if $error && $error eq "ERROR";
    # check signature of kernel image
    seek(DATA, 514, 0);
    read(DATA, $str, 4);
    $error = error(
        "Kernel image file ($image) does not have Linux kernel signature\n")
        unless $str =~ "HdrS";
    return "ERROR"if $error && $error eq "ERROR";
    # setup header version should be 0x201
    read(DATA, $str, 2);
    $str = unpack("S",$str);
    #info (0, "Kernel setup header version is 0x");

	# 2.4.0 kernels now use Start Text 0x202 
	    unless ($str == 0x201
		    || $str == 0x0202) {
		print sprintf("%04x",$str);
		print "(expected 0x201 or 0x202).\n"; 
	    } 

    # get ofset of version string (indirect) and read version string
    seek(DATA, 526, 0);
    read(DATA, $version_start, 2) or ($error = error(
                                                "can't read from $image.\n"));
    return "ERROR"if $error && $error eq "ERROR";
    $version_start = unpack("S",$version_start) + 512;
    seek(DATA, $version_start, 0);
    read(DATA, $str, 30) or
      ($error = error("can't read from offset $version_start of $image.\n"));
    return "ERROR"if $error && $error eq "ERROR";
    close(DATA);
    #  Extract the version number.
    #  Usually this is something like 2.2.15, but because of kernel packages
    #  it can also be something like 2.2.15-27mdk.  Don't make any assumptions
    #  except that beginning must be dotted triple and it's space delimited.
    my($version) = $str =~ /^(\d+\.\d+\.\d+\S*)\s/;

    return $version

  }
}


## HISTORY
#####  Eventually move this into configure since it doesn't have to be
#####  done with every make_root_fs.  But yard_glob would have to be
#####  configured, and yard_utils.pl isn't configured.  Will use for
#####  other things, though.
my($glob_broken);
sub test_glob {
  my($globbed) = join(' ', glob("/*"));
  my($echoed)  = join(' ', `echo /*`);
  chop($echoed);

  if ($globbed ne $echoed) {
    info 0, "\n*****  The glob() function seems to be broken here ",
    "(Perl version $PERL_VERSION)\n",
    "I'll use a slower version that works.\n";
    $glob_broken = 1;
  } else {
    $glob_broken = 0;
  }
}

#####  Check glob() --  In some Perl versions it's reported not to work.
sub yard_glob {
  my($expr) = @_;

  ## first part HISTORY
  if ($glob_broken) {
    my($line) = `echo $expr`;
    chop($line);
    my(@files) = split(' ', $line);

  } else {
    glob($expr);
  }
}


sub mount_device {
    
  my ($device,$mount_point) = @_;  
  my($options);

  if (-f $device) {
    $options = "-o loop ";
  } else {
    $options = "";
  }

  errmk(sys("mount $options -t ext2 $device $mount_point"));
}


#####  Called by make_root_fs to do basic checks on choice of $::device.
sub check_device {

    my $fs_size; # @_

  if (!-e $::device) {
    error("Device $::device does not exist\n");

  } elsif (-l $::device) {
    error("$::device is a symbolic link\n",
    "Please provide a real device to avoid confusion.\n");

  } elsif (-f $::device) {
    info(0, "Device $::device is a normal file.\n",
    "Assuming loopback device is being used.\n");

  } elsif (-c $::device) {
    error("\$::device ($::device) is a character special file\n",
    "It must be a block device\n");

  } elsif (-b $::device) {

    if ($::device =~ m|^/dev/[hs]d[abcd]$|) {
#      error("You've specified an entire hard disk ($::device) as the device\n",
 #     "on which to build the root filesystem.\n";
 #     "Please specify a single partition.\n";
    }
    #####  If we can check device size, make sure it isn't less than
    #####  what's declared.

    my($max) = get_device_size_K($::device);

    if (defined($max)) {
      if ($max < $fs_size) {
	info 0, "You've declared file system size (fs_size) to be ",
	"$fs_size K\n",
	"but Linux says $::device may only hold $max K\n";
	if ($::device =~ m|^/dev/ram|) {
	  info 0, "(Increase ramdisk size";
	  (info 0, " in lilo.conf") if -e "/etc/lilo.conf";
	  info(0, ")\n");
	}
	exit;
      }
    } else {
      info 0, "Warning: Yard can't determine the real size of ",
      "$::device.\n",
      "Assuming it's $fs_size as declared.\n",
      "I hope you're not lying.\n";
    }

  } else {
    error("I have no idea what your \$device ($::device) is!\n",
    "It should either be a block special file (eg, /dev/ram or\n",
    "/dev/hda2) or a plain file for use with a loopback device.\n");
  }
}


#  Copy a file, substituting values for variables in the file.
#  First try using a configuration variable (in CFG package),
#  then issue a warning.
sub copy_file_with_substitution {
  my($from, $to) = @_;

  open(FROM, "<$from") or error("Can't open $from: $!\n");
  open(TO,   ">$to")   or error "$to: $!";

  local($WARNING) = 0;		# Turn off warnings from eval
  while (<FROM>) {
##    s/\$(\w+)/(eval("\$::$1")/eg;
    print TO;
# took this out from space above
#	       or info(0, "Warning: $1 (in $from) has no known value\n")
  }

  close(FROM);
  close(TO);
}

sub bytes_allocated {
  my($file) = @_;

  my($size) = -s $file;

  if ($size % $EXT2_BLOCK_SIZE == 0) {
    $size
  } else {
    (int($size / $EXT2_BLOCK_SIZE) + 1) * $EXT2_BLOCK_SIZE
  }
}


sub onto_proc_filesystem {
  my($file) = @_;
  my($sdev) = (stat($file))[0];
  my($ldev) = (lstat($file))[0];


  if ($sdev && $sdev == $proc_dev) {
      return $proc_dev;
  }
  elsif ($ldev && $ldev == $proc_dev) {
      return $proc_dev;
  }

}


#################
##
##  CHECK_ROOT_FS
##
#################

###  GLOBAL VARIABLES
my(%Termcap);			# Defs from /etc/termcap
my($checked_for_getty_files);	# Scalar -- have we checked getty files yet?
my(%checked);			# Hash table of files we've already checked
my $login_binary;

sub warning_test {
    info(0, "\n", @_);
}

sub which_tests {

    my ($chosen_tests) = @_;
    my ($action, $label);


    #  This is a little crude.  Technically we should read /etc/conf.getty
    #  to make sure we're not supposed to be using a different login binary.

    ## Originally, this was "$mount_point/usr/bin/login" but this is assuming 
    ## to much.  It is better just to find the local version since this varies
    ## from distribution to distribution, and more than likely this is the
    ## "login" used in the mounted version, too.
    ## Once PATH is complete, there will be a separate check just to look at
    ## the non-local $mount_point PATH.

    $login_binary = "$mount_point" . find_file_in_path("login");

    #  This goes first so we define %Termcap for use in children
    ## This now checks for ncurse setups, too.
    return "ERROR" if errm(mount_device($device,$mount_point)) == 2;
    check_termcap();
    return "ERROR" if errum(sys("umount $mount_point")) == 2;

    #####  Here are the tests.
    my $t_fstab    = $chosen_tests->{30}{test_fstab};
    my $t_inittab  = $chosen_tests->{31}{test_inittab};
    my $t_scripts  = $chosen_tests->{32}{test_scripts};

    return "ERROR" if errm(mount_device($device,$mount_point)) == 2;
    sys("yard_chrooted_tests $mount_point $t_fstab $t_inittab $t_scripts",
	"TESTING"); 
    return "ERROR" if errum(sys("umount $mount_point")) == 2;

    return "ERROR" if errm(mount_device($device,$mount_point)) == 2;

    # Now the question is whether or not these next tests depend on
    # chroot, since they must have before.
    if ( $chosen_tests->{33}{test_links}   == 1 ) {
	info(0,"\nTEST: links\n");
	check_links();                   
    }
    if ( $chosen_tests->{34}{test_passwd}  == 1 ) {
	info(0,"\nTEST: passwd\n");
	check_passwd();                  
    }
    if ( $chosen_tests->{35}{test_pam}     == 1 ) {
	info(0,"\nTEST: pam\n");
	check_pam();                     
    }
    if ( $chosen_tests->{36}{test_nss}     == 1 ) {
	info(0,"\nTEST: nss\n");
	check_nss();                     
    }

    return "ERROR" if errum(sys("umount $mount_point")) == 2;

    
} # end sub which_tests


#####  This could be made much more complete, but for typical rc type
#####  files it seems to catch the common problems.
sub scan_command_file {
  my($cmdfile, @args) = @_;
  my(%warned, $line);

  return if $checked{$cmdfile};
  info(0, "\nScanning $cmdfile\n");
  open(CMDFILE, "<$cmdfile")  or error("$cmdfile: $!");

  while ($line = <CMDFILE>) {
    chomp($line);
    next if $line =~ /^\#/ or /^\s*$/;

    next if $line =~ /^\w+=/;

    while ($line =~ m!(/(usr|var|bin|sbin|etc|dev)/\S+)(\s|$)!g) {
	my($abs_file) = $1;
	# next if $abs_file =~ m/[*?]/; # Skip meta chars - we don't trust glob
	next if $warned{$abs_file}; # Only warn once per file
	if (!-e $abs_file) {
	    warning_test("$cmdfile($.): $line\n\t$1: missing on root filesystem\n");
	    $warned{$abs_file} = 1;
	}
    }
  }
  close(CMDFILE) or error("close($cmdfile): $!");

  $checked{$cmdfile} = 1;
  info(0, "Done scanning $cmdfile\n");
}


#####  Check_passwd is NOT run under chroot.
sub check_passwd {
  my $error;
  my($passwd_file) = "$mount_point/etc/passwd";
  open(PASSWD, "<$passwd_file")	or 
      ($error = error("Can't read passwd file: $!\n"));
  return if $error && $error eq "ERROR";

  info(0, "\nChecking passwd file $passwd_file\n");

  while (<PASSWD>) {
    chomp;
    next if /^\s*$/;		# Skip blank/empty lines
    my($line) = $_;
    my($login_name, $passwd, $UID, $GID, $user_name, $home, $shell) =
      split(':');

    next if $passwd eq "*";	# Skip warnings if user can't login

    -d ($mount_point . $home) or
      warning_test "$passwd_file($.): $line\n",
	      "\tHome directory of $login_name ($mount_point$home) is missing\n";
    -e ($mount_point . $shell) or
      warning_test "$passwd_file($.): $line\n",
	      "\tShell of $login_name ($mount_point$shell) doesn't exist\n";

    check_init_files($login_name, $home, $shell);
  }
  close(PASSWD);
  info(0, "Done checking $passwd_file\n");
}


#####  Simple PAM configuration checks.
#####  Tests whether PAM is needed, and whether the configuration libraries exist.
#####  Check_pam is NOT run under chroot.
sub check_pam {
  my($pam_configured) = 0;	# Have we seen some pam config file yet?
  info(0, "Checking for PAM\n");

  my($pamd_dir) = "$mount_point/etc/pam.d";
  my($pam_conf) = "$mount_point/etc/pam.conf";

  if (-e $pam_conf) {
    info(0, "Checking $pam_conf\n");
    $pam_configured = 1;
    open(PAM, $pam_conf)		or error("Can't open pam.conf: $!\n");
    while (<PAM>) {
      chomp;
      next if /^\#/ or /^\s*$/;          # Skip comments and empty lines
      my($file) = (split)[3];	# Get fourth field
      if (!-e "$mount_point/$file") {
	warning_test "$pam_conf($.): $_\n",
	"\tLibrary $file does not exist on root fs\n";
      }
      #  That's all we check for now
    }
    close(PAM)				or error("Closing PAM: $!");
    info(0, "Done with $pam_conf\n");
  }


  if (-e $pamd_dir) {
     info(0, "Checking files in $pamd_dir\n");
     opendir(PAMD, $pamd_dir) or error("Can't open $pamd_dir: $!");
     my($file);
     while (defined($file = readdir(PAMD))) {
	my($file2) = "$pamd_dir/$file";
	next unless -f $file2;	# Skip directories, etc.
	open(PF, $file2) or error("$file2: $!");
	while (<PF>) {
	   chomp;
	   next if /^\#/ or /^\s*$/;           # Skip comments and empty lines
	   my($file) = (split)[3]; # Get fourth field
	   $pam_configured = 1;
	   if (!-e "$mount_point/$file") {
	      warning_test "$file2($.): $_\n",
	      	  "\tLibrary $file does not exist on root fs\n";
	   }
	}
	close(PF);
     }
     closedir(PAMD);
  }

  #  Finally, see whether PAM configuration is needed
  if (!$pam_configured and -e $login_binary) {
     my($dependencies) = scalar(`ldd $login_binary`);
     if (defined($dependencies) and $dependencies =~ /libpam/) {
	warning_test "Warning: login ($login_binary) needs PAM, but you haven't\n",
	    "\tconfigured it (in /etc/pam.conf or /etc/pam.d/)\n",
		"\tYou probably won't be able to login.\n";
     }
  }
  info(0, "Done with PAM\n");
}



#####  Basic checks for nsswitch.conf.
#####  check_nss is NOT run under chroot.
#####  From the nsswitch.conf(5) manpage:
#####  For glibc, you must have a file called /lib/libnss_SERVICE.so.X for
#####  every SERVICE you are using. On a standard installation, you could
#####  use `files', `db', `nis' and `nisplus'. For hosts, you could specify
#####  `dns' as extra service, for passwd, group and shadow `compat'. These
#####  services will not be used by libc5 with NYS.  The version number X
#####  is 1 for glibc 2.0 and 2 for glibc 2.1.

sub check_nss {
   my($nss_conf) = "$mount_point/etc/nsswitch.conf";
   info(0, "Checking for NSS\n");

   my($libc) = yard_glob("$mount_point/lib/libc-2*");
   my($libc_version) = $libc =~ m|/lib/libc-2.(\d)|;
   if (!defined($libc_version)) {
      warning_test "Can't determine your libc version\n";
   } else {
      info(0, "You're using $libc\n");
   }
   my($X) = $libc_version + 1;

   if (-e $nss_conf) {
      open(NSS, "<$nss_conf")		or die "open($nss_conf): $!";

      my($line);
      while (defined($line = <NSS>)) {
	 chomp $line;
	 next if $line =~ /^\#/;
	 next if $line =~ /^\s*$/;
	 my($db, $entries) = $line =~ m/^(\w+):\s*(.+)$/;
	 # Remove bracketed expressions	(action specifiers)
	 $entries =~ s/\[[^\]]*\]//g;
	 my(@entries) = split(' ', $entries);
	 my($entry);
	 for $entry (@entries) {
	    next if $entry =~ /^\[/; # ignore action specifiers
	    my($lib) = "$mount_point/lib/libnss_${entry}.so.${X}";
	    if (!-e $lib) {
	       warning_test "$nss_conf($.):\n$line\n",
		   "\tRoot filesystem needs $lib to support $entry\n";
	    }
	 }
      }
      close(NSS) or error("Closing NSS: $!");
   } else {
      #  No nsswitch.conf is present, figure out if maybe there should be one.
      if (-e $login_binary) {
	 my($dependencies) = scalar(`ldd $login_binary`);
	 my($libc_version) = ($dependencies =~ /libc\.so\.(\d+)/m);
	 if ($libc_version > 5) {
	    #  Needs libc 6 or greater
	    warning_test "Warning: $login_binary on rescue disk needs libc.so.$libc_version,\n"
		. "\tbut there is no NSS configuration file ($nss_conf)\n"
		    . "\ton root filesystem.\n";
	 }
      }
   }
   info(0, "Done with NSS\n");
}

sub check_links {
  info(0, "\nChecking links relative to $mount_point\n");

  sub wanted {
    if (-l $File::Find::name) {
      local($::raw_link) = readlink($File::Find::name);
      local($::target) = make_link_absolute($File::Find::name, $::raw_link);

      #  I added this next test for /dev/stdout link hair.
      #  This really should be more complicated to handle link chains,
      #  but as a hack this works for three.
      if (onto_proc_filesystem($File::Find::name)) {

      } elsif (-l $::target) {
	chase_link($::target, 16);

      } elsif (!-e $::target) {
	warning_test "Warning: Unresolved link: $File::Find::name -> $::raw_link\n";
      }
    }
  };

  finddepth(\&wanted, $mount_point);
}


sub chase_link {
  my($file, $link_depth) = @_;

  if ($link_depth == 0) {
    warning_test "Warning: Probable link circularity involving $file\n";

  } elsif (-l $file) {
    chase_link(make_link_absolute($file, readlink($file)),
	       $link_depth-1);
  }
}


sub check_scripts {
  info(0, "\nChecking script interpreters\n");
  local($::prog);

  sub check_interpreter {
    if (-x $File::Find::name and -f _ and -T _) {
      open(SCRIPT, $File::Find::name)		or error "$File::Find::name: $!";
      my($prog, $firstline);
      chomp($firstline = <SCRIPT>);
      if (($prog) = $firstline =~ /^\#!\s*(\S+)/) {
	if (!-e $prog) {
	  warning_test "Warning: $File::Find::name needs $prog, which is missing\n";
	} elsif (!-x $prog) {
	  warning_test "Warning: $File::Find::name needs $prog, " .
	      "which is not executable.\n";
	}
      }
      close(SCRIPT);
    }
  };				# End of sub check_interpreter

  find(\&check_interpreter, "/");
}

sub check_getty_type_call {
  my($prog, @args) = @_;

  if ($prog eq 'getty') {
    my($tty, $speed, $type) = @args;

    if (!-e "$mount_point/dev/$tty") {
      warning_test "\tLine $.: $prog for $tty, but /dev/$tty doesn't exist.\n";
    }
    if (!defined($Termcap{$type})) {
      warning_test "\tLine $.: Type $type not defined in termcap\n";
    }
  }
  ##  If getty or getty_ps, look for /etc/gettydefs, /etc/issue
  ##  Check that term type matches one in termcap db.

  if ($prog =~ /^getty/) {
    if (!$checked_for_getty_files) {
      warning_test "\tLine $.: $prog expects /etc/gettydefs, which is missing.\n"
	unless -e "$mount_point/etc/gettydefs";
      warning_test "\tLine $.: $prog expects /etc/issue, which is missing.\n"
	unless -e "$mount_point/etc/issue";
      $checked_for_getty_files = 1;
    }
  }
}

###
###  NB. This is *not* run under chroot
###
sub check_init_files {
    my($user, $home, $shell) = @_;

    info(0, "Checking init files of $user (homedir= $home)\n");

  my($shellname) = basename($shell);
  my @init_files;

  #####  Try to infer the list of init files to be run for the shell
  #####  of this user.  Order is somewhat important here because of
  #####  the search path.

  if ($shellname =~ /^(bash|sh)$/) {
    @init_files = ("/etc/profile", "/etc/bashrc",
		   "$home/.profile", "$home/.bash_login", "$home/.bashrc",
		   "$home/.shrc");

  } elsif ($shellname eq "ash") {
    @init_files = ("/etc/profile", "$home/.profile");

  } elsif ($shellname =~ /^(tcsh|csh)$/) {
    @init_files = ("/etc/csh.cshrc", "/etc/.cshrc", "/etc/csh.login",
		   "$home/.cshrc", "$home/.tcshrc", "$home/.login");
  }

  #####  The path to be searched.  This may be error prone.
  my(@path) = ();
  my($init_file);

  foreach $init_file (@init_files) {
    $init_file = $mount_point . $init_file;

    next if $checked{$init_file} or !-r $init_file;

    info(0, "Checking $init_file\n");

    open(INITF, "<$init_file")			or die "$init_file: $!";

    while (<INITF>) {
      chomp;
      next if /^\#/ or /^\s*$/;	  # Skip comments, whitespace

      my($var, $val);
      if (($var, $val) = /^\s*(\w+)\s*=\s*(.*)\s*$/) { # Variable assignment
	#####  Look for PATH assignment
	if ($var eq "PATH") {
	  $val =~ s/^[\"\'](.*)[\"\']$/$1/; # Strip quotes
	  @path = split(':', $val);
	  info(1, "Using PATH: ", join(':', @path), "\n");
	} else {
	  next;			# Skip other assignments
	}
      }

      my($cmd, $hd_abs);

      #####  Check for commands that aren't present
      ($cmd) = /^(\w+)\b/;	# Pick up cmd name
      if ($cmd and ($hd_abs = find_file_in_path($cmd, @path))) {
	#  If it's here, see if it's on the rescue disk
	if (!(-e "$mount_point/$hd_abs" and -x _)) {
	  warning_test "$init_file($.): $_\n\t\t$cmd looks like a command but\n",
	  "\t\tdoes not exist on the root filesystem.\n";
	}
      }

      #  Check for commands in backticks that aren't present
      ($cmd) = /\`(\w+)\b/;
      if ($cmd and ($hd_abs=find_file_in_path($cmd))) {
	#  If it's here, see if it's on the rescue disk
	#  Note that this could mislead if the user moved it to a different
	#  dir on the root fs.
	if (!-e "$mount_point/$hd_abs") {
	  warning_test "${init_file}($.): $_\n\t$cmd: missing from root fs.\n";
	} elsif (!-x _) {
	  warning_test "$init_file($.): $_\n\t$cmd: not executable on root fs.\n";
	}
      }
    }
    close(INITF);
    info(0, "Done with $init_file\n");
    $checked{$init_file} = 1;
  }			# end of foreach
}



sub check_termcap {
  my $error;  

  # Let's first discover whether termcap or terminfo exists
  # we can decide how to interpret the termcap info.

  # terminfo first
  # We assume a terminfo file is not being used .. hum
  if (-d "$mount_point/etc/terminfo") {

      # There should at least be a linux entry, and infocmp needs to exist.x
      my $infocmp = "infocmp -A $mount_point/etc/terminfo -C linux|";
     
      open(TERMCAP, "$infocmp") or
	  ( $error = error("No file $mount_point/etc/terminfo/l/linux"));
      return if $error && $error eq "ERROR";

      while (<TERMCAP>) {
	  chomp;
	  next unless $_;
	  next if /^\#/;		# Skip comments
	  next if /^\s+/;		# Skip non-head lines

	  #####  Get complete logical line
	  my($def) = $_;
	  while (/\\$/) {		# Trailing backslash => continued
	      chomp($def);		# Discard backslash
	      chomp($_ = <TERMCAP>);	# Get a line, w/o newline char
	      $def .= $_;
	  }

	  #####  Extract terminal names from line
	  my($names) = $def =~ /^([^:]+):/;
	  my(@terms) = split(/\|/, $names);
	  @Termcap{@terms} = (1) x ($#terms + 1);
      }

  }

  # termcap next
  elsif (-e "$mount_point/etc/termcap") {

      open(TERMCAP, "<$mount_point/etc/termcap") or
	  ( $error = error("No file $mount_point/etc/termcap"));
      return if $error && $error eq "ERROR";

      while (<TERMCAP>) {
	  chomp;
	  next unless $_;
	  next if /^\#/;		# Skip comments
	  next if /^\s+/;		# Skip non-head lines

	  #####  Get complete logical line
	  my($def) = $_;
	  while (/\\$/) {		# Trailing backslash => continued
	      chomp($def);		# Discard backslash
	      chomp($_ = <TERMCAP>);	# Get a line, w/o newline char
	      $def .= $_;
	  }

	  #####  Extract terminal names from line
	  my($names) = $def =~ /^([^:]+):/;
	  my(@terms) = split(/\|/, $names);
	  @Termcap{@terms} = (1) x ($#terms + 1);
      }
      close(TERMCAP);
  }
  else {
      $error = error("No termcap file or terminfo directory.");
      return if $error && $error eq "ERROR";
  }

} # end sub check_termcap

#####  END OF CHECK_ROOT_FS

##### REPLACEMENTS

sub create_fstab {

   my($NEWFSTAB) = @_;
   open(NEWFSTAB, ">$NEWFSTAB") or die "$NEWFSTAB: $!";
    
    print NEWFSTAB <<BLARD;
# DEVICE	MOUNTPOINT	TYPE	OPTIONS	DUMP	FSCKORDER
#----------------------------------------------------------------
## Choose an appropriate root mount.
# /dev/ram0       /               ext2    defaults
#/dev/ubd/0       /               ext2    defaults   1    1
# If you have this, uncomment it.
#devpts           /dev/pts        devpts  mode=0622  0    0
/proc           /proc           proc    defaults
# Entries adapted from existing fstab:
BLARD
	
    my($line);
    open(FSTAB, "/etc/fstab") or die "/etc/fstab: $!\n";

    while ($line = <FSTAB>) {
	chomp $line;
	next if $line =~ /^\#/ or $line =~ /^\s*$/;
	
	my($device, $mpt, $type, $options, @rest) = split(' ', $line);
	
	if ($device =~ m!^/(proc|dev/ram)! or $type eq "proc") {
	    ## Don't allow /proc or /dev/ram? definitions
	    next;

	} elsif ($type eq 'swap') {
	    ##  Pass swap through unchanged

	} else {
	    ##  By default:
	    ##  - Add a 'noauto' option if it doesn't already have one
	    ##  - Put mountpoint under oldroot
	    $options .= ',noauto' unless $options =~ /\bnoauto\b/;
	    if ($mpt eq '/') {
		#$mpt = "/"; # limitation of mount cmd
		$mpt = $main::oldroot; # limitation of mount cmd
	    } else {
		#$mpt =  $mpt;
		$mpt =  $main::oldroot . $mpt;
	    }
	}
	
	print NEWFSTAB join("\t", ($device, $mpt, $type, $options,
				   @rest)), "\n";
    }

    close(FSTAB);
    close(NEWFSTAB);

    info(0,"Created $NEWFSTAB\n");
} # end create_fstab


##### END REPLACEMENTS

1;






