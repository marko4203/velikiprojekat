#ifndef DEFINES_HPP
#define DEFINES_HPP

#include <iostream>
#include <systemc>
#include <tlm>
#include <tlm_core/tlm_2/tlm_generic_payload/tlm_gp.h>
#include "tlm_utils/simple_initiator_socket.h"
#include "tlm_utils/simple_target_socket.h"
#include "nodes.hpp"

using namespace sc_core;
using namespace sc_dt;
using namespace tlm;
using namespace std;

#define BRAM_SIZE 0x2710
#define BRAM_ADDR_OFFSET 0x0000
#define BRAM_ADDR_MAX 0x270F
#define IP_ADDR_OFFSET 0x2710
#define IP_ADDR_MAX 0x0002 // 0: start koordinate, 1: end koordinate, 2: start signal



#endif
