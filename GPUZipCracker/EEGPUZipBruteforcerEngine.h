//
//  EEGPUZipBruteforcer.h
//  zipcracker
//
//  Created by Eldad Eilam on 10/18/17.
//  Copyright © 2017 Eldad Eilam. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

typedef void (^ZipBruteForcerCompletionBlock)(NSArray<NSString *> *);

#pragma pack (4)
typedef struct Params
{
    uint64_t base_value;
    
    uint32_t charset_size;
    
    uint match_count;
    u_char bytes_to_match[8];
    
    uint32_t match_positions[1024];
} Params;

@interface EEGPUZipBruteforcerEngine : NSObject
{
    id<MTLLibrary> library;
    id <MTLFunction> kernelFunction;
    id <MTLCommandQueue> queue;
    
    id <MTLComputePipelineState> pipelineState5len;
    id <MTLComputePipelineState> pipelineState6len;
    id <MTLComputePipelineState> pipelineState7len;
    id <MTLComputePipelineState> pipelineState8len;
    id <MTLComputePipelineState> pipelineState9len;
    id <MTLComputePipelineState> pipelineState10len;

    
    id <MTLBuffer> charsetBuffer;
    id <MTLBuffer> encryptedDataBuffer;

    Params params;
    
    u_char bytes_to_match[5];
    
    char *processedCharset;
    int processedCharsetLen;
}

@property (nonatomic) NSString *charset;
@property id <MTLDevice> device;

@property uint64_t starting_value;

@property uint wordLen;

@property int commandPipelineDepth;

- (instancetype) initWithDevice: (id <MTLDevice>) device;
- (void) processPasswordPermutations: (uint32_t) count startingIndex: (uint64_t) startingIndex completion: (ZipBruteForcerCompletionBlock) completion;

- (void) setEncryptedData: (u_char *) encryptedBytes length: (int) length;
- (void) setBytesToMatch: (u_char *) bytes length: (int) length;

- (NSString *) wordFromIndex: (uint64_t) index;
- (void) printCurrentIndexString: (uint64_t) index;

@end
