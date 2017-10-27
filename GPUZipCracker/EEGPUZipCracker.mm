//
//  EEGPUZipCracker.m
//  GPUZipCracker
//
//  Created by Eldad Eilam on 10/22/17.
//  Copyright © 2017 Eldad Eilam. All rights reserved.
//

#import "EEGPUZipCracker.h"
#import <Metal/Metal.h>
#import "EEGPUZipBruteforcerEngine.h"
#include "cpuDecryptEngine.hpp"

@implementation EEGPUZipCracker

- (void) setSelectedGPU:(int)selectedGPU
{
    NSArray <id<MTLDevice>> *devices = MTLCopyAllDevices();
    
    selectedDevice = devices[selectedGPU];
    
    _selectedGPU = selectedGPU;
}


+ (NSArray<NSString *>*) getAllGPUNames
{
    NSArray <id<MTLDevice>> *devices = MTLCopyAllDevices();
    NSMutableArray <NSString*> *gpuNames = [NSMutableArray array];
    
    for (id <MTLDevice> device in devices)
    {
        [gpuNames addObject:device.name];
    }
    
    return gpuNames;
}

- (NSString *) wordFromIndex: (uint64_t) index
{
    char word[currentWordLen];
    int i;
    
    for (i = currentWordLen - 1;
         i >= 0;
         i--)
    {
        word[i] = [_charset characterAtIndex: index % _charset.length];//_charset[index % _charset.length];
        index /= _charset.length;
    }
    
    word[currentWordLen] = 0;
    
    NSString *string =  [NSString stringWithUTF8String: word];
    
    return string;
}

- (bool) verifyCRC32UsingPassword: (NSString *) wordString
{
    const char *word = [wordString UTF8String];
    init_keys(word, keys);
    
    unsigned char* data     = new unsigned char[zipParser.good_length];
    uint8_t* buffer         = new uint8_t[12];
    
    
    // 2) Read and decrypt the 12-byte encryption header,
    //    further initializing the encryption keys.
    memcpy(buffer, zipParser.encryption_header, 12);
    for ( int i = 0; i < 12; ++i ) {
        update_keys(buffer[i] ^= decrypt_byte(keys), keys);
    }
    
    memcpy(data, zipParser.encrypted_data, zipParser.good_length);
    for ( int i = 0; i < zipParser.good_length; ++i ) {
        update_keys(data[i] ^= decrypt_byte(keys), keys);
    }
    
    if ( create_crc32(data, zipParser.good_length) == zipParser.good_crc_32 ) {
        delete[] data;
        delete[] buffer;

        return true;
    }

    delete[] data;
    delete[] buffer;
    
    return false;
}

- (NSUInteger) findCharInCharset: (NSString *) character
{
    NSRange range = [_charset rangeOfString: character];
    
    return range.location;
}

- (uint64_t) calculateStartingIndex
{
    
    if (_startingWord == nil)
        return 0;
    
    uint64_t value = 0;
    uint64_t multiplier = 1;
    for (NSInteger i = _startingWord.length - 1; i >= 0; i--)
    {
        NSUInteger position = [self findCharInCharset: [_startingWord substringWithRange:NSMakeRange(i, 1)]];
        
        assert(position != NSNotFound);
        
        value += position * multiplier;
        multiplier *= _charset.length;
    }

    return value;
}

- (void) statPrintingThread
{
    while (stillRunning)
    {
        sleep(60);
        
        double wordsPerSecond = (double) wordsTested / -[startTime timeIntervalSinceNow];
        
        NSTimeInterval secondsLeft = (double) (totalPermutationsForLen - index) / wordsPerSecond;
        
        // Get the system calendar
        NSCalendar *sysCalendar = [NSCalendar currentCalendar];
        
        // Create the NSDates
        NSDate *date1 = [NSDate date];
        NSDate *date2 = [[NSDate alloc] initWithTimeInterval:secondsLeft sinceDate: date1];
        
        // Get conversion to months, days, hours, minutes
        NSCalendarUnit unitFlags = NSHourCalendarUnit | NSMinuteCalendarUnit | NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit;
        
        NSDateComponents *breakdownInfo = [sysCalendar components:unitFlags fromDate:date1  toDate:date2  options:0];
        
        NSMutableString *timeLeftString = [NSMutableString string];
        
        [timeLeftString appendString:@"Time remaining: "];
        
        if ([breakdownInfo year] > 0)
            [timeLeftString appendFormat: @"%i years, ", [breakdownInfo year]];
        
        if ([breakdownInfo month] > 0)
            [timeLeftString appendFormat: @"%i months, ", [breakdownInfo month]];
        
        if ([breakdownInfo day] > 0)
            [timeLeftString appendFormat: @"%i days, ", [breakdownInfo day]];
        
        if ([breakdownInfo hour] > 0)
            [timeLeftString appendFormat: @"%i hours, ", [breakdownInfo hour]];
        
        if ([breakdownInfo minute] > 0)
            [timeLeftString appendFormat: @"%i minutes.", [breakdownInfo minute]];
        else if ([breakdownInfo hour] == 0 && [breakdownInfo day] == 0 && [breakdownInfo month] == 0)
            [timeLeftString appendFormat: @"%i seconds.", [breakdownInfo second]];
        
        if (wordsTested >= pow(10, 12))
            printf("Current word: %s | Tested %0.2fTH (%.0fMH/s). %s\n", [[self wordFromIndex: index] UTF8String], (float)wordsTested / pow(10, 12), wordsPerSecond / 1000000.0, [timeLeftString UTF8String]);
        else
            printf("Current word: %s | Tested %0.2fGH (%.0fMH/s). %s\n", [[self wordFromIndex: index] UTF8String], (float)wordsTested / pow(10, 9), wordsPerSecond / 1000000.0, [timeLeftString UTF8String]);
    }
}

