//
//  SerialPort.m
//  BLEDemo
//
//  Created by Tomas Henriksson on 1/4/12.
//  Copyright (c) 2012 connectBlue. All rights reserved.
//

#import "SerialPort.h"
#import <CoreBluetooth/CBUUID.h>
#import <CoreBluetooth/CBService.h>
#import <CoreBluetooth/CBCharacteristic.h>
#import <Foundation/Foundation.h>

typedef enum
{
    SP_S_CLOSED,
    SP_S_WAIT_SERVICE_SEARCH,
    SP_S_WAIT_CHARACT_SEARCH,
    SP_S_WAIT_INITIAL_TX_CREDITS,
    SP_S_OPEN,

    SP_S_ERROR

} SPState;

typedef enum
{
    SP_S_TX_IDLE,
    SP_S_TX_IN_PROGRESS

} SPStateTx;


@implementation SerialPort
{
    CBPeripheral        *peripheral;
    id                  delegate;

    SPState             state;
    SPStateTx           stateTx;

    NSUInteger          nRxCredits;
    NSData              *dataRxCredits;

    NSUInteger          nTxCredits;

    NSData              *pendingData;
    BOOL                pendingCredits;

    CBService           *service;
    CBCharacteristic    *creditsCharacteristic;
    CBCharacteristic    *fifoCharacteristic;
    CBCharacteristic    *modeCharacteristic;
}

@synthesize isOpen;

- (SerialPort*) initWithPeripheral: (CBPeripheral*) periph andDelegate: (id) deleg
{
    unsigned char buf[1] = {10};
    
    peripheral = periph;
    delegate = deleg;
    
    dataRxCredits = [NSData dataWithBytes:buf length:1];
    
    isOpen = FALSE;
    
    state = SP_S_CLOSED;
    stateTx = SP_S_TX_IDLE;

    return self;
}

- (void) initServicesAndCharacteristics
{
    CBService *s;
    CBCharacteristic *c;
    
    service = nil;
    creditsCharacteristic  = nil;
    modeCharacteristic = nil;
    fifoCharacteristic = nil;
    
    for(int i = 0; (i < peripheral.services.count) && (service == nil); i++)
    {
        s = [[peripheral services] objectAtIndex:i];
        
        if((s.UUID.data.length == SERIAL_PORT_SERVICE_UUID_LEN) &&
           (memcmp(s.UUID.data.bytes, serialPortServiceUuid, SERIAL_PORT_SERVICE_UUID_LEN) == 0))
        {
            service = s;
        }
    }
    
    if(service != nil)
    {
        for(int i = 0; i < service.characteristics.count; i++)
        {
            c = [service.characteristics objectAtIndex:i];
            
            if((c.UUID.data.length == CHARACT_UUID_DEFAULT_LEN) &&
               (memcmp(c.UUID.data.bytes, flowControlModeCharactUuid, CHARACT_UUID_DEFAULT_LEN) == 0))
            {
                modeCharacteristic = c;
            }
            else if((c.UUID.data.length == CHARACT_UUID_DEFAULT_LEN) &&
                    (memcmp(c.UUID.data.bytes, serialPortFifoCharactUuid, CHARACT_UUID_DEFAULT_LEN) == 0))
            {
                fifoCharacteristic = c;
            }
            else if((c.UUID.data.length == CHARACT_UUID_DEFAULT_LEN) &&
                    (memcmp(c.UUID.data.bytes, creditsCharactUuid, CHARACT_UUID_DEFAULT_LEN) == 0))
            {
                creditsCharacteristic = c;
            }
        }
    }
}

- (BOOL) open
{
    BOOL ok = FALSE;
        
    if(peripheral.isConnected == TRUE)
    {
        unsigned char *p = (unsigned char*)dataRxCredits.bytes;

        nRxCredits = (NSUInteger)(p[0]);
        nTxCredits = 0;
        peripheral.delegate = self;
        pendingData = nil;
        pendingCredits = FALSE;
        
        [self initServicesAndCharacteristics];
        
        if(service == nil)
        {
            NSData *data = [NSData dataWithBytes: serialPortServiceUuid length: SERIAL_PORT_SERVICE_UUID_LEN];
            CBUUID *uuid = [CBUUID UUIDWithData: data];
            NSArray *arr = [NSArray arrayWithObject: uuid];
        
            state = SP_S_WAIT_SERVICE_SEARCH;
    
            [peripheral discoverServices:arr];
        }
        else if((modeCharacteristic == nil) ||
                (fifoCharacteristic == nil) ||
                (creditsCharacteristic == nil))
        {
            state = SP_S_WAIT_CHARACT_SEARCH;
            
            [peripheral discoverCharacteristics:nil forService: service];
        }
        else
        {            
            state = SP_S_WAIT_INITIAL_TX_CREDITS;
            
            [peripheral setNotifyValue: TRUE forCharacteristic:creditsCharacteristic];
            [peripheral setNotifyValue: TRUE forCharacteristic:fifoCharacteristic];
            
            [peripheral writeValue:dataRxCredits forCharacteristic:creditsCharacteristic type:CBCharacteristicWriteWithoutResponse];
        }
        
        ok = TRUE;
    }
    
    return ok;
}

- (void) close
{
    isOpen = FALSE;
    state = SP_S_CLOSED;
    
    if(peripheral.isConnected == TRUE)
    {
        if(creditsCharacteristic != nil)
            [peripheral setNotifyValue: FALSE forCharacteristic:creditsCharacteristic];
        
        if(fifoCharacteristic != nil)
            [peripheral setNotifyValue: FALSE forCharacteristic:fifoCharacteristic];
    }
    
    peripheral.delegate = nil;
}

- (NSString*) name
{
    return peripheral.name;
}

- (BOOL) isWriting
{
    BOOL res = FALSE;
    
    if( (state == SP_S_OPEN) && (stateTx != SP_S_TX_IDLE))
    {
        res = TRUE;
    }
    
    return res;
}

- (void)writeCompleteSelector
{
    [delegate writeComplete:self withError:0];
}

- (BOOL) write: (NSData*) data
{
    BOOL ok = FALSE;
    
    NSAssert2((data != nil) && (data.length > 0) , @"%s, %d", __FILE__, __LINE__);

    if((peripheral.isConnected == TRUE) &&
       (state == SP_S_OPEN))
    {

        if(data.length <= SP_MAX_WRITE_SIZE)
        {
            if((nTxCredits > 0) && (stateTx == SP_S_TX_IDLE))
            {
                [peripheral writeValue:data forCharacteristic:fifoCharacteristic type:CBCharacteristicWriteWithResponse];
            
                nTxCredits--;
            
                stateTx = SP_S_TX_IN_PROGRESS;
                
                //[self performSelector:@selector(writeCompleteSelector) withObject:nil afterDelay:0.03];
            }
            else
            {
                NSAssert2(pendingData == nil, @"%s, %d", __FILE__, __LINE__);
                
                pendingData = data;
            }
            
            ok = TRUE;
        }
    }
    
    return ok;
}

- (void)peripheral:(CBPeripheral *)periph didDiscoverServices:(NSError *)error
{
    CBService   *s;
    
    service = nil;
    
    for(int i = 0; (i < peripheral.services.count) && (service == nil); i++)
    {
        s = [[peripheral services] objectAtIndex:i];
        
        if( (s.UUID.data.length == 16) &&
            (memcmp(s.UUID.data.bytes, serialPortServiceUuid, SERIAL_PORT_SERVICE_UUID_LEN) == 0))
        {
            service = s;
        }
    }
    
    if(service != nil)
    {
        state = SP_S_WAIT_CHARACT_SEARCH;
        
        [periph discoverCharacteristics:nil forService: service];
    }
    else
    {
        state = SP_S_ERROR;
        
        [delegate port: self event: SP_EVT_OPEN error: -1];
    }
}

- (void)peripheral:(CBPeripheral *)periph didDiscoverCharacteristicsForService:(CBService *)serv error:(NSError *)error
{
    CBCharacteristic* charact;
    
    modeCharacteristic = nil;
    fifoCharacteristic = nil;
    creditsCharacteristic = nil;
    
    for(int i = 0; i < serv.characteristics.count; i++)
    {
        charact = [serv.characteristics objectAtIndex:i];
        
        if( (charact.UUID.data.length == CHARACT_UUID_SERIAL_LEN) &&
            (memcmp(charact.UUID.data.bytes, flowControlModeCharactUuid, CHARACT_UUID_SERIAL_LEN) == 0))
        {
            modeCharacteristic = charact;
        }
        else if( (charact.UUID.data.length == CHARACT_UUID_SERIAL_LEN) &&
                 (memcmp(charact.UUID.data.bytes, serialPortFifoCharactUuid, CHARACT_UUID_SERIAL_LEN) == 0))
        {
            fifoCharacteristic = charact;
        }
        else if( (charact.UUID.data.length == CHARACT_UUID_SERIAL_LEN) &&
                 (memcmp(charact.UUID.data.bytes, creditsCharactUuid, CHARACT_UUID_SERIAL_LEN) == 0))
        {
            creditsCharacteristic = charact;
        }
    }
        
    if( (modeCharacteristic != nil) &&
        (fifoCharacteristic != nil) &&
        (creditsCharacteristic != nil) &&
        ((creditsCharacteristic.properties & CBCharacteristicPropertyNotify) != 0))
    {
        state = SP_S_WAIT_INITIAL_TX_CREDITS;
        
        [peripheral setNotifyValue: TRUE forCharacteristic:fifoCharacteristic];
        [peripheral setNotifyValue: TRUE forCharacteristic:creditsCharacteristic];
        
        [peripheral writeValue:dataRxCredits forCharacteristic:creditsCharacteristic type:CBCharacteristicWriteWithoutResponse];
    }
    else
    {
        state = SP_S_ERROR;
            
        [delegate port: self event: SP_EVT_OPEN error: -1];            
    }
}

