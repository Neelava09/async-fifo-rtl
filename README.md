## Author

**Neelava Mukherjee**  
* **M.Tech:** Electrical Engineering (Integrated Circuits and Systems), Indian Institute of Technology Bombay
* **B.E.:** Electrical Engineering, Jadavpur University

## Introduction

This repository contains a parameterizable **Dual-Clock Asynchronous FIFO** implemented in Verilog. 

When transferring data between two independent clock domains, differences in clock speed can cause data loss or metastability. This project provides a reliable FIFO buffer to safely bridge these asynchronous clock domains.

**Key Highlights:**
* **Clock Domain Crossing (CDC) Safety:** Uses 2-stage Gray code pointer synchronizers to prevent metastability across domains.
* **Status Flags & Error Handling:** Accurately tracks `full`, `empty`, `almost_full`, `almost_empty`, `overflow`, and `underflow` conditions.
* **Parameterized RTL:** Easily configure data width and buffer depth (e.g., $64 \times 32$ or $256 \times 32$).
* **Verified & Synthesized:** Validated with a self-checking testbench and synthesized on AMD Xilinx Vivado with zero timing violations.


## Detailed Design & Architecture

The architecture of this Asynchronous FIFO is carefully structured to safely transfer data between independent, unsynchronized clock domains—specifically bridging a 100 MHz write domain and an 80 MHz read domain. Below is a comprehensive breakdown of the core mechanics, signals, and submodules that drive the design.

### Read and Write Operations
In this dual-clock system, data injection and extraction are completely decoupled. 
* **Writing:** The write operation is governed by the 100 MHz write clock (`wclk`). A write pointer dynamically tracks the next available memory address. When the write increment signal (`winc`) is asserted and the FIFO is not full, data is written into the buffer, and the pointer advances.
* **Reading:** The read operation is governed by the 80 MHz read clock (`rclk`). A read pointer tracks the oldest unread data. Upon reset, both pointers initialize at zero. As data populates the FIFO, the read pointer immediately exposes the first valid word to the read data bus. Asserting the read increment signal (`rinc`) advances the pointer to fetch subsequent words.

### The Extra-Bit (N+1) Tracking for Full/Empty Conditions
For a FIFO depth of 64 words, a standard address requires 6 bits ($2^6 = 64$). However, the internal pointers are sized at 7 bits (`[6:0]`). This extra Most Significant Bit (MSB) is the "wrap bit," which acts as a lap counter to distinguish between a completely full and a completely empty buffer.

* **Empty Condition:** The FIFO is completely empty when the read pointer and write pointer are identically matched (including the extra wrap bit). This occurs upon initial reset or when the slower read domain successfully consumes all data and "catches up" to the write domain.
* **Full Condition:** The FIFO is saturated when the write pointer loops entirely around the memory array and catches up to the read pointer from behind. In this state, the lower 6 bits (the physical address) of both pointers will match, but their 7th bits (the wrap bits) will be inverted, indicating the write domain has completed exactly one more lap than the read domain.

### Gray Code Synchronization
Directly synchronizing a multi-bit binary counter across asynchronous clock boundaries is dangerous because different bits travel at slightly different speeds (clock skew), which can cause the receiving domain to sample intermediate, garbage values. 

To solve this, binary pointers are converted into **Gray code** before crossing domains. In a Gray code sequence, only a single bit transitions during any given increment. If the receiving clock edge samples the signal exactly as it changes, it will either read the old valid pointer or the new valid pointer—preventing metastability from corrupting the address.

---

### Signal Definitions
Below are the critical signals mapped in the top-level wrapper:

**Write Domain (100 MHz)**
* `wclk` / `wrst_n`: Write domain clock and active-low asynchronous reset.
* `winc`: Write increment command. 
* `wdata`: 32-bit input data bus.
* `wfull`: Asserts high when the FIFO cannot accept more data.
* `walmost_full`: Early warning flag asserted when the FIFO is within 4 words of capacity.
* `woverflow`: Error flag that asserts if a write is illegally attempted while the FIFO is full.

**Read Domain (80 MHz)**
* `rclk` / `rrst_n`: Read domain clock and active-low asynchronous reset.
* `rinc`: Read increment command.
* `rdata`: 32-bit output data bus.
* `rempty`: Asserts high when no valid data is available to read.
* `ralmost_empty`: Early warning flag asserted when the FIFO is within 4 words of being empty.
* `runderflow`: Error flag that asserts if a read is illegally attempted while the FIFO is empty.

