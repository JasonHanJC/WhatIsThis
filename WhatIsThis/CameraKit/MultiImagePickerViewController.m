//
//  MultiImagePickerViewController.m
//  TheOhzone
//
//  Created by Juncheng Han on 6/5/17.
//  Copyright © 2017 The Ohzone, Inc. All rights reserved.
//

#import "MultiImagePickerViewController.h"
#import <Photos/Photos.h>
#import "IOSDefines.h"
#import "MPCameraCell.h"
#import "MPPhotoCell.h"
#import "ImagePickerHelper.h"
#import <MobileCoreServices/MobileCoreServices.h>

static NSString * const cameraCellNibName = @"MPCameraCell";
static NSString * const photoCellNibName = @"MPPhotoCell";
static const CGFloat imageMaxTargetPixel = 1280;

@interface MultiImagePickerViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UINavigationControllerDelegate, PHPhotoLibraryChangeObserver, UIImagePickerControllerDelegate, UINavigationBarDelegate>

@property (weak, nonatomic) IBOutlet UINavigationBar *navigationBar;
@property (weak, nonatomic) IBOutlet UICollectionView *photoCollectionView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *navigationBarTopLayoutConstraint;
@property (weak, nonatomic) IBOutlet UIButton *previewButton;
@property (weak, nonatomic) IBOutlet UILabel *numberOfSelectionLabel;
@property (weak, nonatomic) IBOutlet UILabel *numberOfSelectedLabel;

@property (nonatomic, strong) PHImageManager *imageManager;
@property (nonatomic, weak) AVCaptureSession *session;
@property (nonatomic, strong) NSArray *collectionItems;
@property (nonatomic, strong) NSDictionary *currentCollectionItem;
@property (nonatomic, strong) NSMutableArray *selectedPhotos;
@property (nonatomic, strong) UIBarButtonItem *doneItem;
@property (nonatomic, assign) BOOL needToSelectFirstPhoto;
@property (nonatomic, assign) CGSize cellPortraitSize;
@property (nonatomic, assign) CGSize cellLandscapeSize;
@property (nonatomic, assign) NSUInteger numberOfPhotoColumns;

- (IBAction)dismiss:(id)sender;
- (IBAction)presentAlbumPickerView:(id)sender;
- (IBAction)finishPickingPhotos:(id)sender;
- (void)updateViewWithCollectionItem:(NSDictionary *)collectionItem;
- (void)refreshPhotoSelection;
- (void)fetchCollections;
- (BOOL)allowsMultipleSelection;
- (BOOL)canAddPhoto;
- (IBAction)previewPhotos:(id)sender;
- (void)setupCellSize;
@end

@implementation MultiImagePickerViewController

- (instancetype)init {
    self = [super initWithNibName:NSStringFromClass([self class]) bundle:[NSBundle bundleForClass:[self class]]];
    if (self) {
        // default init
        self.numberOfSelect = 1;
//        self.shouldReturnImageForSingleSelect = YES;
        self.shouldShowPreviewForCamera = NO;
        
        if (IPAD) {
            self.numberOfPhotoColumns = 4;
        } else {
            self.numberOfPhotoColumns = 3;
        }
        self.pickerMediaType = MediaTypeImage;
        self.selectedPhotos = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.imageManager = [[PHCachingImageManager alloc] init];
    
    self.photoCollectionView.delegate = self;
    self.photoCollectionView.dataSource = self;
    
    // Register the cell
    UINib *cellNib = [UINib nibWithNibName:cameraCellNibName bundle:[NSBundle bundleForClass:[MPCameraCell class]]];
    [self.photoCollectionView registerNib:cellNib forCellWithReuseIdentifier:cameraCellNibName];
    cellNib = [UINib nibWithNibName:photoCellNibName bundle:[NSBundle bundleForClass:[MPPhotoCell class]]];
    [self.photoCollectionView registerNib:cellNib forCellWithReuseIdentifier:photoCellNibName];
    self.photoCollectionView.allowsMultipleSelection = self.allowsMultipleSelection;
    
    // fetch the photo data
    [self fetchCollections];
    
    // setup the navigation bar
    UINavigationItem *navigationItem = [[UINavigationItem alloc] init];
    navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(dismiss:)];
    
    if (self.allowsMultipleSelection) {
        self.doneItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(finishPickingPhotos:)];
        navigationItem.rightBarButtonItem = self.doneItem;
        self.doneItem.enabled = NO;
    }
    
    self.navigationBar.items = @[navigationItem];
    
    // update the collection view with the "Camera roll assets"
    [self updateViewWithCollectionItem:self.collectionItems[0]];
    
    self.cellPortraitSize = self.cellLandscapeSize = CGSizeZero;
    
    self.numberOfSelectionLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.numberOfSelect];
    self.numberOfSelectedLabel.text = @"0";
    
    self.previewButton.enabled = NO;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self.photoCollectionView.collectionViewLayout invalidateLayout];
}


