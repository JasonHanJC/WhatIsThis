//
//  MultiImagePickerViewController.h
//  TheOhzone
//
//  Created by Juncheng Han on 6/5/17.
//  Copyright © 2017 The Ohzone, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>


@protocol MultiImagePickerControllerDelegate;

typedef NS_ENUM(NSUInteger, ImagePickerMediaType) {
    MediaTypeImage = 0,
    MediaTypeVideo = 1
};

@interface MultiImagePickerViewController : UIViewController
/**
 * Set the numberOfSelect to limit the max number of the photo.
 * Default is 1, 0 is unlimited.
 */
@property (nonatomic, assign) NSUInteger numberOfSelect;

/**
 * Use this property to define whether the camera cell should show preview.
 * Default is NO.
 */
@property (nonatomic, assign) BOOL shouldShowPreviewForCamera;

/**
 * Use this property to define the media type you want to return. Image or Video.
 * Default is image.
 */
@property (nonatomic, assign) ImagePickerMediaType pickerMediaType;


@property (nonatomic, weak) id<MultiImagePickerControllerDelegate> delegate;

@end

@protocol MultiImagePickerControllerDelegate <NSObject>

@required

- (void)imagePickerViewControllerRecievePhotoAlbumAccessDenied:(MultiImagePickerViewController *)picker;

- (void)imagePickerViewControllerRecieveCameraAccessDenied:(MultiImagePickerViewController *)picker;

@optional

- (void)imagePickerViewController:(MultiImagePickerViewController *)picker didFinishPickingImage:(UIImage *)image;

- (void)imagePickerViewController:(MultiImagePickerViewController *)picker didFinishPickingImages:(NSArray<UIImage *> *)images;

- (void)imagePickerViewController:(MultiImagePickerViewController *)picker didFinishPickingVideo:(NSURL *)videoURL;

//- (void)imagePickerViewController:(MultiImagePickerViewController *)picker didFinishPickingVideos:(NSArray<NSURL *> *)videoURLs;

- (void)imagePickerViewControllerDidCancel:(MultiImagePickerViewController *)picker;

@end
