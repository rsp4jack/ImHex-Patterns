#pragma description MMA XMF and MXMF

// This implements:
// RP-030 Specification for XMF Meta File Format 1.0
// RP-031 Type 0 & Type 1 XMF Files (DLS + SMF)
// RP-032 SMF Meta Event for XMF Patch Type Prefix
// RP-039 XMF Meta File Format Updates 1.01
// RP-040 XMF Compressions Definition for “zlib”
// RP-042a Type 2 XMF File (Mobile XMF)
// RP-043 Specification for XMF Meta File Format 2.0
// RP-045 Audio Clips for Mobile XMF
// RP-047 ID3 Metadata for XMF Files

#pragma endian big

// audio/xmfN does not seem to be used
#pragma MIME audio/mobile-xmf

import std.core;
import std.io;
import std.mem;
import std.array;
import type.guid;
import hex.dec;
 
import * from id3 as ID3;

fn u32ify(u32 vlq) {
    // Converts from variable-length quantity to u32. These numbers are
    // represented 7 bits per byte, most significant bits first. All bytes
    // except the last have bit 7 set, and the last byte has bit 7 clear.
    // If the number is in range 0..127, it is thus represented exactly
    // as one byte.
    u32 n = vlq & 0x7f;
    if (vlq & 0x8000 == 0x8000) {
        n += ((vlq & 0x7f00) >> 8) * 0x80;
    }
    if (vlq & 0x800000 == 0x800000) {
        n += ((vlq & 0x7f0000) >> 8 * 2) * 0x80 * 0x80;
    }
    if (vlq & 0x80000000 == 0x80000000) {
        n += ((vlq & 0x7f000000) >> 8 * 3) * 0x80 * 0x80 * 0x80;
    }
    return n;
};

// TODO: We got VLQs up to 19 bytes long for non-registered ids, and how can we handle it?
struct VLQ<auto name> {
    if (std::mem::read_unsigned($, 1) & 0x80 == 0x80) {
        if (std::mem::read_unsigned($ + 1, 1) & 0x80 == 0x80) {
            if (std::mem::read_unsigned($ + 2, 1) & 0x80 == 0x80) {
                u32 value [[format("u32ify"), name(name)]];
            } else {
                u24 value [[format("u32ify"), name(name)]];
            }
        } else {
            u16 value [[format("u32ify"), name(name)]];
        }
    } else {
        u8 value [[format("u32ify"), name(name)]];
    }
};

fn unwrapVLQ(auto vlq) {
    return u32ify(vlq.value);
};

struct VLQPointer<auto name, T> {
    if (std::mem::read_unsigned($, 1) & 0x80 == 0x80) {
        if (std::mem::read_unsigned($ + 1, 1) & 0x80 == 0x80) {
            if (std::mem::read_unsigned($ + 2, 1) & 0x80 == 0x80) {
                T* pointer: u32[[format("u32ify"), name(name)]];
            } else {
                T* pointer: u24 [[format("u32ify"), name(name)]];
            }
        } else {
            T* pointer: u16 [[format("u32ify"), name(name)]];
        }
    } else {
        T* pointer: u8 [[format("u32ify"), name(name)]];
    }
};
struct VLQPointerToArray<auto name, T, auto size> {
    if (std::mem::read_unsigned($, 1) & 0x80 == 0x80) {
        if (std::mem::read_unsigned($ + 1, 1) & 0x80 == 0x80) {
            if (std::mem::read_unsigned($ + 2, 1) & 0x80 == 0x80) {
                T* pointer[size]: u32[[format("u32ify"), name(name)]];
            } else {
                T* pointer[size]: u24 [[format("u32ify"), name(name)]];
            }
        } else {
            T* pointer[size]: u16 [[format("u32ify"), name(name)]];
        }
    } else {
        T* pointer[size]: u8 [[format("u32ify"), name(name)]];
    }
};

// Enums

enum FileID : u32 {
    XMF_ = 0x584D465F // "XMF_"
};

enum ReferenceTypeID : u8 {
    InlineResource = 0x01,
    InFileResource = 0x02,
    InFileNode = 0x03,
    ExternalResourceFile = 0x04,
    XMFURI = 0x05,
    XMFURIAndNodeID = 0x06
};

enum XMFMetaFileVersion : u32 {
    v1 = 0x312E3030,
    v2 = 0x322E3030
};

enum MetaDataStandardFieldID : u8 { // actually VLQ
    XMFFileType = 0,
    NodeName = 1,
    NodeID = 2,
    ResourceFormat = 3,
    FilenameOnDisk = 4,
    FilenameExtensionOnDisk = 5,
    MacOSFileType = 6,
    MIMEType = 7,
    Title = 8,
    Copyright = 9,
    Comment = 10,
    Autostart = 11,
    Preload = 12,
    ContentDescription = 13,
    ID3Metadata = 14
};

