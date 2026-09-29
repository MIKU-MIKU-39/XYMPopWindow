// XYMBasicPopWindowView.m — Reusable popup component. Created by Xuyiming.

#import "XYMBasicPopWindowView.h"
#import <Masonry/Masonry.h>

static void *XYMPopScrollObservationContext = &XYMPopScrollObservationContext;

// 文件内的几何辅助函数，避免依赖主工程 UIView 分类。
static void XYMPopSetX(UIView *view, CGFloat x) {
    CGRect frame = view.frame;
    frame.origin.x = x;
    view.frame = frame;
}

static void XYMPopSetY(UIView *view, CGFloat y) {
    CGRect frame = view.frame;
    frame.origin.y = y;
    view.frame = frame;
}

@interface XYMBasicPopWindowView ()<UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIButton * bgButton;
@property (nonatomic, strong) UIView * topPanView;
@property (nonatomic, strong) UIPanGestureRecognizer * pan;
@property (nonatomic, strong) UIScreenEdgePanGestureRecognizer * leftPan;
@property (nonatomic, assign) BOOL isScroll;

@property (nonatomic, assign) NSUInteger popIndex;

@property (nonatomic, strong) NSHashTable<XYMBasicPopWindowView *> * views;
@property (nonatomic, assign) BOOL popView_hidden;

@property (nonatomic, assign) BOOL isAddXib;
@property (nonatomic, assign) CGSize lastLayoutSize;
@property (nonatomic, assign) BOOL originalScrollBounces;
@property (nonatomic, assign) BOOL isDismissing;
@property (nonatomic, strong) NSMutableArray *dismissCompletions;
@property (nonatomic, assign) CGRect sidePanParentFrame;
@property (nonatomic, assign) CGRect sidePanCardFrame;
@property (nonatomic, assign) CGFloat sidePanTranslation;
@property (nonatomic, assign) BOOL sidePanActive;
@end

@implementation XYMBasicPopWindowView

- (instancetype)init{
    return [self initWithFrame:UIScreen.mainScreen.bounds];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self constructUI];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) [self constructUI];
    return self;
}

- (void)awakeFromNib{
    [super awakeFromNib];
    [self constructUI];
}

- (void)viewDidFirstAppear{
    NSLog(@"%@第一次出现",NSStringFromClass([self class]));
}

- (void)addXibViewToPopView:(UIView *)xibView{
    // UIKit 会解除与旧父视图的约束；保留内容自身的高度等内部约束。
    // 原来的 nil 父视图比较会误删 secondItem == nil 的固定高度约束。
    [xibView removeFromSuperview];
    [self.popView addSubview:xibView];
    [xibView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.popView);
    }];
    [self.popView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.bottom.left.right.equalTo(self);
    }];
    self.isAddXib = YES;
}

- (void)showIn:(UIView *)superView animation:(BOOL)animation completion:(void(^ __nullable)(void))completion{
    if(![superView.subviews containsObject:self]) [superView addSubview:self];
    self.frame = superView.bounds;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self setNeedsLayout];
    [self layoutIfNeeded];
    self.popView_hidden = NO;
    self.popView.alpha = 1;
    self.popView.transform = CGAffineTransformIdentity;
    XYMPopSetX(self.popView, 0);
    self.backgroundDismissAnimated = animation;
    if(animation){
        // 使用 transform，避免 Auto Layout 在动画中把 XIB 内容拉回原位。
        self.popView.transform = CGAffineTransformMakeTranslation(0, CGRectGetHeight(self.popView.bounds));
        [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:1 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.popView.transform = CGAffineTransformIdentity;
            self.bgButton.alpha = 1;
        } completion:^(BOOL finished) {
            [self viewDidFirstAppear];
            if(completion) completion();
        }];
    }else{
        XYMPopSetY(self.popView, CGRectGetHeight(self.bounds) - CGRectGetHeight(self.popView.frame));
        self.bgButton.alpha = 1;
        [self viewDidFirstAppear];
        if(completion) completion();
    }
}

