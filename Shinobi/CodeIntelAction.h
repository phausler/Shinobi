//
//  CodeIntelAction.h
//  Shinobi
//
//  Created by Philippe Hausler on 9/17/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#ifndef __Shinobi__CodeIntelAction__
#define __Shinobi__CodeIntelAction__

#include <Foundation/NSRange.h>

#undef IBAction
#undef IBOutlet

#include <clang/AST/ASTConsumer.h>
#include <clang/AST/ASTContext.h>
#include <clang/AST/RecursiveASTVisitor.h>
#include <clang/Frontend/CompilerInstance.h>
#include <clang/Frontend/FrontendAction.h>
#include <clang/Frontend/ASTUnit.h>
#include <clang/Lex/Preprocessor.h>
#include <clang/Tooling/Tooling.h>

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

class CodeIntelVisitor : public clang::RecursiveASTVisitor<CodeIntelVisitor>, public clang::CommentHandler, public clang::PPCallbacks {
private:
    clang::ASTContext *Context_;
    clang::LangOptions *LangOpts_;
    const clang::SourceManager *SM_;
    clang::Preprocessor *PP_;
public:
    std::vector<NSRange> Comments_;
    std::vector<NSRange> Preprocessor_;
    std::map<NSRange, clang::Stmt *> Statements_;
    std::map<NSRange, clang::Decl *> Declarations_;
private:
#pragma mark - Range/Spelling
    std::string getSpelling(clang::SourceLocation Start)
    {
        llvm::SmallVector<char, 16> buffer;
        return clang::Lexer::getSpelling(Start, buffer, *SM_, *LangOpts_).str();
    }

