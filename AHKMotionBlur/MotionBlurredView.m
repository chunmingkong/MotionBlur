//
//  MotionBlurredView.m
//  AHKMotionBlur
//
//  Created by Arkadiusz on 01-07-14.
//  Copyright (c) 2014 Arkadiusz Holko. All rights reserved.
//

#import "MotionBlurredView.h"
#import "MotionBlurFilter.h"

@interface MotionBlurredLayer()

//@property (nonatomic, strong) UIImage *blurredImage;
@property (nonatomic, weak) CALayer *blurLayer;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic) CGPoint lastPosition;

@end

@implementation MotionBlurredLayer

- (void)prepareBlur
{
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, 0.0f);
    CGContextRef graphicsContext = UIGraphicsGetCurrentContext();
    CGContextFillRect(graphicsContext, self.bounds);

    // good explanation of differences between drawViewHierarchyInRect:afterScreenUpdates: and renderInContext: https://github.com/radi/LiveFrost/issues/10#issuecomment-28959525
    [self renderInContext:graphicsContext];
    UIImage *snapshotImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CIContext *context = [CIContext contextWithOptions:nil];               // 1
        CIImage *inputImage = [CIImage imageWithCGImage:snapshotImage.CGImage];

        MotionBlurFilter *adjustmentFilter = [[MotionBlurFilter alloc] init];
        [adjustmentFilter setDefaults];
        adjustmentFilter.inputImage = inputImage;

        CIImage *outputImage = [adjustmentFilter valueForKey:@"outputImage"];

        // back to UIImage
        CGImageRef blurredImgRef = [context createCGImage:outputImage fromRect:outputImage.extent] ;
        UIImage *blurredImage = [[UIImage alloc] initWithCGImage:blurredImgRef scale:2.0 orientation:UIImageOrientationUp];
//        self.blurredImage = blurredImage;
        NSLog(@"-prepareBlur completed");

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.blurLayer removeFromSuperlayer];

            CALayer *blurLayer = [[CALayer alloc] init];
            blurLayer.contents = (__bridge id)(blurredImage.CGImage);
            blurLayer.opaque = NO;
            blurLayer.opacity = 0.0f;
            blurLayer.backgroundColor = [UIColor clearColor].CGColor;

            CGSize difference = CGSizeMake(blurredImage.size.width - self.frame.size.width,
                                           blurredImage.size.height - self.frame.size.height);
            CGRect frame = CGRectZero;
            frame.origin = CGPointMake(-difference.width / 2, -difference.height / 2);
            frame.size = CGSizeMake(self.bounds.size.width + difference.width,
                                    self.bounds.size.height + difference.height);
            blurLayer.frame = frame;
            blurLayer.actions = @{
                                  @"opacity" : [NSNull null]
                                  };
            [self addSublayer:blurLayer];

            self.blurLayer = blurLayer;
            self.lastPosition = CGPointMake(FLT_MAX, FLT_MAX);
        });
    });
}

- (void)addAnimation:(CAAnimation *)anim forKey:(NSString *)key
{
    [super addAnimation:anim forKey:key];

    CAPropertyAnimation *animation = (CAPropertyAnimation *)anim;
    if ([animation respondsToSelector:@selector(keyPath)]) {
        if ([animation.keyPath isEqualToString:NSStringFromSelector(@selector(position))]) {
            [self.displayLink invalidate];
            self.displayLink = nil;

            self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
            [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        }
    }
}

- (void)tick:(CADisplayLink *)displayLink
{
    CGPoint realPosition = ((CALayer *)self.presentationLayer).position;

    // check if "undefined"
    if (self.lastPosition.x != FLT_MAX) {
        CGFloat dx = abs(self.lastPosition.x - realPosition.x);
        CGFloat dy = abs(self.lastPosition.y - realPosition.y);

        // TODO: dx is getting ignored

        CGFloat unboundedOpacity = log2(dy) / 4.0f;
        CGFloat opacity = fmax(fmin(unboundedOpacity, 1.0), 0.0);
        self.blurLayer.opacity = opacity;
//        NSLog(@"opacity: %f", opacity);

        if (!self.animationKeys || [self.animationKeys count] == 0) {
            [self.displayLink invalidate];
            self.displayLink = nil;
        }
    }


    self.lastPosition = realPosition;
}

@end

@interface MotionBlurredView()

@property (weak, nonatomic) UIImageView *blurImageView;

@end

@implementation MotionBlurredView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

+ (Class)layerClass
{
    return [MotionBlurredLayer class];
}

@end