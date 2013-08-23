//  ScanController.h
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CBCentralManager.h>

@interface ScanController : <CBCentralManagerDelegate>

- (IBAction)clearPeripherals:(id)sender;

- (void) initWithPeripherals: (NSMutableArray*) discoveredPeripherals;

-(void) enterForeground;
-(void) enterBackground;

// Internal
- (void) clearPeriph;
- (void) clearPeriphForRow: (NSInteger)row;
- (void) scan: (bool)enable;
- (NSInteger)getRowForPeripheral: (CBPeripheral*)peripheral;

@end


