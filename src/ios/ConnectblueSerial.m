//
//  Main external interface used in plugin
//
#import "ConnectblueSerial.h"
#import <Cordova/CDV.h>
#import <CoreBluetooth/CBCentralManager.h>
#import <CoreBluetooth/CBPeripheral.h>
#import "DiscoveredPeripheral.h"

typedef enum {
  DEALLOCATED,
  IDLE,
  CONNECTING,
  DISCONNECTING,
  CONNECTED,
  SCANNING
} PLUGIN_State;

@interface ConnectblueSerial()
- (void) startScan;
- (void) stopScan;
- (void) setState: (PLUGIN_State) newState;
- (NSString*) stateToString: (PLUGIN_State) testState;
- (DiscoveredPeripheral*) findDiscoveredPeripheralByUUID: (NSString*) uuid;
@end

@implementation ConnectblueSerial {
  PLUGIN_State state;
  CBCentralManager *cbCentralManager;
}

- (void) pluginInitialize {
  [super pluginInitialize];
  cbCentralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
  [self setState: IDLE];
  discoveredPeripherals = [[NSMutableArray alloc] init];
}

- (void) dealloc {
  [cbCentralManager stopScan];
  cbCentralManager = nil;
  [self setState: DEALLOCATED];
}


//
// Plugin Methods
//

- (void) connect: (CDVInvokedUrlCommand *) command {
  CDVPluginResult *pluginResult = nil;

  if (state != IDLE) {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"Already scanning!"];
  } else {
    [self setState: CONNECTING];

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [pluginResult setKeepCallbackAsBool:TRUE];
    _connectCallbackId = [command.callbackId copy];

    NSString* uuid = [command.arguments objectAtIndex:0];
    DiscoveredPeripheral *discoveredPeripheral = [self findDiscoveredPeripheralByUUID: uuid];

    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey];
    [cbCentralManager connectPeripheral:discoveredPeripheral.peripheral options:dictionary];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) disconnect: (CDVInvokedUrlCommand *) command {
  CDVPluginResult *pluginResult = nil;

  if (state == CONNECTED || state == CONNECTING) {

    if (state == CONNECTED) {
      [self setState: DISCONNECTING];
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
      [pluginResult setKeepCallbackAsBool:TRUE];
      _disconnectCallbackId = [command.callbackId copy];
      connectedPeripheral.state = DP_STATE_DISCONNECTING;
    } else {
      [self setState: IDLE];
      connectedPeripheral.state = DP_STATE_IDLE;
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }

    [cbCentralManager cancelPeripheralConnection:connectedPeripheral.peripheral];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"Not Connected or Connecting!"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) list: (CDVInvokedUrlCommand*) command {
    CDVPluginResult* pluginResult = nil;

  if (state != IDLE) {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"Already scanning!"];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [pluginResult setKeepCallbackAsBool:TRUE];
    _listCallbackId = [command.callbackId copy];

    [self startScan];

    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 5.0 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^{
      NSLog(@"discoveredPeripherals: %@", discoveredPeripherals);
      DiscoveredPeripheral* discoveredPeripheral;

      [self stopScan];

      NSMutableArray *mappedDiscoveredPeripherals = [[NSMutableArray alloc] init];

      for (int i = 0; i < discoveredPeripherals.count; i++) {
        discoveredPeripheral = [discoveredPeripherals objectAtIndex:i];
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

        [dict setValue: discoveredPeripheral.peripheral.name forKey:@"name"];
        [dict setValue: [discoveredPeripheral uuid] forKey:@"uuid"];

        [mappedDiscoveredPeripherals addObject:dict];
      }

      CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:mappedDiscoveredPeripherals];
      [pluginResult setKeepCallbackAsBool:TRUE];
      [self.commandDelegate sendPluginResult:pluginResult callbackId:_listCallbackId];
    });

  }
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) write: (CDVInvokedUrlCommand *) command {
  CDVPluginResult *pluginResult = nil;

  if (state == CONNECTED) {
    NSString* data = [command.arguments objectAtIndex:0];
    [serialPortController write: data];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"Can't write, not CONNECTED!"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) subscribe: (CDVInvokedUrlCommand *) command {
  CDVPluginResult *pluginResult = nil;

  if (state != CONNECTED) {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"Must connect before subscribe!"];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [pluginResult setKeepCallbackAsBool:TRUE];
    _subscribeCallbackId = [command.callbackId copy];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) unsubscribe: (CDVInvokedUrlCommand *) command {
  CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  _subscribeCallbackId = nil;
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

//
// Private Methods
//

- (void) onData: (NSData*) data {
  if(_subscribeCallbackId != nil) {
    // FIXME - right encoding?
    NSString *str = [[NSString alloc] initWithBytes:data.bytes length:data.length encoding:NSUTF8StringEncoding];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: str];
    [pluginResult setKeepCallbackAsBool:TRUE];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_subscribeCallbackId];
  }
}

