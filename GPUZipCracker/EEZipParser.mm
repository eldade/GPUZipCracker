//
//  EEZipParser.m
//  GPUZipCracker
//
//  Created by Eldad Eilam on 10/22/17.
//  Copyright © 2017 Eldad Eilam. All rights reserved.
//

#import "EEZipParser.h"

@implementation EEZipParser

- (void) swap_lfh: (struct local_file_header_light*) lfh
         localLfh: (const struct local_file_header&) local_lfh
{
    lfh->good_crc_32               = local_lfh.good_crc_32;
    lfh->version_needed_to_extract = local_lfh.version_needed_to_extract;
    lfh->compression_method        = local_lfh.compression_method;
    lfh->start_byte                = local_lfh.start_byte;
    lfh->good_length               = local_lfh.good_length;
    lfh->uncompressed_size         = local_lfh.uncompressed_size;
    lfh->last_mod_file_time        = local_lfh.last_mod_file_time;
    lfh->strong_encryption         = local_lfh.strong_encryption;
    lfh->is_encrypted              = local_lfh.is_encrypted;
    if ( local_lfh.file_name_length > 0 ) {
        strncpy(lfh->file_name, local_lfh.file_name, 512);
    }
}

- (int) check_lfh
{
    size_t max16 = std::numeric_limits<uint16_t>::max();
    size_t max32 = std::numeric_limits<uint32_t>::max();
    
    if ( lfh.good_crc_32 > max32 ) {
        return -1;
    }
    if ( lfh.version_needed_to_extract > max16 ) {
        return -2;
    }
    if ( lfh.compression_method > 99 ) {
        return -3;
    }
    if ( lfh.start_byte > max32 ) {
        return -4;
    }
    if ( lfh.good_length > max32 ) {
        return -5;
    }
    if ( lfh.uncompressed_size > max32 ) {
        return -6;
    }
    if ( lfh.last_mod_file_time > max16 ) {
        return -7;
    }
    return 1;
}

- (void) read_central_directory: (std::ifstream&) filei
                             cd: (struct central_directory*) cd
                     start_byte: (const size_t) start_byte
{
    filei.seekg(start_byte, std::ios::beg);
    filei.read(reinterpret_cast<char*>(&cd->header_signature),            4);
    filei.read(reinterpret_cast<char*>(&cd->version_made_by),             2);
    filei.read(reinterpret_cast<char*>(&cd->version_needed_to_extract),   2);
    filei.read(reinterpret_cast<char*>(&cd->general_purpose_bit_flag),    2);
    filei.read(reinterpret_cast<char*>(&cd->compression_method),          2);
    filei.read(reinterpret_cast<char*>(&cd->last_mod_file_time),          2);
    filei.read(reinterpret_cast<char*>(&cd->last_mod_file_date),          2);
    filei.read(reinterpret_cast<char*>(&cd->crc_32),                      4);
    filei.read(reinterpret_cast<char*>(&cd->compressed_size),             4);
    filei.read(reinterpret_cast<char*>(&cd->uncompressed_size),           4);
    filei.read(reinterpret_cast<char*>(&cd->file_name_length),            2);
    filei.read(reinterpret_cast<char*>(&cd->extra_field_length),          2);
    filei.read(reinterpret_cast<char*>(&cd->file_comment_length),         2);
    filei.read(reinterpret_cast<char*>(&cd->disk_number_part),            2);
    filei.read(reinterpret_cast<char*>(&cd->internal_file_attributes),    2);
    filei.read(reinterpret_cast<char*>(&cd->external_file_attributes),    4);
    filei.read(reinterpret_cast<char*>(&cd->relative_offset_of_local_fh), 4);
    if ( cd->file_name_length > 0 ) {
        cd->file_name = new char[cd->file_name_length + 1];
        filei.read(cd->file_name, cd->file_name_length);
        cd->file_name[cd->file_name_length] = '\0';
    }
    if ( cd->extra_field_length > 0 ) {
        cd->extra_field = new char[cd->extra_field_length];
        filei.read(cd->extra_field, cd->extra_field_length);
    }
    if ( cd->file_comment_length > 0 ) {
        cd->file_comment = new char[cd->file_comment_length + 1];
        filei.read(cd->file_comment, cd->file_comment_length);
        cd->file_comment[cd->file_comment_length] = '\0';
    }
    // Check encryption
    cd->is_encrypted = cd->strong_encryption = false;
    if ( cd->general_purpose_bit_flag & 1 ) {
        cd->is_encrypted = true;
    }
    if ( cd->general_purpose_bit_flag & (1 << 6) ) {
        cd->strong_encryption = true;
    }
    
    if ( cd->file_name_length > 0 ) {
        delete[] cd->file_name;
    }
    if ( cd->extra_field_length > 0 ) {
        delete[] cd->extra_field;
    }
    if ( cd->file_comment_length > 0 ) {
        delete[] cd->file_comment;
    }
}