- (void)setHidden:(BOOL)hidden animation:(BOOL)animation completion:(void(^)(void))completion;{
    if(self.popView_hidden == hidden) {
        if (completion) completion();
        return;
    }
    else self.popView_hidden = hidden;
    if(animation){
        [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:1 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            [self.views.allObjects enumerateObjectsUsingBlock:^(XYMBasicPopWindowView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                obj.popView.transform = CGAffineTransformMakeTranslation(0, hidden ? CGRectGetHeight(obj.popView.bounds) : 0);
            }];
            self.bgButton.alpha = !hidden;
        } completion:^(BOOL finished) {
            if(completion) completion();
        }];
    }else{
        [self.views.allObjects enumerateObjectsUsingBlock:^(XYMBasicPopWindowView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            obj.popView.transform = CGAffineTransformMakeTranslation(0, hidden ? CGRectGetHeight(obj.popView.bounds) : 0);
        }];
        self.bgButton.alpha = !hidden;
        if(completion) completion();
    }
}

- (void)disMissAnimation:(BOOL)animation completion:(void(^ __nullable)(void))completion{
    self.linkScrollView = nil;
    
    if([self.superview isKindOfClass:XYMBasicPopWindowView.class]){
        [self popViewAnimation:animation completion:completion];
        return;
    }
    if (![self beginDismissalWithCompletion:completion]) return;
    if (self.dismissBlock) {
        self.dismissBlock(NO);
    }
    if(animation){
        [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:1 initialSpringVelocity:0 options:UIViewAnimationOptionCurveLinear animations:^{
            self.popView.transform = CGAffineTransformMakeTranslation(0, CGRectGetHeight(self.popView.bounds));
            self.bgButton.alpha = 0;
        } completion:^(BOOL finished) {
            [self removeFromSuperview];
            [self completeDismissal];
        }];
    }else{
        [self removeFromSuperview];
        [self completeDismissal];
    }
}

- (BOOL)beginDismissalWithCompletion:(void (^)(void))completion {
    if (!self.superview) {
        if (completion) completion();
        return NO;
    }
    if (!self.dismissCompletions) self.dismissCompletions = [NSMutableArray array];
    if (completion) [self.dismissCompletions addObject:[completion copy]];
    // 连续关闭合并为一次动画，但每次调用的 completion 都保留。
    if (self.isDismissing) return NO;
    self.isDismissing = YES;
    return YES;
}

- (void)completeDismissal {
    NSArray *callbacks = [self.dismissCompletions copy];
    [self.dismissCompletions removeAllObjects];
    self.isDismissing = NO;
    if (self.dismissBlock) self.dismissBlock(YES);
    for (void (^callback)(void) in callbacks) callback();
}

- (void)moveCardToOrigin:(CGPoint)origin {
    if (self.popView.translatesAutoresizingMaskIntoConstraints) {
        CGRect frame = self.popView.frame;
        frame.origin = origin;
        self.popView.frame = frame;
    } else {
        // XIB/约束内容的基准位置仍由约束决定，转场用 transform，避免下一次布局把位置拉回。
        CGFloat restingY = CGRectGetHeight(self.bounds) - CGRectGetHeight(self.popView.bounds);
        self.popView.transform = CGAffineTransformMakeTranslation(origin.x, origin.y - restingY);
    }
}

