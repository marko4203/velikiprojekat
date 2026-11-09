#ifndef INTERCONNECT_HPP
#define INTERCONNECT_HPP

#include "defines.hpp"

class Interconnect : public sc_core::sc_module {

public:
    Interconnect(sc_core::sc_module_name name);

    tlm_utils::simple_target_socket<Interconnect> tsock_cpu;
    tlm_utils::simple_initiator_socket<Interconnect> isock_bram;
    tlm_utils::simple_initiator_socket<Interconnect> isock_ip;

    void b_transport(tlm::tlm_generic_payload&, sc_core::sc_time&);
    
};

#endif
