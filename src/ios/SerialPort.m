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

// If no ACK is used for writing, a "CoreBluetooth[ERROR] XPC connection interrupted, resetting" may occur
// especially for full duplex data

// Configuration of write with or without response.
// -1 Write without response
// 1 Write with response
// n every n write is with response and all other writes are without
#define SP_WRITE_WITH_RESPONSE_CNT (-1)

// Delay in seconds of write complete when writing without response
#define SP_WRITE_COMPLETE_TIMEOUT (0.0f)

// Max packets the remote device may transmit without getting more credits
#define SP_MAX_CREDITS (10)

#define SP_CURRENT_SERIAL_PORT_VERSION (2)

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
    
    NSUInteger          serialPortVersion;
    
    NSUInteger          nTxCredits;
    NSUInteger          nTxCnt;
    
    NSData              *pendingData;
    BOOL                pendingCredits;
    
    CBService           *service;
    CBCharacteristic    *creditsCharacteristic;
    CBCharacteristic    *fifoCharacteristic;
    
    CBService           *deviceIdService;
    CBCharacteristic    *fwVersionCharacteristic;
    CBCharacteristic    *modelNumberCharacteristic;
    
    NSData *disconnectCredit;
}

@synthesize isOpen;

- (SerialPort*) initWithPeripheral: (CBPeripheral*) periph andDelegate: (id) deleg
{
    unsigned char buf[1] = {SP_MAX_CREDITS};
    
    peripheral = periph;
    delegate = deleg;
    
    serialPortVersion = 0;
    
    dataRxCredits = [NSData dataWithBytes:buf length:1];
    
    unsigned char buf2[1] = {0xFF};
    disconnectCredit = [NSData dataWithBytes:buf2 length:1];
    
    isOpen = FALSE;
    
    state = SP_S_CLOSED;
    stateTx = SP_S_TX_IDLE;
    
    return self;
}

-(NSInteger)getVersionFromString:(NSString*)sVersion
{
    NSArray* arr = [sVersion componentsSeparatedByString: @"."];
    
    NSInteger major = [arr[0] integerValue];
    NSInteger minor = [arr[1] integerValue];
    
    arr = [arr[2] componentsSeparatedByString: @" "];
    
    NSInteger subminor = [arr[0] integerValue];
    
    return ((major << 16) | (minor << 8) | (subminor));
}

-(NSInteger) getSerialPortVersion
{
    NSInteger version = 0;
    
    // Version of different models that implement the current serial port service version
    NSString *sOLS = @"OLS";
    NSInteger vOLS = 0x00010100;
    
    NSString *sOLP = @"OLP";
    NSInteger vOLP = 0x00010200;
    
    NSString *sOBS421 = @"OBS421";
    NSInteger vOBS421 = 0x00050100;
    
    if((modelNumberCharacteristic != nil) && (fwVersionCharacteristic != nil) &&
       (modelNumberCharacteristic.value != nil) && (fwVersionCharacteristic.value != nil))
    {
        NSString* sModel =  [[NSString alloc] initWithBytes:modelNumberCharacteristic.value.bytes length:modelNumberCharacteristic.value.length encoding:NSUTF8StringEncoding];
        
        NSString* sFwVersion =  [[NSString alloc] initWithBytes:fwVersionCharacteristic.value.bytes length:fwVersionCharacteristic.value.length encoding:NSUTF8StringEncoding];
        
        NSInteger fwVersion = [self getVersionFromString:sFwVersion];
                
        if(([sModel rangeOfString:sOBS421].location != NSNotFound) && (fwVersion < vOBS421))
        {
            version = 1;
        }
        else if(([sModel rangeOfString:sOLS].location != NSNotFound) && (fwVersion < vOLS))
        {
            version = 1;
        }
        else if(([sModel rangeOfString:sOLP].location != NSNotFound) && (fwVersion < vOLP))
        {
            version = 1;
        }
        else
        {
            version = SP_CURRENT_SERIAL_PORT_VERSION;
        }
    }

    return version;
}

