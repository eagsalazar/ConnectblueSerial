//
//  DiscoveredPeripheral.h
//  BLEDemo
//
//  Created by Tomas Henriksson on 12/15/11.
//  Copyright (c) 2011 connectBlue. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CBCentralManager.h>

enum DiscoveredPeripheralState
{
    DP_STATE_IDLE = 1,
    DP_STATE_CONNECTING = 2,
    DP_STATE_CONNECTED = 3,
    DP_STATE_DISCONNECTING = 4
};

@interface DiscoveredPeripheral : NSObject

@property (nonatomic, strong) CBPeripheral* peripheral;
@property (nonatomic, strong) NSDictionary* advertisment;
@property (nonatomic, strong) NSNumber*     rssi;
@property enum DiscoveredPeripheralState    state;

- (DiscoveredPeripheral*) initWithPeripheral: (CBPeripheral*) peripheral andAdvertisment: (NSDictionary*) advertisment andRssi: (NSNumber*) rssi;
           
@end
