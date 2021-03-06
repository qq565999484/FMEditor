//
//  DPPhotoListViewController.m
//  DPPictureSelector
//
//  Created by boombox on 15/9/1.
//  Copyright (c) 2015年 lidaipeng. All rights reserved.
//

#import "XZPostPhotoListViewController.h"
#import "XZPhotoListCell.h"
#import "DPPhotoGroupViewController.h"

const CGFloat imageSpacing = 2.0f;  /**< 图片间距 */
const NSInteger maxCountInLine = 3; /**< 每行显示图片张数 */



#pragma mark - ---------------------- controller
@interface XZPostPhotoListViewController ()<UICollectionViewDataSource, UICollectionViewDelegate, DPPhotoGroupViewControllerDelegate>

@property (strong, nonatomic) UICollectionView  *collectionView;    /**< asset列表 */
@property (strong, nonatomic) NSMutableArray    *selectedAssets;    /**< 已选asset集合 */
@property (strong, nonatomic) NSMutableArray    *selectedItems;     /**< 已选item集合 */
@property (strong, nonatomic) UIButton          *finishButton;      /**< 完成按钮 */
@property (strong, nonatomic) NSMutableArray    *groupList;         /**< 相册数组 */

@end

@implementation XZPostPhotoListViewController{
    NSMutableArray *_selectedFalgList;  /**< 是否选中标记 */
    NSMutableArray *_assetList;         /**< 当前相薄所有asset */
    NSInteger       _selectedCount;     /**< 已选asset总数 */
    XZSeletePhotoType _seleteType;      /**< 选择的类型（一个还是全部）*/
}
- (instancetype)initWithSeleteType:(XZSeletePhotoType)type
{
    self = [super init];
    if (self) {
        _seleteType = type;
    }
    return self;
}
#pragma mark 隐藏状态栏
- (BOOL)prefersStatusBarHidden {
    return YES;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.frame = CGRectMake(0, 0, self.view.frame.size.width, [UIScreen mainScreen].bounds.size.height);
//    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"nav_back"] style:UIBarButtonItemStylePlain target:self action:@selector(clickBack)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStylePlain target:self action:@selector(clickCancel)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"选择相册" style:UIBarButtonItemStylePlain target:self action:@selector(selectPhotoGroup)];
    
    _selectedCount = 0;

    [self.view addSubview:self.collectionView];
    
    [self getAllGroup];
    
    [self showFinishButton];
}

#pragma mark - ---------------------- getter
- (UICollectionView *)collectionView {
    if (!_collectionView) {
        UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
        //每张图片宽度
        CGFloat width = (self.view.frame.size.width - imageSpacing * (maxCountInLine - 1)) / maxCountInLine;
        layout.itemSize = CGSizeMake(width, width);
        layout.minimumLineSpacing      = imageSpacing;
        layout.minimumInteritemSpacing = imageSpacing;
        
        _collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
        _collectionView.delegate        = self;
        _collectionView.dataSource      = self;
        _collectionView.backgroundColor = [UIColor whiteColor];
        [_collectionView registerClass:[XZPhotoListCell class] forCellWithReuseIdentifier:@"cell"];
    }
    return _collectionView;
}

- (NSMutableArray *)selectedAssets {
    if (!_selectedAssets) {
        _selectedAssets = [NSMutableArray new];
    }
    return _selectedAssets;
}