- (void) initServicesAndCharacteristics
{
    CBService *s;
    CBCharacteristic *c;
    
    service = nil;
    creditsCharacteristic  = nil;
    fifoCharacteristic = nil;
    
    deviceIdService = nil;
    fwVersionCharacteristic = nil;
    modelNumberCharacteristic = nil;
    
    for(int i = 0; (i < peripheral.services.count) && ((service == nil) || (deviceIdService == nil)); i++)
    {
        s = [[peripheral services] objectAtIndex:i];
        
        if((s.UUID.data.length == SERIAL_PORT_SERVICE_UUID_LEN) &&
           (memcmp(s.UUID.data.bytes, serialPortServiceUuid, SERIAL_PORT_SERVICE_UUID_LEN) == 0))
        {
            service = s;
        }
        else if((s.UUID.data.length == SERVICE_UUID_DEFAULT_LEN) &&
                (memcmp(s.UUID.data.bytes, deviceIdServiceUuid, SERVICE_UUID_DEFAULT_LEN) == 0))
        {
            deviceIdService = s;
        }
    }
    
    if(service != nil)
    {
        for(int i = 0; i < service.characteristics.count; i++)
        {
            c = [service.characteristics objectAtIndex:i];
            
            if((c.UUID.data.length == CHARACT_UUID_SERIAL_LEN) &&
               (memcmp(c.UUID.data.bytes, serialPortFifoCharactUuid, CHARACT_UUID_SERIAL_LEN) == 0))
            {
                fifoCharacteristic = c;
            }
            else if((c.UUID.data.length == CHARACT_UUID_SERIAL_LEN) &&
                    (memcmp(c.UUID.data.bytes, creditsCharactUuid, CHARACT_UUID_SERIAL_LEN) == 0))
            {
                creditsCharacteristic = c;
            }
        }
    }
    
    if(deviceIdService != nil)
    {
        for(int i = 0; i < deviceIdService.characteristics.count; i++)
        {
            c = [deviceIdService.characteristics objectAtIndex:i];
            
            if((c.UUID.data.length == CHARACT_UUID_DEFAULT_LEN) &&
               (memcmp(c.UUID.data.bytes, modelNumberCharactUuid, CHARACT_UUID_DEFAULT_LEN) == 0))
            {
                modelNumberCharacteristic = c;
            }
            else if((c.UUID.data.length == CHARACT_UUID_DEFAULT_LEN) &&
                    (memcmp(c.UUID.data.bytes, firmwareRevisionCharactUuid, CHARACT_UUID_DEFAULT_LEN) == 0))
            {
                fwVersionCharacteristic = c;
            }
        }
    }
}

-(void) openSerialPortService
{
    serialPortVersion = [self getSerialPortVersion];
        
    state = SP_S_WAIT_INITIAL_TX_CREDITS;
        
    if(serialPortVersion == 1)
    {
        [peripheral setNotifyValue: TRUE forCharacteristic:fifoCharacteristic];
        [peripheral setNotifyValue: TRUE forCharacteristic:creditsCharacteristic];
    }
    else
    {
        // Current version
            
        [peripheral setNotifyValue: TRUE forCharacteristic:creditsCharacteristic];
        [peripheral setNotifyValue: TRUE forCharacteristic:fifoCharacteristic];
    }
        
    [peripheral writeValue:dataRxCredits forCharacteristic:creditsCharacteristic type:CBCharacteristicWriteWithoutResponse];
}

-(void) discoverServices
{
    NSData *data1 = [NSData dataWithBytes: serialPortServiceUuid length: SERIAL_PORT_SERVICE_UUID_LEN];
    CBUUID *uuid1 = [CBUUID UUIDWithData: data1];
    
    NSData *data2 = [NSData dataWithBytes: deviceIdServiceUuid length: SERVICE_UUID_DEFAULT_LEN];
    CBUUID *uuid2 = [CBUUID UUIDWithData: data2];
    
    NSArray *arr = [NSArray arrayWithObjects:uuid1, uuid2, nil];
        
    [peripheral discoverServices:arr];
}

