unit kRPC_ViewModel;

interface

uses
  System.Classes, System.SysUtils,
  SocketClient, kRPC_Types, kRPC_DataBuffer;

type
  /// <summary>
  /// Class for managing communication with the kRPC plugin
  /// </summary>
  TKRPCViewModel = class(TObject)
    private
      FClientID: TBytes;
      FClientName: string;
      FDataBuffer: TkRPC_DataBuffer;
      FIsNewConnection: boolean;
      FOnServerConnect, FOnServerDisconnect: TNotifyEvent;
      FPendingMsg: TkrpcMsg;
      FPendingRequest: string;
      FServerVersion: string;
      FSocketMgr: TClientSocketMgr;

      procedure OnMessageReceived(const Data: TBytes);

      procedure OnSocketConnect(Sender: TObject);

      procedure OnSocketData(const Data: TBytes);

      procedure OnSocketDisconnect(Sender: TObject);

    public
      constructor Create(const ClientName: string);

      destructor Destroy; override;

      function OpenConnection(
            const Host: string;
            const Port: Integer): boolean;

      procedure RequestStatus;

      procedure Test(const TestID: Integer);

      property OnServerConnect: TNotifyEvent read FOnServerConnect write FOnServerConnect;

      property OnServerDisconnect: TNotifyEvent read FOnServerDisconnect write FOnServerDisconnect;

      property ServerVersion: string read FServerVersion;
  end;


implementation

uses
  kRPC_Protocol;


{ TKRPCViewModel }


constructor TKRPCViewModel.Create(const ClientName: string);
begin
  inherited Create;
  FClientName := ClientName;

  FDataBuffer := TkRPC_DataBuffer.Create;

  // set up socket connection manager
  FSocketMgr := TClientSocketMgr.Create;
  FSocketMgr.OnConnected := OnSocketConnect;
  FSocketMgr.OnDisconnected := OnSocketDisconnect;
  FSocketMgr.OnDataReceived := OnSocketData;
end;


destructor TKRPCViewModel.Destroy;
begin
  FreeAndNil(FSocketMgr);
  FreeAndNil(FDataBuffer);
  inherited;
end;


procedure TKRPCViewModel.OnMessageReceived(const Data: TBytes);
var
  msgConnectResponse: TkrpcMsg_ConnectionResponse;
  msgStatus: TkrpcMsg_Status;
  msgResponse: TkrpcMsg_Response;
  nVessel: UInt64;

  function DecodeConnectionRequest: TkrpcMsg_ConnectionResponse;
  var
    krpcDecoder: TKRPC_Decoder<TkrpcMsg_ConnectionResponse>;
  begin
    krpcDecoder.DecodeData(Data, False, Result); // size prefix has already been removed
  end;

(*
  function DecodeServicesRequest: boolean;
  var
    krpcRequestDecoder: TKRPC_Decoder<TkrpcMsg_Response>;
    krpcServicesDecoder: TKRPC_Decoder<TkrpcMsg_Services>;
    krpcServiceDecoder: TKRPC_Decoder<TkrpcMsg_Service>;
    msgResponse: TkrpcMsg_Response;
    msgServices: TkrpcMsg_Services;
    msgService: TkrpcMsg_Service;
    nIndex: Integer;
    FServiceList: TArray<TkrpcMsg_Service>;
    sTest: UTF8String;
  begin
    Result := False;

    // decode data to get msgResponse
    krpcRequestDecoder.DecodeData(Data, False, msgResponse); // size prefix already been removed

    // the response should contain the Services message, which contains a listing of each service
    if (Length(msgResponse.results) > 0) then
    begin
      sTest := KRPC_DecodeString(msgResponse.results[0].value, False);
      //krpcServicesDecoder.DecodeData(BytesOf(sTest), False, msgServices);

      // decode Services message from results[0]   >>>crashes here<<<
      krpcServicesDecoder.DecodeData(msgResponse.results[0].value, False, msgServices);

      // decode each service listing
      if (Length(msgServices.services) > 0) then
      begin
        // enumerate all the services
        SetLength(FServiceList, Length(msgServices.services));
        for nIndex := 0 to Length(msgServices.services) - 1 do
        begin
          krpcServiceDecoder.DecodeData(@msgServices.services[nIndex], True, msgService);
          FServiceList[nIndex] := msgService;
        end;
      end;
    end;
  end;
*)

  function DecodeStatusRequest: TkrpcMsg_Status;
  var
    krpcRequestDecoder: TKRPC_Decoder<TkrpcMsg_Response>;
    krpcStatusDecoder: TKRPC_Decoder<TkrpcMsg_Status>;
    msgAResponse: TkrpcMsg_Response;
  begin
    Result.Initialize;

    // decode Data to get msgResposne
    krpcRequestDecoder.DecodeData(Data, False, msgAResponse); // size prefix already removed

    // the response should contain the status message in results[0]
    if (Length(msgAResponse.results) > 0) then
    begin
      krpcStatusDecoder.DecodeData(msgAResponse.results[0].value, False, Result);
    end;
  end;

