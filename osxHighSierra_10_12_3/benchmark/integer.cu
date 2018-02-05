
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

__global__ void bench_Overhead(int *A, unsigned int d_tvalue){
    __shared__ s_tvalue;
    clock_t start_time = clock();
    s_tvalue = A[0];
    clock_t end_time = clock();
    s_tvalue = end_time - start_time;
    d_tvalue = s_tvalue;
}

__global__ void bench_LineSize(unsigned int *CUDA_A, unsigned int device_tvalue[], unsigned int device_index[]) {
	//Placing variables in shared memory makes them
	//not interfere with the global memory cache and, hence, the experiment
	__shared__ unsigned int s_tvalue[iterations];
	__shared__ unsigned int s_index[iterations];
	//__shared__ unsigned int s_tvalue[iterations];
	//__shared__ unsigned int s_index[iterations];
	//__shared__ int j;
    int j;
	j = 0;
	for (int it = 0; it < iterations; it++) {
		clock_t start_time = clock();
		j = CUDA_A[j];
		//Store the element index
		//Also generates memory dependence on previous
		//instruction, so that clock() happens after the
		//array access above
		s_index[it] = j;
		clock_t end_time = clock();
		//store the access latency
		s_tvalue[it] = end_time - start_time;
	}
	//All threads in this block have to reach this point
	//before continuing execution.
	__syncthreads();

	//Transfer results from shared memory to global memory
	//Later we will memcpy() the device global memory to host
	for (int i = 0; i < iterations; i++) {
		device_index[i] = s_index[i];
		device_tvalue[i] = s_tvalue[i];
	}

}

__global__ void bench_Integer(unsigned int*A, unsigned int d_tvalue){
    /*
    *   This function finds the cache line size b.
    */
    __shared__ unsigned int s_tvalue;
    __shared__ int          dummy;
    __shared__ int          result;
    __syncthreads();//If more than 1 thread, all start at same time.
    dummy = A[0];//loader
    clock_t start_time = clock();
    result = A[1]+A[2];//int1+int2 , each a cache hit.
    dummy = result;
    clock_t end_time = clock();
    d_tvalue = end_time - start_time; 

}

int main()
{
	printf("Will go through [%d] iterations with array of size N = [%d].\n", iterations, N);
	FILE * file;
	unsigned int *A = new unsigned int[3]; 
    unsigned int *h_tvalue = 0;
	//Initialize array
    A[0] = 0x00;
    A[1] = 0x01;
    A[2] = 0x02;
   
    unsigned int *CUDA_A = new unsigned int[3];
    unsigned int *d_tvalue = 0;

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

    bench_Overhead<<<1,1>>>(CUDA_A, d_tvalue)

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

    printf("overhead = %d\n",h_tvalue);

    // cudaDeviceReset must be called before exiting in order for profiling and
    // tracing tools such as Nsight and Visual Profiler to show complete traces.
    cudaStatus = cudaDeviceReset();
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaDeviceReset failed!");
        return 1;
    }
    return 0;
}


void newBenchmark(){


}
