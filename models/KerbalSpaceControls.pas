unit KerbalSpaceControls;

interface

type
  TKSPControlType = (ctPushButton, ctToggle, ctAnalog);

  TKSPControl = (kcStaging, kcToggleSAS, kcThrottle);

  TKSPControlEntry = record
    CtrlID: TKSPControl;
    Value: string;
  end;

  TKSPControlTableEntry = record
    public
      CtrlID: TKSPControlType;
      Name: string;
      ServiceName: string;
      ProcedureName: string;
      Value: string;
  end;


const
  sSERVICENAME_SPACECENTER = 'SpaceCenter';

  KSPCONTROL_TABLE: array [TKSPControl] of TKSPControlTableEntry = (
    (CtrlID: ctPushButton;
        Name: 'Stage'; ServiceName: sSERVICENAME_SPACECENTER;
        ProcedureName: 'Control_ActivateNextStage'),
    (CtrlID: ctToggle; Name: 'SAS'),
    (CtrlID: ctAnalog; Name: 'Throttle')
  );


implementation

end.
