#ifndef BITMAP_H
#define BITMAP_H

#include <iostream>
#include <fstream>
#include <stdint.h>

class Bitmap {
public:
	Bitmap() : image( NULL ) {}
	
	Bitmap( int w, int h ) {
		image = new char[ w * h ];
		header.filesz = sizeof( bmpHeader ) + sizeof( bmpInfo ) + ( w * h ) + 2 + 1024;
		header.bmp_offset = sizeof( bmpHeader ) + sizeof( bmpInfo ) + 2 + 1024;
		info.header_sz = sizeof( bmpInfo );
		info.width = w;
		info.height = h;
		info.nplanes = 1;
		info.bitspp = 8;
		info.compress_type = 0;
		info.bmp_bytesz = w * h;
		info.hres = 2835;
		info.vres = 2835;
		info.ncolors = 0;
		info.nimpcolors = 0;
	}
	
	bool Save( const char* filename ) {
		if( image == NULL ) {
			std::cerr << "Image unitialized" << std::endl;
			return false;
		}
		
		std::ofstream file( filename, std::ios::out | std::ios::binary );
		
		file.write( "BM", 2 );
		file.write( (char*)( &header ), sizeof( bmpHeader ) );
		file.write( (char*)( &info ), sizeof( bmpInfo ) );
		
		char rgba[ 4 ];
		for( int i = 0; i < 256; ++i ) {
			rgba[ 0 ] = i;
			rgba[ 1 ] = i;
			rgba[ 2 ] = i;
			rgba[ 3 ] = 0;
			
			file.write( rgba, 4 );
		}
		
		file.write( image, Width() * Height() );
		
		file.close();
		
		return true;
	}
	
	bool Load(const char* filename) {
		if( image != NULL ) {
			delete[] image;
		}
		
		std::ifstream file( filename, std::ios::in | std::ios::binary );

		if( !file.is_open() ) {
			std::cerr << "Cannot open " << filename << std::endl;
			return false;
		}
	
		char BM[ 2 ];
		file.read( (char*)( BM ), 2 );
	
		file.read( (char*)( &header ), sizeof( bmpHeader ) );

		file.read( (char*)( &info ), sizeof( bmpInfo ) );

		file.seekg( header.bmp_offset, std::ios::beg );

		image = new char[ info.width * info.height ];
	
		file.read(image, info.width * info.height);
	
		file.close();

		return true;
	}

	~Bitmap() {
		if( image != NULL ) {
			delete [] image;
		}
	}
	
	int Width() {
		return info.width;
	}
	
	int Height() {
		return info.height;
	}
	
	char GetPixel( int x, int y ) {
		return image[ y * info.width + x ];
	}
	
	void SetPixel( int x, int y, char color ) {
		image[ y * info.width + x ] = color;
	}
	
	char* image;
	
private:
	struct  bmpHeader {
		uint32_t filesz;
		uint16_t creator1;
		uint16_t creator2;
		uint32_t bmp_offset;
	};
	
	struct bmpInfo {
		uint32_t header_sz;
		int32_t width;
		int32_t height;
		uint16_t nplanes;
		uint16_t bitspp;
		uint32_t compress_type;
		uint32_t bmp_bytesz;
		int32_t hres;
		int32_t vres;
		uint32_t ncolors;
		uint32_t nimpcolors;
	};
	
	bmpHeader header;
	bmpInfo info;
	
};

#endif
