/**
 * Copyright (c) 2015, Blocshop s.r.o.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms are permitted
 * provided that the above copyright notice and this paragraph are
 * duplicated in all such forms and that any documentation,
 * advertising materials, and other materials related to such
 * distribution and use acknowledge that the software was developed
 * by the Blocshop s.r.o.. The name of the
 * Blocshop s.r.o. may not be used to endorse or promote products derived
 * from this software without specific prior written permission.
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
 */

#import "SocketPlugin.h"
#import "SocketAdapter.h"
#import <cordova/CDV.h>
#import <Foundation/Foundation.h>
#import "ServerSocketAdapter.h"

@implementation SocketPlugin : CDVPlugin

- (void)setCloseEventHandlerWithSocketKey: (NSString *) socketKey andHasErrors:(BOOL) hasErrors {
    NSMutableDictionary *closeDictionaryData = [[NSMutableDictionary alloc] init];
    [closeDictionaryData setObject:@"Close" forKey:@"type"];
    [closeDictionaryData setObject:(hasErrors == TRUE ? @"true": @"false") forKey:@"hasError"];
    [closeDictionaryData setObject:socketKey forKey:@"socketKey"];
    
    [self dispatchEventWithDictionary:closeDictionaryData];
    
    [self removeSocketAdapter:socketKey];
}

-(void)setDataConsumerWithSocketKey: (NSString *) socketKey andDataArray: (NSArray*) dataArray {
    NSMutableDictionary *dataDictionary = [[NSMutableDictionary alloc] init];
    [dataDictionary setObject:@"DataReceived" forKey:@"type"];
    [dataDictionary setObject:dataArray forKey:@"data"];
    [dataDictionary setObject:socketKey forKey:@"socketKey"];
    
    [self dispatchEventWithDictionary:dataDictionary];
}

-(void)setErrorEventHandlerWithSocketKey:(NSString *) socketKey andError: (NSString *) error {
    NSMutableDictionary *errorDictionaryData = [[NSMutableDictionary alloc] init];
    [errorDictionaryData setObject:@"Error" forKey:@"type"];
    [errorDictionaryData setObject:error forKey:@"errorMessage"];
    [errorDictionaryData setObject:socketKey forKey:@"socketKey"];
    
    [self dispatchEventWithDictionary:errorDictionaryData];
}

- (void) open : (CDVInvokedUrlCommand*) command {
    
	NSString *socketKey = [command.arguments objectAtIndex:0];
	NSString *host = [command.arguments objectAtIndex:1];
	NSNumber *port = [command.arguments objectAtIndex:2];
    
    if (socketAdapters == nil) {
		self->socketAdapters = [[NSMutableDictionary alloc] init];
	}
    
	__block SocketAdapter* socketAdapter = [[SocketAdapter alloc] init];
    socketAdapter.openEventHandler = ^ void () {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
        
        [self->socketAdapters setObject:socketAdapter forKey:socketKey];
        
        socketAdapter = nil;
    };
    socketAdapter.openErrorEventHandler = ^ void (NSString *error){
        [self.commandDelegate
         sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error]
         callbackId:command.callbackId];
        
        socketAdapter = nil;
    };
    socketAdapter.errorEventHandler = ^ void (NSString *error){        
        [self setErrorEventHandlerWithSocketKey:socketKey andError:(NSString *) error];
    };
    socketAdapter.dataConsumer = ^ void (NSArray* dataArray) {
        [self setDataConsumerWithSocketKey:socketKey andDataArray:dataArray];
    };
    socketAdapter.closeEventHandler = ^ void (BOOL hasErrors) {
        [self setCloseEventHandlerWithSocketKey:socketKey andHasErrors:hasErrors];
    };
    
    [self.commandDelegate runInBackground:^{
        @try {
            [socketAdapter open:host port:port];
        }
        @catch (NSException *e) {
            [self.commandDelegate
                sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:e.reason]
                callbackId:command.callbackId];
            
            socketAdapter = nil;
        }
    }];
}

