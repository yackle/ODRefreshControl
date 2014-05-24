//
//  ODRefreshControl.m
//  ODRefreshControl
//
//  Created by Fabio Ritrovato on 6/13/12.
//  Copyright (c) 2012 orange in a day. All rights reserved.
//
// https://github.com/Sephiroth87/ODRefreshControl
//

#import "ODRefreshControl.h"

#define kTotalViewHeight    400
#define kOpenedViewHeight   44
#define kMinTopPadding      9
#define kMaxTopPadding      5
#define kMinTopRadius       6
#define kMaxTopRadius       10
#define kMinBottomRadius    1
#define kMaxBottomRadius    10
#define kMinBottomPadding   4
#define kMaxBottomPadding   6
#define kMinArrowSize       2
#define kMaxArrowSize       3
#define kMinArrowRadius     5
#define kMaxArrowRadius     7
#define kMaxDistance        53

@interface ODRefreshControl ()

@property (nonatomic, readwrite) BOOL refreshing;
@property (nonatomic, assign) UIScrollView *scrollView;
@property (nonatomic, assign) UIEdgeInsets originalContentInset;

@end

@implementation ODRefreshControl

@synthesize refreshing = _refreshing;
@synthesize tintColor = _tintColor;

@synthesize scrollView = _scrollView;
@synthesize originalContentInset = _originalContentInset;

static inline CGFloat lerp(CGFloat a, CGFloat b, CGFloat p)
{
    return a + (b - a) * p;
}

- (id)initInScrollView:(UIScrollView *)scrollView {
    return [self initInScrollView:scrollView activityIndicatorView:nil];
}