#pragma mark - private methods

- (void)fetchCollections {
    
    NSMutableArray *allAblums = [[NSMutableArray alloc] init];
    
    PHFetchResult *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
    
    //set up fetch options, mediaType is image.
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    
    switch (self.pickerMediaType) {
        case MediaTypeImage:
            options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeImage];
            break;
        case MediaTypeVideo:
            options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeVideo];
            break;
        default:
            break;
    }
    for (PHAssetCollection *collection in smartAlbums) {
        PHFetchResult *assetsFetchResult = [PHAsset fetchAssetsInAssetCollection:collection options:options];
        
        if (assetsFetchResult.count > 0) {
            // put the "Camera Roll" in the first place
            if  (collection.assetCollectionSubtype == PHAssetCollectionSubtypeSmartAlbumUserLibrary) {
                [allAblums insertObject:@{@"collection" : collection, @"assets" : assetsFetchResult} atIndex:0];
            } else {
                [allAblums addObject:@{@"collection" : collection, @"assets" : assetsFetchResult}];
            }
        }
    }
    
    self.collectionItems = [allAblums copy];
}

- (BOOL)canAddPhoto {
    return (self.numberOfSelect == 0 || self.selectedPhotos.count < self.numberOfSelect);
}

- (BOOL)allowsMultipleSelection {
    return (self.numberOfSelect != 1);
}

- (void)updateViewWithCollectionItem:(NSDictionary *)collectionItem {
    self.currentCollectionItem = collectionItem;
    
    // update the navigation bar title
    PHCollection *collection = self.currentCollectionItem[@"collection"];

    UIButton *albumButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [albumButton addTarget:self action:@selector(presentAlbumPickerView:) forControlEvents:UIControlEventTouchUpInside];
    [albumButton setTitle:collection.localizedTitle forState:UIControlStateNormal];
    [albumButton.titleLabel setFont:[UIFont systemFontOfSize:17]];
  
    [self.navigationBar.items firstObject].titleView = albumButton;
    
    [self.photoCollectionView reloadData];
    // refresh photo selection
    [self refreshPhotoSelection];
}

- (void)refreshPhotoSelection {
    // keep the selection when change the ablum
    PHFetchResult *fetchResult = self.currentCollectionItem[@"assets"];
    NSInteger numberOfSelection = self.selectedPhotos.count;
    
    for (NSInteger i = 0;i < fetchResult.count;i++) {
        PHAsset *thisAssest = fetchResult[i];
        if ([self.selectedPhotos containsObject:thisAssest]) {
            // select the cell, i + 1 because there is a camera cell
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i + 1 inSection:0];
            [self.photoCollectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
            // set the cell order
            MPPhotoCell *cell = (MPPhotoCell *)[self.photoCollectionView cellForItemAtIndexPath:indexPath];
            cell.selectionOrder = [self.selectedPhotos indexOfObject:thisAssest] + 1;
            
            numberOfSelection--;
            if (numberOfSelection == 0) {
                break;
            }
        }
    }
}

