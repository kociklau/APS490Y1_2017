#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <iostream>
#include <stdio.h>
#include <string.h>
#include <ctime>
#include <math.h>       /* pow, ceil */
#include <algorithm>
#include <device_functions.h>
#include <cuda_runtime_api.h>
#include <cuda.h>
//Windows has <direct.h>, POSIX systems have <unistd.h>
#include <unistd.h> /*To get the path to this script's directory*/
#include <sys/syslimits.h>

using namespace std;

__global__ void bench_Integer(unsigned int*A, unsigned int d_tvalue[]){
    __shared__ unsigned int s_tvalue;
    __shared__ int          result;
    result = A[0];//loader -- cold cache miss, load cache line from mem
    clock_t start_time = clock();
    result = A[1]*A[2];//cache hit.
    result = result; //Same as bench_Overhead
    clock_t end_time = clock();
    s_tvalue = end_time - start_time; 
    d_tvalue[0] = s_tvalue;
}

int main()
{
	unsigned int *A = new unsigned int[3]; 
    unsigned int *h_tvalue = new unsigned int[1];
    const int iterations = 1000;
    unsigned int *avg_tval = new unsigned int[iterations];
	//Initialize array
    A[0] = 0x00;
    A[1] = 0x01;
    A[2] = 0x03;
   
    unsigned int *CUDA_A = new unsigned int[3];
    unsigned int *d_tvalue = new unsigned int[1];

    cudaError_t cudaStatus;
	// Choose which GPU to run on, change this on a multi-GPU system.
	cudaStatus = cudaSetDevice(0);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
		return -1;
	}

	//Places array into cache
	cudaStatus = cudaMalloc((void**)&CUDA_A, 3 * sizeof(unsigned int));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		cudaDeviceReset(); //Clear all allocations and exit
	}

	//Places array into cache
	cudaStatus = cudaMalloc((void**)&d_tvalue, sizeof(unsigned int));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed for the tvalues array!");
		cudaDeviceReset(); //Clear all allocations and exit
		return -1;
	}

    cudaStatus = cudaMemcpy(CUDA_A, A, sizeof(int), cudaMemcpyHostToDevice);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed for the array!");
		cudaDeviceReset();
		return -1;
	}

    bench_Integer<<<1,1>>>(CUDA_A, d_tvalue);

	// Check for any errors launching the kernel
	cudaStatus = cudaGetLastError();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "kernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
		return -1;
	}

	// cudadevicesynchronize waits for the kernel to finish, and returns
	// any errors encountered during the launch.
	cudaStatus = cudaDeviceSynchronize();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudadevicesynchronize returned error code %d after launching kernel!\n", cudaStatus);
		return -1;
	}

    // Copy output vector from GPU buffer to host memory.
	cudaStatus = cudaMemcpy(h_tvalue, d_tvalue, sizeof(unsigned int), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed! Could not retrieve tvalue from device.\n");
		return -1;
	}

    printf("Integer addition tvalue = %d\n",h_tvalue[0]);

    // cudaDeviceReset must be called before exiting in order for profiling and
    // tracing tools such as Nsight and Visual Profiler to show complete traces.
    cudaStatus = cudaDeviceReset();
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaDeviceReset failed!");
        return 1;
    }
    return 0;
}


