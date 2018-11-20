unit KerbalSpace.Model;

interface

uses
  System.Classes, System.SysUtils,
  SocketClient,
  kRPC_DataBuffer, kRPC_Types,
  KerbalSpaceControls;

type
  TKSPControlContext = record
    VesselID, VesselControlID: UInt64;

    procedure Initialize;
    function IsValid: boolean;
  end;

  TKSPVesselID = UInt64;
  TKSPVesselControlID = UInt64;

  TKerbalSpaceControl = class
    private
      FControlContext: TKSPControlContext;
      FOnConnected, FOnDisconnected: TNotifyEvent;
      FIsConnectedToServer: boolean;
      FMessageDataBuffer: TkRPC_DataBuffer;
      FSocketMgr: TClientSocketMgr;

      function DoStandardRequest(
            const Request: TkrpcMsg_Request;
            out Response: TkrpcMsg_Response): boolean;

      function GetActiveVesselID: TKSPVesselID;

      function GetVesselControlID(VesselID: TKSPVesselID): TKSPVesselControlID;

      function GetControlContext: TKSPControlContext;

      function GetIsConnected: boolean;

      function GetServerVersion: string;

      procedure OnSocketConnect(Sender: TObject);

      procedure OnSocketData(const Data: TBytes);

      procedure OnSocketDisconnect(Sender: TObject);


    public
      constructor Create;

      procedure CloseConnection;

      function DoControl(const AControl: TKSPControl;
            const Value: string): boolean;

      destructor Destroy; override;

      function OpenConnection(
            const Host: string;
            const Port: integer;
            const ClientID: string;
            const Timeout: integer): boolean;

      function UpdateControlContext: boolean;

      property ControlContext: TKSPControlContext read FControlContext;

      property IsConnected: boolean read GetIsConnected;

      property OnConnected: TNotifyEvent read FOnConnected write FOnConnected;

      property OnDisconnected: TNotifyEvent read FOnDisconnected write FOnDisconnected;

      property ServerVersion: string read GetServerVersion;
  end;

implementation

uses
  TimeoutMgr,
  kRPC_Protocol;

const
  INVALID_ID = MaxLongInt;
  MSG_TIMEOUT = 5000; //>>>testing<<<


{ TKerbalSpaceControl }


procedure TKerbalSpaceControl.CloseConnection;
begin
  FSocketMgr.CloseConnection(True);
end;


constructor TKerbalSpaceControl.Create;
begin
  // invalidate control context
  FControlContext.Initialize;

  // set up socket connection manager
  FSocketMgr := TClientSocketMgr.Create;
  FSocketMgr.OnConnected := OnSocketConnect;
  FSocketMgr.OnDisconnected := OnSocketDisconnect;
  FSocketMgr.OnDataReceived := OnSocketData;

  FMessageDataBuffer := TkRPC_DataBuffer.Create;
end;


destructor TKerbalSpaceControl.Destroy;
begin
  FreeAndNil(FSocketMgr);
  FreeAndNil(FMessageDataBuffer);
  inherited;
end;


function TKerbalSpaceControl.DoControl(const AControl: TKSPControl;
    const Value: string): boolean;
var
  cteControl: TKSPControlTableEntry;
  msgCall: TkrpcMsg_ProcedureCall;
  msgArg: TkrpcMsg_Argument;
  msgRequest: TkrpcMsg_Request;
  msgResponse: TkrpcMsg_Response;
begin
  Result := False;

  // a control requires a valid vessel and control id, and a connection
  if not FControlContext.IsValid or not IsConnected then
    exit;

  cteControl := KSPCONTROL_TABLE[AControl];

  case AControl of
    kcStaging:
    begin
      msgCall.Initialize;
      msgCall.service_name := cteControl.ServiceName;
      msgCall.procedure_name := cteControl.ProcedureName;

      msgArg.Initialize;
      KRPC_EncodeVarint(FControlContext.VesselControlID, msgArg.value);
      SetLength(msgCall.arguments, 1);
      msgCall.arguments[0] := msgArg;

      msgRequest.Initialize;
      SetLength(msgRequest.calls, 1);
      msgRequest.calls[0] := msgCall;

      Result := DoStandardRequest(msgRequest, msgResponse);
    end;

    kcThrottle: ;
    kcToggleSAS:  ;
  end;
