# Regfile
## Name
ECE 350 Sp'26 32-port Register File
Daniel Tanku (dt216)

## Description of Design
For the regfile, I am starting as close as possible to my ECE 250 regfile in Logisim.

### Hierarchical Description
A hierarchical description of the regfile is: 
|       File            |       Purpose                 |
|    -----------------------|-------------------------------|
|`dffe_ref.v`           |DFF provided by staff.         |
|`reg_32b.v`            |One register made of 32 DFFs.  |
|`decoder32.v`          |5-to-32 decoder with enable.   |
|`regfile.v`            |31 `genvar`'d registers + constant `r0`. Three decoders for read/write selection. |

## Toolchain
This regfile was designed with the following technology:

|        Use         |              Tools           |
|--------------------|------------------------------|
| Language           | Verilog, SystemVerilog (2005)|
| Editor             | Vim                          |
| Simulation Testing | Icarus Verilog               |
| Shell              | Powershell, CMD              |

SystemVerilog was used for `$random` in testbenches.

## Bugs
This regfile contains no bugs that I am aware of. This is due to its simple architecture.  

The only bug I ran into was my own error: I assigned tri-states as `1'bZ` instead of `32'bZ`. Using GTKWave I identified a bad assignment and quickly corrected the bug.