- (void) write:(CDVInvokedUrlCommand *) command {
	
    NSString* socketKey = [command.arguments objectAtIndex:0];
    NSArray *data = [command.arguments objectAtIndex:1];
    
    SocketAdapter *socket = [self getSocketAdapter:socketKey];
    
	[self.commandDelegate runInBackground:^{
        @try {
            [socket write:data];
            [self.commandDelegate
             sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK]
             callbackId:command.callbackId];
        }
        @catch (NSException *e) {
            [self.commandDelegate
             sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:e.reason]
             callbackId:command.callbackId];
        }
    }];
}

- (void) shutdownWrite:(CDVInvokedUrlCommand *) command {
    
    NSString* socketKey = [command.arguments objectAtIndex:0];
	
	SocketAdapter *socket = [self getSocketAdapter:socketKey];
    
    [self.commandDelegate runInBackground:^{
        @try {
            [socket shutdownWrite];
            [self.commandDelegate
            sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK]
            callbackId:command.callbackId];
        }
        @catch (NSException *e) {
            [self.commandDelegate
            sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:e.reason]
            callbackId:command.callbackId];
        }
    }];
}

- (void) close:(CDVInvokedUrlCommand *) command {
    
    NSString* socketKey = [command.arguments objectAtIndex:0];
	
	SocketAdapter *socket = [self getSocketAdapter:socketKey];
    
    [self.commandDelegate runInBackground:^{
        @try {
            [socket close];
            [self.commandDelegate
             sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK]
             callbackId:command.callbackId];
        }
        @catch (NSException *e) {
            [self.commandDelegate
             sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:e.reason]
             callbackId:command.callbackId];
        }
    }];
}

- (void) setOptions: (CDVInvokedUrlCommand *) command {
}

- (ServerSocketAdapter*) getServerSocketAdapter: (NSString*) socketKey {
    ServerSocketAdapter* socketAdapter = [self->serverSocketAdapters objectForKey:socketKey];
    if (socketAdapter == nil) {
        NSString *exceptionReason = [NSString stringWithFormat:@"Cannot find socketKey: %@. Connection is probably closed.", socketKey];
        
        @throw [NSException exceptionWithName:@"IllegalArgumentException" reason:exceptionReason userInfo:nil];
    }
    return socketAdapter;
}

- (SocketAdapter*) getSocketAdapter: (NSString*) socketKey {
	SocketAdapter* socketAdapter = [self->socketAdapters objectForKey:socketKey];
	if (socketAdapter == nil) {
		NSString *exceptionReason = [NSString stringWithFormat:@"Cannot find socketKey: %@. Connection is probably closed.", socketKey];
		
		@throw [NSException exceptionWithName:@"IllegalArgumentException" reason:exceptionReason userInfo:nil];
	}
	return socketAdapter;
}

- (void) removeSocketAdapter: (NSString*) socketKey {
    NSLog(@"Removing socket adapter from storage.");
    [self->socketAdapters removeObjectForKey:socketKey];
}

- (void) removeServerSocketAdapter: (NSString*) socketKey {
    NSLog(@"Removing server socket adapter from storage.");
    [self->serverSocketAdapters removeObjectForKey:socketKey];
}

- (BOOL) socketAdapterExists: (NSString*) socketKey {
	SocketAdapter* socketAdapter = [self->socketAdapters objectForKey:socketKey];
	return socketAdapter != nil;
}

- (void) dispatchEventWithDictionary: (NSDictionary*) dictionary {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    NSString *jsToEval = [NSString stringWithFormat : @"cordova.plugins.sockets.Socket.dispatchEvent(%@);", jsonString];
    [self.commandDelegate evalJs:jsToEval];

}

- (void) dispatchServerEventWithDictionary: (NSDictionary*) dictionary {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    NSString *jsToEval = [NSString stringWithFormat : @"cordova.plugins.sockets.ServerSocket.dispatchEvent(%@);", jsonString];
    [self.commandDelegate evalJs:jsToEval];
    
}

-(void)stopAllServers {
    NSLog(@"STOP ALL SERVERS");
    NSArray *keys = self->serverSocketAdapters.allKeys;
    for (int i = 0; i < keys.count; ++i) {
        ServerSocketAdapter *server = self->serverSocketAdapters[keys[i]];
        NSLog(@"stop server key: %@, server.domain: %@, server.port: %@", keys[i], server.iface, server.port);
        [server halt];
    }
}

