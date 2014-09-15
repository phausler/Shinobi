    //
//  NinjaProject.m
//  Shinobi
//
//  Created by Philippe Hausler on 9/11/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import "NinjaProject.h"
#import "NinjaNode.h"
#import "ProjectDirectory.h"
#include <libgen.h>
#include <ninja/build.h>
#include <ninja/manifest_parser.h>
#include <ninja/state.h>
#include <ninja/util.h>
#include <ninja/build_log.h>
#include <ninja/build.h>
#include <ninja/deps_log.h>
#include <ninja/disk_interface.h>
#include <clang/Tooling/CompilationDatabase.h>

@interface NinjaNode (Internal)

- (instancetype)initWithNode:(ninja::Node *)node project:(NinjaProject *)project;

@end

@interface ProjectItem (Internal)

- (void)setParent:(ProjectItem *)parent;
- (void)addChild:(ProjectItem *)item;

@end

@interface ProjectDirectory (Internal)

- (instancetype)initWithPath:(NSString *)path;

@end

@interface NinjaProject (Internal)

- (void)updateProgress:(BuildProgress)progress;
- (void)startedBuildingNodes:(NSSet *)nodes progress:(BuildProgress)progress;
- (void)finishedBuildingNodes:(NSSet *)nodes progress:(BuildProgress)progress;

@end

class FileReader : public ninja::ManifestParser::FileReader {
    virtual bool ReadFile(const string &path, string *contents, string *err) {
        FILE* f = fopen(path.c_str(), "r");
        if (!f) {
            err->assign(strerror(errno));
            return false;
        }
        
        char buf[64 << 10];
        size_t len;
        while ((len = fread(buf, 1, sizeof(buf), f)) > 0) {
            contents->append(buf, len);
        }
        if (ferror(f)) {
            err->assign(strerror(errno));
            contents->clear();
            fclose(f);
            return false;
        }
        fclose(f);
        return true;
    }
};

class BuildStatusReporter : public ninja::BuildStatus {
private:
    __weak NinjaProject *_project;
    BuildProgress progress;
    
    void reportTotal()
    {
        [_project updateProgress:progress];
    }
    
    void reportStart(ninja::Edge *edge)
    {
        @autoreleasepool {
            NSMutableSet *paths = [[NSMutableSet alloc] init];
            NSMutableSet *nodes = [[NSMutableSet alloc] init];
            for (auto *input : edge->inputs_)
            {
                NSString *path = [NSString stringWithUTF8String:input->path().c_str()];
                [paths addObject:path];
            }
            
            for (NSString *path in paths)
            {
                ProjectItem *node = [_project childForPath:path];
                if (node != nil)
                {
                    [nodes addObject:node];
                }
            }
            
            [_project startedBuildingNodes:nodes progress:progress];
        }
    }
    
    void reportFinished(ninja::Edge *edge, const std::string &output, bool success)
    {
        NSMutableSet *paths = [[NSMutableSet alloc] init];
        NSMutableSet *nodes = [[NSMutableSet alloc] init];
        for (auto *input : edge->inputs_)
        {
            NSString *path = [NSString stringWithUTF8String:input->path().c_str()];
            [paths addObject:path];
        }
        
        for (NSString *path in paths)
        {
            ProjectItem *node = [_project childForPath:path];
            if (node != nil)
            {
                [nodes addObject:node];
            }
        }
        
        [_project finishedBuildingNodes:nodes progress:progress];
    }
    
    void reportFinished()
    {
        [_project updateProgress:progress];
    }
    
public:
    BuildStatusReporter(NinjaProject *project) :
        _project(project)
    {
        progress.finished = 0;
        progress.total = 0;
    }
    
    void PlanHasTotalEdges(int total)
    {
        progress.total = total;
        reportTotal();
    }
    
    void BuildEdgeStarted(ninja::Edge *edge)
    {
        reportStart(edge);
    }
    
    void BuildEdgeFinished(ninja::Edge *edge, bool success, const std::string &output, int *start_time, int *end_time)
    {
        progress.finished++;
        reportFinished(edge, output, success);
    }
    
    void BuildFinished() {
        reportFinished();
    }
};

