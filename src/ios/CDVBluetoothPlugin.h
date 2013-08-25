//
//  CDVBluetoothPlugin.h
//  Bluetooth
//
//  Created by James Pavlic on 8/24/13.
//
//

#import <Cordova/CDVPlugin.h>

@interface CDVBluetoothPlugin : CDVPlugin

- (void) list:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void) connect:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void) disconnect:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void) write:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void) subscribe:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void) unsubscribe:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void) isConnected:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;

@end