- (void) read_end_central_directory: (std::ifstream&) filei
                                ecd: (struct end_central_directory*) ecd
                         start_byte: (const size_t) start_byte
{
    filei.seekg(start_byte, std::ios::beg);
    filei.read(reinterpret_cast<char*>(&ecd->header_signature),            4);
    filei.read(reinterpret_cast<char*>(&ecd->number_of_disk),              2);
    filei.read(reinterpret_cast<char*>(&ecd->number_of_disk_with_cd),      2);
    filei.read(reinterpret_cast<char*>(&ecd->cd_on_this_disk),             2);
    filei.read(reinterpret_cast<char*>(&ecd->total_entries),               2);
    filei.read(reinterpret_cast<char*>(&ecd->cd_size),                     4);
    filei.read(reinterpret_cast<char*>(&ecd->offset),                      4);
    filei.read(reinterpret_cast<char*>(&ecd->zip_file_comment_length),     2);
    if ( ecd->zip_file_comment_length > 0 ) {
        ecd->zip_file_comment = new char[ecd->zip_file_comment_length + 1];
        filei.read(ecd->zip_file_comment, ecd->zip_file_comment_length);
        ecd->zip_file_comment[ecd->zip_file_comment_length] = '\0';
    }
    
    if ( ecd->zip_file_comment_length > 0 ) {
        delete[] ecd->zip_file_comment;
    }
}

