//
//  NinjaProject.h
//  Shinobi
//
//  Created by Philippe Hausler on 9/11/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import "NinjaNode.h"

typedef struct {
    int finished;
    int total;
} BuildProgress;

@protocol NinjaProjectBuildDelegate <NSObject>
@required

- (void)buildProgressChanged:(BuildProgress)progress;

@end

@class ProjectDocument;

@interface NinjaProject : NinjaNode

@property (nonatomic, weak) id<NinjaProjectBuildDelegate> buildDelegate;
@property (nonatomic, weak) ProjectDocument *document;

- (instancetype)initWithPath:(NSString *)path;
- (void)build;

@end
