//
//  ADViewController.h
//  AudioDetector
//
//  Created by Duong Dinh Tho on 7/10/14.
//  Copyright (c) 2014 FPT Software. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ADViewController : UIViewController

#pragma mark - IBOutlet
@property (weak, nonatomic) IBOutlet UIButton *btnRecordSample;
@property (weak, nonatomic) IBOutlet UILabel *lblStatus;
@property (weak, nonatomic) IBOutlet UIButton *btnTrackSound;
@property (weak, nonatomic) IBOutlet UIButton *btnRecord;
@property (weak, nonatomic) IBOutlet UIView *buttonView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segMode;
@property (weak, nonatomic) IBOutlet UILabel *lblResult;

#pragma mark - Properties


#pragma mark - IBAction
- (IBAction)pressBtnStart:(id)sender;
//- (IBAction)btnTrackSoundDidTouch:(id)sender;
- (IBAction)pressBtnRecord:(id)sender;
- (IBAction)changeSegment:(id)sender;
@end