**Internal Cross-Domain Routing**
* `wptr` / `rptr`: Gray-coded pointers originating from their respective domains.
* `rq2_wptr`: The write pointer safely synchronized into the read domain (used for empty logic).
* `wq2_rptr`: The read pointer safely synchronized into the write domain (used for full logic).

---

### Module Breakdown
The system is partitioned into five specialized modules to isolate the memory, domain logic, and synchronization stages. This modularity ensures clean synthesis mapping and static timing analysis.

#### 1. Top Core (`ip_afifo_top_core.v`)
This is the top-level integration wrapper. It instantiates the memory buffer, the read/write controllers, and the synchronizers. It routes the synchronized Gray pointers across the boundary and ensures the parameterized constraints (32-bit width, 64-word depth) are passed down to all submodules.

#### 2. Distributed RAM Memory (`ip_afifo_dpram.v`)
The physical storage engine of the FIFO. It acts as a Dual-Port RAM allowing simultaneous access from the 100 MHz and 80 MHz domains. By utilizing the `(* ram_style = "distributed" *)` attribute, the synthesis tool optimally maps this $64 \times 32$ matrix directly into FPGA LUTs rather than consuming larger Block RAM primitives.

#### 3. 2-Stage Synchronizer (`ip_afifo_sync2.v`)
This module is instantiated twice—once for the write-to-read path and once for the read-to-write path. It cascades two D-flip-flops to combat metastability. The first flip-flop captures the incoming asynchronous Gray code, and the second flip-flop stabilizes it before feeding it into the destination logic. 

#### 4. Write Controller (`ip_afifo_wr_ctrl.v`)
Driven entirely by `wclk`, this module manages the write memory address. It translates the internal binary count into Gray code for the synchronizers. Furthermore, it continuously compares the active write pointer against the synchronized read pointer (`wq2_rptr`) to calculate and drive the `wfull`, `walmost_full`, and `woverflow` boundary flags.

#### 5. Read Controller (`ip_afifo_rd_ctrl.v`)
Driven entirely by `rclk`, this module manages the read memory address. Similar to the write controller, it tracks the binary read location and converts it to Gray code. It compares its active read pointer against the synchronized write pointer (`rq2_wptr`) to evaluate data availability, actively driving the `rempty`, `ralmost_empty`, and `runderflow` boundary flags.

## Testbench Implementation & Verification Strategy

Verifying an Asynchronous FIFO requires more than just checking if data goes in and comes out. The testbench must prove that the design can handle independent clock domains, prevent data corruption during simultaneous read/write operations, and accurately report its boundary states. 

The provided Verilog testbench (`tb_ip_afifo_top_core.v`) utilizes a robust, self-checking architecture to validate the FIFO across three distinct operational phases, completely automating the pass/fail evaluation without requiring manual waveform inspection.

### 1. Clock Generation & Emulation
The testbench accurately models the dual-clock environment by generating two completely independent, non-aligned clocks:
* **Write Clock (`wclk`):** Toggles to emulate the 100 MHz source domain.
* **Read Clock (`rclk`):** Toggles to emulate the slower 80 MHz destination domain.
Because these clocks are not mathematically synchronized in phase, the testbench inherently subjects the RTL to real-world Clock Domain Crossing (CDC) stress on every clock edge.

### 2. The `assert_eq` Self-Checking Mechanism
To eliminate human error during verification, the testbench utilizes a custom `assert_eq` task. This task dynamically compares the expected behavioral outputs against the actual RTL outputs at specific simulation timestamps. If a mismatch occurs, it logs a formatted error message to the console and increments a global `error_count`. At the end of the simulation, the system automatically signs off with a `[ PASS ]` or reports the exact number of failures.

### 3. Verification Phases

#### Phase 1: Reset & Default State Checks
Before any data is introduced, the testbench asserts the asynchronous active-low resets (`wrst_n` and `rrst_n`). It then validates the baseline combinational logic:
* Ensures `rempty` and `ralmost_empty` are strictly asserted high (`1`).
* Ensures `wfull` and `walmost_full` are deasserted (`0`).
* Confirms error flags (`woverflow`, `runderflow`) are cleared.

