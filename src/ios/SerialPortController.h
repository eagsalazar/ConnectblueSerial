//
//  SerialPortController.h
//

#import <UIKit/UIKit.h>
#import "SerialPort.h"
#import "DiscoveredPeripheral.h"

@interface SerialPortController : NSObject <SerialPortDelegate>
- (SerialPortController*) initWithPeripheral: (DiscoveredPeripheral*) dp andDataReceiverDelegate: (id) del;
- (void) write: (NSString*) message;
@end

@protocol DataReceiverDelegate <NSObject>
- (void) onData: (NSData*) data;
@end
