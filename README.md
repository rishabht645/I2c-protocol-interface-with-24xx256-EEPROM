# I2C Interface for 24XX256 EEPROM

A hardware implementation of the I2C protocol to interface with the Microchip 24XX256 Serial EEPROM, written in Verilog. The design includes a fully functional I2C master, EEPROM addressing logic using configurable control bytes (A2, A1, A0), read/write operations, page-write functionality, and a SDA line for serial data transmission.

## Table of Contents

- [Open Source Tools Used](#open-source-tools-used)
- [24XX256 EEPROM](#24xx256-eeprom)
- [Design Overview](#design-overview)
- [Waveform Generation](#waveform-generation)
- [RTL Schematic](#rtl-schematic)
- [FPGA Layout](#fpga-layout)
- [Running the Project](#running-the-project)

## Open Source Tools Used

- [Yosys](https://github.com/YosysHQ/yosys) : Verilog synthesis and netlist generation
- [netlistsvg](https://github.com/nturley/netlistsvg) : renders Yosys netlist as a visual SVG schematic
- [nextpnr](https://github.com/YosysHQ/nextpnr) : FPGA placement and routing with an interactive GUI
- [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build) : bundles all tools in a single suite
- [Icarus Verilog](https://github.com/steveicarus/iverilog) : Verilog simulation and compilation
- [GTKwave](https://github.com/gtkwave/gtkwave) : waveform viewing and analysis

## 24XX256 EEPROM

<!-- Add image of EEPROM here -->

<p align="center">

  <img width="155" height="103" alt="Screenshot 2026-05-24 at 7 03 33 AM" src="https://github.com/user-attachments/assets/72a96a8d-d9c0-46ff-93f4-5a9c001b485b" />
</p>

The Microchip 24XX256 is a 256-Kbit serial EEPROM that communicates using the I2C protocol and supports byte write, random read, sequential read, and page write operations.

The device uses a control byte format consisting of:

- 4-bit control code (4'b1010)
- 3-bit chip select field (A2 A1 A0)
- 1-bit Read/Write bit

Control byte structure is {4'b1010, A2, A1, A0}.


The A2, A1, and A0 bits allow up to eight EEPROM devices to exist on the same I2C bus while maintaining unique device addresses. 

The EEPROM additionally uses:

- 16-bit memory addressing
- 8-bit data transfer
- Acknowledgement after each transmitted byte
- Page write support for transmitting multiple data bytes in one operation

<p align="center">

  <img width="557" height="121" alt="Screenshot 2026-05-24 at 7 12 27 AM" src="https://github.com/user-attachments/assets/589f77df-5b84-4c1f-83ce-d76fbeafc23e" />


## Design Overview

The system clock runs at:

```text
System Clock = 40MHz
I2C Clock = 100KHz
```

The I2C clock timing is generated internally using clock division and pulse segmentation logic.

The top module "i2c_EEPROM" has a finite state machine with the following states:

- IDLE : waits for newd and initializes transaction parameters
- START : generates the I2C start condition
- WRITE_CTRL : transmits the control byte (1010 + A2A1A0 + R/W)
- ACK_1 : receives acknowledgement after control byte transmission
- WRITE_ADDR_H : transmits upper address byte
- ACK_3 : acknowledgement after upper address transmission
- WRITE_ADDR_L : transmits lower address byte
- ACK_4 : acknowledgement after lower address transmission
- WRITE_DATA : transmits a single data byte
- ACK_2 : acknowledgement after data write
- PAGE_WRITE : continuously transmits multiple data bytes without leaving write mode
- ACK_5 : acknowledgement after page transfer completion
- READ_DATA : receives data from EEPROM
- MASTER_ACK : master acknowledgement after read operation
- STOP : generates I2C stop condition and terminates communication

The page write operation uses:

```verilog
input page_wrt
input [5:0] no_of_bytes
```

which enables transmission of multiple bytes sequentially from the "page_data[]" memory array without restarting communication.

The design also includes status outputs:

- busy : indicates active transaction
- ack_err : indicates acknowledgement failure
- done : asserted after successful completion

## Waveform Generation

<p align="center">

  <img width="1708" height="848" alt="gtkwave_i2c2" src="https://github.com/user-attachments/assets/b4c8acca-5fc3-4efb-ba1b-a05488acaaac" />


</p>

<p align="center">

  <img width="1584" height="778" alt="gtkwave_i2c" src="https://github.com/user-attachments/assets/b18e5d28-02d4-49ab-9e90-48d4bdfd5f0a" />



</p>

The waveform was generated using [GTKWave](https://github.com/gtkwave/gtkwave).


## RTL Schematic

<p align="center">

  <img width="1195" height="688" alt="Screenshot 2026-05-24 at 5 58 26 AM" src="https://github.com/user-attachments/assets/e10a9b16-20d5-4744-80a3-f398075cd8cd" />


</p>

The RTL schematic was generated using [Yosys](https://github.com/YosysHQ/yosys) and [netlistsvg](https://github.com/nturley/netlistsvg).

The generated design contains:

- FSM state registers
- Clock divider logic
- Counters
- Data shift registers
- SDA tri-state control logic
- Address and data handling circuitry

## FPGA Layout

<p align="center">

  <img width="1024" height="753" alt="Screenshot 2026-05-24 at 5 57 09 AM" src="https://github.com/user-attachments/assets/b9a0917a-0d9a-4978-9802-956a47c9fdff" />


</p>

The design was placed and routed on a Lattice iCE40HX8K FPGA using [nextpnr](https://github.com/YosysHQ/nextpnr).

The layout visualizes:

- LUT placement
- Flip-flop placement
- Signal routing
- Resource utilization

## Running the Project

### Prerequisites

1. Install OSS CAD Suite (includes Yosys and nextpnr)

Download the appropriate archive from:

https://github.com/YosysHQ/oss-cad-suite-build/releases/latest

Set the environment:

```bash
source ~/Downloads/oss-cad-suite/environment
```

Remove macOS quarantine if necessary:

```bash
sudo xattr -rd com.apple.quarantine ~/Downloads/oss-cad-suite
```

2. Install Icarus Verilog

```bash
brew install icarus-verilog
```

3. Install GTKWave

```bash
brew install --cask gtkwave
```

4. Install Node.js

Download the LTS version from:

https://nodejs.org
```

Install netlistsvg:

```bash
sudo npm install -g netlistsvg
```

## Run Simulation

Using Icarus Verilog:

```bash
iverilog -o sim.out i2c_EEPROM.v
vvp sim.out
```

View waveforms:

```bash
gtkwave dump.vcd
```

## Generate RTL Schematic

```bash
source ~/Downloads/oss-cad-suite/environment

yosys -p "read_verilog i2c_EEPROM.v; hierarchy -top i2c_EEPROM; proc; write_json i2c_EEPROM.json"

netlistsvg i2c_EEPROM.json -o i2c_EEPROM.svg

open i2c_EEPROM.svg
```

## Run FPGA Placement and Routing

```bash
source ~/Downloads/oss-cad-suite/environment

yosys -p "synth_ice40 -top i2c_EEPROM -json i2c_EEPROM.json" i2c_EEPROM.v

nextpnr-ice40 --hx8k --json i2c_EEPROM.json --pcf-allow-unconstrained --gui
```

Then in the nextpnr GUI click:

```text
PACK → PLACE → ROUTE
```

<p align="center">

  <img width="444" height="131" alt="Screenshot 2026-05-23 at 8 49 47 AM" src="https://github.com/user-attachments/assets/d94b45f0-263a-4c35-bd8a-d4fbbad11f3d" />


</p>

## License

MIT License
