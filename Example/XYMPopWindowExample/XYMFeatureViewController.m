// XYMFeatureViewController.m — Interactive feature demonstrations. Created by Xuyiming.
#import "XYMFeatureViewController.h"
#import "XYMDemoContentView.h"
#import <Masonry/Masonry.h>

// StackView 的最终尺寸可能晚于控制器布局回调，预览区尺寸落定后再同步弹窗。
@interface XYMDemoPreviewView : UIView
@property (nonatomic, copy) void (^sizeDidChange)(void);
@property (nonatomic, assign) CGSize reportedSize;
@end
@implementation XYMDemoPreviewView
- (void)layoutSubviews {
    [super layoutSubviews];
    if (CGSizeEqualToSize(self.reportedSize, self.bounds.size)) return;
    self.reportedSize = self.bounds.size;
    if (self.sizeDidChange) self.sizeDidChange();
}
@end

@interface XYMFeatureViewController () <WKNavigationDelegate>
@property (nonatomic, assign, readwrite) XYMDemoFeature feature;
@property (nonatomic, strong, readwrite) XYMBasicPopWindowView *rootPopup;
@property (nonatomic, copy, readwrite) NSString *eventLog;
@property (nonatomic, strong) UIView *previewHost;
@property (nonatomic, strong) UIStackView *pageStack;
@property (nonatomic, strong) UIStackView *controls;
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, strong) UISwitch *animationSwitch;
@property (nonatomic, strong) UISwitch *panSwitch;
@property (nonatomic, strong) UISwitch *headerSwitch;
@property (nonatomic, strong) UISwitch *backgroundSwitch;
@property (nonatomic, strong) UISwitch *sideSwitch;
@property (nonatomic, strong) UISlider *heightSlider;
@property (nonatomic, strong) UISlider *radiusSlider;
@property (nonatomic, strong) UISlider *shadeSlider;
@property (nonatomic, strong) UISegmentedControl *contentChoice;
@property (nonatomic, strong) UISegmentedControl *hostChoice;
@property (nonatomic, strong) UISegmentedControl *insetChoice;
@property (nonatomic, assign) BOOL transitioning;
@property (nonatomic, assign) NSUInteger eventNumber;
@property (nonatomic, assign) CGFloat popupHeightRatio;
@property (nonatomic, assign) CGSize lastHostSize;
@property (nonatomic, assign) BOOL popupHidden;
@property (nonatomic, weak) UIGestureRecognizer *edgeBackGesture;
@property (nonatomic, weak) UIGestureRecognizer *contentBackGesture;
@property (nonatomic, assign) BOOL edgeBackWasEnabled;
@property (nonatomic, assign) BOOL contentBackWasEnabled;
@property (nonatomic, assign) BOOL navigationBackBlocked;
@end

