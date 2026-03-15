#include <stdint.h>
#include <stdlib.h>
#include <bp_utils.h>

#ifndef NUM_ELEMENTS
#define NUM_ELEMENTS 8
#endif

#ifndef BSG_TILES_X
#define BSG_TILES_X 2
#endif

#ifndef BSG_TILES_Y
#define BSG_TILES_Y 2
#endif

#define BSG_TOTAL_TILES BSG_TILES_X * BSG_TILES_Y

int interrupt_taken;

__attribute__((interrupt))
void trap_handler(void) {
  // Disable interrupts
  uint64_t mstatus = 0;
   __asm__ __volatile__ ("csrw mstatus, %0" : : "r" (mstatus));
  interrupt_taken = 1;
}

void main() {
  /*********************
   Interrupt setup
  **********************/
  // Enable only software interrupts
  uint64_t mie = 1 << 3;
  // Enable M-mode interrupts
  uint64_t mstatus = 1 << 3;
  __asm__ __volatile__ ("csrw mie, %0": : "r" (mie));
  __asm__ __volatile__ ("csrw mstatus, %0" : : "r" (mstatus));

  // Set a alternate trap handler
  __asm__ __volatile__ ("csrw mtvec, %0": : "r" (&trap_handler));
  
  // Until interrupt is taken, this should be zero
  interrupt_taken = 0;

  /***********************
   Enable all domains
  ***********************/
  *hio_mask_addr = 0xFFF;



  char str1[] = "Cache flush invalidate starts\n";
  for(int c = 0; str1[c] != '\0'; c++) {
    *mc_stdout_addr = str1[c];
  }

  __asm__ __volatile__ ("fence rw, rw");

  hb_mc_packet_t req_pkt;
  req_pkt.request.data = 0x0;
  hb_mc_packet_t req_dst_array[32];
  for (int j = 0; j < 32; j++) {
    req_dst_array[j].request.x_dst = ((1 << HB_MC_POD_X_SUBCOORD_WIDTH) | (j % 16));
    req_dst_array[j].request.y_dst = (((j < 16 ? 0 : 2) << HB_MC_POD_Y_SUBCOORD_WIDTH) | (j < 16 ? 7 : 0));
    req_dst_array[j].request.x_src = (0 << HB_MC_POD_X_SUBCOORD_WIDTH) | 15;
    req_dst_array[j].request.y_src = (1 << HB_MC_POD_Y_SUBCOORD_WIDTH) | 1;
  }

for (int iter = 0; iter < 1; iter++) {
  req_pkt.request.op_v2 = 0x3;
  req_pkt.request.reg_id = 0x3;
  for (int i = 0; i < 64*4; i++) {
    req_pkt.request.addr = (1 << 31) | (1 << 29) | ((i << 3) << 2);
    #pragma GCC unroll 32
    for (int j = 0; j < 32; j++) {
      *mc_link_bp_req_fifo_addr = req_dst_array[j].words[0];
      *mc_link_bp_req_fifo_addr = req_pkt.words[1];
      *mc_link_bp_req_fifo_addr = req_pkt.words[2];
      *mc_link_bp_req_fifo_addr = req_pkt.words[3];
      __asm__ __volatile__ ("nop");
    }
  }
  req_pkt.request.op_v2 = 0x2;
  req_pkt.request.reg_id = 0xF;
  for (int i = 0; i < 64*4; i++) {
    req_pkt.request.addr = (1 << 31) | (1 << 29) | ((i << 3) << 2);
    #pragma GCC unroll 32
    for (int j = 0; j < 32; j++) {
      *mc_link_bp_req_fifo_addr = req_dst_array[j].words[0];
      *mc_link_bp_req_fifo_addr = req_pkt.words[1];
      *mc_link_bp_req_fifo_addr = req_pkt.words[2];
      *mc_link_bp_req_fifo_addr = req_pkt.words[3];
      __asm__ __volatile__ ("nop");
    }
  }
}

  __asm__ __volatile__ ("fence rw, rw");
  while ((*mc_link_bp_req_credits_addr) != 0);

  char str2[] = "Cache flush invalidate ends\n";
  for(int c = 0; str2[c] != '\0'; c++) {
    *mc_stdout_addr = str2[c];
  }



  // Terminate the simulation
  *mc_finish_addr = 0;

}