-(void) discoverCharacteristics
{
    if(deviceIdService != nil)
    {
        modelNumberCharacteristic = nil;
        fwVersionCharacteristic = nil;
        
        NSData *data1 = [NSData dataWithBytes: modelNumberCharactUuid length: SERVICE_UUID_DEFAULT_LEN];
        CBUUID *uuid1 = [CBUUID UUIDWithData: data1];
    
        NSData *data2 = [NSData dataWithBytes: firmwareRevisionCharactUuid length: SERVICE_UUID_DEFAULT_LEN];
        CBUUID *uuid2 = [CBUUID UUIDWithData: data2];
    
        NSArray *arr = [NSArray arrayWithObjects:uuid1, uuid2, nil];
    
        [peripheral discoverCharacteristics:arr forService: deviceIdService];
    }
    
    if(service != nil)
    {
        fifoCharacteristic = nil;
        creditsCharacteristic = nil;
        
        [peripheral discoverCharacteristics:nil forService: service];
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
        
        if((service == nil) || (deviceIdService == nil))
        {
            state = SP_S_WAIT_SERVICE_SEARCH;

            [self discoverServices];
        }
        else if((fifoCharacteristic == nil) ||
                (creditsCharacteristic == nil) ||
                (fwVersionCharacteristic == nil) ||
                (modelNumberCharacteristic == nil))
        {
            state = SP_S_WAIT_CHARACT_SEARCH;
            
            [self discoverCharacteristics];
        }
        else if((fwVersionCharacteristic.value == nil) || (modelNumberCharacteristic.value == nil))
        {
            state = SP_S_WAIT_CHARACT_SEARCH;
            
            [peripheral readValueForCharacteristic: modelNumberCharacteristic];
            [peripheral readValueForCharacteristic: fwVersionCharacteristic];
        }
        else
        {
            [self openSerialPortService];
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
        if(serialPortVersion == 1)
        {
            if(creditsCharacteristic != nil)
                [peripheral setNotifyValue: FALSE forCharacteristic:creditsCharacteristic];
            
            if(fifoCharacteristic != nil)
                [peripheral setNotifyValue: FALSE forCharacteristic:fifoCharacteristic];
        }
        else
        {
            [peripheral writeValue:disconnectCredit forCharacteristic:creditsCharacteristic type:CBCharacteristicWriteWithoutResponse];
        }
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
                nTxCredits--;
                nTxCnt++;
                
                if((nTxCnt < SP_WRITE_WITH_RESPONSE_CNT) || (nTxCnt == -1) || (serialPortVersion == 1))
                {
                    [peripheral writeValue:data forCharacteristic:fifoCharacteristic type:CBCharacteristicWriteWithoutResponse];
                    
                    [self performSelector:@selector(writeCompleteSelector) withObject:nil afterDelay:SP_WRITE_COMPLETE_TIMEOUT];
                }
                else
                {
                    [peripheral writeValue:data forCharacteristic:fifoCharacteristic type:CBCharacteristicWriteWithResponse];
                    
                    nTxCnt = 0;
                    
                    stateTx = SP_S_TX_IN_PROGRESS;
                }
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
    
    for(int i = 0; (i < peripheral.services.count) && ((service == nil) || (deviceIdService == nil)); i++)
    {
        s = [[peripheral services] objectAtIndex:i];
        
        if( (s.UUID.data.length == SERIAL_PORT_SERVICE_UUID_LEN) &&
           (memcmp(s.UUID.data.bytes, serialPortServiceUuid, SERIAL_PORT_SERVICE_UUID_LEN) == 0))
        {
            service = s;
        }
        else if((s.UUID.data.length == SERVICE_UUID_DEFAULT_LEN) &&
                (memcmp(s.UUID.data.bytes, deviceIdServiceUuid, SERVICE_UUID_DEFAULT_LEN) == 0))
        {
            deviceIdService = s;
        }
    }
    
    if((service != nil) && (deviceIdService != nil))
    {
        state = SP_S_WAIT_CHARACT_SEARCH;
        
        [self discoverCharacteristics];
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
    
    NSAssert2(state == SP_S_WAIT_CHARACT_SEARCH, @"%s, %d", __FILE__, __LINE__);
    
    for(int i = 0; i < serv.characteristics.count; i++)
    {
        charact = [serv.characteristics objectAtIndex:i];

        if(serv == service)
        {
            if( (charact.UUID.data.length == CHARACT_UUID_SERIAL_LEN) &&
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
        else if(serv == deviceIdService)
        {
            if((charact.UUID.data.length == SERVICE_UUID_DEFAULT_LEN) &&
               (memcmp(charact.UUID.data.bytes, modelNumberCharactUuid, SERVICE_UUID_DEFAULT_LEN) == 0))
            {
                modelNumberCharacteristic = charact;
                
                [periph readValueForCharacteristic: modelNumberCharacteristic];
            }
            else if( (charact.UUID.data.length == SERVICE_UUID_DEFAULT_LEN) &&
                    (memcmp(charact.UUID.data.bytes, firmwareRevisionCharactUuid, SERVICE_UUID_DEFAULT_LEN) == 0))
            {
                fwVersionCharacteristic = charact;
                
                [periph readValueForCharacteristic: fwVersionCharacteristic];
            }
        }
    }
    
    if((fifoCharacteristic != nil) &&
       (creditsCharacteristic != nil) &&
       ((creditsCharacteristic.properties & CBCharacteristicPropertyNotify) != 0) &&
       (modelNumberCharacteristic != nil) && (modelNumberCharacteristic.value != nil) &&
       (fwVersionCharacteristic != nil) && (fwVersionCharacteristic.value != nil))
    {
        [self openSerialPortService];
    }
}

- (void)peripheral:(CBPeripheral *)periph didUpdateValueForCharacteristic:(CBCharacteristic *)ch error:(NSError *)error
{
    switch (state)
    {
        case SP_S_WAIT_CHARACT_SEARCH:
            if((fifoCharacteristic != nil) &&
               (creditsCharacteristic != nil) &&
               ((creditsCharacteristic.properties & CBCharacteristicPropertyNotify) != 0) &&
               (modelNumberCharacteristic != nil) && (modelNumberCharacteristic.value != nil) &&
               (fwVersionCharacteristic != nil) && (fwVersionCharacteristic.value != nil))
            {
                [self openSerialPortService];
            }
            break;
            
        case SP_S_WAIT_INITIAL_TX_CREDITS:
            if( (ch == creditsCharacteristic) && (ch.value.length == 1))
            {
                unsigned char *p = (unsigned char*)ch.value.bytes;
                
                nTxCredits += (NSUInteger)(p[0]);
                nTxCnt = 0;

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
                    nTxCredits--;
                    
                    nTxCnt++;
                    
                    if((nTxCnt < SP_WRITE_WITH_RESPONSE_CNT) || (nTxCnt == -1) || (serialPortVersion == 1))
                    {
                        [peripheral writeValue:pendingData forCharacteristic:fifoCharacteristic type:CBCharacteristicWriteWithoutResponse];
                        
                        pendingData = nil;

                        [self performSelector:@selector(writeCompleteSelector) withObject:nil afterDelay:SP_WRITE_COMPLETE_TIMEOUT];
                    }
                    else
                    {
                        [peripheral writeValue:pendingData forCharacteristic:fifoCharacteristic type:CBCharacteristicWriteWithResponse];
                        
                        pendingData = nil;
                        
                        nTxCnt = 0;
                        
                        stateTx = SP_S_TX_IN_PROGRESS;
                    }
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

                        if(serialPortVersion == 1)
                        {
                            [peripheral writeValue:dataRxCredits forCharacteristic:creditsCharacteristic type:CBCharacteristicWriteWithoutResponse];
                        }
                        else
                        {
                            [peripheral writeValue:dataRxCredits forCharacteristic:creditsCharacteristic type:CBCharacteristicWriteWithResponse];
                        
                            stateTx = SP_S_TX_IN_PROGRESS;
                        }
                        
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
    {
        NSAssert2(stateTx == SP_S_TX_IN_PROGRESS, @"%s, %d", __FILE__, __LINE__);
        
        stateTx = SP_S_TX_IDLE;
        
        if(pendingCredits == TRUE)
        {
            unsigned char *p = (unsigned char*)dataRxCredits.bytes;
            
            nRxCredits = (NSUInteger)(p[0]);
            
            if(serialPortVersion == 1)
            {
                [peripheral writeValue:dataRxCredits forCharacteristic:creditsCharacteristic type:CBCharacteristicWriteWithoutResponse];
            }
            else
            {
                [peripheral writeValue:dataRxCredits forCharacteristic:creditsCharacteristic type:CBCharacteristicWriteWithResponse];
                
                stateTx = SP_S_TX_IN_PROGRESS;
            }
            
            pendingCredits = FALSE;
        }
        else if( (nTxCredits > 0) && (pendingData != nil))
        {
            nTxCredits--;
            
            nTxCnt++;
            
            if((nTxCnt < SP_WRITE_WITH_RESPONSE_CNT) || (nTxCnt == -1) || (serialPortVersion == 1))
            {
                [peripheral writeValue:pendingData forCharacteristic:fifoCharacteristic type:CBCharacteristicWriteWithoutResponse];
                
                pendingData = nil;
                
                [self performSelector:@selector(writeCompleteSelector) withObject:nil afterDelay:SP_WRITE_COMPLETE_TIMEOUT];
            }
            else
            {
                [peripheral writeValue:pendingData forCharacteristic:fifoCharacteristic type:CBCharacteristicWriteWithResponse];
                
                pendingData = nil;
                nTxCnt = 0;
                
                stateTx = SP_S_TX_IN_PROGRESS;
            }
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
