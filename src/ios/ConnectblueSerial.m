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
- (double) parseMV: (NSData*) data;
@end

@implementation ConnectblueSerial {
  PLUGIN_State state;
  NSMutableData *dataBuffer;
  CBCentralManager *cbCentralManager;
}

- (void) pluginInitialize {
  [super pluginInitialize];
  cbCentralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
  [self setState: IDLE];
  dataBuffer = [[NSMutableData alloc] initWithLength: 0];
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

- (void) getState: (CDVInvokedUrlCommand*) command {
  NSLog(@"API CALL - getState");

  NSString *stateString = [self stateToString: state];
  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: stateString];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) connect: (CDVInvokedUrlCommand *) command {
  CDVPluginResult *pluginResult = nil;

  NSLog(@"API CALL - connect");

  if (state != IDLE) {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"Can't connect unless state = IDLE!"];
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

  NSLog(@"API CALL - disconnect");

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

- (void) scan: (CDVInvokedUrlCommand*) command {
  CDVPluginResult* pluginResult = nil;
  NSLog(@"API CALL - scan");

  if (state != IDLE) {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"Can't scan devices unless state = IDLE!"];
  } else {
    discoveredPeripherals = [[NSMutableArray alloc] init];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [pluginResult setKeepCallbackAsBool:TRUE];
    _scanCallbackId = [command.callbackId copy];
    [self startScan];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) stopScan: (CDVInvokedUrlCommand*) command {
  CDVPluginResult* pluginResult = nil;
  NSLog(@"API CALL - stopScan");

  if (state != SCANNING) {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"Not scanning!"];
  } else {
    [self stopScan];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    _scanCallbackId = nil;
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }
}

- (void) write: (CDVInvokedUrlCommand *) command {
  CDVPluginResult *pluginResult = nil;

  NSLog(@"API CALL - write");

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
  NSLog(@"API CALL - subscribe");

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

    double mV;
    const char *firstChar = (const char *)[dataBuffer bytes];
    const char *firstNewChar = (const char *)[data bytes];
    CDVPluginResult *pluginResult = nil;
    NSUInteger length;

    if(strstr(firstNewChar,"A") || strstr(firstNewChar,"T")) {
      [dataBuffer setLength: 0];
    }

    [dataBuffer appendData: data];
    length = [dataBuffer length];

    NSLog(@"^^^^^ firstChar: %c, length %d", firstChar[0], length);
    NSLog(@"^^^^^ firstNewChar: %c", firstNewChar[0]);

    if(strstr(firstChar,"A") && length == 6) {
      mV = [self parseMV: dataBuffer];
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble: mV];
      [dataBuffer setLength: 0];
    } else if (strstr(firstChar,"T") && length == 5) {
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: @"T"];
      [dataBuffer setLength: 0];
    } else {
      return;
    }

    [pluginResult setKeepCallbackAsBool:TRUE];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_subscribeCallbackId];
  }
}

- (void) onPeripheralsUpdated {
  if(_scanCallbackId != nil) {
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
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_scanCallbackId];
  }
}

- (double) parseMV: (NSData*) data {
  const unsigned char *bytes = [data bytes];
  double mV;

  int32_t copy, shifted, accumulated;

  copy = bytes[2];
  shifted = copy << 24;
  accumulated = shifted;

  copy = bytes[3];
  shifted = copy << 16;
  accumulated += shifted;

  copy = bytes[4];
  shifted = copy << 8;
  accumulated += shifted;

  copy = bytes[5];
  shifted = copy;
  accumulated += shifted;

  accumulated <<= 3;
  accumulated >>= 8;

  mV = (double)accumulated;
  mV *= 2048;
  mV /= 16777216;

  return -mV;
}

- (void) startScan {
  if(state == IDLE) {
    NSDictionary *scanOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];

    NSData *data1 = [NSData dataWithBytes: serialPortServiceUuid length: SERIAL_PORT_SERVICE_UUID_LEN];
    CBUUID *uuid1 = [CBUUID UUIDWithData: data1];
    NSData *data2 = [NSData dataWithBytes: deviceIdServiceUuid length: SERVICE_UUID_DEFAULT_LEN];
    CBUUID *uuid2 = [CBUUID UUIDWithData: data2];
    NSArray *cbuuidArray = [NSArray arrayWithObjects:uuid1, uuid2, nil];

    [cbCentralManager scanForPeripheralsWithServices:cbuuidArray options:scanOptions];
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
      return @"IDLE";
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

  DiscoveredPeripheral* discoveredPeripheral = [[DiscoveredPeripheral alloc] initWithPeripheral:peripheral andAdvertisment:advertisementData andRssi:RSSI];

  if([discoveredPeripherals containsObject:discoveredPeripheral]) {
    NSInteger index = [discoveredPeripherals indexOfObject:discoveredPeripheral];
    [discoveredPeripherals replaceObjectAtIndex:index withObject:discoveredPeripheral];
  } else {
    [cbCentralManager connectPeripheral:peripheral options:nil];
    [discoveredPeripherals addObject:discoveredPeripheral];
  }

  [self onPeripheralsUpdated];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
  NSString *uuid = [DiscoveredPeripheral uuidToString:peripheral.UUID];

  if(state == CONNECTING) {
    [self setState: CONNECTED];
    connectedPeripheral = [self findDiscoveredPeripheralByUUID:uuid];
    connectedPeripheral.state = DP_STATE_CONNECTED;

    serialPortController = [[SerialPortController alloc] initWithPeripheral: connectedPeripheral andDataReceiverDelegate: self];

    NSMutableDictionary *deviceInfo = [[NSMutableDictionary alloc] init];
    [deviceInfo setValue: connectedPeripheral.peripheral.name forKey:@"name"];
    [deviceInfo setValue: [connectedPeripheral uuid] forKey:@"uuid"];

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: deviceInfo];
    [pluginResult setKeepCallbackAsBool:TRUE];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_connectCallbackId];
  } else if(state == SCANNING) {
    NSLog(@"!!!! didConnectPeripheral called when SCANNING (it's all good)");
  } else {
    NSLog(@"!!!! didConnectPeripheral called when not CONNECTING!!!");
  }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
  NSString *uuid = [DiscoveredPeripheral uuidToString:peripheral.UUID];
  DiscoveredPeripheral *disconnectedPeripheral = [self findDiscoveredPeripheralByUUID:uuid];
  disconnectedPeripheral.state = DP_STATE_IDLE;

  if(state == DISCONNECTING) {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [pluginResult setKeepCallbackAsBool:TRUE];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_disconnectCallbackId];
  } else if(state == CONNECTED) {
    NSLog(@"!!!! didDisconnectPeripheral called when CONNECTED!!!");
  } else {
    NSLog(@"!!!! didDisconnectPeripheral called when not CONNECTED or DISCONNECTING!!!");
  }

  [self setState: IDLE];
  connectedPeripheral = nil;
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
