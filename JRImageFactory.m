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

#import "JRImageFactory.h"

#import <sys/sysctl.h>
#import <libkern/OSAtomic.h>
#import "JRImage.h"

@implementation JRImageFactory

static NSString* UTIFromExtension(NSString* extension){
	NSString* result = nil;
	
	for (NSString* type in [NSArray arrayWithObjects : (id)kUTTypeImage, (id)kUTTypeMovie, nil]) {
		CFStringRef string = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)extension, (__bridge CFStringRef)type);
		
		if (string) {
			result = [[NSString alloc] initWithString:(__bridge NSString*)string];
			CFRelease(string);
			break;
		}
	}
	
	return result;
}

+ (CGSize)loadableImageSizeForImageSize:(CGSize)size{
	CGSize result;
	
	// The max edge that will be in memory is 2x edgeBound
	NSUInteger longEdgeMax = 5000;
	NSUInteger pixels = (NSUInteger)(size.width * size.height);
	
	CGFloat factor = 1;
	
	while (pixels > (longEdgeMax * longEdgeMax)) {
		factor *= 2;
		pixels = (NSUInteger)(size.width / factor * size.height / factor);
	}
	
	// BUG: What if we create a non-integral size? floor? ceil? round?
	result = CGSizeMake(size.width / factor, size.height / factor);
	return result;
}

+ (JRImage *)imageFromData:(NSData *)data uti:(NSString*)imageUti maxEdge:(NSInteger)maxEdge cache:(BOOL)cacheImage{
	if (!data) {
		return nil;
	}
	if (!imageUti) {
		imageUti = (NSString*)kUTTypeJPEG;
	}
	
	JRImage *result = nil;
	    
	@autoreleasepool {
		NSMutableDictionary* options = [[NSMutableDictionary alloc] init];
		options[(id)kCGImageSourceTypeIdentifierHint] = imageUti;
		options[(id)kCGImageSourceCreateThumbnailFromImageAlways] = (id)kCFBooleanTrue;
		options[(id)kCGImageSourceCreateThumbnailWithTransform] = (id)kCFBooleanTrue;
		
		if (cacheImage) {
			options[(id)kCGImageSourceShouldCache] = (id)kCFBooleanTrue;
		}
		else {
			options[(id)kCGImageSourceShouldCache] = (id)kCFBooleanFalse;
		}
		
		CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)(data), (__bridge CFDictionaryRef)(options));
		
		if (source) {
			CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil);
			
			if (properties) {
				NSUInteger width = [((__bridge NSDictionary *)properties)[(id)kCGImagePropertyPixelWidth] unsignedIntegerValue];
				NSUInteger height = [((__bridge NSDictionary *)properties)[(id)kCGImagePropertyPixelHeight] unsignedIntegerValue];
				
				CGSize loadableImageSize = [JRImageFactory loadableImageSizeForImageSize:CGSizeMake(width, height)];
				NSInteger calculatedMaxEdge = (NSInteger)MAX(loadableImageSize.width, loadableImageSize.height);
				
				if (maxEdge > 0) {
					calculatedMaxEdge = MIN(maxEdge, calculatedMaxEdge);
				}
				
				options[(id)kCGImageSourceThumbnailMaxPixelSize] = @(calculatedMaxEdge);
				
				// automatically subsamples if necessary
				CGImageRef image = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
                result = [[JRImage alloc] initWithCGImage:image scale:1.0 orientation:JRImageOrientationUp];
                CGImageRelease(image);
				CFRelease(properties);
			}

			CFRelease(source);
		}
	}
	
	return result;
}

+ (JRImage *)imageFromPath:(NSString*)path maxEdge:(NSInteger)edge cache:(BOOL)cache{
	JRImage *result = nil;
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
		NSData *data = [[NSData alloc] initWithContentsOfFile:path];
		NSString *uti = UTIFromExtension([path pathExtension]);
		result = [JRImageFactory imageFromData:data uti:uti maxEdge:edge cache:cache];
	}
	
	return result;
}

+ (JRImage *)scaledImageFromImage:(JRImage *)image maxEdge:(NSUInteger)edge{
	JRImage *result = image;
	CGSize initialSize = image.size;
	CGSize scaledSize;
	
	if (!MAX(initialSize.width, initialSize.height) < edge) {
		CGFloat ratio;
		
		if (initialSize.width > initialSize.height) {
			ratio = edge / initialSize.width;
        } else {
			ratio = edge / initialSize.height;
        }
		
		scaledSize = CGSizeMake((CGFloat)floor(initialSize.width * ratio), (CGFloat)floor((initialSize.height * ratio)));
		
#if TARGET_OS_IPHONE
		UIGraphicsBeginImageContextWithOptions(scaledSize, YES, 1.0);
		[image drawInRect:CGRectMake(0.0, 0.0, scaledSize.width, scaledSize.height)];
		result = [JRImage imageWithUIImage:UIGraphicsGetImageFromCurrentImageContext()];
		UIGraphicsEndImageContext();
#else
		NSImage* newImage = [[NSImage alloc] initWithSize:scaledSize];
		
		[newImage lockFocus];
		NSRect thumbnailRect = NSMakeRect(0.0, 0.0, scaledSize.width, scaledSize.height);
		[image drawInRect:thumbnailRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];		
		[newImage unlockFocus];
#endif
	}
	
	return result;
}