- (UIImage *)orientationNormalizedImage:(UIImage *)image
{
    if (image.imageOrientation == UIImageOrientationUp) return image;
    
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    [image drawInRect:CGRectMake(0.0, 0.0, image.size.width, image.size.height)];
    UIImage *normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return normalizedImage;
}

- (void)setupCellSize
{
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.photoCollectionView.collectionViewLayout;
    
    // Fetch shorter length
    CGFloat arrangementLength = MIN(CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame));
    
    CGFloat minimumInteritemSpacing = layout.minimumInteritemSpacing;
    UIEdgeInsets sectionInset = layout.sectionInset;
    
    CGFloat totalInteritemSpacing = MAX((self.numberOfPhotoColumns - 1), 0) * minimumInteritemSpacing;
    CGFloat totalHorizontalSpacing = totalInteritemSpacing + sectionInset.left + sectionInset.right;
    
    // Caculate size for portrait mode
    CGFloat size = (CGFloat)floor((arrangementLength - totalHorizontalSpacing) / self.numberOfPhotoColumns);
    self.cellPortraitSize = CGSizeMake(size, size);
    
    // Caculate size for landsacpe mode
    arrangementLength = MAX(CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame));
    NSUInteger numberOfPhotoColumnsInLandscape = (arrangementLength - sectionInset.left + sectionInset.right)/size;
    totalInteritemSpacing = MAX((numberOfPhotoColumnsInLandscape - 1), 0) * minimumInteritemSpacing;
    totalHorizontalSpacing = totalInteritemSpacing + sectionInset.left + sectionInset.right;
    size = (CGFloat)floor((arrangementLength - totalHorizontalSpacing) / numberOfPhotoColumnsInLandscape);
    self.cellLandscapeSize = CGSizeMake(size, size);
}

#pragma mark - IBActions

- (IBAction)dismiss:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(imagePickerViewControllerDidCancel:)]) {
        [self.delegate imagePickerViewControllerDidCancel:self];
    }
    else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (IBAction)presentAlbumPickerView:(id)sender
{
    // TODO: show album picker
}

- (IBAction)finishPickingPhotos:(id)sender
{
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [indicator startAnimating];
    UIBarButtonItem *indicatorItem = [[UIBarButtonItem alloc] initWithCustomView:indicator];
    UINavigationItem *navigationItem = [self.navigationBar.items firstObject];
    navigationItem.rightBarButtonItem = indicatorItem;
    
    if ([self.delegate respondsToSelector:@selector(imagePickerViewController:didFinishPickingImages:)]) {
        
        switch (self.pickerMediaType) {
            case MediaTypeImage:
            {
                PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
                options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
                options.networkAccessAllowed = YES;
                options.resizeMode = PHImageRequestOptionsResizeModeFast;
                options.synchronous = YES;
                
                NSMutableArray *mutableImages = [NSMutableArray array];
                for (PHAsset *asset in [self.selectedPhotos copy]) {
                    CGSize targetSize = CGSizeMake(imageMaxTargetPixel, imageMaxTargetPixel);
                    [self.imageManager requestImageForAsset:asset targetSize:targetSize contentMode:PHImageContentModeDefault options:options resultHandler:^(UIImage *image, NSDictionary *info) {
                        [mutableImages addObject:image];
                    }];
                }
                if ([self.delegate respondsToSelector:@selector(imagePickerViewController:didFinishPickingImages:)]) {
                    [self.delegate imagePickerViewController:self didFinishPickingImages:[mutableImages copy]];
                }
            }
                break;
            case MediaTypeVideo:
                [self dismiss:nil];
                break;
            default:
                break;
        }
    }
    else {
        [self dismiss:nil];
    }
}

- (IBAction)previewPhotos:(id)sender {
    
}

