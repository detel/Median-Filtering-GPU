# High Performance Median Filtering Algorithm Based on NVIDIA GPU Computing

## Abstract

Median filtering technique is often used to remove additive white, salt and pepper noise from a signal or a source image. This filtering method is essential for the processing of digital data representing analog signals in real time.

The median filter considers each pixel in the image in turn and looks at its nearby neighbors to determine whether or not it is representative of its surroundings. It replaces the pixel value with the median of neighboring pixel values. The median is calculated by first sorting all the pixel values from the surrounding neighborhood into numerical order and then replacing the pixel being considered with the middle pixel value.

## Introduction

The salt and pepper noise or impulsive noise is visible in images and is similar to many black and white spots and is generated during image acquisition. It is characterized by positive or negative peaks that saturate the pixels of the image.

The Median filter is a nonlinear digital filtering technique often used to remove salt and pepper noise. 

Computing the neighborhood requires more computation time in a post processing step. More recently, the opened perspectives have been offered by modern GPUs that allow us to develop CUDA-based filters, which will be shown as the fastest median filter implementation known.


## Result

<p align="center">
  <img src="https://github.com/detel/Median-Filtering-GPU/blob/master/InputOutput.jpeg" />
</p>
