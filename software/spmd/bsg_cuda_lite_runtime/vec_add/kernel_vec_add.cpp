//This kernel adds 2 vectors 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#include "bsg_tile_group_barrier.hpp"

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;

extern "C" __attribute__ ((noinline))
int kernel_vec_add_single_tile(int *A, int *B, int *C, unsigned WIDTH);

extern "C" __attribute__ ((noinline))
int kernel_vec_add(int *A, int *B, int *C, int N, int block_size_x) {

	kernel_vec_add_single_tile(A, B, C, block_size_x);

	barrier.sync();

	return 0;
}