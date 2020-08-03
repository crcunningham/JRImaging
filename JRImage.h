// The MIT License (MIT)
//
// Copyright (c) 2014 Chris Cunningham
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.


#import <TargetConditionals.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
 
typedef NS_ENUM(NSInteger, JRImageOrientation){
    JRImageOrientationUp, // default orientation
    JRImageOrientationDown, // 180 deg rotation
    JRImageOrientationLeft, // 90 deg CCW
    JRImageOrientationRight, // 90 deg CW
    JRImageOrientationUpMirrored, // as above but image mirrored along other axis. horizontal flip
    JRImageOrientationDownMirrored, // horizontal flip
    JRImageOrientationLeftMirrored, // vertical flip
    JRImageOrientationRightMirrored, // vertical flip
};

#if TARGET_OS_IPHONE
@interface JRImage : UIImage
#else
@interface JRImage : NSImage
#endif

#if TARGET_OS_IPHONE
+ (JRImage*)imageWithUIImage:(UIImage*)image;
#endif

- (id)initWithCGImage:(CGImageRef)cgImage scale:(CGFloat)scale orientation:(JRImageOrientation)orientation;

#if !TARGET_OS_IPHONE
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, readonly) CGImageRef CGImage;
- (CGImageRef)CGImage NS_RETURNS_INNER_POINTER;
#endif
@property (readonly) JRImageOrientation orientation;

#if !TARGET_OS_IPHONE
- (void)drawInRect:(CGRect)rect blendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha;
#endif

@end

NSData* JRImageJPEGRepresentation(JRImage* image, CGFloat compressionQuality);
