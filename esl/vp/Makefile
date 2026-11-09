#	Usage:
#	make - compiles all binary
#	make run - runs the program
#	make clean - remove all binaries and objects

CC = g++
SYSTEMC_HOME ?= ${SYSTEMC}

SOURCE_CPP=$(wildcard *.cpp)
SOURCE_HPP=$(wildcard *.hpp)

TARGET=vp

.PHONY: all clean run

all: $(TARGET)

$(TARGET): $(SOURCE_CPP) $(SOURCE_HPP)
	@echo "Compiling..."
	$(CC) -std=c++17 -I$(SYSTEMC_HOME)/include -L$(SYSTEMC_HOME)/lib-linux64 -o $@ $(SOURCE_CPP) -lsystemc -lm
	
run: $(TARGET)
	@echo "Running VP..."
	./$(TARGET)

clean:
	@echo "Cleaning up..."
	rm -f $(TARGET)