- (NSMutableArray *)selectedItems {
    if (!_selectedItems) {
        _selectedItems = [NSMutableArray array];
    }
    return _selectedItems;
}
- (UIButton *)finishButton {
    if (!_finishButton) {
        _finishButton = [[UIButton alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width, 49)];
        [_finishButton addTarget:self action:@selector(clickFinish) forControlEvents:UIControlEventTouchUpInside];
        [_finishButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _finishButton.backgroundColor     = [UIColor redColor];
        _finishButton.titleLabel.font     = [UIFont systemFontOfSize:17];
        _finishButton.layer.shadowColor   = [UIColor grayColor].CGColor;
        _finishButton.layer.shadowOffset  = CGSizeMake(0, -1);
        _finishButton.layer.shadowOpacity = 0.5;
        
        [self.view addSubview:_finishButton];
        [self.view bringSubviewToFront:_finishButton];
    }
    return _finishButton;
}

- (void)getAllPhoto {
    _assetList = [NSMutableArray array];
    _selectedFalgList = [NSMutableArray new];
    ALAssetsGroupEnumerationResultsBlock resultsBlock = ^(ALAsset *asset, NSUInteger index, BOOL *stop) {
        if (asset){
            
            NSString *type = [asset valueForProperty:ALAssetPropertyType];
            //当asset类型为照片时，添加到数组
            if ([type isEqual:ALAssetTypePhoto]){
                [_assetList addObject:asset];
                [_selectedFalgList addObject:@0];
            }
        }else{
            
            //asset为nil时代表枚举完成，重新加载collectionView
            self.title = [self.group valueForProperty:ALAssetsGroupPropertyName];
            [self.collectionView reloadData];
            
            //滚动到底部
            [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:_assetList.count - 1 inSection:0] atScrollPosition:UICollectionViewScrollPositionBottom animated:NO];
        }
    };
    
    [self.group enumerateAssetsUsingBlock:resultsBlock];
}
//获取所有相薄
- (void)getAllGroup {
    static dispatch_once_t pred = 0;
    static ALAssetsLibrary *library = nil;
    dispatch_once(&pred, ^{
        library = [[ALAssetsLibrary alloc] init];
    });
    
    //枚举回调
    ALAssetsLibraryGroupsEnumerationResultsBlock resultsBlock = ^(ALAssetsGroup *group, BOOL *stop) {
        if (group){
            //设置过滤类型
            [group setAssetsFilter:[ALAssetsFilter allAssets]];
            [self.groupList addObject:group];
        }else{
            //group为nil时代表枚举完成，刷新tableView
//            [self.tableView reloadData];
            self.group = [self.groupList lastObject];
            
            [self getAllPhoto];
        }
    };
    
    //枚举失败回调
    ALAssetsLibraryAccessFailureBlock failureBlock = ^(NSError *error) {
//        ALERT_MSG(@"没有权限访问相册");
    };
    
    //设置枚举相薄类型
    NSUInteger type = ALAssetsGroupLibrary | ALAssetsGroupAlbum | ALAssetsGroupEvent | ALAssetsGroupFaces | ALAssetsGroupPhotoStream | ALAssetsGroupSavedPhotos;
    
    [library enumerateGroupsWithTypes:type
                           usingBlock:resultsBlock
                         failureBlock:failureBlock];
    
    //    NSLog(@"self.groupList = %@",self.groupList);
}
#pragma mark - ---------------------- animation
- (void)showFinishButton{
    self.finishButton.hidden = NO;
    [UIView animateWithDuration:.25 animations:^{
        CGRect frame = _finishButton.frame;
        frame.origin.y = self.view.frame.size.height - frame.size.height;
        _finishButton.frame = frame;
        
        frame = _collectionView.frame;
        frame.size.height = _finishButton.frame.origin.y;
        _collectionView.frame = frame;
    }];
    
    if (_selectedCount) {
        [_finishButton setTitle:[NSString stringWithFormat:@"导入%li/%zd张",_selectedCount,self.maxSelectionCount] forState:UIControlStateNormal];
    } else {
        if (_seleteType == XZOneSelete) {
            [_finishButton setTitle:[NSString stringWithFormat:@"导入%li/%zd张",_selectedCount,self.maxSelectionCount] forState:UIControlStateNormal];
        } else {
            [_finishButton setTitle:@"可以导入20张图片" forState:UIControlStateNormal];
        }
        
    }
    
}

- (void)hideFinishButton{
    [UIView animateWithDuration:.25 animations:^{
        CGRect frame = _finishButton.frame;
        frame.origin.y = self.view.frame.size.height;
        _finishButton.frame = frame;
        
        frame = _collectionView.frame;
        frame.size.height = _finishButton.frame.origin.y;
        _collectionView.frame = frame;
    } completion:^(BOOL finished) {
        self.finishButton.hidden = YES;
    }];
}

