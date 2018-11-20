unit kRPC_Protocol;

/// <summary>
/// Module containing support code for communicating with the kRPC plugin for Kerbal Space
/// Program. kRPC uses Google's protocol buffers for communication and this module has utility
/// and support code for handling the data to/from the protocol buffers.
/// </summary>

interface

uses
  System.SysUtils,
  Grijjy.ProtocolBuffers, Grijjy.SysUtils,
  kRPC_Types;


type
  /// <summary>
  /// Structure for holding data used to indicate the size of a field. The Value field contains
  /// the 'varint' encoding of the size, while the FieldSize indicates how many bytes of the Value
  /// are actually used.
  /// </summary>
  TSizeField = record
    Value: Cardinal; // the size encoded as a 'varint'
    FieldSize: Cardinal; // number of bytes in the size field
  end;


  /// <summary>
  /// Generic structure for decoding protocol buffer data.
  /// </summary>
  TKRPC_Decoder<T: record > = record
    public
      procedure DecodeData(
            const AData: TBytes;
            const AHasSizeHeader: boolean;
            out ARecord: T);
  end;

  /// <summary>
  /// Generic structure for encoding protocol buffer data.
  /// </summary>
  TKRPC_Encoder<T: record > = record
    public
      procedure EncodeData(
            const ARecord: T;
            const IncludeSizeHeader: boolean;
            out AData: TBytes);
  end;


  TKRPC_StandardRequestHandler<T: record> = record
    public
      procedure ProcessRequestResponse(
            const AData: TBytes;
            out RetVal: T);
  end;



  // ========= support functions =============//

  /// <summary>
  /// Extracts the size prefix from a protocol data buffer -- the result is the count of data
  /// bytes (not including the size prefix) in the buffer.
  /// </summary>
  function KRPC_DecodeSizeField(const Data: TBytes): TSizeField;


  function KRPC_DecodeStandardRequest(const Data: TBytes; out Retval: TkrpcMsg_Response): boolean;


  function KRPC_DecodeString(
        const Data: TBytes;
        const HasSizeHeader: boolean): UTF8String;


  function KRPC_DecodeVarint(const Data: TBytes): UInt64;


  /// <summary>
  /// Given a buffer of data, this returns the data size prefix for the data in the buffer.
  /// </summary>
  function KRPC_EncodeSizeField(const Value: Cardinal): TSizeField;

  /// <summary>
  /// Encodes a string for use in a protocol buffer message. The resulting data contains
  /// a 'varint' prefix that indicates the size of the data in the buffer, followed by the
  /// string data itself. The string value is converted to UTF8 encoding before it's encoded.
  /// </summary>
  procedure KRPC_EncodeString(
      const Value: string;
      out AData: TBytes);


  procedure KRPC_EncodeVarint(const Value: Cardinal; out AData: TBytes);


implementation


function KRPC_DecodeSizeField(const Data: TBytes): TSizeField;
var
  bValue: Byte;
  nIndex: Integer;

  function ReadByte: Byte;
  begin
    Assert(Length(Data) > nIndex);

    Result := Data[nIndex];
    Inc(nIndex);
  end;

begin
  (*
  Assumes that the data contains the count of the number of bytes in the buffer as a 'varint'
  at the begining of the buffer. The number of bytes that make up the varint value depends on the
  value itself, so this code handles that and returns the value of the varint as a TSizeField.
  *)
  Result.Value := 0;
  Result.FieldSize := 0;

  if Length(Data) < 1 then
    exit;

  try
    nIndex := 0;
    bValue := ReadByte;

    // the high bit of each byte indicates if more bytes are used or not
    Result.Value := bValue and $7F;

    if (bValue >= $80) then
    begin
      // decode the next byte(s)
      bValue := ReadByte;
      Result.Value := Result.Value or ((bValue and $7F) shl 7);

      if (bValue >= $80) then
      begin
        // decode the next byte(s)
        bValue := ReadByte;
        Result.Value := Result.Value or ((bValue and $7F) shl 14);

        if (bValue >= $80) then
        begin
          // decode the next byte(s)
          bValue := ReadByte;
          Result.Value := Result.Value or ((bValue and $7F) shl 21);

          if (bValue >= $80) then
          begin
            // decode the next byte (must be the last)
            bValue := ReadByte;
            Assert(bValue < $80);
            Result.Value := Result.Value or (bValue shl 28);
          end;
        end;
      end;
    end;

    Result.FieldSize := nIndex;

  except
    Result.Value := 0;
    Result.FieldSize := 0;
  end;
end;


function KRPC_DecodeStandardRequest(const Data: TBytes; out Retval: TkrpcMsg_Response): boolean;
var
  respDecoder: TKRPC_Decoder<TkrpcMsg_Response>;
begin
  Retval.Initialize;

  respDecoder.DecodeData(Data, False, Retval);

  { TODO : check for error }

  Result := Length(Retval.results) > 0;
end;


function KRPC_DecodeString(
      const Data: TBytes;
      const HasSizeHeader: boolean): UTF8String;
var
  sfSize: TSizeField;
