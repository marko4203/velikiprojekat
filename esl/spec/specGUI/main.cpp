#include <stdio.h>
#include <iostream>
#include <raylib.h>
#include "nodes.hpp"
using namespace std;

// Global Variables ************************************************************************

int const GridSize = 100;
int const maxWindowSize = 1000;
int const offsetX = 20;
int const offsetY = 20;
int cellSize;

const int WALL_CODE  = 298;
const int START_CODE = 299;
const int END_CODE   = 300;
const int PATH_CODE  = 301;

Nodes grid[GridSize][GridSize];

int pathXarray[GridSize * GridSize];
int pathYarray[GridSize * GridSize];
int pathLength = 0;

int startX = -1;
int startY = -1;
int endX = -1;
int endY = -1;

int currentX = 0;
int currentY = 0;

bool solved = false;
bool noPathFound = false;

bool visited[GridSize][GridSize] = {false};

// Interaction states
enum InteractionState {
    PLACING_WALLS,
    PLACING_START,
    PLACING_END,
    SOLVING
};

InteractionState state = PLACING_WALLS;

// Functions *******************************************************************************
void display(Nodes grid[][GridSize], int GridSize);
void evaluateSurroundingNodes(int currentX,int currentY);
void moveNode();
void readWalls();
void finalPath();
void drawGrid();

