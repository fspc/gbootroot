CC=gcc
CFLAGS=-Wall -O2

SRC=genext2fs.c
OBJS=$(patsubst %.c,%.o, $(SRC))


all: genext2fs

genext2fs: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS) -o $@

$(OBJS): %.o : %.c
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJS): Makefile

clean:
	rm -f *.o *.a core genext2fs
