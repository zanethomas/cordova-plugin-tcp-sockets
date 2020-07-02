//
//  ServerSocketAdapter.m
//  SocketsForCordova
//
//  Created by Alexei on 10/09/2018.
//
#include <CoreFoundation/CoreFoundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <arpa/inet.h>

NSString * const TCPServerErrorDomain = @"TCPServerErrorDomain";
int const WRITE_BUFFER_SIZE = 10 * 1024;

#import "ServerSocketAdapter.h"

@implementation ServerSocketAdapter

//NSString *_iface;
//NSNumber *_port;

// This function is called by CFSocket when a new connection comes in.
// We gather some data here, and convert the function call to a method
// invocation on TCPServer.
static void TCPServerAcceptCallBack(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    ServerSocketAdapter *server = (__bridge ServerSocketAdapter *)info;
    if (kCFSocketAcceptCallBack == type) {
        // for an AcceptCallBack, the data parameter is a pointer to a CFSocketNativeHandle
        SocketAdapter *socket = [[SocketAdapter alloc] initWithData:data];
        server.openEventHandler(socket);
    }
}

-(void)stopServer {
    if (netService) {
        [netService stop];
        netService = nil;
        CFSocketInvalidate(ipv4socket);
        CFSocketInvalidate(ipv6socket);
    }
}

-(bool)initializeServer:(NSString *)iface port:(NSNumber*)port  {
    NSError *error;
    CFSocketContext socketCtxt = {0, (__bridge void *)(self), NULL, NULL, NULL};
    ipv4socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, (CFSocketCallBack)&TCPServerAcceptCallBack, &socketCtxt);
    ipv6socket = CFSocketCreate(kCFAllocatorDefault, PF_INET6, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, (CFSocketCallBack)&TCPServerAcceptCallBack, &socketCtxt);

    if (NULL == ipv4socket || NULL == ipv6socket) {
        error = [[NSError alloc] initWithDomain:TCPServerErrorDomain code:kTCPServerNoSocketsAvailable userInfo:nil];
        if (ipv4socket) CFRelease(ipv4socket);
        if (ipv6socket) CFRelease(ipv6socket);
        ipv4socket = NULL;
        ipv6socket = NULL;
        self.startErrorEventHandler([NSString stringWithFormat:@"%@, %@", error.localizedDescription, error.localizedFailureReason]);
        return false;
    }

    int yes = 1;
    setsockopt(CFSocketGetNative(ipv4socket), SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes));
    setsockopt(CFSocketGetNative(ipv6socket), SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes));

    // set up the IPv4 endpoint; if port is 0, this will cause the kernel to choose a port for us
    struct sockaddr_in addr4;
    memset(&addr4, 0, sizeof(addr4));
    addr4.sin_len = sizeof(addr4);
    addr4.sin_family = AF_INET;
    addr4.sin_port = htons(port.integerValue);
    addr4.sin_addr.s_addr = htonl(inet_addr([iface cStringUsingEncoding:NSASCIIStringEncoding])); //INADDR_ANY = all loca lost addresses (0.0.0.0)
    NSData *address4 = [NSData dataWithBytes:&addr4 length:sizeof(addr4)];

    if (kCFSocketSuccess != CFSocketSetAddress(ipv4socket, (CFDataRef)address4)) {
        error = [[NSError alloc] initWithDomain:TCPServerErrorDomain code:kTCPServerCouldNotBindToIPv4Address userInfo:nil];
        if (ipv4socket) CFRelease(ipv4socket);
        if (ipv6socket) CFRelease(ipv6socket);
        ipv4socket = NULL;
        ipv6socket = NULL;
        self.startErrorEventHandler([NSString stringWithFormat:@"%@, %@", error.localizedDescription, error.localizedFailureReason]);
        return false;
    }

    if (0 == port) {
        // now that the binding was successful, we get the port number
        // -- we will need it for the v6 endpoint and for the NSNetService
        NSData *addr = (__bridge NSData *)CFSocketCopyAddress(ipv4socket);
        memcpy(&addr4, [addr bytes], [addr length]);
        port = @(ntohs(addr4.sin_port));
    }

    // set up the IPv6 endpoint
    struct sockaddr_in6 addr6;
    memset(&addr6, 0, sizeof(addr6));
    addr6.sin6_len = sizeof(addr6);
    addr6.sin6_family = AF_INET6;
    addr6.sin6_port = htons(port.integerValue);
    memcpy(&(addr6.sin6_addr), &in6addr_any, sizeof(addr6.sin6_addr));
    NSData *address6 = [NSData dataWithBytes:&addr6 length:sizeof(addr6)];

    if (kCFSocketSuccess != CFSocketSetAddress(ipv6socket, (CFDataRef)address6)) {
        error = [[NSError alloc] initWithDomain:TCPServerErrorDomain code:kTCPServerCouldNotBindToIPv6Address userInfo:nil];
        if (ipv4socket) CFRelease(ipv4socket);
        if (ipv6socket) CFRelease(ipv6socket);
        ipv4socket = NULL;
        ipv6socket = NULL;
        self.startErrorEventHandler([NSString stringWithFormat:@"%@, %@", error.localizedDescription, error.localizedFailureReason]);
        return false;
    }

    // set up the run loop sources for the sockets
    CFRunLoopRef cfrl = CFRunLoopGetMain();
    CFRunLoopSourceRef source4 = CFSocketCreateRunLoopSource(kCFAllocatorDefault, ipv4socket, 0);
    CFRunLoopAddSource(cfrl, source4, kCFRunLoopCommonModes);
    CFRelease(source4);

    CFRunLoopSourceRef source6 = CFSocketCreateRunLoopSource(kCFAllocatorDefault, ipv6socket, 0);
    CFRunLoopAddSource(cfrl, source6, kCFRunLoopCommonModes);
    CFRelease(source6);

    // we can only publish the service if we have a type to publish with
    type = @"_http._tcp.";
    if (nil != type) {
        NSString *publishingDomain = self.iface ? self.iface : @"";
        NSString *publishingName = nil;
        if (nil != name) {
            publishingName = name;
        } else {
            NSString * thisHostName = [[NSProcessInfo processInfo] hostName];
            if ([thisHostName hasSuffix:@".local"]) {
                publishingName = [thisHostName substringToIndex:([thisHostName length] - 6)];
            }
        }
        netService = [[NSNetService alloc] initWithDomain:publishingDomain type:type name:publishingName port:(int)port.integerValue];
        [netService publish];

        NSLog(@"publishingDomain: %@, publishingName: %@, port: %@", publishingDomain, publishingName, port.stringValue);
    }

    return true;
}

