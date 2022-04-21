//
//  MF_Base32Additions.m
//  Base32 -- RFC 4648 compatible implementation
//  see http://www.ietf.org/rfc/rfc4648.txt for more details
//
//  Designed to be compiled with Automatic Reference Counting
//
//  Created by Dave Poirier on 12-06-14.
//  Public Domain
//

#import "MF_Base32Additions.h"

@implementation MF_Base32Codec
+(NSData *)dataFromBase32String:(NSString *)encoding
{
    NSData *data = nil;
    unsigned char *decodedBytes = NULL;
    @try {
#define __ 255
        static char decodingTable[256] = {
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x00 - 0x0F
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x10 - 0x1F
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x20 - 0x2F
            __,__,26,27, 28,29,30,31, __,__,__,__, __, 0,__,__,  // 0x30 - 0x3F
            __, 0, 1, 2,  3, 4, 5, 6,  7, 8, 9,10, 11,12,13,14,  // 0x40 - 0x4F
            15,16,17,18, 19,20,21,22, 23,24,25,__, __,__,__,__,  // 0x50 - 0x5F
            __, 0, 1, 2,  3, 4, 5, 6,  7, 8, 9,10, 11,12,13,14,  // 0x60 - 0x6F
            15,16,17,18, 19,20,21,22, 23,24,25,__, __,__,__,__,  // 0x70 - 0x7F
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x80 - 0x8F
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x90 - 0x9F
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xA0 - 0xAF
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xB0 - 0xBF
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xC0 - 0xCF
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xD0 - 0xDF
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xE0 - 0xEF
            __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xF0 - 0xFF
        };
        static NSUInteger paddingAdjustment[8] = {0,1,1,1,2,3,3,4};
        encoding = [encoding stringByReplacingOccurrencesOfString:@"=" withString:@""];
        NSData *encodedData = [encoding dataUsingEncoding:NSASCIIStringEncoding];
        unsigned char *encodedBytes = (unsigned char *)[encodedData bytes];

        NSUInteger encodedLength = [encodedData length];
        if( encodedLength >= (NSUIntegerMax - 7) ) return nil; // NSUInteger overflow check
        NSUInteger encodedBlocks = (encodedLength + 7) >> 3;
        NSUInteger expectedDataLength = encodedBlocks * 5;

        decodedBytes = calloc(expectedDataLength, 1);
        if( decodedBytes != NULL ) {

            unsigned char encodedByte1, encodedByte2, encodedByte3, encodedByte4;
            unsigned char encodedByte5, encodedByte6, encodedByte7, encodedByte8;
            NSUInteger encodedBytesToProcess = encodedLength;
            NSUInteger encodedBaseIndex = 0;
            NSUInteger decodedBaseIndex = 0;
            unsigned char encodedBlock[8] = {0,0,0,0,0,0,0,0};
            NSUInteger encodedBlockIndex = 0;
            unsigned char c;
            while( encodedBytesToProcess-- >= 1 ) {
                c = encodedBytes[encodedBaseIndex++];
                if( c == '=' ) break; // padding...

                c = decodingTable[c];
                if( c == __ ) continue;

                encodedBlock[encodedBlockIndex++] = c;
                if( encodedBlockIndex == 8 ) {
                    encodedByte1 = encodedBlock[0];
                    encodedByte2 = encodedBlock[1];
                    encodedByte3 = encodedBlock[2];
                    encodedByte4 = encodedBlock[3];
                    encodedByte5 = encodedBlock[4];
                    encodedByte6 = encodedBlock[5];
                    encodedByte7 = encodedBlock[6];
                    encodedByte8 = encodedBlock[7];
                    decodedBytes[decodedBaseIndex] = ((encodedByte1 << 3) & 0xF8) | ((encodedByte2 >> 2) & 0x07);
                    decodedBytes[decodedBaseIndex+1] = ((encodedByte2 << 6) & 0xC0) | ((encodedByte3 << 1) & 0x3E) | ((encodedByte4 >> 4) & 0x01);
                    decodedBytes[decodedBaseIndex+2] = ((encodedByte4 << 4) & 0xF0) | ((encodedByte5 >> 1) & 0x0F);
                    decodedBytes[decodedBaseIndex+3] = ((encodedByte5 << 7) & 0x80) | ((encodedByte6 << 2) & 0x7C) | ((encodedByte7 >> 3) & 0x03);
                    decodedBytes[decodedBaseIndex+4] = ((encodedByte7 << 5) & 0xE0) | (encodedByte8 & 0x1F);
                    decodedBaseIndex += 5;
                    encodedBlockIndex = 0;
                }
            }
            encodedByte7 = 0;
            encodedByte6 = 0;
            encodedByte5 = 0;
            encodedByte4 = 0;
            encodedByte3 = 0;
            encodedByte2 = 0;
            switch (encodedBlockIndex) {
                case 7:
                    encodedByte7 = encodedBlock[6];
                case 6:
                    encodedByte6 = encodedBlock[5];
                case 5:
                    encodedByte5 = encodedBlock[4];
                case 4:
                    encodedByte4 = encodedBlock[3];
                case 3:
                    encodedByte3 = encodedBlock[2];
                case 2:
                    encodedByte2 = encodedBlock[1];
                case 1:
                    encodedByte1 = encodedBlock[0];
                    decodedBytes[decodedBaseIndex] = ((encodedByte1 << 3) & 0xF8) | ((encodedByte2 >> 2) & 0x07);
                    decodedBytes[decodedBaseIndex+1] = ((encodedByte2 << 6) & 0xC0) | ((encodedByte3 << 1) & 0x3E) | ((encodedByte4 >> 4) & 0x01);
                    decodedBytes[decodedBaseIndex+2] = ((encodedByte4 << 4) & 0xF0) | ((encodedByte5 >> 1) & 0x0F);
                    decodedBytes[decodedBaseIndex+3] = ((encodedByte5 << 7) & 0x80) | ((encodedByte6 << 2) & 0x7C) | ((encodedByte7 >> 3) & 0x03);
                    decodedBytes[decodedBaseIndex+4] = ((encodedByte7 << 5) & 0xE0);
            }
            decodedBaseIndex += paddingAdjustment[encodedBlockIndex];
            data = [[NSData alloc] initWithBytes:decodedBytes length:decodedBaseIndex];            
        }
    }
    @catch (NSException *exception) {
        data = nil;
        NSLog(@"WARNING: error occured while decoding base 32 string: %@", exception);
    }
    @finally {
        if( decodedBytes != NULL ) {
            free( decodedBytes );
        }
    }
    return data;
}
+(NSString *)base32StringFromData:(NSData *)data
{
    NSString *encoding = nil;
    unsigned char *encodingBytes = NULL;
    @try {
        static char encodingTable[32] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
        static NSUInteger paddingTable[] = {0,6,4,3,1};
        
        //                     Table 3: The Base 32 Alphabet
        //
        // Value Encoding  Value Encoding  Value Encoding  Value Encoding
        //     0 A             9 J            18 S            27 3
        //     1 B            10 K            19 T            28 4
        //     2 C            11 L            20 U            29 5
        //     3 D            12 M            21 V            30 6
        //     4 E            13 N            22 W            31 7
        //     5 F            14 O            23 X
        //     6 G            15 P            24 Y         (pad) =
        //     7 H            16 Q            25 Z
        //     8 I            17 R            26 2

        NSUInteger dataLength = [data length];
        NSUInteger encodedBlocks = dataLength / 5;
        if( (encodedBlocks + 1) >= (NSUIntegerMax / 8) ) return nil; // NSUInteger overflow check
        NSUInteger padding = paddingTable[dataLength % 5];
        if( padding > 0 ) encodedBlocks++;
        NSUInteger encodedLength = encodedBlocks * 8;

        encodingBytes = calloc(encodedLength, 1);
        if( encodingBytes != NULL ) {
            NSUInteger rawBytesToProcess = dataLength;
            NSUInteger rawBaseIndex = 0;
            NSUInteger encodingBaseIndex = 0;
            unsigned char *rawBytes = (unsigned char *)[data bytes];
            unsigned char rawByte1, rawByte2, rawByte3, rawByte4, rawByte5;
            while( rawBytesToProcess >= 5 ) {
                rawByte1 = rawBytes[rawBaseIndex];
                rawByte2 = rawBytes[rawBaseIndex+1];
                rawByte3 = rawBytes[rawBaseIndex+2];
                rawByte4 = rawBytes[rawBaseIndex+3];
                rawByte5 = rawBytes[rawBaseIndex+4];
                encodingBytes[encodingBaseIndex] = encodingTable[((rawByte1 >> 3) & 0x1F)];
                encodingBytes[encodingBaseIndex+1] = encodingTable[((rawByte1 << 2) & 0x1C) | ((rawByte2 >> 6) & 0x03) ];
                encodingBytes[encodingBaseIndex+2] = encodingTable[((rawByte2 >> 1) & 0x1F)];
                encodingBytes[encodingBaseIndex+3] = encodingTable[((rawByte2 << 4) & 0x10) | ((rawByte3 >> 4) & 0x0F)];
                encodingBytes[encodingBaseIndex+4] = encodingTable[((rawByte3 << 1) & 0x1E) | ((rawByte4 >> 7) & 0x01)];
                encodingBytes[encodingBaseIndex+5] = encodingTable[((rawByte4 >> 2) & 0x1F)];
                encodingBytes[encodingBaseIndex+6] = encodingTable[((rawByte4 << 3) & 0x18) | ((rawByte5 >> 5) & 0x07)];
                encodingBytes[encodingBaseIndex+7] = encodingTable[rawByte5 & 0x1F];

                rawBaseIndex += 5;
                encodingBaseIndex += 8;
                rawBytesToProcess -= 5;
            }
            rawByte4 = 0;
            rawByte3 = 0;
            rawByte2 = 0;
            switch (dataLength-rawBaseIndex) {
                case 4:
                    rawByte4 = rawBytes[rawBaseIndex+3];
                case 3:
                    rawByte3 = rawBytes[rawBaseIndex+2];
                case 2:
                    rawByte2 = rawBytes[rawBaseIndex+1];
                case 1:
                    rawByte1 = rawBytes[rawBaseIndex];
                    encodingBytes[encodingBaseIndex] = encodingTable[((rawByte1 >> 3) & 0x1F)];
                    encodingBytes[encodingBaseIndex+1] = encodingTable[((rawByte1 << 2) & 0x1C) | ((rawByte2 >> 6) & 0x03) ];
                    encodingBytes[encodingBaseIndex+2] = encodingTable[((rawByte2 >> 1) & 0x1F)];
                    encodingBytes[encodingBaseIndex+3] = encodingTable[((rawByte2 << 4) & 0x10) | ((rawByte3 >> 4) & 0x0F)];
                    encodingBytes[encodingBaseIndex+4] = encodingTable[((rawByte3 << 1) & 0x1E) | ((rawByte4 >> 7) & 0x01)];
                    encodingBytes[encodingBaseIndex+5] = encodingTable[((rawByte4 >> 2) & 0x1F)];
                    encodingBytes[encodingBaseIndex+6] = encodingTable[((rawByte4 << 3) & 0x18)]; 
                    // we can skip rawByte5 since we have a partial block it would always be 0
                    break;
            }
            // compute location from where to begin inserting padding, it may overwrite some bytes from the partial block encoding
            // if their value was 0 (cases 1-3).
            encodingBaseIndex = encodedLength - padding;
            while( padding-- > 0 ) {
                encodingBytes[encodingBaseIndex++] = '=';
            }
            encoding = [[NSString alloc] initWithBytes:encodingBytes length:encodedLength encoding:NSASCIIStringEncoding];
        }
    }
    @catch (NSException *exception) {
        encoding = nil;
        NSLog(@"WARNING: error occured while tring to encode base 32 data: %@", exception);
    }
    @finally {
        if( encodingBytes != NULL ) {
            free( encodingBytes );
        }
    }
    return encoding;
}
@end

@implementation NSString (Base32Addition)
-(NSString *)base32String
{
    NSData *utf8encoding = [self dataUsingEncoding:NSUTF8StringEncoding];
    return [MF_Base32Codec base32StringFromData:utf8encoding];
}
+(NSString *)stringFromBase32String:(NSString *)base32String
{
    NSData *utf8encoding = [MF_Base32Codec dataFromBase32String:base32String];
    return [[NSString alloc] initWithData:utf8encoding encoding:NSUTF8StringEncoding];
}
@end

@implementation NSData (Base32Addition)
+(NSData *)dataWithBase32String:(NSString *)base32String
{
    return [MF_Base32Codec dataFromBase32String:base32String];
}
-(NSString *)base32String
{
    return [MF_Base32Codec base32StringFromData:self];
}
@end
