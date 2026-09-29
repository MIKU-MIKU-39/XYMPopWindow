// XYMBasicPopWindowView.h — Reusable popup component. Created by Xuyiming.

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XYMBasicPopWindowView : UIView

@property (nonatomic, strong) UIView * popView;

@property (nonatomic, assign) BOOL bgButton_Enable;

/// 背景点击的关闭动画。Show / Push 时设为该次 animation 参数，显示后可独立修改。
@property (nonatomic, assign) BOOL backgroundDismissAnimated;

@property (nonatomic, assign) CGFloat bgButton_Color_Alpha;

@property (nonatomic, assign) CGFloat popView_height;

@property (nonatomic, assign) BOOL canPanPopView;

@property (nonatomic, weak, nullable) UIScrollView * linkScrollView;

@property (nonatomic, assign) BOOL isOnlyHeaderPan;

@property (nonatomic, assign) CGFloat popView_header_Radius;

@property (nonatomic, assign) BOOL canLeftPanBack;

@property (nonatomic, assign, readonly) NSUInteger popIndex;

@property (nonatomic, strong, readonly) NSHashTable<XYMBasicPopWindowView *> * views;

/// NO 表示开始关闭，YES 表示已从父视图移除；动画与非动画保持一致。
@property (nonatomic, copy, nullable) void(^dismissBlock)(BOOL completion);

- (void)addXibViewToPopView:(UIView *)xibView;
/// 所有 UI 操作需在主线程调用；弹窗尺寸跟随 superView.bounds。
- (void)showIn:(UIView *)superView animation:(BOOL)animation completion:(void(^ __nullable)(void))completion;
- (void)disMissAnimation:(BOOL)animation completion:(void(^ __nullable)(void))completion;
- (void)setHidden:(BOOL)hidden animation:(BOOL)animation completion:(void(^ __nullable)(void))completion;
- (void)pushView:(__kindof XYMBasicPopWindowView *)pushView animation:(BOOL)animation completion:(void(^ __nullable)(void))completion;
- (void)popViewAnimation:(BOOL)animation completion:(void(^ __nullable)(void))completion;
- (void)disMissAllView:(BOOL)animation completion:(void(^ __nullable)(void))completion;
- (void)backGroudButtonClick;

- (void)viewDidFirstAppear;
@end

NS_ASSUME_NONNULL_END