#pragma mark - Collection view datasource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    PHFetchResult *result = self.currentCollectionItem[@"assets"];
    // +1 for camera cell
    return result.count + 1;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    // camera cell
    if (indexPath.row == 0) {
        
        MPCameraCell *cameraCell = (MPCameraCell *)[collectionView dequeueReusableCellWithReuseIdentifier:cameraCellNibName forIndexPath:indexPath];
        
        if (self.shouldShowPreviewForCamera) {
            cameraCell.shouldShowPreview = self.shouldShowPreviewForCamera;
            self.session = cameraCell.session;
        
            if (![self.session isRunning]) {
                [self.session startRunning];
            }
        }
        
        return cameraCell;
    }
    
    // photo cell
    else {
        
        MPPhotoCell *photoCell = (MPPhotoCell *)[collectionView dequeueReusableCellWithReuseIdentifier:photoCellNibName forIndexPath:indexPath];
        
        PHFetchResult *fetchResult = self.currentCollectionItem[@"assets"];
        
        PHAsset *asset = fetchResult[indexPath.item - 1];
        photoCell.representedAssetIdentifier = asset.localIdentifier;
        
        CGFloat scale = [UIScreen mainScreen].scale * 1;
        CGSize imageSize = CGSizeMake(CGRectGetWidth(photoCell.frame) * scale, CGRectGetHeight(photoCell.frame) * scale);
        
        [photoCell loadPhotoWithManager:self.imageManager forAsset:asset targetSize:imageSize];
        
        //[photoCell.longPressGestureRecognizer addTarget:self action:@selector(presentSinglePhoto:)];
        
        if ([self.selectedPhotos containsObject:asset]) {
            NSUInteger selectionIndex = [self.selectedPhotos indexOfObject:asset];
            photoCell.selectionOrder = selectionIndex + 1;
        }
        
        return photoCell;
    }
}

