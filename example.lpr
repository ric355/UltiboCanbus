program example;

{$mode objfpc}{$H+}

(*
Ultibo canbus example
Richard Metcalfe, Sep 2022.
*)

uses
  RaspberryPi3,
  GlobalConfig,
  GlobalConst,
  GlobalTypes,
  Platform,
  Threads,
  SysUtils,
  Classes,
  Ultibo,
  RemoteShell,
  shell,
  ShellUpdate,
  console,
  framebuffer,
  Logging,
  gpio,
  canbus;

var
  CanbusDevice : MCP_CAN;
  TopWindow : THandle;
  Res : longword;
  rxBuf : array[1..8] of byte;
  rxId : INT32U;
  len : INT8U;
  i : integer;

begin
  ConsoleFramebufferDeviceAdd(FramebufferDeviceGetDefault);
  CONSOLE_LOGGING_POSITION := CONSOLE_POSITION_BOTTOM;
  CONSOLE_REGISTER_LOGGING := True;

  TopWindow := ConsoleWindowCreate(ConsoleDeviceGetDefault, CONSOLE_POSITION_TOP,TRUE);

  LoggingConsoleDeviceAdd(ConsoleDeviceGetDefault);
  LoggingDeviceSetDefault(LoggingDeviceFindByType(LOGGING_TYPE_CONSOLE));

  // create the canbus object
  Writeln('Creating the MCP_CAN object');

  CanbusDevice := MCP_CAN.Create(0);     // SPI CS=0.

  // initialise the canbus
  Writeln('Initialising the canbus');

  Res := CanbusDevice.BeginCan(MCP_ANY, CAN_1000KBPS, MCP_16MHZ);

  if (res = CAN_OK) then
  begin
    Writeln('CanbusReadThread.DeviceOpen: MCP2515 Initialized Successfully!');

    // put the canbus into standard mode (it starts in 'loopback' mode)
    Writeln('Taking the canbus device out of loopback mode');

    // if you want to test that your canbus device is properly connected to your pi,
    // then comment out the next three lines (if, writeln, else). This will leave the
    // device in loopback mode, meaning that any message you send from the device
    // will immediately be received by the device. So in the code below, that means
    // message id $108 will be immediately received, since that is what the code
    // before it sends.
    // Once on a real canbus you will need to enable normal mode to receive
    // messages, and will also need at least more more device on the bus, with the
    // bus properly terminated and at least 2 devices switched on, otherwise it
    // won't work.
    if (CanbusDevice.setMode(MCP_NORMAL) <> CAN_OK) then
      Writeln('CanbusReadThread.DeviceOpen: Error setting canbus mode to normal')
    else
    begin
      // send a message
      Writeln('Device is is normal mode. Testing sending a message');

      // put some data into the message
      for i := 1 to 8 do
        rxBuf[i] := i;

      Res := CanbusDevice.sendMsgBuf($108, 0, 8, @rxBuf[1]);
      if (Res = CAN_OK) then
        Writeln('Successfully put a message onto the canbus')
      else
        Writeln('Failed to write a message onto the canbus ' + inttostr(Res) );

      // receive a message - tries forever
      Writeln('Testing receiving a message');
      while (true) do
      begin
        if (CanbusDevice.readMsgBuf(@rxId, @len, @rxBuf) = CAN_OK) then
        begin
          Writeln('Received a canbus message with id ' + rxId.ToString);
        end;
        sleep(10);
      end;


      // destroy the canbus object before termination.
      // the code never actually gets here; this just shows how to free
      // it if you need to.
      Writeln('Termination process');

      CanbusDevice.Free;
    end;
  end
  else
    Writeln('CanbusReadThread.DeviceOpen: Error Initializing MCP2515...');


  // wait here forever so that any on-screen fail messages can be seen.
  Writeln('Wait Forever');

  while true do
  begin
  end;
end.