begin
  (*
  We get here after a complete message has been received. The Data buffer contains the message
  data, with the size prefix already removed. However, there could be fields within the data
  that also have size prefixes, so that has to be taken into account when decoding them.
  *)

  // use the FPendingMsg value to determine what type of data we are expecting
  case FPendingMsg of
    kmsgNONE:
    ;

    kmsgCONNECT_REQUEST:
    begin
      FPendingMsg := kmsgNONE;

      // decode the response
      msgConnectResponse := DecodeConnectionRequest;

      if (msgConnectResponse.status = 0) then
      begin
        FClientID := Copy(msgConnectResponse.client_id);
        FIsNewConnection := True;

        RequestStatus; // gets server version
      end
      else
      begin
        // status not 0, so an error occurred
        Sleep(0);
      end;
    end;

    kmsgREQUEST:
    begin
      FPendingMsg := kmsgNONE;

      if (FPendingRequest = 'KRPC:GetStatus') then
      begin
        msgStatus := DecodeStatusRequest;
        FServerVersion := msgStatus.version;

        if FIsNewConnection then
        begin
          FIsNewConnection := False;

          if Assigned(FOnServerConnect) then
            FOnServerConnect(Self);
        end;
      end
//      else if (FPendingRequest = 'KRPC:GetServices') then
//      begin
//        DecodeServicesRequest;
//      end
      else if (FPendingRequest = 'SpaceCenter:get_ActiveVessel') then
      begin
        if KRPC_DecodeStandardRequest(Data, msgResponse) then
        begin
          nVessel := KRPC_DecodeVarint(msgResponse.results[0].value);
        end;
      end;
    end;
  end;
end;


procedure TKRPCViewModel.OnSocketConnect(Sender: TObject);
begin
  // enable getting data in backgnd -- OnSocketData event will be fired when data is available
  FSocketMgr.StartCheckingForData;
end;


procedure TKRPCViewModel.OnSocketData(const Data: TBytes);
var
  bMessage: TBytes;
begin
  FDataBuffer.AddDataToBuffer(Data);

  // check if a complete message has been recieved yet
  if FDataBuffer.RetreiveNextMessageFromBuffer(bMessage) then
  begin
    OnMessageReceived(bMessage);
  end;
end;


procedure TKRPCViewModel.OnSocketDisconnect(Sender: TObject);
begin
  if Assigned(FOnServerDisconnect) then
    FOnServerDisconnect(Sender);
end;


function TKRPCViewModel.OpenConnection(
      const Host: string;
      const Port: Integer): boolean;
var
  bytesMsg: TBytes;
  krpcEncoder: TKRPC_Encoder<TkrpcMsg_ConnectionRequest>;
  msgConnect: TkrpcMsg_ConnectionRequest;