enum MetaDataStandardResourceFormatID : u8 { // actually VLQ
    SMF0 = 0,
    SMF1 = 1,
    DLS1 = 2,
    DLS2 = 3,
    DLS21 = 4,
    MDLS = 5
};

enum StandardTypeID : u8 { // actually VLQ
    Standard = 0,
    MMAManufacturer = 1,
    Registered = 2,
    Nonregistered = 3
};

enum PRLTypeID : u8 {
    Standard = 0,
    MMAManufacturer = 1,
    Registered = 2,
    Nonregistered = 3,
    WTCodecFormatTag = 4,
    WTCodecGUID = 5
};

enum PRGLGroupID : u8 {
    SynthesizerVoice = 0,
    WTCodec = 1,
    WTMemoryConsumption = 2,
    // exclusive means it cuts itself
    AudioClipsExclusive = 3,
    AudioClipsNonexclusive = 4,
    AudioClipsVoice = 5
};

enum PRLStandardID : u8 {
    // PRGL 0
    GM1VoiceCount = 0,
    MDLSVoiceCount = 1,
    MDLSVoiceCountWithControlGroup = 2,

    // PRGL 2
    DLSWTSizeKiB = 3, // Total wavetable data consumption (in kilobytes) for Mobile DLS instruments using (16-bit, 8-bit) PCM samples
    MDLSWTSizeKiB = 4, // Total uncompressed wavetable data (in kilobytes) for Mobile DLS instruments using compressed samples

    // PRGL 5
    AudioClipsCount = 5,

    // PRGL 3
    AudioClipsWTSizeKiB = 6,

    // PRGL 4
    AudioClipsMaxSR = 7, // in kilosamples per 10 seconds

    // PRGL 3
    // in kilobits per 10 seconds
    AudioClipsAverageBitrate = 8,
    AudioClipsMaxBitrate = 9
};

enum StringFormatTypeID : u8 { // actually VLQ
    EASCIIVisible = 0,
    EASCIIHidden = 1,
    UTF16Visible = 2,
    UTF16Hidden = 3,
    SCSUVisible = 4,
    SCSUHidden = 5,
    BinaryVisible = 6,
    BinaryHidden = 7
};

enum StandardUnpackerID : u8 { // actually VLQ
    None = 0,
    ZLIB = 1
};

enum TypewFormatTag : u16 {
    WAVE_FORMAT_PCM                = 0x0001,               // Microsoft PCM Format
    WAVE_FORMAT_ADPCM              = 0x0002,               // Microsoft ADPCM Format
    WAVE_FORMAT_IEEE_FLOAT         = 0x0003,               // IEEE float
    WAVE_FORMAT_VSELP              = 0x0004,               // Compaq Computer's VSELP
    WAVE_FORMAT_IBM_CVSD           = 0x0005,               // IBM CVSD
    WAVE_FORMAT_ALAW               = 0x0006,               // ALAW
    WAVE_FORMAT_MULAW              = 0x0007,               // MULAW
    WAVE_FORMAT_DTS                = 0x0008,               // Digital Theater Systems DTS
    WAVE_FORMAT_DRM                = 0x0009,               // Microsoft Corporation
    WAVE_FORMAT_WMAVOICE9          = 0x000A,               // Microsoft Corporation
    WAVE_FORMAT_WMAVOICE10         = 0x000B,               // Microsoft Corporation
    WAVE_FORMAT_OKI_ADPCM          = 0x0010,               // OKI ADPCM
//  WAVE_FORMAT_DVI_ADPCM          = 0x0011,               // Intel's DVI ADPCM
    WAVE_FORMAT_IMA_ADPCM          = 0x0011,               // Intel's DVI ADPCM
    WAVE_FORMAT_MEDIASPACE_ADPCM   = 0x0012,               // Videologic's MediaSpace ADPCM
    WAVE_FORMAT_SIERRA_ADPCM       = 0x0013,               // Sierra ADPCM
    WAVE_FORMAT_G723_ADPCM         = 0x0014,               // G.723 ADPCM
    WAVE_FORMAT_DIGISTD            = 0x0015,               // DSP Solution's DIGISTD
    WAVE_FORMAT_DIGIFIX            = 0x0016,               // DSP Solution's DIGIFIX
    WAVE_FORMAT_DIALOGIC_OKI_ADPCM = 0x0017,               // Dialogic Corporation
    WAVE_FORMAT_MEDIAVISION_ADPCM  = 0x0018,               // Media Vision ADPCM
    WAVE_FORMAT_YAMAHA_ADPCM       = 0x0020                // Yamaha ADPCM
};

// Atomic

struct XString {
    VLQ<"length"> length [[inline]];
    char data[(length)];
};

// Metadata