-(void)restartServer {
    NSLog(@"server socket adapter RESTART");
    NSLog(@"iface: %@, port: %@", self.iface, self.port);
    [self initializeServer:self.iface port:self.port];
}

- (void)start:(NSString *)iface port:(NSNumber*)port {

    self.iface = iface;
    self.port = port;

    NSLog(@"server socket adapter start");
    NSLog(@"iface: %@, port: %@", iface, port);
    if ([self initializeServer:iface port:port] ) {
        self.startEventHandler();
    }
}

- (void)halt {
    NSLog(@"server socket adapter stop");
    [netService stop];
    netService = nil;
    if (ipv4socket) {
        CFSocketInvalidate(ipv4socket);
        CFRelease(ipv4socket);
        ipv4socket = NULL;
    }

    if (ipv6socket) {
        CFSocketInvalidate(ipv6socket);
        CFRelease(ipv6socket);
        ipv6socket = NULL;
    }
}
- (void)stop {
    NSLog(@"server socket adapter stop");
    [netService stop];
    netService = nil;
    if (ipv4socket) {
        CFSocketInvalidate(ipv4socket);
        CFRelease(ipv4socket);
        ipv4socket = NULL;
    }

    if (ipv6socket) {
        CFSocketInvalidate(ipv6socket);
        CFRelease(ipv6socket);
        ipv6socket = NULL;
    }
    self.stopEventHandler(false);
}


@end