@implementation XYMFeatureViewController
+ (NSArray<NSString *> *)featureTitles {
    return @[@"外观配置", @"动画与显隐", @"手势控制", @"背景交互", @"多层弹窗", @"滚动联动", @"内容与容器", @"网页与回调"];
}
+ (NSArray<NSString *> *)featureDetails {
    return @[@"高度 / 圆角 / 遮罩 / 自定义内容", @"动画开关 / 隐藏 / 恢复 / 关闭", @"下拉关闭 / 仅顶部拖动", @"背景点击开关 / 遮罩透明度", @"不同高度 Push / Pop / 侧滑 / 全部关闭", @"长列表 / 顶部联动 / contentInset", @"真实 XIB / 约束高度 / 小容器与窗口", @"本地双页面 / 网页返回 / 生命周期日志"];
}
- (instancetype)initWithFeature:(XYMDemoFeature)feature {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _feature = feature;
        _eventLog = @"";
        _popupHeightRatio = 0.82;
        self.title = self.class.featureTitles[feature];
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    UIStackView *page = [[UIStackView alloc] init];
    self.pageStack = page;
    page.accessibilityIdentifier = @"demo.page";
    page.axis = UILayoutConstraintAxisVertical;
    page.alignment = UIStackViewAlignmentCenter;
    page.spacing = 6;
    page.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:page];
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [page.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:6],
        [page.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor constant:-6],
        [page.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [page.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
    UILabel *hint = [[UILabel alloc] init];
    hint.numberOfLines = 0;
    hint.font = [UIFont systemFontOfSize:11];
    hint.textColor = UIColor.secondaryLabelColor;
    hint.text = self.class.featureDetails[self.feature];
    [page addArrangedSubview:hint];

    // 单屏排布：控件保留完整尺寸，预览区使用余下空间，不再滚动整页。
    self.controls = [[UIStackView alloc] init];
    self.controls.axis = UILayoutConstraintAxisVertical;
    self.controls.spacing = 4;
    self.controls.layoutMarginsRelativeArrangement = YES;
    self.controls.layoutMargins = UIEdgeInsetsMake(6, 10, 6, 10);
    self.controls.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.controls.layer.cornerRadius = 12;
    self.controls.accessibilityIdentifier = @"demo.controls";
    [page addArrangedSubview:self.controls];
    self.animationSwitch = [self addSwitch:@"动画" identifier:@"demo.animation" enabled:YES];
    [self addButtons:@[@"显示", @"关闭"] identifiers:@[@"demo.show", @"demo.close"]
             actions:@[NSStringFromSelector(@selector(showExample)), NSStringFromSelector(@selector(closeExample))]];
    // 动画开关与两个主按钮放在同一行，节省一整行而不缩放系统开关。
    UIStackView *commonRow = (UIStackView *)self.controls.arrangedSubviews.firstObject;
    UIView *actionsRow = self.controls.arrangedSubviews.lastObject;
    [self.controls removeArrangedSubview:actionsRow];
    [actionsRow removeFromSuperview];
    [commonRow addArrangedSubview:actionsRow];
    [actionsRow.widthAnchor constraintEqualToAnchor:commonRow.widthAnchor multiplier:0.55].active = YES;
    [self buildFeatureControls];

    XYMDemoPreviewView *preview = [[XYMDemoPreviewView alloc] init];
    __weak typeof(self) weakSelf = self;
    preview.sizeDidChange = ^{ [weakSelf updatePopupSizes]; };
    self.previewHost = preview;
    self.previewHost.accessibilityIdentifier = @"demo.preview";
    self.previewHost.backgroundColor = UIColor.tertiarySystemBackgroundColor;
    self.previewHost.layer.cornerRadius = 12;
    self.previewHost.clipsToBounds = YES;
    [page addArrangedSubview:self.previewHost];
    [self.previewHost.heightAnchor constraintGreaterThanOrEqualToConstant:0].active = YES;
    UILabel *placeholder = [[UILabel alloc] init];
    placeholder.text = @"弹窗预览区域\n点击上方「显示」开始";
    placeholder.numberOfLines = 2;
    placeholder.textAlignment = NSTextAlignmentCenter;
    placeholder.textColor = UIColor.secondaryLabelColor;
    [self.previewHost addSubview:placeholder];
    [placeholder mas_makeConstraints:^(MASConstraintMaker *make) { make.center.equalTo(self.previewHost); }];
    self.logView = [[UITextView alloc] init];
    self.logView.editable = NO;
    self.logView.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    self.logView.textContainerInset = UIEdgeInsetsMake(3, 5, 3, 5);
    self.logView.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.logView.accessibilityIdentifier = @"demo.events";
    [page addArrangedSubview:self.logView];
    // 仅预览区铺满页面宽度；说明、控件和日志仍保留原来的左右留白。
    [NSLayoutConstraint activateConstraints:@[
        [self.previewHost.widthAnchor constraintEqualToAnchor:page.widthAnchor],
        [hint.widthAnchor constraintEqualToAnchor:page.widthAnchor constant:-32],
        [self.controls.widthAnchor constraintEqualToAnchor:page.widthAnchor constant:-32],
        [self.logView.widthAnchor constraintEqualToAnchor:page.widthAnchor constant:-32]
    ]];
    [self.logView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(40);
    }];
    [self appendEvent:@"准备就绪：参数可实时调整；内容和容器切换后重新显示"];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self.pageStack layoutIfNeeded];
    [self updatePopupSizes];
}
- (UIView *)popupHost {
    if (self.hostChoice.selectedSegmentIndex == 1 && self.view.window) return self.view.window;
    return self.previewHost;
}
- (CGFloat)heightForLevel:(NSUInteger)level {
    CGFloat ratio = self.popupHeightRatio;
    if (self.feature == XYMDemoFeatureNested && level > 0) ratio = level % 2 ? 0.90 : 0.68;
    return CGRectGetHeight([self popupHost].bounds) * ratio;
}
- (void)applyHeight:(CGFloat)height toPopup:(XYMBasicPopWindowView *)popup {
    UIView *content = [popup.popView viewWithTag:7301] ?: [popup.popView viewWithTag:7302];
    if (self.popupHidden) popup.popView.transform = CGAffineTransformIdentity;
    if (content) {
        // XIB 和约束内容仍由自身约束推导高度，不与 popView_height 混用。
        for (NSLayoutConstraint *constraint in content.constraints) {
            if ([constraint.identifier isEqualToString:@"demo.contentHeight"]) constraint.constant = height;
        }
    } else {
        popup.popView_height = height;
    }
    [popup setNeedsLayout];
    [popup layoutIfNeeded];
    if ([self childPopup:popup]) {
        CGRect frame = popup.popView.frame;
        frame.origin.x = -CGRectGetWidth(popup.bounds) / 3;
        popup.popView.frame = frame;
    }
    if (self.popupHidden) popup.popView.transform = CGAffineTransformMakeTranslation(0, height);
}
- (void)updatePopupSizes {
    UIView *host = [self popupHost];
    if (self.transitioning || host.bounds.size.height <= 0 || CGSizeEqualToSize(self.lastHostSize, host.bounds.size)) return;
    self.lastHostSize = host.bounds.size;
    self.heightSlider.minimumValue = host.bounds.size.height * 0.45;
    self.heightSlider.maximumValue = host.bounds.size.height * 0.95;
    self.heightSlider.value = [self heightForLevel:0];
    if (self.heightSlider) [self updateSliderLabel:self.heightSlider];
    for (XYMBasicPopWindowView *popup = self.rootPopup; popup; popup = [self childPopup:popup]) {
        [self applyHeight:[self heightForLevel:popup.popIndex] toPopup:popup];
    }
}

