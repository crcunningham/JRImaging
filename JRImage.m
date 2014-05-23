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

#import "JRImage.h"

#import <ImageIO/ImageIO.h>
#import "JRAutoreleaseUtility.h"

#define PIN(X, A, B) ((X) < (A) ? (A) : ((X) > (B) ? (B) : (X)))

#if !TARGET_OS_IPHONE

static inline NSCompositingOperation CompositeOpForBlendMode(CGBlendMode mode)
{
    switch (mode) {
            
        case kCGBlendModeClear:
            return NSCompositeClear;
        case kCGBlendModeCopy:
            return NSCompositeCopy;
        case kCGBlendModeNormal:
            return NSCompositeSourceOver;
        case kCGBlendModeSourceIn:
            return NSCompositeSourceIn;
        case kCGBlendModeSourceOut:
            return NSCompositeSourceOut;
        case kCGBlendModeSourceAtop:
            return NSCompositeSourceAtop;
        case kCGBlendModeDestinationOver:
            return NSCompositeDestinationOver;
        case kCGBlendModeDestinationIn:
            return NSCompositeDestinationIn;
        case kCGBlendModeDestinationOut:
            return NSCompositeDestinationOut;
        case kCGBlendModeDestinationAtop:
            return NSCompositeDestinationAtop;
        case kCGBlendModeXOR:
            return NSCompositeXOR;
        case kCGBlendModePlusDarker:
            return NSCompositePlusDarker;
        case kCGBlendModePlusLighter:
            return NSCompositePlusLighter;
        default:
            return NSCompositeSourceOver;
    }
}
#endif

@interface JRImage ()

@end

@implementation JRImage

#if !TARGET_OS_IPHONE
@synthesize orientation = _orientation;
#endif

#if TARGET_OS_IPHONE
+ (JRImage *)imageWithUIImage:(UIImage*)image {
	return [[JRImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:(JRImageOrientation)image.imageOrientation];
}
#endif

- (id)initWithCGImage:(CGImageRef)cgImage scale:(CGFloat)scale orientation:(JRImageOrientation)orientation {
#if TARGET_OS_IPHONE
	self = [super initWithCGImage:cgImage scale:scale orientation:(JRImageOrientation)orientation];
	if (self) {
		
	}
	return self;
#else
	if(scale == 0.0) {
		scale = 1.0;
	}
	NSSize size = NSMakeSize(CGImageGetWidth(cgImage)/scale , CGImageGetHeight(cgImage)/scale);
	self = [self initWithCGImage:cgImage size:size];
	if (self) {
		if(orientation!=JRImageOrientationUp) {
			// TODO: Reorient!
			NSLog(@"do we need to handle this?");
		}
		_orientation = orientation;
	}
	return self;
#endif
}

- (JRImageOrientation)orientation {
#if TARGET_OS_IPHONE
	return (JRImageOrientation)super.imageOrientation;
#else
	@synchronized(self) {
		return _orientation;
	}
#endif
}

#if !TARGET_OS_IPHONE
- (void)drawInRect:(CGRect)rect blendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha {
	[self drawInRect:NSRectFromCGRect(rect) fromRect:NSZeroRect operation:CompositeOpForBlendMode(blendMode) fraction:alpha];
}

- (CGImageRef)CGImage {
    CGImageRef result = nil;
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)self.TIFFRepresentation, NULL);
    if (source) {
        result = CGImageSourceCreateImageAtIndex(source, 0, NULL);
        CFRelease(source);
    }
    return JRAutoreleaseImage(result);
}

#endif

@end

NSData* JRImageJPEGRepresentation(JRImage *image, CGFloat compressionQuality) {
    CGImageRef imageRef = image.CGImage;
    
    if (!imageRef) {
        NSLog(@"nil image ref!");
		return nil;
    }
	
    NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
    
    // resolution
    CGFloat scale = image.scale;
    if (scale != 1.0 && scale > 0.001) {
		CGFloat dpi = 72.0f * scale;
		properties[(id)kCGImagePropertyDPIWidth] = @(dpi);
        properties[(id)kCGImagePropertyDPIHeight] = @(dpi);
    }
    
    // compression
    compressionQuality = PIN(compressionQuality, 0.0, 1.0);    // pin compression to 0..1
    properties[(id)kCGImageDestinationLossyCompressionQuality] = @(compressionQuality);
    
    //  orientation
    NSInteger exifOrientation;
    switch (image.orientation) {
		case JRImageOrientationUp: exifOrientation = 1; break;
		case JRImageOrientationDown: exifOrientation = 3; break;
		case JRImageOrientationLeft: exifOrientation = 8; break;
		case JRImageOrientationRight: exifOrientation = 6; break;
		case JRImageOrientationUpMirrored: exifOrientation = 2; break;
		case JRImageOrientationDownMirrored: exifOrientation = 4; break;
		case JRImageOrientationLeftMirrored: exifOrientation = 5; break;
		case JRImageOrientationRightMirrored:  exifOrientation = 7; break;
    }
    properties[(id)kCGImagePropertyOrientation] = @(exifOrientation);
	
    // create storage
    bool success = NO;
    NSMutableData* data = [[NSMutableData alloc] init];
    if (data) {
        // write out image
        //
        CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data,
                                                                                  CFSTR("public.jpeg"),
                                                                                  1,
                                                                                  nil);
        if (imageDestination) {
            CGImageDestinationAddImage(imageDestination, imageRef, (__bridge CFDictionaryRef)(properties));
            success = CGImageDestinationFinalize(imageDestination);
            CFRelease(imageDestination);
        }
    }
    
    return success ? data : nil;
}

