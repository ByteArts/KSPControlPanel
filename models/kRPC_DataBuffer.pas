unit kRPC_DataBuffer;

interface

uses
  System.SysUtils,
  kRPC_Protocol;

type
  TkRPC_DataBuffer = class
    private
      FBuffer: TBytes;
      function CheckForCompleteMessage(out Size: kRPC_Protocol.TSizeField): boolean;
    function GetIsMessageInBuffer: boolean;

    public
      procedure AddDataToBuffer(const Data: TBytes);

      procedure ClearBuffer;

      constructor Create;

      destructor Destroy; override;

      /// <summary>
      /// Checks the buffer for data - the data should be prefixed with the byte count encoded
      /// as a 'varint', so this method will keep reading data from the buffer until the
      /// expected number of bytes are read. The size prefix is NOT included in the
      /// resulting data.
      /// </summary>
      function RetreiveNextMessageFromBuffer(out MessageData: TBytes): boolean;

      property IsMessageInBuffer: boolean read GetIsMessageInBuffer;
  end;

implementation

uses
  System.Generics.Collections;


{ TkRPC_DataBuffer }


procedure TkRPC_DataBuffer.AddDataToBuffer(const Data: TBytes);
begin
  FBuffer := Concat(FBuffer, Data);
end;


function TkRPC_DataBuffer.CheckForCompleteMessage(out Size: kRPC_Protocol.TSizeField): boolean;
begin
  (*
  Google Protocol Buffers messages are stored in the buffer with a size prefix, so once enough bytes
  are in the buffer, we can retreive the entire message from the buffer for further processing.
  *)

  // first try to get the size prefix
  Size := KRPC_DecodeSizeField(FBuffer);

  // is the entire message in the buffer yet?
  if (Size.Value = 0) or (Cardinal(Length(FBuffer)) < (Size.Value + Size.FieldSize)) then
    exit(False)
  else
    exit(True);
end;



procedure TkRPC_DataBuffer.ClearBuffer;
begin
  SetLength(FBuffer, 0);
end;


constructor TkRPC_DataBuffer.Create;
begin
  ClearBuffer;
end;


destructor TkRPC_DataBuffer.Destroy;
begin
  ClearBuffer;
  inherited;
end;


function TkRPC_DataBuffer.GetIsMessageInBuffer: boolean;
var
  spSize: kRPC_Protocol.TSizeField;
begin
  Result := CheckForCompleteMessage(spSize);
end;


function TkRPC_DataBuffer.RetreiveNextMessageFromBuffer(out MessageData: TBytes): boolean;
var
  spSize: kRPC_Protocol.TSizeField;
  nTotalMessageSize: Cardinal;
begin
  Result := CheckForCompleteMessage(spSize);

  if not Result then
    exit;


  (*
  Google Protocol Buffers messages are stored in the buffer with a size prefix, so once enough bytes
  are in the buffer, we can retreive the entire message from the buffer for further processing.
  *)

//  // first try to get the size prefix
//  spSize := KRPC_DecodeSizeField(FBuffer);
//
//  // is the entire message in the buffer yet?
//  if (spSize.Value = 0) or (Cardinal(Length(FBuffer)) < (spSize.Value + spSize.FieldSize)) then
//    exit;

  // extract the message from the buffer, skipping over the size prefix
  MessageData := Copy(FBuffer, spSize.FieldSize, spSize.Value);

  // now remove the message from the buffer
  nTotalMessageSize := spSize.Value + spSize.FieldSize;
  Delete(FBuffer, 0, nTotalMessageSize);

  Result := True;
end;

end.
