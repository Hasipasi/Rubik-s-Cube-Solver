//
//  CVWrapper.h
//  CVOpenTemplate
//
//  Created by Washe on 02/01/2013.
//  Copyright (c) 2013 foundry. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
@interface CVWrapper : NSObject
+ (NSArray<NSString*>*) solveCube: (NSArray<UIImage*>*)faces_images;
+ (NSArray<NSValue*>*) getFaceCoordinates: (UIImage*)frame;
+ (UIImage*) detectFace: (UIImage*)frame;
@end
NS_ASSUME_NONNULL_END
