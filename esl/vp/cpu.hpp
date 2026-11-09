#ifndef CPU_HPP
#define CPU_HPP

#include "defines.hpp"

class CPU : public sc_core::sc_module {
public:
    SC_HAS_PROCESS(CPU);
    CPU(sc_core::sc_module_name name);
    tlm_utils::simple_initiator_socket<CPU> isock_interconnect;
    sc_core::sc_in<bool> irq_in;
private:
    void cpu_process();
    
    static const int GridSize = 100;
    Nodes grid[100][100];
    sc_uint<7> startX;
    sc_uint<7> startY;
    sc_uint<7> endX;
    sc_uint<7> endY;
    sc_uint<7> currentX;
    sc_uint<7> currentY;
    sc_uint<1> solved;
    sc_uint<1> visited[100][100];
    
    void display(Nodes grid[][100], int GridSize);
    void readWalls();
    void finalPath();
};

#endif
