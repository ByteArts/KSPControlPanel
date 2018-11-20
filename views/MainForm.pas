unit MainForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls,
  FMX.EditBox, FMX.NumberBox, FMX.Edit,
  KerbalSpaceCtrl.ViewModel,
  KerbalSpaceControls;

type
  TformName = class(TForm)
    editHost: TEdit;
    numPort: TNumberBox;
    lblStatus: TLabel;
    grpViewModelTests: TGroupBox;
    btnConnect: TButton;
    btnDisconnect: TButton;
    grpHost: TGroupBox;
    btnStage: TButton;

    procedure DoControl(
      const Ctrl: TKSPControl;
      const StrValue: string);

    procedure FormCreate(Sender: TObject);

    procedure FormClose(
          Sender: TObject;
          var Action: TCloseAction);

    procedure btnConnectClick(Sender: TObject);

    procedure btnStageClick(Sender: TObject);

    private
      FCtrlViewModel: TKerbalSpaceCtrlViewModel;
      FIsConnected: boolean;

      procedure ConnectionControlsEnabled(const Value: boolean);
      procedure OnConnectionChanged(Sender: TObject);
      function GetHost: string;
      function GetPort: Integer;
      procedure SetHost(const Value: string);
      procedure SetPort(const Value: Integer);
      function GetIsConnected: boolean;
      procedure SetIsConnected(const Value: boolean);

    public
      property Host: string read GetHost write SetHost;

      property IsConnected: boolean read GetIsConnected write SetIsConnected;

      property Port: Integer read GetPort write SetPort;
  end;

var
  formName: TformName;

implementation

{$R *.fmx}


procedure TformName.btnConnectClick(Sender: TObject);
begin
  // disable controls while waiting for connection
  ConnectionControlsEnabled(False);

  FCtrlViewModel.ConnectToServer(editHost.Text, Trunc(numPort.Value));
end;


procedure TformName.btnStageClick(Sender: TObject);
begin
  DoControl(kcStaging, '');
end;


procedure TformName.ConnectionControlsEnabled(const Value: boolean);
begin
  grpHost.Enabled := Value;
  grpViewModelTests.Enabled := Value;
end;


procedure TformName.DoControl(
      const Ctrl: TKSPControl;
      const StrValue: string);
begin
  // add the control event to the queue
  FCtrlViewModel.AddToControlQueue(Ctrl, StrValue);
end;


procedure TformName.FormClose(
      Sender: TObject;
      var Action: TCloseAction);
begin
  FCtrlViewModel.Free;
end;


procedure TformName.FormCreate(Sender: TObject);
begin
{$IFDEF DEBUG}
  TThread.NameThreadForDebugging('MainGUI');
{$ENDIF}
  FCtrlViewModel := TKerbalSpaceCtrlViewModel.Create;
  FCtrlViewModel.OnConnectionChanged := OnConnectionChanged;

  IsConnected := False;
end;


function TformName.GetHost: string;
begin
  Result := editHost.Text;
end;


function TformName.GetIsConnected: boolean;
begin
  Result := FIsConnected;
end;


function TformName.GetPort: Integer;
begin
  Result := Trunc(numPort.Value);
end;


procedure TformName.OnConnectionChanged(Sender: TObject);
begin
  IsConnected := FCtrlViewModel.IsConnected;

  if not IsConnected then
  begin
    lblStatus.Text := 'no connection: ' + FCtrlViewModel.LastConnectionError;
  end
  else
  begin
    lblStatus.Text := 'connected to ' + FCtrlViewModel.ServerVersion;
  end;
end;


procedure TformName.SetHost(const Value: string);
begin
  editHost.Text := Value;
end;


procedure TformName.SetIsConnected(const Value: boolean);
begin
  ConnectionControlsEnabled(True);

  FIsConnected := Value;
  btnConnect.Enabled := not Value;
  btnDisconnect.Enabled := Value;
  grpHost.Enabled := not Value;
end;


procedure TformName.SetPort(const Value: Integer);
begin
  numPort.Value := Value;
end;


end.
