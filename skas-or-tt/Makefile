CC=gcc
CFLAGS=-Wall -O2

SRC=skas-or-tt.c
OBJS=$(patsubst %.c,%.o, $(SRC))


all: skas-or-tt 

skas-or-tt: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS) -o $@

$(OBJS): %.o : %.c
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJS): Makefile

clean:
	rm -f *.o *.a core skas-or-tt 
