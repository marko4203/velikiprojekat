#include "nodes.hpp"

Nodes::Nodes() : x(0), y(0), distance(0), parentX(101), parentY(101) {
}

Nodes::Nodes(sc_uint<7> x, sc_uint<7> y, sc_uint<9> distance) : x(x), y(y), distance(distance), parentX(101), parentY(101){
}

/*void Nodes::updateDistance(int endX, int endY){
    int dx = abs(endX - x);
    int dy = abs(endY - y);
    distance = 2*abs(dx - dy) + 3 * (dx < dy ? dx : dy);
}*/

sc_uint<9> Nodes::getDistance() const { return distance; }
void Nodes::setDistance(sc_uint<9> d) { distance = d; }
void Nodes::setParent(sc_uint<7> px, sc_uint<7> py) { parentX = px; parentY = py; }
sc_uint<7> Nodes::getParentX() const { return parentX; }
sc_uint<7> Nodes::getParentY() const { return parentY; }