unit KerbalSpaceCtrl.ViewModel;

interface

uses
  System.Classes,
  EventQueue,
  BackgndMethods,
  KerbalSpaceControls,
  KerbalSpaceCtrl.Model;

type
  TKerbalSpaceCtrlViewModel = class
    private
      FCtrlModel: TKerbalSpaceControl;
      FControlQueue: TEventQueue;
      FHost: string;
      FBusyLock: TLockFlag;
      FOnConnectionChanged: TNotifyEvent;
      FOnModelConnectionChanged: TNotifyEvent;
      FPort: Integer;

      procedure DoOnConnectionChanged(Sender: TObject);

      procedure DoProcessControlQueue(
            const Value: TEventQueueItem;
            var RemoveFromQueue: boolean);

      function DoSendControlEvent(
            const CheckForAbort: TBoolFunc;
            const InputValue: TKSPControlEntry;
            out OutputValue: Integer): TBackgndProcResult;

      function GetIsConnected: boolean;

      function GetLastConnectionError: string;

      function GetServerVersion: string;

    public
      constructor Create;

      destructor Destroy; override;

      procedure DisconnectFromServer;

      /// <summary>
      /// Tries to establish socket connection to specified host. Returns right away,
      /// but will generate an OnConnectionChanged event when done.
      /// </summary>
      procedure ConnectToServer(
            const Host: string;
            const Port: Integer);

      property IsConnected: boolean read GetIsConnected;

      property LastConnectionError: string read GetLastConnectionError;

      /// <summary>
      /// Event fired when connection to host is established or lost.
      /// </summary>
      property OnConnectionChanged: TNotifyEvent read FOnConnectionChanged
            write FOnConnectionChanged;

      property ServerVersion: string read GetServerVersion;

      procedure AddToControlQueue(
            const Ctrl: TKSPControl;
            const StrValue: string);
  end;

implementation

uses
  System.SysUtils;


{ TKerbalSpaceViewModel }


procedure TKerbalSpaceCtrlViewModel.AddToControlQueue(
      const Ctrl: TKSPControl;
      const StrValue: string);
var
  eqiCtrl: TEventQueueItem;
begin
  eqiCtrl.ID := Ord(Ctrl);
  eqiCtrl.StrValue := StrValue;
  FControlQueue.AddToEndOfQueue(eqiCtrl, True);
end;


procedure TKerbalSpaceCtrlViewModel.ConnectToServer(
      const Host: string;
      const Port: Integer);
var
  thrdConnect: TThread;
begin
  if not FBusyLock.Lock then
    exit;

  FHost := Host;
  FPort := Port;

  FCtrlModel.OnConnected := FOnModelConnectionChanged;
  FCtrlModel.OnDisconnected := FOnModelConnectionChanged;

  // use thread to connect, call OnDone (via Synchronize) when done
  thrdConnect := TThread.CreateAnonymousThread(
    procedure()
    begin
      FCtrlModel.OpenConnection(Host, Port, 'ViewModel', 4000);

      TThread.Synchronize(TThread.CurrentThread,
        procedure()
        begin
          try
            DoOnConnectionChanged(Self);

          finally
            FBusyLock.Release;
          end;
        end);
    end);

  thrdConnect.Start;
end;


constructor TKerbalSpaceCtrlViewModel.Create;
begin
  FCtrlModel := TKerbalSpaceControl.Create;
  FControlQueue := TEventQueue.Create;

  FControlQueue.OnProcessItem := DoProcessControlQueue;
end;


destructor TKerbalSpaceCtrlViewModel.Destroy;
begin
  FreeAndNil(FCtrlModel);
  inherited;
end;


procedure TKerbalSpaceCtrlViewModel.DisconnectFromServer;
begin
  FCtrlModel.CloseConnection; // if connected, then OnDisconnected event will get fired
end;


procedure TKerbalSpaceCtrlViewModel.DoOnConnectionChanged(Sender: TObject);
begin
  if Assigned(FOnConnectionChanged) then
    FOnConnectionChanged(Sender);

  if IsConnected then
    FControlQueue.StartProcessingQueue(100)
  else
    FControlQueue.StopProcessingQueue;
end;


procedure TKerbalSpaceCtrlViewModel.DoProcessControlQueue(
      const Value: TEventQueueItem;
      var RemoveFromQueue: boolean);
var
  bgmCall: TBackgndMethodCall<TKSPControlEntry, Integer>;
  ceCtrl: TKSPControlEntry;
begin
  // this method is called from timer event to process entries in the queue

  // check if connected
  if not IsConnected then
  begin
    FControlQueue.StopProcessingQueue;
    RemoveFromQueue := False; // keep entry in queue
    exit;
  end;

  // init parameter value
  ceCtrl.CtrlID := TKSPControl(Value.ID);
  ceCtrl.Value := Value.StrValue;

  // send control event to server
  RemoveFromQueue := bgmCall.Start(ceCtrl, DoSendControlEvent, nil, nil, FBusyLock);
end;


function TKerbalSpaceCtrlViewModel.DoSendControlEvent(
      const CheckForAbort: TBoolFunc;
      const InputValue: TKSPControlEntry;
      out OutputValue: Integer): TBackgndProcResult;
begin

end;


function TKerbalSpaceCtrlViewModel.GetIsConnected: boolean;
begin
  Result := FCtrlModel.IsConnected;
end;


function TKerbalSpaceCtrlViewModel.GetLastConnectionError: string;
begin
  Result := FCtrlModel.LastConnectionError;
end;


function TKerbalSpaceCtrlViewModel.GetServerVersion: string;
begin
  Result := FCtrlModel.ServerVersion;
end;


end.
