// XYMDemoExamplesTests.m — Feature catalog regression tests. Created by Xuyiming.
#import <XCTest/XCTest.h>
#import "../Example/XYMPopWindowExample/XYMDemoViewController.h"
#import "../Example/XYMPopWindowExample/XYMFeatureViewController.h"

@interface XYMDemoExamplesTests : XCTestCase
@end

@implementation XYMDemoExamplesTests
- (UIView *)findView:(NSString *)identifier inView:(UIView *)view {
    if ([view.accessibilityIdentifier isEqualToString:identifier]) return view;
    for (UIView *child in view.subviews) {
        UIView *found = [self findView:identifier inView:child];
        if (found) return found;
    }
    return nil;
}
- (XYMFeatureViewController *)demo:(XYMDemoFeature)feature {
    XYMFeatureViewController *demo = [[XYMFeatureViewController alloc] initWithFeature:feature];
    [demo loadViewIfNeeded];
    demo.view.frame = CGRectMake(0, 0, 390, 844);
    [demo.view layoutIfNeeded];
    UISwitch *animation = (UISwitch *)[self findView:@"demo.animation" inView:demo.view];
    animation.on = NO;
    return demo;
}
- (void)tap:(NSString *)identifier demo:(XYMFeatureViewController *)demo {
    UIControl *control = (UIControl *)[self findView:identifier inView:demo.view];
    XCTAssertNotNil(control, @"Missing action %@", identifier);
    [control sendActionsForControlEvents:UIControlEventTouchUpInside];
}
- (void)select:(NSInteger)index identifier:(NSString *)identifier demo:(XYMFeatureViewController *)demo {
    UISegmentedControl *control = (UISegmentedControl *)[self findView:identifier inView:demo.view];
    XCTAssertNotNil(control);
    control.selectedSegmentIndex = index;
    [control sendActionsForControlEvents:UIControlEventValueChanged];
}
- (void)assertControlsFitInside:(UIView *)view {
    for (UIView *child in view.subviews) {
        if ([child isKindOfClass:UIControl.class] && [child.accessibilityIdentifier hasPrefix:@"demo."]) {
            CGRect rect = [child convertRect:child.bounds toView:view];
            XCTAssertTrue(CGRectContainsRect(CGRectInset(view.bounds, -0.5, -0.5), rect), @"%@ frame %@ overflows row %@", child.accessibilityIdentifier, NSStringFromCGRect(rect), NSStringFromCGRect(view.bounds));
            XCTAssertGreaterThanOrEqual(child.bounds.size.height, 28);
        }
        [self assertControlsFitInside:child];
    }
}
- (void)assertLabelsFitInside:(UIView *)view {
    for (UIView *child in view.subviews) {
        if ([child isKindOfClass:UILabel.class] && !child.hidden) {
            UILabel *label = (UILabel *)child;
            CGSize textSize = [label sizeThatFits:CGSizeMake(label.bounds.size.width, CGFLOAT_MAX)];
            XCTAssertLessThanOrEqual(textSize.height, label.bounds.size.height + 0.5, @"Clipped text: %@", label.text);
            XCTAssertTrue(CGRectContainsRect(CGRectInset(view.bounds, -0.5, -0.5), label.frame), @"Label outside its container: %@", label.text);
        }
        [self assertLabelsFitInside:child];
    }
}
- (UINavigationController *)navigationForDemo:(XYMFeatureViewController *)demo {
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:[[UIViewController alloc] init]];
    [navigation loadViewIfNeeded];
    [navigation pushViewController:demo animated:NO];
    [navigation.view layoutIfNeeded];
    return navigation;
}
- (NSArray<UIGestureRecognizer *> *)backGestures:(UINavigationController *)navigation {
    NSMutableArray *gestures = [NSMutableArray array];
    XCTAssertNotNil(navigation.interactivePopGestureRecognizer);
    if (navigation.interactivePopGestureRecognizer) [gestures addObject:navigation.interactivePopGestureRecognizer];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        XCTAssertNotNil(navigation.interactiveContentPopGestureRecognizer);
        if (navigation.interactiveContentPopGestureRecognizer) [gestures addObject:navigation.interactiveContentPopGestureRecognizer];
    }
