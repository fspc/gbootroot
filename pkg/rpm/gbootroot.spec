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

The required perl modules perl-Expect, perl-IO-Stty, perl-IO-Tty are 
available for download from prdownloads.sourceforge.net/gbootroot.

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
%files  -f %{_topdir}/SOURCES/filelist
%docdir /usr/share/doc/gbootroot
%attr(4755, root, root) /usr/bin/uml_net
%config /etc/gbootroot/gbootrootrc

# Just include this
##/usr/lib/menu/gbootroot


%changelog

