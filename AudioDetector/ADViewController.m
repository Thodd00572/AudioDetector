//
//  ADViewController.m
//  AudioDetector
//
//  Created by Duong Dinh Tho on 7/10/14.
//  Copyright (c) 2014 FPT Software. All rights reserved.
//

#import "ADViewController.h"
#import "Recorder.h"

#define kCompareDelta 50
#define kHighPich   1000.00f
#define kNumberOfCheckMatchingItem 5

typedef enum {
    Preparing = 0,
    Pausing,
    Recording,
    Finish

}RecordingState;

typedef enum {
    RecordTypeNone = -1,
    RecordTypeRecordingSample = 0,
    RecordTypeTrackingSample
}RecordType;

@interface ADViewController () <RecorderDelegate>
{
    Recorder * _recorder;
    float detectedFreq;           // the frequency we detected
	float deltaFreq;              // for calculating how sharp/flat user is
    
    NSArray * pattern;
    int matchCount;
    RecordingState currentState;
    NSTimer * trackingTimer;
    
    NSMutableArray * recordedSampleFreq;
    NSMutableArray * trackedIndex;
    BOOL isRecordingSample;
    BOOL isTrackingSound;
    NSArray * _imageViewAnimation;
    
    NSTimer * _timerAnimation;
    RecordType currentRecordType;
}
@end

@implementation ADViewController

#pragma mark - Setup View

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

    // Setup view
    [self setupView];
    
    matchCount = 0;
    
    // Init current state
    currentState = Preparing;
    
    // Init current record type
    currentRecordType = RecordTypeNone;
    
    // Setup recordedSampleFreq
    recordedSampleFreq = [NSMutableArray array];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setupView
{
    // Setup image for record animation
    NSMutableArray * imageViewAnimation = [NSMutableArray array];
    for (NSInteger i = 1; i <=6; i ++) {
        
        UIImageView *img = [[UIImageView alloc] initWithImage:[UIImage imageNamed:[NSString stringWithFormat:@"wave%02ld.png", (long)i]]];
        
        img.center = _btnRecord.center;
        
        [_buttonView addSubview:img];
        img.alpha = 0;
        
        [imageViewAnimation addObject:img];
    }
    _imageViewAnimation = [NSArray arrayWithArray:imageViewAnimation];
    
}

#pragma mark - Animation

static int indexAnimating = -1;

- (void)startAnimation {
    indexAnimating = 0;
    
    _timerAnimation = [NSTimer scheduledTimerWithTimeInterval:0.3f target:self selector:@selector(timerUpdate:) userInfo:nil repeats:YES];
}

- (void)stopAnimation {
    [_timerAnimation invalidate];
    _timerAnimation = nil;
    
    for (UIImageView *img in _imageViewAnimation) {
        img.alpha = 0.0f;
    }
}

- (void)timerUpdate:(NSTimer *)timer {
    indexAnimating ++;
    NSInteger count = [_imageViewAnimation count];
    if (indexAnimating >  count - 1) {
        indexAnimating = -1;
    }
    
    for (int i = 0; i < count; i++) {
        UIImageView *img = [_imageViewAnimation objectAtIndex:i];
        if (i  <= indexAnimating) {
            [UIView animateWithDuration:0.2f delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
                img.alpha = 1.0f;
            } completion:^(BOOL finished) {
                
            }];
        } else {
            [UIView animateWithDuration:0.2f delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
                img.alpha = 0.0f;
            } completion:^(BOOL finished) {
                
            }];
        }
    }
}

#pragma mark - Audio callback
void interruptionListenerCallback(void *inUserData, UInt32 interruptionState)
{
	ADViewController* controller = (__bridge ADViewController*) inUserData;
	if (interruptionState == kAudioSessionBeginInterruption)
		[controller beginInterruption];
	else if (interruptionState == kAudioSessionEndInterruption)
		[controller endInterruption];
}


- (void)beginInterruption
{
	[self stopAudioRecorder];
}

