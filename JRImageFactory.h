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

#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <TargetConditionals.h>

#if TARGET_OS_IPHONE
#import <MobileCoreServices/MobileCoreServices.h>
#else
#import <CoreServices/CoreServices.h>
#endif

@class JRImage;

@interface JRImageFactory : NSObject

// loads an image from the given data
//	* cacheImage sets kCGImageSourceShouldCache appropriately
//	* If no UTI is given jpeg is assumed
//	* If edge <= 0 we set the maximum loadable size
+ (JRImage *)imageFromData:(NSData *)data uti:(NSString *)uti maxEdge:(NSInteger)edge cache:(BOOL)cacheImage;

+ (CGSize)loadableImageSizeForImageSize:(CGSize)size;

// convience wrapper for imageFromData:uti:maxEdge:cache where we load the data for you
+ (JRImage *)imageFromPath:(NSString*)path maxEdge:(NSInteger)edge cache:(BOOL)cache;

// scales the image so that its longest edge is <= maxEdge
+ (JRImage *)scaledImageFromImage:(JRImage *)image maxEdge:(NSUInteger)edge;

// pulls the image creation data from the metadata dictionary if it exists
+ (NSTimeInterval)creationTimestampFromMetadata:(NSDictionary *)metadata;

// returns the GPS point for the metadata or {CGFLOAT_MAX, CGFLOAT_MAX} if there is no GPS data
+ (CGPoint)locationFromMetadata:(NSDictionary *)metadata;

// returns the image size for the metadata or CGSizeZero if there is no size
+ (CGSize)sizeFromMetadata:(NSDictionary *)metadata;

// pull out the metadata dictionary
+ (NSDictionary *)metadataFromData:(NSData *)data uti:(NSString *)uti;
+ (NSDictionary *)metadataFromUrl:(NSURL *)url uti:(NSString *)uti;

@end
