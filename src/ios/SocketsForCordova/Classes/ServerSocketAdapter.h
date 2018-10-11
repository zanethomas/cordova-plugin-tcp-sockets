//
//  ServerSocketAdapter.h
//  SocketsForCordova
//
//  Created by Alexei on 10/09/2018.
//

#import <Foundation/Foundation.h>
//#import <CoreServices/CoreServices.h>
#import "SocketAdapter.h"

NSString * const TCPServerErrorDomain;

typedef enum {
    kTCPServerCouldNotBindToIPv4Address = 1,
    kTCPServerCouldNotBindToIPv6Address = 2,
    kTCPServerNoSocketsAvailable = 3,
} TCPServerErrorCode;

@interface ServerSocketAdapter : NSObject {
@private
    id delegate;
    NSString *domain;
    NSString *name;
    NSString *type;
    uint16_t port;
    CFSocketRef ipv4socket;
    CFSocketRef ipv6socket;
    NSNetService *netService;
}

- (void)start:(NSString *)iface port:(NSNumber*)port;
- (void)stop;

@property (copy) void (^startEventHandler)();
@property (copy) void (^startErrorEventHandler)(NSString*);
@property (copy) void (^openEventHandler)(SocketAdapter*);
@property (copy) void (^stopEventHandler)(bool);

@end
