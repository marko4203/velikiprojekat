#ifndef NODES_HPP
#define NODES_HPP
#include <cmath>
#include <stdio.h>
#include <iostream>
#include <systemc>
using namespace std;
using namespace sc_dt;  // Add this to use sc_uint directly

class Nodes {
private:
    sc_uint<7> x;
    sc_uint<7> y;
    sc_uint<9> distance;
    sc_uint<7> parentX;
    sc_uint<7> parentY;
public:
    Nodes();
    Nodes(sc_uint<7> x, sc_uint<7> y, sc_uint<9> distance);  // Fixed parameter type
    //void updateDistance(int endX, int endY);
    sc_uint<9> getDistance() const;
    void setDistance(sc_uint<9> d);
    void setParent(sc_uint<7> px, sc_uint<7> py);
    sc_uint<7> getParentX() const;
    sc_uint<7> getParentY() const;
};

#endif