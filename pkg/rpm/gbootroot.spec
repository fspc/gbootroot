# SPEC designed for RedHat and RedHat-type rpm-based distribution which
# just use perl, and not perl-base.

# Set topdir in .rpmrcmacros .. %_topdir /usr/src/rpm
# cd /usr/src/redhat/SPECS
# place sources in /usr/src/redhat/SOURCES/
# cp  gbootroot.xpm /usr/src/redhat/SOURCES/
# rpm -ba gbootroot.spec


# Update this according to version
%define version 1.3.4
%define release 1


Summary:      Boot/Root Filesystem Distribution testing and creation.
Name:         gbootroot
Version:      %{version}
Release:      %{release}
Copyright:    GPL
#	      was Utilities/System  or Development/System
Group:        Development/Other
Source:       http://prdownloads.sourceforge.net/gbootroot/gbootroot_%{version}.orig.tar.gz
URL:          http://gbootroot.sourceforge.net
Distribution: BootRoot
Vendor:       Free Software
Packager:     Jonathan Rosenbaum <freesource@users.sourceforge.net>


# Place icon in rpm sources directory prior to build
Icon:         gbootroot.xpm


# Extras
#Patch:       gbootroot-1.3.4-buildroot.patch
#Buildroot:   /home/somebody


# Dependencies  .. can you have two alternative deps like with deb?
PreReq: Gtk-Perl >= 0.7002
Requires: perl-Expect, perl-IO-Stty, perl-IO-Tty
Requires: file, ash, lilo, bzip2, binutils
#Conflicts: user_mode_linux
AutoReqProv: no


%description
BootRoot makes the construction and development of distributions fun and
simple with its Root Methods such as Yard and user-mode-linux test bed.  
Finish the product with a Boot Method (2-disk compression supported).  
Normal (non-root) users can make root filesystems and boot disks.


%prep
%setup -n gbootroot-%{version}.orig
chown -R root:root .

# make just does an install
%build

%install
make

# nothing to clean
%clean


# Update this as necessary
# dswim -ql gbootroot > ~/gbootroot/gbootroot/list
# will read this all from a files list %files -f filelist
%files
%docdir /usr/share/doc/gbootroot
%attr(4755, root, root) /usr/bin/uml_net
%config /etc/gbootroot/gbootrootrc

