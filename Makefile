
all: install

install:
	install -d /usr/bin
	cp -fa gbootroot /usr/bin/gbootroot
	install -d /usr/lib/bootroot
	cp -fa yard_chrooted_tests /usr/lib/bootroot/yard_chrooted_tests
	cp -fa genext2fs/genext2fs /usr/lib/bootroot/genext2fs
	cp -fa yard/scripts/make_debian /usr/bin/make_debian
	install -d /usr/share/perl5/BootRoot
	cp -fa BootRoot/*.pm /usr/share/perl5/BootRoot
	install -d /usr/share/gbootroot/yard/Replacements
	mknod yard/replacements/dev/ubd0 b 98 0
	cp -fa yard/replacements/* /usr/share/gbootroot/yard/Replacements
	rm yard/replacements/dev/ubd0
	install -d /usr/share/gbootroot/yard/templatesx
	chmod 444 yard/templates/*.yard
	cp -fa yard/templates/Example* /usr/share/gbootroot/yard/templates
	install -d /usr/share/gbootroot/genext2fs
	cp -fa genext2fs/genext2fs.c /usr/share/gbootroot/genext2fs
	cp -fa genext2fs/Makefile /usr/share/gbootroot/genext2fs
	cp -fa genext2fs/dev* /usr/share/gbootroot/genext2fs
	cp -fa user-mode-linux/usr/bin/uml_* /usr/bin
	cp -fa user-mode-linux/usr/bin/linux /usr/bin/linux
	install -d /etc/gbootroot
	cp -fa gbootrootrc /etc/gbootroot/gbootrootrc
	install -d /usr/X11R6/include/X11/pixmaps
	cp -fa gbootroot.xpm /usr/X11R6/include/X11/pixmaps/gbootroot.xpm
	install -d /usr/share/doc/gbootroot/html/images
	cp -fa doc/html/{*html,*4} /usr/share/doc/gbootroot/html
	cp -fa doc/html/images/{*jpg,*gif} /usr/share/doc/gbootroot/html/images

remove:
	rm /usr/bin/gbootroot
	rm /usr/lib/bootroot/yard_chrooted_tests
	rm /usr/lib/bootroot/genext2fs
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

