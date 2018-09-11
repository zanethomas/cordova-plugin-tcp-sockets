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

- (BOOL) socketAdapterExists: (NSString*) socketKey {
	SocketAdapter* socketAdapter = [self->socketAdapters objectForKey:socketKey];
	return socketAdapter != nil;
}

- (void) dispatchEventWithDictionary: (NSDictionary*) dictionary {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    [self dispatchEvent:jsonString];
}

- (void) dispatchEvent: (NSString *) jsonEventString {
    NSString *jsToEval = [NSString stringWithFormat : @"window.Socket.dispatchEvent(%@);", jsonEventString];
    [self.commandDelegate evalJs:jsToEval];
}

-(void) startServer: (CDVInvokedUrlCommand *) command {
    NSLog(@"startServer command");
    NSString *serverSocketKey = [command.arguments objectAtIndex:0];
    NSString *iface = [command.arguments objectAtIndex:1];
    NSNumber *port = [command.arguments objectAtIndex:2];
    
    if (serverSocketAdapters == nil) {
        self->serverSocketAdapters = [[NSMutableDictionary alloc] init];
    }
    
    __block ServerSocketAdapter* socketAdapter = [[ServerSocketAdapter alloc] init];
    socketAdapter.startEventHandler = ^ void () {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
        
        [self->serverSocketAdapters setObject:socketAdapter forKey:serverSocketKey];
        
        socketAdapter = nil;
    };
    socketAdapter.startErrorEventHandler = ^ void (NSString *error){
        [self.commandDelegate
         sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error]
         callbackId:command.callbackId];
        
        socketAdapter = nil;
    };
    socketAdapter.openEventHandler = ^ void (SocketAdapter *socketAdapter){
        NSString *socketKey = [[NSUUID UUID] UUIDString];
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
        
        [self dispatchEventWithDictionary:dictionaryData];
    };
    
    [self.commandDelegate runInBackground:^{
        @try {
            [socketAdapter start:iface port:port];
        }
        @catch (NSException *e) {
            [self.commandDelegate
             sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:e.reason]
             callbackId:command.callbackId];
            
            socketAdapter = nil;
        }
    }];
    
    
}
-(void) stopServer: (CDVInvokedUrlCommand *) command {
    NSLog(@"stopServer command");
    NSString *serverSocketKey = [command.arguments objectAtIndex:0];
    NSLog(@"serverSocketKey: %@", serverSocketKey);
    
    ServerSocketAdapter *socketAdapter = [self getServerSocketAdapter:serverSocketKey];
    [socketAdapter stop];
    
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
