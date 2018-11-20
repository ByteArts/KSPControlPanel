unit kRPC_Types;

interface

uses
  System.SysUtils,
  Grijjy.ProtocolBuffers;//, Grijjy.SysUtils;


type
  TkrpcMsg = (kmsgNONE, kmsgCONNECT_REQUEST, kmsgREQUEST);

  TkrpcMsg_ConnectionRequest = record
    public
      [Serialize(1)] msg_type: Integer;
      [Serialize(2)] client_name: string;
      [Serialize(3)] client_id: TBytes;

      procedure Initialize;
  end;


  TkrpcMsg_ConnectionResponse = record
    public
      [Serialize(1)] status: Integer;
      [Serialize(2)] msg: string;
      [Serialize(3)] client_id: TBytes;

      procedure Initialize;
  end;


  TkrpcMsg_Argument = record
    public
      [Serialize(1)] position: UInt32;
      [Serialize(2)] value: TBytes;

      procedure Initialize;
  end;


  TkrpcMsg_ProcedureCall = record
    public
      [Serialize(1)] service_name: string;
      [Serialize(2)] procedure_name: string;
      [Serialize(4)] service_id: UInt32;
      [Serialize(5)] procedure_id: UInt32;
      [Serialize(3)] arguments: TArray<TkrpcMsg_Argument>;

      procedure Initialize;
  end;


  TkrpcMsg_Request = record
    public
      [Serialize(1)] calls: TArray<TkrpcMsg_ProcedureCall>;

      procedure Initialize;
  end;


  TkrpcMsg_Error = record
    public
      [Serialize(1)] service: string;
      [Serialize(2)] name: string;
      [Serialize(3)] description: string;
      [Serialize(4)] stack_trace: string;

      procedure Initialize;
  end;


  TkrpcMsg_ProcedureResult = record
    public
      [Serialize(1)] error: TkrpcMsg_Error;
      [Serialize(2)] value: TBytes;

      procedure Initialize;
  end;


  TkrpcMsg_Response = record
    public
      [Serialize(1)] error: TkrpcMsg_Error;
      [Serialize(2)] results: TArray<TkrpcMsg_ProcedureResult>;

      procedure Initialize;
  end;


  TkrpcMsg_Status = record
    public
      [Serialize(1)] version: string;
      [Serialize(2)] bytes_read: UInt64;
      [Serialize(3)] bytes_written: UInt64;
      [Serialize(4)] bytes_read_rate: Single;
      [Serialize(5)] bytes_written_rate: Single;
      [Serialize(6)] rpcs_executed: UInt64;
      [Serialize(7)] rpc_rate: Single;
      [Serialize(8)] one_rpc_per_update: Boolean;
      [Serialize(9)] max_time_per_update: UInt32;
      [Serialize(10)] adaptive_rate_control: Boolean;
      [Serialize(11)] blocking_recv: Boolean;
      [Serialize(12)] recv_timeout: UInt32;
      [Serialize(13)] time_per_rpc_update: Single;
      [Serialize(14)] poll_time_per_rpc_update: Single;
      [Serialize(15)] exec_time_per_rpc_update: Single;
      [Serialize(16)] stream_rpcs: UInt32;
      [Serialize(17)] stream_rpcs_executed: UInt64;
      [Serialize(18)] stream_rpc_rate: Single;
      [Serialize(19)] time_per_stream_update: Single;

      procedure Initialize;
  end;

  TkrpcTypeCode = (
    tcNONE = 0,

    // Values
    tcDOUBLE = 1,
    tcFLOAT = 2,
    tcSINT32 = 3,
    tcSINT64 = 4,
    tcUINT32 = 5,
    tcUINT64 = 6,
    tcBOOL = 7,
    tcSTRING = 8,
    tcBYTES = 9,

    // Objects
    tcCLASS = 100,
    tcENUMERATION = 101,

    // Messages
    tcEVENT = 200,
    tcPROCEDURE_CALL = 201,
    tcSTREAM = 202,
    tcSTATUS = 203,
    tcSERVICES = 204,

    // Collections
    tcTUPLE = 300,
    tcLIST = 301,
    tcSET = 302,
    tcDICTIONARY = 303
  );


  TkrpcMsg_Type = record
    public
      [Serialize(1)] type_code: Int32; // TkrpcTypeCode;
      [Serialize(2)] service: string;
      [Serialize(3)] name: string;
      [Serialize(4)] types: TArray<TkrpcMsg_Type>;
  end;


  TkrpcMsg_Parameter = record
    public
      [Serialize(1)] name: string;
      [Serialize(2)] param_type: TkrpcMsg_Type;
      [Serialize(3)] default_value: TBytes;
  end;


  TkrpcMsg_Procedure = record
    public
      [Serialize(1)] name: string;
      [Serialize(2)] parameters: TArray<TkrpcMsg_Parameter>;
      [Serialize(3)] return_type: TkrpcMsg_Type;
      [Serialize(4)] return_is_nullable: boolean;
      [Serialize(5)] documentation: string;
  end;


  TkrpcMsg_Class = record
    public
      [Serialize(1)] name: string;
      [Serialize(2)] documentation: string;
  end;


  TkrpcMsg_EnumerationValue = record
    public
      [Serialize(1)] name: string;
      [Serialize(2)] value: Int32;
      [Serialize(3)] documentation: string;
  end;


  TkrpcMsg_Enumeration = record
    public
      [Serialize(1)] name: string;
      [Serialize(2)] values: TArray<TkrpcMsg_EnumerationValue>;
      [Serialize(3)] documentation: string;
  end;


  TkrpcMsg_Exception = record
    public
      [Serialize(1)] name: string;
      [Serialize(2)] documentation: string;
  end;


  TkrpcMsg_Service = record
    public
      [Serialize(1)] name: string;
      [Serialize(2)] procedures: TArray<TkrpcMsg_Procedure>;
      [Serialize(3)] classes: TArray<TkrpcMsg_Class>;
      [Serialize(4)] enumerations: TArray<TkrpcMsg_Enumeration>;
      [Serialize(5)] exceptions: TArray<TkrpcMsg_Exception>;
      [Serialize(6)] documentation: string;
  end;

  TkrpcMsg_Services = record
    public
      [Serialize(1)] services: TArray<TkrpcMsg_Service>;

      procedure Initialize;
  end;

  TSizeField = record
    Value: Cardinal; // the value contained in the size field
    FieldSize: Cardinal; // number of bytes in the size field
  end;


