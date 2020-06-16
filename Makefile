CFLAGS = -std=c99 -g -Wall -Werror
CPPFLAGS = -I$(ERL_EI_INCLUDE_DIR)
LDFLAGS = -L$(ERL_EI_LIBDIR)
LDLIBS = -lpthread -lei -lm -lmagic
PRIV = priv/
RM = rm -Rf

all: priv/libmagic_port

priv/libmagic_port: src/libmagic_port.c
	mkdir -p priv
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) $^ $(LDLIBS) -o $@

clean:
	$(RM) $(PRIV)

.PHONY: clean
