//
//  EEZipParser.h
//  GPUZipCracker
//
//  Created by Eldad Eilam on 10/22/17.
//  Copyright © 2017 Eldad Eilam. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <fstream>

/*!
 * \struct central_directory
 * \brief ZIP Central Directory structure.
 */
struct central_directory {
    uint32_t header_signature;             //!< Central file header signature on 4 bytes (0x02014b50)
    uint32_t crc_32;                       //!< CRC-32 on 4 bytes
    uint32_t compressed_size;              //!< Compressed size on 4 bytes
    uint32_t uncompressed_size;            //!< Uncompressed size on 4 bytes
    uint32_t relative_offset_of_local_fh;  //!< Relative offset of local header on 4 bytes
    uint32_t external_file_attributes;     //!< External file attributes on 4 bytes
    uint16_t version_made_by;              //!< Version made by on 2 bytes
    uint16_t version_needed_to_extract;    //!< Version needed to extract on 2 bytes
    uint16_t general_purpose_bit_flag;     //!< General purpose bit flag on 2 bytes
    uint16_t compression_method;           //!< Compression method on 2 bytes
    uint16_t last_mod_file_time;           //!< Last mod file time on 2 bytes
    uint16_t last_mod_file_date;           //!< Last mod file date on 2 bytes
    uint16_t file_name_length;             //!< File name length on 2 bytes
    uint16_t extra_field_length;           //!< Extra field length on 2 bytes
    uint16_t file_comment_length;          //!< File comment length on 2 bytes
    uint16_t disk_number_part;             //!< Disk number start on 2 bytes
    uint16_t internal_file_attributes;     //!< Internal file attributes on 2 bytes
    uint16_t extra_field_id;               //!< Extra field Header ID on 2 bytes
    unsigned int is_encrypted;             //!< Encryption enable? (unsigned int)
    unsigned int strong_encryption;        //!< Use strong encryption? (unsigned int)
    char * file_name;                      //!< File name (variable size)
    char * extra_field;                    //!< Extra field (variable size)
    char * file_comment;                   //!< File comment (variable size)
};

/*!
 * \struct end_central_directory
 * \brief ZIP end of Central Directory structure.
 */
struct end_central_directory {
    uint32_t header_signature;            //!< End of central dir signature on 4 bytes (0x06054b50)
    uint32_t cd_size;                     //!< Size of the central directory on 4 bytes
    uint32_t offset;                      //!< Offset of start of central directory with respect to the starting disk number on 4 bytes
    uint16_t number_of_disk;              //!< Number of this disk on 2 bytes
    uint16_t number_of_disk_with_cd;      //!< Number of the disk with thet start of the central directory on 2 bytes
    uint16_t cd_on_this_disk;             //!< Total number of entries in the central directory on this disk on 2 bytes
    uint16_t total_entries;               //!< Total number of entries in the central directory on 2 bytes
    uint16_t zip_file_comment_length;     //!< ZIP file comment length on 2 bytes
    uint16_t _pad;                        //!< Padding to feet the good alignment
    char * zip_file_comment;              //!< ZIP file comment (variable size)
};

/*!
 * \struct local_file_header
 * \brief ZIP Local File header structure.
 */
struct local_file_header {
    uint32_t header_signature;             //!< Local file header signature on 4 bytes (0x04034b50)
    uint32_t crc_32;                       //!< CRC-32 on 4 bytes
    uint32_t compressed_size;              //!< Compressed size on 4 bytes
    uint32_t uncompressed_size;            //!< Uncompressed size on 4 bytes
    uint32_t data_desc_signature;          //!< Data Descriptor signature (not always used, but should) on 4 bytes (0x08074b50)
    uint32_t data_desc_crc_32;             //!< CRC-32 on 4 bytes
    uint32_t data_desc_compressed_size;    //!< Compressed size on 4 bytes
    uint32_t data_desc_uncompressed_size;  //!< Uncompressed size on 4 bytes
    uint32_t good_crc_32;                  //!< If crc_32 is 0, then check data_desc_crc_32 on 4 bytes
    uint16_t version_needed_to_extract;    //!< Version needed to extract on 2 bytes
    uint16_t general_purpose_bit_flag;     //!< General purpose bit flag on 2 bytes
    uint16_t compression_method;           //!< compression method on 2 bytes
    uint16_t last_mod_file_time;           //!< Last mod file time on 2 bytes
    uint16_t last_mod_file_date;           //!< Last mod file date on 2 bytes
    uint16_t file_name_length;             //!< File name length on 2 bytes
    uint16_t extra_field_length;           //!< Extra field length on 2 bytes
    bool has_data_descriptor;              //!< Data descriptor presents? (bool)
    bool is_encrypted;                     //!< Encryption enabled? (bool)
    unsigned int start_byte;               //!< Start byte of compressed data (unsigned int)
    unsigned int good_length;              //!< If uncompressed_size is 0, then check data_desc_uncompressed_size (unsigned int)
    unsigned int strong_encryption;        //!< Use strong encryption? (bool)
    char * file_name;                      //!< File name (variable size)
    char * extra_field;                    //!< Extra field (variable size)
};

/*!
 * \struct local_file_header_light
 * \brief Light ZIP Local File header structure - we take only what we need.
 */
struct local_file_header_light {
    uint32_t good_crc_32;                 //!< If crc_32 is 0, then check data_desc_crc_32 on 4 bytes
    uint16_t version_needed_to_extract;   //!< Version needed to extract on 2 bytes
    uint16_t compression_method;          //!< compression method on 2 bytes
    uint32_t start_byte;                  //!< Start byte of compressed data on 4 bytes
    uint32_t good_length;                 //!< If uncompressed_size is 0, then check data_desc_uncompressed_size on 4 bytes
    uint32_t uncompressed_size;           //!< Uncompressed size, we need it to reserve the good space to prevent segfault on few files on 4 bytes
    uint16_t last_mod_file_time;          //!< Last mod file time on 2 bytes
    bool strong_encryption;               //!< Use strong encryption? (bool)
    bool is_encrypted;                    //!< Encryption enabled? (bool)
    char file_name[512];                  //!< File name (custom fixed size)
};

@interface EEZipParser : NSObject
{
    std::ifstream filei;
    
    size_t start_byte, end_byte, strong_encryption;
    local_file_header_light lfh;
    central_directory cd;
    end_central_directory ecd;
    
    NSString *chosen_file;
}

@property char *encryption_header;
@property char *encrypted_data;

@property (nonatomic) uint32_t good_length;
@property (nonatomic) uint32_t good_crc_32;
@property (nonatomic) uint16_t last_mod_file_time;

- (instancetype) initWithFilename: (NSString *) filename;
- (bool) isValid;

@end