- (void) read_local_file_header: (std::ifstream&) filei
                            lfh: (struct local_file_header_light*) lfh
                        several: (const bool) several
{
    local_file_header local_lfh;
    
    filei.read(reinterpret_cast<char*>(&local_lfh.header_signature),            4);
    
    filei.read(reinterpret_cast<char*>(&local_lfh.version_needed_to_extract),   2);
    filei.read(reinterpret_cast<char*>(&local_lfh.general_purpose_bit_flag),    2);
    filei.read(reinterpret_cast<char*>(&local_lfh.compression_method),          2);
    filei.read(reinterpret_cast<char*>(&local_lfh.last_mod_file_time),          2);
    filei.read(reinterpret_cast<char*>(&local_lfh.last_mod_file_date),          2);
    filei.read(reinterpret_cast<char*>(&local_lfh.crc_32),                      4);
    filei.read(reinterpret_cast<char*>(&local_lfh.compressed_size),             4);
    filei.read(reinterpret_cast<char*>(&local_lfh.uncompressed_size),           4);
    filei.read(reinterpret_cast<char*>(&local_lfh.file_name_length),            2);
    filei.read(reinterpret_cast<char*>(&local_lfh.extra_field_length),          2);
    if ( local_lfh.file_name_length > 0 ) {
        local_lfh.file_name = new char[local_lfh.file_name_length + 1];
        filei.read(local_lfh.file_name, local_lfh.file_name_length);
        local_lfh.file_name[local_lfh.file_name_length] = '\0';
    }
    if ( local_lfh.extra_field_length > 0 ) {
        local_lfh.extra_field = new char[local_lfh.extra_field_length + 1];
        filei.read(local_lfh.extra_field, local_lfh.extra_field_length);
        local_lfh.extra_field[local_lfh.extra_field_length] = '\0';
    }
    
    // Save the compressed data start byte
    local_lfh.start_byte = filei.tellg();
    
    // Data Descriptor
    local_lfh.has_data_descriptor         = false;
    local_lfh.data_desc_crc_32            = 0;
    local_lfh.data_desc_compressed_size   = 0;
    local_lfh.data_desc_uncompressed_size = 0;
    filei.seekg(local_lfh.compressed_size, std::ios::cur);
    if ( local_lfh.general_purpose_bit_flag & (1 << 3) ) {
        local_lfh.has_data_descriptor = true;
        filei.read(reinterpret_cast<char*>(&local_lfh.data_desc_signature),         4);
        // Data Description signature could be omitted, so take care of that!
        if ( local_lfh.data_desc_signature != 0x8074b50 ) {
            local_lfh.data_desc_crc_32 = local_lfh.data_desc_signature;
            local_lfh.data_desc_signature = 0;
        } else {
            filei.read(reinterpret_cast<char*>(&local_lfh.data_desc_crc_32),        4);
        }
        filei.read(reinterpret_cast<char*>(&local_lfh.data_desc_compressed_size),   4);
        filei.read(reinterpret_cast<char*>(&local_lfh.data_desc_uncompressed_size), 4);
    }
    
    // Data length
    local_lfh.good_length =
    (
     local_lfh.uncompressed_size > 0 ?
     local_lfh.uncompressed_size : local_lfh.data_desc_uncompressed_size
     );
    
    // CRC-32
    local_lfh.good_crc_32 =
    (
     local_lfh.crc_32 > 0 ?
     local_lfh.crc_32 :
     (
      local_lfh.data_desc_crc_32 > 0 ? local_lfh.data_desc_crc_32 :    0
      )
     );
    
    // Check encryption
    local_lfh.is_encrypted      = false;
    local_lfh.strong_encryption = false;
    if ( local_lfh.general_purpose_bit_flag & 1 ) {
        local_lfh.is_encrypted = true;
        if ( local_lfh.general_purpose_bit_flag & (1 << 6) ) {
            local_lfh.strong_encryption = true;
        }
    }
    
    // Now, let's decide if we need this entry o_0
    if ( several ) {
        // Check for folders: uncompressed size is 0 byte
        if ( local_lfh.uncompressed_size > 0 ) {
            // First, check file length: smaller bytes => faster crack process
            if ( local_lfh.good_length <= lfh->good_length ) {
                // Then, chek compression method: smaller number => simpler method => should be faster
                if ( local_lfh.compression_method <= lfh->compression_method ) {
                    [self swap_lfh:lfh localLfh: local_lfh];
                }
            } else if ( local_lfh.compression_method < lfh->compression_method ) {
                [self swap_lfh: lfh localLfh:local_lfh];
            }
        }
    } else {
        // There is only one file, so we choose this entry
        [self swap_lfh: lfh localLfh:local_lfh];
    }
    
    if ( local_lfh.file_name_length > 0 ) {
        delete[] local_lfh.file_name;
    }
    if ( local_lfh.extra_field_length > 0 ) {
        delete[] local_lfh.extra_field;
    }
}

-(bool) check_headers {
    uint32_t* header_signature = new uint32_t;
    uint32_t zip_signature = 0x04034b50;
    
    filei.read(reinterpret_cast<char*>(header_signature), 4);
    bool found = *header_signature == zip_signature;
    delete header_signature;
    return found;
}

- (bool) locate_appropriate_file
{
    filei.seekg(lfh.start_byte, std::ios::beg);
    if ( ecd.total_entries > 1 ) {
        for ( size_t i = 1; i <= ecd.total_entries; ++i ) {
            [self read_local_file_header: filei lfh: &lfh several: true];
        }
    } else {
        [self read_local_file_header: filei lfh: &lfh several:false];
    }
    
    chosen_file = [NSString stringWithUTF8String: lfh.file_name];
    
    if (lfh.is_encrypted == false || lfh.strong_encryption == true)
    {
        printf("Selected file in archive (%s), isn't encrypted or is encrypted using strong encryption.", lfh.file_name);
        return false;
    }
    
    if ([[chosen_file uppercaseString] hasSuffix: @".ZIP"] == NO)
    {
        printf("Selected file in archive (%s), doesn't appear to be a .ZIP archive. For now this program only supports decryption of ZIP archives stored within ZIP files...", lfh.file_name);
        return false;
    }
    
    return true;
}


