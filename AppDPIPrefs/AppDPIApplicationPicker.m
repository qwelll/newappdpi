#import "AppDPIApplicationPicker.h"
#import <objc/message.h>

/*
 * Standalone app picker so the plugin works without AltList. Applications come from
 * LSApplicationWorkspace (user apps only); a bundle-scan fallback covers the case where the
 * private class is unavailable in the settings process.
 */

@interface AppDPIApplicationPickerController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@end

@implementation AppDPIApplicationPickerController {
    UITableView *_table;
    UISearchBar *_search;
    NSArray<NSDictionary<NSString *, NSString *> *> *_allApplications;
    NSArray<NSDictionary<NSString *, NSString *> *> *_filteredApplications;
    NSMutableSet<NSString *> *_selected;
    UIActivityIndicatorView *_spinner;
}

- (instancetype)appdpi_scale_initWithSelectedBundles:(NSArray<NSString *> *)selectedBundles {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _selected = [NSMutableSet setWithArray:selectedBundles ?: @[]];
        _allApplications = @[];
        _filteredApplications = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"选择应用";
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];

    _search = [[UISearchBar alloc] initWithFrame:CGRectZero];
    _search.placeholder = @"搜索应用名称或标识符";
    _search.delegate = self;
    _search.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_search];

    _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _table.dataSource = self;
    _table.delegate = self;
    _table.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    _table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_table];

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spinner.hidesWhenStopped = YES;
    [self.view addSubview:_spinner];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(appdpi_scale_finishSelection)];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *applications = [AppDPIApplicationPickerController appdpi_scale_loadApplications];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_spinner stopAnimating];
            self->_allApplications = applications;
            self->_filteredApplications = applications;
            [self->_table reloadData];
        });
    });
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = self.view.safeAreaInsets.top;
    CGFloat width = self.view.bounds.size.width;
    _search.frame = CGRectMake(0, top, width, 56);
    CGFloat listTop = CGRectGetMaxY(_search.frame);
    _table.frame = CGRectMake(0, listTop, width, CGRectGetHeight(self.view.bounds) - listTop);
    _spinner.center = CGPointMake(width / 2.0, CGRectGetMidY(_table.frame));
}

+ (NSArray<NSDictionary<NSString *, NSString *> *> *)appdpi_scale_loadApplications {
    NSMutableArray *result = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];

    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (workspaceClass) {
        id workspace = ((id (*)(id, SEL))objc_msgSend)((id)workspaceClass, sel_registerName("defaultWorkspace"));
        NSArray *proxies = ((id (*)(id, SEL))objc_msgSend)(workspace, sel_registerName("allApplications"));
        for (id proxy in proxies) {
            if ([proxy respondsToSelector:sel_registerName("applicationType")]) {
                long long type = ((long long (*)(id, SEL))objc_msgSend)(proxy, sel_registerName("applicationType"));
                if (type != 0) continue; // User applications only.
            }
            NSString *identifier = ((id (*)(id, SEL))objc_msgSend)(proxy, sel_registerName("bundleIdentifier"));
            if (![identifier isKindOfClass:[NSString class]] || identifier.length == 0) continue;
            if ([seen containsObject:identifier]) continue;
            NSString *name = ((id (*)(id, SEL))objc_msgSend)(proxy, sel_registerName("localizedName"));
            if (![name isKindOfClass:[NSString class]] || name.length == 0) name = identifier;
            [seen addObject:identifier];
            [result addObject:@{@"name": name, @"bundle": identifier}];
        }
    }

    if (result.count == 0) {
        NSFileManager *manager = [NSFileManager defaultManager];
        NSString *root = @"/var/containers/Bundle/Application";
        for (NSString *container in [manager contentsOfDirectoryAtPath:root error:nil]) {
            NSString *containerPath = [root stringByAppendingPathComponent:container];
            for (NSString *bundle in [manager contentsOfDirectoryAtPath:containerPath error:nil]) {
                if (![bundle hasSuffix:@".app"]) continue;
                NSString *infoPath = [[containerPath stringByAppendingPathComponent:bundle]
                                      stringByAppendingPathComponent:@"Info.plist"];
                NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
                NSString *identifier = info[@"CFBundleIdentifier"];
                if (![identifier isKindOfClass:[NSString class]] || identifier.length == 0) continue;
                if ([seen containsObject:identifier]) continue;
                NSString *name = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: identifier;
                [seen addObject:identifier];
                [result addObject:@{@"name": name, @"bundle": identifier}];
            }
        }
    }

    return [result sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
    }];
}

- (void)appdpi_scale_finishSelection {
    NSArray *sorted = [[_selected allObjects] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    if (self.appdpi_scale_completion) {
        self.appdpi_scale_completion(sorted);
    }
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)_filteredApplications.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"AppDPIPickerCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    }
    NSDictionary *application = _filteredApplications[(NSUInteger)indexPath.row];
    cell.textLabel.text = application[@"name"];
    cell.detailTextLabel.text = application[@"bundle"];
    cell.accessoryType = [_selected containsObject:application[@"bundle"]] ? UITableViewCellAccessoryCheckmark
                                                                           : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *bundle = _filteredApplications[(NSUInteger)indexPath.row][@"bundle"];
    if ([_selected containsObject:bundle]) {
        [_selected removeObject:bundle];
    } else {
        [_selected addObject:bundle];
    }
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        _filteredApplications = _allApplications;
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:
            @"name CONTAINS[cd] %@ OR bundle CONTAINS[cd] %@", searchText, searchText];
        _filteredApplications = [_allApplications filteredArrayUsingPredicate:predicate];
    }
    [_table reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

@end