+ (NSTimeInterval)creationTimestampFromMetadata:(NSDictionary *)metadata{
	NSTimeInterval result = 0;
	NSDate* date = nil;
	
	@autoreleasepool {
		NSString* dateString = nil;
		NSString* dateSubseconds = nil;
		
		// first try the exif
		NSDictionary * exif = metadata[(id)kCGImagePropertyExifDictionary];
		if (exif) {
			dateString = exif[(id)kCGImagePropertyExifDateTimeOriginal];
			dateSubseconds = exif[(id)kCGImagePropertyExifSubsecTimeOriginal];
			
			if (!dateString) {
				dateString = exif[(id)kCGImagePropertyExifDateTimeDigitized];
				dateSubseconds = exif[(id)kCGImagePropertyExifSubsecTimeDigitized];
			}
		}
		
		// next, try tiff
		if (!dateString) {
			NSDictionary *tiff = metadata[(id)kCGImagePropertyTIFFDictionary];
			dateString = tiff[(id)kCGImagePropertyTIFFDateTime];
		}
		
        // date format: YYYY:MM:DD:hh:mm:ss
		if ([dateString length] < 1 || [dateString hasPrefix:@"0000"]) {
			// nothing we can do
		} else {
			NSCalendar* calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
			NSDateComponents* components = [[NSDateComponents alloc] init];
			int year, month, day, hour, minute, second;
			sscanf([dateString UTF8String], "%d%*c%d%*c%d%*c%d%*c%d%*c%d", &year, &month, &day, &hour, &minute, &second);
			[components setYear:year];
			[components setMonth:month];
			[components setDay:day];
			[components setHour:hour];
			[components setMinute:minute];
			[components setSecond:second];
			[components setTimeZone:[NSTimeZone localTimeZone]];
			date = [calendar dateFromComponents:components];
		}
		
		if (date) {
			if (dateSubseconds) {
				CGFloat subseconds = (CGFloat)[dateSubseconds doubleValue];
				if (subseconds > 0 && subseconds < 1.0) {
					date = [date dateByAddingTimeInterval:subseconds];
				}
			}
		}
		
		result = [date timeIntervalSinceReferenceDate];
	}
	
	return result;
}

+ (CGPoint)locationFromMetadata:(NSDictionary *)metadata {
	CGPoint result = CGPointMake(CGFLOAT_MAX, CGFLOAT_MAX);
	NSDictionary * gps = metadata[(id)kCGImagePropertyGPSDictionary];
	
	if (gps) {
		NSNumber* latitude = gps[(id)kCGImagePropertyGPSLatitude];
		NSNumber* longitude = gps[(id)kCGImagePropertyGPSLongitude];
		NSString* latRef = gps[(id)kCGImagePropertyGPSLatitudeRef];
		NSString* longRef = gps[(id)kCGImagePropertyGPSLongitudeRef];
		
		if (latitude && longitude) {
			CGFloat la = [latRef isEqualToString:@"S"] ? -[latitude floatValue] : [latitude floatValue];
			CGFloat lo = [longRef isEqualToString:@"W"] ? -[longitude floatValue] : [longitude floatValue];
			result = CGPointMake(la, lo);
		}
	}
	
	return result;
}

+ (CGSize)sizeFromMetadata:(NSDictionary *)metadata{
    NSUInteger width = [metadata[(id)kCGImagePropertyPixelWidth] unsignedIntegerValue];
    NSUInteger height = [metadata[(id)kCGImagePropertyPixelHeight] unsignedIntegerValue];
    return CGSizeMake(width, height);
}

+ (NSDictionary *)metadataFromData:(NSData *)data uti:(NSString *)uti{
    if (!uti) {
        uti = (id)kUTTypeJPEG;
    }
    
    NSDictionary * options = @{(id)kCGImageSourceTypeIdentifierHint : uti, (id)kCGImageSourceShouldCache : @NO};
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, (__bridge CFDictionaryRef)options);
    
    if (source) {
        CFDictionaryRef metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil);
        CFRelease(source);
        return CFBridgingRelease(metadata);
    }
    return nil;
}

@end