- (void)endInterruption
{
	[self startAudioRecorder];
}

#pragma mark - Audio Handler

- (void)stopAudioRecorder
{
    if (_recorder != nil)
	{
		[_recorder stopRecording];
		_recorder = nil;
        
		AudioSessionSetActive(false);
	}
}

/*
 * Starts recording from the microphone. Also starts the audio player.
 */
- (void)startAudioRecorder
{
	if (_recorder == nil)  // should always be the case
	{
		AudioSessionInitialize(
                               NULL,
                               NULL,
                               interruptionListenerCallback,
                               (__bridge void *)(self)
                               );
        
		UInt32 sessionCategory = kAudioSessionCategory_RecordAudio;
		AudioSessionSetProperty(
                                kAudioSessionProperty_AudioCategory,
                                sizeof(sessionCategory),
                                &sessionCategory
                                );
        
		AudioSessionSetActive(true);
        
        [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
		
		_recorder = [[Recorder alloc] init];
		_recorder.delegate = self;
        _recorder.trackingPitch = YES;
        currentState = Recording;
		[_recorder startRecording];
	}
}

#pragma mark - Timer Handler
- (void)startTimer
{
//    trackingTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(handleTimer) userInfo:nil repeats:YES];
    
    matchCount = 0;
    
    NSLog(@"timer started");
}

#pragma mark - Audio Record Processing
- (void)preparePlay
{
    detectedFreq = 0;
    
    deltaFreq = 0.0f;

    _recorder.trackingPitch= YES;
    currentState = Recording;
}

- (void)pauseRecording
{
    currentState = Recording;
    _recorder.trackingPitch=  YES;
}

- (void)stopTimer
{
    if( trackingTimer)
    {
        [trackingTimer invalidate];
        trackingTimer   = nil;
    }
}


- (void)recordedFreq:(float)freq
{
            NSLog(@"%lf",freq);
    if (currentState == Recording)
    {

        detectedFreq = freq;
        
        deltaFreq = 0.0f;
        
        if (freq > kHighPich)  // record high pitch
        {
            if (isRecordingSample)
            {
                [recordedSampleFreq addObject:[NSNumber numberWithFloat:freq]];
            }
            
            if (isTrackingSound)
            {
                [self matchingSoundWithInputPitch:freq];
            }
        }
    }
}

- (void)matchingSoundWithInputPitch:(float)pitch
{
    NSNumber * trackedFreq = [NSNumber numberWithFloat:pitch];
    for (NSNumber * freqItem in recordedSampleFreq)
    {
        float delta = fabsf([freqItem floatValue] - [trackedFreq floatValue]);
        NSLog(@"deta: %lf",delta);

        if (delta <= kCompareDelta)
        {
            NSLog(@"Add index in trackedIndex Array: %@",trackedIndex);
            if (trackedIndex == nil)
            {
                trackedIndex = [NSMutableArray array];
            }
            [trackedIndex addObject:[NSNumber numberWithInteger:[recordedSampleFreq indexOfObject:freqItem]]];
        }
        else
        {
            NSLog(@"Wipe out recorded Data with recorded freq: %@",trackedFreq);
            trackedIndex = [NSMutableArray array];
        }
        
        if ([trackedIndex count] >= kNumberOfCheckMatchingItem)
        {
            _recorder.trackingPitch = NO;
            [self showResult];
            trackedIndex = [NSMutableArray array];
        }
        
    }

}

#pragma mark - Internal Methods

- (void)startRecordingSample
{
    [self resetResult];
    // Stop receiving pitch
    _recorder.trackingPitch = NO;
    // Change flag status
    isRecordingSample = ! isRecordingSample;
    if (isRecordingSample)
    {
        [self startAudioRecorder];
        [self startAnimation];
        recordedSampleFreq = [NSMutableArray array];
        [_btnRecordSample setTitle:@"RECORDING" forState:UIControlStateNormal];
        [_lblStatus setText:@"Recording sample..."];
    }
    else
    {
        [self stopAudioRecorder];
        [self stopAnimation];
        NSLog(@"Recorded sample: %@",recordedSampleFreq);
        [_btnRecordSample setTitle:@"RECORD SAMPLE" forState:UIControlStateNormal];

        if ([recordedSampleFreq count] > 0)
        {
            [_lblStatus setText:@"Samples prepared"];
        }
        else
        {
            [_lblStatus setText:@"Preparing recording..."];
        }
    }
    // Continue receiving pitch
    _recorder.trackingPitch = YES;
}

- (void)startTrackingSample
{
    [self resetResult];
    // Stop receiving pitch
    _recorder.trackingPitch = NO;
    isTrackingSound = ! isTrackingSound;
    if (isTrackingSound)
    {
        [self startAudioRecorder];
        [self startAnimation];
        [_btnTrackSound setTitle:@"TRACKING..." forState:UIControlStateNormal];
        [_lblStatus setText:@"Tracking sample..."];
    }
    else
    {
        [self stopAudioRecorder];
        [self stopAnimation];
        [_btnTrackSound setTitle:@"START TRACKING" forState:UIControlStateNormal];
        [_lblStatus setText:@"Preparing tracking..."];
    }
    
    // Continue receiving pitch
    _recorder.trackingPitch = YES;
    
}

- (void)resetResult
{
    _lblResult.alpha = 0;
    [_lblResult setText:@"Matching..."];

}

- (void)showResult
{
    _lblResult.alpha = 1;
    NSString * barcodeResult = @"Hello world";
    [_lblResult setText:[NSString stringWithFormat:@"Audio barcode detected with result: %@",barcodeResult]];
    
    [self scheduleLocalNotification];
    
}

- (void)scheduleLocalNotification{
    // Setup local notification
    NSDate * scheduleDate = [[NSDate date] dateByAddingTimeInterval:1];
    
    UILocalNotification *localNotif = [[UILocalNotification alloc] init];
    if (localNotif == nil)
        return;
    localNotif.fireDate = scheduleDate;
    localNotif.timeZone = [NSTimeZone defaultTimeZone];
    
    localNotif.alertBody = [NSString stringWithFormat:NSLocalizedString(@"There is promotion here",nil)];
    localNotif.alertAction = NSLocalizedString(@"View Details", nil);
    
    localNotif.soundName = UILocalNotificationDefaultSoundName;
    localNotif.applicationIconBadgeNumber = 1;
    
    // Set info dict
    NSDictionary *infoDict = [NSDictionary dictionaryWithObject:@"ObjectNotification" forKey:@"NofKey"];
    localNotif.userInfo = infoDict;
    
    [[UIApplication sharedApplication] scheduleLocalNotification:localNotif];
}

#pragma mark - IBActions

- (IBAction)pressBtnStart:(id)sender
{
    [self startTimer];
}

- (IBAction)pressBtnRecord:(id)sender {
    
    switch (currentRecordType) {
        case RecordTypeNone:
            break;
            
        case RecordTypeRecordingSample:
            [self  startRecordingSample];
            break;
            
        case RecordTypeTrackingSample:
            [self startTrackingSample];
            break;
            
        default:
            break;
    }
}

- (IBAction)changeSegment:(id)sender {
    [self stopAudioRecorder];
    switch (_segMode.selectedSegmentIndex) {
        case 0: // NONE
            [_lblStatus setText:@"Welcome to sound barcode tracking"];
            currentRecordType = RecordTypeNone;
            break;
            
        case 1: // Record sample
            [_lblStatus setText:@"Preparing recording..."];
            currentRecordType = RecordTypeRecordingSample;
            break;
            
        case 2: // Start tracking
            [_lblStatus setText:@"Preparing tracking..."];
            currentRecordType = RecordTypeTrackingSample;
            break;
            
        default:
            break;
    }
}

@end