- (void)pushView:(__kindof XYMBasicPopWindowView *)pushView animation:(BOOL)animation completion:(void(^ __nullable)(void))completion{
    // Push 不经过 showIn:，也需保存子层点击背景返回时使用的动画选项。
    pushView.backgroundDismissAnimated = animation;
    pushView.frame = CGRectMake(CGRectGetWidth(self.bounds), 0, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
    pushView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    pushView.popIndex = self.popIndex + 1;
    pushView.canLeftPanBack = YES;
    if(![self.views containsObject:self]) [self.views addObject:self];
    for (XYMBasicPopWindowView * view in self.views) {
        [pushView.views addObject:view];
    }
    [pushView.views addObject:pushView];
    [self addSubview:pushView];
    if (self.isAddXib) [self layoutIfNeeded];
    // 子弹窗可能按屏幕尺寸初始化，先完成宿主尺寸布局，再计算转场位置。
    [pushView setNeedsLayout];
    [pushView layoutIfNeeded];
    self.bgButton.frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds) * 2, CGRectGetHeight(self.bounds));
    pushView.bgButton.frame = CGRectMake(-CGRectGetWidth(self.bounds), 0, CGRectGetWidth(self.bounds) * 2, CGRectGetHeight(self.bounds));
    if(animation){
        [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:1 initialSpringVelocity:0 options:UIViewAnimationOptionCurveLinear animations:^{
            CGFloat parentY = CGRectGetMinY(self.popView.frame);
            if(CGRectGetHeight(self.popView.frame) > CGRectGetHeight(pushView.popView.frame)){
                parentY = CGRectGetMinY(pushView.popView.frame) + 44;
            }
            [self moveCardToOrigin:CGPointMake(-CGRectGetWidth(self.bounds) / 3, parentY)];
            XYMPopSetX(pushView, 0);
            self.bgButton.alpha = 0;
            pushView.bgButton.alpha = 1;
        } completion:^(BOOL finished) {
            pushView.bgButton.frame = CGRectMake( 0, 0, CGRectGetWidth(self.bounds),CGRectGetHeight(self.bounds));
            [pushView viewDidFirstAppear];
            self.bgButton.frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
            [UIView animateWithDuration:0.35 animations:^{
                self.popView.alpha = 0;
            }completion:nil];
            if(completion) completion();
        }];
    }else{
        // 无动画也必须应用动画分支的最终位置与遮罩状态。
        [self moveCardToOrigin:CGPointMake(-CGRectGetWidth(self.bounds) / 3, CGRectGetMinY(self.popView.frame))];
        XYMPopSetX(pushView, 0);
        self.popView.alpha = 0;
        self.bgButton.alpha = 0;
        pushView.bgButton.alpha = 1;
        self.bgButton.frame = self.bounds;
        pushView.bgButton.frame = pushView.bounds;
        [pushView viewDidFirstAppear];
        if(completion) completion();
    }
}

- (void)popViewAnimation:(BOOL)animation completion:(void(^ __nullable)(void))completion{
    // 根弹窗挂在普通 UIView 上，返回时按关闭处理，不能强转后访问私有属性。
    if (![self.superview isKindOfClass:XYMBasicPopWindowView.class]) {
        [self disMissAnimation:animation completion:completion];
        return;
    }
    if (![self beginDismissalWithCompletion:completion]) return;
    if (self.dismissBlock) self.dismissBlock(NO);
    self.linkScrollView = nil;
    XYMBasicPopWindowView * superView = (XYMBasicPopWindowView *)self.superview;
    superView.popView.alpha = 1;
    self.bgButton.frame = CGRectMake(- CGRectGetWidth(self.bounds), 0, CGRectGetWidth(self.bounds) * 2, CGRectGetHeight(self.bounds));
    superView.bgButton.frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds) * 2, CGRectGetHeight(self.bounds));
    [superView moveCardToOrigin:CGPointMake(-CGRectGetWidth(self.bounds) / 3, CGRectGetMinY(superView.popView.frame))];
    [self.views removeAllObjects];
    if(animation){
        [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:1 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            superView.bgButton.alpha = 1;
            self.bgButton.alpha = 0;
            [superView moveCardToOrigin:CGPointMake(0, CGRectGetHeight(self.bounds) - CGRectGetHeight(superView.popView.frame))];
            XYMPopSetX(self, CGRectGetWidth(self.bounds));
        } completion:^(BOOL finished) {
            superView.bgButton.frame = CGRectMake( 0, 0, CGRectGetWidth(self.bounds),CGRectGetHeight(self.bounds));
            self.bgButton.frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
            [self removeFromSuperview];
            [self completeDismissal];
        }];
    }else{
        superView.bgButton.alpha = 1;
        superView.bgButton.frame = superView.bounds;
        [superView moveCardToOrigin:CGPointMake(0, CGRectGetHeight(self.bounds) - CGRectGetHeight(superView.popView.frame))];
        [self removeFromSuperview];
        [self completeDismissal];
    }
}