- (void)buildFeatureControls {
    switch (self.feature) {
        case XYMDemoFeatureAppearance:
            self.heightSlider = [self addSlider:@"高度" identifier:@"demo.height" minimum:189 maximum:399 value:344.4];
            self.radiusSlider = [self addSlider:@"圆角" identifier:@"demo.radius" minimum:0 maximum:36 value:16];
            self.shadeSlider = [self addSlider:@"遮罩" identifier:@"demo.shade" minimum:0 maximum:0.8 value:0.35];
            self.contentChoice = [self addChoices:@[@"文字内容", @"彩色卡片"] identifier:@"demo.content"];
            break;
        case XYMDemoFeatureVisibility:
            [self addButtons:@[@"隐藏", @"恢复"] identifiers:@[@"demo.hide", @"demo.restore"]
                     actions:@[NSStringFromSelector(@selector(hideExample)), NSStringFromSelector(@selector(restoreExample))]];
            break;
        case XYMDemoFeatureGestures:
            self.panSwitch = [self addSwitch:@"允许下拉关闭" identifier:@"demo.pan" enabled:YES];
            self.headerSwitch = [self addSwitch:@"只允许顶部 32pt 拖动" identifier:@"demo.header" enabled:NO];
            break;
        case XYMDemoFeatureBackground:
            self.backgroundSwitch = [self addSwitch:@"点击背景关闭（非触摸穿透）" identifier:@"demo.background" enabled:YES];
            self.shadeSlider = [self addSlider:@"遮罩" identifier:@"demo.shade" minimum:0 maximum:0.8 value:0.35];
            break;
        case XYMDemoFeatureNested:
            self.sideSwitch = [self addSwitch:@"允许左边缘右滑返回" identifier:@"demo.side" enabled:YES];
            [self addButtons:@[@"Push 一层", @"Pop 一层", @"全部关闭"]
                 identifiers:@[@"demo.push", @"demo.pop", @"demo.closeAll"]
                     actions:@[NSStringFromSelector(@selector(pushExample)), NSStringFromSelector(@selector(popExample)), NSStringFromSelector(@selector(closeExample))]];
            break;
        case XYMDemoFeatureScroll:
            self.insetChoice = [self addChoices:@[@"顶部 inset = 0", @"顶部 inset = 24"] identifier:@"demo.inset"];
            [self addButtons:@[@"列表回到顶部"] identifiers:@[@"demo.scrollTop"] actions:@[NSStringFromSelector(@selector(scrollToTop))]];
            break;
        case XYMDemoFeatureContent:
            self.contentChoice = [self addChoices:@[@"真实 XIB", @"代码约束高度"] identifier:@"demo.content"];
            self.hostChoice = [self addChoices:@[@"预览区域", @"当前窗口"] identifier:@"demo.host"];
            break;
        case XYMDemoFeatureWeb:
            [self addButtons:@[@"网页后退", @"网页前进", @"刷新"] identifiers:@[@"demo.webBack", @"demo.webForward", @"demo.reload"]
                     actions:@[NSStringFromSelector(@selector(webBack)), NSStringFromSelector(@selector(webForward)), NSStringFromSelector(@selector(webReload))]];
            break;
        default: break;
    }
}

