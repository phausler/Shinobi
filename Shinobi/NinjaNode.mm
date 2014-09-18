//
//  NinjaNode.m
//  Shinobi
//
//  Created by Philippe Hausler on 9/11/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import "NinjaNode.h"
#import "NinjaProject.h"
#import "SymbolicDefinition.h"
#import <ninja/graph.h>
#include <clang/Tooling/Tooling.h>
#import <AppKit/AppKit.h>
#import "CodeIntelAction.h"

#undef IBAction
#undef IBOutlet
#include <clang/Frontend/ASTUnit.h>
#include <unordered_map>
#include <clang/AST/RecursiveASTVisitor.h>
#include <clang/Lex/Preprocessor.h>
#include <clang/Lex/HeaderSearch.h>


class NinjaNodeCompilationDatabase : public clang::tooling::CompilationDatabase {
private:
    clang::tooling::CompilationDatabase *project_;
    std::vector<std::string> files_;
public:
    NinjaNodeCompilationDatabase(clang::tooling::CompilationDatabase *project, std::vector<std::string> files) :
        project_(project),
        files_(files)
    {
        
    }
    
    virtual std::vector<clang::tooling::CompileCommand> getCompileCommands(llvm::StringRef FilePath) const
    {
        return project_->getCompileCommands(FilePath);
    }
    
    virtual std::vector<std::string> getAllFiles() const
    {
        return files_;
    }
    
    virtual std::vector<clang::tooling::CompileCommand> getAllCompileCommands() const
    {
        std::vector<clang::tooling::CompileCommand> commands;
        
        for (std::string file : getAllFiles())
        {
            for (clang::tooling::CompileCommand command : getCompileCommands(file))
            {
                commands.push_back(command);
            }
        }
        
        return commands;
    }
};

@interface NinjaProject (Internal)

@property (nonatomic, readonly) clang::tooling::CompilationDatabase *compilationDatabase;

@end

@interface SymbolicDefinition (Internal)

- (instancetype)initWithRange:(NSRange)range spelling:(NSString *)spelling;

@end

@implementation NinjaNode {
    ninja::Node *_node;
    __weak NinjaProject *_project;
    NSString *_contents;
    NSStringEncoding _encoding;
    id<ProjectItemSyntaxHighlightingDelegate> _syntaxDelegate;
    OSSpinLock _lock;
    NSMutableArray *_symbols;
}

- (instancetype)initWithNode:(ninja::Node *)node project:(NinjaProject *)project
{
    self = [super init];
    
    if (self)
    {
        _symbols = [[NSMutableArray alloc] init];
        _node = node;
        _project = project;
        _lock = OS_SPINLOCK_INIT;
    }
    
    return self;
}

- (NinjaProject *)project
{
    return _project;
}

- (NSString *)path
{
    return [NSString stringWithUTF8String:_node->path().c_str()];
}

- (NSArray *)children
{
    return nil;
}

- (NSString *)contents
{
    if (_contents == nil)
    {
        _contents = [NSString stringWithContentsOfFile:self.absolutePath usedEncoding:&_encoding error:NULL];
    }
    
    return _contents;
}

- (void)setContents:(NSString *)contents
{
    if (![_contents isEqualToString:contents])
    {
        _contents = [contents copy];
    }
}

- (NSStringEncoding)encoding
{
    return _encoding;
}

- (void)setEncoding:(NSStringEncoding)encoding
{
    _encoding = encoding;
}

- (void)beginSyntaxHighlighting:(id<ProjectItemSyntaxHighlightingDelegate>)syntaxDelegate
{
    _syntaxDelegate = syntaxDelegate;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        std::vector<std::string> files;
        files.push_back(std::string(self.absolutePath.UTF8String));
        NinjaNodeCompilationDatabase db(self.project.compilationDatabase, files);
        CodeIntelVisitor *visitor = new CodeIntelVisitor;
        
        clang::tooling::ClangTool Tool(db, files);
        Tool.mapVirtualFile(files[0], self.contents.UTF8String);
        visitor->process(Tool);
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            [syntaxDelegate beginEditingForItem:self];
            
            for (NSRange r : visitor->Comments_)
            {
                [syntaxDelegate setType:SyntaxCommentType range:r forItem:self];
            }
            
            for (NSRange r : visitor->Preprocessor_)
            {
                [syntaxDelegate setType:SyntaxPreprocessorType range:r forItem:self];
            }
            
            for (auto info : visitor->Declarations_)
            {
                if (info.second->getKind() == clang::Decl::Function)
                {
                    [syntaxDelegate setType:SyntaxFunctionType range:info.first forItem:self];
                }
                else if (info.second->getKind() == clang::Decl::CXXMethod)
                {
                    [syntaxDelegate setType:SyntaxCXXMethodType range:info.first forItem:self];
                }
                else
                {
                    [syntaxDelegate setType:SyntaxOtherType range:info.first tooltip:[NSString stringWithFormat:@"clang::Decl %s", info.second->getDeclKindName()] forItem:self];
                }
            }
            
            for (auto info : visitor->Statements_)
            {
                if (info.second->getStmtClass() == clang::Stmt::IntegerLiteralClass ||
                    info.second->getStmtClass() == clang::Stmt::FloatingLiteralClass)
                {
                    [syntaxDelegate setType:SyntaxNumericLiteralType range:info.first forItem:self];
                }
                else if (info.second->getStmtClass() == clang::Stmt::StringLiteralClass)
                {
                    [syntaxDelegate setType:SyntaxStringLiteralType range:info.first forItem:self];
                }
                else if (info.second->getStmtClass() == clang::Stmt::ForStmtClass ||
                         info.second->getStmtClass() == clang::Stmt::SwitchStmtClass ||
                         info.second->getStmtClass() == clang::Stmt::CaseStmtClass ||
                         info.second->getStmtClass() == clang::Stmt::BreakStmtClass ||
                         info.second->getStmtClass() == clang::Stmt::ReturnStmtClass ||
                         info.second->getStmtClass() == clang::Stmt::WhileStmtClass ||
                         info.second->getStmtClass() == clang::Stmt::CXXBoolLiteralExprClass ||
                         info.second->getStmtClass() == clang::Stmt::CXXCatchStmtClass ||
                         info.second->getStmtClass() == clang::Stmt::CXXConstCastExprClass ||
                         info.second->getStmtClass() == clang::Stmt::CXXDeleteExprClass ||
                         info.second->getStmtClass() == clang::Stmt::CXXDynamicCastExprClass ||
                         info.second->getStmtClass() == clang::Stmt::CXXNewExprClass ||
                         info.second->getStmtClass() == clang::Stmt::CXXThrowExprClass ||
                         info.second->getStmtClass() == clang::Stmt::CXXTryStmtClass)
                {
                    [syntaxDelegate setType:SyntaxIntrinsicLiteralType range:info.first forItem:self];
                }
                else
                {
                    [syntaxDelegate setType:SyntaxOtherType range:info.first tooltip:[NSString stringWithFormat:@"clang::Stmt %s", info.second->getStmtClassName()] forItem:self];
                }
            }
            
            [syntaxDelegate endEditingForItem:self];
        });
    });
}

- (void)endSyntaxHighlighting:(id<ProjectItemSyntaxHighlightingDelegate>)syntaxDelegate
{
    _syntaxDelegate = nil;
}

@end
