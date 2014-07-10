#import "PSKeyValueDecoder.h"

#import <objc/runtime.h>

@interface PSKeyValueDecoder ()
{
    NSData *_data;
 
@public
    uint8_t const *_currentPtr;
    uint8_t const *_begin;
    uint8_t const *_end;
    
    PSKeyValueDecoder *_tempCoder;
}

@end

static inline uint32_t readLength(uint8_t const **currentPtr)
{
    uint32_t result = 0;
    
    result |= (*(*currentPtr)) & 127;
    
    if ((*(*currentPtr)) & 128)
    {
        (*currentPtr)++;
        result |= ((*(*currentPtr)) & 127) << (7 * 1);
        
        if ((*(*currentPtr)) & 128)
        {
            (*currentPtr)++;
            result |= ((*(*currentPtr)) & 127) << (7 * 2);
            
            if ((*(*currentPtr)) & 128)
            {
                (*currentPtr)++;
                result |= ((*(*currentPtr)) & 127) << (7 * 3);
                
                if ((*(*currentPtr)) & 128)
                {
                    (*currentPtr)++;
                    result |= ((*(*currentPtr)) & 127) << (7 * 4);
                }
            }
        }
    }
    
    (*currentPtr)++;
    
    return result;
}

static inline NSString *readString(uint8_t const **currentPtr)
{
    uint32_t stringLength = readLength(currentPtr);
    
    NSString *string = [[NSString alloc] initWithBytes:*currentPtr length:stringLength encoding:NSUTF8StringEncoding];
    (*currentPtr) += stringLength;
    return string;
}

static inline void skipString(uint8_t const **currentPtr)
{
    uint32_t stringLength = readLength(currentPtr);
    (*currentPtr) += stringLength;
}

static inline int32_t readInt32(uint8_t const **currentPtr)
{
    int32_t number = *((int32_t *)(*currentPtr));
    (*currentPtr) += 4;
    return number;
}

static inline void skipInt32(uint8_t const **currentPtr)
{
    (*currentPtr) += 4;
}

static inline int64_t readInt64(uint8_t const **currentPtr)
{
    int64_t number = *((int64_t *)(*currentPtr));
    (*currentPtr) += 8;
    return number;
}

static inline void skipInt64(uint8_t const **currentPtr)
{
    (*currentPtr) += 8;
}

static inline id<PSCoding> readObject(uint8_t const **currentPtr, PSKeyValueDecoder *tempCoder)
{
    uint32_t objectLength = *((uint32_t *)(*currentPtr));
    (*currentPtr) += 4;
    
    uint8_t const *objectEnd = (*currentPtr) + objectLength;

    const char *className = (const char *)(*currentPtr);
    NSUInteger classNameLength = strlen(className) + 1;
    (*currentPtr) += classNameLength;
    
    id<PSCoding> object = nil;
    
    Class<PSCoding> objectClass = objc_getClass(className);
    if (objectClass != nil)
    {
        tempCoder->_begin = *currentPtr;
        tempCoder->_end = objectEnd;
        tempCoder->_currentPtr = tempCoder->_begin;
        
        object = [(id<PSCoding>)[(id)objectClass alloc] initWithKeyValueCoder:tempCoder];
    }

    *currentPtr = objectEnd;
    
    return object;
}

static inline void skipObject(uint8_t const **currentPtr)
{
    uint32_t objectLength = *((uint32_t *)currentPtr);
    (*currentPtr) += 4 + objectLength;
}

static inline NSArray *readArray(uint8_t const **currentPtr, PSKeyValueDecoder *tempCoder)
{
    uint32_t objectLength = *((uint32_t *)(*currentPtr));
    (*currentPtr) += 4;
    
    uint8_t const *objectEnd = (*currentPtr) + objectLength;
    
    uint32_t count = readLength(currentPtr);
    
    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:count];
    
    for (uint32_t i = 0; i < count; i++)
    {
        id<PSCoding> object = readObject(currentPtr, tempCoder);
        if (object != nil)
            [array addObject:object];
    }
    
    *currentPtr = objectEnd;
    
    return array;
}

