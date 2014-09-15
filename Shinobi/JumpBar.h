//
//  JumpBar.h
//  Shinobi
//
//  Created by Philippe Hausler on 9/15/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol JumpBarDelegate <NSPathControlDelegate>
@required

- (NSMenu *)pathControl:(NSPathControl *)pathControl menuForCell:(NSPathComponentCell *)cell;

@end

@interface JumpBar : NSPathControl

@property (weak) IBOutlet id <JumpBarDelegate> delegate;

@end