- (void)disMissAllView:(BOOL)animation completion:(void(^ __nullable)(void))completion;{
    // 先找根节点并保存整组，不能在 removeFromSuperview 后继续追溯父节点。
    XYMBasicPopWindowView *root = self;
    while ([root.superview isKindOfClass:XYMBasicPopWindowView.class]) {
        root = (XYMBasicPopWindowView *)root.superview;
    }
    if (![root beginDismissalWithCompletion:completion]) return;
    NSMutableArray<XYMBasicPopWindowView *> *stack = [NSMutableArray arrayWithObject:root];
    for (NSUInteger index = 0; index < stack.count; index++) {
        for (UIView *child in stack[index].subviews) {
            if ([child isKindOfClass:XYMBasicPopWindowView.class]) [stack addObject:(XYMBasicPopWindowView *)child];
        }
    }
    for (XYMBasicPopWindowView *view in stack) {
        view.linkScrollView = nil;
        if (view.dismissBlock) view.dismissBlock(NO);
    }
    void (^finish)(void) = ^{
        for (XYMBasicPopWindowView *view in stack.reverseObjectEnumerator) {
            [view removeFromSuperview];
            // 清理本次只施加给卡片的位移，避免下次复用实例时仍停在屏幕外。
            view.popView.transform = CGAffineTransformIdentity;
            view.sidePanActive = NO;
            [view.views removeAllObjects];
            [view.views addObject:view];
            view.popIndex = 0;
            if (view != root && view.dismissBlock) view.dismissBlock(YES);
        }
        [root completeDismissal];
    };
    if (animation) {
        [UIView animateWithDuration:0.45 animations:^{
            for (XYMBasicPopWindowView *view in stack) {
                // 遮罩所属容器保持不动，仅卡片退出；不同高度和已拖动的卡片均按当前位置计算。
                CGFloat distance = MAX(0, CGRectGetHeight(view.bounds) - CGRectGetMinY(view.popView.frame));
                view.popView.transform = CGAffineTransformTranslate(view.popView.transform, 0, distance);
                view.bgButton.alpha = 0;
            }
        } completion:^(BOOL finished) { finish(); }];
    } else {
        finish();
    }
}

- (void)backGroudButtonClick{
    [self disMissAnimation:self.backgroundDismissAnimated completion:nil];
}

- (void)constructUI{
    // initWithCoder 和 awakeFromNib 均可能经过此处，避免创建两套控件。
    if (self.popView) return;
    self.isScroll = YES;
    _bgButton_Enable = YES;
    self.bgButton = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds))];
    self.bgButton.backgroundColor = UIColor.clearColor;
    self.bgButton.alpha = 0;
    [self.bgButton addTarget:self action:@selector(backGroudButtonClick) forControlEvents:UIControlEventTouchUpInside];
    
    CGFloat height = CGRectGetHeight(self.bounds) * 0.55;
    self.popView_height = height;
    self.popView = [[UIView alloc]initWithFrame:CGRectMake(0, CGRectGetHeight(self.bounds) - height, CGRectGetWidth(self.bounds), height)];
    self.popView.backgroundColor = UIColor.whiteColor;
    self.pan.delaysTouchesEnded = NO;
    self.pan.delaysTouchesBegan = NO;
    self.leftPan.delaysTouchesBegan = NO;
    self.leftPan.delaysTouchesEnded = NO;
    self.layer.shadowRadius = 5;
    self.layer.shadowOpacity = 0.2;
    self.layer.shadowOffset = CGSizeMake(-4, 0);
    [self addSubview:self.bgButton];
    [self addSubview:self.popView];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (!CGSizeEqualToSize(self.lastLayoutSize, self.bounds.size)) {
        self.lastLayoutSize = self.bounds.size;
        self.bgButton.frame = self.bounds;
        // XIB 内容由 Masonry 决定高度，不再额外用 frame 覆盖它。
        if (self.popView.translatesAutoresizingMaskIntoConstraints) {
            self.popView.frame = CGRectMake(0, CGRectGetHeight(self.bounds) - self.popView_height,
                                           CGRectGetWidth(self.bounds), self.popView_height);
        }
        self.topPanView.frame = CGRectMake(0, 0, CGRectGetWidth(self.popView.bounds), 32);
    }
    [self updateCornerMask];
}

