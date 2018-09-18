//
//  ServerSocketAdapter.m
//  SocketsForCordova
//
//  Created by Alexei Vinidiktov on 10/09/2018.
//
#include <CoreFoundation/CoreFoundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <arpa/inet.h>

NSString * const TCPServerErrorDomain = @"TCPServerErrorDomain";
int const WRITE_BUFFER_SIZE = 10 * 1024;

NSInputStream *inputStream;
NSOutputStream *outputStream;

#import "ServerSocketAdapter.h"

@implementation ServerSocketAdapter

- (id)init {
    return self;
}

// This function is called by CFSocket when a new connection comes in.
// We gather some data here, and convert the function call to a method
// invocation on TCPServer.
static void TCPServerAcceptCallBack(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    ServerSocketAdapter *server = (__bridge ServerSocketAdapter *)info;
    if (kCFSocketAcceptCallBack == type) {
        // for an AcceptCallBack, the data parameter is a pointer to a CFSocketNativeHandle
        SocketAdapter *socket = [[SocketAdapter alloc] initWithData:data];
        [socket startReadLoop];
//        SocketAdapter *socket = [SocketAdapter new];
        server.openEventHandler(socket);
        
//        CFSocketNativeHandle nativeSocketHandle = *(CFSocketNativeHandle *)data;
//        uint8_t name[SOCK_MAXADDRLEN];
//        socklen_t namelen = sizeof(name);
//        NSData *peer = nil;
//        if (0 == getpeername(nativeSocketHandle, (struct sockaddr *)name, &namelen)) {
//            peer = [NSData dataWithBytes:name length:namelen];
//        }
//        CFReadStreamRef readStream = NULL;
//        CFWriteStreamRef writeStream = NULL;
//        CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeSocketHandle, &readStream, &writeStream);
//        if (readStream && writeStream) {
//            CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
//            CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
//            
//            if(!CFWriteStreamOpen(writeStream) || !CFReadStreamOpen(readStream)) {
//                NSLog(@"Error, streams not open");
//                
//                @throw [NSException exceptionWithName:@"SocketException" reason:@"Cannot open streams." userInfo:nil];
//            }
//            
//            inputStream = (__bridge NSInputStream *)readStream;
//            outputStream = (__bridge NSOutputStream *)writeStream;
//            NSString *response = @"Roger that!";
//            NSData *data = [[NSData alloc] initWithData:[response dataUsingEncoding:NSASCIIStringEncoding]];
//            [outputStream write:[data bytes] maxLength:[data length]];
//            
////            [server handleNewConnectionFromAddress:peer inputStream:(NSInputStream *)readStream outputStream:(NSOutputStream *)writeStream];
//        } else {
//            // on any failure, need to destroy the CFSocketNativeHandle
//            // since we are not going to use it any more
//            close(nativeSocketHandle);
//        }
//        if (readStream) CFRelease(readStream);
//        if (writeStream) CFRelease(writeStream);
    }
}

- (void)write:(NSArray *)dataArray {
    int numberOfBatches = ceil((float)dataArray.count / (float)WRITE_BUFFER_SIZE);
    for (int i = 0; i < (numberOfBatches - 1); i++) {
        [self writeSubarray:dataArray offset:i * WRITE_BUFFER_SIZE length:WRITE_BUFFER_SIZE];
    }
    int lastBatchPosition = (numberOfBatches - 1) * WRITE_BUFFER_SIZE;
    [self writeSubarray:dataArray offset:lastBatchPosition length:(dataArray.count - lastBatchPosition)];
}

- (void)writeSubarray:(NSArray *)dataArray offset:(long)offset length:(long)length {
    uint8_t buf[length];
    for (long i = 0; i < length; i++) {
        unsigned char byte = (unsigned char)[[dataArray objectAtIndex:(offset + i)] integerValue];
        buf[i] = byte;
    }
    NSInteger bytesWritten = [outputStream write:buf maxLength:length];
    if (bytesWritten == -1) {
        @throw [NSException exceptionWithName:@"SocketException" reason:[outputStream.streamError localizedDescription] userInfo:nil];
    }
    if (bytesWritten != length) {
        [self writeSubarray:dataArray offset:(offset + bytesWritten) length:(length - bytesWritten)];
    }
}

- (void)handleNewConnectionFromAddress:(NSData *)addr inputStream:(NSInputStream *)istr outputStream:(NSOutputStream *)ostr {
    // if the delegate implements the delegate method, call it
//    if (delegate && [delegate respondsToSelector:@selector(ServerSocketAdapter:didReceiveConnectionFrom:inputStream:outputStream:)]) {
//        [delegate ServerSocketAdapter:self didReceiveConnectionFromAddress:addr inputStream:istr outputStream:ostr];
//    }
}

- (void)start:(NSString *)iface port:(NSNumber*)port {
    NSError *error;
    NSLog(@"server socket adapter start");
    NSLog(@"iface: %@, port: %@", iface, port);
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
        return;
        
//        return NO;
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
    addr4.sin_addr.s_addr = INADDR_ANY; //htonl(inet_addr([iface cStringUsingEncoding:NSASCIIStringEncoding]));// htonl(INADDR_ANY); //INADDR_ANY = all loca lost addresses (0.0.0.0)
    NSData *address4 = [NSData dataWithBytes:&addr4 length:sizeof(addr4)];
    
    if (kCFSocketSuccess != CFSocketSetAddress(ipv4socket, (CFDataRef)address4)) {
        error = [[NSError alloc] initWithDomain:TCPServerErrorDomain code:kTCPServerCouldNotBindToIPv4Address userInfo:nil];
        if (ipv4socket) CFRelease(ipv4socket);
        if (ipv6socket) CFRelease(ipv6socket);
        ipv4socket = NULL;
        ipv6socket = NULL;
        self.startErrorEventHandler([NSString stringWithFormat:@"%@, %@", error.localizedDescription, error.localizedFailureReason]);
        return;
//        return NO;
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
        return;
//        return NO;
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
        NSString *publishingDomain = domain ? domain : @"";
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
    self.startEventHandler();
//    return YES;
    
}
- (void)stop {
    NSLog(@"server socket adapter stop");
    [netService stop];
//    [netService release];
    netService = nil;
    CFSocketInvalidate(ipv4socket);
    CFSocketInvalidate(ipv6socket);
    CFRelease(ipv4socket);
    CFRelease(ipv6socket);
    ipv4socket = NULL;
    ipv6socket = NULL;
//    self.stopEventHandler(true);
//    return YES;
}


@end
