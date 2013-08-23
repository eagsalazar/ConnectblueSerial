//
//  DiscoveredPeripheral.m
//  BLEDemo
//
//  Created by Tomas Henriksson on 12/15/11.
//  Copyright (c) 2011 connectBlue. All rights reserved.
//

#import "DiscoveredPeripheral.h"

@implementation DiscoveredPeripheral

//@synthesize peripheral;
@synthesize advertisment;
@synthesize rssi;
@synthesize state;

- (DiscoveredPeripheral*) initWithPeripheral: (CBPeripheral*) newPeripheral andAdvertisment: (NSDictionary*) newAdvertisment andRssi: (NSNumber*) newRssi
{
    self.peripheral = newPeripheral;
    self.advertisment = newAdvertisment;
    self.rssi = newRssi;
    self.state = DP_STATE_IDLE;
    
    return self;
}
@end
