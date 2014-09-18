//
//  ProjectItem.h
//  Shinobi
//
//  Created by Philippe Hausler on 9/11/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NinjaProject, ProjectItem;

typedef enum {
    SyntaxBuiltinType,
    SyntaxNumericLiteralType,
    SyntaxStringLiteralType,
    SyntaxIntrinsicLiteralType,
    SyntaxFunctionType,
    SyntaxCXXMethodType,
    SyntaxPreprocessorType,
    SyntaxCommentType,
    SyntaxOtherType
} SyntaxType;

@protocol ProjectItemSyntaxHighlightingDelegate <NSObject>
@required

- (void)beginEditingForItem:(ProjectItem *)item;
- (void)setType:(SyntaxType)type range:(NSRange)range forItem:(ProjectItem *)item;
- (void)setType:(SyntaxType)type range:(NSRange)range tooltip:(NSString *)tooltip forItem:(ProjectItem *)item;
- (void)endEditingForItem:(ProjectItem *)item;

- (NSString *)substringWithRange:(NSRange)range;

@end

@interface ProjectItem : NSObject

@property (nonatomic, readonly) NinjaProject *project;
@property (nonatomic, readonly) ProjectItem *parent;
@property (nonatomic, readonly) NSArray *children;
@property (nonatomic, readonly) NSString *path;
@property (nonatomic, readonly) NSString *absolutePath;
@property (nonatomic, readonly) NSString *contents;
@property (nonatomic, assign) NSStringEncoding encoding;

- (ProjectItem *)childForPath:(NSString *)path;

- (void)beginSyntaxHighlighting:(id<ProjectItemSyntaxHighlightingDelegate>)syntaxDelegate;
- (void)endSyntaxHighlighting:(id<ProjectItemSyntaxHighlightingDelegate>)syntaxDelegate;

@end
