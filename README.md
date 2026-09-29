# XYMPopWindow

作者：Xuyiming

Objective-C 底部弹窗组件，提供基础容器、嵌套 Push / Pop、下拉关闭、滚动联动和 WebKit 网页弹窗。依赖 UIKit、WebKit、Masonry，不依赖 TripVue 的 PCH、宏、分类或图片资源。

## 项目结构

```text
XYMPopWindow/
├── XYMPopWindow.podspec
├── LICENSE                              # MIT
├── Gemfile
├── README.md
├── Sources/
│   ├── XYMPopWindow.h                   # 统一导入入口
│   ├── XYMBasicPopWindowView.h/.m       # 基础弹窗
│   └── XYMPopWindowWebView.h/.m         # 网页弹窗
├── Example/
│   ├── Podfile
│   ├── XYMPopWindowExample.xcodeproj
│   ├── XYMPopWindowExample.xcworkspace # pod install 后生成
│   └── XYMPopWindowExample/
│       ├── XYMDemoViewController.h/.m    # 8 组功能目录
│       ├── XYMFeatureViewController.h/.m # 操作面板、弹窗与事件日志
│       ├── XYMDemoContentView.h/.m       # 文字与长列表内容
│       ├── XYMDemoContent.xib           # 真实 XIB，自身高度约束随宿主调整
│       ├── XYMDemoIndex.html            # 本地首页
│       └── XYMDemoDetail.html           # 本地第二页
├── Tests/
│   ├── XYMBasicPopWindowViewTests.m
│   └── XYMDemoExamplesTests.m
└── scripts/
    ├── generate_example.rb             # 工程首次生成工具
    └── sync_example_files.rb           # 追加源码/资源引用，不重建工程
```

组件声明最低 iOS 13.0，启用 ARC；示例与测试工程最低 iOS 17.0，以适配当前 XCTest。示例的最低版本不改变组件自身的最低版本。Masonry 依赖为 `~> 1.1`。

## 运行示例

首次准备 Ruby 依赖，然后安装 Pods：

```sh
bundle install
cd Example
bundle exec pod install
open XYMPopWindowExample.xcworkspace
```

已有 CocoaPods 的环境，也可直接在 Example 目录运行 `pod install`。请打开 `.xcworkspace`，不要只打开 `.xcodeproj`。

选择 `XYMPopWindowExample` scheme 和 iOS 模拟器，点击 Run。真机运行需自行在 Signing 中选择开发团队，仓库不绑定个人证书。

演示入口共 8 组，每组都提供动画开关、显示/关闭按钮和事件日志。先点击「显示」，再修改参数；保留“控制区 → 预览区 → 日志”的上下顺序，使用紧凑单屏布局，无需滚动整页。源码主要位于 `Example/XYMPopWindowExample/XYMFeatureViewController.m`。

| 功能 | 操作方法 | 对应组件 API |
| --- | --- | --- |
| 外观配置 | 拖动高度、圆角、遮罩滑块；切换文字/彩色卡片 | `popView_height`、`popView_header_Radius`、`bgButton_Color_Alpha` |
| 动画与显隐 | 切换动画；隐藏后使用预览区外的按钮恢复 | `showIn:`、`setHidden:animation:completion:`、`disMissAllView:` |
| 手势控制 | 开关下拉关闭，或仅允许顶部 32pt 拖动 | `canPanPopView`、`isOnlyHeaderPan` |
| 背景交互 | 开关点击背景关闭；调整遮罩透明度 | `bgButton_Enable`、`bgButton_Color_Alpha` |
| 多层弹窗 | Push 不同高度的页面、Pop 本层、左边缘右滑返回、全部关闭 | `pushView:`、`popViewAnimation:`、`canLeftPanBack` |
| 滚动联动 | 滚动 40 行列表；回到顶部后下拉；切换 0/24pt inset | `linkScrollView` |
| 内容与容器 | 切换真实 XIB / 代码约束高度；挂载到预览区 / 当前 UIWindow | `addXibViewToPopView:`、`showIn:` |
| 网页与回调 | 点击本地首页链接进入第二页，测试后退/前进/刷新，查看日志 | `XYMPopWindowWebView`、`WKWebView`、`dismissBlock` |

