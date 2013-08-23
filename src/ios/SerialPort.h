//
//  SerialPort.h
//  BLEDemo
//
//  Created by Tomas Henriksson on 1/4/12.
//  Copyright (c) 2012 connectBlue. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CBPeripheral.h>
#import "BLEDefinitions.h"

#define SP_MAX_WRITE_SIZE   (20)

typedef enum
{
    SP_EVT_OPEN,
    SP_EVT_CLOSED
    
} SPEvent;

@class SerialPort;

@protocol SerialPortDelegate <NSObject>

- (void) port: (SerialPort*) serialPort event : (SPEvent) ev error: (NSInteger)err;

- (void) writeComplete: (SerialPort*) serialPort withError: (NSInteger)err;

- (void) port: (SerialPort*) serialPort receivedData: (NSData*)data;

@end

@interface SerialPort : NSObject <CBPeripheralDelegate>

@property (nonatomic) BOOL isOpen;
@property (nonatomic, readonly) BOOL isWriting;
@property (nonatomic, readonly) NSString *name;

- (SerialPort*) initWithPeripheral: (CBPeripheral*) peripheral andDelegate: (id) delegate;

- (BOOL) open;
- (void) close;

- (BOOL) write: (NSData*) data;

@end
