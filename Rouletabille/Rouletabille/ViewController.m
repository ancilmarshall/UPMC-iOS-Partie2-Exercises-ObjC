//
//  ViewController.m
//  Rouletabille
//
//  Created by Ancil on 6/9/15.
//  Copyright (c) 2015 Ancil Marshall. All rights reserved.
//

#import <CoreMotion/CoreMotion.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "ViewController.h"

static const NSTimeInterval updateInterval = 0.01; //100 Hz
static const CGFloat acc_deadband_threshold = 0.02;
static const CGFloat acc_max = 1.0;
static NSString* const kStarfishBoundaryIdentifier = @"starfish";
static const NSUInteger kCountdownTime = 20;
static const CGFloat kCollisionBoundaryRatio = 0.25;
static const NSUInteger kMinStarfishDisanceRatio = 3;

@interface ViewController () <UICollisionBehaviorDelegate, AVAudioPlayerDelegate>

@property (nonatomic,strong) CMMotionManager* cmmanager;
@property (nonatomic,strong) UIDynamicAnimator* animator;
@property (nonatomic,strong) UIGravityBehavior* gravity;
@property (nonatomic,strong) UICollisionBehavior* boundary;
@property (nonatomic,strong) UIImageView* ball;
@property (nonatomic,strong) UIImageView* starfish;
@property (nonatomic,strong) AVAudioPlayer* backgroundAudioPlayer;
@property (nonatomic,strong) AVAudioPlayer* wallBumpAudioPlayer;
@property (nonatomic,strong) AVAudioPlayer* starBumpAudioPlayer;
@property (nonatomic,strong) NSTimer* timer;
@property (nonatomic,assign) NSUInteger countdownTime;
@property (weak, nonatomic) IBOutlet UILabel *countdownLabel;
@property (nonatomic,assign) NSUInteger score;
@property (weak, nonatomic) IBOutlet UILabel *scoreLabel;
@property (nonatomic,assign) dispatch_queue_t dispatchQueue;
@property (nonatomic,strong) UIDynamicItemBehavior* itemBehavior;
@property (weak, nonatomic) IBOutlet UIButton *startGameButton;
@property (weak, nonatomic) IBOutlet UIButton *quitGameButton;
@property (weak, nonatomic) IBOutlet UILabel *countdownEndingIndicator;
@end

@implementation ViewController

#pragma mark - Initialization

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.countdownEndingIndicator.hidden = YES;
    self.quitGameButton.enabled = NO;
    self.quitGameButton.tintColor = [UIColor whiteColor];
    [self resetCountdownLabel];

    //initialize audio players background queue, since may take time to load
    self.dispatchQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(self.dispatchQueue, ^(void){
        self.backgroundAudioPlayer = [self audioPlayerWithSound:@"midnight-ride-01a"];
        self.wallBumpAudioPlayer = [self audioPlayerWithSound:@"son"];
        self.starBumpAudioPlayer = [self audioPlayerWithSound:@"squeeze-toy-1"];
        
    });
    
    //core motion manager for acceleration data
    self.cmmanager = [[CMMotionManager alloc] init];
    if (self.cmmanager == nil){
        NSLog(NSLocalizedString(@"CMMotion Manager unable to be defined",nil));
    }
    if (![self.cmmanager isAccelerometerAvailable]){
        NSLog(NSLocalizedString(@"Acclerometer is not available",nil));
    }
    
    //background view
    UIImageView* bg = [[UIImageView alloc] initWithFrame:self.view.frame];
    bg.image = [UIImage imageNamed:@"rouletabille-fond-eau.jpg"];
    [self.view addSubview:bg];
    [self.view sendSubviewToBack:bg]; // to move behind labels in the IB storyboard
    
    //add ball object, centered in the view
    self.ball = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"bille"]];
    self.ball.hidden = YES;
    [self.view addSubview:self.ball];
    
    //add starfish target object
    self.starfish = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"etoile-96"]];
    self.starfish.hidden = YES;
    [self.view addSubview:self.starfish];
    
    //UI Kit Dynamics
    self.animator = [[UIDynamicAnimator alloc] initWithReferenceView:self.view];
    self.gravity = [[UIGravityBehavior alloc] initWithItems:@[self.ball]];
    self.gravity.magnitude = 0;
    self.gravity.angle = 0;
    
    self.boundary = [[UICollisionBehavior alloc] initWithItems:@[self.ball]];
    self.boundary.translatesReferenceBoundsIntoBoundary = YES;
    
    //add a bit of elasticity to the ball to add bounce
    self.itemBehavior = [[UIDynamicItemBehavior alloc] initWithItems:@[self.ball]];
    self.itemBehavior.elasticity = 0.5;

    self.boundary.collisionDelegate = self;
    
}

#pragma mark - Game Controls