注意：

- 预览区仍内嵌在页面中，宽度铺满当前页面，高度使用控件与日志之外的剩余空间，不再设置 420pt 最低高度。普通弹窗默认占预览区的 82%；外观高度滑块可调范围为 45%～95%，切换页面尺寸后保持所选比例。说明、控件与日志仍保留左右 16pt 留白。
- 嵌套子层采用 90% / 68% 交替高度。XIB 与代码约束内容通过自己的高度约束自适应，不与 `popView_height` 混用。
- 动画开关、显示和关闭按钮合并为一行；控件组行间距 4pt，页面区域间距 6pt。Switch 保留系统固有尺寸，Slider、按钮与分段控件最低 32pt；开关所在行保留水平余量，避免实际 frame 超出系统 alignment rect 后碰到边界。这是紧凑演示面板的尺寸，不是业务 App 的通用点击区域建议。
- 当前窗口模式会覆盖操作面板，可点弹窗内「关闭本层」退出；其他示例默认仍在预览区显示。
- 示例弹窗显示期间禁用页面的导航侧滑返回（边缘返回与 iOS 26+ 内容区返回）；根弹窗完全关闭后恢复原状态，原本禁用的手势不会被误打开。临时隐藏与子层关闭不解锁，弹窗内部多层侧滑仍可使用。离开示例页面时恢复，返回仍有弹窗的页面时重新禁用。这是示例控制器的接入逻辑，组件本体不自动控制业务导航。
- 背景关闭开关仅控制能否点击背景关闭，不表示触摸穿透。
- 示例动画开关也会实时同步到当前所有弹窗的背景点击返回；开启动画时等待转场完成，关闭时立即移除当前层。
- 手势需要在模拟器或真机上实际拖动；下拉超过弹窗高度一半后松手触发关闭。
- 内容类型、inset、宿主切换会关闭旧实例并重新显示，避免混用固定高度与内容约束。
- `XYMDemoContent.xib` 是真实资源，`XYMDemoIndex.html` 与 `XYMDemoDetail.html` 通过 `loadFileURL:` 加载，不依赖网络。
- 底部日志高度 40pt，显示最近记录，最多保留 50 行，可在日志内部滚动查看历史；弹窗内列表和网页仍保留各自的滚动能力。关闭按 `dismiss.start → dismiss.finished → dismiss.completion` 记录。手势或弹窗内部返回触发关闭时，没有外部方法的 completion 日志。

工程文件已提供，正常使用无需运行生成脚本。脚本遇到已有工程会退出，以免覆盖手工修改。
新增示例文件后，可在仓库根目录运行 `bundle exec ruby scripts/sync_example_files.rb`，幂等追加 `.m` 编译引用及 `.xib/.html` 资源引用，不覆盖现有工程配置。

## 本地接入其他工程

在调用方 Podfile 中添加本组件目录（路径相对于该 Podfile）：

```ruby
pod 'XYMPopWindow', :path => '../XYMPopWindow'
```

执行 `pod install` 后导入：

```objc
#import <XYMPopWindow/XYMPopWindow.h>
```

如果调用方已复制过这两个同名类，应先决定采用源码还是 Pod，避免两份实现同时参与编译。本次没有自动删除 TripVue 内的原文件。

## 基础用法

所有 UI 操作均需在主线程执行。将业务子视图添加到 `popView`，不要添加到背景容器上。

```objc
XYMBasicPopWindowView *popup = [[XYMBasicPopWindowView alloc] init];
popup.popView_height = 300;
popup.popView_header_Radius = 16;
popup.bgButton_Color_Alpha = 0.45;
popup.canPanPopView = YES;

UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(24, 24, 240, 40)];
label.text = @"自定义内容";
[popup.popView addSubview:label];
[popup showIn:self.view animation:YES completion:nil];
```

