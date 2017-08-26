//
//  MPPhotoCell.m
//  TheOhzone
//
//  Created by Juncheng Han on 6/6/17.
//  Copyright © 2017 The Ohzone, Inc. All rights reserved.
//

#import "MPPhotoCell.h"

static const CGFloat hightedAnimationDuration = 0.15;
static const CGFloat unhightedAnimationDuration = 0.4;
static const CGFloat hightedAnimationTransformScale = 0.8;
static const CGFloat unhightedAnimationSpringDamping = 0.4;
static const CGFloat unhightedAnimationSpringVelocity = 5.0;

@interface MPPhotoCell()

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIView *selectionVeil;
@property (weak, nonatomic) IBOutlet UILabel *selectionOrderLabel;
@property (weak, nonatomic) IBOutlet UIImageView *videoIndicator;

@property (nonatomic, weak) PHImageManager *imageManager;
@property (nonatomic, assign) PHImageRequestID imageRequestID;
@property (nonatomic, assign) BOOL animateSelection;
@property (nonatomic, assign, getter=isAnimatingHighlight) BOOL animateHighlight;
@property (nonatomic, strong) UIImage *thumbnailImage;

- (void)cancelImageRequest;
- (void)setSelected:(BOOL)selected animated:(BOOL)animated;

@end

@implementation MPPhotoCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    
    self.selectionOrderLabel.layer.cornerRadius = 12;
    self.selectionOrderLabel.layer.masksToBounds = YES;
    
    self.selectionVeil.layer.borderWidth = 1.0;
    self.selectionVeil.layer.borderColor = [UIColor colorWithRed:40/255.0 green:149/255.0 blue:255/255.0 alpha:1].CGColor;
    
    [self prepareForReuse];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    [self cancelImageRequest];
    
    self.videoIndicator.alpha = 0.0;
    self.imageView.image = nil;
    self.selectionVeil.alpha = 0.0;
    self.selectionOrderLabel.alpha = 0.0;
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    
    [self setSelected:selected animated:self.animateSelection];
}

- (void)setSelectionOrder:(NSUInteger)selectionOrder
{
    _selectionOrder = selectionOrder;
    self.selectionOrderLabel.text = [NSString stringWithFormat:@"%zd", selectionOrder];
}

- (void)dealloc
{
    [self cancelImageRequest];
}

#pragma mark - Public Methods

- (void)loadPhotoWithManager:(PHImageManager *)manager forAsset:(PHAsset *)asset targetSize:(CGSize)size
{
    self.videoIndicator.alpha = asset.mediaType == PHAssetMediaTypeVideo ? 0.95 : 0.0;
    self.imageManager = manager;
    self.imageRequestID = [self.imageManager requestImageForAsset:asset
                                                       targetSize:size
                                                      contentMode:PHImageContentModeAspectFill
                                                          options:nil
                                                    resultHandler:^(UIImage *result, NSDictionary *info) {
                                                        // Set the cell's thumbnail image if it's still showing the same asset.
                                                        if ([self.representedAssetIdentifier isEqualToString:asset.localIdentifier]) {
                                                            self.thumbnailImage = result;
                                                        }
                                                    }];
}

- (void)setNeedsAnimateSelection
{
    self.animateSelection = YES;
}

- (void)setHighlighted:(BOOL)highlighted {
    if (highlighted) {
        self.animateHighlight = YES;
        [UIView animateWithDuration:hightedAnimationDuration delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
            self.selectionOrderLabel.transform = CGAffineTransformMakeScale(hightedAnimationTransformScale, hightedAnimationTransformScale);
        } completion:^(BOOL finished) {
            self.animateHighlight = NO;
        }];
    }
    else {
        [UIView animateWithDuration:unhightedAnimationDuration delay:self.isAnimatingHighlight? hightedAnimationDuration: 0 usingSpringWithDamping:unhightedAnimationSpringDamping initialSpringVelocity:unhightedAnimationSpringVelocity options:UIViewAnimationOptionAllowUserInteraction animations:^{
            self.selectionOrderLabel.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

#pragma mark - Private Methods

- (void)setThumbnailImage:(UIImage *)thumbnailImage
{
    _thumbnailImage = thumbnailImage;
    self.imageView.image = thumbnailImage;
}

- (void)cancelImageRequest
{
    if (self.imageRequestID != PHInvalidImageRequestID) {
        [self.imageManager cancelImageRequest:self.imageRequestID];
        self.imageRequestID = PHInvalidImageRequestID;
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    if (!animated) {
        self.selectionVeil.alpha = selected ? 1.0 : 0.0;
        self.selectionOrderLabel.alpha = selected ? 1.0 : 0.0;
    }
    else {

        [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
            self.selectionVeil.alpha = selected ? 1.0 : 0.0;
            self.selectionOrderLabel.alpha = selected ? 1.0 : 0.0;
        } completion:^(BOOL finished) {
            
        }];
    }
    self.animateSelection = NO;
}

@end
