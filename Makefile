
all: install

install:
	install -d /usr/bin
	cp -fa gbootroot /usr/bin/gbootroot
	install -d /usr/lib/bootroot
	cp -fa yard_chrooted_tests /usr/lib/bootroot/yard_chrooted_tests
	cp -fa genext2fs/genext2fs /usr/lib/bootroot/genext2fs
	cp -fa expect_uml /usr/lib/bootroot/expect_uml
	install -d /usr/lib/bootroot/root_filesystem
	chmod 0666 root_filesystem/root_fs_helper
	cp -fa root_filesystem/root_fs_helper /usr/lib/bootroot/root_filesystem
	cp -fa root_filesystem/Initrd.gz /usr/lib/bootroot/root_filesystem
	cp -fa yard/scripts/make_debian /usr/bin/make_debian
	install -d /usr/share/perl5/BootRoot
	cp -fa BootRoot/*.pm /usr/share/perl5/BootRoot
	install -d /usr/share/gbootroot/yard/Replacements
	cp -fa yard/replacements/* /usr/share/gbootroot/yard/Replacements
	install -d /usr/lib/bootroot/yard/Replacements/lib/modules
	cp -fa user-mode-linux/usr/lib/uml/modules* /usr/lib/bootroot/yard/Replacements/lib/modules
	cp -fa user-mode-linux/usr/lib/uml/config /usr/lib/bootroot/yard/Replacements/lib/modules
	cp -fa user-mode-linux/usr/lib/uml/CVS /usr/lib/bootroot/yard/Replacements/lib/modules/CVS
	install -d /usr/lib/uml
	cp -fa user-mode-linux/usr/lib/uml/port-helper /usr/lib/uml/port-helper
	install -d /usr/share/gbootroot/yard/templates
	chmod 0444 yard/templates/*.yard
	cp -fa yard/templates/Example* /usr/share/gbootroot/yard/templates
	cp -fa yard/templates/Helper.yard /usr/share/gbootroot/yard/templates
	install -d /usr/share/gbootroot/genext2fs
	cp -fa genext2fs/genext2fs.c /usr/share/gbootroot/genext2fs
	cp -fa genext2fs/Makefile /usr/share/gbootroot/genext2fs
	cp -fa genext2fs/dev* /usr/share/gbootroot/genext2fs
	cp -fa user-mode-linux/usr/bin/uml_* /usr/bin
	chown 0:0 /usr/bin/uml_*
	chmod 4755 /usr/bin/uml_net
	cp -fa user-mode-linux/usr/bin/tunctl /usr/bin/tunctl
	cp -fa user-mode-linux/usr/bin/linux /usr/bin/linux
	install -d /etc/gbootroot
	cp -fa gbootrootrc /etc/gbootroot/gbootrootrc
	install -d /usr/X11R6/include/X11/pixmaps
	cp -fa gbootroot.xpm /usr/X11R6/include/X11/pixmaps/gbootroot.xpm
	install -d /usr/share/doc/gbootroot/html/images
	cp -fa doc/html/{*html,*4} /usr/share/doc/gbootroot/html
	cp -fa doc/html/images/{*jpg,*gif} /usr/share/doc/gbootroot/html/images
	cp -fa Changes /usr/share/doc/gbootroot/Changes

remove:
	rm /usr/bin/gbootroot
	rm -rf /usr/lib/bootroot
	rm -rf /usr/lib/uml
	rm /usr/bin/make_debian
	rm /usr/share/perl5/BootRoot/*
	rmdir /usr/share/perl5/BootRoot
	rm -rf /usr/share/gbootroot
	rm /usr/bin/uml_*
	rm /usr/bin/tunctl
	rm /usr/bin/linux
	rm /etc/gbootroot/gbootrootrc
	rmdir /etc/gbootroot
	rm /usr/X11R6/include/X11/pixmaps/gbootroot.xpm
	rm -rf /usr/share/doc/gbootroot


