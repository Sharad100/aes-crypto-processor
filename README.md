# AES-128 Crypto Processor

A 5-stage pipelined MIPS-style processor extended with 128-bit vector registers and custom AES instructions, deployed on a Digilent Nexys A7-100T FPGA. Built by Sharad Parulekar and Daniel Tanku for Duke ECE 350.

## Custom AES instructions
| Opcode | Mnemonic | Operation |
|---|---|---|
| 10000 / 10100 | `ake` / `ark` | AddRoundKey: `vrd = vrs XOR vrt` |
| 10001 | `asb` | SubBytes |
| 10010 | `asr` | ShiftRows |
| 10011 | `amc` | MixColumns |
| 11001 | `asbi` | InvSubBytes |
| 11010 | `asri` | InvShiftRows |
| 11011 | `amci` | InvMixColumns |
| 11100 | `akx` | Key expansion into an 11 × 128-bit round-key bank |
| 11101 | `lrk` | Load round key by index |

## Microarchitecture
- 8 vector registers (`vr0`–`vr7`), 128 bits each, alongside the 32 scalar registers
- 128-bit X→D and M→D vector bypassing
- Stall/forward path between `akx` (key expansion) and `lrk` (round-key load)

## FPGA demo
Type up to 16 characters on a PS/2 keyboard; the plaintext appears on a VGA display. Press BTNC to encrypt, and the ciphertext is shown in green. CPU_RESETN clears everything.

## Layout
| Path | Contents |
|---|---|
| `proc/processor_aes.v` | Pipelined processor with AES instructions |
| `proc/Wrapper_aes.v`, `proc/Wrapper_aes_tb.v` | Simulation wrapper and testbench |
| `AES/` | SubBytes, ShiftRows, MixColumns, AddRoundKey, key expansion, and inverses |
| `VGA/`, `Ps2Interface.vhd` | Display and keyboard interfaces |
| `AES_VGA_Top.v`, `Nexys-A7-100T-Master.xdc` | FPGA top level and pin constraints |
