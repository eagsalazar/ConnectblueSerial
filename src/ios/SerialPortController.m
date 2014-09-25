//
//  SerialPortController.m
//

#import "SerialPortController.h"
#import "DiscoveredPeripheral.h"
#import "SerialPort.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <Foundation/NSException.h>

@implementation SerialPortController {
  DiscoveredPeripheral *connectedPeripheral;
  SerialPort *serialPort;
  NSMutableArray *txQueue;
  id dataReceiverDelegate;
}

- (SerialPortController*) initWithPeripheral: (DiscoveredPeripheral*) dp andDataReceiverDelegate: (id) del {
  connectedPeripheral = dp;
  dataReceiverDelegate = del;
  txQueue =  [[NSMutableArray alloc] init];
  serialPort = [[SerialPort alloc] initWithPeripheral:connectedPeripheral.peripheral andDelegate: self];
  [serialPort open];

  return self;
}

- (void) write: (NSString*) message {
  [txQueue addObject: message];
  [self writeFromFifo];
}

- (void) dealloc {
  [serialPort close];
}

- (void) writeFromFifo {
  NSData *data;
  unsigned char buf[SP_MAX_WRITE_SIZE];
  NSUInteger len;
  NSRange range;

  if(txQueue.count > 0 && serialPort.isOpen == TRUE) {
    NSString* message = [txQueue objectAtIndex:0];
    range.location = 0;
    range.length = message.length;

    [message getBytes:buf maxLength:SP_MAX_WRITE_SIZE usedLength:&len encoding:NSUTF8StringEncoding options:NSStringEncodingConversionAllowLossy range:range remainingRange:&range];
    data = [NSData dataWithBytes:buf length:len];
    NSLog(@"*** WRITE: %@", message);
    [serialPort write: data];

    [txQueue removeObjectAtIndex: 0];
  }
}

//
// SerialPortDelegate methods
//

- (void) port: (SerialPort*) sp event : (SPEvent) ev error: (NSInteger)err {
  if (ev == SP_EVT_OPEN)
    [self writeFromFifo];
}

- (void) writeComplete: (SerialPort*) sp withError:(NSInteger)err {
  if(serialPort.isWriting != TRUE) { [self writeFromFifo]; }
}

- (void) port: (SerialPort*) sp receivedData: (NSData*)data {
  [dataReceiverDelegate onData: data];
}

@end
