#include <cuda.h>
#include <cuda_runtime_api.h>
#include <device_launch_parameters.h>
#include <iostream>
#include "MedianFilter.h"
#include <time.h>
#define TILE_SIZE 4 

__global__ void medianFilterKernel(unsigned char *inputImageKernel, unsigned char *outputImagekernel, int imageWidth, int imageHeight)
{
	// Set row and colum for thread.
	int row = blockIdx.y * blockDim.y + threadIdx.y;
	int col = blockIdx.x * blockDim.x + threadIdx.x;
	unsigned char filterVector[9] = {0,0,0,0,0,0,0,0,0};   //Take fiter window
	if((row==0) || (col==0) || (row==imageHeight-1) || (col==imageWidth-1))
				outputImagekernel[row*imageWidth+col] = 0; //Deal with boundry conditions
	else {
		for (int x = 0; x < WINDOW_SIZE; x++) { 
			for (int y = 0; y < WINDOW_SIZE; y++){
				filterVector[x*WINDOW_SIZE+y] = inputImageKernel[(row+x-1)*imageWidth+(col+y-1)];   // setup the filterign window.
			}
		}
		for (int i = 0; i < 9; i++) {
			for (int j = i + 1; j < 9; j++) {
				if (filterVector[i] > filterVector[j]) { 
					//Swap the variables.
					char tmp = filterVector[i];
					filterVector[i] = filterVector[j];
					filterVector[j] = tmp;
				}
			}
		}
		outputImagekernel[row*imageWidth+col] = filterVector[4];   //Set the output variables.
	}
}


__global__ void medianFilterSharedKernel(unsigned char *inputImageKernel, unsigned char *outputImagekernel, int imageWidth, int imageHeight)
{
	//Set the row and col value for each thread.
	int row = blockIdx.y * blockDim.y + threadIdx.y;
	int col = blockIdx.x * blockDim.x + threadIdx.x;
	__shared__ unsigned char sharedmem[(TILE_SIZE+2)]  [(TILE_SIZE+2)];  //initialize shared memory
	//Take some values.
	bool is_x_left = (threadIdx.x == 0), is_x_right = (threadIdx.x == TILE_SIZE-1);
    bool is_y_top = (threadIdx.y == 0), is_y_bottom = (threadIdx.y == TILE_SIZE-1);

	//Initialize with zero
	if(is_x_left)
		sharedmem[threadIdx.x][threadIdx.y+1] = 0;
	else if(is_x_right)
		sharedmem[threadIdx.x + 2][threadIdx.y+1]=0;
	if (is_y_top){
		sharedmem[threadIdx.x+1][threadIdx.y] = 0;
		if(is_x_left)
			sharedmem[threadIdx.x][threadIdx.y] = 0;
		else if(is_x_right)
			sharedmem[threadIdx.x+2][threadIdx.y] = 0;
	}
	else if (is_y_bottom){
		sharedmem[threadIdx.x+1][threadIdx.y+2] = 0;
		if(is_x_right)
			sharedmem[threadIdx.x+2][threadIdx.y+2] = 0;
		else if(is_x_left)
			sharedmem[threadIdx.x][threadIdx.y+2] = 0;
	}

	//Setup pixel values
	sharedmem[threadIdx.x+1][threadIdx.y+1] = inputImageKernel[row*imageWidth+col];
	//Check for boundry conditions.
	if(is_x_left && (col>0))
		sharedmem[threadIdx.x][threadIdx.y+1] = inputImageKernel[row*imageWidth+(col-1)];
	else if(is_x_right && (col<imageWidth-1))
		sharedmem[threadIdx.x + 2][threadIdx.y+1]= inputImageKernel[row*imageWidth+(col+1)];
	if (is_y_top && (row>0)){
		sharedmem[threadIdx.x+1][threadIdx.y] = inputImageKernel[(row-1)*imageWidth+col];
		if(is_x_left)
			sharedmem[threadIdx.x][threadIdx.y] = inputImageKernel[(row-1)*imageWidth+(col-1)];
		else if(is_x_right )
			sharedmem[threadIdx.x+2][threadIdx.y] = inputImageKernel[(row-1)*imageWidth+(col+1)];
	}
	else if (is_y_bottom && (row<imageHeight-1)){
		sharedmem[threadIdx.x+1][threadIdx.y+2] = inputImageKernel[(row+1)*imageWidth + col];
		if(is_x_right)
			sharedmem[threadIdx.x+2][threadIdx.y+2] = inputImageKernel[(row+1)*imageWidth+(col+1)];
		else if(is_x_left)
			sharedmem[threadIdx.x][threadIdx.y+2] = inputImageKernel[(row+1)*imageWidth+(col-1)];
	}

	__syncthreads();   //Wait for all threads to be done.

	//Setup the filter.
	unsigned char filterVector[9] = {sharedmem[threadIdx.x][threadIdx.y], sharedmem[threadIdx.x+1][threadIdx.y], sharedmem[threadIdx.x+2][threadIdx.y],
                   sharedmem[threadIdx.x][threadIdx.y+1], sharedmem[threadIdx.x+1][threadIdx.y+1], sharedmem[threadIdx.x+2][threadIdx.y+1],
                   sharedmem[threadIdx.x] [threadIdx.y+2], sharedmem[threadIdx.x+1][threadIdx.y+2], sharedmem[threadIdx.x+2][threadIdx.y+2]};

	
	{
		for (int i = 0; i < 9; i++) {
        for (int j = i + 1; j < 9; j++) {
            if (filterVector[i] > filterVector[j]) { 
				//Swap Values.
                char tmp = filterVector[i];
                filterVector[i] = filterVector[j];
                filterVector[j] = tmp;
            }
        }
    }
	outputImagekernel[row*imageWidth+col] = filterVector[4];   //Set the output image values.
	}
}

