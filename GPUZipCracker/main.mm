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
@import Darwin;

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        XPMArgumentSignature
        *helpSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[-h --help]"],
        *inFileSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[-i --input-file]={1}"],
        *charsetSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[-c --charset]={1}"],
        *minWordLengthSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[-min --min-word-length]={1}"],
        *startingWordLengthSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[-s --starting-word]={1}"],
        *maxWordLengthSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[-max --max-word-length]={1}"];
        


        NSArray *signatures = @[helpSig, inFileSig, charsetSig, minWordLengthSig, maxWordLengthSig];
        
        XPMArgumentPackage *arguments = [[NSProcessInfo processInfo] xpmargs_parseArgumentsWithSignatures:signatures];
        
        if ([arguments booleanValueForSignature:helpSig]) {
            printf("This is a GPU-based deflated ZIP password bruteforcer.\n\n");
            
            printf(" -i --input-file: ZIP file to process.\n");
            
            printf(" -c --charset: Sets the character set used by the GPU to crack the password. Please note that the order of the characters will determine the order used by the program.\n");
            
            printf(" -min --min-word-length: Sets the minimum word length to try as password. The minimum currently supported is 5.\n");
            
            printf(" -max --max-word-length: Sets the maximum word length to try as password. The minimum currently supported is 10.\n");
            
            printf(" -s --starting-word: Sets the starting word for the search\n");

            
        } else {
            printf("%s\n", [[signatures description] UTF8String]);
        }
        
    }
    return 0;
}
