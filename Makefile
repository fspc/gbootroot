
all: install

install:
	install -d /usr/bin
	cp -fa gbootroot /usr/bin/gbootroot
	cp -fa yard_chrooted_tests /usr/bin/yard_chrooted_tests
	install -d /usr/share/perl5/BootRoot
	cp -fa BootRoot/*.pm /usr/share/perl5/BootRoot
	install -d /usr/share/gbootroot/yard/Replacements
	cp -fa yard/replacements/[!CVS]* /usr/share/gbootroot/yard/Replacements
	install -d /usr/share/gbootroot/yard/templates
	chmod 444 yard/templates/*.yard
	cp -fa yard/templates/*.yard /usr/share/gbootroot/yard/templates	
	cp -fa user-mode-linux/usr/bin/uml_* /usr/bin
	cp -fa user-mode-linux/usr/bin/linux /usr/bin/linux
	install -d /etc/gbootroot
	cp -fa gbootrootrc /etc/gbootroot/gbootrootrc

remove:
	rm /usr/bin/gbootroot
	rm /usr/bin/yard_chrooted_tests
	rm /usr/share/perl5/BootRoot/*
	rmdir /usr/share/perl5/BootRoot
	rm -rf /usr/share/gbootroot
	rm /usr/bin/uml_*
	rm /usr/bin/linux
	rm /etc/gbootroot/gbootrootrc
	rmdir /etc/gbootroot