end;


function TKerbalSpaceControl.DoStandardRequest(const Request: TkrpcMsg_Request;
      out Response: TkrpcMsg_Response): boolean;
var
  bytesMsg: TBytes;
  encodMsg: TKRPC_Encoder<TkrpcMsg_Request>;
  decodMsg: TKRPC_Decoder<TkrpcMsg_Response>;
  tmTimeout: TTimeoutCount;
begin
  Result := False;
  Response.Initialize;

  if not IsConnected then
    exit;

  // flush buffer, send request
  FMessageDataBuffer.ClearBuffer;
  encodMsg.EncodeData(Request, True, bytesMsg);
  FSocketMgr.Write(bytesMsg);

  // wait for response or timeout
  tmTimeout.Init(MSG_TIMEOUT);
  while not tmTimeout.IsExpired do
  begin
    if FSocketMgr.Read(bytesMsg) > 0 then
    begin
      FMessageDataBuffer.AddDataToBuffer(bytesMsg);

      // check if an entire message in is the buffer yet
      if FMessageDataBuffer.IsMessageInBuffer then
      begin
        // got response, so check it
        if FMessageDataBuffer.RetreiveNextMessageFromBuffer(bytesMsg) then
        begin
          decodMsg.DecodeData(bytesMsg, False, Response);
          Result := True;
          break;
        end;
      end;

      Sleep(50);
    end; // if..
  end; // while..
end;


function TKerbalSpaceControl.GetActiveVesselID: TKSPVesselID;
var
  msgRequest: TkrpcMsg_Request;
  msgProcedure: TkrpcMsg_ProcedureCall;
  msgResponse: TkrpcMsg_Response;
begin
  Result := INVALID_ID;

  msgProcedure.Initialize;
  msgProcedure.service_name := sSERVICENAME_SPACECENTER;
  msgProcedure.procedure_name := 'get_ActiveVessel';

  msgRequest.Initialize;
  SetLength(msgRequest.calls, 1);
  msgRequest.calls[0] := msgProcedure;

  if DoStandardRequest(msgRequest, msgResponse) then
  begin
    if Length(msgResponse.results) > 0 then
    begin
      Result := KRPC_DecodeVarint(msgResponse.results[0].value);
    end;
  end;
end;


function TKerbalSpaceControl.GetVesselControlID(VesselID: TKSPVesselID): TKSPVesselControlID;
var
  msgRequest: TkrpcMsg_Request;
  msgCall: TkrpcMsg_ProcedureCall;
  msgArg: TkrpcMsg_Argument;
  msgResponse: TkrpcMsg_Response;
begin
  Result := INVALID_ID;

  msgCall.Initialize;
  msgCall.service_name := sSERVICENAME_SPACECENTER;
  msgCall.procedure_name := 'Vessel_get_Control';

  msgArg.Initialize;
  KRPC_EncodeVarint(VesselID, msgArg.value);
  SetLength(msgCall.arguments, 1);
  msgCall.arguments[0] := msgArg;

  msgRequest.Initialize;
  SetLength(msgRequest.calls, 1);
  msgRequest.calls[0] := msgCall;

  if DoStandardRequest(msgRequest, msgResponse) then
  begin
    if Length(msgResponse.results) > 0 then
    begin
      Result := KRPC_DecodeVarint(msgResponse.results[0].value);
    end;
  end;
end;


function TKerbalSpaceControl.GetControlContext: TKSPControlContext;
begin
  Result.Initialize;

  Result.VesselID := GetActiveVesselID;
  if Result.VesselID <> INVALID_ID then
    Result.VesselControlID := GetVesselControlID(Result.VesselID);
