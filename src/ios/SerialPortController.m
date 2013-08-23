//
//  SerialPortController.m
//

#import "SerialPortController.h"
#import "ChatMessage.h"
#import "ChatCell.h"
#import "DiscoveredPeripheral.h"
#import "SerialPort.h"
#import <CoreBluetooth/CBPeripheral.h>
#import <Foundation/NSException.h>

typedef enum
{
    CHAT_S_NOT_LOADED,
    CHAT_S_DISAPPEARED,
    CHAT_S_APPEARED_IDLE,
    CHAT_S_APPEARED_WAIT_TX,
    CHAT_S_APPEARED_NO_CONNECT_PERIPH

} CHAT_State;

@implementation SerialPortController
{
    CHAT_State      state;

    NSMutableArray  *chatMessages;
    NSDateFormatter *dateFormatter;

    NSMutableArray  *discoveredPeripherals;
    NSMutableArray  *connectedPeripherals;

    NSMutableArray  *serialPorts;
    SerialPort      *serialPort;

    NSMutableArray  *txQueue;
    ChatMessage     *outstandingMsg;
}
@synthesize messageTextField;

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

    connectedPeripherals = [[NSMutableArray alloc] init];
    serialPorts = [[NSMutableArray alloc] init];
    txQueue =  [[NSMutableArray alloc] init];

    outstandingMsg = nil;

    state = CHAT_S_NOT_LOADED;
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

    NSAssert2(state == CHAT_S_NOT_LOADED, @"%s, %d", __FILE__, __LINE__);

    chatMessages = [[NSMutableArray alloc] init];

    state = CHAT_S_DISAPPEARED;
}

- (void)viewDidUnload
{
    [self setMessageTextField:nil];
    [super viewDidUnload];
    chatMessages = nil;
    connectedPeripherals = nil;
    serialPorts = nil;
    txQueue = nil;

    state = CHAT_S_NOT_LOADED;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    DiscoveredPeripheral* dp;
    CBPeripheral* p;
    SerialPort* s;

    [super viewDidAppear:animated];

    NSAssert2(state == CHAT_S_DISAPPEARED, @"%s, %d", __FILE__, __LINE__);

    messageTextField.delegate = self;

    [chatMessages removeAllObjects];
    [self.tableView reloadData];

    [connectedPeripherals removeAllObjects];

    for(int i = 0; i < discoveredPeripherals.count; i++)
    {
        dp = [discoveredPeripherals objectAtIndex:i];

        if (dp.peripheral.isConnected == TRUE)
        {
            [connectedPeripherals addObject:dp.peripheral];
        }
    }

    [serialPorts removeAllObjects];

    if(connectedPeripherals.count > 0)
    {
        for(int i = 0; i < connectedPeripherals.count; i++)
        {
            p = [connectedPeripherals objectAtIndex:i];

            s = [[SerialPort alloc] initWithPeripheral:p andDelegate: self];

            [serialPorts addObject:s];

            [s open];
        }

        state = CHAT_S_APPEARED_IDLE;
    }
    else
    {
        state = CHAT_S_APPEARED_NO_CONNECT_PERIPH;
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    if(serialPorts.count > 0)
    {
        for(int i = 0; i < serialPorts.count; i++)
        {
            [[serialPorts objectAtIndex:i] close];
        }

        [serialPorts removeAllObjects];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

    state = CHAT_S_DISAPPEARED;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return chatMessages.count;
}

- (NSString*) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *str = nil;

    switch(section)
    {
        case 0:
            if(serialPorts.count > 0)
            {
                str = @"";

                for(int i = 0; i < serialPorts.count; i++)
                {
                    if(i == 0)
                      str = [[serialPorts objectAtIndex:i] name];
                    else
                        str = [[NSString alloc] initWithFormat:@"%@ & %@", str, [[serialPorts objectAtIndex:i] name]];
                }
            }
            else
            {
                str = @"No Connected Peripheral";
            }
            break;

        default:
            break;
    }

    return str;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"ChatCell";

    ChatCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

    // Configure the cell...

    ChatMessage *msg = [chatMessages objectAtIndex:(chatMessages.count - 1 - indexPath.row)];

    cell.labelFrom.text = msg.from;
    cell.labelTime.text = msg.time;
    cell.labelMessage.text = msg.message;

    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    [self.messageTextField resignFirstResponder];
}

- (void) writeFromFifo
{
    SerialPort      *sp;
    NSData          *data;
    unsigned char   buf[SP_MAX_WRITE_SIZE];
    NSUInteger      len;
    NSRange         range;
    BOOL            ok;
    NSInteger       nWrites = 0;

    if( (state == CHAT_S_APPEARED_IDLE) && (txQueue.count > 0))
    {
        outstandingMsg = [txQueue objectAtIndex:0];

        range.location = 0;
        range.length = outstandingMsg.message.length;

        ok = [outstandingMsg.message getBytes:buf maxLength:SP_MAX_WRITE_SIZE usedLength:&len encoding:NSUTF8StringEncoding options:NSStringEncodingConversionAllowLossy range:range remainingRange:&range];

        data = [NSData  dataWithBytes:buf length:len];

        for(int i = 0; i < serialPorts.count; i++)
        {
            sp = [serialPorts objectAtIndex:i];

            if(sp.isOpen == TRUE)
            {
                ok = [sp write:data];

                if(ok == TRUE)
                    nWrites++;
            }
        }

        if(nWrites > 0)
        {
            [txQueue removeObjectAtIndex:0];

            [chatMessages addObject:outstandingMsg];

            state = CHAT_S_APPEARED_WAIT_TX;
        }
    }
}

- (IBAction)sendMessage:(id)sender
{

    // Alloc msg and put it in queue
    if( ((state == CHAT_S_APPEARED_IDLE) || (state == CHAT_S_APPEARED_WAIT_TX)) &&
        (messageTextField.text != nil) && (messageTextField.text.length > 0) &&
        (serialPorts.count > 0))
    {
        ChatMessage* msg = [[ChatMessage alloc] initWithFrom:@"Me" andMessage:messageTextField.text];

        [txQueue addObject:msg];

        [self.messageTextField resignFirstResponder];

        if(state == CHAT_S_APPEARED_IDLE)
        {
            [self writeFromFifo];
        }
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];

    return YES;
}

- (void) port: (SerialPort*) sp event : (SPEvent) ev error: (NSInteger)err
{
    switch(ev)
    {
        case SP_EVT_OPEN:
            [self writeFromFifo];
            break;

        default:
            break;
    }
}

- (void) writeComplete: (SerialPort*) serialPort withError:(NSInteger)err
{
    BOOL        done = TRUE;
    SerialPort  *sp;

    NSAssert2(state == CHAT_S_APPEARED_WAIT_TX, @"%s, %d", __FILE__, __LINE__);

    for(int i = 0; (i < serialPorts.count) && (done == TRUE); i++)
    {
        sp = [serialPorts objectAtIndex:i];

        if(sp.isWriting == TRUE)
        {
            done = FALSE;
        }
    }

    if(done == TRUE)
    {
        outstandingMsg = nil;

        [self.tableView reloadData];

        state = CHAT_S_APPEARED_IDLE;

        [self writeFromFifo];
    }
}

- (void) port: (SerialPort*) sp receivedData: (NSData*)data
{
    NSString *str = [[NSString alloc] initWithBytes:data.bytes length:data.length encoding:NSUTF8StringEncoding];

    ChatMessage* msg = [[ChatMessage alloc] initWithFrom: sp.name andMessage: str];

    [chatMessages addObject:msg];

    [self.tableView reloadData];
}
@end
