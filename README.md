Ultibo Canbus Library
=====================

  This is a port of the MCP_CAN library written by Cory J. Fowler for Arduino.
  The original library is on github here: https://github.com/coryjfowler/MCP_CAN_lib

  Please see the above github for examples on how to use the library in the
  /examples folder.  I have succesfully ported one of the examples and it required
  very little change. Note that some of the functions have been changed to
  use var parameters but most have retained the original C style pointers, so
  you need to be careful when passing buffers etc.

  The library talks to an MCP2515 SPI based canbus controller.

  Basic example. This code will not compile until you implement 'log()' or
  delete that code;


  ```Pascal
  var
    MyCanBus : MCP_CAN;
    Res : longword;
    buf : array[0..7] of byte;

  begin
    MyCanBus := MCP_CAN.Create(0);  // 0 or 1 i.e. which of the two SPI enable pins you want to use.

    // this is as fast as you can go on a chinese MCP2515 board.
    Res := MyCanBus.BeginCan(MCP_ANY, CAN_1000KBPS, MCP_16MHZ);

    if (res = CAN_OK) then
      log('MCP2515 Initialized Successfully.')
    else
      log('Error Initializing MCP2515...');

    // the lib defaults to loopback mode if you don't change it.
    // in loopback mode any message you send is received by the same node and
    // a canbus does not have to be connected.

    // Change from loopback to normal mode to allow messages to be transmitted
    if (FCanBus.setMode(MCP_NORMAL) <> CAN_OK) then
      log('Error setting canbus mode to normal');

    buf[0] := 0;
    buf[1] := 1;
    buf[2] := 2;
    buf[3] := 3;
    buf[4] := 4;
    buf[5] := 5;
    buf[6] := 6;
    buf[7] := 7;

    // send the above buffer onto the canbus with can id $100, length 8.
    // note you do not have to send 8 bytes, but you must send at least 1 byte.
    res := FCanBus.sendMsgBuf($100, 8, @buf[0]);

    // check res here for CAN_OK
  end.
  ```

  This library will work with the multitude of Arduino SPI canbus boards you
  can buy on eBay for couple of quid. However, when using one of these boards
  with Raspberry PI you must either use a level shifter or modify the board
  because the PI is a 3.3v device and all of the boards are 5v devices. Luckily
  the board only requires 5v for the Canbus transceiver so it is possible to
  get the right voltage levels on the SPI pins with a small modification. This
  is easier and neater, and details can be found here;

  https://www.raspberrypi.org/forums/viewtopic.php?t=141052
  or here;
  https://vimtut0r.com/2017/01/17/can-bus-with-raspberry-pi-howtoquickstart-mcp2515-kernel-4-4-x/

  My boards are mostly like that second one but in my case I cut a trace on the
  back of the board and soldered to the capacitor on the front.

  Note that if you do not either modify the board or use a level shifter you
  will blow the input pins on your PI.