bool MedianFilterGPU( Bitmap* image, Bitmap* outputImage, bool sharedMemoryUse ){
	//Cuda error and image values.
	cudaEvent_t start,stop;
	cudaEventCreate(&start);
	cudaEventCreate(&stop);
	cudaEventRecord(start);
	cudaError_t status;
	int width = image->Width();
	int height = image->Height();

	int size =  width * height * sizeof(char);
	//initialize images.
	unsigned char *deviceinputimage;
	cudaMalloc((void**) &deviceinputimage, size);
	status = cudaGetLastError();              
	if (status != cudaSuccess) {                     
		std::cout << "Kernel failed for cudaMalloc : " << cudaGetErrorString(status) << 
		std::endl;
		return false;
	}
	cudaMemcpy(deviceinputimage, image->image, size, cudaMemcpyHostToDevice);
	status = cudaGetLastError();              
	if (status != cudaSuccess) {                     
		std::cout << "Kernel failed for cudaMemcpy cudaMemcpyHostToDevice: " << cudaGetErrorString(status) << 
		std::endl;
		cudaFree(deviceinputimage);
		return false;
	}
	unsigned char *deviceOutputImage;
	cudaMalloc((void**) &deviceOutputImage, size);
	//take block and grids.
	dim3 dimBlock(TILE_SIZE, TILE_SIZE);
	dim3 dimGrid((int)ceil((float)image->Width() / (float)TILE_SIZE),
				(int)ceil((float)image->Height() / (float)TILE_SIZE));

	//Check for shared memories and call the kernel
	if (!sharedMemoryUse)
		medianFilterKernel<<<dimGrid, dimBlock>>>(deviceinputimage, deviceOutputImage, width, height);
	else
		medianFilterSharedKernel<<<dimGrid, dimBlock>>>(deviceinputimage, deviceOutputImage, width, height);
	
	

// save output image to host.
	cudaMemcpy(outputImage->image, deviceOutputImage, size, cudaMemcpyDeviceToHost);
	status = cudaGetLastError();              
	


if (status != cudaSuccess) {                     
		std::cout << "Kernel failed for cudaMemcpy cudaMemcpyDeviceToHost: " << cudaGetErrorString(status) << 
		std::endl;
		cudaFree(deviceinputimage);
		cudaFree(deviceOutputImage);
		return false;
	}
	//Free the memory
	cudaFree(deviceinputimage);
	cudaFree(deviceOutputImage);
	cudaEventRecord(stop);
	cudaEventSynchronize(stop);
	float time = 0;
	cudaEventElapsedTime(&time,start,stop);
	printf("time %f\n", time); 
	return true;
}
