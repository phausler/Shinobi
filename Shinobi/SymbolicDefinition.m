//
//  SymbolicDefinition.m
//  Shinobi
//
//  Created by Philippe Hausler on 9/15/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import "SymbolicDefinition.h"

@implementation SymbolicDefinition {
    NSString *_spelling;
    NSRange _range;
}

@synthesize name = _spelling;
@synthesize range = _range;

- (instancetype)initWithRange:(NSRange)range spelling:(NSString *)spelling
{
    self = [super init];
    
    if (self)
    {
        _spelling = [spelling copy];
        _range = range;
    }
    
    return self;
}

@end
