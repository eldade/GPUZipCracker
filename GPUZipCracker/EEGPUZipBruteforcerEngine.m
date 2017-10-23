//
//  EEGPUZipBruteforcer.m
//  zipcracker
//
//  Created by Eldad Eilam on 10/18/17.
//  Copyright © 2017 Eldad Eilam. All rights reserved.
//

#import "EEGPUZipBruteforcerEngine.h"
@import Darwin;

@implementation EEGPUZipBruteforcerEngine

- (instancetype) initWithDevice:(id<MTLDevice>)device
{
    _device = device;

    library = [device newDefaultLibrary];
    
    // Create the pipeline states:
    pipelineState5len = [device newComputePipelineStateWithFunction: [library newFunctionWithName:@"generate_word_and_test_5len"]
                                                              error:nil];
    pipelineState6len = [device newComputePipelineStateWithFunction: [library newFunctionWithName:@"generate_word_and_test_6len"]
                                                              error:nil];
    pipelineState7len = [device newComputePipelineStateWithFunction: [library newFunctionWithName:@"generate_word_and_test_7len"]
                                                              error:nil];
    pipelineState8len = [device newComputePipelineStateWithFunction: [library newFunctionWithName:@"generate_word_and_test_8len"]
                                                                                        error:nil];
    pipelineState9len = [device newComputePipelineStateWithFunction: [library newFunctionWithName:@"generate_word_and_test_9len"]
                                                              error:nil];
    pipelineState10len = [device newComputePipelineStateWithFunction: [library newFunctionWithName:@"generate_word_and_test_10len"]
                                                              error:nil];

    
    queue = [device newCommandQueue];
    
    memset(&params, 0, sizeof(params));

    return self;
}

- (void) setCharset:(NSString *)charset
{
    processedCharset = malloc(charset.length + 1);
    
    strcpy (processedCharset, [charset UTF8String]);
    
    charsetBuffer = [_device newBufferWithBytes: processedCharset length: charset.length options: MTLResourceStorageModeManaged];
    
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
    encryptedDataBuffer = [_device newBufferWithBytes: encryptedBytes length: length options: MTLResourceStorageModeManaged];
}

- (void) processPasswordPermutations: (uint32_t) count startingIndex: (uint64_t) startingIndex completion: (ZipBruteForcerCompletionBlock) completion
{
    NSMutableArray <id <MTLCommandBuffer>> *commandBuffers = [NSMutableArray array];
    
    assert(count % 5 == 0);
    
    for (int i = 0; i < 5; i++)
    {
        Params inputParams = params;
        inputParams.base_value = startingIndex;
        
        id <MTLBuffer> paramBuffer = [_device newBufferWithBytes:&inputParams length:sizeof(inputParams) options: MTLResourceStorageModeManaged];
         
        [commandBuffers addObject: [self processPasswordPermutationsWorker: count / 5 paramBuffer: paramBuffer completion:completion]];
        
        startingIndex += count / 5;
    }
    
    [commandBuffers[0] waitUntilCompleted];
}

- (id <MTLCommandBuffer>) processPasswordPermutationsWorker: (uint32_t) count paramBuffer: (id<MTLBuffer>) paramsBuffer completion: (ZipBruteForcerCompletionBlock) completion
{
    id <MTLCommandBuffer> commandBuffer = [queue commandBuffer];

    id <MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
    
    [encoder setBuffer: paramsBuffer offset:0 atIndex:0];
    [encoder setBuffer: charsetBuffer offset: 0 atIndex:1];
    [encoder setBuffer: encryptedDataBuffer offset:0 atIndex: 2];
    
    switch(_wordLen)
    {
        case 5:
            [encoder setComputePipelineState: pipelineState5len];
            break;
        case 6:
            [encoder setComputePipelineState: pipelineState6len];
            break;
        case 7:
            [encoder setComputePipelineState: pipelineState7len];
            break;
        case 8:
            [encoder setComputePipelineState: pipelineState8len];
            break;
        case 9:
            [encoder setComputePipelineState: pipelineState9len];
            break;
        case 10:
            [encoder setComputePipelineState: pipelineState10len];
            break;

        default:
            NSLog(@"Unsupported word length: %d", _wordLen);
    }
    
    [encoder dispatchThreads:MTLSizeMake(count, 1, 1) threadsPerThreadgroup:MTLSizeMake(_device.maxThreadsPerThreadgroup.width, 1, 1)];
    [encoder endEncoding];
    id <MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
    [blitEncoder synchronizeResource: paramsBuffer];
    [blitEncoder endEncoding];
    
    __block id<MTLBuffer> outputParamsBuffer = paramsBuffer;
    
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull commandBuffer) {
        NSMutableArray<NSString *> *matchedWords = nil;
        
        Params * outputParams = outputParamsBuffer.contents;
        
        if (outputParams->match_count > 0)
        {
            matchedWords = [NSMutableArray array];
            
            for (int i = 0; i < outputParams->match_count; i++)
            {
                [matchedWords addObject: [self wordFromIndex: outputParams->base_value + outputParams->match_positions[i]]];
            }
        }

        completion(matchedWords);
        
        [paramsBuffer setPurgeableState: MTLPurgeableStateEmpty];
    }];
    
    [commandBuffer commit];
    
    return commandBuffer;
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

- (NSString *) wordFromIndex: (uint64_t) index
{
    char word[16];
    int i;
    
    for (i = 8 - 1;
         i >= 0;
         i--)
    {
        word[i] = processedCharset[index % processedCharsetLen];
        index /= processedCharsetLen;
    }
    
    word[8] = 0;
    
    return [NSString stringWithUTF8String: word];
}

- (uint64_t) stringToIndex: (char *) string
{
    char reverse_charset[128] = {0};
    
    char *charset = charsetBuffer.contents;
    
    for (int i = 0; i < charsetBuffer.length; i++)
    {
        reverse_charset[charset[i]] = i;
    }
    
    return 0;
}


@end
