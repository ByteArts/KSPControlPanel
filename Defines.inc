(*
Author: Scott Pinkham, ByteArts LLC
Description:
  Application global defines.
*)

(*
Note: The Build Configuration selection in the project options dialog
will determine whether DEBUG or RELEASE are defined.
*)

//=======FEATURE OPTIONS================

{$DEFINE DEMO}  // uses the simulation channel


//=======DEVELOPER OPTIONS===============

{$DEFINE APPLOG_ENABLED} // enable logging
{$DEFINE LOG_TO_FILE}  // enable logging to a file
{$DEFINE EMAIL_LOG} // enable sending log as an email

//=======AUTO-SET OPTIONS=================

{$IFDEF DEMO}
  {$MESSAGE HINT 'Compiled with DEMO defined'}
{$ENDIF}

{$IF Defined(EMAIL_LOG) AND NOT Defined(APPLOG_ENABLED) OR NOT Defined(LOG_TO_FILE)}
  {$MESSAGE ERROR 'Invalid logging options'}
{$ENDIF}

{$IF Defined(LOG_TO_FILE) AND NOT Defined(APPLOG_ENABLED)}
  {$MESSAGE ERROR 'Invalid logging options'}
{$ENDIF}


//========================================

