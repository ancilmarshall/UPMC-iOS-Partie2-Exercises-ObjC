//
//  HumeurNetServiceBrowserDelegate.m
//  Humeur
//
//  Created by Ancil on 6/17/15.
//  Copyright (c) 2015 Ancil Marshall. All rights reserved.
//

#import "HumeurNetServiceBrowserDelegate.h"

#pragma mark - Initialization
@implementation HumeurNetServiceBrowserDelegate

-(instancetype)initWithTableViewController:(HumeurTableViewController*)tvc;
{
    self = [super init];
    if (self){
        
        _services = [NSMutableArray new];
        _searching = NO;
        NSAssert(tvc !=nil, @"Error initializing table view controller");
        _tableViewController = tvc;
        
    }
    return self;
}

#pragma mark - Private Methods
-(void)handleError:(NSNumber*)error;
{
    NSLog(@"An error occurred. Error code = %d", [error intValue]);
}

-(void)updateUI;
{
    if(self.searching)
    {
        [self.tableViewController updateUI];
    }
    else
    {
        // Update the user interface to indicate not searching
    }
}


#pragma mark - NSServiceBrowserDelegate Methods

//sent when browser begings searching for services
-(void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)aNetServiceBrowser;
{
    NSAssert(self == aNetServiceBrowser.delegate,@"Expected NetServiceBrowser's delegate to be self");
    self.searching = YES;
    
    //Update the UI to reflect that search is taking place. Maybe the network indicator
    
}

//sent when a service appears
-(void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing;
{
    NSAssert(self == aNetServiceBrowser.delegate,@"Expected NetServiceBrowser's delegate to be self");
    self.searching = YES;
    
    [self.services addObject:aNetService];
    if (!moreComing){
        [self updateUI];
    }
    
}

//sent when a service disappears
-(void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing;
{
    NSAssert(self == aNetServiceBrowser.delegate,@"Expected NetServiceBrowser's delegate to be self");
    self.searching = YES;
    
    [self.services removeObject:aNetService];
    if (!moreComing){
        [self updateUI];
    }
    
}


-(void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)aNetServiceBrowser;
{
    NSAssert(self == aNetServiceBrowser.delegate,@"Expected NetServiceBrowser's delegate to be self");
    self.searching = YES;
    
    //Update the UI to reflect that search stopped. Maybe the network indicator
   
}


-(void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didNotSearch:(NSDictionary *)errorDict;
{
    NSAssert(self == aNetServiceBrowser.delegate,@"Expected NetServiceBrowser's delegate to be self");
    self.searching = NO;
    
    [self handleError:[errorDict objectForKey:NSNetServicesErrorCode]];
}
@end