- (id)initInScrollView:(UIScrollView *)scrollView activityIndicatorView:(UIView *)activity
{
    self = [super initWithFrame:CGRectMake(0, -(kTotalViewHeight + scrollView.contentInset.top), scrollView.frame.size.width, kTotalViewHeight)];
    
    if (self) {
        self.scrollView = scrollView;
        self.originalContentInset = scrollView.contentInset;
        
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [scrollView addSubview:self];
        [scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
        [scrollView addObserver:self forKeyPath:@"contentInset" options:NSKeyValueObservingOptionNew context:nil];
        
        _activity = activity ? activity : [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _activity.center = CGPointMake(floor(self.frame.size.width / 2), floor(self.frame.size.height / 2));
        _activity.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _activity.alpha = 0;
        [self addSubview:_activity];
        
        _refreshing = NO;
        _canRefresh = YES;
        _ignoreInset = NO;
        _ignoreOffset = NO;
        _didSetInset = NO;
        _hasSectionHeaders = NO;
        _tintColor = [UIColor colorWithRed:155.0 / 255.0 green:162.0 / 255.0 blue:172.0 / 255.0 alpha:1.0];
        
        _shapeLayer = [CAShapeLayer layer];
        _shapeLayer.fillColor = [_tintColor CGColor];
        _shapeLayer.strokeColor = [[[UIColor darkGrayColor] colorWithAlphaComponent:0.5] CGColor];
        _shapeLayer.lineWidth = 0.5;
        [self.layer addSublayer:_shapeLayer];
        
        _arrowLayer = [CAShapeLayer layer];
        _arrowLayer.strokeColor = [[[UIColor darkGrayColor] colorWithAlphaComponent:0.5] CGColor];
        _arrowLayer.lineWidth = 0.5;
        _arrowLayer.fillColor = [[UIColor whiteColor] CGColor];
        [_shapeLayer addSublayer:_arrowLayer];
        
        _highlightLayer = [CAShapeLayer layer];
        _highlightLayer.fillColor = [[[UIColor whiteColor] colorWithAlphaComponent:0.2] CGColor];
        [_shapeLayer addSublayer:_highlightLayer];
    }
    return self;
}

- (void)dealloc
{
    [self.scrollView removeObserver:self forKeyPath:@"contentOffset"];
    [self.scrollView removeObserver:self forKeyPath:@"contentInset"];
    self.scrollView = nil;
}

- (void)setEnabled:(BOOL)enabled
{
    super.enabled = enabled;
    _shapeLayer.hidden = !self.enabled;
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    [super willMoveToSuperview:newSuperview];
    if (!newSuperview) {
        [self.scrollView removeObserver:self forKeyPath:@"contentOffset"];
        [self.scrollView removeObserver:self forKeyPath:@"contentInset"];
        self.scrollView = nil;
    }
}

- (void)setTintColor:(UIColor *)tintColor
{
    _tintColor = tintColor;
    _shapeLayer.fillColor = [_tintColor CGColor];
}

- (void)setActivityIndicatorViewStyle:(UIActivityIndicatorViewStyle)activityIndicatorViewStyle
{
    if ([_activity isKindOfClass:[UIActivityIndicatorView class]]) {
        [(UIActivityIndicatorView *)_activity setActivityIndicatorViewStyle:activityIndicatorViewStyle];
    }
}

- (UIActivityIndicatorViewStyle)activityIndicatorViewStyle
{
    if ([_activity isKindOfClass:[UIActivityIndicatorView class]]) {
        return [(UIActivityIndicatorView *)_activity activityIndicatorViewStyle];
    }
    return 0;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"contentInset"]) {
        if (!_ignoreInset) {
            _shapeLayer.opacity = 0;
            self.originalContentInset = [[change objectForKey:@"new"] UIEdgeInsetsValue];
            //self.frame = CGRectMake(0, -(kTotalViewHeight + self.scrollView.contentInset.top), self.scrollView.frame.size.width, kTotalViewHeight);
            self.frame = CGRectMake(0, -(kTotalViewHeight), self.scrollView.frame.size.width, kTotalViewHeight);
        }
        return;
    }
    
    if (!self.enabled || _ignoreOffset) {
        return;
    }

    CGFloat offset = [[change objectForKey:@"new"] CGPointValue].y + self.originalContentInset.top;
    
    if (_refreshing) {
        if (offset != 0) {
            // Keep thing pinned at the top
            
            [CATransaction begin];
            [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
            _shapeLayer.position = CGPointMake(0, kMaxDistance + offset + kOpenedViewHeight);
            [CATransaction commit];

            _activity.center = CGPointMake(floor(self.frame.size.width / 2), MIN(offset + self.frame.size.height + floor(kOpenedViewHeight / 2), self.frame.size.height - kOpenedViewHeight/ 2));

            _ignoreInset = YES;
            _ignoreOffset = YES;
            
            if (offset < 0) {
                // Set the inset depending on the situation
                if (offset >= -kOpenedViewHeight) {
                    if (!self.scrollView.dragging) {
                        if (!_didSetInset) {
                            _didSetInset = YES;
                            _hasSectionHeaders = NO;
                            if([self.scrollView isKindOfClass:[UITableView class]]){
                                for (int i = 0; i < [(UITableView *)self.scrollView numberOfSections]; ++i) {
                                    if ([(UITableView *)self.scrollView rectForHeaderInSection:i].size.height) {
                                        _hasSectionHeaders = YES;
                                        break;
                                    }
                                }
                            }
                        }
                        if (_hasSectionHeaders) {
                            [self.scrollView setContentInset:UIEdgeInsetsMake(MIN(-offset, kOpenedViewHeight) + self.originalContentInset.top, self.originalContentInset.left, self.originalContentInset.bottom, self.originalContentInset.right)];
                        } else {
                            [self.scrollView setContentInset:UIEdgeInsetsMake(kOpenedViewHeight + self.originalContentInset.top, self.originalContentInset.left, self.originalContentInset.bottom, self.originalContentInset.right)];
                        }
                    } else if (_didSetInset && _hasSectionHeaders) {
                        [self.scrollView setContentInset:UIEdgeInsetsMake(-offset + self.originalContentInset.top, self.originalContentInset.left, self.originalContentInset.bottom, self.originalContentInset.right)];
                    }
                }
                else if(self.scrollView.contentInset.top==self.originalContentInset.top){
                    CGFloat tmp = self.scrollView.contentOffset.y;
                    [self.scrollView setContentInset:UIEdgeInsetsMake(kOpenedViewHeight + self.originalContentInset.top, self.originalContentInset.left, self.originalContentInset.bottom, self.originalContentInset.right)];
                    self.scrollView.contentOffset = CGPointMake(0, tmp - self.scrollView.contentOffset.y - self.scrollView.contentInset.top);
                }
            } else if (_hasSectionHeaders) {
                [self.scrollView setContentInset:self.originalContentInset];
            }
            _ignoreInset = NO;
            _ignoreOffset = NO;
        }
        return;
    } else {
        // Check if we can trigger a new refresh and if we can draw the control
        BOOL dontDraw = NO;
        if (!_canRefresh) {
            if (offset >= 0) {
                // We can refresh again after the control is scrolled out of view
                _canRefresh = YES;
                _didSetInset = NO;
            } else {
                dontDraw = YES;
            }
        } else {
            if (offset >= 0) {
                // Don't draw if the control is not visible
                dontDraw = YES;
            }
        }
        if (offset > 0 && _lastOffset > offset && !self.scrollView.isTracking) {
            // If we are scrolling too fast, don't draw, and don't trigger unless the scrollView bounced back
            _canRefresh = NO;
            dontDraw = YES;
        }
        if (dontDraw) {
            _shapeLayer.path = nil;
            _shapeLayer.shadowPath = nil;
            _arrowLayer.path = nil;
            _highlightLayer.path = nil;
            _lastOffset = offset;
            return;
        }
    }
    _lastOffset = offset;
    
    BOOL triggered = NO;
    
    CGMutablePathRef path = CGPathCreateMutable();
    
    //Calculate some useful points and values
    CGFloat verticalShift = MAX(0, -((kMaxTopRadius + kMaxBottomRadius + kMaxTopPadding + kMaxBottomPadding) + offset));
    CGFloat distance = MIN(kMaxDistance, fabs(verticalShift));
    CGFloat percentage = 1 - (distance / kMaxDistance);
    
    CGFloat currentTopPadding = lerp(kMinTopPadding, kMaxTopPadding, percentage);
    CGFloat currentTopRadius = lerp(kMinTopRadius, kMaxTopRadius, percentage);
    CGFloat currentBottomRadius = lerp(kMinBottomRadius, kMaxBottomRadius, percentage);
    CGFloat currentBottomPadding =  lerp(kMinBottomPadding, kMaxBottomPadding, percentage);
    
    CGPoint bottomOrigin = CGPointMake(floor(self.bounds.size.width / 2), self.bounds.size.height - currentBottomPadding -currentBottomRadius);
    CGPoint topOrigin = CGPointZero;
    if (distance == 0) {
        topOrigin = CGPointMake(floor(self.bounds.size.width / 2), bottomOrigin.y);
    } else {
        topOrigin = CGPointMake(floor(self.bounds.size.width / 2), self.bounds.size.height + offset + currentTopPadding + currentTopRadius);
        if (percentage == 0) {
            bottomOrigin.y -= (fabs(verticalShift) - kMaxDistance);
            triggered = YES;
        }
    }
    
    CGFloat bottom2 = bottomOrigin.y;
    bottomOrigin.y = -(topOrigin.y - bottomOrigin.y)/2 + topOrigin.y;
    
    //Top semicircle
    CGPathAddArc(path, NULL, topOrigin.x, topOrigin.y, currentTopRadius, 0, M_PI, YES);
    
    //Left curve
    CGPoint leftCp1 = CGPointMake(lerp((topOrigin.x - currentTopRadius), (bottomOrigin.x - currentBottomRadius), 0.1), lerp(topOrigin.y, bottomOrigin.y, 0.3));
    CGPoint leftCp2 = CGPointMake(lerp((topOrigin.x - currentTopRadius), (bottomOrigin.x - currentBottomRadius), 0.9), lerp(topOrigin.y, bottomOrigin.y, 0.3));
    CGPoint leftDestination = CGPointMake(bottomOrigin.x - currentBottomRadius, bottomOrigin.y);
    
    CGPathAddCurveToPoint(path, NULL, leftCp1.x, leftCp1.y, leftCp2.x, leftCp2.y, leftDestination.x, leftDestination.y);
    
    CGPoint leftCp3 = leftCp2;
    CGPoint leftCp4 = leftCp1;
    leftCp3.y = 2*bottomOrigin.y - leftCp3.y;
    leftCp4.y = 2*bottomOrigin.y - leftCp4.y;
    leftDestination = CGPointMake(topOrigin.x - currentTopRadius, bottom2);
    
    CGPathAddCurveToPoint(path, NULL, leftCp3.x, leftCp3.y, leftCp4.x, leftCp4.y, leftDestination.x, leftDestination.y);
    
    //Bottom semicircle
    CGPathAddArc(path, NULL, topOrigin.x, bottom2, currentTopRadius, M_PI, 0, YES);
    
    //Right curve
    CGPoint rightCp1 = leftCp4;
    CGPoint rightCp2 = leftCp3;
    rightCp1.x = 2*bottomOrigin.x - rightCp1.x;
    rightCp2.x = 2*bottomOrigin.x - rightCp2.x;
    CGPoint rightDestination = CGPointMake(bottomOrigin.x + currentBottomRadius, bottomOrigin.y);
    
    CGPathAddCurveToPoint(path, NULL, rightCp1.x, rightCp1.y, rightCp2.x, rightCp2.y, rightDestination.x, rightDestination.y);
    
    CGPoint rightCp3 = rightCp2;
    CGPoint rightCp4 = rightCp1;
    
    rightCp3.y = 2*bottomOrigin.y - rightCp3.y;
    rightCp4.y = 2*bottomOrigin.y - rightCp4.y;
    rightDestination = CGPointMake(topOrigin.x + currentTopRadius, topOrigin.y);
    
    CGPathAddCurveToPoint(path, NULL, rightCp3.x, rightCp3.y, rightCp4.x, rightCp4.y, rightDestination.x, rightDestination.y);
    
    CGPathCloseSubpath(path);
    
    if (!triggered) {
        // Set paths
        
        _shapeLayer.path = path;
        _shapeLayer.shadowPath = path;
        _shapeLayer.opacity = MAX(0, MIN(1, 2*distance/(kOpenedViewHeight+kMinTopPadding)));
        
    } else {
        // Start the shape disappearance animation
        
        CABasicAnimation *pathMorph = [CABasicAnimation animationWithKeyPath:@"path"];
        pathMorph.duration = 0.15;
        pathMorph.fillMode = kCAFillModeForwards;
        pathMorph.removedOnCompletion = NO;
        
        CGMutablePathRef fromPath = CGPathCreateMutable();
        CGMutablePathRef tmpPath = CGPathCreateMutable();
        CGPathAddArc(tmpPath, NULL, topOrigin.x, topOrigin.y, currentTopRadius, 0, M_PI, YES);
        leftDestination = CGPointMake(bottomOrigin.x - currentBottomRadius, bottomOrigin.y-5);
        CGPathAddCurveToPoint(tmpPath, NULL, leftCp1.x, leftCp1.y, leftCp2.x, leftCp2.y, leftDestination.x, leftDestination.y);
        CGPathAddArc(tmpPath, NULL, bottomOrigin.x, bottomOrigin.y-5, currentBottomRadius, M_PI, 0, YES);
        rightDestination = CGPointMake(topOrigin.x + currentTopRadius, topOrigin.y);
        CGPathAddCurveToPoint(tmpPath, NULL, rightCp3.x, rightCp3.y, rightCp4.x, rightCp4.y, rightDestination.x, rightDestination.y);
        CGPathCloseSubpath(tmpPath);
        CGPathAddPath(fromPath, &CGAffineTransformIdentity, tmpPath);
        CGPathRelease(tmpPath);
        
        tmpPath = CGPathCreateMutable();
        CGPathAddArc(tmpPath, NULL, bottomOrigin.x, bottomOrigin.y+5, currentBottomRadius, 0, M_PI, YES);
        leftDestination = CGPointMake(topOrigin.x - currentTopRadius, bottom2);
        CGPathAddCurveToPoint(tmpPath, NULL, leftCp3.x, leftCp3.y+5, leftCp4.x, leftCp4.y+5, leftDestination.x, leftDestination.y);
        CGPathAddArc(tmpPath, NULL, topOrigin.x, bottom2, currentTopRadius, M_PI, 0, YES);
        rightDestination = CGPointMake(bottomOrigin.x + currentBottomRadius, bottomOrigin.y+5);
        CGPathAddCurveToPoint(tmpPath, NULL, rightCp1.x, rightCp1.y+5, rightCp2.x, rightCp2.y+5, rightDestination.x, rightDestination.y);
        CGPathCloseSubpath(tmpPath);
        CGPathAddPath(fromPath, &CGAffineTransformIdentity, tmpPath);
        CGPathRelease(tmpPath);
        
        pathMorph.fromValue = (__bridge id)fromPath;
        
        CGFloat radius = 3;
        CGMutablePathRef toPath = CGPathCreateMutable();
        
        tmpPath = CGPathCreateMutable();
        CGPathAddArc(tmpPath, NULL, topOrigin.x, topOrigin.y, radius, 0, M_PI, YES);
        CGPathAddCurveToPoint(tmpPath, NULL, topOrigin.x - radius, topOrigin.y, topOrigin.x - radius, topOrigin.y, topOrigin.x - radius, topOrigin.y);
        CGPathAddArc(tmpPath, NULL, topOrigin.x, topOrigin.y, radius, M_PI, 0, YES);
        CGPathAddCurveToPoint(tmpPath, NULL, topOrigin.x + radius, topOrigin.y, topOrigin.x + radius, topOrigin.y, topOrigin.x + radius, topOrigin.y);
        CGPathCloseSubpath(tmpPath);
        CGPathAddPath(toPath, &CGAffineTransformIdentity, tmpPath);
        CGPathRelease(tmpPath);
        
        tmpPath = CGPathCreateMutable();
        CGPathAddArc(tmpPath, NULL, topOrigin.x, topOrigin.y+15, radius, 0, M_PI, YES);
        CGPathAddCurveToPoint(tmpPath, NULL, topOrigin.x - radius, topOrigin.y+15, topOrigin.x - radius, topOrigin.y+15, topOrigin.x - radius, topOrigin.y+15);
        CGPathAddArc(tmpPath, NULL, topOrigin.x, topOrigin.y+15, radius, M_PI, 0, YES);
        CGPathAddCurveToPoint(tmpPath, NULL, topOrigin.x + radius, topOrigin.y+15, topOrigin.x + radius, topOrigin.y+15, topOrigin.x + radius, topOrigin.y+15);
        CGPathCloseSubpath(tmpPath);
        CGPathAddPath(toPath, &CGAffineTransformIdentity, tmpPath);
        CGPathRelease(tmpPath);
        
        pathMorph.toValue = (__bridge id)toPath;
        
        [_shapeLayer addAnimation:pathMorph forKey:nil];
        
        CGPathRelease(fromPath);
        CGPathRelease(toPath);
        
        CABasicAnimation *shapeAlphaAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        shapeAlphaAnimation.duration = 0.1;
        shapeAlphaAnimation.beginTime = CACurrentMediaTime() + 0.1;
        shapeAlphaAnimation.toValue = [NSNumber numberWithFloat:0];
        shapeAlphaAnimation.fillMode = kCAFillModeForwards;
        shapeAlphaAnimation.removedOnCompletion = NO;
        [_shapeLayer addAnimation:shapeAlphaAnimation forKey:nil];
        
        
        [CATransaction begin];
        [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
        _activity.layer.transform = CATransform3DMakeScale(0.1, 0.1, 1);
        [CATransaction commit];
        
        [_activity performSelectorOnMainThread:@selector(startAnimating) withObject:nil waitUntilDone:NO];
        [UIView animateWithDuration:0.2 delay:0.15 options:UIViewAnimationOptionCurveLinear animations:^{
            _activity.alpha = 1;
            _activity.layer.transform = CATransform3DMakeScale(1, 1, 1);
        } completion:nil];
        
        self.refreshing = YES;
        _canRefresh = NO;
        [self sendActionsForControlEvents:UIControlEventValueChanged];
    }
    
    CGPathRelease(path);
}

- (void)beginRefreshing
{
    if (!_refreshing) {
        CABasicAnimation *alphaAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        alphaAnimation.duration = 0.0001;
        alphaAnimation.toValue = [NSNumber numberWithFloat:0];
        alphaAnimation.fillMode = kCAFillModeForwards;
        alphaAnimation.removedOnCompletion = NO;
        [_shapeLayer addAnimation:alphaAnimation forKey:nil];
        [_arrowLayer addAnimation:alphaAnimation forKey:nil];
        [_highlightLayer addAnimation:alphaAnimation forKey:nil];
        
        _activity.alpha = 1;
        _activity.layer.transform = CATransform3DMakeScale(1, 1, 1);
        [_activity performSelectorOnMainThread:@selector(startAnimating) withObject:nil waitUntilDone:NO];

        CGPoint offset = self.scrollView.contentOffset;
        _ignoreInset = YES;
        [self.scrollView setContentInset:UIEdgeInsetsMake(kOpenedViewHeight + self.originalContentInset.top, self.originalContentInset.left, self.originalContentInset.bottom, self.originalContentInset.right)];
        _ignoreInset = NO;
        [self.scrollView setContentOffset:offset animated:NO];

        self.refreshing = YES;
        _canRefresh = NO;
    }
}

- (void)endRefreshing
{
    if (_refreshing) {
        self.refreshing = NO;
        // Create a temporary retain-cycle, so the scrollView won't be released
        // halfway through the end animation.
        // This allows for the refresh control to clean up the observer,
        // in the case the scrollView is released while the animation is running
        
        if(!self.scrollView.isTracking){
            __block UIScrollView *blockScrollView = self.scrollView;
            [UIView animateWithDuration:0.4 animations:^{
                _ignoreInset = YES;
                [blockScrollView setContentInset:self.originalContentInset];
                _ignoreInset = NO;
                _activity.alpha = 0;
                _activity.layer.transform = CATransform3DMakeScale(0.1, 0.1, 1);
            } completion:^(BOOL finished) {
                [_shapeLayer removeAllAnimations];
                _shapeLayer.path = nil;
                _shapeLayer.shadowPath = nil;
                _shapeLayer.position = CGPointZero;
                [_arrowLayer removeAllAnimations];
                _arrowLayer.path = nil;
                [_highlightLayer removeAllAnimations];
                _highlightLayer.path = nil;
                // We need to use the scrollView somehow in the end block,
                // or it'll get released in the animation block.
                _ignoreInset = YES;
                [blockScrollView setContentInset:self.originalContentInset];
                _ignoreInset = NO;
                
                [_activity performSelectorOnMainThread:@selector(stopAnimating) withObject:nil waitUntilDone:NO];
            }];
        }
        else{
            _activity.alpha = 0;
            _activity.layer.transform = CATransform3DMakeScale(0.1, 0.1, 1);
            
            [_shapeLayer removeAllAnimations];
            _shapeLayer.path = nil;
            _shapeLayer.shadowPath = nil;
            _shapeLayer.position = CGPointZero;
            [_arrowLayer removeAllAnimations];
            _arrowLayer.path = nil;
            [_highlightLayer removeAllAnimations];
            _highlightLayer.path = nil;
            
            if(self.scrollView.contentInset.top != self.originalContentInset.top){
                _ignoreInset = YES;
                CGFloat tmp = self.scrollView.contentOffset.y;
                [self.scrollView setContentInset:self.originalContentInset];
                self.scrollView.contentOffset = CGPointMake(0, tmp - self.scrollView.contentOffset.y - self.scrollView.contentInset.top);
                _ignoreInset = NO;
            }
            [_activity performSelectorOnMainThread:@selector(stopAnimating) withObject:nil waitUntilDone:NO];
        }
    }
}

@end