- (void)peripheral:(CBPeripheral *)periph didUpdateValueForCharacteristic:(CBCharacteristic *)ch error:(NSError *)error
{
    switch (state)
    {
        case SP_S_WAIT_INITIAL_TX_CREDITS:
            if( (ch == creditsCharacteristic) && (ch.value.length == 1))
            {
                unsigned char *p = (unsigned char*)ch.value.bytes;
                
                nTxCredits += (NSUInteger)(p[0]);

                isOpen = TRUE;
            
                state = SP_S_OPEN;
                stateTx = SP_S_TX_IDLE;
            
                [delegate port: self event: SP_EVT_OPEN error: 0];
            }
            break;
            
        case SP_S_OPEN:
            if( (ch == creditsCharacteristic) && (ch.value.length == 1))
            {
                unsigned char *p = (unsigned char*)ch.value.bytes;
                
                nTxCredits += (NSUInteger)(p[0]);
                
                if( (nTxCredits > 0) && (stateTx == SP_S_TX_IDLE) && (pendingData != nil))
                {
                    [peripheral writeValue:pendingData forCharacteristic:fifoCharacteristic type:CBCharacteristicWriteWithResponse];
                
                    pendingData = nil;
                    nTxCredits--;
                
                    stateTx = SP_S_TX_IN_PROGRESS;
                    
                    //[self performSelector:@selector(writeCompleteSelector) withObject:nil afterDelay:0.03];
                }
            }
            else if(ch == fifoCharacteristic)
            {
                [delegate port: self receivedData: [fifoCharacteristic value]];
                
                nRxCredits--;
                
                //NSLog(@"Rx: Credits %d", nRxCredits);
                
                //if(FALSE)
                if(nRxCredits == 0)
                {
                    unsigned char *p = (unsigned char*)dataRxCredits.bytes;
                    
                    //if(TRUE)
                    if(stateTx == SP_S_TX_IDLE)
                    {
                        nRxCredits = (NSUInteger)(p[0]);

                        [peripheral writeValue:dataRxCredits forCharacteristic:creditsCharacteristic type:CBCharacteristicWriteWithResponse];
                        
                        stateTx = SP_S_TX_IN_PROGRESS;
                        
                        //NSLog(@"New Credits: Credits %d", nRxCredits);
                    }
                    else
                    {
                        pendingCredits = TRUE;
                    }
                }
            }
            break;
            
        default:
            break;
    }
}

- (void)peripheral:(CBPeripheral *)periph didWriteValueForCharacteristic:(CBCharacteristic *)charact error:(NSError *)err;
{
    if((charact == creditsCharacteristic) || (charact == fifoCharacteristic))
    //if(charact == fifoCharacteristic)
    {
        NSAssert2(stateTx == SP_S_TX_IN_PROGRESS, @"%s, %d", __FILE__, __LINE__);
        
        stateTx = SP_S_TX_IDLE;
        
        if(pendingCredits == TRUE)
        {
            unsigned char *p = (unsigned char*)dataRxCredits.bytes;
            
            nRxCredits = (NSUInteger)(p[0]);
            
            [peripheral writeValue:dataRxCredits forCharacteristic:creditsCharacteristic type:CBCharacteristicWriteWithResponse];
            
            pendingCredits = FALSE;
            
            stateTx = SP_S_TX_IN_PROGRESS;

        }
        else if( (nTxCredits > 0) && (pendingData != nil))
        {
            [peripheral writeValue:pendingData forCharacteristic:fifoCharacteristic type:CBCharacteristicWriteWithResponse];
            
            pendingData = nil;
            nTxCredits--;
            
            stateTx = SP_S_TX_IN_PROGRESS;
        }
        
        if(charact == fifoCharacteristic)
        {
            if(err == nil)
                [delegate writeComplete:self withError:0];
            else
                [delegate writeComplete:self withError:-1];
        }
    }
}


@end