`showIn:` 使用宿主 bounds。需要覆盖导航栏时，可传入当前页面所属的 `self.view.window`，不使用全局 keyWindow，适用于多场景环境。

## 多层弹窗与关闭

```objc
XYMBasicPopWindowView *child = [[XYMBasicPopWindowView alloc] init];
child.popView_height = 260;
[popup pushView:child animation:YES completion:nil];

// 当前层返回；根弹窗则直接关闭。
[child popViewAnimation:YES completion:nil];

// 从任意仍处于栈中的弹窗关闭整组。
[popup disMissAllView:YES completion:nil];
```

关闭回调中，`dismissBlock(NO)` 表示开始关闭，`dismissBlock(YES)` 表示已移除；方法的 completion 在移除后执行。不要在 block 中强持有弹窗自身，避免形成引用环。

点击背景关闭使用 `backgroundDismissAnimated`。每次 `showIn:animation:` 或 `pushView:animation:` 会将被显示弹窗的该属性设为此次 `animation` 参数；显示后可单独修改，不影响父层，也不改变显式关闭方法传入的动画参数。

嵌套侧滑从上一层 Push 结束后的实际位置开始，随手势进度恢复到底部；正常松手超过一半时返回，取消或失败则恢复到手势开始位置。XIB/约束内容使用转场位移保持位置，避免重新布局产生跳变。`disMissAllView:` 仅将各层卡片向下移出，背景遮罩保持固定，只做透明度渐隐。

## 网页弹窗

```objc
XYMPopWindowWebView *web = [[XYMPopWindowWebView alloc]
    initWithTitle:@"页面说明" url:[NSURL URLWithString:@"about:blank"]];
[web.webView loadHTMLString:@"<h1>本地内容</h1>" baseURL:nil];
[web showIn:self.view animation:YES completion:nil];
```

没有主工程 `btn_back` 图片时，使用系统 `chevron.left`。生产工程加载在线页面时，应由业务方处理可用 URL、网络失败与内容安全策略；组件不会替调用方修改 ATS 配置。

## 滚动与 XIB 内容

- `linkScrollView` 弱引用内容滚动视图，到顶部后允许拖动弹窗；解除绑定或移除弹窗时恢复原有 bounces。
- `canPanPopView` 开启下拉；`isOnlyHeaderPan` 将拖动范围限制为顶部区域，内容布局应为其预留空间。
- `addXibViewToPopView:` 接收内容视图；内容必须提供可推导高度的完整约束，或自身固定高度约束。不要同时再用 `popView_height` 控制这类内容高度。
- 下拉松手时超过弹窗高度一半才关闭；取消手势恢复位置。

## 测试

Xcode 中选中同一 scheme，执行 Product → Test，运行 54 项 XCTest 回归（组件 27 项 + 示例 27 项）。测试与演示均通过 Podfile 接入本组件，没有本机绝对源码路径。

命令行示例（替换为本机实际模拟器名称）：

```sh
cd Example
xcodebuild test -workspace XYMPopWindowExample.xcworkspace \
  -scheme XYMPopWindowExample \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -parallel-testing-enabled NO -collect-test-diagnostics never
```

回归覆盖布局、嵌套切换、关闭回调、重复手势配置、滚动联动、约束内容、重复关闭和手势取消。示例回归覆盖八项入口、参数生效、隐藏恢复、动画防重入、XIB/代码高度、窗口容器、离线网页跳转及历史，以及宿主变化后的高度占比、隐藏状态、嵌套位置、控件固有尺寸和留白。单屏布局在 320×568、375×667、390×844、402×874、768×1024 竖屏尺寸下扣除顶部/底部保留区域验证，检查全宽预览、40pt 日志、控件边界和小屏默认弹窗文字。两种系统返回手势的原状态恢复、弹窗重建/关闭动画/背景关闭/子层关闭/窗口内关闭及页面离开与返回也保留回归。它不等价于所有方向、辅助字体大小、系统版本或真实手势场景的完整验收。

