//
//  main.m
//  zipcracker
//
//  Created by Eldad Eilam on 10/10/17.
//  Copyright © 2017 Eldad Eilam. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XPMArguments.h"
#import "EEGPUZipCracker.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        XPMArgumentSignature
        *helpSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[-h --help]"],
        *inFileSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[-i --input-file]={1,}"],
        *charsetSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[-c --charset]={1}"],
        *minWordLengthSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[-m --min-word-length]={1}"],
        *startingWordSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[-s --starting-word]={1}"],
        *gpuSelectionSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[-g --gpu-index]={1}"],
        *gpuPipelineDepthSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[-p  --gpu-pipeline-depth]={1}"],
        *maxWordLengthSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[-x --max-word-length]={1}"];

        NSArray *signatures = @[helpSig, inFileSig, charsetSig, minWordLengthSig, maxWordLengthSig, gpuPipelineDepthSig, startingWordSig, gpuSelectionSig];
        
        XPMArgumentPackage *arguments = [[NSProcessInfo processInfo] xpmargs_parseArgumentsWithSignatures:signatures];
        
        printf("This is a GPU-based deflated ZIP password bruteforcer.\n\n");
        
        NSArray<NSString *> *gpuNames = [EEGPUZipCracker getAllGPUNames];
        
        printf("Available GPUs:\n");
        int i = 0;
        for (NSString *gpuName in gpuNames)
        {
            printf("%d: %s\n", i++, [gpuName UTF8String]);
        }
        
        if ([arguments booleanValueForSignature:helpSig] || [arguments firstObjectForSignature: inFileSig] == nil) {
            
            printf(" -i --input-file: ZIP file to process.\n");
            
            printf(" -c --charset: Sets the character set used by the GPU to crack the password. Please note that the order of the characters will determine the order used by the program.\n");
            
            printf(" -m --min-word-length: Sets the minimum word length to try as password. The minimum currently supported is 5.\n");
            
            printf(" -x --max-word-length: Sets the maximum word length to try as password. The maximum currently supported is 15.\n");
            
            printf(" -s --starting-word: Sets the starting word for the search, otherwise program will start from first word ('aaaa', etc.)\n");

            printf(" -g  --gpu-index: Select a GPU to use. If not specified, all available GPUs will be used concurrently.\n");

            printf(" -p  --gpu-pipeline-depth: Specify the maximum number of GPU commands to issue without waiting for completion. A higher number will generally run somewhat faster, but might adversely affect system performance (maximum is 64).\n");

        } else {
            EEGPUZipCracker *cracker = [[EEGPUZipCracker alloc] initWithFilename: [[arguments firstObjectForSignature:inFileSig] description]];
            
            if (cracker == nil)
                return 0;
            
            cracker.minLen = [[arguments firstObjectForSignature: minWordLengthSig] intValue];
            cracker.maxLen = [[arguments firstObjectForSignature: maxWordLengthSig] intValue];
            cracker.charset = [arguments firstObjectForSignature: charsetSig];
            
            if (cracker.minLen == 0)
                cracker.minLen = 5;
            
            if (cracker.maxLen == 0)
                cracker.maxLen = 15;
            
            if (cracker.charset == nil)
                cracker.charset = @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*-";
            
            if ([arguments firstObjectForSignature: gpuPipelineDepthSig] != nil)
            {
                cracker.GPUCommandPipelineDepth = MAX(MIN(64, [[arguments firstObjectForSignature: gpuPipelineDepthSig] intValue]), 1);
                printf("Set GPU pipeline depth to %d commands.\n", cracker.GPUCommandPipelineDepth);
            }
            
            printf("Using charset: %s\n", [cracker.charset UTF8String]);
            
            if ([arguments firstObjectForSignature: startingWordSig] != nil)
            {
                cracker.startingWord = [arguments firstObjectForSignature: startingWordSig];
                printf ("Starting from word: '%s'\n", [cracker.startingWord UTF8String]);
                
                cracker.minLen = cracker.startingWord.length;
                
                if (cracker.maxLen < cracker.minLen)
                    cracker.maxLen = cracker.minLen;
            }
            
            if ([arguments firstObjectForSignature: gpuSelectionSig] != nil)
             {
                 cracker.selectedGPU = [[arguments firstObjectForSignature: gpuSelectionSig] intValue];
                 printf("Using selected GPU: %s\n", [gpuNames[cracker.selectedGPU] UTF8String]);
             }
            else
                printf("Using all available GPUs.\n");

            return [cracker crack];
        }
        
    }
    return 1;
}