#pragma mark - ---------------------- UICollectionViewDataSource/delegate
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return _assetList.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    XZPhotoListCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    if (!cell) {
        cell = [XZPhotoListCell new];
    }
    cell.imageView.image = [UIImage imageWithCGImage:[_assetList[indexPath.row] thumbnail]];
    cell.isChoose = [_selectedFalgList[indexPath.row] boolValue];
    if ([self.selectedItems containsObject:@(indexPath.item)]) {
        [cell setNumber:[self.selectedItems indexOfObject:@(indexPath.item)] + 1];
    } else {
        [cell setNumberStr:@""];
    }
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    
    
    //如果已选总数大于等于可选总数，并且当前cell为选中状态，return
    if (_selectedCount >= self.maxSelectionCount) {
        NSString *msg = [NSString stringWithFormat:@"最多选择%li张图片",self.maxSelectionCount];
//        ALERT_MSG(msg);
        return;
    }
    
    //bool值取反
    _selectedFalgList[indexPath.row] = [NSNumber numberWithBool:![_selectedFalgList[indexPath.row] boolValue]];
    
    //设置cell选中状态
    BOOL isChiose = [_selectedFalgList[indexPath.row] boolValue];
    ALAsset *asset = _assetList[indexPath.row];
    if (isChiose) {
        //选中时，添加到数组，已选总数+1
        [self.selectedAssets addObject:asset];
        [self.selectedItems addObject:@(indexPath.item)];
        _selectedCount++;
    }else{
        //取消选中时，从数组中删除，已选总数-1
        if ([self.selectedAssets containsObject:asset]) {
            [self.selectedAssets removeObject:asset];
        }
        if ([self.selectedItems containsObject:@(indexPath.item)]) {
            [self.selectedItems removeObject:@(indexPath.item)];
        }
        _selectedCount--;
    }
    
    [collectionView reloadData];
    [_finishButton setTitle:[NSString stringWithFormat:@"导入%li/%zd张",_selectedCount,self.maxSelectionCount] forState:UIControlStateNormal];
}

#pragma mark - ---------------------- action
- (void)clickBack{
//    [self.navigationController popViewControllerAnimated:YES];
    [self clickCancel];
}

- (void)clickCancel{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)clickFinish{
    if (_seleteType == XZOneSelete) {
        
        if (self.oneDelegate && [self.oneDelegate respondsToSelector:@selector(didSelectOnePhotos:item:)]) {
            ALAsset *asset = [_selectedAssets firstObject];
            [self.oneDelegate didSelectOnePhotos:[UIImage imageWithCGImage:asset.defaultRepresentation.fullScreenImage] item:self.view.tag];
        }
        
    } else {
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(didSelectPhotos:)]) {
            NSMutableArray *photos = [NSMutableArray new];
            for (ALAsset *asset in _selectedAssets) {
                [photos addObject:[UIImage imageWithCGImage:asset.defaultRepresentation.fullScreenImage]];
            }
            [self.delegate didSelectPhotos:photos];
        }
        
    }
    
    [self clickCancel];
}
#pragma mark 导航栏右键点击（选择相册）
- (void)selectPhotoGroup {
//    DLog(@"选择相册");
    DPPhotoGroupViewController *photoGroupView = [[DPPhotoGroupViewController alloc]init];
    photoGroupView.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc]initWithRootViewController:photoGroupView];
    [self presentViewController:nav animated:YES completion:nil];
}
#pragma mark DPPhotoGroup代理
- (void)didSelectPhotos:(NSMutableArray *)photos {
    self.group = (ALAssetsGroup *)photos;
    [self getAllPhoto];
}
#pragma mark 初始化
- (NSMutableArray *)groupList{
    if (!_groupList) {
        _groupList = [NSMutableArray new];
    }
    return _groupList;
}
@end
