# SPEC designed for Mandrake and Mandrake-type rpm-based distribution which
# use perl and perl-base.

# Set topdir in .rpmrcmacros .. %_topdir /usr/src/rpm
# cd /usr/src/redhat/SPECS
# place sources in /usr/src/redhat/SOURCES/
# cp  gbootroot.xpm /usr/src/redhat/SOURCES/
# rpm -ba gbootroot.spec


# Update this according to version, and if you want to copy in your own
# sources define base_dir and put them in source_dir.  Define filelist if
# you want it included in the sources.
%define version 1.4.0
%define release 1mdk
%define kversion 2.4.19
%define patch_version 40
%define util_ver 20021103
%define kernel_source linux-%{kversion}.tar.bz2
%define patch_1 uml-patch-%{kversion}-%{patch_version}.bz2
%define utilities uml_utilities_%{util_ver}.tar.bz2
%define base_dir /home/mttrader/gbootroot/gbootroot
%define source_dir %{base_dir}/sources
%define build_dir /gbootroot-%{version}
%define filelist %{base_dir}/pkg/rpm/filelist

Summary:      Boot/Root Filesystem Distribution testing and creation.
Name:         gbootroot
Version:      %{version}
Release:      %{release}
Copyright:    GPL
#	      was Utilities/System  or Development/System
Group:        Development/Other
Source:       http://prdownloads.sourceforge.net/gbootroot/gbootroot-%{version}.tar.gz
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
PreReq: perl-GTK >= 0.7002
Requires: perl-Expect, perl-IO-Stty, perl-IO-Tty
Requires: file, ash, lilo, bzip2, binutils
#Conflicts: user_mode_linux
AutoReqProv: no


%description
BootRoot makes the construction and development of distributions fun and
simple with its Root Methods such as Yard and user-mode-linux test bed.  
Finish the product with a Boot Method (2-disk compression supported).  
Normal (non-root) users can make root filesystems and boot disks.
There is a MTD Emulator useful for running distributions made with the 
jffs/jffs2 filesystem.

The required perl modules perl-Expect, perl-IO-Stty, perl-IO-Tty are 
available for download from prdownloads.sourceforge.net/gbootroot.

Please note that there are two types of rpms packaged for gbootroot.  
Distributions which require perl-GTK and require perl-base for perl such as 
Mandrake should use the mdk rpm.  Distributions which require Gtk-Perl and 
only require perl for perl such as Red Hat should use the rpm not marked 
as mdk. 


%prep
%setup -n gbootroot-%{version}
chown -R root:root .
if [ ! -e $RPM_BUILD_DIR/%{build_dir}/sources/%{kernel_source} ] ; then  
    if [ -e %{source_dir}/%{kernel_source} ] ; then
	cp -fa %{source_dir}/%{kernel_source} $RPM_BUILD_DIR/%{build_dir}/sources;
    fi;
fi;
if [ ! -e $RPM_BUILD_DIR/%{build_dir}/sources/%{patch_1} ] ; then  
    if [ -e %{source_dir}/%{patch_1} ] ; then
    cp -fa %{source_dir}/%{patch_1} $RPM_BUILD_DIR/%{build_dir}/sources;
    fi;
fi;
if [ ! -e $RPM_BUILD_DIR/%{build_dir}/sources/%{utilities} ] ; then  
    if [ -e %{source_dir}/%{patch_1} ] ; then
    cp -fa %{source_dir}/%{utilities} $RPM_BUILD_DIR/%{build_dir}/sources;
    fi;
fi;

%build
make

%install
make install

%clean
make clean
make clean-sources

# Update this as necessary
# dswim -ql gbootroot > ~/gbootroot/gbootroot/list
# will read this all from a files list %files -f filelist
%files -f %{_topdir}/BUILD/%{build_dir}/pkg/rpm/filelist
%docdir /usr/share/doc/gbootroot
%attr(4755, root, root) /usr/bin/uml_net
%config /etc/gbootroot/gbootrootrc


# Just include this
##/usr/lib/menu/gbootroot


%changelog