static void skipArray(uint8_t const **currentPtr)
{
    uint32_t objectLength = *((uint32_t *)currentPtr);
    (*currentPtr) += 4 + objectLength;
}

static inline void skipField(uint8_t const **currentPtr)
{
    uint8_t fieldType = *(*currentPtr);
    (*currentPtr)++;
    
    switch (fieldType)
    {
        case PSKeyValueCoderFieldTypeString:
        {
            skipString(currentPtr);
            break;
        }
        case PSKeyValueCoderFieldTypeInt32:
        {
            skipInt32(currentPtr);
            break;
        }
        case PSKeyValueCoderFieldTypeInt64:
        {
            skipInt64(currentPtr);
            break;
        }
        case PSKeyValueCoderFieldTypeCustomClass:
        {
            skipObject(currentPtr);
            break;
        }
        case PSKeyValueCoderFieldTypeArray:
        {
            skipArray(currentPtr);
            break;
        }
        default:
            break;
    }
}

@implementation PSKeyValueDecoder

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        
    }
    return self;
}

- (instancetype)initWithData:(NSData *)data
{
    self = [super init];
    if (self != nil)
    {
        _data = data;
        
        _begin = (uint8_t const *)[_data bytes];
        _end = _begin + [_data length];
        _currentPtr = _begin;
    }
    return self;
}

- (void)resetData:(NSData *)data
{
    _data = data;
    
    _begin = (uint8_t const *)[_data bytes];
    _end = _begin + [_data length];
    _currentPtr = _begin;
}

- (void)resetBytes:(uint8_t const *)bytes length:(NSUInteger)length
{
    _data = nil;
    
    _begin = bytes;
    _end = _begin + length;
    _currentPtr = _begin;
}

static bool skipToValueForRawKey(PSKeyValueDecoder *self, uint8_t const *key, NSUInteger keyLength)
{
    uint8_t const *middlePtr = self->_currentPtr;
    
    for (int i = 0; i < 2; i++)
    {
        uint8_t const *scanEnd = self->_end;
        
        if (i == 1)
        {
            self->_currentPtr = self->_begin;
            scanEnd = middlePtr;
        }
        
        while (self->_currentPtr < scanEnd)
        {
            uint32_t compareKeyLength = readLength(&self->_currentPtr);
            
            if (compareKeyLength != keyLength || memcmp(key, self->_currentPtr, keyLength))
            {
                self->_currentPtr += compareKeyLength;
                skipField(&self->_currentPtr);
                
                continue;
            }
            
            self->_currentPtr += compareKeyLength;
            
            return true;
        }
    }
    
    return false;
}

static NSString *decodeStringForRawKey(PSKeyValueDecoder *self, uint8_t const *key, NSUInteger keyLength)
{
    if (skipToValueForRawKey(self, key, keyLength))
    {
        uint8_t fieldType = *self->_currentPtr;
        self->_currentPtr++;
        
        if (fieldType == PSKeyValueCoderFieldTypeString)
            return readString(&self->_currentPtr);
        else if (fieldType == PSKeyValueCoderFieldTypeInt32)
            return [[NSString alloc] initWithFormat:@"%" PRId32 "", readInt32(&self->_currentPtr)];
        else if (fieldType == PSKeyValueCoderFieldTypeInt64)
            return [[NSString alloc] initWithFormat:@"%" PRId64 "", readInt64(&self->_currentPtr)];
        else
        {
            skipField(&self->_currentPtr);
            
            return nil;
        }
    }
    
    return nil;
}

- (NSString *)decodeStringForKey:(NSString *)key
{
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    return decodeStringForRawKey(self, (uint8_t const *)[keyData bytes], [keyData length]);
}

- (NSString *)decodeStringForCKey:(const char *)key
{
    return decodeStringForRawKey(self, (uint8_t const *)key, (NSUInteger)strlen(key));
}

static int32_t decodeInt32ForRawKey(PSKeyValueDecoder *self, uint8_t const *key, NSUInteger keyLength)
{
    if (skipToValueForRawKey(self, key, keyLength))
    {
        uint8_t fieldType = *self->_currentPtr;
        self->_currentPtr++;
        
        if (fieldType == PSKeyValueCoderFieldTypeString)
            return (int32_t)[readString(&self->_currentPtr) intValue];
        else if (fieldType == PSKeyValueCoderFieldTypeInt32)
            return readInt32(&self->_currentPtr);
        else if (fieldType == PSKeyValueCoderFieldTypeInt64)
            return (int32_t)readInt64(&self->_currentPtr);
        else
        {
            skipField(&self->_currentPtr);
            
            return 0;
        }
    }
    
    return 0;
}

- (int32_t)decodeInt32ForKey:(NSString *)key
{
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    return decodeInt32ForRawKey(self, (uint8_t const *)[keyData bytes], [keyData length]);
}

- (int32_t)decodeInt32ForCKey:(const char *)key
{
    return decodeInt32ForRawKey(self, (uint8_t const *)key, strlen(key));
}

static int64_t decodeInt64ForRawKey(PSKeyValueDecoder *self, uint8_t const *key, NSUInteger keyLength)
{
    if (skipToValueForRawKey(self, key, keyLength))
    {
        uint8_t fieldType = *self->_currentPtr;
        self->_currentPtr++;
        
        if (fieldType == PSKeyValueCoderFieldTypeString)
            return (int64_t)[readString(&self->_currentPtr) longLongValue];
        else if (fieldType == PSKeyValueCoderFieldTypeInt32)
            return readInt32(&self->_currentPtr);
        else if (fieldType == PSKeyValueCoderFieldTypeInt64)
            return readInt64(&self->_currentPtr);
        else
        {
            skipField(&self->_currentPtr);
            return 0;
        }
    }
    
    return 0;
}

- (int64_t)decodeInt64ForKey:(NSString *)key
{
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    return decodeInt64ForRawKey(self, (uint8_t const *)[keyData bytes], [keyData length]);
}

- (int64_t)decodeInt64ForCKey:(const char *)key
{
    return decodeInt64ForRawKey(self, (uint8_t const *)key, strlen(key));
}

static id<PSCoding> decodeObjectForRawKey(PSKeyValueDecoder *self, uint8_t const *key, NSUInteger keyLength)
{
    if (skipToValueForRawKey(self, key, keyLength))
    {
        uint8_t fieldType = *self->_currentPtr;
        self->_currentPtr++;
        
        if (fieldType == PSKeyValueCoderFieldTypeCustomClass)
        {
            if (self->_tempCoder == nil)
                self->_tempCoder = [[PSKeyValueDecoder alloc] init];
            return readObject(&self->_currentPtr, self->_tempCoder);
        }
        else
        {
            skipField(&self->_currentPtr);
            
            return nil;
        }
    }
    
    return nil;
}

- (id<PSCoding>)decodeObjectForKey:(NSString *)key
{
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    return decodeObjectForRawKey(self, (uint8_t const *)[keyData bytes], [keyData length]);
}

- (id<PSCoding>)decodeObjectForCKey:(const char *)key
{
    return decodeObjectForRawKey(self, (uint8_t const *)key, strlen(key));
}

static NSArray *decodeArrayForRawKey(PSKeyValueDecoder *self, uint8_t const *key, NSUInteger keyLength)
{
    if (skipToValueForRawKey(self, key, keyLength))
    {
        uint8_t fieldType = *self->_currentPtr;
        self->_currentPtr++;
        
        if (fieldType == PSKeyValueCoderFieldTypeArray)
        {
            if (self->_tempCoder == nil)
                self->_tempCoder = [[PSKeyValueDecoder alloc] init];
            return readArray(&self->_currentPtr, self->_tempCoder);
        }
        else
        {
            skipField(&self->_currentPtr);
            
            return nil;
        }
    }
    
    return nil;
}

- (NSArray *)decodeArrayForKey:(NSString *)key
{
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    return decodeArrayForRawKey(self, (uint8_t const *)[keyData bytes], [keyData length]);
}

- (NSArray *)decodeArrayForCKey:(const char *)key
{
    return decodeArrayForRawKey(self, (uint8_t const *)key, strlen(key));
}

@end