begin
  // set socket connection parameters
  FSocketMgr.Host := Host;
  FSocketMgr.Port := Port;
  FSocketMgr.OnConnected := OnSocketConnect;
  FSocketMgr.OnDisconnected := OnSocketDisconnect;
  FSocketMgr.OnDataReceived := OnSocketData;

  // build request data packet
  msgConnect.Initialize;
  msgConnect.client_name := FClientName;
  krpcEncoder.EncodeData(msgConnect, True, bytesMsg);

  // open connection, send request
  FSocketMgr.OpenConnection;
  FPendingMsg := kmsgCONNECT_REQUEST;
  FSocketMgr.Write(bytesMsg);

  Result := FSocketMgr.IsConnected;
end;


procedure TKRPCViewModel.RequestStatus;
var
  msgCall: TkrpcMsg_ProcedureCall;
  msgRequest: TkrpcMsg_Request;
  bytesMsg: TBytes;
  krpcEncoder: TKRPC_Encoder<TkrpcMsg_Request>;
begin
  msgCall.Initialize;
  msgCall.service_name := 'KRPC';
  msgCall.procedure_name := 'GetStatus';

  msgRequest.Initialize;
  SetLength(msgRequest.calls, 1);
  msgRequest.calls[0] := msgCall;

  krpcEncoder.EncodeData(msgRequest, True, bytesMsg);

  FPendingMsg := kmsgREQUEST;
  FPendingRequest := Format('%s:%s', [msgCall.service_name, msgCall.procedure_name]);
  FSocketMgr.Write(bytesMsg);
end;


procedure TKRPCViewModel.Test(const TestID: Integer);
var
  msgCall: TkrpcMsg_ProcedureCall;
  msgArg: TkrpcMsg_Argument;
  msgRequest: TkrpcMsg_Request;
  bytesMsg: TBytes;
  encodeMsgRequest: TKRPC_Encoder<TkrpcMsg_Request>;
begin
  case TestID of
    0:
    begin
      // test UI message
      msgCall.Initialize;
      msgCall.service_name := 'UI';
      msgCall.procedure_name := 'Message';

      msgArg.Initialize;
      msgArg.position := 0;
      KRPC_EncodeString('nice ship you have there', msgArg.value);

      SetLength(msgCall.arguments, 1);
      msgCall.arguments[0] := msgArg;

      msgRequest.Initialize;
      SetLength(msgRequest.calls, 1);
      msgRequest.calls[0] := msgCall;

      encodeMsgRequest.EncodeData(msgRequest, True, bytesMsg);

      FPendingMsg := kmsgREQUEST;
      FPendingRequest := Format('%s:%s', [msgCall.service_name, msgCall.procedure_name]);
      FSocketMgr.Write(bytesMsg);
    end;

    1:
    begin
      // test GetServices
      msgCall.Initialize;
      msgCall.service_name := 'KRPC';
      msgCall.procedure_name := 'GetServices';

      msgRequest.Initialize;
      SetLength(msgRequest.calls, 1);
      msgRequest.calls[0] := msgCall;

      encodeMsgRequest.EncodeData(msgRequest, True, bytesMsg);

      FPendingMsg := kmsgREQUEST;
      FPendingRequest := Format('%s:%s', [msgCall.service_name, msgCall.procedure_name]);
      FSocketMgr.Write(bytesMsg);
    end;

    2:
    begin
      // test sending a staging command

      // first get vessel
      msgCall.Initialize;
      msgCall.service_name := 'SpaceCenter';
      msgCall.procedure_name := 'get_ActiveVessel';

      msgRequest.Initialize;
      SetLength(msgRequest.calls, 1);
      msgRequest.calls[0] := msgCall;

      encodeMsgRequest.EncodeData(msgRequest, True, bytesMsg);
      FPendingMsg := kmsgREQUEST;
      FPendingRequest := Format('%s:%s', [msgCall.service_name, msgCall.procedure_name]);
      FSocketMgr.Write(bytesMsg);
    end;
  end;
end;


end.
