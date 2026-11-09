#include "bram.hpp"

Bram::Bram(sc_core::sc_module_name name) : sc_core::sc_module(name), tsock_a("tsock_a"), tsock_b("tsock_b") {
	tsock_a.register_b_transport(this, &Bram::b_transport);
	tsock_b.register_b_transport(this, &Bram::b_transport);

	for(int i = 0; i < BRAM_SIZE; i++){
	    mem[i] = 0;
	}
}

void Bram::b_transport(tlm::tlm_generic_payload &pl, sc_core::sc_time &offset){

    int addr = pl.get_address();
    int len = pl.get_data_length();
    unsigned char *buf = pl.get_data_ptr();
    tlm::tlm_command cmd = pl.get_command();

    switch(cmd){
        case tlm::TLM_READ_COMMAND:
            for(int i = 0; i < len; i++){
                sc_bv<24>* data_ptr = reinterpret_cast<sc_bv<24>*>(buf);
                data_ptr[i] = mem[addr + i];
            }
            pl.set_response_status(tlm::TLM_OK_RESPONSE);
        break;

        case tlm::TLM_WRITE_COMMAND:
            for(int i = 0; i < len; i++){
                sc_bv<24>* data_ptr = reinterpret_cast<sc_bv<24>*>(buf);
                mem[addr + i] = data_ptr[i];
            }
            pl.set_response_status(tlm::TLM_OK_RESPONSE);
        break;

        default:
            std::cout << "Error: Bram::b_transport: Unknown command" << std::endl;
            pl.set_response_status(tlm::TLM_COMMAND_ERROR_RESPONSE);
        break;
    }
    
    wait(sc_core::SC_ZERO_TIME);
}