implementation


{ TkrpcMsg_ConnectionRequest }

procedure TkrpcMsg_ConnectionRequest.Initialize;
begin
  Self.msg_type := 0;
  Self.client_name := '';
  SetLength(Self.client_id, 0);  //  Self.client_id := nil;
end;


{ TkrpcMsg_ConnectionResponse }

procedure TkrpcMsg_ConnectionResponse.Initialize;
begin
  Self.status := 0;
  Self.msg := '';
  SetLength(Self.client_id, 0);  //  Self.client_id := nil;
end;

{ TkrpcMsg_Argument }

procedure TkrpcMsg_Argument.Initialize;
begin
  Self.position := 0;
  SetLength(Self.value, 0); //  Self.value := nil;
end;


{ TkrpcMsg_ProcedureCall }

procedure TkrpcMsg_ProcedureCall.Initialize;
begin
  Self.service_name := '';
  Self.procedure_name := '';
  Self.service_id := 0;
  Self.procedure_id := 0;
  SetLength(Self.arguments, 0); // Self.arguments := nil;
end;


{ TkrpcMsg_Request }

procedure TkrpcMsg_Request.Initialize;
begin
  SetLength(Self.Calls, 0); //  Self.calls := nil;
end;


{ TkrpcMsg_Error }

procedure TkrpcMsg_Error.Initialize;
begin
  Self.service := '';
  Self.name := '';
  Self.description := '';
  Self.stack_trace := '';
end;


{ TkrpcMsg_ProcedureResult }

procedure TkrpcMsg_ProcedureResult.Initialize;
begin
  Self.error.Initialize;
  SetLength(Self.value, 0); // Self.value := nil;
end;


{ TkrpcMsg_Response }

procedure TkrpcMsg_Response.Initialize;
begin
  Self.error.Initialize;
  SetLength(Self.results, 0); // Self.results := nil;
end;


{ TkrpcMsg_Status }

procedure TkrpcMsg_Status.Initialize;
begin
  version := '';
  bytes_read := 0;
  bytes_written := 0;
  bytes_read_rate := 0;
  bytes_written_rate := 0;
  rpcs_executed := 0;
  rpc_rate := 0;
  one_rpc_per_update := False;
  max_time_per_update := 0;
  adaptive_rate_control := False;
  blocking_recv := False;
  recv_timeout := 0;
  time_per_rpc_update := 0;
  poll_time_per_rpc_update := 0;
  exec_time_per_rpc_update := 0;
  stream_rpcs := 0;
  stream_rpcs_executed := 0;
  stream_rpc_rate := 0;
  time_per_stream_update := 0;
end;


{ TkrpcMsg_Services }

procedure TkrpcMsg_Services.Initialize;
begin
  SetLength(Self.services, 0);  // Self.services := nil;
end;

end.
