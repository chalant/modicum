from numba import cuda
import numpy
import math

# CUDA kernel
@cuda.jit
def my_kernel(io_array):
    # Thread id in a 1D block
    tx = cuda.threadIdx.x
    # Block id in a 1D grid
    ty = cuda.blockIdx.x
    # Block width, i.e. number of threads per block
    bw = cuda.blockDim.x
    # Compute flattened index inside the array
    pos = tx + ty * bw
    if pos < io_array.size:  # Check array boundaries
        io_array[pos] *= 2 # do the computation

if __name__ == '__main__':
    for i in range(0,1000):
        # Create the data array - usually initialized some other way
        data = numpy.ones(256 * 10000)

        # Set the number of threads in a block
        threadsperblock = 32

        # Calculate the number of thread blocks in the grid
        blockspergrid = (data.size + (threadsperblock - 1)) // threadsperblock

        # Now start the kernel
        my_kernel[blockspergrid, threadsperblock](data)

        # Print the result
        # print(data)