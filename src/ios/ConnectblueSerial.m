//
//  Main external interface used in plugin
//
#import "ConnectblueSerial.h"
#import <Cordova/CDV.h>
#import "DiscoveredPeripheral.h"

@interface ConnectblueSerial()
- (void) onDidDiscoverPeripheral;
- (void) onData: (NSData*) data;
- (void) disconnectCleanly;
- (DiscoveredPeripheral*) findInDiscoveredPeripheralsByUUID: (NSString*) uuid;
- (double) parseMV: (NSData*) data;
@end

@implementation ConnectblueSerial {
  NSMutableData *dataBuffer;
  CBCentralManager *cbCentralManager;

  NSMutableArray *discoveredPeripherals;
  DiscoveredPeripheral *connectedPeripheral;
  SerialPortController *serialPortController;
  NSString *_initializeCallbackId;
  NSString *_onDataCallbackId;
  NSString *_connectCallbackId;
  NSString *_disconnectCallbackId;
  NSString *_scanCallbackId;
  NSString *_subscribeCallbackId;
}

- (void) pluginInitialize {
  [super pluginInitialize];
  cbCentralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
  dataBuffer = [[NSMutableData alloc] initWithLength: 0];
}

- (void) dealloc {
  [cbCentralManager stopScan];
  cbCentralManager = nil;
}

- (void) onAppTerminate {
  NSLog(@"💋  onAppTerminate! - disconnecting");
  [self disconnectCleanly];
  [super onAppTerminate];
}


//
// Plugin Methods
//