// Main function ***************************************************************************
int main(){

    // Initialize each node with its coordinates
    for (int x = 0; x < GridSize; x++) {
        for (int y = 0; y < GridSize; y++) {
            grid[x][y] = Nodes(x, y, 0);
        }
    }

    // Calculate cellSize to fit in max window size
    cellSize = (maxWindowSize - offsetX * 2) / GridSize;
    int windowWidth = GridSize * cellSize + offsetX * 2;
    int windowHeight = GridSize * cellSize + offsetY * 2 + 40; // Extra space for instructions
    InitWindow(windowWidth, windowHeight, "Grid Navigation");
    SetTargetFPS(60);
    
    bool isMouseDragging = false;
    
    // Main loop - handle user interaction
    while(!WindowShouldClose()){
        
        // Get mouse position
        Vector2 mousePos = GetMousePosition();
        int mouseGridX = (mousePos.x - offsetX) / cellSize;
        int mouseGridY = (mousePos.y - offsetY) / cellSize;
        
        // Check if mouse is within grid bounds
        bool inBounds = (mouseGridX >= 0 && mouseGridX < GridSize && 
                        mouseGridY >= 0 && mouseGridY < GridSize);
        
        // Handle state transitions with Enter key
        if(IsKeyPressed(KEY_ENTER)){
            if(state == PLACING_WALLS){
                state = PLACING_START;
            } else if(state == PLACING_START && startX != -1){
                state = PLACING_END;
            } else if(state == PLACING_END && endX != -1){
                state = SOLVING;
                currentX = startX;
                currentY = startY;
                // Start solving
                break;
            }
        }
        
        // Handle mouse input based on state
        if(state == PLACING_WALLS){
            // Hold and drag to place walls
            if(IsMouseButtonDown(MOUSE_LEFT_BUTTON) && inBounds){
                if(grid[mouseGridX][mouseGridY].getDistance() == 0){
                    grid[mouseGridX][mouseGridY].setDistance(WALL_CODE);
                }
            }
            // Right click to remove walls
            if(IsMouseButtonDown(MOUSE_RIGHT_BUTTON) && inBounds){
                if(grid[mouseGridX][mouseGridY].getDistance() == WALL_CODE){
                    grid[mouseGridX][mouseGridY].setDistance(0);
                }
            }
        } 
        else if(state == PLACING_START){
            if(IsMouseButtonPressed(MOUSE_LEFT_BUTTON) && inBounds){
                // If clicking on existing start, remove it
                if(mouseGridX == startX && mouseGridY == startY){
                    grid[startX][startY].setDistance(0);
                    startX = -1;
                    startY = -1;
                }
                // Otherwise, place start node (if not wall)
                else if(grid[mouseGridX][mouseGridY].getDistance() != WALL_CODE){
                    // Remove old start if exists
                    if(startX != -1){
                        grid[startX][startY].setDistance(0);
                    }
                    startX = mouseGridX;
                    startY = mouseGridY;
                    grid[startX][startY].setDistance(START_CODE);
                }
            }
        }
        else if(state == PLACING_END){
            if(IsMouseButtonPressed(MOUSE_LEFT_BUTTON) && inBounds){
                // If clicking on existing end, remove it
                if(mouseGridX == endX && mouseGridY == endY){
                    grid[endX][endY].setDistance(0);
                    endX = -1;
                    endY = -1;
                }
                // Otherwise, place end node (if not wall or start)
                else if(grid[mouseGridX][mouseGridY].getDistance() != WALL_CODE &&
                        grid[mouseGridX][mouseGridY].getDistance() != START_CODE){
                    // Remove old end if exists
                    if(endX != -1){
                        grid[endX][endY].setDistance(0);
                    }
                    endX = mouseGridX;
                    endY = mouseGridY;
                    grid[endX][endY].setDistance(END_CODE);
                }
            }
        }
        
        // Draw
        BeginDrawing();
        ClearBackground(BLACK);
        drawGrid();
        
        // Draw instructions
        const char* instructions = "";
        if(state == PLACING_WALLS){
            instructions = "PLACE WALLS: Hold left mouse to draw, right mouse to erase. Press ENTER when done.";
        } else if(state == PLACING_START){
            instructions = "PLACE START: Click to place/remove green start node. Press ENTER when done.";
        } else if(state == PLACING_END){
            instructions = "PLACE END: Click to place/remove red end node. Press ENTER to solve.";
        }
        DrawText(instructions, 10, windowHeight - 30, 14, WHITE);
        
        EndDrawing();
    }
    
    // If window was closed during setup, exit
    if(WindowShouldClose()){
        CloseWindow();
        return 0;
    }
    
    // Solving phase
    while(!solved && !WindowShouldClose()){
        evaluateSurroundingNodes(currentX, currentY);
        moveNode();
    }
    
    if(WindowShouldClose()){
        CloseWindow();
        return 0;
    }

    if(!noPathFound){
        finalPath();
    }

    // Display final path animation or red grid if no path
    int pathIndex = pathLength - 1;
    while(!WindowShouldClose()){
        BeginDrawing();
        ClearBackground(BLACK);
        drawGrid();
        
        if(noPathFound){
            // Make entire grid red
            for(int x = 0; x < GridSize; x++){
                for(int y = 0; y < GridSize; y++){
                    DrawRectangle(offsetX + x * cellSize,
                                  offsetY + y * cellSize,
                                  cellSize,
                                  cellSize,
                                  RED);
                    DrawRectangleLines(offsetX + x * cellSize,
                                       offsetY + y * cellSize,
                                       cellSize,
                                       cellSize,
                                       BLACK);
                }
            }
            DrawText("No valid path found! Close window to exit.", 10, windowHeight - 30, 14, WHITE);
        } else {
            // Draw all path nodes up to pathIndex in orange
            for(int i = pathLength - 1; i >= pathIndex; i--){
                DrawRectangle(offsetX + pathXarray[i] * cellSize,
                              offsetY + pathYarray[i] * cellSize,
                              cellSize,
                              cellSize,
                              ORANGE);
            }
            
            // Zameniti pathLength sa pathIndex za animaciju u for loopu iznad ovog komentara i otkomentarisati sledeći deo
            if(pathIndex > 0){
                pathIndex--;
            }
            
            DrawText("Path found! Close window to exit.", 10, windowHeight - 30, 14, WHITE);
        }
        
        EndDrawing();
    }
    
    CloseWindow();
    return 0;
}


void display(Nodes grid[][GridSize], int GridSize){
    system("clear");
    cout << "Grid (" << GridSize << "x" << GridSize << "):\n\n";

    for (int x = 0; x < GridSize; x++) {
        for (int y = 0; y < GridSize; y++) {
            int distance = grid[x][y].getDistance();
            string s;

            if (distance == START_CODE) {
                s = "  S  ";
            } else if (distance == END_CODE) {
                s = "  E  ";
            } else if (distance == WALL_CODE) {
                s = "█████";
            } else {
                int dist = grid[x][y].getDistance();
                if (dist == 0) {
                    s = "[   ]";
                } else {
                    s = " " + to_string(dist);
                }
            }

            // pad the string with spaces to 5 characters
            int padding = 5 - s.size();
            cout << s;
            for (int k = 0; k < padding; k++) cout << " ";
        }
        cout << "\n";
    }
}