    NSRange getRange(clang::SourceLocation Start, clang::SourceLocation End)
    {
        std::pair<clang::FileID, unsigned> start = SM_->getDecomposedLoc(Start);
        std::pair<clang::FileID, unsigned> end = SM_->getDecomposedLoc(End);
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
    
    bool isInMainFile(const clang::SourceLocation &loc)
    {
        return SM_->getFileID(loc) == SM_->getMainFileID();
    }
    
public:
#pragma mark - Comments
    virtual bool HandleComment(clang::Preprocessor &PP, clang::SourceRange Comment) {
        if (!isInMainFile(Comment.getBegin()))
        {
            return true;
        }
        
        return true;
    }

#pragma mark - Preprocessor
    virtual void InclusionDirective(clang::SourceLocation Loc,
                                    const clang::Token &IncludeTok,
                                    llvm::StringRef FileName,
                                    bool IsAngled,
                                    clang::CharSourceRange FilenameRange,
                                    const clang::FileEntry *File,
                                    llvm::StringRef SearchPath,
                                    llvm::StringRef RelativePath,
                                    const clang::Module *Imported) {
        if (!isInMainFile(Loc))
        {
            return;
        }
        
        Preprocessor_.push_back(getRange(Loc));
    }
    
    virtual void Ident(clang::SourceLocation Loc, const std::string &str) {
        if (!isInMainFile(Loc))
        {
            return;
        }
        
        Preprocessor_.push_back(getRange(Loc));
    }
    
    
    virtual void PragmaDirective(clang::SourceLocation Loc,
                                 clang::PragmaIntroducerKind Introducer) {
        if (!isInMainFile(Loc))
        {
            return;
        }
        
        Preprocessor_.push_back(getRange(Loc));
    }
    
    virtual void PragmaComment(clang::SourceLocation Loc, const clang::IdentifierInfo *Kind,
                               const std::string &Str) {
        if (!isInMainFile(Loc))
        {
            return;
        }
        
        Preprocessor_.push_back(getRange(Loc));
    }
    
    virtual void PragmaDebug(clang::SourceLocation Loc, llvm::StringRef DebugType) {
        if (!isInMainFile(Loc))
        {
            return;
        }
        
        Preprocessor_.push_back(getRange(Loc));
    }
    
    virtual void PragmaMessage(clang::SourceLocation Loc, llvm::StringRef Namespace,
                               clang::PPCallbacks::PragmaMessageKind Kind, llvm::StringRef Str) {
        if (!isInMainFile(Loc))
        {
            return;
        }
        
        Preprocessor_.push_back(getRange(Loc));
    }
    
    virtual void PragmaDiagnosticPush(clang::SourceLocation Loc,
                                      llvm::StringRef Namespace) {
        if (!isInMainFile(Loc))
        {
            return;
        }
        
        Preprocessor_.push_back(getRange(Loc));
    }
    
    virtual void PragmaDiagnosticPop(clang::SourceLocation Loc,
                                     llvm::StringRef Namespace) {
        if (!isInMainFile(Loc))
        {
            return;
        }
        
        Preprocessor_.push_back(getRange(Loc));
    }
    
    virtual void PragmaDiagnostic(clang::SourceLocation Loc, llvm::StringRef Namespace,
                                  clang::diag::Severity mapping, llvm::StringRef Str) {
        if (!isInMainFile(Loc))
        {
            return;
        }
        
        Preprocessor_.push_back(getRange(Loc));
    }
    
    virtual void PragmaOpenCLExtension(clang::SourceLocation NameLoc,
                                       const clang::IdentifierInfo *Name,
                                       clang::SourceLocation StateLoc, unsigned State) {
        if (!isInMainFile(NameLoc))
        {
            return;
        }
        
        Preprocessor_.push_back(getRange(NameLoc));
    }
    
    virtual void PragmaWarning(clang::SourceLocation Loc, llvm::StringRef WarningSpec,
                               llvm::ArrayRef<int> Ids) {
        if (!isInMainFile(Loc))
        {
            return;
        }
        
        Preprocessor_.push_back(getRange(Loc));
    }
    
    virtual void PragmaWarningPush(clang::SourceLocation Loc, int Level) {
        if (!isInMainFile(Loc))
        {
            return;
        }
        
        Preprocessor_.push_back(getRange(Loc));
    }
    
    virtual void PragmaWarningPop(clang::SourceLocation Loc) {
        if (!isInMainFile(Loc))
        {
            return;
        }
        
        Preprocessor_.push_back(getRange(Loc));
    }
    
    virtual void MacroDefined(const clang::Token &MacroNameTok,
                              const clang::MacroDirective *MD) {
    }
    
    virtual void MacroUndefined(const clang::Token &MacroNameTok,
                                const clang::MacroDirective *MD) {
    }
    
    virtual void Defined(const clang::Token &MacroNameTok, const clang::MacroDirective *MD,
                         clang::SourceRange Range) {
    }
    
#pragma mark - AST
    
    bool VisitIntegerLiteral(clang::IntegerLiteral *S)
    {
        if (!isInMainFile(S->getLocStart()))
        {
            return true;
        }
        
        NSRange range = getRange(S->getLocStart(), S->getLocEnd());
        Statements_[range] = S;
        
        return true;
    }
    
    bool VisitStmt(clang::Stmt *S) {
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
                Statements_[range] = S;
                if (If->getElse() != nullptr) {
                    range = getRange(If->getElseLoc());
                    Statements_[range] = S;
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
                Statements_[range] = S;
                break;
            case clang::Stmt::DoStmtClass: {
                clang::DoStmt *Do = llvm::dyn_cast<clang::DoStmt>(S);
                range = getRange(Do->getDoLoc());
                Statements_[range] = S;
                range = getRange(Do->getWhileLoc());
                Statements_[range] = S;
                break;
            }
            case clang::Stmt::StringLiteralClass:
                range.location = SM_->getDecomposedSpellingLoc(llvm::dyn_cast<clang::StringLiteral>(S)->getLocStart()).second;
                range.length = SM_->getDecomposedSpellingLoc(llvm::dyn_cast<clang::StringLiteral>(S)->getLocEnd()).second - range.location;
                Statements_[range] = S;
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
                Statements_[range] = S;
                break;
        }
        
        return true;
    }

    bool VisitDecl(clang::Decl *D) {
        if (!isInMainFile(D->getLocStart()))
        {
            return true;
        }
        
        Declarations_[getRange(D->getSourceRange())] = D;
        return true;
    }
#pragma mark - Visitor
    bool process(clang::tooling::ClangTool &Tool) {
        Comments_.clear();
        Preprocessor_.clear();
        Statements_.clear();
        Declarations_.clear();
        CodeIntelVisitor::Action action(this);
        int res = Tool.run(&action);
        return res == 0;
    }
private:
    class Consumer : public clang::ASTConsumer {
    public:
        Consumer(CodeIntelVisitor *Visitor) :
            Visitor_(Visitor) {
        }
        
        virtual void HandleTranslationUnit(clang::ASTContext &Context) {
            Visitor_->Context_ = &Context;
            Visitor_->TraverseDecl(Context.getTranslationUnitDecl());
        }
        
    private:
        CodeIntelVisitor *Visitor_;
    };
    
    class Action : public clang::ASTFrontendAction, public clang::tooling::ToolAction {
    private:
        CodeIntelVisitor *Visitor_;
        clang::ASTConsumer *Consumer_;
    public:
        Action(CodeIntelVisitor *Visitor) :
            Visitor_(Visitor),
            Consumer_(nullptr) {
        }
        
        ~Action() {
            delete Consumer_;
        }
        
        clang::ASTConsumer *CreateASTConsumer(clang::CompilerInstance &CI,
                                              llvm::StringRef InFile) {
            if (Consumer_ == nullptr) {
                Consumer_ = new CodeIntelVisitor::Consumer(Visitor_);
            }
            
            return Consumer_;
        }
        
        virtual bool BeginSourceFileAction(clang::CompilerInstance &CI,
                                           llvm::StringRef FileName) {
            Visitor_->LangOpts_ = &CI.getLangOpts();
            Visitor_->SM_ = &CI.getSourceManager();
            Visitor_->PP_ = &CI.getPreprocessor();
            Visitor_->PP_->addPPCallbacks(Visitor_);
            return true;
        }
        
        bool runInvocation(clang::CompilerInvocation *CI, clang::FileManager *Files, clang::DiagnosticConsumer *DiagConsumer) {
            clang::ASTUnit *AST = clang::ASTUnit::LoadFromCompilerInvocationAction(CI, clang::CompilerInstance::createDiagnostics(&CI->getDiagnosticOpts()), this);
            if (!AST)
                return false;
            return true;
        }
    };
};

#endif /* defined(__Shinobi__CodeIntelAction__) */