- (void) startScan {
  if(state == IDLE) {
    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
    [cbCentralManager scanForPeripheralsWithServices:nil options:dictionary];
    [self setState: SCANNING];
  }
}

- (void) stopScan {
  if(state == SCANNING) {
    [cbCentralManager stopScan];
    [self setState: IDLE];
  }
}

- (void) setState: (PLUGIN_State) newState {
  NSString *old = [self stateToString: state];
  NSString *new = [self stateToString: newState];
  NSLog(@"**** state change **** %@ -> %@", old, new);
  state = newState;
}

- (NSString*) stateToString: (PLUGIN_State) testState {
  switch (testState) {
    case DEALLOCATED:
      return @"DEALLOCATED";
    case IDLE:
      return @"DEALLOCATED";
    case CONNECTING:
      return @"CONNECTING";
    case DISCONNECTING:
      return @"DISCONNECTING";
    case CONNECTED:
      return @"CONNECTED";
    case SCANNING:
      return @"SCANNING";
  }
}

- (DiscoveredPeripheral*) findDiscoveredPeripheralByUUID: (NSString*) uuid {
  DiscoveredPeripheral *discoveredPeripheral = nil;
  NSString *discoveredUUID = nil;

  for (int i = 0; i < discoveredPeripherals.count; i++) {
    discoveredPeripheral = [discoveredPeripherals objectAtIndex:i];
    discoveredUUID = [discoveredPeripheral uuid];
    if ([uuid isEqualToString:discoveredUUID]) {
      return discoveredPeripheral;
    }
  }

  return nil;
}

//
// CBCentralManagerDelegate methods
//
- (void) centralManager: (CBCentralManager *) central didDiscoverPeripheral: (CBPeripheral *) peripheral advertisementData: (NSDictionary *) advertisementData RSSI: (NSNumber *) RSSI {

  if((state != SCANNING) || (peripheral == nil)) { return; }

  bool new = TRUE;
  DiscoveredPeripheral* discPeripheral;

  for(int i = 0; (i < discoveredPeripherals.count) && (new == TRUE); i++) {
    discPeripheral = [discoveredPeripherals objectAtIndex:i];
    new = (discPeripheral.peripheral != peripheral);
  }

  if(new == TRUE) {
    discPeripheral = [[DiscoveredPeripheral alloc] initWithPeripheral:peripheral andAdvertisment:advertisementData andRssi:RSSI];
    [discoveredPeripherals addObject:discPeripheral];
  }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
  NSString *uuid = [DiscoveredPeripheral uuidToString:peripheral.UUID];

  if(state == CONNECTING) {
    [self setState: CONNECTED];
    connectedPeripheral = [self findDiscoveredPeripheralByUUID:uuid];
    connectedPeripheral.state = DP_STATE_CONNECTED;

    serialPortController = [[SerialPortController alloc] initWithPeripheral: connectedPeripheral andDataReceiverDelegate: self];

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [pluginResult setKeepCallbackAsBool:TRUE];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_connectCallbackId];
  } else {
    NSLog(@"!!!! didConnectPeripheral called when not CONNECTING!!!");
  }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
  NSString *uuid = [DiscoveredPeripheral uuidToString:peripheral.UUID];
  DiscoveredPeripheral *disconnectedPeripheral = [self findDiscoveredPeripheralByUUID:uuid];
  disconnectedPeripheral.state = DP_STATE_IDLE;
  [self setState: IDLE];
  connectedPeripheral = nil;

  if(state == DISCONNECTING) {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [pluginResult setKeepCallbackAsBool:TRUE];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_disconnectCallbackId];
  } else if(state == CONNECTED) {
    NSLog(@"!!!! didDisconnectPeripheral called when CONNECTED!!!");
  } else {
    NSLog(@"!!!! didDisconnectPeripheral called when not CONNECTED or DISCONNECTING!!!");
  }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
  [self setState: IDLE];
  if(state == CONNECTING) {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"Failed to Connect!"];
    [pluginResult setKeepCallbackAsBool:TRUE];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_connectCallbackId];
  } else {
    NSLog(@"!!!! didFailToConnectPeripheral called when not CONNECTING!!!");
  }
}

- (void) centralManagerDidUpdateState: (CBCentralManager *) central {
  if(central.state == CBCentralManagerStatePoweredOn) {
    [cbCentralManager retrieveConnectedPeripherals];
  }
}

@end