void evaluateSurroundingNodes(int x,int y){
    int i, j, distance;
    for (i = x - 1; i <= x + 1; i++) {
        for (j = y - 1; j <= y + 1; j++) {
            if (i >= 0 && i < GridSize && j >= 0 && j < GridSize && !(i == x && j == y)) {
                if(grid[i][j].getDistance() != WALL_CODE && grid[i][j].getDistance() != START_CODE && grid[i][j].getDistance() != END_CODE) {
                    int dx = abs(endX - i);
                    int dy = abs(endY - j);
                    distance = 2*abs(dx - dy) + 3 * (dx < dy ? dx : dy);
                    grid[i][j].setDistance(distance);
                    if(grid[i][j].getParentX() == -1){grid[i][j].setParent(x, y);}
                } else if(grid[i][j].getDistance() == END_CODE){
                    grid[i][j].setParent(x, y);
                    solved = true;
                }    
            }
        }
    }        
}

void moveNode(){
    int minDistance = 100000;
    int nextX = -1, nextY = -1;
    
    for (int x = 0; x < GridSize; x++) {
        for (int y = 0; y < GridSize; y++) {
            // Skip if already visited
            if (!visited[x][y]) {
                int dist = grid[x][y].getDistance();
                if (dist > 0 && dist < 298 && dist < minDistance) {
                    minDistance = dist;
                    nextX = x;
                    nextY = y;
                }
            }
        }
    }
    
    // Move to the new node if found
    if (nextX != -1 && nextY != -1) {
        visited[currentX][currentY] = true;
        currentX = nextX;
        currentY = nextY;
    } else {
        cout << "Greška:moveNode() Nije našao novi node.\n";
        solved = true;
        noPathFound = true;
    }
}

void readWalls(){
    cout << "Enter wall coordinates as x y pairs (0-indexed). Enter -1 -1 to finish:\n";
    int x, y;
    while (true) {
        cin >> x >> y;
        if (x == -1 && y == -1) {
            break;
        }

        if (x >= 0 && x < GridSize && y >= 0 && y < GridSize) {
            if ((x == startX && y == startY) || (x == endX && y == endY)) {
                cout << "Cannot place wall on start or end node. Try again.\n";
            } else {
                grid[x][y].setDistance(WALL_CODE);
            }
        } else {
            cout << "Coordinates out of bounds. Try again.\n";
        }


        system("clear");
        display(grid, GridSize);
        cout << "Enter wall coordinates as x y pairs (0-indexed). Enter -1 -1 to finish:\n";
    }
}

void finalPath(){
    int i = grid[endX][endY].getParentX();
    int j = grid[endX][endY].getParentY();
    int parentX, parentY;
    pathLength = 0;

    cout << "Final path:" << endl;

    while(grid[i][j].getDistance() != START_CODE){
        if(!(i == endX && j == endY)) {cout << "(" << i << ", " << j << ")" << endl;}
        // Store the path coordinates
        grid[i][j].setDistance(PATH_CODE);
        pathXarray[pathLength] = i;
        pathYarray[pathLength] = j;
        pathLength++;
        
        parentX = grid[i][j].getParentX();
        parentY = grid[i][j].getParentY();
        i = parentX;
        j = parentY;
    }
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
            } else {
                // All path nodes are gray (no color change for explored nodes)
                color = GRAY;
            }

            // Draw filled square
            DrawRectangle(offsetX + x * cellSize,
                          offsetY + y * cellSize,
                          cellSize,
                          cellSize,
                          color);

            // Grid lines
            DrawRectangleLines(offsetX + x * cellSize,
                               offsetY + y * cellSize,
                               cellSize,
                               cellSize,
                               BLACK);
        }
    }
}