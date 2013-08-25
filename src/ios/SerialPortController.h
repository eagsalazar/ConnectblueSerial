//
//  SerialPortController.h
//

#import <UIKit/UIKit.h>
#import "SerialPort.h"

@interface SerialPortController : NSObject <SerialPortDelegate>

- (void) initWithPeripherals: (NSMutableArray*) discoveredPeripherals;

- (IBAction)sendMessage:(id)sender;

@end