- (UIStackView *)rowWithLabel:(NSString *)text control:(UIView *)control {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = [UIFont systemFontOfSize:12];
    label.numberOfLines = 2;
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[label, control]];
    row.spacing = 6;
    row.alignment = UIStackViewAlignmentCenter;
    row.layoutMarginsRelativeArrangement = YES;
    // 系统开关的实际 frame 会略超出 alignment rect，行内保留少量水平余量。
    row.layoutMargins = UIEdgeInsetsMake(2, 4, 2, 4);
    [row.heightAnchor constraintGreaterThanOrEqualToConstant:32].active = YES;
    [self.controls addArrangedSubview:row];
    return row;
}
- (UISwitch *)addSwitch:(NSString *)text identifier:(NSString *)identifier enabled:(BOOL)enabled {
    UISwitch *control = [[UISwitch alloc] init];
    control.on = enabled;
    control.accessibilityIdentifier = identifier;
    // Switch 必须保持系统固有尺寸，不能被水平 StackView 拉伸或压缩。
    [control setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [control setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [control setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [control setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [control addTarget:self action:@selector(settingsChanged:) forControlEvents:UIControlEventValueChanged];
    [self rowWithLabel:text control:control];
    return control;
}
- (UISlider *)addSlider:(NSString *)text identifier:(NSString *)identifier minimum:(float)minimum maximum:(float)maximum value:(float)value {
    UISlider *control = [[UISlider alloc] init];
    control.minimumValue = minimum;
    control.maximumValue = maximum;
    control.value = value;
    control.accessibilityIdentifier = identifier;
    control.accessibilityLabel = text;
    [control.heightAnchor constraintGreaterThanOrEqualToConstant:32].active = YES;
    [control addTarget:self action:@selector(settingsChanged:) forControlEvents:UIControlEventValueChanged];
    UIStackView *row = [self rowWithLabel:text control:control];
    [control.widthAnchor constraintEqualToAnchor:row.widthAnchor multiplier:0.60].active = YES;
    [self updateSliderLabel:control];
    return control;
}
- (UISegmentedControl *)addChoices:(NSArray<NSString *> *)items identifier:(NSString *)identifier {
    UISegmentedControl *control = [[UISegmentedControl alloc] initWithItems:items];
    control.selectedSegmentIndex = 0;
    control.accessibilityIdentifier = identifier;
    [control.heightAnchor constraintGreaterThanOrEqualToConstant:32].active = YES;
    [control setTitleTextAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:12]} forState:UIControlStateNormal];
    [control addTarget:self action:@selector(settingsChanged:) forControlEvents:UIControlEventValueChanged];
    [self.controls addArrangedSubview:control];
    return control;
}
- (void)addButtons:(NSArray<NSString *> *)titles identifiers:(NSArray<NSString *> *)identifiers actions:(NSArray<NSString *> *)actions {
    UIStackView *row = [[UIStackView alloc] init];
    row.distribution = UIStackViewDistributionFillEqually;
    row.spacing = 4;
    for (NSUInteger index = 0; index < titles.count; index++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        UIButtonConfiguration *configuration = [UIButtonConfiguration tintedButtonConfiguration];
        configuration.attributedTitle = [[NSAttributedString alloc] initWithString:titles[index]
            attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold]}];
        configuration.buttonSize = UIButtonConfigurationSizeSmall;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(4, 6, 4, 6);
        button.configuration = configuration;
        button.titleLabel.numberOfLines = 2;
        button.accessibilityIdentifier = identifiers[index];
        [button addTarget:self action:NSSelectorFromString(actions[index]) forControlEvents:UIControlEventTouchUpInside];
        [button.heightAnchor constraintGreaterThanOrEqualToConstant:32].active = YES;
        [row addArrangedSubview:button];
    }
    [self.controls addArrangedSubview:row];
}
- (void)updateSliderLabel:(UISlider *)slider {
    UILabel *label = (UILabel *)slider.superview.subviews.firstObject;
    if ([label isKindOfClass:UILabel.class]) {
        label.text = [NSString stringWithFormat:@"%@ %.2f", slider.accessibilityLabel, slider.value];
    }
}
- (void)settingsChanged:(UIControl *)sender {
    if ([sender isKindOfClass:UISlider.class]) [self updateSliderLabel:(UISlider *)sender];
    if (sender == self.heightSlider && [self popupHost].bounds.size.height > 0) {
        self.popupHeightRatio = self.heightSlider.value / [self popupHost].bounds.size.height;
        [self applyHeight:[self heightForLevel:0] toPopup:self.rootPopup];
    }
    if ([sender isKindOfClass:UISegmentedControl.class]) {
        // 内容高度来源可能不同，切换时重建，避免混用固定高度和 XIB 约束。
        BOOL visible = self.rootPopup != nil;
        [self removeCurrentImmediately];
        if (visible) [self showExample];
    } else {
        for (XYMBasicPopWindowView *popup = self.rootPopup; popup; popup = [self childPopup:popup]) {
            [self applySettings:popup];
        }
    }
}
- (void)applySettings:(XYMBasicPopWindowView *)popup {
    // 背景点击由组件内部处理，因此也要同步当前动画开关，而非仅给按钮方法传参。
    popup.backgroundDismissAnimated = self.animationSwitch.on;
    popup.popView_header_Radius = self.radiusSlider ? self.radiusSlider.value : 16;
    popup.bgButton_Color_Alpha = self.shadeSlider ? self.shadeSlider.value : 0.35;
    popup.bgButton_Enable = self.backgroundSwitch ? self.backgroundSwitch.on : YES;
    popup.canPanPopView = self.panSwitch ? self.panSwitch.on : self.feature != XYMDemoFeatureWeb;
    popup.isOnlyHeaderPan = self.headerSwitch.on;
    popup.canLeftPanBack = self.sideSwitch.on && popup.popIndex > 0;
}
- (XYMBasicPopWindowView *)makePopup {
    XYMBasicPopWindowView *popup;
    if (self.feature == XYMDemoFeatureWeb) {
        XYMPopWindowWebView *web = [[XYMPopWindowWebView alloc] initWithTitle:@"本地网页 · 返回 / 关闭" url:[NSURL URLWithString:@"about:blank"]];
        web.webView.navigationDelegate = self;
        NSURL *url = [NSBundle.mainBundle URLForResource:@"XYMDemoIndex" withExtension:@"html"];
        if (url) [web.webView loadFileURL:url allowingReadAccessToURL:url.URLByDeletingLastPathComponent];
        else [self appendEvent:@"错误：缺少本地 HTML 资源"];
        popup = web;
    } else {
        popup = [[XYMBasicPopWindowView alloc] init];
        if (self.feature == XYMDemoFeatureContent && self.contentChoice.selectedSegmentIndex == 0) {
            UIView *content = [[UINib nibWithNibName:@"XYMDemoContent" bundle:NSBundle.mainBundle] instantiateWithOwner:nil options:nil].firstObject;
            [popup addXibViewToPopView:content];
        } else {
            BOOL scrolling = self.feature == XYMDemoFeatureScroll;
            CGFloat inset = self.insetChoice.selectedSegmentIndex == 1 ? 24 : 0;
            XYMDemoContentView *content = [[XYMDemoContentView alloc] initWithText:self.title scrolling:scrolling inset:inset];
            if (self.feature == XYMDemoFeatureContent) {
                content.tag = 7302;
                // addXibViewToPopView: 会重建 Masonry 约束，内容自身高度用原生约束保留。
                NSLayoutConstraint *height = [content.heightAnchor constraintEqualToConstant:[self heightForLevel:0]];
                height.identifier = @"demo.contentHeight";
                height.active = YES;
                [popup addXibViewToPopView:content];
            } else {
                [popup.popView addSubview:content];
                [content mas_makeConstraints:^(MASConstraintMaker *make) { make.edges.equalTo(popup.popView); }];
            }
            if (scrolling) popup.linkScrollView = content.tableView;
            if (self.feature == XYMDemoFeatureAppearance && self.contentChoice.selectedSegmentIndex == 1) {
                content.backgroundColor = [UIColor.systemTealColor colorWithAlphaComponent:0.25];
            }
        }
        UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
        [close setTitle:@"关闭本层" forState:UIControlStateNormal];
        close.titleLabel.font = [UIFont systemFontOfSize:12];
        close.accessibilityIdentifier = @"demo.popupClose";
        [close addTarget:self action:@selector(popExample) forControlEvents:UIControlEventTouchUpInside];
        [popup.popView addSubview:close];
        [close mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(popup.popView).offset(32);
            make.right.equalTo(popup.popView).offset(-12);
            make.width.mas_equalTo(68);
            make.height.mas_equalTo(24);
        }];
    }
    [self applySettings:popup];
    [self applyHeight:[self heightForLevel:0] toPopup:popup];
    __weak typeof(self) weakSelf = self;
    __weak XYMBasicPopWindowView *weakPopup = popup;
    popup.dismissBlock = ^(BOOL finished) {
        [weakSelf appendEvent:finished ? @"dismiss.finished" : @"dismiss.start"];
        if (finished && weakSelf.rootPopup == weakPopup) {
            weakSelf.rootPopup = nil;
            [weakSelf restoreNavigationBack];
        }
    };
    return popup;
}
- (void)showExample {
    if (self.transitioning) return;
    [self loadViewIfNeeded];
    [self removeCurrentImmediately];
    [self.view layoutIfNeeded];
    [self updatePopupSizes];
    UIView *host = self.previewHost;
    if (self.hostChoice.selectedSegmentIndex == 1) {
        if (self.view.window) host = self.view.window;
        else [self appendEvent:@"当前无窗口，使用预览区域"];
    }
    self.rootPopup = [self makePopup];
    [self blockNavigationBack];
    [self beginTransition];
    __weak typeof(self) weakSelf = self;
    [self.rootPopup showIn:host animation:self.animationSwitch.on completion:^{
        [weakSelf finishTransition:@"show.completion"];
    }];
}
- (void)closeExample {
    if (self.transitioning || !self.rootPopup) return;
    [self beginTransition];
    __weak typeof(self) weakSelf = self;
    [self.rootPopup disMissAllView:self.animationSwitch.on completion:^{
        [weakSelf finishTransition:@"dismiss.completion"];
    }];
}
- (void)hideExample { [self changeVisibility:YES]; }
- (void)restoreExample { [self changeVisibility:NO]; }
- (void)changeVisibility:(BOOL)hidden {
    if (self.transitioning || !self.rootPopup) return;
    self.popupHidden = hidden;
    [self beginTransition];
    __weak typeof(self) weakSelf = self;
    [self.rootPopup setHidden:hidden animation:self.animationSwitch.on completion:^{
        [weakSelf finishTransition:hidden ? @"hide.completion" : @"restore.completion"];
    }];
}
- (XYMBasicPopWindowView *)childPopup:(XYMBasicPopWindowView *)popup {
    for (UIView *view in popup.subviews.reverseObjectEnumerator) {
        if ([view isKindOfClass:XYMBasicPopWindowView.class]) return (XYMBasicPopWindowView *)view;
    }
    return nil;
}
- (XYMBasicPopWindowView *)topPopup {
    XYMBasicPopWindowView *top = self.rootPopup;
    while ([self childPopup:top]) top = [self childPopup:top];
    return top;
}
- (void)pushExample {
    if (self.transitioning) return;
    if (!self.rootPopup) { [self showExample]; return; }
    XYMBasicPopWindowView *top = [self topPopup];
    XYMBasicPopWindowView *child = [self makePopup];
    [self applyHeight:[self heightForLevel:top.popIndex + 1] toPopup:child];
    [self beginTransition];
    __weak typeof(self) weakSelf = self;
    [top pushView:child animation:self.animationSwitch.on completion:^{
        [weakSelf finishTransition:@"push.completion"];
    }];
    // pushView 默认开启侧滑，示例开关需要在 push 之后重新应用。
    child.canLeftPanBack = self.sideSwitch.on;
}
- (void)popExample {
    if (self.transitioning || !self.rootPopup) return;
    [self beginTransition];
    __weak typeof(self) weakSelf = self;
    [[self topPopup] popViewAnimation:self.animationSwitch.on completion:^{
        [weakSelf finishTransition:@"pop.completion"];
    }];
}
- (void)scrollToTop {
    UIScrollView *scroll = self.rootPopup.linkScrollView;
    if (!scroll) return;
    [scroll setContentOffset:CGPointMake(0, -scroll.adjustedContentInset.top) animated:self.animationSwitch.on];
    [self appendEvent:@"列表已请求滚动到顶部；继续下拉可关闭"];
}
- (WKWebView *)currentWebView {
    return [self.rootPopup isKindOfClass:XYMPopWindowWebView.class] ? ((XYMPopWindowWebView *)self.rootPopup).webView : nil;
}
- (void)webBack {
    WKWebView *web = [self currentWebView];
    if (web.canGoBack) [web goBack];
    else [self appendEvent:@"网页已在首页；弹窗内返回按钮会关闭弹窗"];
}
- (void)webForward {
    WKWebView *web = [self currentWebView];
    if (web.canGoForward) [web goForward];
    else [self appendEvent:@"没有可前进的网页"];
}
- (void)webReload { [[self currentWebView] reload]; }
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    if (webView == [self currentWebView]) [self appendEvent:[@"web.finished: " stringByAppendingString:webView.URL.lastPathComponent ?: @""]];
}
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (webView == [self currentWebView]) [self appendEvent:[@"web.error: " stringByAppendingString:error.localizedDescription]];
}
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (error.code != NSURLErrorCancelled) [self webView:webView didFailNavigation:navigation withError:error];
}
- (void)beginTransition {
    self.transitioning = YES;
    self.controls.userInteractionEnabled = NO;
}
- (void)finishTransition:(NSString *)event {
    self.transitioning = NO;
    self.controls.userInteractionEnabled = YES;
    [self updatePopupSizes];
    [self appendEvent:event];
}
- (void)appendEvent:(NSString *)event {
    self.eventNumber++;
    NSString *line = [NSString stringWithFormat:@"%lu. %@", (unsigned long)self.eventNumber, event];
    NSArray *lines = [[self.eventLog stringByAppendingFormat:@"\n%@", line] componentsSeparatedByString:@"\n"];
    if (lines.count > 50) lines = [lines subarrayWithRange:NSMakeRange(lines.count - 50, 50)];
    self.eventLog = [lines componentsJoinedByString:@"\n"];
    self.logView.text = self.eventLog;
    if (self.eventLog.length) [self.logView scrollRangeToVisible:NSMakeRange(self.eventLog.length - 1, 1)];
}
- (void)removeCurrentImmediately {
    [self.rootPopup disMissAllView:NO completion:nil];
    self.rootPopup = nil;
    self.popupHidden = NO;
    self.lastHostSize = CGSizeZero;
    self.transitioning = NO;
    self.controls.userInteractionEnabled = YES;
    [self restoreNavigationBack];
}
- (void)blockNavigationBack {
    UINavigationController *navigation = self.navigationController;
    if (!navigation) return;
    if (!self.navigationBackBlocked) {
        // 只在本次弹窗首次显示时保存状态，避免重复调用把“原状态”覆盖为禁用。
        self.edgeBackGesture = navigation.interactivePopGestureRecognizer;
        self.edgeBackWasEnabled = self.edgeBackGesture.enabled;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
        if (@available(iOS 26.0, *)) {
            self.contentBackGesture = navigation.interactiveContentPopGestureRecognizer;
            self.contentBackWasEnabled = self.contentBackGesture.enabled;
        }
#endif
        self.navigationBackBlocked = YES;
    }
    // 同时禁用边缘返回与 iOS 26+ 内容区返回，不改弹窗自身的嵌套侧滑手势。
    self.edgeBackGesture.enabled = NO;
    self.contentBackGesture.enabled = NO;
}
- (void)restoreNavigationBack {
    if (!self.navigationBackBlocked) return;
    self.edgeBackGesture.enabled = self.edgeBackWasEnabled;
    self.contentBackGesture.enabled = self.contentBackWasEnabled;
    self.edgeBackGesture = nil;
    self.contentBackGesture = nil;
    self.navigationBackBlocked = NO;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.rootPopup) [self blockNavigationBack];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // 导航转场完成后再确认一次，原始状态仍只保存一次。
    if (self.rootPopup) [self blockNavigationBack];
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    // 其他页面复用同一导航控制器，离开当前页面后不能继续占用返回手势。
    [self restoreNavigationBack];
    if (self.isMovingFromParentViewController || self.navigationController.isBeingDismissed) {
        // 挂到 UIWindow 的内容不属于控制器视图，离开示例时需显式移除。
        [self removeCurrentImmediately];
    }
}
@end