- (void) crackThreadUsingDevice: (id <MTLDevice>) device wordLen: (int) wordLen
{
    u_char bytesToMatch[] = { (u_char) (zipParser.last_mod_file_time >> 8), 0x50, 0x4b, 0x03, 0x04 };
    
    u_char inputBuffer[16];
    
    memcpy(inputBuffer, zipParser.encryption_header, 12);
    memcpy(&inputBuffer[12], zipParser.encrypted_data, 4);
    
    EEGPUZipBruteforcerEngine *bruteForcer =  [[EEGPUZipBruteforcerEngine alloc] initWithDevice: device];
    
    [bruteForcer setCharset: _charset];
    [bruteForcer setBytesToMatch: (u_char *) &bytesToMatch length: 5];
    
    [bruteForcer setEncryptedData: (u_char *) &inputBuffer length: 16];
    
    bruteForcer.commandPipelineDepth = _GPUCommandPipelineDepth;
    
    startTime = [NSDate date];
    wordsTested = 0;
    
    
    bruteForcer.wordLen = wordLen;
    [bruteForcer setup];
   
    totalPermutationsForLen = pow(_charset.length, wordLen);
    
    uint64_t latestIndex = index.fetch_add(bruteForcer.iterationsPerRequest);
    
    while (latestIndex < totalPermutationsForLen)
    {
        @autoreleasepool {
            [bruteForcer processPasswordPermutationsWithStartingIndex: latestIndex
                                     completion:^(uint64_t iterationsExecuted, NSArray <NSString*> *matchedWords) {
                                         // NOTE: This is only for performance measurements, so we only increment it when an actual command is completed...
                                         wordsTested += iterationsExecuted;

                                         if (matchedWords != nil && matchedWords.count > 0)
                                         {
                                             for (NSString *wordString in matchedWords)
                                             {
                                                 printf("Matched word '%s'\n", [wordString UTF8String]);
                                                 
                                                 if ( [self verifyCRC32UsingPassword: wordString] ) {
                                                     printf("MATCHED and CONFIRMED password '%s'(on %s)!!\n", [wordString UTF8String], [device.name UTF8String]);
                                                     stillRunning = NO;
                                                     exit(1);
                                                 }
                                                 printf("Matched word '%s' failed CRC verification!\n", [wordString UTF8String]);
                                             }
                                         }
                                     }];
            
            latestIndex = index.fetch_add(bruteForcer.iterationsPerRequest);
        }
    }
}

- (bool) crack
{
    stillRunning = YES;
    
    NSArray <id <MTLDevice>> *devices = MTLCopyAllDevices();
    
    if (selectedDevice != nil)
        devices = @[selectedDevice];
    
    bruteForcers = [NSMutableArray array];
    
    uint64_t startingIndex = [self calculateStartingIndex];
    
    index = startingIndex;
    
    NSUInteger startingLen = _minLen;
    
    if (_startingWord != nil)
        startingLen = _startingWord.length;
    
    // Calculate the total number of permutations for all lengths:
    totalPermutations = 0;
    for (NSUInteger wordLen = startingLen; wordLen <= _maxLen; wordLen++)
    {
        if (wordLen == startingLen && startingIndex != 0)
        {
            totalPermutations = pow(_charset.length, wordLen) - startingIndex;
        }
        else
            totalPermutations += pow(_charset.length, wordLen);
    }
    
    uint64_t currentIndex = startingIndex;
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_queue_create("com.eldade.crackerqueue", DISPATCH_QUEUE_CONCURRENT);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self statPrintingThread];
    });
    
    for (currentWordLen = startingLen; currentWordLen <= _maxLen; currentWordLen++)
    {
        for (id <MTLDevice> device in devices)
        {
            dispatch_group_async(group, queue, ^{
                [self crackThreadUsingDevice: device wordLen: currentWordLen];
            });
        }
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        printf("Completed all %d-length words.\n", currentWordLen);
        
        index = 0;
        currentIndex = 0;
        wordsTested = 0;
    }

    
    
    
    

    startTime = [NSDate date];
    wordsTested = 0;
    
    index = startingIndex;
    
    startingIndex = 0; // Set the startingIndex to zero
    
    return false;
}

- (instancetype) initWithFilename: (NSString *) filename
{
    self = [super init];
    _GPUCommandPipelineDepth = 5;
    
    zipParser = [[EEZipParser alloc] initWithFilename: filename];
    if ([zipParser isValid] == NO)
        return nil;
    
    return self;
}

@end
