// Xuyiming: Regression tests for popup transitions and resource ownership.
#import <XCTest/XCTest.h>
#import <QuartzCore/QuartzCore.h>
#import "XYMBasicPopWindowView.h"
#import "XYMPopWindowWebView.h"

@interface XYMBasicPopWindowView (GestureRegression)
- (void)panGes:(UIPanGestureRecognizer *)gesture;
- (void)leftPanGes:(UIPanGestureRecognizer *)gesture;
@end

@interface XYMTestPanGesture : UIPanGestureRecognizer
@property (nonatomic) UIGestureRecognizerState testState;
@property (nonatomic) CGPoint testTranslation;
@end
@implementation XYMTestPanGesture
- (UIGestureRecognizerState)state { return self.testState; }
- (CGPoint)translationInView:(UIView *)view { return self.testTranslation; }
- (void)setTranslation:(CGPoint)translation inView:(UIView *)view { self.testTranslation = translation; }
@end

@interface XYMBasicPopWindowViewTests : XCTestCase
@end

@implementation XYMBasicPopWindowViewTests
- (void)testAnimatedPushAlsoAnimatesBackgroundReturn {
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    XYMBasicPopWindowView *root = [[XYMBasicPopWindowView alloc] init];
    XYMBasicPopWindowView *child = [[XYMBasicPopWindowView alloc] init];
    // 子层应使用本次 Push 的参数，不依赖父层 Show 时是否开启动画。
    [root showIn:host animation:NO completion:nil];
    XCTestExpectation *pushed = [self expectationWithDescription:@"animated child pushed"];
    [root pushView:child animation:YES completion:^{ [pushed fulfill]; }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTestExpectation *closed = [self expectationWithDescription:@"background return finished"];
    child.dismissBlock = ^(BOOL finished) { if (finished) [closed fulfill]; };
    UIButton *backdrop = [child valueForKey:@"bgButton"];
    [backdrop sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertEqual(child.superview, root, @"背景返回应等待动画结束后才移除子层");
    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertNil(child.superview);
    XCTAssertEqualWithAccuracy(root.popView.frame.origin.x, 0, 0.01);
    [root disMissAllView:NO completion:nil];
}

- (void)testUnanimatedPushResetsReusedBackgroundAnimationPreference {
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    XYMBasicPopWindowView *child = [[XYMBasicPopWindowView alloc] init];
    XCTestExpectation *shown = [self expectationWithDescription:@"previous presentation finished"];
    [child showIn:host animation:YES completion:^{ [shown fulfill]; }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    [child disMissAnimation:NO completion:nil];
    XYMBasicPopWindowView *root = [[XYMBasicPopWindowView alloc] init];
    [root showIn:host animation:NO completion:nil];
    root.backgroundDismissAnimated = YES;
    [root pushView:child animation:NO completion:nil];
    __block BOOL finished = NO;
    child.dismissBlock = ^(BOOL completed) { finished = completed; };
    [child backGroudButtonClick];
    XCTAssertNil(child.superview);
    XCTAssertTrue(finished);
    XCTAssertTrue(root.backgroundDismissAnimated, @"子层的动画参数不能覆盖父层设置");
    [root disMissAllView:NO completion:nil];
}

- (void)testSidePanContinuesFromPushEndAndCancellationRestoresThatFrame {
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    XYMBasicPopWindowView *root = [[XYMBasicPopWindowView alloc] init];
    XYMBasicPopWindowView *child = [[XYMBasicPopWindowView alloc] init];
    root.popView_height = 300;
    child.popView_height = 180;
    [root showIn:host animation:NO completion:nil];
    XCTestExpectation *pushed = [self expectationWithDescription:@"shorter child pushed"];
    [root pushView:child animation:YES completion:^{ [pushed fulfill]; }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    CGRect parkedFrame = root.popView.frame;
    CGRect childFrame = child.popView.frame;
    XYMTestPanGesture *gesture = [[XYMTestPanGesture alloc] init];
    gesture.testState = UIGestureRecognizerStateBegan;
    [child leftPanGes:gesture];
    XCTAssertTrue(CGRectEqualToRect(root.popView.frame, parkedFrame), @"Side pan must start at %@, not %@", NSStringFromCGRect(parkedFrame), NSStringFromCGRect(root.popView.frame));
    gesture.testState = UIGestureRecognizerStateChanged;
    gesture.testTranslation = CGPointMake(48, 0);
    [child leftPanGes:gesture];
    // 按手势进度在 Push 停留位置和父层正常显示位置之间连续插值。
    CGFloat progress = 48.0 / 320.0;
    XCTAssertEqualWithAccuracy(root.popView.frame.origin.y, parkedFrame.origin.y + (180 - parkedFrame.origin.y) * progress, 0.01);
    gesture.testState = UIGestureRecognizerStateCancelled;
    [child leftPanGes:gesture];
    XCTAssertTrue(CGRectEqualToRect(root.popView.frame, parkedFrame));
    XCTAssertTrue(CGRectEqualToRect(child.popView.frame, childFrame));
    XCTAssertNotNil(child.superview);
    [root disMissAllView:NO completion:nil];
}

- (void)testSidePanCompletesFromDifferentParentAndChildHeights {
    for (NSArray<NSNumber *> *heights in @[@[@300, @180], @[@180, @300], @[@180, @180]]) {
        UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
        XYMBasicPopWindowView *root = [[XYMBasicPopWindowView alloc] init];
        XYMBasicPopWindowView *child = [[XYMBasicPopWindowView alloc] init];
        root.popView_height = heights[0].doubleValue;
        child.popView_height = heights[1].doubleValue;
        [root showIn:host animation:NO completion:nil];
        [root pushView:child animation:NO completion:nil];
        CGRect parkedFrame = root.popView.frame;
        XYMTestPanGesture *gesture = [[XYMTestPanGesture alloc] init];
        gesture.testState = UIGestureRecognizerStateBegan;
        [child leftPanGes:gesture];
        XCTAssertTrue(CGRectEqualToRect(root.popView.frame, parkedFrame));
        gesture.testState = UIGestureRecognizerStateChanged;
        for (NSUInteger step = 0; step < 2; step++) {
            gesture.testTranslation = CGPointMake(90, 0);
            [child leftPanGes:gesture];
        }
        XCTAssertEqualWithAccuracy(child.popView.frame.origin.x, 180, 0.01);
        gesture.testState = UIGestureRecognizerStateEnded;
        [child leftPanGes:gesture];
        NSPredicate *removed = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) { return child.superview == nil; }];
        [self expectationForPredicate:removed evaluatedWithObject:child handler:nil];
        [self waitForExpectationsWithTimeout:2 handler:nil];
        XCTAssertEqualWithAccuracy(root.popView.frame.origin.x, 0, 0.01);
        XCTAssertEqualWithAccuracy(CGRectGetMaxY(root.popView.frame), 480, 0.01);
        XCTAssertEqualWithAccuracy(root.popView.alpha, 1, 0.01);
        [root disMissAllView:NO completion:nil];
    }
}

- (void)testCancelledAndFailedLargeSidePanNeverDismissesTheChild {
    for (NSNumber *state in @[@(UIGestureRecognizerStateCancelled), @(UIGestureRecognizerStateFailed)]) {
        UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
        XYMBasicPopWindowView *root = [[XYMBasicPopWindowView alloc] init];
        XYMBasicPopWindowView *child = [[XYMBasicPopWindowView alloc] init];
        [root showIn:host animation:NO completion:nil];
        [root pushView:child animation:NO completion:nil];
        CGRect parkedFrame = root.popView.frame;
        XYMTestPanGesture *gesture = [[XYMTestPanGesture alloc] init];
        gesture.testState = UIGestureRecognizerStateBegan;
        [child leftPanGes:gesture];
        gesture.testState = UIGestureRecognizerStateChanged;
        gesture.testTranslation = CGPointMake(240, 0);
        [child leftPanGes:gesture];
        XCTAssertEqualWithAccuracy(child.popView.frame.origin.x, 240, 0.01);
        XCTAssertEqualWithAccuracy(child.frame.origin.x, 0, 0.01);
        gesture.testState = state.integerValue;
        [child leftPanGes:gesture];
        XCTAssertEqual(child.superview, root);
        XCTAssertTrue(CGRectEqualToRect(root.popView.frame, parkedFrame));
        XCTAssertEqualWithAccuracy(child.popView.frame.origin.x, 0, 0.01);
        [root disMissAllView:NO completion:nil];
    }
}

- (void)testConstrainedParentKeepsItsSidePanStartAfterAnotherLayout {
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    XYMBasicPopWindowView *root = [[XYMBasicPopWindowView alloc] init];
    UIView *content = [[UIView alloc] init];
    [content.heightAnchor constraintEqualToConstant:300].active = YES;
    [root addXibViewToPopView:content];
    XYMBasicPopWindowView *child = [[XYMBasicPopWindowView alloc] init];
    UIView *childContent = [[UIView alloc] init];
    [childContent.heightAnchor constraintEqualToConstant:180].active = YES;
    [child addXibViewToPopView:childContent];
    [root showIn:host animation:NO completion:nil];
    XCTestExpectation *pushed = [self expectationWithDescription:@"constrained parent pushed"];
    [root pushView:child animation:YES completion:^{ [pushed fulfill]; }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    CGRect parkedFrame = root.popView.frame;
    XYMTestPanGesture *gesture = [[XYMTestPanGesture alloc] init];
    gesture.testState = UIGestureRecognizerStateBegan;
    [child leftPanGes:gesture];
    [root setNeedsLayout];
    [root layoutIfNeeded];
    XCTAssertTrue(CGRectEqualToRect(root.popView.frame, parkedFrame));
    gesture.testState = UIGestureRecognizerStateChanged;
    gesture.testTranslation = CGPointMake(48, 0);
    [child leftPanGes:gesture];
    CGRect movingParentFrame = root.popView.frame;
    CGRect movingChildFrame = child.popView.frame;
    [root setNeedsLayout];
    [child setNeedsLayout];
    [root layoutIfNeeded];
    XCTAssertTrue(CGRectEqualToRect(root.popView.frame, movingParentFrame));
    XCTAssertTrue(CGRectEqualToRect(child.popView.frame, movingChildFrame));
    gesture.testState = UIGestureRecognizerStateCancelled;
    [child leftPanGes:gesture];
    [root setNeedsLayout];
    [child setNeedsLayout];
    [root layoutIfNeeded];
    XCTAssertTrue(CGRectEqualToRect(root.popView.frame, parkedFrame));
    XCTAssertEqualWithAccuracy(child.popView.frame.origin.x, 0, 0.01);
    [root disMissAllView:NO completion:nil];
}

- (void)testPushWithoutAnimationPlacesChildInsideContainer {
    UIView *host = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    XYMBasicPopWindowView *root = [[XYMBasicPopWindowView alloc] init];
    XYMBasicPopWindowView *child = [[XYMBasicPopWindowView alloc] init];
    [root showIn:host animation:NO completion:nil];
    [root pushView:child animation:NO completion:nil];
    XCTAssertEqualWithAccuracy(CGRectGetMinX(child.frame), 0, 0.01);
}

- (void)testRootPopSafelyDismissesFromPlainHost {
    UIView *host = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    XYMBasicPopWindowView *root = [[XYMBasicPopWindowView alloc] init];
    [root showIn:host animation:NO completion:nil];
    __block NSUInteger calls = 0;
    XCTAssertNoThrow([root popViewAnimation:NO completion:^{ calls++; }]);
    XCTAssertNil(root.superview);
    XCTAssertEqual(calls, 1u);
}

- (void)testDismissWithoutAnimationReportsFinishedAfterRemoval {
    UIView *host = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    XYMBasicPopWindowView *root = [[XYMBasicPopWindowView alloc] init];
    [root showIn:host animation:NO completion:nil];
    NSMutableArray *events = [NSMutableArray array];
    root.dismissBlock = ^(BOOL finished) { [events addObject:@(finished)]; };
    [root disMissAnimation:NO completion:^{
        XCTAssertNil(root.superview);
        [events addObject:@"completion"];
    }];
    XCTAssertEqualObjects(events, (@[@NO, @YES, @"completion"]));
}

- (void)testGestureConfigurationIsIdempotentAndReversible {
    XYMBasicPopWindowView *view = [[XYMBasicPopWindowView alloc] init];
    view.canPanPopView = YES;
    view.canPanPopView = YES;
    XCTAssertEqual(view.popView.gestureRecognizers.count, 1u);
    view.isOnlyHeaderPan = YES;
    view.isOnlyHeaderPan = YES;
    view.isOnlyHeaderPan = NO;
    XCTAssertEqual(view.popView.gestureRecognizers.count, 1u);
    view.canPanPopView = NO;
    XCTAssertEqual(view.popView.gestureRecognizers.count, 0u);
    view.canLeftPanBack = YES;
    view.canLeftPanBack = YES;
    XCTAssertEqual(view.popView.gestureRecognizers.count, 1u);
    view.canLeftPanBack = NO;
    XCTAssertEqual(view.popView.gestureRecognizers.count, 0u);
}

- (void)testNestedDismissHonorsNoAnimationAndCompletion {
    UIView *host = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    XYMBasicPopWindowView *root = [[XYMBasicPopWindowView alloc] init];
    XYMBasicPopWindowView *child = [[XYMBasicPopWindowView alloc] init];
    [root showIn:host animation:NO completion:nil];
    [root pushView:child animation:NO completion:nil];
    __block NSUInteger calls = 0;
    [child disMissAnimation:NO completion:^{ calls++; }];
    XCTAssertEqual(calls, 1u);
    XCTAssertNil(child.superview);
    XCTAssertEqualWithAccuracy(CGRectGetMinX(root.popView.frame), 0, 0.01);
}

- (void)testFrameInitializerAndShowUseContainerBounds {
    XYMBasicPopWindowView *view = [[XYMBasicPopWindowView alloc] initWithFrame:CGRectMake(0, 0, 200, 300)];
    XCTAssertNotNil(view.popView);
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    view.popView_height = 180;
    [view showIn:host animation:NO completion:nil];
    [view layoutIfNeeded];
    XCTAssertTrue(CGRectEqualToRect(view.frame, host.bounds));
    XCTAssertEqualWithAccuracy(CGRectGetWidth(view.popView.frame), 320, 0.01);
    XCTAssertEqualWithAccuracy(CGRectGetMaxY(view.popView.frame), 480, 0.01);
}

- (void)testScrollLinkHonorsInsetAndRestoresOriginalBounces {
    XYMBasicPopWindowView *view = [[XYMBasicPopWindowView alloc] init];
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    scroll.contentSize = CGSizeMake(100, 500);
    scroll.contentInset = UIEdgeInsetsMake(20, 0, 0, 0);
    scroll.contentOffset = CGPointMake(0, -10); // 尚未到达顶部 -20。
    view.linkScrollView = scroll;
    scroll.contentOffset = CGPointMake(0, -9);
    XCTAssertTrue(scroll.bounces);
    scroll.contentOffset = CGPointMake(0, -20);
    XCTAssertFalse(scroll.bounces);
    view.linkScrollView = nil;
    XCTAssertTrue(scroll.bounces);
}

- (void)testDismissAllRemovesEntireStackAndCompletesOnce {
    UIView *host = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    XYMBasicPopWindowView *root = [[XYMBasicPopWindowView alloc] init];
    XYMBasicPopWindowView *child = [[XYMBasicPopWindowView alloc] init];
    [root showIn:host animation:NO completion:nil];
    [root pushView:child animation:NO completion:nil];
    __block NSUInteger calls = 0;
    [child disMissAllView:NO completion:^{ calls++; }];
    XCTAssertEqual(calls, 1u);
    XCTAssertEqual(host.subviews.count, 0u);
    XCTAssertNil(root.superview);
    XCTAssertNil(child.superview);
}

- (void)testRepeatedAnimatedDismissNotifiesLifecycleOnce {
    UIView *host = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    XYMBasicPopWindowView *view = [[XYMBasicPopWindowView alloc] init];
    [view showIn:host animation:NO completion:nil];
    __block NSUInteger starts = 0;
    __block NSUInteger finishes = 0;
    view.dismissBlock = ^(BOOL finished) { if (finished) finishes++; else starts++; };
    XCTestExpectation *first = [self expectationWithDescription:@"first completion"];
    XCTestExpectation *second = [self expectationWithDescription:@"second completion"];
    [view disMissAnimation:YES completion:^{ [first fulfill]; }];
    [view disMissAnimation:YES completion:^{ [second fulfill]; }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqual(starts, 1u);
    XCTAssertEqual(finishes, 1u);
}

- (void)testConstrainedContentRemainsHiddenAfterLayout {
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    XYMBasicPopWindowView *view = [[XYMBasicPopWindowView alloc] init];
    UIView *content = [[UIView alloc] init];
    [content.heightAnchor constraintEqualToConstant:120].active = YES;
    [view addXibViewToPopView:content];
    [view showIn:host animation:NO completion:nil];
    XCTAssertEqualWithAccuracy(CGRectGetHeight(view.popView.bounds), 120, 0.01);
    [view setHidden:YES animation:NO completion:nil];
    [view setNeedsLayout];
    [view layoutIfNeeded];
    XCTAssertGreaterThanOrEqual(CGRectGetMinY(view.popView.frame), 480);
    [view setHidden:NO animation:NO completion:nil];
    XCTAssertEqualWithAccuracy(CGRectGetMaxY(view.popView.frame), 480, 0.01);
}

- (void)testCancelledPanRestoresPopupPosition {
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    XYMBasicPopWindowView *view = [[XYMBasicPopWindowView alloc] init];
    view.popView_height = 180;
    [view showIn:host animation:NO completion:nil];
    XYMTestPanGesture *gesture = [[XYMTestPanGesture alloc] init];
    gesture.testState = UIGestureRecognizerStateChanged;
    gesture.testTranslation = CGPointMake(0, 60);
    [view panGes:gesture];
    gesture.testState = UIGestureRecognizerStateCancelled;
    [view panGes:gesture];
    XCTAssertEqualWithAccuracy(CGRectGetMaxY(view.popView.frame), 480, 0.01);
}

- (void)testAnimatedShowPushAndPopRestoreParent {
    UIView *host = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    XYMBasicPopWindowView *root = [[XYMBasicPopWindowView alloc] init];
    XYMBasicPopWindowView *child = [[XYMBasicPopWindowView alloc] init];
    XCTestExpectation *shown = [self expectationWithDescription:@"shown"];
    [root showIn:host animation:YES completion:^{ [shown fulfill]; }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTestExpectation *pushed = [self expectationWithDescription:@"pushed"];
    [root pushView:child animation:YES completion:^{ [pushed fulfill]; }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTestExpectation *popped = [self expectationWithDescription:@"popped"];
    [child popViewAnimation:YES completion:^{ [popped fulfill]; }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertNil(child.superview);
    XCTAssertEqualWithAccuracy(CGRectGetMinX(root.popView.frame), 0, 0.01);
    XCTAssertEqualWithAccuracy(root.popView.alpha, 1, 0.01);
}

- (void)testDismissAllWithAnimationCompletesForThreeLevels {
    UIView *host = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    XYMBasicPopWindowView *root = [[XYMBasicPopWindowView alloc] init];
    XYMBasicPopWindowView *middle = [[XYMBasicPopWindowView alloc] init];
    XYMBasicPopWindowView *top = [[XYMBasicPopWindowView alloc] init];
    [root showIn:host animation:NO completion:nil];
    [root pushView:middle animation:NO completion:nil];
    [middle pushView:top animation:NO completion:nil];
    __block NSUInteger finishedCount = 0;
    for (XYMBasicPopWindowView *view in @[root, middle, top]) {
        view.dismissBlock = ^(BOOL finished) { if (finished) finishedCount++; };
    }
    XCTestExpectation *closed = [self expectationWithDescription:@"all closed"];
    [top disMissAllView:YES completion:^{ [closed fulfill]; }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    XCTAssertEqual(finishedCount, 3u);
    XCTAssertEqual(host.subviews.count, 0u);
}

- (void)testDismissAllSlidesOnlyCardsWhileEveryBackdropStaysFixedAndFades {
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    XYMBasicPopWindowView *root = [[XYMBasicPopWindowView alloc] init];
    XYMBasicPopWindowView *middle = [[XYMBasicPopWindowView alloc] init];
    XYMBasicPopWindowView *top = [[XYMBasicPopWindowView alloc] init];
    [root showIn:host animation:NO completion:nil];
    [root pushView:middle animation:NO completion:nil];
    [middle pushView:top animation:NO completion:nil];
    NSArray<XYMBasicPopWindowView *> *stack = @[root, middle, top];
    NSMutableArray<NSValue *> *backdropFrames = [NSMutableArray array];
    for (XYMBasicPopWindowView *popup in stack) {
        UIView *backdrop = [popup valueForKey:@"bgButton"];
        [backdropFrames addObject:[NSValue valueWithCGRect:[backdrop convertRect:backdrop.bounds toView:host]]];
    }
    XCTestExpectation *closed = [self expectationWithDescription:@"cards dismissed"];
    [top disMissAllView:YES completion:^{ [closed fulfill]; }];
    for (NSUInteger index = 0; index < stack.count; index++) {
        XYMBasicPopWindowView *popup = stack[index];
        UIView *backdrop = [popup valueForKey:@"bgButton"];
        XCTAssertTrue(CGAffineTransformIsIdentity(popup.transform));
        XCTAssertEqualWithAccuracy(popup.alpha, 1, 0.01);
        XCTAssertTrue(CGRectEqualToRect([backdrop convertRect:backdrop.bounds toView:host], backdropFrames[index].CGRectValue));
        XCTAssertEqualWithAccuracy(backdrop.alpha, 0, 0.01);
        XCTAssertGreaterThanOrEqual(CGRectGetMinY(popup.popView.frame), CGRectGetHeight(popup.bounds));
    }
    [self waitForExpectationsWithTimeout:2 handler:nil];
    for (XYMBasicPopWindowView *popup in stack) {
        XCTAssertNil(popup.superview);
        XCTAssertTrue(CGAffineTransformIsIdentity(popup.popView.transform));
    }
}

- (void)testDismissAllPresentationKeepsBackdropsStationaryDuringCardAnimation {
    UIWindowScene *scene = nil;
    UIWindow *previousWindow = nil;
    for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
        if (![candidate isKindOfClass:UIWindowScene.class]) continue;
        scene = (UIWindowScene *)candidate;
        for (UIWindow *window in scene.windows) {
            if (window.isKeyWindow) { previousWindow = window; break; }
        }
        if (previousWindow) break;
    }
    XCTAssertNotNil(scene);
    if (!scene) return;
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
    UIViewController *controller = [[UIViewController alloc] init];
    window.rootViewController = controller;
    XYMBasicPopWindowView *root = [[XYMBasicPopWindowView alloc] init];
    XYMBasicPopWindowView *child = [[XYMBasicPopWindowView alloc] init];
    @try {
        [window makeKeyAndVisible];
        [window layoutIfNeeded];
        UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
        [controller.view addSubview:host];
        root.popView_height = 300;
        child.popView_height = 180;
        root.bgButton_Color_Alpha = child.bgButton_Color_Alpha = 0.5;
        [root showIn:host animation:NO completion:nil];
        [root pushView:child animation:NO completion:nil];
        [host layoutIfNeeded];
        [CATransaction flush];
        CGFloat initialCardY = CGRectGetMinY(child.popView.frame);
        XCTestExpectation *sampled = [self expectationWithDescription:@"in-flight layer geometry"];
        XCTestExpectation *closed = [self expectationWithDescription:@"visible stack closed"];
        XCTestExpectation *coalesced = [self expectationWithDescription:@"repeated close completed"];
        [child disMissAllView:YES completion:^{ [closed fulfill]; }];
        [root disMissAllView:YES completion:^{ [coalesced fulfill]; }];
        // 检查屏幕正在绘制的 presentationLayer，不能只验证提前到达终点的 model layer。
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            for (XYMBasicPopWindowView *popup in @[root, child]) {
                UIView *backdrop = [popup valueForKey:@"bgButton"];
                CALayer *containerLayer = popup.layer.presentationLayer;
                CALayer *backdropLayer = backdrop.layer.presentationLayer;
                XCTAssertNotNil(containerLayer);
                XCTAssertNotNil(backdropLayer);
                XCTAssertTrue(CATransform3DIsIdentity(containerLayer.transform));
                XCTAssertEqualWithAccuracy(containerLayer.opacity, 1, 0.01);
                XCTAssertTrue(CGRectEqualToRect(backdropLayer.frame, backdrop.layer.frame));
            }
            UIView *backdrop = [child valueForKey:@"bgButton"];
            XCTAssertGreaterThan(backdrop.layer.presentationLayer.opacity, 0);
            XCTAssertLessThan(backdrop.layer.presentationLayer.opacity, 1);
            CGFloat visibleCardY = CGRectGetMinY(child.popView.layer.presentationLayer.frame);
            XCTAssertGreaterThan(visibleCardY, initialCardY);
            XCTAssertLessThan(visibleCardY, CGRectGetHeight(child.bounds));
            [sampled fulfill];
        });
        [self waitForExpectationsWithTimeout:3 handler:nil];
        XCTAssertNil(root.superview);
        XCTAssertNil(child.superview);
    } @finally {
        if (root.superview) [root disMissAllView:NO completion:nil];
        window.hidden = YES;
        window.rootViewController = nil;
        [previousWindow makeKeyWindow];
    }
}

- (void)testReleasingScrollObserverRestoresCallerSettings {
    UIScrollView *scroll = [[UIScrollView alloc] init];
    __weak XYMBasicPopWindowView *weakView;
    @autoreleasepool {
        XYMBasicPopWindowView *view = [[XYMBasicPopWindowView alloc] init];
        weakView = view;
        view.linkScrollView = scroll;
        XCTAssertFalse(scroll.bounces);
    }
    XCTAssertNil(weakView);
    XCTAssertTrue(scroll.bounces);
    XCTAssertNoThrow(scroll.contentOffset = CGPointMake(0, 30));
}

- (void)testWebPopupWorksWithoutHostMacrosOrImageAsset {
    XYMPopWindowWebView *view = [[XYMPopWindowWebView alloc] initWithTitle:@"Example" url:[NSURL URLWithString:@"about:blank"]];
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 600)];
    [view showIn:host animation:NO completion:nil];
    [view layoutIfNeeded];
    XCTAssertNotNil(view.webView);
    XCTAssertEqualObjects(view.titleL.text, @"Example");
    XCTAssertNotNil([view.backBtn imageForState:UIControlStateNormal]);
    XCTAssertEqualWithAccuracy(CGRectGetWidth(view.webView.frame), 320, 0.01);
    [view.webView stopLoading];
}

- (void)testContainerResizeUpdatesPopupAndMask {
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    XYMBasicPopWindowView *view = [[XYMBasicPopWindowView alloc] init];
    view.popView_height = 180;
    view.popView_header_Radius = 12;
    [view showIn:host animation:NO completion:nil];
    host.frame = CGRectMake(0, 0, 480, 320);
    [host layoutIfNeeded];
    [view layoutIfNeeded];
    XCTAssertEqualWithAccuracy(CGRectGetWidth(view.popView.frame), 480, 0.01);
    XCTAssertEqualWithAccuracy(CGRectGetMaxY(view.popView.frame), 320, 0.01);
    CAShapeLayer *mask = (CAShapeLayer *)view.popView.layer.mask;
    XCTAssertEqualWithAccuracy(CGRectGetWidth(CGPathGetBoundingBox(mask.path)), 480, 0.01);
}

- (void)testRepeatedHideStillCallsCompletion {
    XYMBasicPopWindowView *view = [[XYMBasicPopWindowView alloc] init];
    __block NSUInteger calls = 0;
    [view setHidden:YES animation:NO completion:^{ calls++; }];
    [view setHidden:YES animation:NO completion:^{ calls++; }];
    XCTAssertEqual(calls, 2u);
}

- (void)testLeftPanOnRootDoesNotTreatHostAsPopup {
    UIView *host = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    XYMBasicPopWindowView *view = [[XYMBasicPopWindowView alloc] init];
    [view showIn:host animation:NO completion:nil];
    XYMTestPanGesture *gesture = [[XYMTestPanGesture alloc] init];
    gesture.testState = UIGestureRecognizerStateBegan;
    XCTAssertNoThrow([view leftPanGes:gesture]);
}

- (void)testPushedChildUsesSmallHostBoundsBeforeCompletion {
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    XYMBasicPopWindowView *root = [[XYMBasicPopWindowView alloc] init];
    XYMBasicPopWindowView *child = [[XYMBasicPopWindowView alloc] init];
    [root showIn:host animation:NO completion:nil];
    [root pushView:child animation:NO completion:^{
        XCTAssertEqualWithAccuracy(CGRectGetWidth(child.popView.frame), 320, 0.01);
        XCTAssertEqualWithAccuracy(CGRectGetMaxY(child.popView.frame), 480, 0.01);
    }];
}
@end
