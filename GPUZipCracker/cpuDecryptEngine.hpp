//
//  crc32.hpp
//  GPUZipCracker
//
//  Created by Eldad Eilam on 10/22/17.
//  Copyright © 2017 Eldad Eilam. All rights reserved.
//

#ifndef crc32_hpp
#define crc32_hpp

#include <stdio.h>
#include <stdlib.h>

void update_keys(const int& c, uint32_t *keys);
void init_keys(const char* passwd, uint32_t *keys);
unsigned char decrypt_byte(uint32_t *keys);
uint32_t create_crc32(const unsigned char* buf, size_t len);

#endif /* crc32_hpp */