#endif
    return gestures;
}
- (void)testCatalogContainsAllEightFeatureGroups {
    XYMDemoViewController *catalog = [[XYMDemoViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    [catalog loadViewIfNeeded];
    XCTAssertEqual([catalog tableView:catalog.tableView numberOfRowsInSection:0], 8);
}
- (void)testEveryFeatureFitsOnePortraitPageWithoutScrollingOrClipping {
    NSArray<NSValue *> *sizes = @[
        [NSValue valueWithCGSize:CGSizeMake(320, 568)],
        [NSValue valueWithCGSize:CGSizeMake(375, 667)],
        [NSValue valueWithCGSize:CGSizeMake(390, 844)],
        [NSValue valueWithCGSize:CGSizeMake(402, 874)],
        [NSValue valueWithCGSize:CGSizeMake(768, 1024)]
    ];
    for (NSValue *size in sizes) {
        for (NSInteger feature = 0; feature < XYMDemoFeatureCount; feature++) {
            XYMFeatureViewController *demo = [self demo:feature];
            // 无窗口的测试视图没有系统安全区，因此直接扣除导航栏和底部保留高度。
            demo.view.frame = CGRectMake(0, 0, size.CGSizeValue.width, size.CGSizeValue.height - 130);
            [demo.view setNeedsLayout];
            [demo.view layoutIfNeeded];
            CGRect safeRect = demo.view.safeAreaLayoutGuide.layoutFrame;
            UIView *page = [self findView:@"demo.page" inView:demo.view];
            if ([page isKindOfClass:UIScrollView.class]) XCTAssertFalse(((UIScrollView *)page).scrollEnabled);
            for (NSString *identifier in @[@"demo.controls", @"demo.preview", @"demo.events"]) {
                UIView *section = [self findView:identifier inView:demo.view];
                CGRect rect = [section convertRect:section.bounds toView:demo.view];
                XCTAssertGreaterThanOrEqual(CGRectGetMinY(rect), CGRectGetMinY(safeRect) - 0.5, @"%@ feature %ld", identifier, (long)feature);
                XCTAssertLessThanOrEqual(CGRectGetMaxY(rect), CGRectGetMaxY(safeRect) + 0.5, @"%@ feature %ld", identifier, (long)feature);
                XCTAssertGreaterThan(section.bounds.size.height, 0);
            }
            UIView *preview = [self findView:@"demo.preview" inView:demo.view];
            UIView *log = [self findView:@"demo.events" inView:demo.view];
            XCTAssertGreaterThanOrEqual(preview.bounds.size.height, 120);
            XCTAssertEqualWithAccuracy(preview.bounds.size.width, size.CGSizeValue.width, 0.5);
            XCTAssertLessThanOrEqual(log.bounds.size.height, 44);
            [self assertControlsFitInside:[self findView:@"demo.controls" inView:demo.view]];
        }
    }
}
- (void)testPreviewUsesFullPageWidthAndKeepsControlMargins {
    for (NSNumber *width in @[@320, @390, @768]) {
        XYMFeatureViewController *demo = [self demo:XYMDemoFeatureAppearance];
        demo.view.frame = CGRectMake(0, 0, width.doubleValue, 844);
        [demo.view setNeedsLayout];
        [demo.view layoutIfNeeded];
        UIView *preview = [self findView:@"demo.preview" inView:demo.view];
        UIView *controls = [self findView:@"demo.controls" inView:demo.view];
        CGRect previewRect = [preview convertRect:preview.bounds toView:demo.view];
        XCTAssertEqualWithAccuracy(CGRectGetMinX(previewRect), 0, 0.5);
        XCTAssertEqualWithAccuracy(preview.bounds.size.width, width.doubleValue, 0.5);
        XCTAssertGreaterThan(preview.bounds.size.height, 0);
        XCTAssertEqualWithAccuracy(controls.bounds.size.width, width.doubleValue - 32, 0.5);
    }
}
- (void)testPopupHeightAdaptsToRemainingPreviewSpaceAndResizing {
    for (NSInteger index = 0; index < XYMDemoFeatureCount; index++) {
        XYMFeatureViewController *demo = [self demo:index];
        demo.view.frame = CGRectMake(0, 0, 375, 540);
        [demo.view setNeedsLayout];
        [demo.view layoutIfNeeded];
        [demo showExample];
        XYMBasicPopWindowView *popup = demo.rootPopup;
        UIView *preview = [self findView:@"demo.preview" inView:demo.view];
        XCTAssertGreaterThanOrEqual(preview.bounds.size.height, 120);
        XCTAssertEqualWithAccuracy(popup.popView.bounds.size.height, preview.bounds.size.height * 0.82, 1);
        CGFloat originalHeight = popup.popView.bounds.size.height;
        demo.view.frame = CGRectMake(0, 0, 768, 1000);
        [demo.view setNeedsLayout];
        [demo.view layoutIfNeeded];
        XCTAssertEqual(popup, demo.rootPopup);
        XCTAssertGreaterThan(popup.popView.bounds.size.height, originalHeight, @"Feature %ld", (long)index);
        XCTAssertEqualWithAccuracy(popup.popView.bounds.size.height, preview.bounds.size.height * 0.82, 1, @"Feature %ld", (long)index);
        XCTAssertEqualWithAccuracy(popup.bounds.size.width, preview.bounds.size.width, 1);
        [demo closeExample];
    }
}
- (void)testControlsKeepIntrinsicSizeAndPaddingOnSmallScreens {
    for (NSNumber *width in @[@320, @390]) {
        XYMFeatureViewController *demo = [self demo:XYMDemoFeatureAppearance];
        demo.view.frame = CGRectMake(0, 0, width.doubleValue, 540);
        [demo.view setNeedsLayout];
        [demo.view layoutIfNeeded];
        UIView *controls = [self findView:@"demo.controls" inView:demo.view];
        UIView *page = [self findView:@"demo.page" inView:demo.view];
        XCTAssertNotNil(controls);
        XCTAssertFalse([page isKindOfClass:UIScrollView.class]);
        for (NSString *identifier in @[@"demo.animation", @"demo.show", @"demo.close", @"demo.height", @"demo.radius", @"demo.shade", @"demo.content"]) {
            UIControl *control = (UIControl *)[self findView:identifier inView:controls];
            XCTAssertNotNil(control);
            CGRect rect = [control convertRect:control.bounds toView:controls];
            XCTAssertGreaterThanOrEqual(CGRectGetMinX(rect), 8, @"%@ lacks leading padding", identifier);
            XCTAssertLessThanOrEqual(CGRectGetMaxX(rect), controls.bounds.size.width - 8, @"%@ lacks trailing padding", identifier);
            if ([control isKindOfClass:UISwitch.class]) {
                CGSize naturalSize = [control sizeThatFits:CGSizeZero];
                XCTAssertEqualWithAccuracy(control.bounds.size.width, naturalSize.width, 0.5);
                XCTAssertEqualWithAccuracy(control.bounds.size.height, naturalSize.height, 0.5);
                XCTAssertGreaterThanOrEqual(control.superview.bounds.size.height, naturalSize.height + 4);
            } else {
                XCTAssertGreaterThanOrEqual(control.bounds.size.height, 32, @"%@ is vertically cramped", identifier);
            }
            // 中间不能再有固定高度的滚动视口裁掉半个控件。
            for (UIView *ancestor = control.superview; ancestor && ancestor != page; ancestor = ancestor.superview) {
                XCTAssertFalse([ancestor isKindOfClass:UIScrollView.class]);
            }
        }
    }
}
- (void)testDefaultPopupTextFitsCompactPortraitPreview {
    for (NSNumber *feature in @[@(XYMDemoFeatureAppearance), @(XYMDemoFeatureContent)]) {
        XYMFeatureViewController *demo = [self demo:feature.integerValue];
        demo.view.frame = CGRectMake(0, 0, 320, 438);
        [demo.view setNeedsLayout];
        [demo.view layoutIfNeeded];
        [demo showExample];
        [self assertLabelsFitInside:demo.rootPopup.popView];
        [demo closeExample];
    }
}
- (void)testEveryFeatureCanShowAndCloseAPopup {
    // 关闭示例的动画开关，而非假设全局禁用动画后 completion 同步执行。
    for (NSInteger index = 0; index < XYMDemoFeatureCount; index++) {
        XYMFeatureViewController *demo = [self demo:index];
        [demo showExample];
        XYMBasicPopWindowView *popup = demo.rootPopup;
        XCTAssertNotNil(popup, @"Feature %ld must create its demonstration", (long)index);
        XCTAssertNotNil(popup.superview);
        [demo closeExample];
        XCTAssertNil(popup.superview);
    }
}
- (void)testRootPopupBlocksNavigationBackUntilItIsDismissed {
    XYMFeatureViewController *demo = [self demo:XYMDemoFeatureVisibility];
    UINavigationController *navigation = [self navigationForDemo:demo];
    NSArray<UIGestureRecognizer *> *gestures = [self backGestures:navigation];
    for (UIGestureRecognizer *gesture in gestures) gesture.enabled = YES;
    [demo showExample];
    for (UIGestureRecognizer *gesture in gestures) XCTAssertFalse(gesture.enabled);
    // 隐藏只是临时移出弹窗内容，实例尚未关闭，页面返回仍需保持锁定。
    [self tap:@"demo.hide" demo:demo];
    for (UIGestureRecognizer *gesture in gestures) XCTAssertFalse(gesture.enabled);
    [self tap:@"demo.restore" demo:demo];
    for (UIGestureRecognizer *gesture in gestures) XCTAssertFalse(gesture.enabled);
    [demo closeExample];
    XCTAssertNil(demo.rootPopup);
    for (UIGestureRecognizer *gesture in gestures) XCTAssertTrue(gesture.enabled);
}
- (void)testNavigationBackIsReleasedWhilePageIsAwayAndBlockedAgainOnReturn {
    XYMFeatureViewController *demo = [self demo:XYMDemoFeatureVisibility];
    UINavigationController *navigation = [self navigationForDemo:demo];
    NSArray<UIGestureRecognizer *> *gestures = [self backGestures:navigation];
    for (UIGestureRecognizer *gesture in gestures) gesture.enabled = YES;
    [demo beginAppearanceTransition:YES animated:NO];
    [demo endAppearanceTransition];
    [demo showExample];
    [demo beginAppearanceTransition:NO animated:NO];
    [demo endAppearanceTransition];
    XCTAssertNotNil(demo.rootPopup);
    for (UIGestureRecognizer *gesture in gestures) XCTAssertTrue(gesture.enabled);
    [demo beginAppearanceTransition:YES animated:NO];
    [demo endAppearanceTransition];
    for (UIGestureRecognizer *gesture in gestures) XCTAssertFalse(gesture.enabled);
    [demo closeExample];
    for (UIGestureRecognizer *gesture in gestures) XCTAssertTrue(gesture.enabled);
}
- (void)testNavigationBackRestoresEachOriginalStateAfterPopupRebuild {
    for (NSUInteger enabledMask = 0; enabledMask < 4; enabledMask++) {
        XYMFeatureViewController *demo = [self demo:XYMDemoFeatureAppearance];
        UINavigationController *navigation = [self navigationForDemo:demo];
        NSArray<UIGestureRecognizer *> *gestures = [self backGestures:navigation];
        for (NSUInteger index = 0; index < gestures.count; index++) gestures[index].enabled = (enabledMask & (1 << index)) != 0;
        [demo showExample];
        [demo showExample];
        [self select:1 identifier:@"demo.content" demo:demo];
        for (UIGestureRecognizer *gesture in gestures) XCTAssertFalse(gesture.enabled);
        // 走组件的背景关闭路径，而非控制器的“关闭”按钮，验证统一收尾回调。
        [demo.rootPopup backGroudButtonClick];
        XCTAssertNil(demo.rootPopup);
        for (NSUInteger index = 0; index < gestures.count; index++) {
            XCTAssertEqual(gestures[index].enabled, (enabledMask & (1 << index)) != 0);
        }
    }
}
- (void)testAnimatedShowAndDismissFinishBeforeNextAction {
    XYMFeatureViewController *demo = [self demo:XYMDemoFeatureVisibility];
    UINavigationController *navigation = [self navigationForDemo:demo];
    NSArray<UIGestureRecognizer *> *gestures = [self backGestures:navigation];
    for (UIGestureRecognizer *gesture in gestures) gesture.enabled = YES;
    UISwitch *animation = (UISwitch *)[self findView:@"demo.animation" inView:demo.view];
    animation.on = YES;
    [demo showExample];
    for (UIGestureRecognizer *gesture in gestures) XCTAssertFalse(gesture.enabled);
    XYMBasicPopWindowView *popup = demo.rootPopup;
    [demo showExample];
    XCTAssertEqual(demo.rootPopup, popup);
    NSPredicate *shown = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return [demo.eventLog containsString:@"show.completion"];
    }];
    [self expectationForPredicate:shown evaluatedWithObject:demo handler:nil];
    [self waitForExpectationsWithTimeout:3 handler:nil];
    [demo closeExample];
    // 关闭动画尚未完成时，不能提前允许导航返回。
    XCTAssertNotNil(popup.superview);
    for (UIGestureRecognizer *gesture in gestures) XCTAssertFalse(gesture.enabled);
    NSPredicate *closed = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return !popup.superview && [demo.eventLog containsString:@"dismiss.completion"];
    }];
    [self expectationForPredicate:closed evaluatedWithObject:demo handler:nil];
    [self waitForExpectationsWithTimeout:3 handler:nil];
    for (UIGestureRecognizer *gesture in gestures) XCTAssertTrue(gesture.enabled);
}
- (void)testAppearanceSlidersUpdateVisiblePopup {
    XYMFeatureViewController *demo = [self demo:XYMDemoFeatureAppearance];
    [demo showExample];
    NSArray *identifiers = @[@"demo.height", @"demo.radius", @"demo.shade"];
    CGFloat requestedHeight = demo.rootPopup.superview.bounds.size.height * 0.60;
    NSArray *values = @[@(requestedHeight), @28, @0.6];
    for (NSUInteger index = 0; index < identifiers.count; index++) {
        UISlider *slider = (UISlider *)[self findView:identifiers[index] inView:demo.view];
        XCTAssertNotNil(slider);
        slider.value = [values[index] floatValue];
        [slider sendActionsForControlEvents:UIControlEventValueChanged];
    }
    [demo.rootPopup layoutIfNeeded];
    XCTAssertEqualWithAccuracy(demo.rootPopup.popView.bounds.size.height, requestedHeight, 0.5);
    XCTAssertEqualWithAccuracy(demo.rootPopup.popView_header_Radius, 28, 0.01);
    XCTAssertEqualWithAccuracy(demo.rootPopup.bgButton_Color_Alpha, 0.6, 0.01);
    [demo closeExample];
}
- (void)testHeightSliderPreservesItsRatioWhenPreviewResizes {
    XYMFeatureViewController *demo = [self demo:XYMDemoFeatureAppearance];
    [demo showExample];
    UISlider *slider = (UISlider *)[self findView:@"demo.height" inView:demo.view];
    slider.value = demo.rootPopup.superview.bounds.size.height * 0.60;
    [slider sendActionsForControlEvents:UIControlEventValueChanged];
    demo.view.frame = CGRectMake(0, 0, 768, 1000);
    [demo.view setNeedsLayout];
    [demo.view layoutIfNeeded];
    CGFloat hostHeight = demo.rootPopup.superview.bounds.size.height;
    XCTAssertEqualWithAccuracy(demo.rootPopup.popView.bounds.size.height, hostHeight * 0.60, 1);
    XCTAssertEqualWithAccuracy(slider.value, hostHeight * 0.60, 1);
    XCTAssertEqualWithAccuracy(slider.maximumValue, hostHeight * 0.95, 1);
    [demo closeExample];
}
- (void)testHiddenPopupStaysBelowPreviewAfterResizing {
    XYMFeatureViewController *demo = [self demo:XYMDemoFeatureVisibility];
    [demo showExample];
    [self tap:@"demo.hide" demo:demo];
    demo.view.frame = CGRectMake(0, 0, 768, 1000);
    [demo.view setNeedsLayout];
    [demo.view layoutIfNeeded];
    XCTAssertEqualWithAccuracy(demo.rootPopup.popView.transform.ty, demo.rootPopup.popView.bounds.size.height, 1);
    XCTAssertGreaterThanOrEqual(CGRectGetMinY(demo.rootPopup.popView.frame), demo.rootPopup.bounds.size.height - 1);
    [self tap:@"demo.restore" demo:demo];
    XCTAssertTrue(CGAffineTransformIsIdentity(demo.rootPopup.popView.transform));
    [demo closeExample];
}
- (void)testNestedPopupHeightsAdaptToResizedPreview {
    XYMFeatureViewController *demo = [self demo:XYMDemoFeatureNested];
    [demo showExample];
    [self tap:@"demo.push" demo:demo];
    XYMBasicPopWindowView *child = (XYMBasicPopWindowView *)demo.rootPopup.subviews.lastObject;
    demo.view.frame = CGRectMake(0, 0, 768, 1000);
    [demo.view setNeedsLayout];
    [demo.view layoutIfNeeded];
    XCTAssertEqualWithAccuracy(child.popView.bounds.size.height, demo.rootPopup.superview.bounds.size.height * 0.90, 1);
    XCTAssertEqualWithAccuracy(demo.rootPopup.popView.frame.origin.x, -demo.rootPopup.bounds.size.width / 3, 1);
    [self tap:@"demo.pop" demo:demo];
    XCTAssertEqualWithAccuracy(demo.rootPopup.popView.frame.origin.x, 0, 1);
    [demo closeExample];
}
- (void)testCompactLayoutKeepsPopupHeaderInsidePreview {
    for (NSInteger index = 0; index < XYMDemoFeatureCount; index++) {
        XYMFeatureViewController *demo = [self demo:index];
        // 模拟小尺寸手机扣除导航栏和安全区后的内容空间。
        demo.view.frame = CGRectMake(0, 0, 375, 540);
        [demo.view layoutIfNeeded];
        [demo showExample];
        XCTAssertGreaterThanOrEqual(CGRectGetMinY(demo.rootPopup.popView.frame), 0, @"Feature %ld clips its header", (long)index);
        [demo closeExample];
    }
}
- (void)testHiddenPopupCanBeRestoredFromExternalControls {
    XYMFeatureViewController *demo = [self demo:XYMDemoFeatureVisibility];
    [demo showExample];
    XYMBasicPopWindowView *popup = demo.rootPopup;
    [self tap:@"demo.hide" demo:demo];
    XCTAssertGreaterThan(popup.popView.transform.ty, 0);
    UIView *restore = [self findView:@"demo.restore" inView:demo.view];
    XCTAssertFalse([restore isDescendantOfView:popup]);
    [self tap:@"demo.restore" demo:demo];
    XCTAssertTrue(CGAffineTransformIsIdentity(popup.popView.transform));
    [demo closeExample];
    NSRange start = [demo.eventLog rangeOfString:@"dismiss.start"];
    NSRange finish = [demo.eventLog rangeOfString:@"dismiss.finished"];
    NSRange completion = [demo.eventLog rangeOfString:@"dismiss.completion"];
    XCTAssertNotEqual(start.location, NSNotFound);
    XCTAssertLessThan(start.location, finish.location);
    XCTAssertLessThan(finish.location, completion.location);
    XCTAssertNil(demo.rootPopup);
}
- (void)testGestureSwitchesConfigurePopup {
    XYMFeatureViewController *demo = [self demo:XYMDemoFeatureGestures];
    [demo showExample];
    UISwitch *header = (UISwitch *)[self findView:@"demo.header" inView:demo.view];
    header.on = YES;
    [header sendActionsForControlEvents:UIControlEventValueChanged];
    XCTAssertTrue(demo.rootPopup.isOnlyHeaderPan);
    UISwitch *pan = (UISwitch *)[self findView:@"demo.pan" inView:demo.view];
    pan.on = NO;
    [pan sendActionsForControlEvents:UIControlEventValueChanged];
    XCTAssertFalse(demo.rootPopup.canPanPopView);
    [demo closeExample];
}
- (void)testBackgroundSwitchDisablesDismissal {
    XYMFeatureViewController *demo = [self demo:XYMDemoFeatureBackground];
    [demo showExample];
    UISwitch *control = (UISwitch *)[self findView:@"demo.background" inView:demo.view];
    control.on = NO;
    [control sendActionsForControlEvents:UIControlEventValueChanged];
    XCTAssertFalse(demo.rootPopup.bgButton_Enable);
    [demo closeExample];
}
- (void)testNestedPushPopAndCloseAll {
    XYMFeatureViewController *demo = [self demo:XYMDemoFeatureNested];
    UINavigationController *navigation = [self navigationForDemo:demo];
    NSArray<UIGestureRecognizer *> *gestures = [self backGestures:navigation];
    for (UIGestureRecognizer *gesture in gestures) gesture.enabled = YES;
    [demo showExample];
    XYMBasicPopWindowView *root = demo.rootPopup;
    [self tap:@"demo.push" demo:demo];
    XYMBasicPopWindowView *child = (XYMBasicPopWindowView *)root.subviews.lastObject;
    XCTAssertTrue([child isKindOfClass:XYMBasicPopWindowView.class]);
    XCTAssertEqual(child.popIndex, 1);
    XCTAssertTrue(child.canLeftPanBack);
    for (UIGestureRecognizer *gesture in gestures) XCTAssertFalse(gesture.enabled);
    XCTAssertNotEqual(child.popView_height, root.popView_height);
    UISwitch *side = (UISwitch *)[self findView:@"demo.side" inView:demo.view];
    side.on = NO;
    [side sendActionsForControlEvents:UIControlEventValueChanged];
    XCTAssertFalse(child.canLeftPanBack);
    [self tap:@"demo.pop" demo:demo];
    XCTAssertNil(child.superview);
    XCTAssertEqual(root, demo.rootPopup);
    for (UIGestureRecognizer *gesture in gestures) XCTAssertFalse(gesture.enabled);
    [self tap:@"demo.push" demo:demo];
    [self tap:@"demo.push" demo:demo];
    [self tap:@"demo.closeAll" demo:demo];
    XCTAssertNil(root.superview);
    XCTAssertNil(demo.rootPopup);
    for (UIGestureRecognizer *gesture in gestures) XCTAssertTrue(gesture.enabled);
}
- (void)testEnablingAnimationUpdatesBackgroundReturnForEveryExistingLayer {
    XYMFeatureViewController *demo = [self demo:XYMDemoFeatureNested];
    [demo showExample];
    XYMBasicPopWindowView *root = demo.rootPopup;
    [self tap:@"demo.push" demo:demo];
    XYMBasicPopWindowView *middle = (XYMBasicPopWindowView *)root.subviews.lastObject;
    [self tap:@"demo.push" demo:demo];
    XYMBasicPopWindowView *top = (XYMBasicPopWindowView *)middle.subviews.lastObject;
    UISwitch *animation = (UISwitch *)[self findView:@"demo.animation" inView:demo.view];
    animation.on = YES;
    [animation sendActionsForControlEvents:UIControlEventValueChanged];
    // 开关变化应应用到已存在的整组弹窗，而不只是下一次 Show / Push。
    for (XYMBasicPopWindowView *popup in @[top, middle, root]) {
        [popup backGroudButtonClick];
        XCTAssertNotNil(popup.superview, @"开启动画后，背景点击不能立即移除第 %lu 层", (unsigned long)popup.popIndex);
        NSPredicate *removed = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
            return popup.superview == nil;
        }];
        [self expectationForPredicate:removed evaluatedWithObject:popup handler:nil];
        [self waitForExpectationsWithTimeout:2 handler:nil];
    }
    XCTAssertNil(demo.rootPopup);
}
- (void)testDisablingAnimationMakesExistingLayersBackgroundReturnImmediate {
    XYMFeatureViewController *demo = [self demo:XYMDemoFeatureNested];
    UISwitch *animation = (UISwitch *)[self findView:@"demo.animation" inView:demo.view];
    animation.on = YES;
    [demo showExample];
    NSPredicate *shown = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return [demo.eventLog containsString:@"show.completion"];
    }];
    [self expectationForPredicate:shown evaluatedWithObject:demo handler:nil];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    XYMBasicPopWindowView *root = demo.rootPopup;
    [self tap:@"demo.push" demo:demo];
    NSPredicate *pushed = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return [demo.eventLog containsString:@"push.completion"];
    }];
    [self expectationForPredicate:pushed evaluatedWithObject:demo handler:nil];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    XYMBasicPopWindowView *child = (XYMBasicPopWindowView *)root.subviews.lastObject;
    animation.on = NO;
    [animation sendActionsForControlEvents:UIControlEventValueChanged];
    for (XYMBasicPopWindowView *popup in @[child, root]) {
        [popup backGroudButtonClick];
        XCTAssertNil(popup.superview, @"关闭动画后背景返回应立即移除当前层");
    }
    XCTAssertNil(demo.rootPopup);
}
- (void)testScrollInsetAndTopAction {
    XYMFeatureViewController *demo = [self demo:XYMDemoFeatureScroll];
    [self select:1 identifier:@"demo.inset" demo:demo];
    [demo showExample];
    UITableView *table = (UITableView *)demo.rootPopup.linkScrollView;
    XCTAssertNotNil(table);
    XCTAssertEqualWithAccuracy(table.contentInset.top, 24, 0.01);
    XCTAssertEqual([table.dataSource tableView:table numberOfRowsInSection:0], 40);
    table.contentOffset = CGPointMake(0, 160);
    [self tap:@"demo.scrollTop" demo:demo];
    XCTAssertEqualWithAccuracy(table.contentOffset.y, -table.adjustedContentInset.top, 0.01);
    [demo closeExample];
}
- (void)testRealXIBAndProgrammaticConstraintHeight {
    XYMFeatureViewController *demo = [self demo:XYMDemoFeatureContent];
    [demo showExample];
    XCTAssertNotNil([demo.rootPopup viewWithTag:7301]);
    XCTAssertEqualWithAccuracy(demo.rootPopup.popView.bounds.size.height, demo.rootPopup.superview.bounds.size.height * 0.82, 1);
    XYMBasicPopWindowView *old = demo.rootPopup;
    [self select:1 identifier:@"demo.content" demo:demo];
    XCTAssertNil(old.superview);
    XCTAssertNotNil([demo.rootPopup viewWithTag:7302]);
    XCTAssertEqualWithAccuracy(demo.rootPopup.popView.bounds.size.height, demo.rootPopup.superview.bounds.size.height * 0.82, 1);
    [demo closeExample];
}
- (void)testWindowContainerCanBeClosedInsidePopup {
    XYMFeatureViewController *demo = [self demo:XYMDemoFeatureContent];
    UINavigationController *navigation = [self navigationForDemo:demo];
    NSArray<UIGestureRecognizer *> *gestures = [self backGestures:navigation];
    for (UIGestureRecognizer *gesture in gestures) gesture.enabled = YES;
    UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 390, 844)];
    [window addSubview:navigation.view];
    [self select:1 identifier:@"demo.host" demo:demo];
    [demo showExample];
    XCTAssertEqual(demo.rootPopup.superview, window);
    for (UIGestureRecognizer *gesture in gestures) XCTAssertFalse(gesture.enabled);
    UIButton *close = (UIButton *)[self findView:@"demo.popupClose" inView:demo.rootPopup];
    XCTAssertNotNil(close);
    [close sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertNil(demo.rootPopup);
    for (UIGestureRecognizer *gesture in gestures) XCTAssertTrue(gesture.enabled);
    [navigation.view removeFromSuperview];
}
- (void)testLocalWebPagesSupportHistory {
    XYMFeatureViewController *demo = [self demo:XYMDemoFeatureWeb];
    [demo showExample];
    XYMPopWindowWebView *popup = (XYMPopWindowWebView *)demo.rootPopup;
    XCTAssertTrue([popup isKindOfClass:XYMPopWindowWebView.class]);
    NSPredicate *indexReady = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return !popup.webView.loading && [popup.webView.URL.lastPathComponent isEqualToString:@"XYMDemoIndex.html"];
    }];
    [self expectationForPredicate:indexReady evaluatedWithObject:popup handler:nil];
    [self waitForExpectationsWithTimeout:15 handler:nil];
    [popup.webView evaluateJavaScript:@"document.querySelector('a').click()" completionHandler:nil];
    NSPredicate *detailReady = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return !popup.webView.loading && [popup.webView.URL.lastPathComponent isEqualToString:@"XYMDemoDetail.html"];
    }];
    [self expectationForPredicate:detailReady evaluatedWithObject:popup handler:nil];
    [self waitForExpectationsWithTimeout:15 handler:nil];
    XCTAssertTrue(popup.webView.canGoBack);
    [self tap:@"demo.webBack" demo:demo];
    [self expectationForPredicate:indexReady evaluatedWithObject:popup handler:nil];
    [self waitForExpectationsWithTimeout:15 handler:nil];
    XCTAssertTrue(popup.webView.canGoForward);
    XCTAssertTrue([demo.eventLog containsString:@"web.finished"]);
    [demo closeExample];
}
- (void)testVisibleControlsAndPreviewSnapshots {
    UIWindowScene *scene = nil;
    UIWindow *previousWindow = nil;
    for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
        if (![candidate isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *window in ((UIWindowScene *)candidate).windows) {
            if (window.isKeyWindow) { scene = (UIWindowScene *)candidate; previousWindow = window; break; }
        }
        if (scene) break;
    }
    XCTAssertNotNil(scene);
    if (!scene) return;
    XYMFeatureViewController *demo = nil;
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
    @try {
        for (NSInteger feature = 0; feature < XYMDemoFeatureCount; feature++) {
            demo = [self demo:feature];
            window.rootViewController = [[UINavigationController alloc] initWithRootViewController:demo];
            [window makeKeyAndVisible];
            [window layoutIfNeeded];
            [demo showExample];
            if (feature == XYMDemoFeatureWeb) {
                NSPredicate *loaded = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
                    return [demo.eventLog containsString:@"web.finished: XYMDemoIndex.html"];
                }];
                [self expectationForPredicate:loaded evaluatedWithObject:demo handler:nil];
                [self waitForExpectationsWithTimeout:15 handler:nil];
            }
            [self attachSnapshotOfWindow:window name:[NSString stringWithFormat:@"SinglePage-%ld", (long)feature]];
            [demo closeExample];
        }
    } @finally {
        [demo closeExample];
        window.hidden = YES;
        window.rootViewController = nil;
        [previousWindow makeKeyWindow];
    }
}
- (void)attachSnapshotOfWindow:(UIWindow *)window name:(NSString *)name {
    [window layoutIfNeeded];
    // 真实窗口合成才能可靠绘制系统材质，不能用 layer renderInContext 替代。
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithBounds:window.bounds];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES];
    }];
    XCTAttachment *attachment = [XCTAttachment attachmentWithImage:image];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}
@end
