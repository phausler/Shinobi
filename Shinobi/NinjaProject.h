//
//  NinjaProject.h
//  Shinobi
//
//  Created by Philippe Hausler on 9/11/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import "ProjectItem.h"

typedef struct {
    int finished;
    int total;
} BuildProgress;

@protocol NinjaProjectBuildDelegate <NSObject>
@required

- (void)buildProgressChanged:(BuildProgress)progress;

@end

@interface NinjaProject : ProjectItem

@property (nonatomic, weak) id<NinjaProjectBuildDelegate> buildDelegate;

- (instancetype)initWithPath:(NSString *)path;
- (void)build;

@end
