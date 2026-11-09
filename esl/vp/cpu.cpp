#include "cpu.hpp"
#include <fstream>
#include <string>

CPU::CPU(sc_core::sc_module_name name) : sc_core::sc_module(name), isock_interconnect("isock_interconnect"), irq_in("irq_in") {
    SC_THREAD(cpu_process);
    
    startX = 5;
    startY = 5;
    endX = GridSize - 1;
    endY = GridSize - 1;
    currentX = 0;
    currentY = 0;
    solved = false;
    
    for(int i = 0; i < GridSize; i++){
        for(int j = 0; j < GridSize; j++){
            visited[i][j] = false;
        }
    }
}

void CPU::cpu_process(){
    tlm::tlm_generic_payload pl;
    sc_core::sc_time delay = sc_core::SC_ZERO_TIME;


    currentX = startX;
    currentY = startY;

    for (sc_uint<7> x = 0; x < GridSize; x++) {
        for (sc_uint<7> y = 0; y < GridSize; y++) {
            grid[x][y] = Nodes(x, y, 0);
        }
    }

    grid[startX][startY].setDistance(299);
    grid[endX][endY].setDistance(300);
    
    // Read wall positions from user
    //readWalls(); 

    sc_uint<7> i;
    for(i = 0; i < GridSize-1; i++){
        grid[i][10].setDistance(298);
    }

    for(i = GridSize-1 ; i > 13; i--){
        grid[i][13].setDistance(298);
    }

    grid[14][12].setDistance(298);
    grid[18][11].setDistance(298);
    
    display(grid, GridSize);

    for (sc_uint<7> x = 0; x < GridSize; x++) {
        for (sc_uint<7> y = 0; y < GridSize; y++) {
            sc_bv<24> bram_data;
            bram_data.range(23, 15) = grid[x][y].getDistance();
            bram_data.range(14, 8) = grid[x][y].getParentX();
            bram_data.range(7, 1) = grid[x][y].getParentY();
            bram_data.range(0, 0) = visited[x][y];
            
            //OVDE DODAMO ISPIS LINIJE U FAJL U CISTOM BINARNOM RED PO RED
            std::ofstream outFile("bram_init.txt", std::ios::app);
            if (!outFile.is_open()) {
                std::cerr << "Error: could not open bram_init.txt for writing!" << std::endl;
            } else {
                std::string bitstring;
                bitstring.reserve(24);
                // MSB-first: bit 23 down to bit 0, matching VHDL's (23 downto 0) ordering
                for (int bit = 23; bit >= 0; --bit) {
                    bitstring += (bram_data[bit] ? '1' : '0');
                }
                outFile << bitstring << "\n";
                outFile.close();
            }

            pl.set_command(tlm::TLM_WRITE_COMMAND);
            pl.set_address((BRAM_ADDR_OFFSET + x * GridSize + y));
            pl.set_data_ptr(reinterpret_cast<unsigned char*>(&bram_data));
            pl.set_data_length(1);
            pl.set_streaming_width(1);
            pl.set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);

            isock_interconnect->b_transport(pl, delay);
        }
    }

    sc_bv<14> start_koordinate;
    sc_bv<14> end_koordinate;
    sc_bv<14> start_signal;
    
    start_koordinate.range(13, 7) = startX;
    start_koordinate.range(6, 0) = startY;
    
    pl.set_command(tlm::TLM_WRITE_COMMAND);
    pl.set_address((IP_ADDR_OFFSET + 0));
    pl.set_data_ptr(reinterpret_cast<unsigned char*>(&start_koordinate));
    pl.set_data_length(1);
    pl.set_streaming_width(1);
    pl.set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);

    isock_interconnect->b_transport(pl, delay);

    end_koordinate.range(13, 7) = endX;
    end_koordinate.range(6, 0) = endY;
    
    pl.set_command(tlm::TLM_WRITE_COMMAND);
    pl.set_address((IP_ADDR_OFFSET + 1));
    pl.set_data_ptr(reinterpret_cast<unsigned char*>(&end_koordinate));
    pl.set_data_length(1);
    pl.set_streaming_width(1);
    pl.set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);

    isock_interconnect->b_transport(pl, delay);

    start_signal = 1;
    
    pl.set_command(tlm::TLM_WRITE_COMMAND);
    pl.set_address((IP_ADDR_OFFSET + 2));
    pl.set_data_ptr(reinterpret_cast<unsigned char*>(&start_signal));
    pl.set_data_length(1);
    pl.set_streaming_width(1);
    pl.set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);

    isock_interconnect->b_transport(pl, delay);

    wait(irq_in.posedge_event());  // block until IP asserts the interrupt line
    
    for (sc_uint<7> x = 0; x < GridSize; x++) {
        for (sc_uint<7> y = 0; y < GridSize; y++) {
            sc_bv<24> bram_data;
            
            pl.set_command(tlm::TLM_READ_COMMAND);
            pl.set_address((BRAM_ADDR_OFFSET + x * GridSize + y));
            pl.set_data_ptr(reinterpret_cast<unsigned char*>(&bram_data));
            pl.set_data_length(1);
            pl.set_streaming_width(1);
            pl.set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);

            isock_interconnect->b_transport(pl, delay);
            
            grid[x][y].setDistance(bram_data.range(23, 15).to_uint());
            grid[x][y].setParent(bram_data.range(14, 8).to_uint(), bram_data.range(7, 1).to_uint());
            visited[x][y] = bram_data.range(0, 0).to_uint();
        }
    }
    
    finalPath();

    display(grid, GridSize);

    cout << "\nPathfinding complete." << endl;
    cout.flush(); 
    
    wait(); // da se ne bi vrtelo
}


