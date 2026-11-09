#ifndef BRAM_HPP
#define BRAM_HPP

#include "defines.hpp"

class Bram : public sc_core::sc_module {

public:
    Bram(sc_core::sc_module_name name);
    
    tlm_utils::simple_target_socket<Bram> tsock_a;
    tlm_utils::simple_target_socket<Bram> tsock_b;

    void b_transport(tlm::tlm_generic_payload&, sc_core::sc_time&);
    
private:
    sc_bv<24> mem[BRAM_SIZE];
};

#endif
