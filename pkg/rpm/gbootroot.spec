# SPEC designed for RedHat and RedHat-type rpm-based distribution which
# just use perl, and not perl-base.

# cd %{_topdir}/SPECS
# place rpm source in %{_topdir}/SOURCES/
# optional: place linux*bz2, uml_patch* uml_utilities* in 
#           $HOME/gbootroot/gbootroot/sources
# cp  gbootroot.xpm %{_topdir}/SOURCES/
# rpm -ba %{_topdir}/SPECS/gbootroot.spec

# Update this according to version, and if you want to copy in your own
# sources define base_dir and put them in source_dir.  You can build this 
# package as a normal user, just make sure to adjust _topdir so that 
# /home/freesource is your own echo $HOME, for instance, /home/person.

%define home /home/freesource
%define _topdir %{home}/gbootroot
%define version 1.5.0
%define release 1
%define kversion 2.4.19
%define patch_version 50
%define util_ver 20030202
%define kernel_source linux-%{kversion}.tar.bz2
%define patch_1 uml-patch-%{kversion}-%{patch_version}.bz2
%define utilities uml_utilities_%{util_ver}.tar.bz2
%define base_dir %{home}/gbootroot/gbootroot
%define source_dir %{base_dir}/sources
%define buildd_dir /gbootroot-%{version}
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
Buildroot:   /tmp/gbootroot

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
#chown -R root:root .
if [ ! -e /tmp/gbootroot ] ; then
    mkdir /tmp/gbootroot;
fi;
install -d $HOME/gbootroot/RPMS/i386
install -d $HOME/gbootroot/BUILD
install -d $HOME/gbootroot/SOURCES
install -d $HOME/gbootroot/SPECS
install -d $HOME/gbootroot/SRPMS
if [ ! -e $RPM_BUILD_DIR/%{buildd_dir}/sources/%{kernel_source} ] ; then  
    if [ -e %{source_dir}/%{kernel_source} ] ; then
	cp -fa %{source_dir}/%{kernel_source} $RPM_BUILD_DIR/%{buildd_dir}/sources;
    fi;
fi;
if [ ! -e $RPM_BUILD_DIR/%{buildd_dir}/sources/%{patch_1} ] ; then  
    if [ -e %{source_dir}/%{patch_1} ] ; then
    cp -fa %{source_dir}/%{patch_1} $RPM_BUILD_DIR/%{buildd_dir}/sources;
    fi;
fi;
if [ ! -e $RPM_BUILD_DIR/%{buildd_dir}/sources/%{utilities} ] ; then  
    if [ -e %{source_dir}/%{patch_1} ] ; then
    cp -fa %{source_dir}/%{utilities} $RPM_BUILD_DIR/%{buildd_dir}/sources;
    fi;
fi;


%build
./configure
make

%install
make DESTDIR=$RPM_BUILD_ROOT install

%clean
make clean
#make clean-sources
rm -rf $RPM_BUILD_ROOT

# Update this as necessary
# dswim -ql gbootroot > ~/gbootroot/gbootroot/list
# will read this all from a files list %files -f filelist
%files -f %{_topdir}/BUILD/%{buildd_dir}/pkg/rpm/filelist
%attr(- root root) %docdir /usr/share/doc/gbootroot
%attr(4755, root, root) /usr/bin/uml_net
%attr(- root root) %config /etc/gbootroot/gbootrootrc

# Just include this
##/usr/lib/menu/gbootroot


%changelog

