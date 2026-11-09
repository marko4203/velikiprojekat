#include "ip.hpp"

IP::IP(sc_core::sc_module_name name) : sc_core::sc_module(name), tsock_interconnect("tsock_interconnect"), isock_bram("isock_bram"), irq_out("irq_out") {
	tsock_interconnect.register_b_transport(this, &IP::b_transport);
    SC_THREAD(solve);
    sensitive << start_event;
    
    startX = 0;
    startY = 0;
    endX = 0;
    endY = 0;
    currentX = 0;
    currentY = 0;
    solved = false;
    irq_out.initialize(false);
}

void IP::b_transport(tlm::tlm_generic_payload &pl, sc_core::sc_time &offset){

    int addr = pl.get_address();
    unsigned char *buf = pl.get_data_ptr();
    int len = pl.get_data_length();
    tlm::tlm_command cmd = pl.get_command();

    switch(cmd){
        case tlm::TLM_WRITE_COMMAND:
            if(addr == IP_ADDR_OFFSET + START_COORD_ADRESS){
                sc_bv<14>* koordinate = reinterpret_cast<sc_bv<14>*>(buf);
                startX = koordinate->range(13, 7).to_uint();
                startY = koordinate->range(6, 0).to_uint();
                std::cout << "IP primio start adrresu: (" << startX << ", " << startY << ")" << std::endl;
            } else if(addr == IP_ADDR_OFFSET + END_COORD_ADRESS){
                sc_bv<14>* koordinate = reinterpret_cast<sc_bv<14>*>(buf);
                endX = koordinate->range(13, 7).to_uint();
                endY = koordinate->range(6, 0).to_uint();
                std::cout << "IP primio end adrresu: (" << endX << ", " << endY << ")" << std::endl;
            } else if(addr == IP_ADDR_OFFSET + START_SIGNAL_ADRESS){
                solved = false;
                currentX = startX;
                currentY = startY;
                start_event.notify();
                std::cout << "IP primio start signal." << std::endl;
            } else {    
                std::cout << "Error: IP::b_transport: Invalid write address " << addr << std::endl;
            }
            pl.set_response_status(tlm::TLM_OK_RESPONSE);
        break;

        default:
            std::cout << "Error: IP::b_transport: Unknown command" << std::endl;
            pl.set_response_status(tlm::TLM_COMMAND_ERROR_RESPONSE);
        break;
    }
}


void IP::solve(){
    while(true) {
        wait(start_event);
        
        std::cout << "IP started solving. Time: " << sc_core::sc_time_stamp() << std::endl;
        
        while(!solved){
            evaluateSurroundingNodes(currentX, currentY);
            moveNode();
            wait(sc_core::SC_ZERO_TIME); //yielduje scheduleru da bi bram mogao da prihvati transakciju
        }
        
        wait(70, sc_core::SC_US); // dleay na osnovu HLS alata

        std::cout << "IP finished solving. Time: " << sc_core::sc_time_stamp() << std::endl;
        irq_out.write(true);   // assert interrupt
        wait(sc_core::SC_ZERO_TIME); // let the signal propagate
        irq_out.write(false);  // deassert (pulse)
    }
}

sc_bv<24> IP::bramread(int x, int y){
    tlm::tlm_generic_payload pl;
    sc_core::sc_time delay = sc_core::SC_ZERO_TIME;
    sc_bv<24> bram_data;
    
    pl.set_command(tlm::TLM_READ_COMMAND);
    pl.set_address((BRAM_ADDR_OFFSET + x * GridSize + y));
    pl.set_data_ptr(reinterpret_cast<unsigned char*>(&bram_data));
    pl.set_data_length(1);
    pl.set_streaming_width(1);
    pl.set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);

    isock_bram->b_transport(pl, delay);
    
    return bram_data;
}

void IP::bramwrite(int x, int y, sc_bv<24> data){
    tlm::tlm_generic_payload pl;
    sc_core::sc_time delay = sc_core::SC_ZERO_TIME;
    
    pl.set_command(tlm::TLM_WRITE_COMMAND);
    pl.set_address((BRAM_ADDR_OFFSET + x * GridSize + y));
    pl.set_data_ptr(reinterpret_cast<unsigned char*>(&data));
    pl.set_data_length(1);
    pl.set_streaming_width(1);
    pl.set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);

    isock_bram->b_transport(pl, delay);
}

void IP::evaluateSurroundingNodes(sc_uint<7> x, sc_uint<7> y){
    sc_uint<7> i, j;
    sc_uint<9> distance;
    
    for (i = x - 1; i <= x + 1; i++) {
        for (j = y - 1; j <= y + 1; j++) {
            if (i >= 0 && i < GridSize && j >= 0 && j < GridSize && !(i == x && j == y)) {
                sc_bv<24> node_data = bramread(i, j);
                sc_uint<9> node_distance = node_data.range(23, 15).to_uint();
                sc_uint<7> node_parentX = node_data.range(14, 8).to_uint();
                sc_uint<7> node_parentY = node_data.range(7, 1).to_uint();
                sc_uint<1> node_visited = node_data.range(0, 0).to_uint();
                
                if(node_distance != 298 && node_distance != 299 && node_distance != 300) {
                    if(node_distance == 0) {
                        sc_uint<7> dx = (endX > i) ? (endX - i) : (i - endX);
                        sc_uint<7> dy = (endY > j) ? (endY - j) : (j - endY);
                        sc_uint<7> diff = (dx > dy) ? (dx - dy) : (dy - dx);
                        sc_uint<7> minVal = (dx < dy) ? dx : dy;
                        distance = 2 * diff + 3 * minVal;
                        
                        sc_bv<24> updated_data;
                        updated_data.range(23, 15) = distance;
                        updated_data.range(14, 8) = x;
                        updated_data.range(7, 1) = y;
                        updated_data.range(0, 0) = node_visited;
                        bramwrite(i, j, updated_data);
                    }
                } else if(node_distance == 300){
                    
                    sc_bv<24> updated_data;
                    updated_data.range(23, 15) = node_distance;
                    updated_data.range(14, 8) = x;
                    updated_data.range(7, 1) = y;
                    updated_data.range(0, 0) = node_visited;
                    bramwrite(i, j, updated_data);
                    solved = true;
                }    
            }
        }
    }        
}

void IP::moveNode(){
    sc_uint<9> minDistance = 320;
    sc_uint<7> nextX = 127, nextY = 127;
    
    for (sc_uint<7> x = 0; x < GridSize; x++) {
        for (sc_uint<7> y = 0; y < GridSize; y++) {
            sc_bv<24> node_data = bramread(x, y);
            sc_uint<9> dist = node_data.range(23, 15).to_uint();
            sc_uint<1> visited = node_data.range(0, 0).to_uint();
            
            if (!visited) {
                if (dist > 0 && dist < 298 && dist < minDistance) {
                    minDistance = dist;
                    nextX = x;
                    nextY = y;
                }
            }
        }
    }
    
    if (nextX != 127 && nextY != 127) {
        sc_bv<24> current_data = bramread(currentX, currentY);
        current_data.range(0, 0) = 1;
        bramwrite(currentX, currentY, current_data);
        
        currentX = nextX;
        currentY = nextY;
    } else {
        cout << "Greška:moveNode() Nije našao novi node.\n";
        solved = true;
        exit(0);
    }
}
