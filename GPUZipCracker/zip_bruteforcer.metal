//
//  decrypt_for_crc32.metal
//  zipcracker
//
//  Created by Eldad Eilam on 10/11/17.
//  Copyright © 2017 Eldad Eilam. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

extern constant uint32_t pcrc_32_tab[8][256];


#define DECRYPT_BYTE(byte) (((byte) * ((byte) ^ 1)) >> 8)

#define UPDATE_KEYS(key, c) key[0] = (key[0] >> 8) ^ pcrc_32_tab[0][(key[0] ^ (c)) & 0xff]; \
    key[1] = (key[1] + (key[0] & 0xff)) * 134775813 + 1; \
    key[2] = (key[2] >> 8) ^ pcrc_32_tab[0][(key[2] ^ (key[1] >> 24)) & 0xff];


#define DECRYPT_4_BYTES(i)   \
    UPDATE_KEYS(key, decoded.bytes[(i)] = data[(i)] ^ DECRYPT_BYTE(key[2] | 2));   \
    UPDATE_KEYS(key, decoded.bytes[(i)+1] = data[(i)+1] ^ DECRYPT_BYTE(key[2] | 2)); \
    UPDATE_KEYS(key, decoded.bytes[(i)+2] = data[(i)+2] ^ DECRYPT_BYTE(key[2] | 2)); \
    UPDATE_KEYS(key, decoded.bytes[(i)+3] = data[(i)+3] ^ DECRYPT_BYTE(key[2] | 2)); \


struct Params
{
    alignas(uint32_t)
    
    uint32_t base_value_low;
    uint32_t base_value_high;

    uint32_t charset_size;
    
    uint32_t init_key[3];
        
    atomic_uint match_count;
    uchar bytes_to_match[8];

    uint32_t match_positions[1024];
};

union decodedUnion
{
    uint32_t ints[16/4];
    uchar bytes[16];
};

void inline decrypt_and_check(thread uint3 key, decodedUnion decoded, constant char *data, device Params *params, uint position)
{
    // Decrypt the 12 salt bytes plus the 12th verification byte:
    
    DECRYPT_4_BYTES(0)
    DECRYPT_4_BYTES(4)
    DECRYPT_4_BYTES(8)
    
    // Check if we have a potential match:
    
    if (decoded.bytes[11] == params->bytes_to_match[0])
    {
        // The one-byte check passed, we decrypt the next four bytes and see if they match:
        DECRYPT_4_BYTES(12)
        
        if ((decoded.bytes[12] == params->bytes_to_match[1]) &&
            (decoded.bytes[13] == params->bytes_to_match[2]) &&
            (decoded.bytes[14] == params->bytes_to_match[3]) &&
            (decoded.bytes[15] == params->bytes_to_match[4]))
        {
            // If we do, increment an atomic counter and store our current position in the array.
            uint32_t last_count = atomic_fetch_add_explicit(&params->match_count, 1, memory_order_relaxed);
            
            params->match_positions[last_count] = position;
        }

    }
}

#define MAKE_WORD_CHAR(i)     word[(i)] = charset[value % charset_size]; \
                              value /= charset_size;

constant int word_len [[function_constant(0)]];
constant int starting_index [[function_constant(1)]];

kernel void generate_word_and_test(
                                        uint2 pig                                    [[ thread_position_in_grid ]],
                                        device Params *params                         [[ buffer(0) ]],
                                        constant uchar *charset                         [[ buffer(1) ]],
                                        constant char *data                          [[ buffer(2)]]
                                        )
{
    uint position = pig.x;
    size_t value = ((size_t) params->base_value_high << 32) + params->base_value_low + position;
    uchar charset_size = params->charset_size;
    
    thread decodedUnion decoded;
    
    thread char word[64];
    
    for (int i = word_len - 1; i >= starting_index; i --)
    {
        MAKE_WORD_CHAR(i)
    }
    
    // 1) Initialize the three 32-bit keys with the password.
    thread uint3 key = uint3( params->init_key[0], params->init_key[1], params->init_key[2] );
    
    for (int i = starting_index; i < word_len; i ++)
    {
        UPDATE_KEYS(key, word[i]);
    }
    
    decrypt_and_check(key, decoded, data, params, position);
}