- (IBAction)startGame:(UIButton *)sender {
    
    // set ball and starfish's frame
    self.ball.center = [self.view center];
    self.starfish.frame = [self randomStarfishFrame];
    [self.boundary addBoundaryWithIdentifier:kStarfishBoundaryIdentifier
                                     forPath:[self starfishCollisionBoundary]];
    
    self.ball.hidden = NO;
    self.starfish.hidden = NO;
    self.startGameButton.hidden = YES;
    self.quitGameButton.enabled = YES;
    
    dispatch_async(self.dispatchQueue, ^{
        if ([self.backgroundAudioPlayer prepareToPlay]){
            [self.backgroundAudioPlayer play];
        }
    });
    
    self.score = 0;
    //Start a countdown timer
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                  target:self
                                                selector:@selector(updateCountdownTimer:)
                                                userInfo:nil
                                                 repeats:YES];
    self.countdownTime = kCountdownTime; //seconds
    [self updateCountdownLabel];
    [self updateScoreLabel];
    
    [self.animator addBehavior:self.gravity];
    [self.animator addBehavior:self.boundary];
    [self.animator addBehavior:self.itemBehavior];
    
    if (self.cmmanager){
        self.cmmanager.accelerometerUpdateInterval = updateInterval;
        [self.cmmanager startAccelerometerUpdatesToQueue:[NSOperationQueue mainQueue]
                                             withHandler:
         
            ^(CMAccelerometerData *accelerometerData, NSError *error) {
                if (error != nil){
                    NSLog(NSLocalizedString(@"Error in CMAcceleratorData update", nil));
                }
                else {
                    
                    CGFloat acc_x = accelerometerData.acceleration.x;
                    CGFloat acc_y = accelerometerData.acceleration.y;
                    
                    CGFloat mag = sqrt( acc_x*acc_x + acc_y*acc_y);
                    if ( mag < acc_deadband_threshold){
                        mag = 0.0f;
                    }
                    else if ( mag > acc_max ){
                        mag = acc_max;
                    }
                    
                    // Gravity angle is measured clockwise from +ve X-axis
                    CGFloat angle = atan2(-acc_y, acc_x);
                    
                    self.gravity.magnitude = mag;
                    self.gravity.angle = angle;
                }
            }];
    }
}

-(void)stopGame;
{
    [self.timer invalidate];
    self.timer = nil;
    self.ball.hidden = YES;
    self.starfish.hidden = YES;
    self.quitGameButton.enabled = NO;
    [self.animator removeAllBehaviors];
    if ([self.cmmanager isAccelerometerActive]){
        [self.cmmanager stopAccelerometerUpdates];
    }
    self.score = 0;
    [self resetCountdownLabel];
    [self updateScoreLabel];
    
    dispatch_after(5.0, self.dispatchQueue, ^{
        [self.backgroundAudioPlayer stop];
    });
    
    UIAlertController* alert =
    [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Game Over", nil)
                                        message:[NSString stringWithFormat:NSLocalizedString(@"Score: %tu",nil),self.score]
                                 preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* quit = [UIAlertAction actionWithTitle:NSLocalizedString(@"Main Screen",nil)
                                                   style:UIAlertActionStyleCancel
                                                 handler:^(UIAlertAction *action) {
                                                     self.startGameButton.hidden = NO;
                                                 }];
    UIAlertAction* replay = [UIAlertAction actionWithTitle:NSLocalizedString(@"Replay", nil)
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *action) {
                                                       [self startGame:nil];
                                                   }];
    
    [alert addAction:quit];
    [alert addAction:replay];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)quitGame:(UIButton *)sender;
{
    [self.timer invalidate];
    self.timer = nil;
    self.quitGameButton.enabled = NO;
    [self.animator removeAllBehaviors];
    
    
    UIAlertController* alert =
    [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Game in Progress",nil)
                                        message:NSLocalizedString(@"Quit Game?",nil)
                                 preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* no = [UIAlertAction actionWithTitle:NSLocalizedString(@"Resume", nil)
                                                 style:UIAlertActionStyleCancel
                                               handler:^(UIAlertAction *action) {
                                                   [self resumeGame];
                                               }];
    UIAlertAction* yes = [UIAlertAction actionWithTitle:NSLocalizedString(@"Stop", nil)
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *action) {
                                                     self.startGameButton.hidden = NO;
                                                     [self stopGame];
                                                 }];

    [alert addAction:no];
    [alert addAction:yes];
    
    [self presentViewController:alert animated:YES completion:nil];
    
}


-(void)resumeGame;
{
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                  target:self
                                                selector:@selector(updateCountdownTimer:)
                                                userInfo:nil
                                                 repeats:YES];
    
    [self.animator addBehavior:self.gravity];
    [self.animator addBehavior:self.boundary];
    [self.animator addBehavior:self.itemBehavior];
    self.quitGameButton.enabled = YES;
}


#pragma mark - CollisionBehavior Methods

