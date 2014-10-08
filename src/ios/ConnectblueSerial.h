//
//  Main external interface used in plugin
//
#import <Cordova/CDV.h>
#import <Cordova/CDVPlugin.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "SerialPortController.h"
#import "DiscoveredPeripheral.h"

@interface ConnectblueSerial : CDVPlugin <CBCentralManagerDelegate, DataReceiverDelegate>
- (void) initialize: (CDVInvokedUrlCommand *) command;
- (void) scan: (CDVInvokedUrlCommand *) command;
- (void) stopScan: (CDVInvokedUrlCommand *) command;
- (void) connect: (CDVInvokedUrlCommand *) command;
- (void) disconnect: (CDVInvokedUrlCommand *) command;
- (void) write: (CDVInvokedUrlCommand *) command;
@end

