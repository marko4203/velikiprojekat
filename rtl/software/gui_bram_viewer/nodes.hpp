#ifndef NODES_HPP
#define NODES_HPP
#include <cmath>
using namespace std;

class Nodes {
private:
    int x;
    int y;
    int distance;
    int parentX;
    int parentY;
public:
    Nodes();
    Nodes(int x, int y, int distance);
    // void updateDistance(int endX, int endY);
    int getDistance() const;
    void setDistance(int d);
    void setParent(int px, int py);
    int getParentX() const;
    int getParentY() const;
};

#endif
