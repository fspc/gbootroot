# A SPEC to crreate a rpm package from IO-Stty-.  This should work on all
# distributions using perl5.8.

# Update this according to version
%define version .02
%define release 1


Summary:      Interface to secure pseudo ttys
Name:         perl-IO-Stty
Version:      %{version}
Release:      %{release}
Copyright:    GPL
Group:        Development/Perl
Source:       http://www.perl.com/CPAN/authors/id/A/AU/AUSCHUTZ/IO-Stty-%{version}.tar.gz
URL:          http://gbootroot.sourceforge.net
Distribution: BootRoot
Vendor:       Free Software
Packager:     Jonathan Rosenbaum <freesource@users.sourceforge.net>


# Dependencies  
PreReq: perl
AutoReqProv: no


%description
This is a generic interface to handle secure pseudo terminals by perl
scripts, such as the expect library.  Compiled for Perl 5.8. 



%prep
%setup -n IO-Stty-%{version}


%build
perl Makefile.PL LIB=/usr/lib/perl5/site_perl
make


%install
make install
install -d /usr/share/doc/perl-IO-Stty/examples
cp -fa README /usr/share/doc/perl-IO-Stty/README
cp stty.pl /usr/share/doc/perl-IO-Stty/examples/stty.pl


# nothing to clean
%clean


# will read this all from a files list %files -f filelist
%files  
%docdir /usr/share/doc/perl-IO-Stty
/usr/lib/perl5/site_perl/IO/Stty.pm
/usr/lib/perl5/site_perl/IO/stty.pl
/usr/share/doc/perl-IO-Stty/examples/stty.pl
/usr/share/doc/perl-IO-Stty/README


%changelog



