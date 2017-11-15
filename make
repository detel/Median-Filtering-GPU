all: cuda cpp output

cuda:
	nvcc -arch=sm_20 -c medianFilter.cu 
cpp:
	g++ -c main.cpp
	g++ -o test medianFilter.o main.o -L/usr/local/cuda/lib64 -lcudart
output:
	./test
