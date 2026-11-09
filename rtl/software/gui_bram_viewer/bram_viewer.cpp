#include <stdio.h>
#include <iostream>
#include <fstream>
#include <string>
#include <raylib.h>
#include "nodes.hpp"
using namespace std;

int const GridSize = 100;
int const maxWindowSize = 1000;
int const offsetX = 20;
int const offsetY = 20;
int cellSize;

const int WALL_CODE  = 298;
const int START_CODE = 299;
const int END_CODE   = 300;
const int PATH_CODE  = 301;

const int BRAM_WORD_BITS = 24;

Nodes grid[GridSize][GridSize];
bool visited[GridSize][GridSize] = {false};

int startX = -1;
int startY = -1;
int endX = -1;
int endY = -1;

bool dataLoaded = false;
string loadError = "";

void drawGrid();
bool loadBramInit(const char* filename);

int main(int argc, char** argv){

    for (int x = 0; x < GridSize; x++) {
        for (int y = 0; y < GridSize; y++) {
            grid[x][y] = Nodes(x, y, 0);
        }
    }

    const char* bramFile = (argc > 1) ? argv[1] : "bram_init.txt";
    dataLoaded = loadBramInit(bramFile);

    cellSize = (maxWindowSize - offsetX * 2) / GridSize;
    int windowWidth = GridSize * cellSize + offsetX * 2;
    int windowHeight = GridSize * cellSize + offsetY * 2 + 40;
    InitWindow(windowWidth, windowHeight, "BRAM Grid Viewer");
    SetTargetFPS(60);

    string status;
    if(!dataLoaded){
        status = "Failed to load '" + string(bramFile) + "': " + loadError;
    } else {
        status = "BRAM snapshot '" + string(bramFile) + "' - Start: ";
        status += (startX != -1) ? ("(" + to_string(startX) + ", " + to_string(startY) + ")") : "none";
        status += "  End: ";
        status += (endX != -1) ? ("(" + to_string(endX) + ", " + to_string(endY) + ")") : "none";
        status += "  -  viewer only, close window to exit.";
    }

    while(!WindowShouldClose()){
        BeginDrawing();
        ClearBackground(BLACK);

        if(dataLoaded){
            drawGrid();
        }

        DrawText(status.c_str(), 10, windowHeight - 30, 14, WHITE);
        EndDrawing();
    }

    CloseWindow();
    return 0;
}

bool loadBramInit(const char* filename){
    ifstream file(filename);
    if(!file.is_open()){
        loadError = "could not open file";
        return false;
    }

    string line;
    int addr = 0;
    int total = GridSize * GridSize;

    while(getline(file, line)){

        while(!line.empty() && (line.back() == '\r' || line.back() == '\n' || line.back() == ' ')){
            line.pop_back();
        }
        if(line.empty()) continue;

        if((int)line.size() != BRAM_WORD_BITS){
            loadError = "line " + to_string(addr) + " is not " + to_string(BRAM_WORD_BITS) + " bits";
            return false;
        }
        if(addr >= total){

            addr++;
            continue;
        }

        int x = addr / GridSize;
        int y = addr % GridSize;

        try {
            int distance = stoi(line.substr(0, 9), nullptr, 2);
            int parentX  = stoi(line.substr(9, 7), nullptr, 2);
            int parentY  = stoi(line.substr(16, 7), nullptr, 2);
            int v        = line[23] - '0';

            grid[x][y].setDistance(distance);
            grid[x][y].setParent(parentX, parentY);
            visited[x][y] = (v != 0);

            if(distance == START_CODE){ startX = x; startY = y; }
            if(distance == END_CODE)  { endX = x;   endY = y;   }
        } catch(...) {
            loadError = "could not parse line " + to_string(addr);
            return false;
        }

        addr++;
    }

    if(addr < total){
        loadError = "file has " + to_string(addr) + " lines, expected " + to_string(total);
        return false;
    }

    return true;
}

void drawGrid() {
    for (int x = 0; x < GridSize; x++) {
        for (int y = 0; y < GridSize; y++) {

            int distance = grid[x][y].getDistance();
            Color color;

            if (distance == START_CODE) {
                color = GREEN;
            } else if (distance == END_CODE) {
                color = RED;
            } else if (distance == WALL_CODE) {
                color = DARKGRAY;
            } else if( distance > 0 && distance < 298){
                color = ORANGE;
            } else {
                color = GRAY;
            }

            DrawRectangle(offsetX + x * cellSize,
                          offsetY + y * cellSize,
                          cellSize,
                          cellSize,
                          color);

            DrawRectangleLines(offsetX + x * cellSize,
                               offsetY + y * cellSize,
                               cellSize,
                               cellSize,
                               BLACK);
        }
    }
}