- (bool) find_central_directory
{
    char* tmp = new char[4];
    bool found_end = false, found = false;
    size_t i;
    
    filei.seekg(-4, std::ios::end);
    i = filei.tellg();
    for ( ; i > 3 && !found; --i ) {
        filei.seekg(i, std::ios::beg);
        filei.read(tmp, 4);
        if ( !found_end ) {
            if ( tmp[0] == 0x50 && tmp[1] == 0x4b &&
                tmp[2] == 0x05 && tmp[3] == 0x06 ) {
                end_byte = i;
                found_end = true;
                i -= 3;
            } else if ( tmp[2] != 0x06 ) {
                --i;
                if ( tmp[1] != 0x06 ) {
                    --i;
                    if ( tmp[0] != 0x06 ) {
                        --i;
                    }
                }
            }
        } else {
            if ( tmp[0] == 0x50 && tmp[1] == 0x4b &&
                tmp[2] == 0x01 && tmp[3] == 0x02 ) {
                start_byte = i;
                found = true;
            } else if ( tmp[2] != 0x02 ) {
                --i;
                if ( tmp[1] != 0x02 ) {
                    --i;
                    if ( tmp[0] != 0x02 ) {
                        --i;
                    }
                }
            }
        }
    }
    delete[] tmp;
    return found;
}

- (void) init_lfh
{
    lfh.good_crc_32               = 0;
    lfh.version_needed_to_extract = 0;
    lfh.compression_method        = 99;
    lfh.start_byte                = 0;
    lfh.good_length               = 1024*1024*1024;
    lfh.uncompressed_size         = 0;
    lfh.last_mod_file_time        = 0;
    lfh.strong_encryption         = true;
    lfh.is_encrypted              = true;
}

- (bool) initializeZipFile
{
    if ( ![self check_headers] ) {
        NSLog(@" ! Bad ZIP file (wrong headers).");
        return false;
    }
    filei.seekg(0, std::ios::end);
    size_t size = filei.tellg();
    if ( size < 22 ) {
        NSLog(@" ! The file size is %d bytes, but the minimum size is 22 bytes.", size);
        return false;
    } else if ( size > 4294967295 ) {
        NSLog(@" ! The file size is %d bytes, but the maximum size is 4294967295 bytes.", size);
        return false;
    }
    
    if ( ![self find_central_directory] ) {
        NSLog(@"! Unable to find Central Directory signatures.");
        return false;
    }
    
    [self read_central_directory: filei cd: &cd start_byte: start_byte];
    [self read_end_central_directory: filei ecd: &ecd start_byte: end_byte];
    
    [self init_lfh];
    
    if ([self locate_appropriate_file] == NO)
    {
        return false;
    }
    
    if (lfh.compression_method != 0)
    {
        NSLog(@"ERROR: This program only supports stored ZIP files, no compression methods are supported.");
        return false;
    }
    
    if ([self check_lfh] != 1)
    {
        NSLog(@"Found a bad paramter in the LFH struct!");
        return false;
    }
    
    // Read encrypted data
    filei.seekg(lfh.start_byte, std::ios::beg);
    
    _encryption_header = (char *) malloc(12);
    filei.read(_encryption_header, 12);
    
    size_t len = lfh.good_length;
    
    _encrypted_data = (char *) malloc(len);
    filei.read(_encrypted_data, len);
    filei.close();
    
    return true;
}

- (instancetype) initWithFilename: (NSString *) filename
{
    self = [super init];
    filei = std::ifstream([filename UTF8String], std::ios::in | std::ios::binary);
    bool result = [self initializeZipFile];
    
    if (result == false)
        return nil;
    
    return self;
}

- (uint32_t) good_crc_32
{
    return lfh.good_crc_32;
}

- (uint16_t) last_mod_file_time
{
    return lfh.last_mod_file_time;
}


- (uint32_t) good_length
{
    return lfh.good_length;
}
- (bool) isValid
{
    if (_encryption_header != nil && _encrypted_data != nil)
        return true;
    else
        return false;
}

@end
