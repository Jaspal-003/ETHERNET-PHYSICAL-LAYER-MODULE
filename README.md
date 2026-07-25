# ETHERNET-PHYSICAL-LAYER-MODULE
* A Verilog implementation of an IEEE 802.3-compliant 64b/66b Ethernet PHY TX/RX datapath. Features include hierarchical modularity, cycle-accurate timing, robust frame integrity checking, and a self-synchronizing scrambler/descrambler.

<img width="1751" height="762" alt="SCRAMBLER" src="https://github.com/user-attachments/assets/cd2554f3-aeea-43d6-bd24-62b370c0d077" />

* The Linear Feedback Shift Registers Used in the scrambler and descrambler modules are multiplicative LFSR, hence for descramble to properly work there is no need to have same seed values for scrambler LFSR and Descrambler LFSR.

* The Encoder is operating at slower frequency as compared to scrambler which is 64 times faster than clock frequency of Encoder which ensures that encoder is not waiting for the scrambler to finish it's received encoded data packet, and there is no actual data loss.

* Same is the case of decoder and descrambler.

* The individual and intermodule connections are in the below image
# SCRAMBLER MODULE
<img width="778" height="438" alt="SCRAMBLER_MODULE" src="https://github.com/user-attachments/assets/b318404b-2269-4181-9f89-79744cf44269" />

# DESCRAMBLER MODULE
* The initial 58 bits of DESCRAMB_OUT will not be or actual data as the LFSR does not consist of valid scramb_keys which is to be decoded hence it is GARBAGE_DATA.
* After first 58 bits of DESCRAMB_OUT the actual data bits are generated and after 64 clock cycles all the actual data is matching the encoded data hence the VALID_DATA Flag is set, only then the Data packet is given to the DECODER.

<img width="778" height="438" alt="DESCRAMBLER_MODULE" src="https://github.com/user-attachments/assets/3c5def81-39b6-468a-8eab-f4b1b44eca3a" />

# Testbench Results

Starting Cycle-by-Cycle Monitor...
Time = 0 | VALID_DATA = 0 | DECODE_DATA_IN = xxxxxxxxxxxxxxxxx
Time = 655000 | VALID_DATA = 0 | DECODE_DATA_IN = 110f3252fd0d9e7fa
Time = 1295000 | VALID_DATA = 1 | DECODE_DATA_IN = 112153524c0895e81

TRIGGER: VALID_DATA went HIGH at Time 1305000

Transmitted Payload      : 112153524c0895e81
Current DECODE_DATA_IN   : 112153524c0895e81
Previous DECODE_DATA_IN  : 110f3252fd0d9e7fa
RESULT: Match on CURRENT cycle.

# Working of Encoder Scrambler Decoder and Descrambler
* For this design to work properly the clock frequency of Scrambler and Descrambler should be 64 times faster than that of clock frequency of Encoder and decoder
* Because the encoder is continously encoding the Data received by MAC Layer, and giving parallel bus output, whereas the scrambler is serially scrambling each encoded bit.
* As you can see in the below diagram of entire top module

Time = 1305000 | VALID_DATA = 0 | DECODE_DATA_IN = 112153524c0895e81
testbench.sv:106: $finish called at 1520000 (1ps)