##/usr/lib/menu/gbootroot
/usr/bin/gbootroot
/usr/bin/make_debian
/usr/bin/uml_mconsole
/usr/bin/uml_moo
/usr/bin/uml_switch
/usr/bin/linux
/usr/lib/bootroot/yard_chrooted_tests
/usr/lib/bootroot/genext2fs
/usr/lib/bootroot/expect_uml
/usr/lib/bootroot/root_filesystem/root_fs_helper
/usr/lib/bootroot/yard/Replacements/lib/modules/modules-2.2.tar
/usr/lib/bootroot/yard/Replacements/lib/modules/modules-2.4.tar
/usr/lib/bootroot/yard/Replacements/lib/modules/config
/usr/lib/bootroot/yard/Replacements/lib/modules/CVS/Root
/usr/lib/bootroot/yard/Replacements/lib/modules/CVS/Repository
/usr/lib/bootroot/yard/Replacements/lib/modules/CVS/Entries
/usr/lib/uml/port-helper
/usr/share/perl5/BootRoot/BootRoot.pm
/usr/share/perl5/BootRoot/Error.pm
/usr/share/perl5/BootRoot/UML.pm
/usr/share/perl5/BootRoot/Yard.pm
/usr/share/perl5/BootRoot/YardBox.pm
/usr/share/perl5/BootRoot/lsMode.pm
/usr/share/gbootroot/yard/Replacements/CVS/Root
/usr/share/gbootroot/yard/Replacements/CVS/Repository
/usr/share/gbootroot/yard/Replacements/CVS/Entries
/usr/share/gbootroot/yard/Replacements/dev/CVS/Root
/usr/share/gbootroot/yard/Replacements/dev/CVS/Repository
/usr/share/gbootroot/yard/Replacements/dev/CVS/Entries
/usr/share/gbootroot/yard/Replacements/etc/CVS/Root
/usr/share/gbootroot/yard/Replacements/etc/CVS/Repository
/usr/share/gbootroot/yard/Replacements/etc/CVS/Entries
/usr/share/gbootroot/yard/Replacements/etc/network/CVS/Root
/usr/share/gbootroot/yard/Replacements/etc/network/CVS/Repository
/usr/share/gbootroot/yard/Replacements/etc/network/CVS/Entries
/usr/share/gbootroot/yard/Replacements/etc/network/interfaces
/usr/share/gbootroot/yard/Replacements/etc/fstab.debian
/usr/share/gbootroot/yard/Replacements/etc/gettydefs
/usr/share/gbootroot/yard/Replacements/etc/group-debian
/usr/share/gbootroot/yard/Replacements/etc/group.debian
/usr/share/gbootroot/yard/Replacements/etc/hostname
/usr/share/gbootroot/yard/Replacements/etc/hosts
/usr/share/gbootroot/yard/Replacements/etc/inittab
/usr/share/gbootroot/yard/Replacements/etc/inittab.agetty
/usr/share/gbootroot/yard/Replacements/etc/inittab.debian
/usr/share/gbootroot/yard/Replacements/etc/inittab.mingetty
/usr/share/gbootroot/yard/Replacements/etc/ld.so.conf
/usr/share/gbootroot/yard/Replacements/etc/motd
/usr/share/gbootroot/yard/Replacements/etc/networks
/usr/share/gbootroot/yard/Replacements/etc/pam.conf
/usr/share/gbootroot/yard/Replacements/etc/passwd
/usr/share/gbootroot/yard/Replacements/etc/passwd-debian
/usr/share/gbootroot/yard/Replacements/etc/passwd.debian
/usr/share/gbootroot/yard/Replacements/etc/rc
/usr/share/gbootroot/yard/Replacements/etc/securetty.debian
/usr/share/gbootroot/yard/Replacements/etc/shadow.debian
/usr/share/gbootroot/yard/Replacements/etc/termcap
/usr/share/gbootroot/yard/Replacements/etc/ttytype
/usr/share/gbootroot/yard/Replacements/etc/pam.d/CVS/Root
/usr/share/gbootroot/yard/Replacements/etc/pam.d/CVS/Repository
/usr/share/gbootroot/yard/Replacements/etc/pam.d/CVS/Entries
/usr/share/gbootroot/yard/Replacements/etc/pam.d/other
/usr/share/gbootroot/yard/Replacements/etc/apt/CVS/Root
/usr/share/gbootroot/yard/Replacements/etc/apt/CVS/Repository
/usr/share/gbootroot/yard/Replacements/etc/apt/CVS/Entries
/usr/share/gbootroot/yard/Replacements/etc/apt/sources.list
/usr/share/gbootroot/yard/Replacements/etc/init.d/rcS.example
/usr/share/gbootroot/yard/Replacements/etc/init.d/rc.example
/usr/share/gbootroot/yard/Replacements/etc/init.d/CVS/Root
/usr/share/gbootroot/yard/Replacements/etc/init.d/CVS/Repository
/usr/share/gbootroot/yard/Replacements/etc/init.d/CVS/Entries
/usr/share/gbootroot/yard/Replacements/etc/init.d/halt.example
/usr/share/gbootroot/yard/Replacements/etc/init.d/reboot.example
/usr/share/gbootroot/yard/Replacements/etc/passwd.example
/usr/share/gbootroot/yard/Replacements/etc/group.example
/usr/share/gbootroot/yard/Replacements/etc/nsswitch.conf.example
/usr/share/gbootroot/yard/Replacements/etc/fstab.example
/usr/share/gbootroot/yard/Replacements/etc/inittab.example-deb
/usr/share/gbootroot/yard/Replacements/etc/inittab.example-deb-nodevfs
/usr/share/gbootroot/yard/Replacements/etc/inittab.example.agetty-slack
/usr/share/gbootroot/yard/Replacements/etc/securetty.example
/usr/share/gbootroot/yard/Replacements/etc/inittab.example.mingetty-rpm-nodevfs
/usr/share/gbootroot/yard/Replacements/etc/inittab.example.agetty-slack-nodevfs
/usr/share/gbootroot/yard/Replacements/etc/inittab.example.mingetty-rpm
/usr/share/gbootroot/yard/Replacements/home/CVS/Root
/usr/share/gbootroot/yard/Replacements/home/CVS/Repository
/usr/share/gbootroot/yard/Replacements/home/CVS/Entries
/usr/share/gbootroot/yard/Replacements/home/user/CVS/Root
/usr/share/gbootroot/yard/Replacements/home/user/CVS/Repository
/usr/share/gbootroot/yard/Replacements/home/user/CVS/Entries
/usr/share/gbootroot/yard/Replacements/home/user/.bash_profile.debian
/usr/share/gbootroot/yard/Replacements/home/user/.bashrc.debian
/usr/share/gbootroot/yard/Replacements/home/user/README
/usr/share/gbootroot/yard/Replacements/root/CVS/Root
/usr/share/gbootroot/yard/Replacements/root/CVS/Repository
/usr/share/gbootroot/yard/Replacements/root/CVS/Entries
/usr/share/gbootroot/yard/Replacements/root/.bashrc.debian
/usr/share/gbootroot/yard/Replacements/root/.profile
/usr/share/gbootroot/yard/Replacements/root/.profile.debian
/usr/share/gbootroot/yard/Replacements/root/umlnet
/usr/share/gbootroot/yard/templates/Example-Debian.yard
/usr/share/gbootroot/yard/templates/Example-Mini.yard
/usr/share/gbootroot/yard/templates/Example.yard
/usr/share/gbootroot/genext2fs/genext2fs.c
/usr/share/gbootroot/genext2fs/Makefile
/usr/share/gbootroot/genext2fs/dev.txt
/usr/share/gbootroot/genext2fs/device_table.txt
## AND DOCUMENTATION
/usr/share/doc/gbootroot/html/images/ABS.jpg
/usr/share/doc/gbootroot/html/images/ARS.jpg
/usr/share/doc/gbootroot/html/images/create.jpg
/usr/share/doc/gbootroot/html/images/file.jpg
/usr/share/doc/gbootroot/html/images/filesystem.jpg
/usr/share/doc/gbootroot/html/images/gBS.jpg
/usr/share/doc/gbootroot/html/images/gBSicon.jpg
/usr/share/doc/gbootroot/html/images/gbootroot.jpg
/usr/share/doc/gbootroot/html/images/paths.jpg
/usr/share/doc/gbootroot/html/images/replacements.jpg
/usr/share/doc/gbootroot/html/images/screenshot.jpg
/usr/share/doc/gbootroot/html/images/settings.jpg
/usr/share/doc/gbootroot/html/images/stripping.jpg
/usr/share/doc/gbootroot/html/images/template_search.jpg
/usr/share/doc/gbootroot/html/images/tests.jpg
/usr/share/doc/gbootroot/html/images/uml_box.jpg
/usr/share/doc/gbootroot/html/images/verbosity_box.jpg
/usr/share/doc/gbootroot/html/images/yard_box.jpg
/usr/share/doc/gbootroot/html/images/peng-movie.4.gif
/usr/share/doc/gbootroot/html/images/rateit80x18.gif
/usr/share/doc/gbootroot/html/bootroot.html
/usr/share/doc/gbootroot/html/index.html
/usr/share/doc/gbootroot/html/boot_root.4.gz
/usr/share/doc/gbootroot/copyright
## AND CHANGELOG
/usr/share/doc/gbootroot/Changes.gz
/usr/share/doc/gbootroot/changelog.Debian.gz
## xpm
/usr/X11R6/include/X11/pixmaps/gbootroot.xpm
## config


%changelog

