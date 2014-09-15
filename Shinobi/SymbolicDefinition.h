//
//  SymbolicDefinition.h
//  Shinobi
//
//  Created by Philippe Hausler on 9/15/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SymbolicDefinition : NSObject

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSRange range;

@end