begin
  if HasSizeHeader then
  begin
    // get size prefix from data
    sfSize := KRPC_DecodeSizeField(Data);
  end
  else
  begin
    // use size of data buffer
    sfSize.Value := Length(Data);
    sfSize.FieldSize := 0;
  end;

  Result := UTF8String(Copy(Data, sfSize.FieldSize, sfSize.Value));
end;


function KRPC_DecodeVarint(const Data: TBytes): UInt64;
var
  sfSize: TSizeField;
begin
  sfSize := KRPC_DecodeSizeField(Data);
  Result := sfSize.Value;
end;


function KRPC_EncodeSizeField(const Value: Cardinal): TSizeField;
begin
  Result.Value := Value;
  Result.FieldSize := 0;

  if (Value >= $80) then
  begin
    Inc(Result.FieldSize);

    if (Value >= $4000) then
    begin
      Inc(Result.FieldSize);

      if (Value >= $200000) then
      begin
        Inc(Result.FieldSize);

        if (Value >= $10000000) then
        begin
          Inc(Result.FieldSize, 2);
        end
        else
          Inc(Result.FieldSize);
      end
      else
        Inc(Result.FieldSize);
    end
    else
      Inc(Result.FieldSize);
  end
  else
    Inc(Result.FieldSize);
end;


procedure KRPC_EncodeString(
      const Value: string;
      out AData: TBytes);
var
  bufProtoMsg: TgoByteBuffer;
  bytesMsg: TBytes;
  sValueUTF: UTF8String;
  sfSize: TSizeField;
begin
  bufProtoMsg := TgoByteBuffer.Create;

  try
    // convert string to UTF-8 encoding. then get bytes
    sValueUTF := UTF8String(Value);
    bytesMsg := BytesOf(sValueUTF);

    // add prefix containing message size to the buffer
    sfSize := KRPC_EncodeSizeField(Length(bytesMsg));
    bufProtoMsg.AppendBuffer(&sfSize.Value, sfSize.FieldSize);

    // add message data to buffer
    bufProtoMsg.Append(bytesMsg);
    bufProtoMsg.TrimExcess;

    AData := bufProtoMsg.Buffer;

  finally
    bufProtoMsg.Free;
  end;
end;


procedure KRPC_EncodeVarint(const Value: Cardinal; out AData: TBytes);
var
  sfSize: TSizeField;
  pValue: PByte;
  nIndex: Integer;
begin
  sfSize := KRPC_EncodeSizeField(Value);

  SetLength(AData, sfSize.FieldSize);
  pValue := @Value;

  for nIndex := 0 to sfSize.FieldSize - 1 do
  begin
    AData[nIndex] := pValue^;
    Inc(pValue);
  end;

  //Move(pValue, AData, Length(AData));  //<<<doesn't work
end;


{ TKRPC_Decoder<T> }


procedure TKRPC_Decoder<T>.DecodeData(
      const AData: TBytes;
      const AHasSizeHeader: boolean;
      out ARecord: T);
var
  bytesMsg: TBytes;
  sfSize: TSizeField;
begin
  if (AHasSizeHeader) then
  begin
    // get size from prefix in data
    sfSize := KRPC_DecodeSizeField(AData);
  end
  else
  begin
    // use size of data
    sfSize.Value := Length(AData);
    sfSize.FieldSize := 0;
  end;

  bytesMsg := Copy(AData, sfSize.FieldSize, sfSize.Value);
  TgoProtocolBuffer.Deserialize<T>(ARecord, bytesMsg);
end;


{ TKRPC_Encoder<T> }


procedure TKRPC_Encoder<T>.EncodeData(
      const ARecord: T;
      const IncludeSizeHeader: boolean;
      out AData: TBytes);
var
  bufProtoMsg: TgoByteBuffer;
  bytesMsg: TBytes;
  sfSize: TSizeField;
begin
  bufProtoMsg := TgoByteBuffer.Create;

  try
    // serialize the message data using protocol buffers
    bytesMsg := TgoProtocolBuffer.Serialize<T>(ARecord);

    if (IncludeSizeHeader) then
    begin
      // add prefix containing message size to the buffer
      sfSize := KRPC_EncodeSizeField(Length(bytesMsg));
      bufProtoMsg.AppendBuffer(&sfSize.Value, sfSize.FieldSize);
    end;

    // add message data to buffer
    bufProtoMsg.Append(bytesMsg);
    bufProtoMsg.TrimExcess;

    AData := bufProtoMsg.Buffer;

  finally
    bufProtoMsg.Free;
  end;
end;


{ TKRPC_StandardRequestHandler<T> }

procedure TKRPC_StandardRequestHandler<T>.ProcessRequestResponse(
      const AData: TBytes;
      out RetVal: T);
var
  krpcRequestDecoder: TKRPC_Decoder<TkrpcMsg_Response>;
  msgResponse: TkrpcMsg_Response;
  respDecoder: TKRPC_Decoder<T>;
begin
  krpcRequestDecoder.DecodeData(AData, False, msgResponse);

  // the response should contain the response in results[0]
  if (Length(msgResponse.results) > 0) then
  begin
    respDecoder.DecodeData(msgResponse.results[0].value, False, RetVal);
  end;

end;

end.