#pragma mark - Collection view delegate

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    if (!self.canAddPhoto || cell.isSelected) {
        return NO;
    }
    
    if ([cell isKindOfClass:[MPPhotoCell class]]) {
        MPPhotoCell *photoCell = (MPPhotoCell *)cell;
        [photoCell setNeedsAnimateSelection];
        photoCell.selectionOrder = self.selectedPhotos.count + 1;
    }
    return YES;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0) {
        // TODO: OPEN CAMERA
        if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
            
            AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
            if(status == AVAuthorizationStatusAuthorized) {
                UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
                imagePickerController.delegate = self;
                imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
                if (self.pickerMediaType == MediaTypeVideo) {
                    imagePickerController.mediaTypes =
                    [NSArray arrayWithObject:(NSString *)kUTTypeMovie];
                }
                
                [self presentViewController:imagePickerController animated:NO completion:nil];
            }
            else if(status == AVAuthorizationStatusDenied || status == AVAuthorizationStatusRestricted) {
                if ([self.delegate respondsToSelector:@selector(imagePickerViewControllerRecieveCameraAccessDenied:)]) {
                    [self.delegate imagePickerViewControllerRecieveCameraAccessDenied:self];
                }
            }
            else if(status == AVAuthorizationStatusNotDetermined) {
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                    dispatch_async(dispatch_get_main_queue(), ^() {
                        if(granted){
                            UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
                            imagePickerController.delegate = self;
                            imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
                            [self presentViewController:imagePickerController animated:NO completion:nil];
                        }
                        else {
                            if ([self.delegate respondsToSelector:@selector(imagePickerViewControllerRecieveCameraAccessDenied:)]) {
                                [self.delegate imagePickerViewControllerRecieveCameraAccessDenied:self];
                            }
                        }
                    });
                }];
            }
        }
        else {
            // Camera is not support in this device, the reason we don't need to handle it because the only iOS8+ environment which does not support camera is iPhone simulator.
        }
    }
    else if (self.allowsMultipleSelection == NO) {
        PHFetchResult *fetchResult = self.currentCollectionItem[@"assets"];
        PHAsset *asset = fetchResult[indexPath.item-1];
        switch (self.pickerMediaType) {
            case MediaTypeImage:
            {
                // Prepare the options to pass when fetching the live photo.
                PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
                options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
                options.networkAccessAllowed = YES;
                options.resizeMode = PHImageRequestOptionsResizeModeExact;
                
                CGSize targetSize = CGSizeMake(asset.pixelWidth, asset.pixelHeight);
                
                [self.imageManager requestImageForAsset:asset targetSize:targetSize contentMode:PHImageContentModeAspectFill options:options resultHandler:^(UIImage *image, NSDictionary *info) {
                    if (image && [self.delegate respondsToSelector:@selector(imagePickerViewController:didFinishPickingImage:)]) {
                        [self.delegate imagePickerViewController:self didFinishPickingImage:[self orientationNormalizedImage:image]];
                    }
                    else {
                        [self dismiss:nil];
                    }
                }];
            }
                break;
            case MediaTypeVideo:
            {
                PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
                options.deliveryMode = PHVideoRequestOptionsDeliveryModeFastFormat;
        
                __block AVURLAsset *videoAsset;
                dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                
                [self.imageManager requestAVAssetForVideo:asset options:options resultHandler:^(AVAsset *asset, AVAudioMix *audioMix, NSDictionary *info)
                 {
                     if ([asset isKindOfClass:[AVURLAsset class]])
                     {
                         videoAsset = (AVURLAsset*)asset;
                     }
                     
                     dispatch_semaphore_signal(semaphore);
                 
                 }];
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                
                NSData *videoData = [NSData dataWithContentsOfURL:videoAsset.URL];
                
                NSError *error = nil;
                
                NSURL *directoryURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]] isDirectory:YES];
                [[NSFileManager defaultManager] createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:&error];
                
                NSDate *now = [NSDate date];
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                [dateFormatter setDateFormat:@"yyyyMMddHHmmssSSS"];
                NSString *recorderPath = [NSString stringWithFormat:@"%@-tem-MyVideo.MOV", [dateFormatter stringFromDate:now]];
                
                NSURL *fileURL = [directoryURL URLByAppendingPathComponent:recorderPath];
                
                [videoData writeToURL:fileURL options:NSDataWritingAtomic error:&error];
                
                NSAssert(error == nil, @"%@", error.description);
                
                if ([self.delegate respondsToSelector:@selector(imagePickerViewController:didFinishPickingVideo:)]) {
                    [self.delegate imagePickerViewController:self didFinishPickingVideo:fileURL];
                }
            }
                break;
            default:
                break;
        }
    }
    else {
        PHFetchResult *fetchResult = self.currentCollectionItem[@"assets"];
        PHAsset *asset = fetchResult[indexPath.item-1];
        [self.selectedPhotos addObject:asset];
        self.doneItem.enabled = YES;
        self.previewButton.enabled = YES;
        
        self.numberOfSelectedLabel.text = [NSString stringWithFormat:@"%lu", (long unsigned)self.selectedPhotos.count];
    }
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    if ([cell isKindOfClass:[MPPhotoCell class]]) {
        [(MPPhotoCell *)cell setNeedsAnimateSelection];
    }
    return YES;
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.item == 0) {
        // Camera cell doesn't need to be deselected
        return;
    }
    PHFetchResult *fetchResult = self.currentCollectionItem[@"assets"];
    PHAsset *asset = fetchResult[indexPath.item-1];
    
    NSUInteger removedIndex = [self.selectedPhotos indexOfObject:asset];
    
    // Reload order higher than removed cell
    for (NSInteger i=removedIndex+1; i<self.selectedPhotos.count; i++) {
        PHAsset *needReloadAsset = self.selectedPhotos[i];
        MPPhotoCell *cell = (MPPhotoCell *)[collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:[fetchResult indexOfObject:needReloadAsset]+1 inSection:indexPath.section]];
        cell.selectionOrder = cell.selectionOrder-1;
    }
    
    [self.selectedPhotos removeObject:asset];
    if (self.selectedPhotos.count == 0) {
        self.doneItem.enabled = NO;
        self.previewButton.enabled = NO;
    }
    
    self.numberOfSelectedLabel.text = [NSString stringWithFormat:@"%lu", (long unsigned)self.selectedPhotos.count];
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (CGSizeEqualToSize(CGSizeZero, self.cellPortraitSize)
        || CGSizeEqualToSize(CGSizeZero, self.cellLandscapeSize)) {
        [self setupCellSize];
    }
    
    if ([[UIApplication sharedApplication] statusBarOrientation] == UIInterfaceOrientationLandscapeLeft
        || [[UIApplication sharedApplication] statusBarOrientation] == UIInterfaceOrientationLandscapeRight) {
        return self.cellLandscapeSize;
    }
    return self.cellPortraitSize;
}