class _NinjaProject : public ninja::BuildLogUser, public clang::tooling::CompilationDatabase {
private:
    ninja::BuildConfig config;
    ninja::State state;
    ninja::ManifestParser parser;
    FileReader reader;
    ninja::RealDiskInterface diskInterface;
    
    std::string nodePath(std::string path) const
    {
        if (path[0] == '/') {
            return path;
        } else {
            std::string absolute = parser.GetBuildDirectory() + "/" + path;
            char rpath[PATH_MAX];
            realpath(absolute.c_str(), rpath);
            return std::string(rpath);
        }
    }
    
    std::string nodePath(ninja::Node *node) const
    {
        return nodePath(node->path());
    }
    
    static std::vector<std::string> splitArguments(std::string command)
    {
        std::vector<std::string> args;
        std::string arg = "";
        char quoteType = '\0';
        bool escaped = false;
        
        for (char c : command)
        {
            if (escaped)
            {
                escaped = false;
                arg += c;
            }
            else if (c == '\\')
            {
                escaped = true;
            }
            else if ((quoteType == '\0' && c == '\'') ||
                     (quoteType == '\0' && c == '"'))
            {
                quoteType = c;
            }
            else if ((quoteType == '\'' && c == '\'') ||
                     (quoteType == '"' && c == '"'))
            {
                quoteType = '\0';
            }
            else if (!isspace(c) || quoteType != '\0')
            {
                arg += c;
            }
            else
            {
                args.push_back(arg);
                arg = "";
            }
        }
        
        args.push_back(arg);
        
        return args;
    }
    
    std::vector<clang::tooling::CompileCommand> getCompileCommands(llvm::StringRef FilePath) const
    {
        std::vector<clang::tooling::CompileCommand> commands;
        
        for (auto *edge : state.edges_)
        {
            for (auto *input : edge->inputs_)
            {
                if (nodePath(input) == FilePath.str())
                {
                    clang::tooling::CompileCommand command;
                    command.Directory = edge->GetWorkingDirectory();
                    
                    const ninja::EvalString *commandStr = edge->rule_->GetBinding("command");
                    
                    if (commandStr != nullptr)
                    {
                        std::string evaluatedCommand = edge->EvaluateCommand();
                        command.CommandLine = splitArguments(evaluatedCommand);
                        command.CommandLine.push_back("--sysroot=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.9.sdk/");
                    }
                    
                    if (command.CommandLine.size() > 0)
                    {
                        commands.push_back(command);
                    }
                    
                    
                    break;
                }
            }
            
            if (commands.size() > 0)
            {
                break;
            }
        }
        
        return commands;
    }
    
    std::vector<std::string> getAllFiles() const
    {
        std::vector<std::string> files;
        std::set<std::string> paths;
        
        // add all sources
        for (auto *edge : state.edges_)
        {
            for (auto *input : edge->inputs_)
            {
                paths.insert(input->path());
            }
        }
        
        // remove all derived sources
        for (auto *edge : state.edges_)
        {
            for (auto *output : edge->outputs_)
            {
                paths.erase(output->path());
            }
        }
        
        // filter for compiled, non-derived clang compatible sources
        for (auto path : paths)
        {
            std::string ext = path.substr(path.find_last_of(".") + 1);
            if (!(ext == "c" ||
                  ext == "C" ||
                  ext == "m" ||
                  ext == "mm" ||
                  ext == "cpp" ||
                  ext == "CPP" ||
                  ext == "cc" ||
                  ext == "CC"))
            {
                continue;
            }
            
            files.push_back(nodePath(path));
        }
        
        return files;
    }
    
    std::vector<clang::tooling::CompileCommand> getAllCompileCommands() const
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
    
public:
    _NinjaProject() :
        parser(&state, &reader) {}
    
    void load(NSString *path)
    {
        parser.Load(std::string(path.UTF8String), nullptr);
    }
    