struct PRLEntry {
    PRLTypeID typeID;
    if (typeID == PRLTypeID::Standard) {
        PRLStandardID standardID;
    } else if (typeID == PRLTypeID::MMAManufacturer) {
        VLQ<"manufacturerID"> manufacturerID [[inline]];
        VLQ<"internalID"> internalID [[inline]];
    } else if (typeID == PRLTypeID::Registered) {
        VLQ<"registeredID"> registeredID [[inline]];
    } else if (typeID == PRLTypeID::Nonregistered) {
        type::GUID guid;
    } else if (typeID == PRLTypeID::WTCodecFormatTag) {
        TypewFormatTag wFormatTag;
    } else if (typeID == PRLTypeID::WTCodecGUID) {
        type::GUID guid;
    }
};

// MXMF
struct ContentDescription {
    VLQ<"MIPIndex"> MIPIndex [[inline]];
    VLQ<"ChannelCount"> ChannelCount [[inline]];
    VLQ<"PlaybackResourceCount"> PlaybackResourceCount [[inline]];
    PRLEntry PRL[unwrapVLQ(PlaybackResourceCount.value)];
    PRGLGroupID PRGL[unwrapVLQ(PlaybackResourceCount.value)];
    std::Array<std::Array<VLQ<"MIRCount">, unwrapVLQ(PlaybackResourceCount.value)>, unwrapVLQ(ChannelCount.value)> MIRCountTable;
};

struct MetaDataTypeEntry {
    VLQ<"metadataType"> metadataType [[inline]];
    VLQ<"stringFormatTypeID"> stringFormatTypeID [[inline]];
    XString langCountrySpec;
};

struct MetaDataTypesTable {
    VLQ<"size"> size [[inline]];
    if (unwrapVLQ(size) != 0) {
        VLQ<"numberOfEntries"> numberOfEntries [[inline]];
        MetaDataTypeEntry typeEntries[unwrapVLQ(numberOfEntries)];
    }
};

struct FieldSpecifier {
    if (std::mem::read_unsigned($, 1) == 0) {
        u8;
        // VLQ<"fieldID"> fieldID [[inline]];
        MetaDataStandardFieldID fieldID; // standard fieldid is no longer than u8
    } else {
        XString fieldName;
    }
};

struct ContentVersion {
    VLQ<"metadataType"> metadataType [[inline]];
    VLQ<"lengthOfData"> lengthOfData [[inline]];
    char versionData[unwrapVLQ(lengthOfDat)];
};

struct FieldContents {
    VLQ<"numberOfVersions"> numberOfVersions [[inline]];
    VLQ<"lengthOfData"> lengthOfData [[inline]];
    if (unwrapVLQ(lengthOfData) == 0) {
        u8; // stirngFormatTypeID
    } else {
        if (unwrapVLQ(numberOfVersions) == 0) {
            StringFormatTypeID stringFormatTypeID;
            try {
                if (parent.fieldSpecifier.fieldID == MetaDataStandardFieldID::XMFFileType) {
                    VLQ<"fileTypeID"> fileTypeID [[inline]];
                    VLQ<"revisionID"> revisionID [[inline]];
                } else if (parent.fieldSpecifier.fieldID == MetaDataStandardFieldID::NodeID) {
                    VLQ<"nodeID"> nodeID [[inline]];
                } else if (parent.fieldSpecifier.fieldID == MetaDataStandardFieldID::ResourceFormat) {
                    StandardTypeID formatTypeID;
                    if (formatTypeID == StandardTypeID::Standard) {
                        MetaDataStandardResourceFormatID standardResourceFormatID;
                    } else {
                        VLQ<"resourceFormatID"> resourceFormatID [[inline]];
                    }
                } else if (parent.fieldSpecifier.fieldID == MetaDataStandardFieldID::ContentDescription) {
                    ContentDescription contentDescription;
                } else if (parent.fieldSpecifier.fieldID == MetaDataStandardFieldID::ID3Metadata) {
                    ID3 id3v2;
                } else {
                    std::error();
                }
                padding[addressof(stringFormatTypeID)+unwrapVLQ(lengthOfData)-$];
            } catch {
                char universalData[unwrapVLQ(lengthOfData)-sizeof(stringFormatTypeID)];
            }
        } else {
            ContentVersion versions[while(!std::mem::reached(addressof(verions)+unwrapVLQ(size)))];
        }
    }
};

struct MetaDataItem {
    FieldSpecifier fieldSpecifier;
    FieldContents fieldContents;
};

struct NodeMetaData {
    VLQ<"size"> size [[inline]];
    MetaDataItem items[while(!std::mem::reached(addressof(this)+unwrapVLQ(size)))];
};

// Unpacker

struct UnpackerID {
    StandardTypeID typeID;
    if (typeID == StandardTypeID::Standard) {
        StandardUnpackerID standardUnpackerID;
    } else {
        VLQ<"id"> id [[inline]];
    }
};

