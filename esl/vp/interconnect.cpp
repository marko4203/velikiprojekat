#include "interconnect.hpp"

Interconnect::Interconnect(sc_core::sc_module_name name) : sc_core::sc_module(name), tsock_cpu("tsock_cpu"), isock_bram("isock_bram"), isock_ip("isock_ip") {
	tsock_cpu.register_b_transport(this, &Interconnect::b_transport);
}

void Interconnect::b_transport(tlm::tlm_generic_payload &pl, sc_core::sc_time &offset){

    int addr = pl.get_address();

    if (addr >= BRAM_ADDR_OFFSET && addr <= BRAM_ADDR_MAX){
	    isock_bram->b_transport(pl, offset);
    } else if (addr >= IP_ADDR_OFFSET && addr <= (IP_ADDR_OFFSET + IP_ADDR_MAX)){
	    isock_ip->b_transport(pl, offset);
    } else {
	    std::cout << "Error: Interconnect::b_transport: Invalid address 0x" << std::hex << addr << std::dec << std::endl;
	    pl.set_response_status(tlm::TLM_ADDRESS_ERROR_RESPONSE);
    }

}
