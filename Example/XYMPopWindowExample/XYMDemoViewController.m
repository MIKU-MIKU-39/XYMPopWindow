// XYMDemoViewController.m — Eight feature entry points. Created by Xuyiming.
#import "XYMDemoViewController.h"
#import "XYMFeatureViewController.h"

@implementation XYMDemoViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"XYMPopWindow";
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 78;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return XYMDemoFeatureCount;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"功能示例 · 点击进入操作面板";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Feature"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Feature"];
    cell.textLabel.text = XYMFeatureViewController.featureTitles[indexPath.row];
    cell.detailTextLabel.text = XYMFeatureViewController.featureDetails[indexPath.row];
    cell.detailTextLabel.numberOfLines = 0;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.accessibilityIdentifier = [NSString stringWithFormat:@"feature.%ld", (long)indexPath.row];
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    XYMFeatureViewController *demo = [[XYMFeatureViewController alloc] initWithFeature:indexPath.row];
    [self.navigationController pushViewController:demo animated:YES];
}
@end
