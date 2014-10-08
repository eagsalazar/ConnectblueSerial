//
//  DiscoveredPeripheral.m
//

#import "DiscoveredPeripheral.h"
@implementation DiscoveredPeripheral

@synthesize advertisment;
@synthesize rssi;

- (DiscoveredPeripheral*) initWithPeripheral: (CBPeripheral*) newPeripheral andAdvertisment: (NSDictionary*) newAdvertisment andRssi: (NSNumber*) newRssi {
    self.peripheral = newPeripheral;
    self.advertisment = newAdvertisment;
    self.rssi = newRssi;
    self.createdAt = [NSDate date];

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
