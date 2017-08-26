//
//  MPPhotoCell.h
//  TheOhzone
//
//  Created by Juncheng Han on 6/6/17.
//  Copyright © 2017 The Ohzone, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

@interface MPPhotoCell : UICollectionViewCell

@property (nonatomic, assign) NSUInteger selectionOrder;

@property (nonatomic, strong) NSString *representedAssetIdentifier;

- (void)loadPhotoWithManager:(PHImageManager *)manager forAsset:(PHAsset *)asset targetSize:(CGSize)size;

- (void)setNeedsAnimateSelection;

@end