- (void)setupPanGes{
    if (self.pan) return;
    self.pan = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panGes:)];
    self.pan.delegate = self;
    self.pan.delaysTouchesBegan = NO;
    self.pan.delaysTouchesEnded = NO;
    [self.popView addGestureRecognizer:self.pan];
}

- (void)setupLeftPan{
    if (self.leftPan) {
        [self.popView addGestureRecognizer:self.leftPan];
        return;
    }
    self.leftPan = [[UIScreenEdgePanGestureRecognizer alloc]initWithTarget:self action:@selector(leftPanGes:)];
    self.leftPan.delegate = self;
    self.leftPan.edges = UIRectEdgeLeft;
    self.leftPan.delaysTouchesBegan = NO;
    self.leftPan.delaysTouchesEnded = NO;
    [self.popView addGestureRecognizer:self.leftPan];
}

- (void)leftPanGes:(UIPanGestureRecognizer *)panGesture{
    if (self.isDismissing || ![self.superview isKindOfClass:XYMBasicPopWindowView.class]) return;
    XYMBasicPopWindowView *parent = (XYMBasicPopWindowView *)self.superview;
    if (panGesture.state == UIGestureRecognizerStateBegan) {
        // Push 的停留高度受前后两层高度影响，必须接续实际位置，不能重设成固定 44pt。
        self.sidePanParentFrame = parent.popView.frame;
        self.sidePanCardFrame = self.popView.frame;
        self.sidePanTranslation = 0;
        self.sidePanActive = YES;
        parent.popView.alpha = 1;
    }
    if (!self.sidePanActive) return;
    CGFloat width = MAX(CGRectGetWidth(self.bounds), 1);
    self.sidePanTranslation = MAX(0, MIN(width, self.sidePanTranslation + [panGesture translationInView:self].x));
    [panGesture setTranslation:CGPointZero inView:self];
    CGFloat progress = self.sidePanTranslation / width;
    CGRect cardFrame = self.sidePanCardFrame;
    cardFrame.origin.x += self.sidePanTranslation;
    [self moveCardToOrigin:cardFrame.origin];
    CGRect parentFrame = self.sidePanParentFrame;
    parentFrame.origin.x *= 1 - progress;
    CGFloat restingY = CGRectGetHeight(parent.bounds) - CGRectGetHeight(parentFrame);
    parentFrame.origin.y += (restingY - parentFrame.origin.y) * progress;
    [parent moveCardToOrigin:parentFrame.origin];
    self.bgButton.alpha = 1 - progress;
    if (panGesture.state == UIGestureRecognizerStateEnded ||
        panGesture.state == UIGestureRecognizerStateCancelled || panGesture.state == UIGestureRecognizerStateFailed) {
        self.sidePanActive = NO;
        // 只在正常松手且超过一半时完成返回；取消/失败不受单次位移大小影响。
        if (panGesture.state == UIGestureRecognizerStateEnded && progress >= 0.5) {
            [self popViewByPan:YES completion:nil];
        } else {
            [self restoreCancelledSidePanWithParent:parent];
        }
    }
}

- (void)restoreCancelledSidePanWithParent:(XYMBasicPopWindowView *)parent {
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:1 initialSpringVelocity:0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        [self moveCardToOrigin:self.sidePanCardFrame.origin];
        [parent moveCardToOrigin:self.sidePanParentFrame.origin];
        self.bgButton.alpha = 1;
    } completion:^(BOOL finished) {
        if (!self.sidePanActive && self.superview == parent && !self.isDismissing) parent.popView.alpha = 0;
    }];
}

