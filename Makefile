
all: install

install:
	install -d /usr/bin
	cp -fa gbootroot /usr/bin/gbootroot
	cp -fa yard_chrooted_tests /usr/bin/yard_chrooted_tests
	cp -fa yard/scripts/make_debian /usr/bin/make_debian
	install -d /usr/share/perl5/BootRoot
	cp -fa BootRoot/*.pm /usr/share/perl5/BootRoot
	install -d /usr/share/gbootroot/yard/Replacements
	mknod yard/replacements/dev/ubd0 b 98 0
	cp -fa yard/replacements/[!CVS]* /usr/share/gbootroot/yard/Replacements
	rm yard/replacements/dev/ubd0
	install -d /usr/share/gbootroot/yard/templates
	chmod 444 yard/templates/*.yard
	cp -fa yard/templates/*.yard /usr/share/gbootroot/yard/templates
	cp -fa user-mode-linux/usr/bin/uml_* /usr/bin
	cp -fa user-mode-linux/usr/bin/linux /usr/bin/linux
	install -d /etc/gbootroot
	cp -fa gbootrootrc /etc/gbootroot/gbootrootrc
	install -d /usr/X11R6/include/X11/pixmaps
	cp -fa gbootroot.xpm /usr/X11R6/include/X11/pixmaps/gbootroot.xpm
	install -d /usr/share/doc/gbootroot/html/images
	cp -fa doc/html/*html /usr/share/doc/gbootroot/html
	cp -fa doc/html/images/* /usr/share/doc/gbootroot/html/images

remove:
	rm /usr/bin/gbootroot
	rm /usr/bin/yard_chrooted_tests
	rm /usr/bin/make_debian
	rm /usr/share/perl5/BootRoot/*
	rmdir /usr/share/perl5/BootRoot
	rm -rf /usr/share/gbootroot
	rm /usr/bin/uml_*
	rm /usr/bin/linux
	rm /etc/gbootroot/gbootrootrc
	rmdir /etc/gbootroot
	rm /usr/X11R6/include/X11/pixmaps/gbootroot.xpm
	rm -rf /usr/share/doc/gbootroot

