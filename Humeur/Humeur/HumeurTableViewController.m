//
//  ViewController.m
//  Humeur
//
//  Created by Ancil on 6/17/15.
//  Copyright (c) 2015 Ancil Marshall. All rights reserved.
//

#import "HumeurTableViewController.h"
#import "HumeurNetServiceBrowserDelegate.h"

static NSString* const kNetServiceDomain = @"local";
static NSString* const kNetServiceType = @"_humeur._tcp";
static int const kNetServicePortNumber = 9090;

@interface HumeurTableViewController () <NSNetServiceDelegate>
@property (nonatomic,strong) NSNetService* service;
@property (nonatomic,strong) NSNetServiceBrowser* browser;
@property (nonatomic,strong) HumeurNetServiceBrowserDelegate* browserDelegate;

@end

#pragma mark - Initialization
@implementation HumeurTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initAndPublishNetService:kNetServicePortNumber];
    [self initAndBrowseForNetService:kNetServicePortNumber];
}

-(void)initAndPublishNetService:(int)port;
{
    self.service =
    [[NSNetService alloc] initWithDomain:kNetServiceDomain
                                    type:kNetServiceType
                                    name:[[UIDevice currentDevice] name]
                                    port:port];
    
    if (self.service)
    {
        self.service.delegate = self;
        self.service.includesPeerToPeer = YES; // for bluetooth
        [self.service publish];
    } else {
        NSLog(@"Error initializing NSNetService Oject");
    }
}

-(void)initAndBrowseForNetService:(int)port;
{
    self.browser = [NSNetServiceBrowser new];
    self.browserDelegate = [[HumeurNetServiceBrowserDelegate alloc] initWithTableViewController:self];;
    if (self.browser ==nil){
        NSLog(@"Error initializing NSNetServiceBrowser");
        return;
    }
    self.browser.delegate = self.browserDelegate;
    [self.browser searchForServicesOfType:kNetServiceType
                                 inDomain:kNetServiceDomain];
    
}

-(void)updateUI;
{
    [self.tableView reloadData];
}

#pragma mark - TableView Data Source Methods
-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
{
    return 1;
    
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
{
    return [[self.browserDelegate services] count];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    
    UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:@"TableViewCell"
                                                                 forIndexPath:indexPath];
    if (cell == nil){
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"TableViewCell"];
    }
    
    cell.textLabel.text = [[self.browserDelegate.services objectAtIndex:indexPath.row] name];
    
    return cell;
}

#pragma mark - TableView Delegate Methods



@end
