//
//  EEGPUZipBruteforcer.m
//  zipcracker
//
//  Created by Eldad Eilam on 10/18/17.
//  Copyright © 2017 Eldad Eilam. All rights reserved.
//

#import "EEGPUZipBruteforcerEngine.h"
#include "cpuDecryptEngine.hpp"

@implementation EEGPUZipBruteforcerEngine

- (instancetype) initWithDevice:(id<MTLDevice>)device
{
    _device = device;

    library = [device newDefaultLibrary];
    
    queue = [device newCommandQueue];
    
    memset(&params, 0, sizeof(params));

    return self;
}

- (void) setCommandPipelineDepth:(int)commandPipelineDepth
{
    queue = [_device newCommandQueueWithMaxCommandBufferCount: commandPipelineDepth];
    _commandPipelineDepth = commandPipelineDepth;
}

- (void) setCharset:(NSString *)charset
{
    processedCharset = (char *) malloc(charset.length + 1);
    
    strcpy (processedCharset, [charset UTF8String]);
    
    processedCharsetLen = charset.length;
    
    params.charset_size = processedCharsetLen;
}

- (void) setBytesToMatch: (u_char *) bytes length: (int) length
{
    assert(length == 5);
    
    memcpy(bytes_to_match, bytes, 5);
    
    memcpy(params.bytes_to_match, bytes, length);
}

- (void) setEncryptedData: (u_char *) encryptedBytes length: (int) length
{
    encryptedData = malloc(length);
    memcpy(encryptedData, encryptedBytes, length);
    encryptedDataLength = length;
}

- (void) setup
{
    // Create the pipeline state:
    int latestThreadCount = 0;
    
    for (charsPerKernel = 1; charsPerKernel < _wordLen; charsPerKernel++)
    {
        latestThreadCount = pow(processedCharsetLen, charsPerKernel);
        
        // Note: this is an arbitrary limit that helps us decide how many characters
        // to process per kernel. We're trying to shoot for more or less over
        // 100k iterations per GPU dispatch to maximize GPU utilization.
        if (latestThreadCount > 100000)
            break;
    }
    
    // Compile a kernel for the given word length and charsPerKernel:
    
    int startingOffset = _wordLen - charsPerKernel;
    
    MTLFunctionConstantValues *constantValues = [MTLFunctionConstantValues new];
    
    // Overall word len processed by the kernel:
    [constantValues setConstantValue: &_wordLen type:MTLDataTypeInt atIndex: 0];
    
    // Starting offset processed by the kernel:
    [constantValues setConstantValue: &startingOffset type:MTLDataTypeInt atIndex: 1];
        
    pipelineState = [_device newComputePipelineStateWithFunction: [library newFunctionWithName:@"generate_word_and_test" constantValues: constantValues error:nil] error:nil];
    
    topIndexForWordLen = pow(processedCharsetLen, _wordLen);
}

- (uint64_t) processPasswordPermutationsWithStartingIndex:(uint64_t)startingIndex completion:(ZipBruteForcerCompletionBlock)completion
{
    Params inputParams = params;
    inputParams.base_value = startingIndex;
    
    // As we prepare to test some hashes, we process the first few characters of the word in the CPU,
    // and pass the resulting key over the GPU. For each iteration, the GPU will only permute the rest of the word,
    // starting with the key provided here. This more or less cuts the GPU's workload in half.
    
    // Specifically, charsPerKernel indicates how many characters the GPU is processing in each iteration.
    // For each iteration, the CPU will prepare the first n number of characters for a given word. That number
    // is the current word length minus charsPerKernel.
    
    // The goal of this is to more or less balance the size of each GPU request with the amount of work the shader has
    // to do (how many characters it has to process).
    
    NSString *currentWord = [self wordFromIndex: startingIndex maxChars: _wordLen - charsPerKernel];
    
    init_keys([currentWord UTF8String], inputParams.init_key);
    
    id <MTLBuffer> paramBuffer = [_device newBufferWithBytes:&inputParams length:sizeof(inputParams) options: MTLResourceStorageModeManaged];
    
    [self processPasswordPermutationsWorker: pow(processedCharsetLen, charsPerKernel) paramBuffer: paramBuffer completion:completion];
    
    startingIndex += pow(processedCharsetLen, charsPerKernel);
        
    return pow(processedCharsetLen, charsPerKernel);
}

- (void) processPasswordPermutationsWorker: (uint32_t) count paramBuffer: (id<MTLBuffer>) paramsBuffer completion: (ZipBruteForcerCompletionBlock) completion
{
    id <MTLCommandBuffer> commandBuffer = [queue commandBuffer];

    id <MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
    
    [encoder setBuffer: paramsBuffer offset:0 atIndex:0];
    
    [encoder setBytes: processedCharset length: processedCharsetLen atIndex: 1];
    [encoder setBytes: encryptedData length: encryptedDataLength atIndex: 2];
    
    [encoder setComputePipelineState: pipelineState];
    
    [encoder dispatchThreads:MTLSizeMake(count, 1, 1) threadsPerThreadgroup:MTLSizeMake(_device.maxThreadsPerThreadgroup.width, 1, 1)];
    [encoder endEncoding];
    id <MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
    [blitEncoder synchronizeResource: paramsBuffer];
    [blitEncoder endEncoding];
    
    __block int wordLen = _wordLen;

    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull commandBuffer) {
            Params * outputParams = (Params *) paramsBuffer.contents;
        
        assert(outputParams != nil);

        NSMutableArray<NSString *> *matchedWords = nil;

        if (outputParams->match_count > 0)
        {
            matchedWords = [NSMutableArray array];

            for (int i = 0; i < outputParams->match_count; i++)
            {
                [matchedWords addObject: [self wordFromIndex: outputParams->base_value + outputParams->match_positions[i] maxChars: wordLen]];
            }
        }

        completion(count, matchedWords);
    }];
    
    [commandBuffer commit];
    
    return;
}

- (void) printCurrentIndexString: (uint64_t) index
{
    char word[_wordLen + 1];
    int i;
    
    for (i = _wordLen - 1;
         i >= 0;
         i--)
    {
        word[i] = processedCharset[index % processedCharsetLen];
        index /= processedCharsetLen;
    }
    
    word[_wordLen] = 0;
    
    printf ("Currently processing word '%s'\n", word);
}

- (NSString *) wordFromIndex: (uint64_t) index maxChars: (int) maxChars
{
    char word[_wordLen];
    int i;
    
    for (i = _wordLen - 1;
         i >= 0;
         i--)
    {
        word[i] = processedCharset[index % processedCharsetLen];
        index /= processedCharsetLen;
    }
    
    word[_wordLen] = 0;
    
    NSString *string =  [NSString stringWithUTF8String: word];
    
    return [string substringToIndex: maxChars];
}

- (uint64_t) stringToIndex: (char *) string
{
    char reverse_charset[128] = {0};
    
    char *charset = (char *) processedCharset;
    
    for (int i = 0; i < processedCharsetLen; i++)
    {
        reverse_charset[charset[i]] = i;
    }
    
    return 0;
}

- (int) iterationsPerRequest
{
    return pow(processedCharsetLen, charsPerKernel);// * _commandPipelineDepth;
}


@end

