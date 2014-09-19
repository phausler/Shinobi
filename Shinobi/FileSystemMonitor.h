//
//  FileSystemMonitor.h
//  Shinobi
//
//  Created by Philippe Hausler on 9/18/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FileSystemMonitor;

@protocol FileSystemMonitorDelegate <NSObject>
@optional

- (void)monitor:(FileSystemMonitor *)monitor filesRemoved:(NSSet *)files;
- (void)monitor:(FileSystemMonitor *)monitor filesAdded:(NSSet *)files;
- (void)monitor:(FileSystemMonitor *)monitor filesChanged:(NSSet *)files;

@end

@interface FileSystemMonitor : NSObject

@property (nonatomic, weak) id <FileSystemMonitorDelegate> delegate;
- (instancetype)initWithPath:(NSString *)path;

@end