- (void)popViewByPan:(BOOL)animation completion:(void(^ __nullable)(void))completion{
    if (![self.superview isKindOfClass:XYMBasicPopWindowView.class]) {
        [self disMissAnimation:animation completion:completion];
        return;
    }
    if (![self beginDismissalWithCompletion:completion]) return;
    self.linkScrollView = nil;
    if (self.dismissBlock) self.dismissBlock(NO);
    XYMBasicPopWindowView * superView = (XYMBasicPopWindowView *)self.superview;
    superView.popView.alpha = 1;
    self.bgButton.frame = CGRectMake(- CGRectGetWidth(self.bounds), 0, CGRectGetWidth(self.bounds) * 2, CGRectGetHeight(self.bounds));
    superView.bgButton.frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds) * 2, CGRectGetHeight(self.bounds));
    [self.views removeAllObjects];
    if(animation){
        CGFloat progress = MIN(1, MAX(0, CGRectGetMinX(self.popView.frame) / MAX(CGRectGetWidth(self.bounds), 1)));
        [UIView animateWithDuration:MAX(0.1, 0.45 * (1 - progress)) animations:^{
            superView.bgButton.alpha = 1;
            self.bgButton.alpha = 0;
            [superView moveCardToOrigin:CGPointMake(0, CGRectGetHeight(self.bounds) - CGRectGetHeight(superView.popView.frame))];
            XYMPopSetX(self, CGRectGetWidth(self.bounds));
        } completion:^(BOOL finished) {
            superView.bgButton.frame = CGRectMake( 0, 0, CGRectGetWidth(self.bounds),CGRectGetHeight(self.bounds));
            self.bgButton.frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
            [self removeFromSuperview];
            [self completeDismissal];
        }];
    }else{
        [superView moveCardToOrigin:CGPointMake(0, CGRectGetHeight(self.bounds) - CGRectGetHeight(superView.popView.frame))];
        superView.bgButton.alpha = 1;
        superView.bgButton.frame = superView.bounds;
        [self removeFromSuperview];
        [self completeDismissal];
    }
}