-(void)restartAllServers {
    NSLog(@"RESTART ALL SERVERS");
    NSArray *keys = self->serverSocketAdapters.allKeys;
    for (int i = 0; i < keys.count; ++i) {
        ServerSocketAdapter *server = self->serverSocketAdapters[keys[i]];
        NSLog(@"restart server key: %@, server.domain: %@, server.port: %@", keys[i], server.iface, server.port);
        [server restartServer];
    }
    
}

-(void) startServer: (CDVInvokedUrlCommand *) command {
    
    if (!notificationsAreAdded) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(stopAllServers)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(restartAllServers)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        notificationsAreAdded = true;
    }
    
    NSLog(@"startServer command");
    NSString *serverSocketKey = [command.arguments objectAtIndex:0];
    NSString *iface = [command.arguments objectAtIndex:1];
    NSNumber *port = [command.arguments objectAtIndex:2];
    
    if (serverSocketAdapters == nil) {
        self->serverSocketAdapters = [[NSMutableDictionary alloc] init];
    }
    
    if (socketAdapters == nil) {
        self->socketAdapters = [[NSMutableDictionary alloc] init];
    }
    
    __block ServerSocketAdapter* serverSocketAdapter = [[ServerSocketAdapter alloc] init];
    serverSocketAdapter.startEventHandler = ^ void () {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
        
        [self->serverSocketAdapters setObject:serverSocketAdapter forKey:serverSocketKey];
        
        serverSocketAdapter = nil;
    };
    serverSocketAdapter.startErrorEventHandler = ^ void (NSString *error){
        [self.commandDelegate
         sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error]
         callbackId:command.callbackId];
        
        serverSocketAdapter = nil;
    };
    serverSocketAdapter.openEventHandler = ^ void (SocketAdapter *socketAdapter){
        NSString *socketKey = [[NSUUID UUID] UUIDString];
        socketAdapter.openEventHandler = ^ void () {
        };
        socketAdapter.closeEventHandler = ^ void (BOOL hasErrors) {
            [self setCloseEventHandlerWithSocketKey:socketKey andHasErrors:hasErrors];
        };
        socketAdapter.dataConsumer = ^ void (NSArray* dataArray) {
            [self setDataConsumerWithSocketKey:socketKey andDataArray:dataArray];
        };
        socketAdapter.errorEventHandler = ^ void (NSString *error){
            [self setErrorEventHandlerWithSocketKey:socketKey andError:(NSString *) error];
        };
        
        self->socketAdapters[socketKey] = socketAdapter;
        
        NSMutableDictionary *dictionaryData = [[NSMutableDictionary alloc] init];
        
        dictionaryData[@"type"] = @"Connected";
        dictionaryData[@"socketKey"] = socketKey;
        dictionaryData[@"serverSocketKey"] = serverSocketKey;
        
        [self dispatchServerEventWithDictionary:dictionaryData];
    };
    
    serverSocketAdapter.stopEventHandler = ^ void (bool hasError){
        NSMutableDictionary *dictionaryData = [[NSMutableDictionary alloc] init];
        
        [self removeServerSocketAdapter:serverSocketKey];
        
        dictionaryData[@"type"] = @"Stopped";
        dictionaryData[@"hasError"] = (hasError == true ? @"true": @"false");
        dictionaryData[@"serverSocketKey"] = serverSocketKey;
        
        [self dispatchServerEventWithDictionary:dictionaryData];
    };

    [self.commandDelegate runInBackground:^{
        @try {
            [serverSocketAdapter start:iface port:port];
        }
        @catch (NSException *e) {
            [self.commandDelegate
             sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:e.reason]
             callbackId:command.callbackId];

            serverSocketAdapter = nil;
        }
    }];
    
    
}
-(void) stopServer: (CDVInvokedUrlCommand *) command {
    NSLog(@"stopServer command");
    NSString *serverSocketKey = [command.arguments objectAtIndex:0];
    NSLog(@"serverSocketKey: %@", serverSocketKey);
    
    ServerSocketAdapter *socketAdapter = [self getServerSocketAdapter:serverSocketKey];
    
    [self.commandDelegate runInBackground:^{
        @try {
            [socketAdapter stop];
            [self.commandDelegate
             sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK]
             callbackId:command.callbackId];
        }
        @catch (NSException *e) {
            [self.commandDelegate
             sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:e.reason]
             callbackId:command.callbackId];
        }
    }];
}

@end
