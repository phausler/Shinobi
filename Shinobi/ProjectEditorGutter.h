//
//  ProjectEditorGutter.h
//  Shinobi
//
//  Created by Philippe Hausler on 9/11/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ProjectEditor;

@interface ProjectEditorGutterMarker : NSRulerMarker

@end

@interface ProjectEditorGutter : NSRulerView

- (instancetype)initWithEditor:(ProjectEditor *)editor;

@end
