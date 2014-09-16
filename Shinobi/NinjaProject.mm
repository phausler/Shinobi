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
#include <stdlib.h>
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

class RelativeDiskInterface : public ninja::DiskInterface {
private:
    ninja::RealDiskInterface interface_;
    std::string base_;
    
    bool isAbsolute(const string &path) const
    {
        return path[0] == '/' || path[0] == '~';
    }
    
    std::string absolutePath(const string &path) const
    {
        std::string composed = base_ + "/" + path;
        char resolved[PATH_MAX];
        realpath(composed.c_str(), resolved);
        return std::string(resolved);
    }
    
public:
    void setBase(std::string base) {
        base_ = base;
    }
    
    virtual TimeStamp Stat(const string& path) const
    {
        if (isAbsolute(path))
        {
            return interface_.Stat(path);
        }
        else
        {
            return interface_.Stat(absolutePath(path));
        }
    }

    virtual bool MakeDir(const string& path)
    {
        if (isAbsolute(path))
        {
            return interface_.MakeDir(path);
        }
        else
        {
            return interface_.MakeDir(absolutePath(path));
        }
    }
    
    virtual bool WriteFile(const string& path, const string& contents)
    {
        if (isAbsolute(path))
        {
            return interface_.WriteFile(path, contents);
        }
        else
        {
            return interface_.WriteFile(absolutePath(path), contents);
        }
    }
    
    virtual string ReadFile(const string& path, string* err)
    {
        if (isAbsolute(path))
        {
            return interface_.ReadFile(path, err);
        }
        else
        {
            return interface_.ReadFile(absolutePath(path), err);
        }
    }
    
    virtual int RemoveFile(const string& path)
    {
        if (isAbsolute(path))
        {
            return interface_.RemoveFile(path);
        }
        else
        {
            return interface_.RemoveFile(absolutePath(path));
        }
    }
};

class _NinjaProject : public ninja::BuildLogUser, public clang::tooling::CompilationDatabase {
private:
    ninja::BuildConfig config;
    ninja::State state;
    ninja::ManifestParser parser;
    FileReader reader;
    RelativeDiskInterface diskInterface;
    
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
    
    bool load(NSString *path, std::string *error)
    {
        NSString *base = [path stringByDeletingLastPathComponent];
        diskInterface.setBase(std::string(base.UTF8String));
        return parser.Load(std::string(path.UTF8String), error);
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
    
    bool build(NinjaProject *project, std::string *err) {
        for (int cycle = 0; cycle < 2; ++cycle) {
            std::string builddir = state.bindings_.LookupVariable("builddir");
            
            if (!builddir.empty())
            {
                diskInterface.MakeDirs(parser.GetBuildDirectory() + "/" + builddir + "/.");
            }
            
            ninja::BuildLog log;
            ninja::DepsLog *deps = new ninja::DepsLog();
            ninja::ConsoleBuildStatus status(config);
            
            std::string buildDir = parser.GetBuildDirectory();
            
            std::string log_path = buildDir + "/.ninja_log";
            std::string deps_path = buildDir + "/.ninja_deps";
            
            if (!log.OpenForWrite(log_path, *this, err))
            {
                return false;
            }
            
            if (!deps->OpenForWrite(deps_path, err))
            {
                return false;
            }
            
            ninja::Builder builder(&state, config, &log, deps, &diskInterface, &status);
            
            for (auto node : state.DefaultNodes(err))
            {
                if (!builder.AddTarget(node, err)) {
                    return false;
                }
            }
            
            if (builder.AlreadyUpToDate())
            {
                return true;
            }
            
            if (!builder.Build(err))
            {
                return false;
            }
        }
        return true;
    }
};

@implementation NinjaProject {
    BOOL _loaded;
    _NinjaProject _project;
    NSMutableArray *_children;
    NSString *_path;
}

- (instancetype)initWithPath:(NSString *)path
{
    self = [super init];
    
    if (self)
    {
        _path = [path copy];
    }
    
    return self;
}

- (ProjectItem *)parent
{
    return nil;
}

- (NSString *)absolutePath
{
    return _path;
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
        
        for (auto *node : [self ninjaProject]->nodes())
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
    _NinjaProject *project = [self ninjaProject];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        std::string err;

        if (!project->build(self, &err)) {
            NSLog(@"build failed: %s", err.c_str());
        }
    });
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

- (void)loadIfNeeded
{
    if (!_loaded)
    {
        std::string error;
        if (_project.load(_path, &error)) {
            _loaded = YES;
        } else {
            NSLog(@"%s", error.c_str());
        }
    }
}

- (clang::tooling::CompilationDatabase *)compilationDatabase
{
    [self loadIfNeeded];
    return &_project;
}

- (_NinjaProject *)ninjaProject
{
    [self loadIfNeeded];
    return &_project;
}

@end


