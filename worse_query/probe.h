//
//  probe.h
//  独立探针：用自己的 App Group 容器做查询形状实验（不沿用任何公开 PoC 的入口）。
//

#ifndef probe_h
#define probe_h

#import <Foundation/Foundation.h>
#include <stdint.h>
#include <stdbool.h>

// 运行时读自己签名里的 App Group 列表
NSArray<NSString *> *wq_own_groups(void);

// class 7 查询：可指定 group 标识符、part、flags、part-domain。
// linkTarget 非空时，先在自己的组容器 <group>/<partRel>/<domain> 建符号链接指向 linkTarget。
int64_t wq_probe_group(NSString *group, NSString *partRel, uint64_t part, uint64_t flags,
                       NSString *domain, NSString *linkTarget, bool *linkOk);

// 诊断版：把每一步拆开报出来（查到了没 / token 有没有 / 错误类型 / errno / consume 返回值）
int64_t wq_probe_group_detail(NSString *group, NSString *partRel, uint64_t part, uint64_t flags,
                              NSString *domain, NSString *linkTarget,
                              int64_t *queryResult, int64_t *errorType, int64_t *errorPosix,
                              int64_t *tokenOK, int64_t *consumeHandle);

// 同上，但查询后保留符号链接（用于验证经由链接路径的写入）
int64_t wq_probe_group_keep(NSString *group, NSString *partRel, uint64_t part, uint64_t flags,
                            NSString *domain, NSString *linkTarget, bool *linkOk);

// 时序差：先查询拿到 token，再把 domain 目录换成指向 linkTarget 的符号链接，最后 consume
int64_t wq_probe_group_swap(NSString *group, NSString *partRel, uint64_t part, uint64_t flags,
                            NSString *domain, NSString *linkTarget, bool *linkOk);

// class 2 对照：查询自己的数据容器
int64_t wq_probe_own_container(uint64_t part, uint64_t flags, NSString *domain);

// class 2 按 bundle id 查询任意 App 数据容器：返回路径，handle<0 表示 consume 失败
NSString *wq_bundle_container(NSString *bundle, uint64_t part, uint64_t flags,
                              int64_t *handle, int64_t *errType, int64_t *errPosix);

// 通用租约实验：任意 class / 标识符 / part / flags / part-domain，返回路径并立即 consume
NSString *wq_lease_probe(uint64_t cls, NSString *ident, BOOL isGroup, uint64_t part,
                         uint64_t flags, NSString *domain, int64_t *handle,
                         int64_t *errType, int64_t *errPosix);

// 只读诊断：转储 LaunchServices 相关类的运行时方法列表
NSString *wq_ls_methods(void);

// 只读诊断：尝试 mach-lookup 一个 XPC 服务（不发送业务消息）
NSString *wq_xpc_lookup(NSString *service);

// 只读诊断：尝试 LaunchServices 的块枚举入口，返回命中数量
NSString *wq_ls_enumerate(void);

// 只读诊断：尝试 LSApplicationRecord 的枚举器（launchservices 新接口）
NSString *wq_ls_records(void);

// 只读诊断：向 XPC 服务发一条探测消息，看是否真的可达
NSString *wq_xpc_ping(NSString *service);

// 诊断：尝试连接 com.apple.mobile.installation_proxy 并发送 Lookup
void wq_try_install_xpc(void);

// 不带标识符枚举容器（诊断）：返回总数，out 收集前 limit 条 {path, identifier}
uint64_t wq_list_containers(uint64_t cls, uint64_t part, uint64_t flags,
                            NSMutableArray<NSDictionary *> *out, uint64_t limit,
                            int64_t *errType, int64_t *errPosix);

// 参考形状的枚举：iterate_results_sync，无标识符；返回条数，out 收集前 limit 条
uint64_t wq_iterate_containers(uint64_t cls, uint64_t part, uint64_t flags,
                               NSMutableArray<NSDictionary *> *out, uint64_t limit,
                               int64_t *errType, int64_t *errPosix, int64_t *iterOK);

// class 2 诊断版：part 传 UINT64_MAX 表示不设 part（最干净的基线）
int64_t wq_probe_own_detail(uint64_t part, uint64_t flags,
                            int64_t *queryResult, int64_t *errorType, int64_t *errorPosix,
                            int64_t *tokenOK, int64_t *consumeHandle);

#endif /* probe_h */