    std::vector<ninja::Node *> nodes()
    {
        std::vector<ninja::Node *> files;
        std::map<std::string, ninja::Node *> nodes;
        std::set<std::string> paths;
        
        // add all sources
        for (auto *edge : state.edges_)
        {
            for (auto *input : edge->inputs_)
            {
                paths.insert(input->path());
                nodes[input->path()] = input;
            }
        }
        
        // remove all derived sources
        for (auto *edge : state.edges_)
        {
            for (auto *output : edge->outputs_) {
                paths.erase(output->path());
                nodes.erase(output->path());
            }
        }
        
        // filter for compiled, non-derived clang compatible sources
        for (auto path : paths)
        {
            std::string ext = path.substr(path.find_last_of(".") + 1);
            if (!(ext == "c" ||
                  ext == "C" ||
                  ext == "m" ||
                  ext == "mm" ||
                  ext == "cpp" ||
                  ext == "CPP" ||
                  ext == "cc" ||
                  ext == "CC"))
            {
                continue;
            }
            
            files.push_back(nodes[path]);
        }
        
        return files;
    }
    
    bool IsPathDead(StringPiece s) const {
        ninja::Node* n = state.LookupNode(s);
        return (!n || !n->in_edge()) && diskInterface.Stat(s.AsString()) == 0;
    }
    
    bool build(NinjaProject *project) {
        ninja::BuildLog log;
        ninja::DepsLog deps;
        BuildStatusReporter status(project);
        ninja::Builder builder(&state, config, &log, &deps, &diskInterface, &status);
        std::string err;
        
        for (auto node : state.DefaultNodes(&err))
        {
            builder.AddTarget(node, &err);
        }
        

        std::string log_path = ".ninja_log";
        if (!log.Load(log_path, &err))
        {
            return false;
        }
        
        if (!err.empty()) {
            err.clear();
        }
        
        std::string deps_path = ".ninja_deps";
        if (!deps.Load(deps_path, &state, &err))
        {
            return false;
        }
        
        if (!err.empty()) {
            err.clear();
        }
        
        if (!log.OpenForWrite(log_path, *this, &err)) {
            return false;
        }
        
        if (!deps.OpenForWrite(deps_path, &err)) {
            return false;
        }
        
        if (builder.AlreadyUpToDate()) {
            return true;
        }
        
        return builder.Build(&err);
    }
};

@implementation NinjaProject {
    _NinjaProject project;
    NSMutableArray *_children;
    NSString *_path;
}

- (instancetype)initWithPath:(NSString *)path
{
    self = [super init];
    
    if (self)
    {
        _path = [path copy];
        project.load(path);
    }
    
    return self;
}

- (ProjectItem *)parent
{
    return nil;
}

- (NSString *)path
{
    return _path;
}

- (void)addChild:(ProjectItem *)item
{
    [item setParent:self];
    [_children addObject:item];
}

- (NSArray *)children
{
    if (_children == nil)
    {
        NSMutableArray *nodes = [[NSMutableArray alloc] init];
        
        for (auto *node : project.nodes())
        {
            [nodes addObject:[[NinjaNode alloc] initWithNode:node project:self]];
        }
        
        _children = [[NSMutableArray alloc] init];
        
        for (NinjaNode *node in nodes)
        {
            NSArray *pathComponents = [node.path pathComponents];
            NSString *path = nil;
            ProjectItem *currentItem = self;
            
            for (NSString *item in pathComponents)
            {
                if (path == nil)
                {
                    path = item;
                }
                else
                {
                    path = [path stringByAppendingPathComponent:item];
                }
                
                ProjectItem *child = [self childForPath:path];
                
                if (child == nil)
                {
                    if ([path isEqualToString:node.path])
                    {
                        [currentItem addChild:node];
                    }
                    else
                    {
                        ProjectDirectory *dirItem = [[ProjectDirectory alloc] initWithPath:path];
                        [currentItem addChild:dirItem];
                        currentItem = dirItem;
                    }
                }
                else if ([child isKindOfClass:[ProjectDirectory class]])
                {
                    currentItem = child;
                }
            }
        }
    }
    
    return _children;
}

- (void)build
{
    project.build(self);
}

- (void)updateProgress:(BuildProgress)progress
{
    [self.buildDelegate buildProgressChanged:progress];
}

- (void)startedBuildingNodes:(NSSet *)nodes progress:(BuildProgress)progress
{
    [self.buildDelegate buildProgressChanged:progress];
}

- (void)finishedBuildingNodes:(NSSet *)nodes progress:(BuildProgress)progress
{
    [self.buildDelegate buildProgressChanged:progress];
}

- (clang::tooling::CompilationDatabase *)compilationDatabase
{
    return &project;
}

@end


