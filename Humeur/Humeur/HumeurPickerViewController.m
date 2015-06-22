//
//  HumeurPickerViewController.m
//  Humeur
//
//  Created by Ancil on 6/17/15.
//  Copyright (c) 2015 Ancil Marshall. All rights reserved.
//

#import "HumeurPickerViewController.h"

@interface HumeurPickerViewController () <UIPickerViewDelegate,UIPickerViewDataSource>

@end

@implementation HumeurPickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];

}

#pragma mark - UIPickViewDataSource Methods

-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView;
{
    return 1;
}

-(NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component;
{
    return [[self moods] count];
}

-(NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component;
{
    NSString* title;
    title = [[self moods] objectAtIndex:row];
    return title;
}

#pragma mark - Private Methods
-(NSArray*)moods;
{
    NSMutableArray* arr = [[NSMutableArray alloc] init];
    [arr addObject:NSLocalizedString(@"Happy", nil)];
    [arr addObject:NSLocalizedString(@"Sad", nil)];
    [arr addObject:NSLocalizedString(@"Angry", nil)];
    [arr addObject:NSLocalizedString(@"Tired", nil)];
    
    return [NSArray arrayWithArray:arr];
}

@end
