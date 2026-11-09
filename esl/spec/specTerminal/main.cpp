#include <stdio.h>
#include <iostream>
#include "nodes.hpp"
using namespace std;

// Global Variables ************************************************************************
int const GridSize = 30;

Nodes grid[GridSize][GridSize];

int startX = 5;
int startY = 5;
int endX = GridSize - 1;
int endY = GridSize - 1;

int currentX = 0;
int currentY = 0;

bool solved = false;

bool visited[GridSize][GridSize] = {false};

// Functions *******************************************************************************
void display(Nodes grid[][GridSize], int GridSize);
void evaluateSurroundingNodes(int currentX,int currentY);
void moveNode();
void readWalls();
void finalPath();

// Main function ***************************************************************************
int main(){

    currentX = startX;
    currentY = startY;

    // Initialize each node with its coordinates
    for (int x = 0; x < GridSize; x++) {
        for (int y = 0; y < GridSize; y++) {
            grid[x][y] = Nodes(x, y, 0);
        }
    }
    // Set start and end nodes
    grid[startX][startY].setDistance(299);
    grid[endX][endY].setDistance(300);

    // Display the grid
    display(grid, GridSize);
    
    // Read wall positions from user
    readWalls();    
    int i;
    /*for(i = 0; i < GridSize-1; i++){
        grid[i][10].setDistance(298);
    }

    for(i = GridSize-1 ; i > 13; i--){
        grid[i][13].setDistance(298);
    }

    grid[14][12].setDistance(298);
    grid[18][11].setDistance(298);*/
    
    display(grid, GridSize);

    while(!solved){
        evaluateSurroundingNodes(currentX, currentY);
        moveNode();
    }

    finalPath();

    display(grid, GridSize);

    return 0;
}


void display(Nodes grid[][GridSize], int GridSize){
    
    cout << "Grid (" << GridSize << "x" << GridSize << "):\n\n";

    for (int x = 0; x < GridSize; x++) {
        for (int y = 0; y < GridSize; y++) {
            int distance = grid[x][y].getDistance();
            string s;

            if (distance == 299) {
                s = "  S  ";
            } else if (distance == 300) {
                s = "  E  ";
            } else if (distance == 298) {
                s = "█████";
            } else if (distance == 301) {
                s = "--X--";
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
    int i, j,distance;
    for (i = x - 1; i <= x + 1; i++) {
        for (j = y - 1; j <= y + 1; j++) {
            if (i >= 0 && i < GridSize && j >= 0 && j < GridSize && !(i == x && j == y)) {
                if(grid[i][j].getDistance() != 298 && grid[i][j].getDistance() != 299 && grid[i][j].getDistance() != 300) {
                    int dx = abs(endX - i);
                    int dy = abs(endY - j);
                    distance = 2*abs(dx - dy) + 3 * (dx < dy ? dx : dy);
                    grid[i][j].setDistance(distance);
                    if(grid[i][j].getParentX() == -1){grid[i][j].setParent(x, y);}
                } else if(grid[i][j].getDistance() == 300){
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
        exit(0);
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
                grid[x][y].setDistance(298);
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
    
   // cout << "Final path:" << endl;

    while(grid[i][j].getDistance() != 299){
        //if(!(i == endX && j == endY)) {cout << "(" << i << ", " << j << ")" << endl;}
        grid[i][j].setDistance(301); 
        parentX = grid[i][j].getParentX();
        parentY = grid[i][j].getParentY();
        i = parentX;
        j = parentY;
    }
}
