//
//  ScanController.m
//

#import "ScanController.h"
#import "ServiceTableViewController.h"
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

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void) initWithPeripherals: (NSMutableArray*) dp
{
    discoveredPeripherals = dp;

    state = SCAN_S_NOT_LOADED;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];

    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    cbCentralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];

    //[cbCentralManager retrieveConnectedPeripherals];

    state = SCAN_S_DISAPPEARED;
}

- (void)viewDidUnload
{
    //[self setScanButton:nil];
    [super viewDidUnload];

    cbCentralManager = nil;

    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;

    state = SCAN_S_NOT_LOADED;

}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [self clearPeriph];

    state = SCAN_S_APPEARED_IDLE;

    [self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self scan: FALSE];

    [super viewWillDisappear:animated];

    state = SCAN_S_WILL_DISAPPEAR;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

    state = SCAN_S_DISAPPEARED;
}

-(void) enterForeground
{
    [self clearPeriph];

    state = SCAN_S_APPEARED_IDLE;
}

-(void) enterBackground
{
    [self scan: FALSE];

    state = SCAN_S_DISAPPEARED;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    //return (interfaceOrientation == UIInterfaceOrientationPortrait);

    bool result = YES;

    if(interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown)
    {
        result = NO;
    }

    return result;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.

    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    NSInteger nRows;

    switch(section)
    {
        case 0:
            nRows = 1;
            break;

        case 1:
            nRows = discoveredPeripherals.count;
            break;

        default:
            nRows = 0;
            break;
    }

    return nRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"ScanCell";

    ScanCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

    DiscoveredPeripheral* discoveredPeripheral;

    cell.activityView.hidesWhenStopped = TRUE;
    cell.accessoryType = UITableViewCellAccessoryNone;

    switch(indexPath.section)
    {
        case 0:
            cell.labelInfo.text = @"";
            if(state == SCAN_S_APPEARED_SCANNING)
            {
                cell.labelName.text = @"Stop Scan";
                //cell.labelInfo.text = @"Active";

                [cell.activityView startAnimating];
            }
            else
            {
                cell.labelName.text = @"Start Scan";
                //cell.labelInfo.text = @"Inactive";

                [cell.activityView stopAnimating];
            }
            break;

        case 1:
            discoveredPeripheral = [discoveredPeripherals objectAtIndex:indexPath.row];

            cell.labelName.text = discoveredPeripheral.peripheral.name;

            switch(discoveredPeripheral.state)
            {
            case DP_STATE_CONNECTING:
                cell.labelInfo.text = [[NSString alloc] initWithFormat:@"Connecting"];

                [cell.activityView startAnimating];
                cell.accessoryType = UITableViewCellAccessoryNone;
                break;

            case DP_STATE_CONNECTED:
                cell.labelInfo.text = [[NSString alloc] initWithFormat:@"Connected"];

                [cell.activityView stopAnimating];
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
                break;

            default:
                cell.labelInfo.text = [[NSString alloc] initWithFormat:@"RSSI: %@", discoveredPeripheral.rssi];

                [cell.activityView stopAnimating];
                cell.accessoryType = UITableViewCellAccessoryNone;
                break;
            }
            break;
    }

    return cell;
}

- (NSString*) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *str;

    switch(section)
    {
        case 0:
            str = @"Bluetooth Low Energy Scanning";
            break;

        case 1:
            str = @"Found Devices";
            break;

        default:
            break;
    }

    return str;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{

    if(cbCentralManager.state == CBCentralManagerStatePoweredOn)
    {
        ScanCell* cell = (ScanCell*)[tableView cellForRowAtIndexPath:indexPath];

        if(indexPath.section == 0)
        {
            if(state == SCAN_S_APPEARED_SCANNING)
            {
                [self scan: FALSE];

                cell.labelName.text = @"Start Scan";
                //cell.labelInfo.text = @"Inactive";
                [cell.activityView stopAnimating];

                state = SCAN_S_APPEARED_IDLE;
            }
            else if((state == SCAN_S_APPEARED_IDLE) &&
                    (cbCentralManager.state == CBCentralManagerStatePoweredOn))
            {

                [self scan: TRUE];

                cell.labelName.text = @"Stop Scan";
                //cell.labelInfo.text = @"Active";
                [cell.activityView startAnimating];

                state = SCAN_S_APPEARED_SCANNING;
            }
        }
        else
        {
            DiscoveredPeripheral* dp = [discoveredPeripherals objectAtIndex:indexPath.row];

            NSDictionary *dictionary;

            switch (dp.state)
            {
                case DP_STATE_IDLE:

                    cell.labelInfo.text = @"Connecting";

                    [cell.activityView startAnimating];

                    dictionary = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey];

                    [cbCentralManager connectPeripheral:dp.peripheral options:dictionary];

                    dp.state = DP_STATE_CONNECTING;
                    break;

                case DP_STATE_CONNECTED:
                case DP_STATE_CONNECTING:
                    [cbCentralManager cancelPeripheralConnection:dp.peripheral];

                    cell.labelInfo.text = @"";

                    [cell.activityView stopAnimating];
                    cell.accessoryType = UITableViewCellAccessoryNone;

                    dp.state = DP_STATE_IDLE;
                    break;

                default:
                    break;
            }
        }

        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
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

        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:1];

        ScanCell* cell = (ScanCell*)[self.tableView cellForRowAtIndexPath:indexPath];

        [cell.activityView stopAnimating];

        cell.accessoryType = UITableViewCellAccessoryNone;

        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
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

    [self.tableView reloadData];
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
        NSIndexPath* indexPath = [NSIndexPath indexPathForRow:row inSection:1];

        ScanCell* cell = (ScanCell*)[self.tableView cellForRowAtIndexPath:indexPath];

        cell.labelInfo.text = [[NSString alloc] initWithFormat:@"Connected"];

        [cell.activityView stopAnimating];
        cell.accessoryType = UITableViewCellAccessoryCheckmark;

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
        NSIndexPath* indexPath = [NSIndexPath indexPathForRow:row inSection:1];

        ScanCell* cell = (ScanCell*)[self.tableView cellForRowAtIndexPath:indexPath];

        cell.labelInfo.text = [[NSString alloc] initWithFormat:@""];

        cell.accessoryType = UITableViewCellAccessoryNone;
        [cell.activityView stopAnimating];

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

            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[discoveredPeripherals count] - 1 inSection:1];

            [self.tableView insertRowsAtIndexPaths: [NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        else
        {
            discPeripheral.peripheral = peripheral;
            discPeripheral.advertisment = advertisementData;
            discPeripheral.rssi = RSSI;

            NSIndexPath* indexPath = [NSIndexPath indexPathForRow:row inSection:1];

            ScanCell* cell = (ScanCell*)[self.tableView cellForRowAtIndexPath:indexPath];

            //NSLog(@"%i: Update %@", row, discPeripheral.peripheral.name);

            cell.labelName.text = discPeripheral.peripheral.name;
            cell.labelInfo.text = [[NSString alloc] initWithFormat:@"RSSI: %@", discPeripheral.rssi];
        }
    }
}


- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSInteger row = [self getRowForPeripheral:peripheral];

    if(row != -1)
    {
        NSIndexPath* indexPath = [NSIndexPath indexPathForRow:row inSection:1];

        ScanCell* cell = (ScanCell*)[self.tableView cellForRowAtIndexPath:indexPath];

        cell.labelInfo.text = [[NSString alloc] initWithFormat:@""];

        cell.accessoryType = UITableViewCellAccessoryNone;
        [cell.activityView stopAnimating];

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
