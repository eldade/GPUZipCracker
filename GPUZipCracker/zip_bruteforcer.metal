//
//  decrypt_for_crc32.metal
//  zipcracker
//
//  Created by Eldad Eilam on 10/11/17.
//  Copyright © 2017 Eldad Eilam. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

extern constant uint32_t pcrc_32_tab[256];


#define DECRYPT_BYTE(byte) (((byte) * ((byte) ^ 1)) >> 8)

#define UPDATE_KEYS(key, c)  \
    key.word[0] = (key.word[0] >> 8) ^ pcrc_32_tab[(key.bytes[0] ^ (c))]; \
    key.word[1] = (key.word[1] + key.bytes[0]) * 134775813 + 1; \
    key.word[2] = (key.word[2] >> 8) ^ pcrc_32_tab[(key.bytes[8] ^ (key.bytes[7]))];


#define DECRYPT_4_BYTES(i)   \
    UPDATE_KEYS(key, decoded.bytes[(i)] = data[(i)] ^ DECRYPT_BYTE(key.word[2] | 2));   \
    UPDATE_KEYS(key, decoded.bytes[(i)+1] = data[(i)+1] ^ DECRYPT_BYTE(key.word[2] | 2)); \
    UPDATE_KEYS(key, decoded.bytes[(i)+2] = data[(i)+2] ^ DECRYPT_BYTE(key.word[2] | 2)); \
    UPDATE_KEYS(key, decoded.bytes[(i)+3] = data[(i)+3] ^ DECRYPT_BYTE(key.word[2] | 2)); \


struct Params
{
    alignas(uint32_t)
    
    uint32_t base_value_low;
    uint32_t base_value_high;

    uint32_t charset_size;
    
    uint32_t init_key[3];
    
    atomic_uint match_count;
    uchar bytes_to_match[8];


    uint32_t match_positions[8];
};

union key_type
{
    uint32_t word[3];
    uchar bytes[12];
};

union decodedUnion
{
    uint32_t ints[16/4];
    uchar bytes[16];
};

void inline decrypt_and_check(thread key_type key, decodedUnion decoded, constant char *data, device Params *params, uint position)
{
    // Decrypt the 12 salt bytes plus the 12th verification byte:
    
    DECRYPT_4_BYTES(0)
    DECRYPT_4_BYTES(4)
    DECRYPT_4_BYTES(8)
    
    // Check one byte and leave if it doesn't match.
    if (decoded.bytes[11] != params->bytes_to_match[0])
        return;
    
    // It matched. Decode one more byte and see if it matches. And so on and so forth...
    // This is an optimization so we don't have to decode any redundant bytes (decoding is pretty
    // expensive).
    UPDATE_KEYS(key, decoded.bytes[12] = data[12] ^ DECRYPT_BYTE(key.word[2] | 2));
    
    if (decoded.bytes[12] != params->bytes_to_match[1])
        return;
    
    UPDATE_KEYS(key, decoded.bytes[13] = data[13] ^ DECRYPT_BYTE(key.word[2] | 2));
    
    if (decoded.bytes[13] != params->bytes_to_match[2])
        return;
    
    UPDATE_KEYS(key, decoded.bytes[14] = data[14] ^ DECRYPT_BYTE(key.word[2] | 2));
    
    if (decoded.bytes[14] != params->bytes_to_match[3])
        return;
    
    UPDATE_KEYS(key, decoded.bytes[15] = data[15] ^ DECRYPT_BYTE(key.word[2] | 2));
    
    if (decoded.bytes[15] != params->bytes_to_match[4])
        return;

    // All 5 bytes are a match, meaning we have a very likely (but not definite) match.
    
    // We increment an atomic counter and store our current position in the array:
    uint32_t last_count = atomic_fetch_add_explicit(&params->match_count, 1, memory_order_relaxed);
    
    params->match_positions[last_count] = position;
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
    size_t value = *(device size_t *) &params->base_value_low + position;
    
    uchar charset_size = params->charset_size;
    
    thread decodedUnion decoded;
    
    thread char word[20];
    
    for (int i = word_len - 1; i >= starting_index; i --)
    {
        MAKE_WORD_CHAR(i)
    }
    
    // 1) Initialize the three 32-bit keys with the password.
    
    thread key_type key;
    
    key.word[0] = params->init_key[0];
    key.word[1] = params->init_key[1];
    key.word[2] = params->init_key[2];
    
    for (int i = starting_index; i < word_len; i ++)
    {
        UPDATE_KEYS(key, word[i]);
    }
    
    decrypt_and_check(key, decoded, data, params, position);
}
