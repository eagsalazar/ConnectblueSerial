//
//  Main external interface used in plugin
//
#import "ConnectblueSerial.h"
#import <Cordova/CDV.h>
#import "DiscoveredPeripheral.h"

@interface ConnectblueSerial()
- (void) onDidDiscoverPeripheral;
- (void) onData: (NSData*) data;
- (void) publishUpdate: (NSMutableArray*) update;
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

  NSString *_updateCallbackId;
  BOOL _publishData;
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
  discoveredPeripherals = [[NSMutableArray alloc] init];
  [pluginResult setKeepCallbackAsBool:TRUE];
  _updateCallbackId = [command.callbackId copy];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) scan:(CDVInvokedUrlCommand*) command {
  NSLog(@"💋 🎷  API CALL - scan");
  NSDictionary *dictionary = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:YES] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
  [cbCentralManager scanForPeripheralsWithServices:nil options:dictionary];
}

- (void) stopScan:(CDVInvokedUrlCommand*) command {
  NSLog(@"💋 🎷  API CALL - stopScan");
  [cbCentralManager stopScan];
}

- (void) connect: (CDVInvokedUrlCommand *) command {
  NSLog(@"💋 🎷  API CALL - connect");

  if (connectedPeripheral == nil) {
    NSString* uuid = [command.arguments objectAtIndex:0];
    DiscoveredPeripheral *discoveredPeripheral = [self findInDiscoveredPeripheralsByUUID: uuid];

    if (discoveredPeripheral != nil) {
      NSDictionary *dictionary = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey];
      [cbCentralManager connectPeripheral:discoveredPeripheral.peripheral options:dictionary];
    }
  }
}

- (void) disconnect: (CDVInvokedUrlCommand *) command {
  NSLog(@"💋 🎷  API CALL - disconnect");
  [self disconnectCleanly];
}

- (void) write: (CDVInvokedUrlCommand *) command {
  NSLog(@"💋 🎷  API CALL - write");

  if (connectedPeripheral != nil) {
    NSString* data = [command.arguments objectAtIndex:0];
    [serialPortController write: data];
  }
}


//
// Private Methods
//

- (void) onDidDiscoverPeripheral {
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

  NSMutableArray *update = [[NSMutableArray alloc] init];
  [update addObject: @"didDiscoverPeripheral"];
  [update addObject:mappedDiscoveredPeripherals];
  [self publishUpdate: update];
}

- (void) onData: (NSData*) data {
  double mV;
  const char *firstChar = (const char *)[dataBuffer bytes];
  const char *firstNewChar = (const char *)[data bytes];
  NSUInteger length;

  if(strstr(firstNewChar,"A") || strstr(firstNewChar,"T")) {
    [dataBuffer setLength: 0];
  }

  [dataBuffer appendData: data];
  length = [dataBuffer length];

  NSMutableArray *update = [[NSMutableArray alloc] init];
  [update addObject: @"onData"];

  if(strstr(firstChar,"A") && length == 6) {
    mV = [self parseMV: dataBuffer];
    [update addObject: @(mV)];
    [dataBuffer setLength: 0];
  } else if (strstr(firstChar,"T") && length == 5) {
    [update addObject: @"T"];
    [dataBuffer setLength: 0];
  } else {
    return;
  }

  [self publishUpdate: update];
}

- (void) publishUpdate: (NSMutableArray*) update {
  CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray: update];
  [pluginResult setKeepCallbackAsBool:TRUE];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:_updateCallbackId];
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

  NSMutableArray *update = [[NSMutableArray alloc] init];
  [update addObject: @"didConnectPeripheral"];
  [update addObject: deviceInfo];
  [self publishUpdate: update];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
  NSLog(@"💋  !!!! didFailToConnectPeripheral");

  NSMutableArray *update = [[NSMutableArray alloc] init];
  [update addObject: @"didFailToConnectPeripheral"];
  [self publishUpdate: update];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
  NSLog(@"💋  !!!! didDisconnectPeripheral");
  connectedPeripheral = nil;

  NSMutableArray *update = [[NSMutableArray alloc] init];
  [update addObject: @"didDisconnectPeripheral"];
  [self publishUpdate: update];
}

- (void) centralManagerDidUpdateState: (CBCentralManager *) central {
  NSLog(@"💋  !!!! centralManagerDidUpdateState called: %d", central.state);
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

  NSMutableArray *update = [[NSMutableArray alloc] init];
  [update addObject: @"centralManagerDidUpdateState"];
  [update addObject: status];
  [self publishUpdate: update];
}

@end
