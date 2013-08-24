//
//  ScanController.m
//

#import "ScanController.h"
#import <CoreBluetooth/CBCentralManager.h>
#import <CoreBluetooth/CBPeripheral.h>
#import "DiscoveredPeripheral.h"

typedef enum
{
    SCAN_S_NOT_LOADED,
    SCAN_S_DISAPPEARED,
    SCAN_S_WILL_DISAPPEAR,
    SCAN_S_APPEARED_IDLE,
    SCAN_S_APPEARED_SCANNING

} SCAN_State;



@implementation ScanController
{
    SCAN_State          state;

    CBCentralManager    *cbCentralManager;
    NSMutableArray      *discoveredPeripherals;
}

- (void) initWithPeripherals: (NSMutableArray*) dp
{
    discoveredPeripherals = dp;

    state = SCAN_S_NOT_LOADED;
}

#pragma mark - View lifecycle

- (id) init
{
    if ( self = [super init] ) {
        cbCentralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];

        //[cbCentralManager retrieveConnectedPeripherals];

        state = SCAN_S_DISAPPEARED;
        
        [self clearPeriph];
        
        state = SCAN_S_APPEARED_IDLE;
    }
    
    return self;
}

- (void)dealloc
{
    [self scan: FALSE];
    
    cbCentralManager = nil;

    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;

    state = SCAN_S_NOT_LOADED;

}

- (void) scan: (bool) enable
{
    if(enable == TRUE)
    {
        NSDictionary *dictionary = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];

        [cbCentralManager scanForPeripheralsWithServices:nil options:dictionary];
    }
    else
    {
        [cbCentralManager stopScan];
    }
}

- (IBAction)startScan:(id)sender {

    if(state == SCAN_S_APPEARED_IDLE)
    {
        [self scan: TRUE];

        state = SCAN_S_APPEARED_SCANNING;
    }
    else if(state == SCAN_S_APPEARED_SCANNING)
    {
        [self scan: FALSE];

        state = SCAN_S_APPEARED_IDLE;
    }
}

- (void) clearPeriphForRow: (NSInteger)row
{
    DiscoveredPeripheral* dp = [discoveredPeripherals objectAtIndex:row];

    //if( (dp.peripheral.isConnected == FALSE) &&
    //   ( (dp.state == DP_STATE_CONNECTED) || (dp.state == DP_STATE_DISCONNECTING)))
    if(dp.peripheral.isConnected == FALSE)
    {
        dp.state = DP_STATE_IDLE;
    }
    else if( (dp.peripheral.isConnected == TRUE) &&
             (dp.state != DP_STATE_CONNECTED))
    {
        dp.state = DP_STATE_CONNECTED;
    }

    if(dp.state == DP_STATE_IDLE)
    {
        [discoveredPeripherals removeObjectAtIndex:row];
    }
}

- (void) clearPeriph
{
    if(self->discoveredPeripherals.count > 0)
    {
        for(int i = discoveredPeripherals.count - 1; i >= 0 ; i--)
        {
            [self clearPeriphForRow:i];
        }
    }
}

- (IBAction)clearPeripherals:(id)sender {

    [self clearPeriph];

    [self scan: FALSE];

    state = SCAN_S_APPEARED_IDLE;
}

- (NSInteger)getRowForPeripheral: (CBPeripheral*)peripheral
{
    NSInteger row = -1;
    DiscoveredPeripheral* p;

    for(int i = 0; (i < discoveredPeripherals.count) && (row == -1); i++)
    {
        p = [discoveredPeripherals objectAtIndex:i];

        if([peripheral isEqual:p.peripheral] == TRUE)
        {
            row = i;
        }
    }

    return row;
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSInteger row = [self getRowForPeripheral:peripheral];

    if(row != -1)
    {
        DiscoveredPeripheral* dp = [discoveredPeripherals objectAtIndex:row];

        dp.state = DP_STATE_CONNECTED;

        //[peripheral discoverServices:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSInteger row = [self getRowForPeripheral:peripheral];

    if(row != -1)
    {
        DiscoveredPeripheral* dp = [discoveredPeripherals objectAtIndex:row];

        dp.state = DP_STATE_IDLE;
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    bool new = TRUE;
    DiscoveredPeripheral* discPeripheral;
    int row = -1;

    if((state == SCAN_S_APPEARED_SCANNING) &&
       (peripheral != nil))
    {
        for(int i = 0; (i < discoveredPeripherals.count) && (new == TRUE); i++)
        {
            discPeripheral = [discoveredPeripherals objectAtIndex:i];

            if(discPeripheral.peripheral == peripheral)
            {
                new = false;
                row = i;

                discPeripheral.peripheral = peripheral;
            }
        }


        if(new == TRUE)
        {
            discPeripheral = [[DiscoveredPeripheral alloc] initWithPeripheral:peripheral andAdvertisment:advertisementData andRssi:RSSI];

            discPeripheral.rssi = RSSI;

            if(peripheral.isConnected == TRUE)
            {
                discPeripheral.state = DP_STATE_CONNECTED;
            }

            [discoveredPeripherals addObject:discPeripheral];

            //NSLog(@"%i: Add %@", ([discoveredPeripherals count] - 1), discPeripheral.peripheral.name);
        }
        else
        {
            discPeripheral.peripheral = peripheral;
            discPeripheral.advertisment = advertisementData;
            discPeripheral.rssi = RSSI;
        }
    }
}


- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSInteger row = [self getRowForPeripheral:peripheral];

    if(row != -1)
    {
        DiscoveredPeripheral* dp = [discoveredPeripherals objectAtIndex:row];

        dp.state = DP_STATE_IDLE;
    }
}

- (void)centralManager:(CBCentralManager *)central didRetrieveConnectedPeripherals:(NSArray *)peripherals
{
    //DiscoveredPeripheral*   discPeripheral;
    CBPeripheral*           peripheral;

    for(int i = 0; i < peripherals.count; i++)
    {
        peripheral = [peripherals objectAtIndex:i];

        NSDictionary *dictionary;

        dictionary = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey];

        [cbCentralManager connectPeripheral:peripheral options:dictionary];

    }
}

- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals
{

}


- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if(central.state == CBCentralManagerStatePoweredOn)
    {
        [cbCentralManager retrieveConnectedPeripherals];
    }
}

@end
