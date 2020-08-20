//==============================================================================
// Hedeby.Net A/S
// (c)Copyright 2016 All Rights Reserved
//------------------------------------------------------------------------------
// file name:       fModbusClient.st
// library:         -
// system:          Simotion
// version:         Simotion Scout V4.4 and newer
// restrictions:    Cyclic task
// requirements:    LCom
// functionality:   
//------------------------------------------------------------------------------
//  change log table:
//  version     date            expert in charge        changes applied
//  01.00.00    2016-03-21      LHH.GAAB                created 
//==============================================================================

INTERFACE
    USELIB LCom;
    
    FUNCTION_BLOCK FBModbusTCPClient;
    
END_INTERFACE

IMPLEMENTATION
    FUNCTION_BLOCK FBFrequenceyGenerator
        VAR_INPUT
            Frequency           : REAL;
        END_VAR
        
        VAR_OUTPUT
            Q                   : BOOL;
            Q_Trig              : BOOL;
            Countdown           : TIME;
        END_VAR

        VAR 
            TOF_on              : TOF;
            TOF_off             : TOF;
            Frequency_mem       : REAL;
            Time_base           : TIME;
            Q_TrigMem           : R_TRIG;
        END_VAR
		
        IF Frequency <= 0.0 THEN // If input is <= 0.0 >> block is off // Wenn Eingang kleiner als 0.0 >> Baustein arbeitet nicht
            Q:= FALSE;
            Countdown:= t#0s;
        ELSE  
            IF Frequency_mem <> Frequency THEN // assign frequency one time   // Frequenz zuweisen
                Time_base:= t#1000s / TRUNC(Frequency*1000); // calculate time  //Zeit berechnen
                Frequency_mem := Frequency;
            END_IF;

            //TOF_off expired >> Start again // TOF_off abgelaufen starte von vorn
            TOF_on(IN:= NOT TOF_off.Q, PT:=Time_base);
            Countdown:= Time_base - TOF_on.ET;

            TOF_off(IN:= TOF_on.Q, PT:=Time_base);

            IF Countdown=t#0s THEN
            Countdown:= Time_base - TOF_off.ET; 
            END_IF;

            Q := TOF_on.Q;                          //assign ouptut // Frequenzausgang setzen
            Q_TrigMem(CLK := Q);
            Q_Trig := Q_TrigMem.Q;
        END_IF;
        
    END_FUNCTION_BLOCK
    
    FUNCTION_BLOCK FBModbusTCPClient
        VAR_INPUT 
            Req                     : BOOL := FALSE;
            Disconnect              : BOOL := FALSE;
            MB_Mode                 : USINT := 1;
            MB_Data_Addr            : UDINT := 40001;
            MB_Data_Len             : UINT := 8;
        END_VAR

        VAR_OUTPUT 
            Done                    : BOOL;
            Busy                    : BOOL;
            Error                   : BOOL;
            Status                  : WORD;
            Connected               : BOOL;
        END_VAR

        VAR_IN_OUT 
            MB_Data_Ptr             : ARRAY[0..4095] OF BYTE;
            Connect                 : sLComParameterType;
        END_VAR

        VAR 
            FBLcom                  : FBLComMachineCom;
            statInitDone            : BOOL;
            Blocked_Proc_Timeout    : TIME := T#3s;
            RCV_Timeout             : TIME := T#10s;
            statState               : INT;
            tempData                : ARRAY[0..4095] OF BYTE;
            statTransactionID       : INT;
            statSavedMBAddr         : UDINT;
            statSavedMBLen          : UINT;
            statSavedMBMode         : USINT;
            statMBFunctionCode      : BYTE;
            statSend                : BOOL;
            statSendLenght          : UDINT;
            TON_BlockedProc         : TON;
            TON_Recive              : TON;
            rcvData                 : ARRAY[0..4095] OF BYTE;
            tempWord                : WORD;
            tempLength              : INT;
            statIndex               : INT;
            aBytes                  : ARRAY[0..7] OF BYTE;
            Index                   : INT;
            boReConnect             : BOOL;
            FBPulse100ms            : FBFrequenceyGenerator;
        END_VAR

        //===================================================================================================================================================
        // change log table:
        // version      date              expert in charge        changes applied
        // 1.00.00      2016.05.10        LHH                     created 
        //===================================================================================================================================================
        //  Function Description:
        //  
        //  
        // ===================================================================================================================================================
        // Modbus Function:
        // ===================================================================================================================================================
        // MB_Mode:          MB_Data_Addr:             MB_Data_Len:                Modbus Function:            Function and data type:
        // ---------------------------------------------------------------------------------------------------------------------------------------------------
        // 0                 40001-49999               1-125 (Words)               03 (16#03)                  Read holding register 0-9998
        // 0                 400001-465535             1-125 (Words)               03 (16#03)                  Read holding register 0-65534
        // 1                 40001-49999               1-125 (Words)               16 (16#10)                  Write multiple holding registers 0-9998
        // 1                 400001-465535             1-125 (Words)               16 (16#10)                  Write multiple holding registers 0-65534
        // ===================================================================================================================================================
        //
        // ===================================================================================================================================================
        // Status Codes
        // ===================================================================================================================================================
        //  - Information:
        // ---------------------------------------------------------------------------------------------------------------------------------------------------
        // 16#0000 Instruction execute without errors
        // 16#0001 Connection established
        // 16#0003 Connection terminated
        // 16#7000 No call active and no connection established
        // 16#7001 Connection establishment triggered
        // 16#7002 Intermediate call. Connection is being established
        // 16#7003 Connection is being terminated
        // 16#7004 Connection established and monitored. No job processing active
        // 16#7005 Data is being send
        // 16#7006 Data is being recived
        // ---------------------------------------------------------------------------------------------------------------------------------------------------
        //  - Errors:
        // ---------------------------------------------------------------------------------------------------------------------------------------------------
        // 16#8381 Function code not supported
        // 16#8383 Error reading or writing data outside the address area of MB_Data_Ptr
        // 16#8386 Received function code does not match the one sent
        // 16#8387 Modbus Server responds with error (Function code 16#90)
        // 16#80B0 Invalid value at remote address
        // 16#80B1 Invalid value at remote port
        // 16#80B2 Invalid value at connection ID
        // 16#80B3 ConnectionID is already used by another instance
        // 16#80B4 Invalid value at local port
        // 16#80B6 Invalid connection type, only TCP is supported
        // 16#80BB Invalid value at ActiveEstablishment. Only active connection
        // 16#80BC Connection lost after establishment 
        // 16#80C8 No response from the server in the defined period
        // 16#8188 The MB_Mode parameter is invalid
        // 16#818A Invalid data length of the MB_Data_Len parameter
        // 16#818C Timeout at Blocked_Proc_Timeout
        // 16#818D The transaction ID does not match the one sent originaly
        // 16#8901 Internal block error
        // ===================================================================================================================================================

        //
        // Variables for internal use
        // 
        Status := 16#7000;
        FBPulse100ms(10.0);

        //
        // Initialize block
        //
        IF NOT statInitDone THEN
          statInitDone                          := TRUE;
          Connect.sCfgConnection.u16LocalPort   := 1024;
          statSend                              := FALSE;
          Status                                := 16#7001;
          RETURN;
        END_IF;

        IF NOT Req THEN
          Done := FALSE;
          Busy := FALSE;
          Error := FALSE;
        END_IF;
        
        IF NOT req AND FBLcom.connected THEN
            statState := 20;
        ELSIF NOT FBLcom.connected THEN
            statState := 0;
        END_IF;
    
        //
        // TCP Connection
        //
        //connection configuration
        //-----------------------------------------------------------
        Connect.sCfgConnection.boWithLComProtocol    := 0;    //0: exchange data in raw format, 1: use LCom header at data transfer
        Connect.sCfgConnection.boAcceptUnknownPartner:= 0;    //1: accept requests from all partners, 0: only specified partner is allowed
        Connect.sCfgConnection.boIsTcpClient         := 1;    //0: passive (server), 1: active connection establishment (client)
        Connect.sCfgConnection.u16ComService         := 1;    //1: TCP/IP, 0: UDP
        Connect.sCfgConnection.u16LifeSignCycle      := 3000;  //life sign cycle time (1..60000ms)
        //sender parameter
        //-----------------------------------------------------------
        Connect.sCfgSender.u8ComMode                 := 3;    //0: inactive, 1: cyclic, 2: on change, 3: once
        Connect.sCfgSender.u8SlidingWindow           := 1;    //max. number of telegrams with summary confirmation (1..10)
        Connect.sCfgSender.u16CycleTime              := 100;  //time interval for cyclic mode (1..60000ms)
        Connect.sCfgSender.u16AckTimeout             := 500;  //time interval in case of missing confirmation (1..60000ms)
        //receiver parameter
        //-----------------------------------------------------------
        Connect.sCfgReceiver.u8ComMode               := 3;    //0: inactive, 1: cyclic, 2: on change, 3: once
        Connect.sCfgReceiver.u8SlidingWindow         := 1;    //max. number of telegrams with summary confirmation (1..10)
        Connect.sCfgReceiver.u16CycleTime            := 100;  //time interval for cyclic mode (1..60000ms)
        Connect.sCfgReceiver.u16AckTimeout           := 500;  //time interval in case of missing confirmation (1..60000ms)
        //time synchronisation parameter
        //-----------------------------------------------------------
        Connect.sCfgTimeSync.boUseReceivedTimeStamps := FALSE;//synchronize local time with received time stamps
        Connect.sCfgTimeSync.u8SendModeTimeSync      := 0;    //0: inactive, 1: cyclic, 2: at time of day
        Connect.sCfgTimeSync.u16TimeSyncCycleTime    := 0;   //time interval for cyclic mode (1..65535 minutes)
        Connect.sCfgTimeSync.todTimeSyncAtTime       := TOD#00:00:00.0; //time synchronization at specified time of day
        //-----------------------------------------------------------
        
        IF NOT Disconnect THEN
          // 16#80B0 Invalid value at remote address
          IF (Connect.sCfgConnection.au8remoteaddress[0] = 0) THEN
            Done := FALSE;
            Busy := FALSE;
            Error := TRUE;
            Status := 16#80B0;
            RETURN;
          END_IF;
          // 16#80B1 Invalid value at remote port
          IF (Connect.sCfgConnection.u16RemotePort = 0) THEN
            Done := FALSE;
            Busy := FALSE;
            Error := TRUE;
            Status := 16#80B1;
            RETURN;
          END_IF;
          // 16#80B4 Invalid value at local port
          IF (Connect.sCfgConnection.u16LocalPort = 0) THEN
            Done := FALSE;
            Busy := FALSE;
            Error := TRUE;
            Status := 16#80B4;
            RETURN;
          END_IF;
        ELSE
            statState := 0;
        END_IF;

        //
        // Modbus Function Statemachine
        // 
        CASE statState OF
          // Wait for connection
          0:
          IF FBLcom.connected THEN
            Status := 16#0001;
            statSend := FALSE;
            
            statState := 20;
          END_IF;
                      
          // Wait for job execution
          20:
            Done := FALSE;
            statSend := FALSE;
            
            Status := 16#7004;
            
            IF Req THEN
              // Save values
              statSavedMBAddr := MB_Data_Addr;
              statSavedMBLen := MB_Data_Len;
              statSavedMBMode := MB_Mode;
              
              Busy := TRUE;
              
              statState := 30;
            END_IF;

          // Check input
          30:
            // Determin function code
            IF (MB_Mode = 0) AND (((MB_Data_Addr > 40000) AND (MB_Data_Addr < 50000)) OR ((MB_Data_Addr > 400000) AND (MB_Data_Addr < 465536))) THEN
              statMBFunctionCode := 16#03;
            ELSIF (MB_Mode = 1) AND (((MB_Data_Addr > 40000) AND (MB_Data_Addr < 50000)) OR ((MB_Data_Addr > 400000) AND (MB_Data_Addr < 465536))) THEN
              statMBFunctionCode := 16#10;
            ELSE
              statMBFunctionCode := 16#00;
              Error := TRUE;
              Status := 16#8381;
              RETURN;
            END_IF;
            
            // ******************* Modbus parameter errors *******************
            // 16#8188 The MB_Mode parameter is invalid
            CASE MB_Mode OF
              0, 1:
                ;
              ELSE
                Error := TRUE;
                Status := 16#8188;
                RETURN;
            END_CASE;
            // 16#818A Invalid data length of the MB_Data_Len parameter
            IF (MB_Data_Len < 1) OR (MB_Data_Len > 125) THEN
              Error := TRUE;
              Status := 16#818A;
              RETURN;
            END_IF;
            // ************************** no errors **************************
            
            statState := 40;
            
          // Send data
          40:
            Status := 16#7005;
            
            // Increment transaction ID for every telegram
            IF (statTransactionID < 1) OR (statTransactionID = 32767) THEN
              statTransactionID := 1;
            ELSE
              statTransactionID := statTransactionID + 1;
            END_IF;
            
            CASE statMBFunctionCode OF
                // Read registers (Function code 03 (16#03))
                16#03:
                // Calculate length
                tempLength := 6;
                
                // ---------------------------------------------------------
                // MBAP Header
                // ---------------------------------------------------------
                // Byte 1+2 : Transaction ID
                aBytes := ANYTYPE_TO_BIGBYTEARRAY(statTransactionID,0);
                tempData[0] := aBytes[0];
                tempData[1] := aBytes[1];
                // Byte 3+4 : Protocol Identifier
                tempData[2] := 0;
                tempData[3] := 0;
                // Byte 5+6 : Length
                aBytes := ANYTYPE_TO_BIGBYTEARRAY(tempLength,0);
                tempData[4] := aBytes[0];
                tempData[5] := aBytes[1];
                // Byte 7 : Unit Identifier
                tempData[6] := 16#00;
                // ---------------------------------------------------------
                // PDU
                // ---------------------------------------------------------
                // Byte 8 : Function Code
                tempData[7] := statMBFunctionCode;
                // Byte 9+10 : Starting Address
                aBytes := ANYTYPE_TO_BIGBYTEARRAY(statSavedMBAddr,0);
                tempData[8] := aBytes[0];
                tempData[9] := aBytes[1];
                // Byte 11+12 : No. of registers
                aBytes := ANYTYPE_TO_BIGBYTEARRAY(statSavedMBLen,0);
                tempData[10] := aBytes[0];
                tempData[11] := aBytes[1];
                // ---------------------------------------------------------
                // Total send length
                // MBAP Header + PDU
                statSendLenght := (12);
                
                // Write holding registers (Function code 16 (16#10))
                16#10:
                // Calculate length
                tempLength := 7 + (UINT_TO_INT(statSavedMBLen) * 2);
                
                // ---------------------------------------------------------
                // MBAP Header
                // ---------------------------------------------------------
                // Byte 1+2 : Transaction ID
                aBytes := ANYTYPE_TO_BIGBYTEARRAY(statTransactionID,0);
                tempData[0] := aBytes[0];
                tempData[1] := aBytes[1];
                // Byte 3+4 : Protocol Identifier
                tempData[2] := 0;
                tempData[3] := 0;
                // Byte 5+6 : Length
                aBytes := ANYTYPE_TO_BIGBYTEARRAY(tempLength,0);
                tempData[4] := aBytes[0];
                tempData[5] := aBytes[1];
                // Byte 7 : Unit Identifier
                tempData[6] := 16#00;
                // ---------------------------------------------------------
                // PDU
                // ---------------------------------------------------------
                // Byte 8 : Function Code
                tempData[7] := statMBFunctionCode;
                // Byte 9+10 : Starting Address
                aBytes := ANYTYPE_TO_BIGBYTEARRAY(statSavedMBAddr,0);
                tempData[8] := aBytes[0];
                tempData[9] := aBytes[1];
                // Byte 11+12 : No. of registers
                aBytes := ANYTYPE_TO_BIGBYTEARRAY(statSavedMBLen,0);
                tempData[10] := aBytes[0];
                tempData[11] := aBytes[1];
                // Byte 13 : Byte count
                tempData[12] := UINT_TO_BYTE(statSavedMBLen * 2);
                // Byte 14-n
                FOR Index := 1 TO UINT_TO_INT(statSavedMBLen * 2) DO
                    tempData[12 + Index] := MB_Data_Ptr[Index-1];
                END_FOR;
                // ---------------------------------------------------------
                // Total send length
                // MBAP Header + PDU + Data
                statSendLenght := (13 + (statSavedMBLen * 2));
            END_CASE;
            
            statSend := TRUE;
            
            statState := 60;
            
          // Receive data
          60:
            Status := 16#7006;
            IF FBLcom.dataReceived THEN
              statState := 70;
            END_IF;
            
          // Evaluate received data
          70:
            // 16#8387 Modbus Server responds with error (Function code 16#90)
            IF (rcvData[7] = 16#90) THEN
              Error := TRUE;
              Status := 16#8387;
              RETURN;
            END_IF;
            
            // 16#8386 Received function code does not match the one sent
            IF (rcvData[7] <> statMBFunctionCode) THEN
              Error := TRUE;
              Status := 16#8386;
              RETURN;
            END_IF;
            // 16#818D The transaction ID does not match the one sent originaly
            aBytes[0] := rcvData[0];
            aBytes[1] := rcvData[1];
            tempWord := BIGBYTEARRAY_TO_ANYTYPE(aBytes,0);
            IF (WORD_TO_INT(tempWord) <> statTransactionID) THEN
              Error := TRUE;
              Status := 16#818D;
              RETURN;
            END_IF;
            
            // Copy data to memory area
            FOR statIndex := 0 TO (BYTE_TO_INT(rcvData[8])-1) DO
              MB_Data_Ptr[statIndex] := rcvData[8 + statIndex];
            END_FOR;
            
            
            Done := TRUE;
            Busy := FALSE;
            Status := 16#0000;
            
            statState := 100;
            
          // Wait for reset of sequence
          100:
            ;
          ELSE
            Error := TRUE;
            Status := 16#8901;
            RETURN;
        END_CASE;

        // Blocked program timer
        // 16#818C Timeout at Blocked_Proc_Timeout
        TON_BlockedProc(IN:=(Req AND (FBLcom.connected) AND NOT ((statState = 20) OR (statState = 100))),
                         PT:=Blocked_Proc_Timeout);
        IF TON_BlockedProc.Q THEN
          Error := TRUE;
          Status := 16#818C;
        END_IF;

        // Recive timeout
        // 16#80C8 No response from the server in the defined period
        TON_Recive(IN:= (Req AND (statState = 60)),
                    PT:=RCV_Timeout);
        IF TON_Recive.Q THEN
          Error := TRUE;
          Status := 16#80C8;
        END_IF;
        
        // Command LCom Call
        FBLCom(enable            := (NOT Disconnect) AND (NOT boReConnect)
              ,communicate       := statSend
              ,sendDataLength    := UDINT_TO_UINT(statSendLenght)
              ,sendData          := tempData
              ,receivedData      := rcvData
              ,parameter         := Connect);
          
        boReConnect := FALSE;
        
        Connected := FBLcom.connected;
    END_FUNCTION_BLOCK
END_IMPLEMENTATION
