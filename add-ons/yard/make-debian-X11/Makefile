
all: install

install:
	install -d /usr/bin
	cp -fa make_debian-X11 /usr/bin/make_debian-X11 
	install -d /usr/share/gbootroot/yard/Replacements/root
	chmod 644 replacements/root/README-debian-X11
	cp -fa replacements/root/*debian-X11 /usr/share/gbootroot/yard/Replacements/root
	cp -fa replacements/root/make_swapfile /usr/share/gbootroot/yard/Replacements/root
	install -d /usr/share/gbootroot/yard/Replacements/usr/X11R6/bin
	cp -fa replacements/usr/X11R6/bin/* /usr/share/gbootroot/yard/Replacements/usr/X11R6/bin




