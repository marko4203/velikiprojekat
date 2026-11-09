# Makefile za pathfinder_app (pokretati kao root zbog /dev/pathfinder*)
CC      = gcc
CFLAGS  = -O2 -Wall
EXEC    = pathfinder_app

all: $(EXEC)

$(EXEC): pathfinder_app.c
	$(CC) $(CFLAGS) -o $(EXEC) pathfinder_app.c

run: $(EXEC)
	sudo ./$(EXEC)

sim: $(EXEC)
	./$(EXEC) --sim

clean:
	rm -f $(EXEC)
