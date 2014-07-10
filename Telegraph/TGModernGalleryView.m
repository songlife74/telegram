/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGModernGalleryView.h"

@implementation TGModernGalleryView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.opaque = false;
    }
    return self;
}

- (void)setFrame:(CGRect)frame
{
    static CGSize screenSize;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        screenSize = [UIScreen mainScreen].bounds.size;
    });
    
    frame.origin = CGPointZero;
    
    if (ABS(frame.size.width - screenSize.width) < FLT_EPSILON)
        frame.size.height = screenSize.height;
    else if (ABS(frame.size.width - screenSize.height) < FLT_EPSILON)
        frame.size.height = screenSize.width;
    
    [super setFrame:frame];
}

- (void)setCenter:(CGPoint)center
{
    static CGSize screenSize;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        screenSize = [UIScreen mainScreen].bounds.size;
    });
    
    if (ABS(center.x - screenSize.width / 2.0f) < FLT_EPSILON)
        center.y = screenSize.height / 2.0f;
    else if (ABS(center.x - screenSize.height / 2.0f) < FLT_EPSILON)
        center.y = screenSize.width / 2.0f;
    
    [super setCenter:center];
}

- (void)setBounds:(CGRect)bounds
{
    static CGSize screenSize;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        screenSize = [UIScreen mainScreen].bounds.size;
    });
    
    if (ABS(bounds.size.width - screenSize.width) < FLT_EPSILON)
        bounds.size.height = screenSize.height;
    else if (ABS(bounds.size.width - screenSize.height) < FLT_EPSILON)
        bounds.size.height = screenSize.width;
    
    [super setBounds:bounds];
}

@end
