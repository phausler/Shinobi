//
//  FileSystemMonitor.m
//  Shinobi
//
//  Created by Philippe Hausler on 9/18/14.
//  Copyright (c) 2014 Philippe Hausler. All rights reserved.
//

#import "FileSystemMonitor.h"
#include <sys/types.h>
#include <sys/event.h>
#include <sys/time.h>
#include <fcntl.h>
#include <unistd.h>

@interface FileSystemMonitor () <FileSystemMonitorDelegate>

- (void)handleEvent:(struct kevent *)event;

@end

@implementation FileSystemMonitor {
    NSString *_path;
    NSMutableDictionary *_contents;
    int _fd;
    int _kq;
    CFFileDescriptorRef _fileDescriptor;
    __weak id<FileSystemMonitorDelegate> _delegate;
    struct {
        int removed:1;
        int added:1;
        int changed:1;
    } _flags;
}

static void eventHandler(CFFileDescriptorRef descriptor, CFOptionFlags callBackTypes, void *info)
{
    FileSystemMonitor *obj = (__bridge FileSystemMonitor *)info;
    struct kevent event;
    struct timespec timeout = {0, 0};
    int eventCount;
    int kq = CFFileDescriptorGetNativeDescriptor(descriptor);
    eventCount = kevent(kq, NULL, 0, &event, 1, &timeout);
    if (eventCount > 0)
    {
        [obj handleEvent:&event];
    }
    CFFileDescriptorEnableCallBacks(descriptor, kCFFileDescriptorReadCallBack);
}

- (instancetype)initWithPath:(NSString *)path
{
    self = [super init];
    
    if (self)
    {
        _path = [path copy];
        NSError *error = nil;
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray *contents = [fm contentsOfDirectoryAtPath:_path error:&error];
        _contents = [[NSMutableDictionary alloc] init];
        for (NSString *item in contents)
        {
            NSString *itemPath = [path stringByAppendingPathComponent:item];
            BOOL isDir = NO;
            BOOL exists = [fm fileExistsAtPath:itemPath isDirectory:&isDir];
            if (exists && isDir)
            {
                FileSystemMonitor *monitor = [[FileSystemMonitor alloc] initWithPath:itemPath];
                
                if (monitor == nil)
                {
                    continue;
                }
                
                monitor.delegate = self;
                _contents[itemPath] = monitor;
            }
            else if (exists)
            {
                _contents[itemPath] = [fm attributesOfItemAtPath:itemPath error:&error];
            }
        }

        _fd = open([path fileSystemRepresentation], O_EVTONLY);
        
        if (_fd < 0)
        {
            self = nil;
            return nil;
        }
        
        _kq = kqueue();
        
        if (_kq < 0)
        {
            self = nil;
            return nil;
        }
        
        struct kevent event = {
            .ident  = _fd,
            .filter = EVFILT_VNODE,
            .flags  = EV_ADD | EV_CLEAR,
            .fflags = NOTE_WRITE,
            .data   = 0,
            .udata  = NULL,
        };
        
        int err = kevent(_kq, &event, 1, NULL, 0, NULL);

        if (err != 0)
        {
            self = nil;
            return nil;
        }
        
        CFFileDescriptorContext ctx = {
            .version = 0,
            .info = (__bridge void *)self
        };
        
        _fileDescriptor = CFFileDescriptorCreate(kCFAllocatorDefault, _kq, true, &eventHandler, &ctx);
        
        if (_fileDescriptor == NULL)
        {
            self = nil;
            return nil;
        }
        
        CFRunLoopSourceRef source = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, _fileDescriptor, 0);
        
        if (source == NULL)
        {
            self = nil;
            return self;
        }
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
        CFRelease(source);
    }
    
    return self;
}

- (void)dealloc
{
    _path = nil;
    
    if (_fd >= 0)
    {
        close(_fd);
    }
    
    if (_fileDescriptor != NULL)
    {
        // since the descriptor owns the FD dont double close
        CFFileDescriptorInvalidate(_fileDescriptor);
        CFRelease(_fileDescriptor);
        _fileDescriptor = NULL;
    }
    else if (_kq >= 0)
    {
        close(_kq);
    }
}

- (void)handleEvent:(struct kevent *)event
{
    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *contents = [fm contentsOfDirectoryAtPath:_path error:&error];
    NSMutableSet *items = [[NSMutableSet alloc] init];
    for (NSString *item in contents)
    {
        NSString *itemPath = [_path stringByAppendingPathComponent:item];
        [items addObject:itemPath];
    }
    NSDictionary *prevContents = [_contents copy];
    NSSet *prevItems = [NSSet setWithArray:[prevContents allKeys]];

    for (NSString *itemPath in items)
    {
        BOOL isDir = NO;
        BOOL exists = [fm fileExistsAtPath:itemPath isDirectory:&isDir];
        if (exists && isDir)
        {
            if (_contents[itemPath] == nil)
            {
                FileSystemMonitor *monitor = [[FileSystemMonitor alloc] initWithPath:itemPath];
                monitor.delegate = self;
                _contents[itemPath] = monitor;
            }
        }
        else if (exists)
        {
            _contents[itemPath] = [fm attributesOfItemAtPath:itemPath error:&error];
        }
    }
    
    NSMutableSet *removed = [prevItems mutableCopy];
    [removed minusSet:items];
    NSMutableSet *added = [items mutableCopy];
    [added minusSet:prevItems];
    NSMutableSet *changed = [items mutableCopy];
    [changed minusSet:added];
    [changed minusSet:removed];
    
    for (NSString *item in [changed copy])
    {
        if ([_contents[item] isEqualTo:prevContents[item]])
        {
            [changed removeObject:item];
        }
    }
    
    [_contents removeObjectsForKeys:[removed allObjects]];
    
    if ([removed count] > 0)
    {
        [self monitor:self filesRemoved:removed];
    }
    
    if ([added count] > 0)
    {
        [self monitor:self filesRemoved:added];
    }
    
    if ([changed count] > 0)
    {
        [self monitor:self filesChanged:changed];
    }
}

- (id<FileSystemMonitorDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<FileSystemMonitorDelegate>)delegate
{
    if (_delegate != delegate)
    {
        _flags.added = [delegate respondsToSelector:@selector(monitor:filesAdded:)];
        _flags.removed = [delegate respondsToSelector:@selector(monitor:filesRemoved:)];
        _flags.changed = [delegate respondsToSelector:@selector(monitor:filesChanged:)];
        _delegate = delegate;
        if (_delegate && _fileDescriptor)
        {
            CFFileDescriptorEnableCallBacks(_fileDescriptor, kCFFileDescriptorReadCallBack);
        }
    }
}

- (void)monitor:(FileSystemMonitor *)monitor filesRemoved:(NSSet *)files
{
    if (_flags.removed)
    {
        [_delegate monitor:self filesRemoved:files];
    }
}

- (void)monitor:(FileSystemMonitor *)monitor filesAdded:(NSSet *)files
{
    if (_flags.added)
    {
        [_delegate monitor:self filesAdded:files];
    }
}

- (void)monitor:(FileSystemMonitor *)monitor filesChanged:(NSSet *)files
{
    if (_flags.changed)
    {
        [_delegate monitor:self filesChanged:files];
    }
}

@end
