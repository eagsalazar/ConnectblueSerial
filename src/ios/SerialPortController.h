//
//  SerialPortController.h
//

#import <UIKit/UIKit.h>
#import "SerialPort.h"

@interface SerialPortController : <SerialPortDelegate>

@property (strong, nonatomic) IBOutlet UITextField *messageTextField;

- (void) initWithPeripherals: (NSMutableArray*) discoveredPeripherals;

- (IBAction)sendMessage:(id)sender;

@end
