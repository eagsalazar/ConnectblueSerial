//
//  SerialPortController.m
//

#import "SerialPortController.h"
#import "ChatMessage.h"
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

- (void) initWithPeripherals: (NSMutableArray*) dp
{
    discoveredPeripherals = dp;

    connectedPeripherals = [[NSMutableArray alloc] init];
    serialPorts = [[NSMutableArray alloc] init];
    txQueue =  [[NSMutableArray alloc] init];

    outstandingMsg = nil;

    state = CHAT_S_NOT_LOADED;
    
    chatMessages = [[NSMutableArray alloc] init];
    
    state = CHAT_S_DISAPPEARED;
    
    CBPeripheral* p;
    SerialPort* s;
    
    [chatMessages removeAllObjects];
    
    [connectedPeripherals removeAllObjects];
    
    for(int i = 0; i < discoveredPeripherals.count; i++)
    {
        DiscoveredPeripheral*dp = [discoveredPeripherals objectAtIndex:i];
        
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

- (void)dealloc
{
    if(serialPorts.count > 0)
    {
        for(int i = 0; i < serialPorts.count; i++)
        {
            [[serialPorts objectAtIndex:i] close];
        }
        
        [serialPorts removeAllObjects];
    }
    
    state = CHAT_S_DISAPPEARED;
    
    chatMessages = nil;
    connectedPeripherals = nil;
    serialPorts = nil;
    txQueue = nil;

    state = CHAT_S_NOT_LOADED;
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

        state = CHAT_S_APPEARED_IDLE;

        [self writeFromFifo];
    }
}

- (void) port: (SerialPort*) sp receivedData: (NSData*)data
{
    NSString *str = [[NSString alloc] initWithBytes:data.bytes length:data.length encoding:NSUTF8StringEncoding];

    ChatMessage* msg = [[ChatMessage alloc] initWithFrom: sp.name andMessage: str];

    [chatMessages addObject:msg];
}
@end