- (void)panGes:(UIPanGestureRecognizer *)panGesture{
    if (self.isDismissing) return;
    CGPoint point = [panGesture translationInView:self];
    [panGesture setTranslation:CGPointZero inView:self];
    BOOL canMove = self.isScroll || self.isOnlyHeaderPan;
    CGFloat offset = canMove ? MAX(0, self.popView.transform.ty + point.y) : 0;
    CGFloat height = MAX(CGRectGetHeight(self.popView.bounds), 1);
    // 拖拽也只改 transform，保留 XIB 布局计算出的基准位置。
    self.popView.transform = CGAffineTransformMakeTranslation(0, offset);
    self.bgButton.alpha = MAX(0, 1 - offset / height);
    if (panGesture.state == UIGestureRecognizerStateEnded && offset >= height / 2) {
        [self disMissAnimation:YES completion:nil];
        return;
    }
    if (panGesture.state == UIGestureRecognizerStateEnded ||
        panGesture.state == UIGestureRecognizerStateCancelled ||
        panGesture.state == UIGestureRecognizerStateFailed || !canMove) {
        [UIView animateWithDuration:0.25 animations:^{
            self.popView.transform = CGAffineTransformIdentity;
            self.bgButton.alpha = 1;
        }];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if(context == XYMPopScrollObservationContext){
        UIScrollView *scrollView = self.linkScrollView;
        self.isScroll = scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top + 0.5;
        scrollView.bounces = self.originalScrollBounces && !self.isScroll;
        return;
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if([gestureRecognizer.view isEqual:self.popView] && [otherGestureRecognizer.view isEqual:self.linkScrollView]){
        return YES;
    }else if([otherGestureRecognizer.view isEqual:self.popView] && [gestureRecognizer.view isEqual:self.linkScrollView]){
        return YES;
    }else{
        return NO;
    }
}
- (void)setBgButton_Enable:(BOOL)bgButton_Enable{
    _bgButton_Enable = bgButton_Enable;
    self.bgButton.enabled = bgButton_Enable;
}

- (void)setBgButton_Color_Alpha:(CGFloat)bgButton_Color_Alpha{
    _bgButton_Color_Alpha = bgButton_Color_Alpha;
    self.bgButton.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:bgButton_Color_Alpha];
}

- (void)setCanPanPopView:(BOOL)canPanPopView{
    _canPanPopView = canPanPopView;
    if (canPanPopView) {
        [self setupPanGes];
        self.isOnlyHeaderPan = self.isOnlyHeaderPan;
    } else {
        [self.pan.view removeGestureRecognizer:self.pan];
        [self.topPanView removeFromSuperview];
    }
}

- (void)setPopView_height:(CGFloat)popView_height{
    _popView_height = popView_height;
    self.popView.frame = CGRectMake(0, CGRectGetHeight(self.bounds) - popView_height, CGRectGetWidth(self.bounds), popView_height);
    self.popView_header_Radius = self.popView_header_Radius;
}

- (void)setLinkScrollView:(UIScrollView *)linkScrollView{
    if (_linkScrollView == linkScrollView) return;
    if(_linkScrollView){
        [_linkScrollView removeObserver:self forKeyPath:@"contentOffset" context:XYMPopScrollObservationContext];
        _linkScrollView.bounces = self.originalScrollBounces;
        _linkScrollView = nil;
    }
    _linkScrollView = linkScrollView;
    self.isScroll = YES;
    if(!linkScrollView) return;
    self.originalScrollBounces = linkScrollView.bounces;
    [_linkScrollView addObserver:self forKeyPath:@"contentOffset"
                        options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial
                        context:XYMPopScrollObservationContext];
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    if (!newSuperview) self.linkScrollView = nil;
    [super willMoveToSuperview:newSuperview];
}

- (void)setCanLeftPanBack:(BOOL)canLeftPanBack{
    _canLeftPanBack = canLeftPanBack;
    if(canLeftPanBack){
        [self setupLeftPan];
    }else{
        [self.popView removeGestureRecognizer:self.leftPan];
    }
}

- (NSHashTable<XYMBasicPopWindowView *> *)views{
    if(!_views){
        _views = [NSHashTable weakObjectsHashTable];
        [_views addObject:self];
    }
    return _views;
}

- (void)setIsOnlyHeaderPan:(BOOL)isOnlyHeaderPan{
    _isOnlyHeaderPan = isOnlyHeaderPan;
    if(!self.canPanPopView) return;
    if(isOnlyHeaderPan){
        if (!self.topPanView) {
            self.topPanView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.bounds), 32)];
            self.topPanView.backgroundColor = UIColor.clearColor;
            self.topPanView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        }
        [self.popView addSubview:self.topPanView];
        [self.topPanView addGestureRecognizer:self.pan];
    }else{
        [self.topPanView removeFromSuperview];
        [self.popView addGestureRecognizer:self.pan];
    }
}

- (void)setPopView_header_Radius:(CGFloat)popView_header_Radius{
    _popView_header_Radius = popView_header_Radius;
    [self updateCornerMask];
}

- (void)updateCornerMask {
    UIBezierPath *rounded = [UIBezierPath bezierPathWithRoundedRect:self.popView.bounds byRoundingCorners:UIRectCornerTopRight|UIRectCornerTopLeft cornerRadii:CGSizeMake(self.popView_header_Radius, self.popView_header_Radius)];
    CAShapeLayer *shape = [[CAShapeLayer alloc]init];
    [shape setPath:rounded.CGPath];
    self.popView.layer.mask = shape;
}

- (void)dealloc{
    // 非 dismiss 路径释放时也解除观察，并恢复调用方的滚动设置。
    UIScrollView *scrollView = _linkScrollView;
    if (scrollView) {
        [scrollView removeObserver:self forKeyPath:@"contentOffset" context:XYMPopScrollObservationContext];
        scrollView.bounces = _originalScrollBounces;
    }
}
@end
