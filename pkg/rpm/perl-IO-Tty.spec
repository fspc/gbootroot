# A SPEC to create a rpm package from IO-Tty.  This should work on all
# distributions using perl5.8.

# Update this according to version
%define version 1.02
%define release 1


Summary:      Perl module for pseudo tty IO
Name:         perl-IO-Tty
Version:      %{version}
Release:      %{release}
Copyright:    GPL
Group:        Development/Perl
Source:       http://www.perl.com/CPAN/authors/id/R/RG/RGIERSIG/IO-Tty-%{version}.tar.gz
URL:          http://gbootroot.sourceforge.net
Distribution: BootRoot
Vendor:       Free Software
Packager:     Jonathan Rosenbaum <freesource@users.sourceforge.net>


# Dependencies  
PreReq: perl
AutoReqProv: no


%description
IO::Pty provides I/O handles to the master- and slave-side of a
pseudo tty.  Compiled for Perl 5.8.


%prep
%setup -n IO-Tty-%{version}


%build
perl Makefile.PL LIB=/usr/lib/perl5/site_perl
make


# This here is a kludge to avoid versioning to allow the creation of a 
# universal package.  This is done in Debian.
%install

install -d /usr/lib/perl5/site_perl/IO/Tty
install -d /usr/lib/perl5/site_perl/auto/IO/Tty

cp -fa blib/arch/auto/IO/Tty/Tty.so /usr/lib/perl5/site_perl/auto/IO/Tty/Tty.so
cp -fa blib/arch/auto/IO/Tty/Tty.bs /usr/lib/perl5/site_perl/auto/IO/Tty/Tty.bs
cp -fa Tty.pm /usr/lib/perl5/site_perl/IO/Tty.pm
cp -fa Pty.pm /usr/lib/perl5/site_perl/IO/Pty.pm
cp -fa Tty/Constant.pm /usr/lib/perl5/site_perl/IO/Tty/Constant.pm

install -d /usr/share/man/man3
cp -fa blib/man3/IO::Pty.3pm /usr/share/man/man3/IO::Pty.3pm
cp -fa blib/man3/IO::Tty.3pm /usr/share/man/man3/IO::Tty.3pm
cp -fa blib/man3/IO::Tty::Constant.3pm /usr/share/man/man3/IO::Tty::Constant.3pm
install -d /usr/share/doc/perl-IO-Tty/examples
cp -fa try /usr/share/doc/perl-IO-Tty/examples
cp -fa README /usr/share/doc/perl-IO-Tty/README
gzip -9c ChangeLog > /usr/share/doc/perl-IO-Tty/changelog.gz

# nothing to clean
%clean


%files
%docdir /usr/share/doc/perl-IO-Tty/examples
%attr(0644, root, root) /usr/share/doc/perl-IO-Tty/examples/try
%attr(0644, root, root) /usr/share/doc/perl-IO-Tty/README
%attr(0644, root, root) /usr/share/doc/perl-IO-Tty/changelog.gz
%attr(0644, root, root) /usr/lib/perl5/site_perl/IO/Pty.pm
%attr(0644, root, root) /usr/lib/perl5/site_perl/IO/Tty.pm
%attr(0644, root, root) /usr/lib/perl5/site_perl/IO/Tty/Constant.pm
%attr(0644, root,  root) /usr/lib/perl5/site_perl/auto/IO/Tty/Tty.bs
%attr(0755, root, root) /usr/lib/perl5/site_perl/auto/IO/Tty/Tty.so
%attr(0644, root, root) /usr/share/man/man3/IO::Pty.3pm
%attr(0644, root, root) /usr/share/man/man3/IO::Tty.3pm
%attr(0644, root, root) /usr/share/man/man3/IO::Tty::Constant.3pm

%changelog