struct UnpackerEntry {
    UnpackerID unpackerID;
    VLQ<"decodedLength"> decodedLength;
};

struct NodeUnpackers {
    VLQ<"size"> size [[inline]];
    if (unwrapVLQ(size) != 0) {
        UnpackerEntry unpackerEntries[while(!std::mem::reached(addressof(this)+unwrapVLQ(size)))];
    }
};

fn unpackData(auto unpackerEntries, auto pattern, std::mem::Section dest) {
    bool unpacked = false;
    std::mem::copy_value_to_section(pattern, dest, 0);
    for (u32 i = 0, i < sizeof(unpackerEntries)/sizeof(UnpackerEntry), i += 1) {
        if (unpackerEntries[i].unpackerID.typeID == StandardTypeID::Standard) {
            if (unpackerEntries[i].unpackerID.standardUnpackerID == StandardUnpackerID::None) {
                continue;
            } else if (unpackerEntries[i].unpackerID.standardUnpackerID == StandardUnpackerID::ZLIB) {
                if (!hex::dec::zlib_decompress(dest, dest, 0)) {
                    std::error("Failed to decompress ZLIB data");
                }
                unpacked = true;
            } else {
                std::error("Unrecognized StandardUnpackerID");
            }
        } else {
            std::error("Unsupported UnpackerID");
        }
    }
    return unpacked;
};

// Node

using Node;
using NodeWithPadding;

struct NodeHeader {
    VLQ<"nodeSize"> nodeSize [[inline]];
    VLQ<"itemCount"> itemCount [[inline]];
    VLQ<"headerSize"> headerSize [[inline]];
    NodeMetaData nodeMetadata;
    NodeUnpackers nodeUnpackers;
};

struct NodeContents {
    ReferenceTypeID typeID;
    if (unwrapVLQ(parent.header.itemCount) > 0) {
        if (typeID == ReferenceTypeID::InlineResource) {
            NodeWithPadding children[unwrapVLQ(parent.header.itemCount)];
        } else if (typeID == ReferenceTypeID::InFileResource) {
            VLQPointerToArray<"pointerToChildren", NodeWithPadding, unwrapVLQ(parent.header.itemCount)> pointerToChildren [[inline]];
        } else if (typeID == ReferenceTypeID::InFileNode) {
            VLQPointer<"pointerToFolderNode", Node> pointerToFolderNode [[inline]];
        } else {
            std::error("Unrecognized or invalid ReferenceTypeID for FolderNode");
        }
    } else {
        if (typeID == ReferenceTypeID::InlineResource) {
            char data[unwrapVLQ(parent.header.nodeSize)-($-addressof(parent))];
            if (unwrapVLQ(parent.header.nodeUnpackers.size) != 0) {
                try {
                    std::mem::Section unpacked = std::mem::create_section("Unpacked");
                    if (unpackData(parent.header.nodeUnpackers.unpackerEntries, data, unpacked)) {
                        char unpackedData[std::mem::get_section_size(unpacked)] @ 0x00 in unpacked;
                    }
                } catch {
                    std::warning("Something unexpected happened while unpacking data");
                }
            }
        } else if (typeID == ReferenceTypeID::InFileResource) {
            VLQ<"pointerToData"> pointerToData [[inline]];
        } else if (typeID == ReferenceTypeID::InFileNode) {
            VLQPointer<"pointerToFileNode", Node> pointerToFileNode [[inline]];
        } else if (typeID == ReferenceTypeID::ExternalResourceFile || typeID == ReferenceTypeID::XMFURI) {
            XString externalURI;
        } else if (typeID == ReferenceTypeID::XMFURIAndNodeID) {
            XString uri; // nullable
            VLQ<"nodeID"> nodeID [[inline]];
        } else {
            std::error("Unrecognized ReferenceTypeID");
        }
    }
};

struct Node {
    NodeHeader header;
    padding[unwrapVLQ(header.headerSize)-sizeof(header)];
    NodeContents content;
};

struct NodeWithPadding {
    Node node;
    padding[unwrapVLQ(node.header.nodeSize)-sizeof(node)];
};

// File

struct FileHeader {
    FileID fileID;
    XMFMetaFileVersion fileVer;
    if (fileVer == XMFMetaFileVersion::v2) {
        u32 fileTypeID;
        u32 fileTypeRevisionID;
    }
    VLQ<"fileSize"> fileSize [[inline]];
    MetaDataTypesTable metadataTypesTable;
    VLQ<"treeStart"> treeStart [[inline]];
    VLQ<"treeEnd"> treeEnd [[inline]];
};

FileHeader fileHeader @ 0x00;
Node tree @ unwrapVLQ(fileHeader.treeStart);