-(void)collisionBehavior:(UICollisionBehavior *)behavior
     beganContactForItem:(id<UIDynamicItem>)item
  withBoundaryIdentifier:(NSString*)identifier
                 atPoint:(CGPoint)p
{

    if ( [identifier isEqualToString:kStarfishBoundaryIdentifier] ){
        
        if (self.starBumpAudioPlayer != nil){
            if ([self.starBumpAudioPlayer prepareToPlay]){
                [self.starBumpAudioPlayer play];
            }
        } else {
            NSLog(NSLocalizedString(@"StarfishBump Audio Player is nil",nil));
        }
        
        [self.boundary removeBoundaryWithIdentifier:kStarfishBoundaryIdentifier];
        self.starfish.frame = [self randomStarfishFrame];
        [self.boundary addBoundaryWithIdentifier:kStarfishBoundaryIdentifier
                                         forPath:[self starfishCollisionBoundary]];
        self.score = self.score + 1;
        [self updateScoreLabel];
    }
    else { // wall boundrary
        if (self.wallBumpAudioPlayer != nil){
        }
            if ([self.wallBumpAudioPlayer prepareToPlay]){
                [self.wallBumpAudioPlayer play];
        }
        else {
            NSLog(NSLocalizedString(@"WallBumpAudioPlayer is nil",nil));
        }
    }
}

-(CGRect)randomStarfishFrame;
{
    // let the starfish center always be at least 3 ball widths away from the current ball position
    CGFloat ballwidth = CGRectGetWidth(self.ball.frame);
    CGPoint ballcenter = self.ball.center;
    CGRect frame = self.starfish.frame;
    CGPoint framecenter;
        
    do {
    
        CGPoint origin = CGPointMake(arc4random_uniform(self.view.frame.size.width-frame.size.width),
                                   arc4random_uniform(self.view.frame.size.height-frame.size.height));
        
        frame.origin = origin;
        
        framecenter = CGPointMake(CGRectGetMidX(frame),CGRectGetMidY(frame));
    
    } while ( [self distanceBetweenPoint:ballcenter andPoint:framecenter] <
             kMinStarfishDisanceRatio * ballwidth );
    
    return frame;
}

-(UIBezierPath*)starfishCollisionBoundary;
{
    CGRect rect = CGRectInset(self.starfish.frame, self.starfish.frame.size.width*kCollisionBoundaryRatio,
                              self.starfish.frame.size.width*kCollisionBoundaryRatio);
    return [UIBezierPath bezierPathWithRect:rect];
}


#pragma mark - Audio Player methods

-(AVAudioPlayer*)audioPlayerWithSound:(NSString*)sound;
{
    NSBundle* bundle = [NSBundle mainBundle];
    NSString* path = [bundle pathForResource:sound ofType:@"mp3"];
    NSData* data = [NSData dataWithContentsOfFile:path];
    NSError* error;
    AVAudioPlayer* player = [[AVAudioPlayer alloc] initWithData:data error:&error];
    if (error != nil || player == nil){
        NSLog(@"Error initializing audio player");
    }else{
        player.delegate = self;
    }
    return player;
}

#pragma mark - Game Labels

-(void)updateCountdownTimer:(id)sender;
{
    self.countdownTime = self.countdownTime - 1;
    [self updateCountdownLabel];
    
    if (self.countdownTime <= 3 && self.countdownTime >=1){
        [self countdownEndingIndicatorAnimation:self.countdownTime];
    }
    if (self.countdownTime == 0){
        [self stopGame];
    }
}

-(void)countdownEndingIndicatorAnimation:(NSUInteger)time;
{
    self.countdownEndingIndicator.text = [NSString stringWithFormat:@"%tu",time];
    self.countdownEndingIndicator.alpha = 0.8;
    self.countdownEndingIndicator.hidden = NO;
    
    [UIView animateWithDuration:0.7 animations:^{
        
        self.countdownEndingIndicator.alpha = 0;
    } completion:^(BOOL finished) {
        self.countdownEndingIndicator.hidden = YES;
    }];
}

-(void)resetCountdownLabel;
{
    self.countdownLabel.text = @"--:--";
}

-(void)updateCountdownLabel;
{
    NSUInteger minute = self.countdownTime / 60;
    NSUInteger second = self.countdownTime % 60;
    self.countdownLabel.text = [NSString stringWithFormat:@"%02tu:%02tu",minute,second];
}

-(void)updateScoreLabel;
{
    self.scoreLabel.text =
        [NSString stringWithFormat:NSLocalizedString(@"Score: %tu",@"Game Score Label"),self.score];
}

# pragma mark - Helper functions

-(BOOL)prefersStatusBarHidden;
{
    return YES;
}

-(CGFloat)distanceBetweenPoint:(CGPoint)a andPoint:(CGPoint)b
{
    CGFloat dx = a.x - b.x;
    CGFloat dy = a.y - b.y;
    
    return sqrt( dx*dx + dy*dy);
}

@end
