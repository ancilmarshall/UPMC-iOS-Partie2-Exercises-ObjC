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
static int const kNetServicePortNumber = 0;

@interface HumeurTableViewController () <NSNetServiceDelegate,NSStreamDelegate>
@property (nonatomic,strong) NSNetService* service;
@property (nonatomic,strong) NSNetServiceBrowser* browser;
@property (nonatomic,strong) HumeurNetServiceBrowserDelegate* browserDelegate;
@property (nonatomic,strong) NSOutputStream* outputStream;

@end

#pragma mark - Initialization
@implementation HumeurTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initAndPublishNetService:kNetServicePortNumber];
    [self initAndBrowseForNetService:kNetServicePortNumber];
    
    self.navigationItem.title = @"Humeur";
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


- (IBAction)broadcastMessage:(UIBarButtonItem *)sender {
    
    NSNetService* me;
    
    //Find list of services that are not
    NSArray* services = self.browserDelegate.services;
    NSMutableArray* peerServices = [NSMutableArray new];
    for (NSNetService* service in services) {
        
        if (![service.name isEqualToString:[[UIDevice currentDevice] name]]){
            [peerServices addObject:service];
        }
        else {
            me = service;
        }
    }

    NSOutputStream* out = nil;
    BOOL ok = [self.service getInputStream:nil outputStream:&out];
    if (!ok){
        NSLog(@"Error retrieving OutputStream");
    }
    self.outputStream = out;
    self.outputStream.delegate = self;
    [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream open];
    
}


- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
    
    NSString* message = @"Hello";
    NSMutableData* data = [[message dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    
    static uint8_t byteIndex = 0;
    
    switch(eventCode) {
        case NSStreamEventHasSpaceAvailable:
        {
            uint8_t *readBytes = (uint8_t *)[data mutableBytes];
            readBytes += byteIndex; // instance variable to move pointer
            int data_len = (int)[data length];
            unsigned int len = ((data_len - byteIndex >= 1024) ?
                                1024 : (data_len-byteIndex));
            uint8_t buf[len];
            (void)memcpy(buf, readBytes, len);
            len = (unsigned int)[(NSOutputStream*)stream write:(const uint8_t *)buf maxLength:len];
            byteIndex += len;
            break;
        }
        case NSStreamEventOpenCompleted:
            break;
            
        case NSStreamEventEndEncountered:
            break;
            
        case NSStreamEventErrorOccurred:
            break;
            
        case NSStreamEventHasBytesAvailable:
            break;
            
        case NSStreamEventNone:
            break;
    }
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
    //Highlight the cell if it corresponds to the my device
    if ([[[self.browserDelegate.services objectAtIndex:indexPath.row] name] isEqualToString:[[UIDevice currentDevice] name]]) {
        cell.backgroundColor = [UIColor yellowColor];
    }
    return cell;
}

#pragma mark - TableView Delegate Methods

-(void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath;
{
   // NSNetService* service = [self.browserDelegate.services objectAtIndex:indexPath.row];
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end
