# ETHERNET-PHYSICAL-LAYER-MODULE
*A Verilog implementation of an IEEE 802.3-compliant 64b/66b Ethernet PHY TX/RX datapath. Features include hierarchical modularity, cycle-accurate timing, robust frame integrity checking, and a self-synchronizing scrambler/descrambler.

<img width="1751" height="762" alt="SCRAMBLER" src="https://github.com/user-attachments/assets/cd2554f3-aeea-43d6-bd24-62b370c0d077" />

*The Linear Feedback Shift Registers Used in the scrambler and descrambler modules are multiplicative LFSR, hence for descramble to properly work there is no need to have same seed values for scrambler LFSR and Descrambler LFSR.

*The Encoder is operating at slower frequency as compared to scrambler which is 64 times faster than clock frequency of Encoder which ensures that encoder is not waiting for the scrambler to finish it's received encoded data packet, and there is no actual data loss.

*Same is the case of decoder and descrambler.

*The individual and intermodule connections are in the below image