转场回归另覆盖父子不同高度的侧滑起点、取消/失败恢复、完成返回，以及父子均使用约束时重新布局的位置保持。全部关闭同时验证三层模型坐标和真实窗口动画中途的 `presentationLayer`：容器与遮罩不位移，卡片向下退出，遮罩透明度在动画过程中递减，重复关闭的 completion 均执行。

背景返回回归覆盖动画 Push 后背景点击、复用弹窗时覆盖旧动画选项，以及示例开关开启/关闭后对已显示层级的同步。

### 本机验证记录（2026-09-28）

- 已成功执行真实 `pod install`：XYMPopWindow 0.1.0、Masonry 1.1.0。
- 示例 App 与测试 target 均构建成功；iPhone 18 Pro / iOS Simulator 27.0 上 50 / 50 测试通过，无跳过。
- 本次最终增量编译为 0 error / 0 warning，测试日志无 Auto Layout 约束冲突；此前完整构建的 13 条警告来自 Masonry 1.1.0。
- 行覆盖率：示例 App 96%、组件 91.3%；包含测试和第三方 Pods 的整体覆盖率为 70.4%。
- podspec 解析、Info.plist 校验及源码迁入一致性检查通过。
- Sources、Example 源码和 Tests 的关键词检查均通过；未扫描第三方 Pods 或构建产物。
- 八个演示入口的首页截图为 `build/ExampleMenu-Features.png`。上一轮布局截图见 `build/SinglePageFinalScreenshots/`，对应 XCTest 附件名为 `SinglePage-0` 至 `SinglePage-7`；已检查单屏控件、预览和底部日志。本轮新增真实窗口动画中途的图层位置及透明度断言。
- 最终测试结果为 `build/PopupMotion-Final.xcresult`；此前各轮测试结果保留。整个 build 目录被 Git 忽略。
- 两个 Ruby 工程脚本语法检查通过；重复运行引用同步脚本后 project.pbxproj 哈希不变。
- 之前的示例布局调整未改 Sources；本轮转场修复修改了 `Sources/XYMBasicPopWindowView.m`，公开 API 保持不变。
- 未做真机触摸手势和多系统版本验收。
- 尚未执行公开发布用的完整 pod lint；远端仓库和 tag 未创建。

### 本机验证记录（2026-09-29）

- 修复动画 Push 的子层点击背景时直接移除：Push 与 Show 均保存本次动画参数，背景点击统一读取 `backgroundDismissAnimated`。
- 示例动画开关实时同步到当前整组弹窗；新增 4 项回归，覆盖动画 Push、无动画复用，以及显示后开启/关闭动画。
- iPhone 18 Pro / iOS Simulator 27.0 上 54/54 项测试通过，无跳过；增量编译 0 error / 0 warning，未发现 Auto Layout 约束冲突。
- 行覆盖率：组件 91.3%、示例 App 96%，含测试和第三方 Pods 的整体覆盖率 71.2%。结果见 `build/BackdropReturn-Final.xcresult`。
- Sources / Example / Tests 共 18 个源码文件关键词检查零命中。现有页面布局未改，未做真机手势验收，未提交、推送或发布。

## 发布状态

目前仅完成本地项目整理，尚未创建 GitHub 仓库、推送代码、创建版本 tag 或发布 CocoaPods。
podspec 中的 `https://github.com/MIKU-MIKU-39/XYMPopWindow` 是规划地址，并不表示仓库已经存在。真正发布前需确认仓库地址，创建与版本一致的 tag，并运行 pod lint 验证；当前请使用 `:path` 接入。

## License

按所有者选择使用 MIT，全文见 LICENSE。Masonry 由 CocoaPods 独立获取并保留其自身许可证。
