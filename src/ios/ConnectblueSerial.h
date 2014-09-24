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
  NSString *_onDataCallbackId;
  NSString *_connectCallbackId;
  NSString *_disconnectCallbackId;
  NSString *_scanCallbackId;
  NSString *_subscribeCallbackId;
}

- (void) getState: (CDVInvokedUrlCommand *) command;

// IDLE -> SCANNING
- (void) scan: (CDVInvokedUrlCommand *) command;

// SCANNING -> IDLE
- (void) stopScan: (CDVInvokedUrlCommand *) command;

// IDLE -> CONNECTING -> CONNECTED
- (void) connect: (CDVInvokedUrlCommand *) command;

// CONNECTED -> DISCONNECTING -> IDLE
- (void) disconnect: (CDVInvokedUrlCommand *) command;

// CONNECTED
- (void) write: (CDVInvokedUrlCommand *) command;
- (void) subscribe: (CDVInvokedUrlCommand *) command;
- (void) unsubscribe: (CDVInvokedUrlCommand *) command;
@end

