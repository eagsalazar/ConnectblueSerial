//
//  Main external interface used in plugin
//
#import <Cordova/CDV.h>
#import <Cordova/CDVPlugin.h>
#import <CoreBluetooth/CBCentralManager.h>
#import "BLE.h"
#import "BLEDefinitions.h"

@interface ConnectblueSerial : CDVPlugin <BLEDelegate> {
    BLE *_bleShield;
    NSString* _connectCallbackId;
    NSString* _subscribeCallbackId;
    NSMutableString *_buffer;
    NSString *_delimiter;
}

- (void)connect:(CDVInvokedUrlCommand *)command;
- (void)disconnect:(CDVInvokedUrlCommand *)command;

- (void)subscribe:(CDVInvokedUrlCommand *)command;
- (void)write:(CDVInvokedUrlCommand *)command;
- (void)read:(CDVInvokedUrlCommand *)command;
- (void)readUntil:(CDVInvokedUrlCommand *)command;
- (void)clear:(CDVInvokedUrlCommand *)command;

- (void)list:(CDVInvokedUrlCommand *)command;
- (void)isConnected:(CDVInvokedUrlCommand *)command;
- (void)isAvailable:(CDVInvokedUrlCommand *)command;

@end

