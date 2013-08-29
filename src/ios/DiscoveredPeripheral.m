//
//  DiscoveredPeripheral.m
//  BLEDemo
//
//  Created by Tomas Henriksson on 12/15/11.
//  Copyright (c) 2011 connectBlue. All rights reserved.
//

#import "DiscoveredPeripheral.h"

@implementation DiscoveredPeripheral

@synthesize advertisment;
@synthesize rssi;
@synthesize state;

- (DiscoveredPeripheral*) initWithPeripheral: (CBPeripheral*) newPeripheral andAdvertisment: (NSDictionary*) newAdvertisment andRssi: (NSNumber*) newRssi {
    self.peripheral = newPeripheral;
    self.advertisment = newAdvertisment;
    self.rssi = newRssi;
    self.state = DP_STATE_IDLE;
    return self;
}

- (NSString*) uuid {
  return [DiscoveredPeripheral uuidToString: self.peripheral.UUID];
}

+ (NSString*) uuidToString: (CFUUIDRef) UUID {
  CFStringRef cStr = CFUUIDCreateString(NULL, UUID);
  NSString *str = (__bridge NSString *) cStr;
  return str;
}

- (BOOL) isEqual: (DiscoveredPeripheral*) other {
  return [self.peripheral isEqual: other.peripheral];
}

- (NSUInteger) hash {
  return [self.peripheral hash];
}


@end
