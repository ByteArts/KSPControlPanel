program KSPControlPanel;

uses
  System.StartUpCopy,
  FMX.Forms,
  MainForm in 'views\MainForm.pas' {formName},
  kRPC_Protocol in 'models\kRPC_Protocol.pas',
  kRPC_Types in 'models\kRPC_Types.pas',
  kRPC_DataBuffer in 'models\kRPC_DataBuffer.pas',
  KerbalSpaceCtrl.Model in 'models\KerbalSpaceCtrl.Model.pas',
  KerbalSpaceControls in 'models\KerbalSpaceControls.pas',
  KerbalSpaceCtrl.ViewModel in 'viewmodels\KerbalSpaceCtrl.ViewModel.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TformName, formName);
  Application.Run;
end.
