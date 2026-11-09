# Compiler and flags
CXX = g++
LIBS = -lraylib

# Directories
GUI_DIR = specGUI
TERMINAL_DIR = specTerminal

# Output binaries
GUI_BIN = $(GUI_DIR)/gui
TERMINAL_BIN = $(TERMINAL_DIR)/terminal

# Source files
GUI_SRCS = $(GUI_DIR)/main.cpp $(GUI_DIR)/nodes.cpp
TERMINAL_SRCS = $(TERMINAL_DIR)/main.cpp $(TERMINAL_DIR)/nodes.cpp

# Default target: build both
all: gui terminal

# Build GUI
gui: $(GUI_SRCS)
	$(CXX) $(CXXFLAGS) $(GUI_SRCS) -o $(GUI_BIN) $(LIBS)

# Build Terminal
terminal: $(TERMINAL_SRCS)
	$(CXX) $(CXXFLAGS) $(TERMINAL_SRCS) -o $(TERMINAL_BIN) $(LIBS)

# Clean all binaries
clean:
	rm -f $(GUI_BIN) $(TERMINAL_BIN)

.PHONY: all gui terminal clean
