
all:

install:
	install -d /usr/bin
	cp -fa gBootRoot /usr/bin/gBootRoot
	install -d /usr/share/perl5/gBootRoot
	cp -fa *.pm /usr/share/perl5/gBootRoot
	install -d /usr/share/gbootroot/yard/replacements
	cp -fa yard/replacements/* /usr/share/gbootroot/yard/replacements
	install -d /usr/share/gbootroot/yard/templates
	chmod 444 yard/templates/*.yard
	cp -fa yard/templates/*.yard /usr/share/gbootroot/yard/templates	
	cp -fa user-mode-linux/usr/bin/uml_* /usr/bin
	cp -fa user-mode-linux/usr/bin/linux /usr/bin/linux

remove: