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
#undef IBAction
#undef IBOutlet
#include <clang/Frontend/ASTUnit.h>
#include <unordered_map>
#include <clang/AST/RecursiveASTVisitor.h>
#include <clang/Lex/Preprocessor.h>

namespace std {
    template <>
    struct hash<NSRange> {
        size_t operator()(const NSRange &r) const {
            return std::hash<NSUInteger>()(r.location) ^ std::hash<NSUInteger>()(r.length);
        }
    };
    
    template <>
    struct equal_to<NSRange> {
        bool operator()(const NSRange &r1, const NSRange &r2) const {
            return r1.location == r2.location && r1.length == r2.length;
        }
    };
    
    template <>
    struct less<NSRange> {
        bool operator()(const NSRange &r1, const NSRange &r2) const {
            return r1.location < r2.location || NSMaxRange(r1) < NSMaxRange(r2);
        }
    };
}

class NinjaNodeASTVisitor : public clang::RecursiveASTVisitor<NinjaNodeASTVisitor> {
private:
    clang::SourceManager &SM_;
    const clang::LangOptions &LangOpts_;
    std::map<NSRange, clang::Decl *> &decls_;
    std::map<NSRange, clang::Stmt *> &statements_;
    std::map<NSRange, clang::TypeLoc> &typeLocs_;

public:
    NinjaNodeASTVisitor(clang::SourceManager &SM,
                        const clang::LangOptions &LangOpts,
                        std::map<NSRange, clang::Decl *> &decls,
                        std::map<NSRange, clang::Stmt *> &statements,
                        std::map<NSRange, clang::TypeLoc> &typeLocs) :
        SM_(SM),
        LangOpts_(LangOpts),
        decls_(decls),
        statements_(statements),
        typeLocs_(typeLocs)
    {
        
    }
    
    bool isInMainFile(const clang::SourceLocation &loc)
    {
        return SM_.getFileID(loc) == SM_.getMainFileID();
    }
    
    std::string getSpelling(clang::SourceLocation Start)
    {
        llvm::SmallVector<char, 16> buffer;
        std::string spelling = clang::Lexer::getSpelling(Start, buffer, SM_, LangOpts_).str();
        return spelling;
    }
    
    NSRange getRange(clang::SourceLocation Start, clang::SourceLocation End)
    {
        std::pair<clang::FileID, unsigned> start = SM_.getDecomposedLoc(Start);
        std::pair<clang::FileID, unsigned> end = SM_.getDecomposedLoc(End);
        size_t length = 0;
        if (start.second == end.second)
        {
            length = getSpelling(Start).length();
        }
        
        return NSMakeRange(start.second, length + end.second - start.second);
    }
    
    NSRange getRange(clang::SourceRange Range)
    {
        return getRange(Range.getBegin(), Range.getEnd());
    }
    
    NSRange getRange(clang::SourceLocation Loc)
    {
        return getRange(Loc, Loc);
    }
    
    bool VisitDecl(clang::Decl *D)
    {
        if (!isInMainFile(D->getLocStart()))
        {
            return true;
        }
        
        NSRange range = getRange(D->getLocation());
        decls_[range] = D;
        
        return true;
    }
    
    bool VisitTypeLoc(clang::TypeLoc TL)
    {
        if (!isInMainFile(TL.getLocStart()))
        {
            return true;
        }
        
        NSRange range = getRange(TL.getSourceRange());
        typeLocs_[range] = TL;
        
        return true;
    }
    
    bool VisitIntegerLiteral(clang::IntegerLiteral *S)
    {
        if (!isInMainFile(S->getLocStart()))
        {
            return true;
        }
        
        NSRange range = getRange(S->getLocStart(), S->getLocEnd());
        NSCAssert(range.length != 0, @"invalid range!");
        statements_[range] = S;
        
        return true;
    }
    
    bool VisitStmt(clang::Stmt *S)
    {
        if (!isInMainFile(S->getLocStart()))
        {
            return true;
        }
        
        NSRange range = getRange(S->getSourceRange());
        
        switch (S->getStmtClass())
        {
            case clang::Stmt::IfStmtClass: {
                clang::IfStmt *If = llvm::dyn_cast<clang::IfStmt>(S);
                range = getRange(If->getIfLoc());
                statements_[range] = S;
                if (If->getElse() != nullptr) {
                    range = getRange(If->getElseLoc());
                    statements_[range] = S;
                }
                break;
            }
            case clang::Stmt::ForStmtClass:
            case clang::Stmt::SwitchStmtClass:
            case clang::Stmt::CaseStmtClass:
            case clang::Stmt::BreakStmtClass:
            case clang::Stmt::ReturnStmtClass:
            case clang::Stmt::WhileStmtClass:
            case clang::Stmt::CXXBoolLiteralExprClass:
            case clang::Stmt::CXXCatchStmtClass:
            case clang::Stmt::CXXConstCastExprClass:
            case clang::Stmt::CXXDeleteExprClass:
            case clang::Stmt::CXXDynamicCastExprClass:
            case clang::Stmt::CXXNewExprClass:
            case clang::Stmt::CXXThrowExprClass:
            case clang::Stmt::CXXTryStmtClass:
                range = getRange(S->getLocStart());
                statements_[range] = S;
                break;
            case clang::Stmt::DoStmtClass: {
                clang::DoStmt *Do = llvm::dyn_cast<clang::DoStmt>(S);
                range = getRange(Do->getDoLoc());
                statements_[range] = S;
                range = getRange(Do->getWhileLoc());
                statements_[range] = S;
                break;
            }
            case clang::Stmt::StringLiteralClass:
                range.location = SM_.getDecomposedSpellingLoc(llvm::dyn_cast<clang::StringLiteral>(S)->getLocStart()).second;
                range.length = SM_.getDecomposedSpellingLoc(llvm::dyn_cast<clang::StringLiteral>(S)->getLocEnd()).second - range.location;
                statements_[range] = S;
                break;
            case clang::Stmt::CXXOperatorCallExprClass: {
                clang::CXXOperatorCallExpr *Expr = llvm::dyn_cast<clang::CXXOperatorCallExpr>(S);
                for (unsigned idx = 0; idx < Expr->getNumArgs(); ++idx)
                {
                    VisitExpr(Expr->getArg(idx));
                }
                break;
            }
            case clang::Stmt::CXXBindTemporaryExprClass: {
                clang::CXXBindTemporaryExpr *Bind = llvm::dyn_cast<clang::CXXBindTemporaryExpr>(S);
                VisitExpr(Bind->getSubExpr());
                break;
            }
            case clang::Stmt::MaterializeTemporaryExprClass: {
                clang::MaterializeTemporaryExpr *Materialize = llvm::dyn_cast<clang::MaterializeTemporaryExpr>(S);
                VisitStmt(Materialize->getTemporary());
                break;
            }
            case clang::Stmt::DeclRefExprClass: {
                clang::DeclRefExpr *Expr = llvm::dyn_cast<clang::DeclRefExpr>(S);
                VisitDecl(Expr->getDecl());
                break;
            }
            case clang::Stmt::ImplicitCastExprClass: {
                clang::ImplicitCastExpr *Cast = llvm::dyn_cast<clang::ImplicitCastExpr>(S);
                VisitStmt(Cast->getSubExpr());
                break;
            }
            default:
                range = getRange(S->getLocStart());
                statements_[range] = S;
                break;
        }

        return true;
    }
};

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
    std::vector<std::unique_ptr<clang::ASTUnit>> _ASTs;
    std::map<NSRange, clang::Decl *> _decls;
    std::map<NSRange, clang::Stmt *> _statements;
    std::map<NSRange, clang::TypeLoc> _typeLocs;
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
        clang::tooling::ClangTool Tool(db, files);
        OSSpinLockLock(&_lock);
        _ASTs.clear();
        Tool.buildASTs(_ASTs);
        _decls.clear();
        _statements.clear();
        _typeLocs.clear();
        [_symbols removeAllObjects];
        OSSpinLockUnlock(&_lock);
        for (auto ASTPtr = _ASTs.begin(); ASTPtr != _ASTs.end(); ASTPtr++)
        {
            clang::SourceManager &SM = ASTPtr->get()->getSourceManager();
            
            const clang::LangOptions &LangOpts = ASTPtr->get()->getLangOpts();
            for (auto it = ASTPtr->get()->top_level_begin(); it != ASTPtr->get()->top_level_end(); it++)
            {
                std::map<NSRange, clang::Decl *> decls;
                clang::Decl *D = (*it);
                NinjaNodeASTVisitor visitor(SM, LangOpts, decls, _statements, _typeLocs);
                OSSpinLockLock(&_lock);
                visitor.TraverseDecl(D);
                OSSpinLockUnlock(&_lock);
                
                for (auto info : decls)
                {
                    NSString *spelling = [NSString stringWithUTF8String:visitor.getSpelling(info.second->getLocation()).c_str()];
                    SymbolicDefinition *def = [[SymbolicDefinition alloc] initWithRange:info.first spelling:spelling];
                    [_symbols addObject:def];
                    _decls[info.first] = info.second;
                }
            }
        }
        dispatch_sync(dispatch_get_main_queue(), ^{
            [syntaxDelegate beginEditingForItem:self];
            for (auto info : _decls)
            {
                if (info.second->getKind() == clang::Decl::Function)
                {
                    [syntaxDelegate setType:ASTSyntaxFunctionType range:info.first forItem:self];
                }
                else if (info.second->getKind() == clang::Decl::CXXMethod)
                {
                    [syntaxDelegate setType:ASTSyntaxCXXMethodType range:info.first forItem:self];
                }
                else
                {
                    [syntaxDelegate setType:ASTSyntaxOtherType range:info.first tooltip:[NSString stringWithFormat:@"clang::Decl %s", info.second->getDeclKindName()] forItem:self];
                }
            }
            
            for (auto info : _statements)
            {
                if (info.second->getStmtClass() == clang::Stmt::IntegerLiteralClass ||
                    info.second->getStmtClass() == clang::Stmt::FloatingLiteralClass)
                {
                    [syntaxDelegate setType:ASTSyntaxNumericLiteralType range:info.first forItem:self];
                }
                else if (info.second->getStmtClass() == clang::Stmt::StringLiteralClass)
                {
                    [syntaxDelegate setType:ASTSyntaxStringLiteralType range:info.first forItem:self];
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
                    [syntaxDelegate setType:ASTSyntaxIntrinsicLiteralType range:info.first forItem:self];
                }
                else
                {
                    [syntaxDelegate setType:ASTSyntaxOtherType range:info.first tooltip:[NSString stringWithFormat:@"clang::Stmt %s", info.second->getStmtClassName()] forItem:self];
                }
            }
            
            for (auto info : _typeLocs)
            {
                if (info.second.getTypeLocClass() == clang::TypeLoc::Builtin)
                {
                    [syntaxDelegate setType:ASTSyntaxBuiltinType range:info.first forItem:self];
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
