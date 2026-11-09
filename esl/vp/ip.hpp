#ifndef IP_HPP
#define IP_HPP

#include "defines.hpp"
#define START_COORD_ADRESS 0
#define END_COORD_ADRESS 1
#define START_SIGNAL_ADRESS 2

class IP : public sc_core::sc_module {
public:
    SC_HAS_PROCESS(IP);
    IP(sc_core::sc_module_name name);
    tlm_utils::simple_target_socket<IP> tsock_interconnect;
    tlm_utils::simple_initiator_socket<IP> isock_bram;
    sc_core::sc_out<bool> irq_out;
    void b_transport(tlm::tlm_generic_payload &pl, sc_core::sc_time &offset);
    void solve();
    void evaluateSurroundingNodes(sc_uint<7> x, sc_uint<7> y);
    void moveNode();
private:
    sc_event start_event;
    sc_bv<24> bramread(int x, int y);
    void bramwrite(int x, int y, sc_bv<24> data);

    static const int GridSize = 100;
    sc_uint<7> startX;
    sc_uint<7> startY;
    sc_uint<7> endX;
    sc_uint<7> endY;
    sc_uint<7> currentX;
    sc_uint<7> currentY;
    sc_uint<1> solved;
};

#endif
