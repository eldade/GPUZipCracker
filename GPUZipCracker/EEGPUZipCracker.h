//
//  EEGPUZipCracker.h
//  GPUZipCracker
//
//  Created by Eldad Eilam on 10/22/17.
//  Copyright © 2017 Eldad Eilam. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EEZipParser.h"
#import "EEGPUZipBruteforcerEngine.h"

@interface EEGPUZipCracker : NSObject
{
    uint32_t keys[3];
    
    EEZipParser *zipParser;
    
    id <MTLDevice> selectedDevice;
    
    NSMutableArray <EEGPUZipBruteforcerEngine *> *bruteForcers;
    uint64_t index;
    NSDate *startTime;
    uint64_t wordsTested;
    int currentLen;
    uint64_t totalPermutations;
    
    BOOL stillRunning;
}

@property NSString *charset;
@property int minLen;
@property int maxLen;
@property NSString *startingWord;

@property int selectedGPU;

- (instancetype) initWithFilename: (NSString *) filename;

- (bool) crack;
- (uint64_t) startingIndexFromWord: (NSString *) startingWord;

+ (NSArray<NSString *>*) getAllGPUNames;

@end