#### Phase 2: Saturation & Error Injection (Boundary Testing)
This phase tests the extreme edges of the 64-word buffer limits.
* **Write Saturation:** The testbench drives exactly 64 sequential writes into the FIFO. It then pauses and asserts that `wfull` and `walmost_full` transition high.
* **Overflow Trapping:** While the FIFO is confirmed full, the testbench intentionally forces an illegal write transaction (injecting `32'hABCDEF99`). It then verifies that the FIFO protects its memory and correctly triggers the `woverflow` error flag.
* **Read Draining:** The testbench switches to the read domain and extracts all 64 words. It uses the `assert_eq` task on every single clock cycle to ensure the sequential data matches exactly what was written. 
* **Underflow Trapping:** Once `rempty` is asserted, the testbench forces an illegal read, successfully verifying that the `runderflow` flag catches the violation.

#### Phase 3: Asynchronous Concurrent Traffic (Stress Testing)
Testing isolated writes and reads is insufficient for an AFIFO. The true test of the Gray code synchronizers occurs when pointers are moving simultaneously.
* **The `fork ... join` Block:** The testbench uses Verilog's `fork...join` construct to spin up two parallel execution threads. 
* **Simultaneous Operations:** One thread continuously injects data into the write domain while the other thread continuously extracts data from the read domain. 
* **Dynamic Backpressure:** Both threads are programmed with dynamic backpressure awareness. The write thread checks `if (!wfull)` before writing, and the read thread checks `if (!rempty)` before reading.  
* **Data Integrity:** Even as the read and write pointers endlessly chase each other across the asynchronous clock boundary, the read thread maintains a tracking index to guarantee that every single word pulled from the concurrent stream matches the exact sequence injected by the write thread.


## Verification & Simulation Results

The asynchronous FIFO design was rigorously verified using a self-checking testbench. Based on the behavioral and post-synthesis timing simulations, the following key hardware results were validated:

* **Data Integrity & Retrieval:** The FIFO correctly stored and retrieved data across the 100 MHz and 80 MHz clock domains without any data loss or corruption. Throughout both sequential and concurrent stress tests, the internal `error_count` remained at exactly 0.
* **Accurate Boundary Detection:** The status flags behaved exactly as designed. The simulations confirm that the `walmost_full` flag precisely asserts at word 60 (based on the depth of 64 and an offset of 4). Furthermore, the `wfull` flag correctly engages at absolute capacity, effectively blocking additional writes and preventing memory overflow. 
* **Post-Synthesis Consistency:** The Post-Synthesis Timing Simulation successfully mirrored the behavioral logic, proving that the translated gate-level netlist functions perfectly under real hardware delays without synchronization glitches.

---

## Synthesis & Timing Closure

The RTL was synthesized using AMD Xilinx Vivado. The design achieved complete timing closure with a highly efficient logic footprint. By utilizing the `distributed` RAM attribute, the synthesis tool optimally mapped the storage array to LUTRAM rather than consuming larger Block RAM primitives.

**Resource Utilization:**
* **LUT:** 100 (0.19%)
* **LUTRAM:** 44 (0.25%)
* **Registers (FF):** 92 (0.09%)
* **IO:** 76 (60.80%)

**Timing Summary:**
* **Worst Negative Slack (WNS):** +5.593 ns (Setup Clean)
* **Worst Hold Slack (WHS):** +0.111 ns (Hold Clean)
* **Worst Pulse Width Slack (WPWS):** +3.750 ns
* **Failing Endpoints:** 0 out of 418 endpoints.
* *All user-specified timing constraints across the asynchronous domains were successfully met.*

---

## Conclusion

The design and implementation of the Dual-Clock Asynchronous FIFO were highly successful, demonstrating reliable cross-domain data transfer and robust clock domain crossing (CDC) safety. The use of Gray code pointers and 2-stage synchronizers ensured mathematically sound synchronization, while the internal logic accurately protected the memory boundaries against overflow and underflow conditions. 

While timing simulations confirm the functional and setup/hold aspects of the design, it is important to acknowledge that metastability is ultimately a physical hardware phenomenon. The next phase of this project would involve deploying the netlist onto a physical FPGA development board to observe real-world silicon behavior under extended, heavy-load concurrent traffic. Overall, this IP block is lightweight, highly efficient, and perfectly suited for SoC applications requiring safe buffering between independent clock domains.
