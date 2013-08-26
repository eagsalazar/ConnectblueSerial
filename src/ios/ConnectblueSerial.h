//
//  Main external interface used in plugin
//
#import <Cordova/CDV.h>
#import <Cordova/CDVPlugin.h>
#import <CoreBluetooth/CBCentralManager.h>
#import "DiscoveredPeripheral.h"

@interface ConnectblueSerial : CDVPlugin <CBCentralManagerDelegate> {
  NSMutableArray *discoveredPeripherals;
  DiscoveredPeripheral *connectedPeripheral;
  NSString *_keptCallbackId;
}

- (void) connect: (CDVInvokedUrlCommand *) command;
- (void) disconnect: (CDVInvokedUrlCommand *) command;
- (void) list: (CDVInvokedUrlCommand *) command;
@end

