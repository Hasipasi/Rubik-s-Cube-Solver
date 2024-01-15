//
//  CVWrapper.m
//  CVOpenTemplate
//
//  Created by Washe on 02/01/2013.
//  Copyright (c) 2013 foundry. All rights reserved.
//

#import "CVWrapper.h"
#import "UIImage+OpenCV.h"
#import "UIImage+Rotate.h"
#import "Solver.h"

@implementation CVWrapper

+ (NSArray<NSString*>*) solveCube: (NSArray<UIImage*>*)faces_images;
{
    if ([faces_images count] == 0){
        NSLog (@"imageArray is empty");
        return 0;
        }
    std::vector<cv::Mat> faces;

    for (id image in faces_images) {
        if ([image isKindOfClass: [UIImage class]]) {
            UIImage* rotatedImage = [image rotateToImageOrientation];

            cv::Mat matImage = [rotatedImage CVMat3];
            
            NSLog (@"matImage: %@", image);
            faces.push_back(matImage);
        }
    }
    std::vector<std::string> states = Solver().solve(faces);
    NSLog (@"asd1");
    NSMutableArray *resultArray = [NSMutableArray array];
    NSLog (@"asd2");
    for (const auto &state : states) {
        [resultArray addObject:[NSString stringWithUTF8String:state.c_str()]];
    }
    NSLog (@"asd3");
    return [resultArray copy];
}

+ (NSArray<NSValue*>*) getFaceCoordinates:(UIImage *)frame {
    UIImage* rotatedImage = [frame rotateToImageOrientation];

    cv::Mat matFrame = [rotatedImage CVMat3];
        
    std::vector<cv::Point> faceCoordinates = Solver().getFaceCoordinates(matFrame);
        
    NSMutableArray *resultArray = [NSMutableArray array];
    for (const auto &point : faceCoordinates) {
        [resultArray addObject:[NSValue valueWithCGPoint:CGPointMake(point.x, point.y)]];
    }

    return [resultArray copy];
}

+ (UIImage *) detectFace:(UIImage *)frame {
    UIImage* rotatedImage = [frame rotateToImageOrientation];
    
    cv::Mat matFrame = [rotatedImage CVMat3];
    
    cv::Mat croppedFace = Solver().detectFace(matFrame);
    
    if (!croppedFace.empty()) {
        cv::cvtColor(croppedFace, croppedFace, cv::COLOR_BGR2RGB);
        UIImage *croppedFaceUIImage = MatToUIImage(croppedFace);
        return croppedFaceUIImage;
    } else {
        return nil;
    }
}
@end
