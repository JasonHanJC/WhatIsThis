//
//  MPCameraCell.h
//  TheOhzone
//
//  Created by Juncheng Han on 6/6/17.
//  Copyright © 2017 The Ohzone, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface MPCameraCell : UICollectionViewCell

@property (nonatomic, readonly) AVCaptureSession *session;
@property (nonatomic, assign) BOOL shouldShowPreview;

@end