end;


function TKerbalSpaceControl.GetIsConnected: boolean;
begin
  Result := Assigned(FSocketMgr) and FSocketMgr.IsConnected and FIsConnectedToServer;
end;


function TKerbalSpaceControl.GetServerVersion: string;
begin

end;


procedure TKerbalSpaceControl.OnSocketConnect(Sender: TObject);
begin
  // enable getting data in backgnd -- OnSocketData event will be fired when data is available
//  FSocketMgr.StartCheckingForData;  >>>caused deadlocks<<<
  if Assigned(FOnConnected) then
    FOnConnected(Sender);
end;


procedure TKerbalSpaceControl.OnSocketData(const Data: TBytes);
begin
  { TODO : lock the message data buffer }
  FMessageDataBuffer.AddDataToBuffer(Data);
end;


procedure TKerbalSpaceControl.OnSocketDisconnect(Sender: TObject);
begin
  FIsConnectedToServer := False;

  if Assigned(FOnDisconnected) then
    FOnDisconnected(Sender);
end;


function TKerbalSpaceControl.OpenConnection(
      const Host: string;
      const Port: integer;
      const ClientID: string;
      const Timeout: integer): boolean;
var
  bytesMsg: TBytes;
  krpcEncoder: TKRPC_Encoder<TkrpcMsg_ConnectionRequest>;
  krpcDecoder: TKRPC_Decoder<TkrpcMsg_ConnectionResponse>;
  msgConnect: TkrpcMsg_ConnectionRequest;
  msgResponse: TkrpcMsg_ConnectionResponse;
  tmTimeout: TTimeoutCount;
begin
  FIsConnectedToServer := False;

  if FSocketMgr.IsConnected then
    FSocketMgr.CloseConnection;

  // set socket connection parameters
  FSocketMgr.Host := Host;
  FSocketMgr.Port := Port;
  FSocketMgr.OnConnected := OnSocketConnect;
  FSocketMgr.OnDisconnected := OnSocketDisconnect;
  FSocketMgr.OnDataReceived := OnSocketData;

  // try to open the socket connection
  FSocketMgr.OpenConnection;
  if not FSocketMgr.IsConnected then
    exit(False);

  // socket is open, so send command to open connection to server

  // build connection request data packet
  msgConnect.Initialize;
  msgConnect.client_name := ClientID;
  krpcEncoder.EncodeData(msgConnect, True, bytesMsg);

  // flush buffer, send request
  FMessageDataBuffer.ClearBuffer;
  FSocketMgr.Write(bytesMsg);

  // wait for response or timeout
  tmTimeout.Init(Timeout);
  FSocketMgr.ReadTimeout := 5;

  while not tmTimeout.IsExpired do
  begin
    if FSocketMgr.Read(bytesMsg) > 0 then
    begin
      FMessageDataBuffer.AddDataToBuffer(bytesMsg);

      // check if an entire message in is the buffer yet
      if FMessageDataBuffer.IsMessageInBuffer then
      begin
        // got response, so check it
        if FMessageDataBuffer.RetreiveNextMessageFromBuffer(bytesMsg) then
        begin
          krpcDecoder.DecodeData(bytesMsg, False, msgResponse);
          FIsConnectedToServer := True;
          break;
        end;
      end;
    end;

    Sleep(50);
  end;

  Result := FIsConnectedToServer;
end;


function TKerbalSpaceControl.UpdateControlContext: boolean;
begin
  FControlContext := GetControlContext;
  Result := FControlContext.IsValid;
end;


{ TKSPControlContext }


procedure TKSPControlContext.Initialize;
begin
  VesselID := INVALID_ID;
  VesselControlID := INVALID_ID;
end;


function TKSPControlContext.IsValid: boolean;
begin
  Result := (VesselID <> INVALID_ID) and (VesselControlID <> INVALID_ID);
end;

end.
