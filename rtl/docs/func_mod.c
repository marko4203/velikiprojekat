#include <stdlib.h>

#define GRID_SIZE   100
#define TOTAL_NODES 10000
#define VAL_WALL    298
#define VAL_START   299
#define VAL_END     300

int distance[TOTAL_NODES];
int parentX[TOTAL_NODES];
int parentY[TOTAL_NODES];
int parentValid[TOTAL_NODES];
int visited[TOTAL_NODES];

int currentX;
int currentY;
int startX;
int startY;
int endX;
int endY;
int solved;

void evaluateSurroundingNodes(int x, int y) {
    int i, j, d, dx, dy, h, a;

    for (i = x - 1; i <= x + 1; i++) {
        for (j = y - 1; j <= y + 1; j++) {

            if (i < 0 || i >= GRID_SIZE) continue;
            if (j < 0 || j >= GRID_SIZE) continue;
            if (i == x && j == y)        continue;

            a = j * GRID_SIZE + i;
            d = distance[a];

            if (d != VAL_WALL && d != VAL_START && d != VAL_END) {

                dx = endX - i;
                if (dx < 0) dx = -dx;

                dy = endY - j;
                if (dy < 0) dy = -dy;
                
                if (dx > dy) h = 2 * (dx - dy) + 3 * dy;
                else         h = 2 * (dy - dx) + 3 * dx;
                
                distance[a] = h;

                if (!parentValid[a]) {
                    parentX[a] = x;
                    parentY[a] = y;
                    parentValid[a] = 1;
                }

            } else if (d == VAL_END) {
                parentX[a] = x;
                parentY[a] = y;
                parentValid[a] = 1;
                solved = 1;
            }
        }
    }
}

void moveNode() {
    int minDistance = 100000;
    int nextX = 0;
    int nextY = 0;
    int found = 0;
    int x, y, a, dist;

    for (x = 0; x < GRID_SIZE; x++) {
        for (y = 0; y < GRID_SIZE; y++) {

            a = y * GRID_SIZE + x;

            if (!visited[a]) {
                dist = distance[a];

                if (dist > 0 && dist < VAL_WALL && dist < minDistance) {
                    minDistance = dist;
                    nextX = x;
                    nextY = y;
                    found = 1;
                }
            }
        }
    }

    if (found) {
        visited[currentY * GRID_SIZE + currentX] = 1;
        currentX = nextX;
        currentY = nextY;
    } else {
        solved = 1;
    }
}
