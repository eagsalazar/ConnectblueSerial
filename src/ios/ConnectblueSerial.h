//
//  Main external interface used in plugin
//
#import <Cordova/CDV.h>
#import <Cordova/CDVPlugin.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "SerialPortController.h"
#import "DiscoveredPeripheral.h"

@interface ConnectblueSerial : CDVPlugin <CBCentralManagerDelegate, DataReceiverDelegate> {
  NSMutableArray *discoveredPeripherals;
  DiscoveredPeripheral *connectedPeripheral;
  SerialPortController *serialPortController;
  NSString *_onDataCallbackId;
  NSString *_connectCallbackId;
  NSString *_disconnectCallbackId;
  NSString *_listCallbackId;
  NSString *_subscribeCallbackId;
}

- (void) list: (CDVInvokedUrlCommand *) command;
- (void) connect: (CDVInvokedUrlCommand *) command;
- (void) disconnect: (CDVInvokedUrlCommand *) command;
- (void) write: (CDVInvokedUrlCommand *) command;
- (void) subscribe: (CDVInvokedUrlCommand *) command;
- (void) unsubscribe: (CDVInvokedUrlCommand *) command;
@end