- (void) initialize: (CDVInvokedUrlCommand*) command {
  NSLog(@"💋 🎷  API CALL - initialize");
  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
  [pluginResult setKeepCallbackAsBool:TRUE];
  _initializeCallbackId = [command.callbackId copy];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) scan:(CDVInvokedUrlCommand*) command {
  CDVPluginResult *pluginResult = nil;
  NSLog(@"💋 🎷  API CALL - scan");

  discoveredPeripherals = [[NSMutableArray alloc] init];
  pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
  [pluginResult setKeepCallbackAsBool:TRUE];
  _scanCallbackId = [command.callbackId copy];

  NSDictionary *dictionary = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:YES] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
  [cbCentralManager scanForPeripheralsWithServices:nil options:dictionary];

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) stopScan:(CDVInvokedUrlCommand*) command {
  CDVPluginResult *pluginResult = nil;
  NSLog(@"💋 🎷  API CALL - stopScan");

  [cbCentralManager stopScan];
  pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  _scanCallbackId = nil;
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) connect: (CDVInvokedUrlCommand *) command {
  CDVPluginResult *pluginResult = nil;
  NSLog(@"💋 🎷  API CALL - connect");

  if (connectedPeripheral == nil) {
    NSString* uuid = [command.arguments objectAtIndex:0];
    DiscoveredPeripheral *discoveredPeripheral = [self findInDiscoveredPeripheralsByUUID: uuid];

    if (discoveredPeripheral == nil) {
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"Peripheral not available!"];
    } else {
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
      [pluginResult setKeepCallbackAsBool:TRUE];
      _connectCallbackId = [command.callbackId copy];

      NSDictionary *dictionary = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey];
      [cbCentralManager connectPeripheral:discoveredPeripheral.peripheral options:dictionary];
    }
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"Already connected!"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) disconnect: (CDVInvokedUrlCommand *) command {
  CDVPluginResult *pluginResult = nil;
  NSLog(@"💋 🎷  API CALL - disconnect");

  if (connectedPeripheral == nil) {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"Not Connected or Connecting!"];
  } else {
    if(connectedPeripheral.peripheral.state == CBPeripheralStateDisconnected) {
      connectedPeripheral = nil;
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"Warning: Peripheral was already disconnected!"];
    } else {
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
      [pluginResult setKeepCallbackAsBool:TRUE];
      _disconnectCallbackId = [command.callbackId copy];
      [self disconnectCleanly];
    }
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) write: (CDVInvokedUrlCommand *) command {
  CDVPluginResult *pluginResult = nil;
  NSLog(@"💋 🎷  API CALL - write");

  if (connectedPeripheral != nil) {
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
  NSLog(@"💋 🎷  API CALL - subscribe");

  if (connectedPeripheral == nil) {
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
  NSLog(@"💋 🎷  API CALL - unsubscribe");

  _subscribeCallbackId = nil;
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


//
// Private Methods
//

- (void) onDidDiscoverPeripheral {
  if(_scanCallbackId == nil) { return; }

  DiscoveredPeripheral* discoveredPeripheral;
  NSMutableArray *mappedDiscoveredPeripherals = [[NSMutableArray alloc] init];
  NSDate *cutoffDate = [NSDate dateWithTimeIntervalSinceNow:-5];

  for (int i = 0; i < discoveredPeripherals.count; i++) {
    discoveredPeripheral = [discoveredPeripherals objectAtIndex:i];

    if ([discoveredPeripheral.createdAt timeIntervalSinceDate: cutoffDate] > 0) {
      NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

      [dict setValue: discoveredPeripheral.peripheral.name forKey:@"name"];
      [dict setValue: [discoveredPeripheral uuid] forKey:@"uuid"];
      [dict setValue: [discoveredPeripheral rssi] forKey:@"rssi"];

      [mappedDiscoveredPeripherals addObject:dict];
    }
  }

  CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:mappedDiscoveredPeripherals];
  [pluginResult setKeepCallbackAsBool:TRUE];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:_scanCallbackId];
}

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

- (void) disconnectCleanly {
  if (connectedPeripheral != nil) {
    [serialPortController write: @"X"];
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^{
      [cbCentralManager cancelPeripheralConnection:connectedPeripheral.peripheral];
    });
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

- (DiscoveredPeripheral*) findInDiscoveredPeripheralsByUUID: (NSString*) uuid {
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
  NSLog(@"💋 !!!! didDiscoverPeripheral, name: %@, RSSI: %@", peripheral.name, RSSI);

  DiscoveredPeripheral* discoveredPeripheral = [[DiscoveredPeripheral alloc] initWithPeripheral:peripheral andAdvertisment:advertisementData andRssi:RSSI];

  if([discoveredPeripherals containsObject:discoveredPeripheral]) {
    NSInteger index = [discoveredPeripherals indexOfObject:discoveredPeripheral];
    [discoveredPeripherals replaceObjectAtIndex:index withObject:discoveredPeripheral];
  } else {
    [discoveredPeripherals addObject:discoveredPeripheral];
  }

  [self onDidDiscoverPeripheral];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
  NSLog(@"💋  !!!! didConnectPeripheral");

  NSString *uuid = [DiscoveredPeripheral uuidToString:peripheral.UUID];
  connectedPeripheral = [self findInDiscoveredPeripheralsByUUID:uuid];
  serialPortController = [[SerialPortController alloc] initWithPeripheral: connectedPeripheral andDataReceiverDelegate: self];

  NSMutableDictionary *deviceInfo = [[NSMutableDictionary alloc] init];
  [deviceInfo setValue: connectedPeripheral.peripheral.name forKey:@"name"];
  [deviceInfo setValue: [connectedPeripheral uuid] forKey:@"uuid"];

  CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: deviceInfo];
  [pluginResult setKeepCallbackAsBool:TRUE];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:_connectCallbackId];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
  NSLog(@"💋  !!!! didFailToConnectPeripheral");

  CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: @"Failed to Connect!"];
  [pluginResult setKeepCallbackAsBool:TRUE];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:_connectCallbackId];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
  NSLog(@"💋  !!!! didDisconnectPeripheral");
  connectedPeripheral = nil;
  CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  [pluginResult setKeepCallbackAsBool:TRUE];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:_disconnectCallbackId];
}

- (void) centralManagerDidUpdateState: (CBCentralManager *) central {
  NSLog(@"💋  !!!! centralManagerDidUpdateState called: %ld", central.state);
  CDVPluginResult *pluginResult;
  NSString* status;

  if (central.state == CBCentralManagerStatePoweredOn) {
    status = @"ready";
  } else if (central.state == CBCentralManagerStatePoweredOff) {
    status = @"off";
  } else if (central.state == CBCentralManagerStateResetting) {
    status = @"resetting";
  } else if (central.state == CBCentralManagerStateUnsupported) {
    status = @"unsupported";
  } else if (central.state == CBCentralManagerStateUnauthorized) {
    status = @"unauthorized";
  }

  pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: status];
  [pluginResult setKeepCallbackAsBool:TRUE];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:_initializeCallbackId];
}

@end
