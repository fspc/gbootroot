
all:

install:
	install -d /usr/bin
	cp -fa gbootroot /usr/bin/gbootroot
	cp -fa yard_chrooted_tests /usr/bin/yard_chrooted_tests
	install -d /usr/share/perl5/BootRoot
	cp -fa BootRoot/*.pm /usr/share/perl5/BootRoot
	install -d /usr/share/gbootroot/yard/replacements
	cp -fa yard/replacements/* /usr/share/gbootroot/yard/replacements
	install -d /usr/share/gbootroot/yard/templates
	chmod 444 yard/templates/*.yard
	cp -fa yard/templates/*.yard /usr/share/gbootroot/yard/templates	
	cp -fa user-mode-linux/usr/bin/uml_* /usr/bin
	cp -fa user-mode-linux/usr/bin/linux /usr/bin/linux

remove: