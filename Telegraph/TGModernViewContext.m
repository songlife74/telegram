#import "TGModernViewContext.h"

@implementation TGModernViewContext

- (bool)isMediaVisibleInMessage:(int32_t)__unused messageId
{
    return true;
}

- (bool)isMessageChecked:(int32_t)__unused messageId
{
    return false;
}

- (bool)isSecretMessageViewed:(int32_t)__unused messageId
{
    return false;
}

- (bool)isSecretMessageScreenshotted:(int32_t)__unused messageId
{
    return false;
}

- (TGModernViewInlineMediaContext *)inlineMediaContext:(int32_t)__unused messageId
{
    return nil;
}

@end
