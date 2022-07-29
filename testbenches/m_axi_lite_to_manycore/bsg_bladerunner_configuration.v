// auto-generated by bsg_ascii_to_rom.py from /mnt/users/ssd1/homes/gaozihou/tapeout_2021/playground_cudalite/bsg_manycore_replay/testbenches/m_axi_lite_to_manycore/bsg_bladerunner_configuration.rom; do not modify
module bsg_bladerunner_configuration #(parameter width_p=-1, addr_width_p=-1)
(input  [addr_width_p-1:0] addr_i
,output logic [width_p-1:0]      data_o
);
always_comb case(addr_i)
         0: data_o = width_p ' (32'b00000000000001100000000000000000); // 0x00060000
         1: data_o = width_p ' (32'b00000111001001010010000000100010); // 0x07252022
         2: data_o = width_p ' (32'b00000000000000000000000000011100); // 0x0000001C
         3: data_o = width_p ' (32'b00000000000000000000000000100000); // 0x00000020
         4: data_o = width_p ' (32'b00000000000000000000000000000001); // 0x00000001
         5: data_o = width_p ' (32'b00000000000000000000000000000001); // 0x00000001
         6: data_o = width_p ' (32'b00000000000000000000000000010000); // 0x00000010
         7: data_o = width_p ' (32'b00000000000000000000000000001000); // 0x00000008
         8: data_o = width_p ' (32'b00000000000000000000000000010000); // 0x00000010
         9: data_o = width_p ' (32'b00000000000000000000000000000000); // 0x00000000
        10: data_o = width_p ' (32'b00000000000000000000000000000111); // 0x00000007
        11: data_o = width_p ' (32'b00000000000000000000000000000111); // 0x00000007
        12: data_o = width_p ' (32'b00000000000000000000000000000000); // 0x00000000
        13: data_o = width_p ' (32'b01010111010101010011110001010011); // 0x57553C53
        14: data_o = width_p ' (32'b00111010000001011110000000000000); // 0x3A05E000
        15: data_o = width_p ' (32'b01011001011011100100010110100101); // 0x596E45A5
        16: data_o = width_p ' (32'b00000000000000000000000000000100); // 0x00000004
        17: data_o = width_p ' (32'b00000000000000000000000001000000); // 0x00000040
        18: data_o = width_p ' (32'b00000000000000000000000000001000); // 0x00000008
        19: data_o = width_p ' (32'b00000000000000000000000000001000); // 0x00000008
        20: data_o = width_p ' (32'b00000000000000000000000000100000); // 0x00000020
        21: data_o = width_p ' (32'b00000000000000000000000000100000); // 0x00000020
        22: data_o = width_p ' (32'b00000000000000000000000000100000); // 0x00000020
        23: data_o = width_p ' (32'b00000000000000000000000000000000); // 0x00000000
        24: data_o = width_p ' (32'b00000000000000000000000000000000); // 0x00000000
        25: data_o = width_p ' (32'b01010100010100110100010101010100); // 0x54534554
        26: data_o = width_p ' (32'b00000000000000000000000000000010); // 0x00000002
        27: data_o = width_p ' (32'b00000100000000000000000000000000); // 0x04000000
        28: data_o = width_p ' (32'b00000000000000000000000000000000); // 0x00000000
        29: data_o = width_p ' (32'b00000000000000000000000000000000); // 0x00000000
        30: data_o = width_p ' (32'b00000000000000000000000000000000); // 0x00000000
        31: data_o = width_p ' (32'b00000000000000000000000000000000); // 0x00000000
        32: data_o = width_p ' (32'b00000000000000000000000000011110); // 0x0000001E
        33: data_o = width_p ' (32'b00000000000000000000000000000000); // 0x00000000
        34: data_o = width_p ' (32'b00000000000000000000000000000000); // 0x00000000
        35: data_o = width_p ' (32'b00000000000000000000000000000000); // 0x00000000
        36: data_o = width_p ' (32'b00000000000000000000000000000000); // 0x00000000
        37: data_o = width_p ' (32'b00000000000000000000000000000000); // 0x00000000
   default: data_o = 'X;
endcase
endmodule