#pragma mark - PHPhotoLibraryChangeObserver

- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    // Check if there are changes to the assets we are showing.
    PHFetchResult *fetchResult = self.currentCollectionItem[@"assets"];
    
    PHFetchResultChangeDetails *collectionChanges = [changeInstance changeDetailsForFetchResult:fetchResult];
    if (collectionChanges == nil) {
        
        [self fetchCollections];
        
        if (self.needToSelectFirstPhoto) {
            self.needToSelectFirstPhoto = NO;
            
            fetchResult = [self.collectionItems firstObject][@"assets"];
            PHAsset *asset = [fetchResult firstObject];
            [self.selectedPhotos addObject:asset];
            self.doneItem.enabled = YES;
        }
        
        return;
    }
    
    /*
     Change notifications may be made on a background queue. Re-dispatch to the
     main queue before acting on the change as we'll be updating the UI.
     */
    dispatch_async(dispatch_get_main_queue(), ^{
        // Get the new fetch result.
        PHFetchResult *fetchResult = [collectionChanges fetchResultAfterChanges];
        NSInteger index = [self.collectionItems indexOfObject:self.currentCollectionItem];
        self.currentCollectionItem = @{
                                       @"assets": fetchResult,
                                       @"collection": self.currentCollectionItem[@"collection"]
                                       };
        if (index != NSNotFound) {
            NSMutableArray *updatedCollectionItems = [self.collectionItems mutableCopy];
            [updatedCollectionItems replaceObjectAtIndex:index withObject:self.currentCollectionItem];
            self.collectionItems = [updatedCollectionItems copy];
        }
        UICollectionView *collectionView = self.photoCollectionView;
        
        if (![collectionChanges hasIncrementalChanges] || [collectionChanges hasMoves]
            || ([collectionChanges removedIndexes].count > 0
                && [collectionChanges changedIndexes].count > 0)) {
                // Reload the collection view if the incremental diffs are not available
                [collectionView reloadData];
            }
        else {
            /*
             Tell the collection view to animate insertions and deletions if we
             have incremental diffs.
             */
            [collectionView performBatchUpdates:^{
                
                NSIndexSet *removedIndexes = [collectionChanges removedIndexes];
                NSMutableArray *removeIndexPaths = [NSMutableArray arrayWithCapacity:removedIndexes.count];
                [removedIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                    [removeIndexPaths addObject:[NSIndexPath indexPathForItem:idx+1 inSection:0]];
                }];
                if ([removedIndexes count] > 0) {
                    [collectionView deleteItemsAtIndexPaths:removeIndexPaths];
                }
                
                NSIndexSet *insertedIndexes = [collectionChanges insertedIndexes];
                NSMutableArray *insertIndexPaths = [NSMutableArray arrayWithCapacity:insertedIndexes.count];
                [insertedIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                    [insertIndexPaths addObject:[NSIndexPath indexPathForItem:idx+1 inSection:0]];
                }];
                if ([insertedIndexes count] > 0) {
                    [collectionView insertItemsAtIndexPaths:insertIndexPaths];
                }
                
                NSIndexSet *changedIndexes = [collectionChanges changedIndexes];
                NSMutableArray *changedIndexPaths = [NSMutableArray arrayWithCapacity:changedIndexes.count];
                [changedIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:idx inSection:0];
                    if (![removeIndexPaths containsObject:indexPath]) {
                        // In case reload selected cell, they were didSelected and re-select. Ignore them to prevent weird transition.
                        if (self.needToSelectFirstPhoto) {
                            if (![collectionView.indexPathsForSelectedItems containsObject:indexPath]) {
                                [changedIndexPaths addObject:indexPath];
                            }
                        }
                        else {
                            [changedIndexPaths addObject:indexPath];
                        }
                    }
                }];
                if ([changedIndexes count] > 0) {
                    [collectionView reloadItemsAtIndexPaths:changedIndexPaths];
                }
            } completion:^(BOOL finished) {
                if (self.needToSelectFirstPhoto) {
                    self.needToSelectFirstPhoto = NO;
                    
                    PHAsset *asset = [fetchResult firstObject];
                    [self.selectedPhotos addObject:asset];
                    self.numberOfSelectedLabel.text = [NSString stringWithFormat:@"%lu", (long unsigned)self.selectedPhotos.count];
                    self.doneItem.enabled = YES;
                }
                [self refreshPhotoSelection];
            }];
        }
    });
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info
{
    [picker dismissViewControllerAnimated:YES completion:^{
        
        // Enable camera preview when user allow it first time
        if (![self.session isRunning]) {
            [self.photoCollectionView reloadItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:0 inSection:0]]];
        }
        
        UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
        
        if (image) {
        
        // Save the image to Photo Album
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetCollection *collection = self.currentCollectionItem[@"collection"];
            if (collection.assetCollectionType == PHAssetCollectionTypeSmartAlbum) {
                // Cannot save to smart albums other than "all photos", pick it and dismiss
                [PHAssetChangeRequest creationRequestForAssetFromImage:image];
            }
            else {
                PHAssetChangeRequest *assetRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                PHObjectPlaceholder *placeholder = [assetRequest placeholderForCreatedAsset];
                PHAssetCollectionChangeRequest *albumChangeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:collection assets:self.currentCollectionItem[@"assets"]];
                [albumChangeRequest addAssets:@[placeholder]];
            }
        } completionHandler:^(BOOL success, NSError *error) {
            if (success) {
                self.needToSelectFirstPhoto = YES;
            }
            
            if (!self.allowsMultipleSelection) {
                if ([self.delegate respondsToSelector:@selector(imagePickerViewController:didFinishPickingImage:)]) {
                    [self.delegate imagePickerViewController:self didFinishPickingImage:image];
                }
                else {
                    [self dismiss:nil];
                }
            }
        }];
            
        } else {
            // get video url
            if (!info)
                return;
            
            NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
            NSURL *videoUrl;
            if (CFStringCompare ((__bridge CFStringRef) mediaType, kUTTypeMovie, 0) == kCFCompareEqualTo) {
                videoUrl = (NSURL *)[info objectForKey:UIImagePickerControllerMediaURL];
        
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:videoUrl];
                } completionHandler:^(BOOL success, NSError * _Nullable error) {

                    if (success) {
                        self.needToSelectFirstPhoto = YES;
                    }
                    
                    if (!self.allowsMultipleSelection) {
                        if ([self.delegate respondsToSelector:@selector(imagePickerViewController:didFinishPickingVideo:)]) {
                            [self.delegate imagePickerViewController:self didFinishPickingVideo:videoUrl];
                        }
                        else {
                            [self dismiss:nil];
                        }
                    }
                }];
            }
        }
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:^(){
        [self.photoCollectionView deselectItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0] animated:NO];
        
        // Enable camera preview when user allow it first time
        if (![self.session isRunning]) {
            [self.photoCollectionView reloadItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:0 inSection:0]]];
        }
    }];
}

@end
