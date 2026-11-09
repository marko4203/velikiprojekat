#include "nodes.hpp"

Nodes::Nodes() : x(0), y(0), distance(0), parentX(-1), parentY(-1) {
}

Nodes::Nodes(int x, int y, int distance) : x(x), y(y), distance(distance), parentX(-1), parentY(-1){
}

/*void Nodes::updateDistance(int endX, int endY){
    int dx = abs(endX - x);
    int dy = abs(endY - y);
    distance = 10*abs(dx - dy) + 14 * (dx < dy ? dx : dy);
}*/

int Nodes::getDistance() const { return distance; }
void Nodes::setDistance(int d) { distance = d; }
void Nodes::setParent(int px, int py) { parentX = px; parentY = py; }
int Nodes::getParentX() const { return parentX; }
int Nodes::getParentY() const { return parentY; }