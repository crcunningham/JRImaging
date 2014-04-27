JRImaging
==============

Imaging code for iOS and OSX

JRAutoreleaseUtility - A non-arc utility required by JRImage, compile it with the '-fno-objc-arc' flag
JRImage - An image class that works on both iOS and OSX

```
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
```

JRImageFactory - Utilities for loading images on the GPU with edge bounding as well as some metadata extraction functions

```
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
```

