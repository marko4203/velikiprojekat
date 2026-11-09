#include "defines.hpp"
#include "cpu.hpp"
#include "interconnect.hpp"
#include "ip.hpp"
#include "bram.hpp"

int sc_main(int argc, char *argv[]) {
    // Create modules
    CPU cpu("cpu");
    Interconnect interconnect("interconnect");
    IP ip("ip");
    Bram bram("bram");

    // Interrupt signal: IP -> CPU
    sc_core::sc_signal<bool> irq("irq");
    ip.irq_out.bind(irq);
    cpu.irq_in.bind(irq);

    // Connect CPU to Interconnect
    cpu.isock_interconnect.bind(interconnect.tsock_cpu);

    // Connect Interconnect to BRAM and IP
    interconnect.isock_bram.bind(bram.tsock_a);
    interconnect.isock_ip.bind(ip.tsock_interconnect);

    // Connect IP to BRAM for reading
    ip.isock_bram.bind(bram.tsock_b);

    std::cout << "Starting simulation..." << std::endl;

    // Start simulation
    sc_core::sc_start();

    return 0;
}
