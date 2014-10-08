//
//  DiscoveredPeripheral.h
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface DiscoveredPeripheral : NSObject

@property (nonatomic, strong) CBPeripheral* peripheral;
@property (nonatomic, strong) NSDictionary* advertisment;
@property (nonatomic, strong) NSNumber*     rssi;
@property (nonatomic, strong) NSDate*       createdAt;

- (DiscoveredPeripheral*) initWithPeripheral: (CBPeripheral*) peripheral andAdvertisment: (NSDictionary*) advertisment andRssi: (NSNumber*) rssi;
- (NSString*) uuid;
+ (NSString*) uuidToString: (CFUUIDRef) UUID;

@end
