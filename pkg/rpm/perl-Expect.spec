# A SPEC to crreate a rpm package from Expect.  This should work on all
# distributions using >= perl5.

# Update this according to version
%define version 1.12
%define release 1


Summary:      Expect.pm (%{version}) - Perl Expect interface
Name:         perl-Expect
Version:      %{version}
Release:      %{release}
Copyright:    GPL
Group:        Development/Perl
Source:       http://www.perl.com/CPAN/authors/id/R/RG/RGIERSIG/Expect-%{version}.tar.gz
URL:          http://gbootroot.sourceforge.net
Distribution: BootRoot
Vendor:       Free Software
Packager:     Jonathan Rosenbaum <freesource@users.sourceforge.net>


# Dependencies  
Requires: perl-IO-Stty, perl-IO-Tty
AutoReqProv: no


%description
The Expect module is a successor of Comm.pl and a descendent of Chat.pl. It
more closely ressembles the Tcl Expect language than its predecessors. It
does not contain any of the networking code found in Comm.pl. I suspect this
would be obsolete anyway given the advent of IO::Socket and external tools
such as netcat.

Expect.pm is an attempt to have more of a switch() & case: feel to make
decision processing more fluid. three separate types of debugging have
been implemented to make code production easier.

It is now possible to interconnect multiple file handles (and processes) much
like Tcl's expect. An attempt was made to enable all the features of Tcl's
expect without forcing Tcl on the victim programmer :-) .


%prep
%setup -n Expect-%{version}


#  This works if IO::Pty is put in the proper place 
%build
perl Makefile.PL LIB=/usr/lib/perl5/site_perl
make


%install
make install
install -d /usr/share/doc/perl-Expect/examples/kibitz
cp -fa README /usr/share/doc/perl-Expect/README
gzip -9c Changes > /usr/share/doc/perl-Expect/changelog.gz
cp Expect.pod /usr/share/doc/perl-Expect/Expect.pod
cp -fa tutorial/* /usr/share/doc/perl-Expect/examples
cp -fa examples/kibitz/* /usr/share/doc/perl-Expect

# nothing to clean
%clean


%files
%docdir /usr/share/doc/perl-Expect
/usr/share/doc/perl-Expect/README
/usr/share/doc/perl-Expect/changelog.gz
/usr/share/doc/perl-Expect/Expect.pod
/usr/share/doc/perl-Expect/examples/1.A.Intro
/usr/share/doc/perl-Expect/examples/2.A.ftp
/usr/share/doc/perl-Expect/examples/2.B.rlogin
/usr/share/doc/perl-Expect/examples/3.A.debugging
/usr/share/doc/perl-Expect/examples/4.A.top
/usr/share/doc/perl-Expect/examples/5.A.top
/usr/share/doc/perl-Expect/examples/5.B.top
/usr/share/doc/perl-Expect/examples/6.A.smtp-verify
/usr/share/doc/perl-Expect/examples/6.B.modem-init
/usr/share/doc/perl-Expect/examples/README
/usr/share/doc/perl-Expect/examples/kibitz/Changelog
/usr/share/doc/perl-Expect/examples/kibitz/README
/usr/share/doc/perl-Expect/examples/kibitz/kibitz
/usr/share/doc/perl-Expect/examples/kibitz/kibitz.man
/usr/lib/perl5/site_perl/Expect.pm
/usr/lib/perl5/site_perl/Expect.pod
/usr/share/man/man3/Expect.3pm



%changelog

