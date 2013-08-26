//
//  Main external interface used in plugin
//
#import <Cordova/CDV.h>
#import <Cordova/CDVPlugin.h>
#import <CoreBluetooth/CBCentralManager.h>
#import "SerialPortController.h"
#import "DiscoveredPeripheral.h"

@interface ConnectblueSerial : CDVPlugin <CBCentralManagerDelegate, DataReceiverDelegate> {
  NSMutableArray *discoveredPeripherals;
  DiscoveredPeripheral *connectedPeripheral;
  SerialPortController *serialPortController;
  NSString *_keptCallbackId;
}

- (void) list: (CDVInvokedUrlCommand *) command;
- (void) connect: (CDVInvokedUrlCommand *) command;
- (void) disconnect: (CDVInvokedUrlCommand *) command;
- (void) write: (CDVInvokedUrlCommand *) command;
@end