//Definicije funkcija ------------------------------------------------------------------------------------------------

void CPU::readWalls(){
    cout << "Enter wall coordinates as x y pairs (0-indexed). Enter -1 -1 to finish:\n";
    int x, y;
    while (true) {
        cin >> x >> y;
        if (x == -1 && y == -1) {
            break;
        }

        if (x >= 0 && x < GridSize && y >= 0 && y < GridSize) {
            if ((x == (int)startX && y == (int)startY) || (x == (int)endX && y == (int)endY)) {
                cout << "Cannot place wall on start or end node. Try again.\n";
            } else {
                grid[x][y].setDistance(298);
            }
        } else {
            cout << "Coordinates out of bounds. Try again.\n";
        }


        system("clear");
        display(grid, GridSize);
        cout << "Enter wall coordinates as x y pairs (0-indexed). Enter -1 -1 to finish:\n";
    }
}

void CPU::finalPath(){
    sc_uint<7> i = grid[endX][endY].getParentX();
    sc_uint<7> j = grid[endX][endY].getParentY();
    sc_uint<7> parentX, parentY;
    
   // cout << "Final path:" << endl;

    while(grid[i][j].getDistance() != 299){
        //if(!(i == endX && j == endY)) {cout << "(" << i << ", " << j << ")" << endl;}
        grid[i][j].setDistance(301); 
        parentX = grid[i][j].getParentX();
        parentY = grid[i][j].getParentY();
        i = parentX;
        j = parentY;
    }
}

void CPU::display(Nodes grid[][GridSize], int GridSize){
    
    cout << "Grid (" << GridSize << "x" << GridSize << "):\n\n";

    for (sc_uint<7> x = 0; x < GridSize; x++) {
        for (sc_uint<7> y = 0; y < GridSize; y++) {
            sc_uint<9> distance = grid[x][y].getDistance();
            string s;

            if (distance == 299) {
                s = "  S  ";
            } else if (distance == 300) {
                s = "  E  ";
            } else if (distance == 298) {
                s = "█████";
            } else if (distance == 301) {
                s = "--X--";
            } else {
                sc_uint<9> dist = grid[x][y].getDistance();
                if (dist == 0) {
                    s = "[   ]";
                } else {
                    s = " " + to_string((int)dist);
                }
            }

            int padding = 5 - s.size();
            cout << s;

            if (padding > 0) {
                for (int k = 0; k < padding; k++) cout << " ";
            }
        }
        cout << "\n";
    }
}
