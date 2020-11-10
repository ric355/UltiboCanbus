unit canbus;

{$mode objfpc}{$H+}
{$define DEBUG_MODE}

{
  canbus.pas
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
    res := FCanBus.sendMsgBuf($100, 8, @buf[0]);

    // check res here for CAN_OK
  end.

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

  My boards are mostl like that second one but in my case I cut a trace on the
  back of the board and soldered to the capacitor on the front.

  Note that if you do not either modify the board or use a level shifter you
  will blow the input pins on your PI.


  Original header from MCP_CAN.cpp. This port uses the same license.
  I did no heavy lifting here. All thanks go to Cory J. Fowler for the
  library.

  2012 Copyright (c) Seeed Technology Inc.  All right reserved.
  2017 Copyright (c) Cory J. Fowler  All Rights Reserved.
  Author: Loovee
  Contributor: Cory J. Fowler
  2017-09-25
  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.
  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.
  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-
  1301  USA
}

interface

uses
  GlobalTypes,
  threads,
  Classes
  , SysUtils
  , SPI
  , GlobalConst
  , Devices
  {$ifdef RPI1}
  , RaspberryPi
  , BCM2835
  , BCM2708
  {$endif}
  {$ifdef ZERO}
  , RaspberryPi
  , BCM2835
  , BCM2708
  {$endif}
  {$ifdef RPI2}
  , RaspberryPi2
  , BCM2836
  , BCM2709
  {$endif}
  {$ifdef RPI3}
  , RaspberryPi3
  , BCM2837
  , BCM2710
  {$endif}
  ;

type
    INT32U = longword;
    PINT32U = ^INT32U;
    INT8U = byte;
    PINT8U = ^INT8U;
    uint16_t = word;

const

  SPI_TRANSFER = SPI_TRANSFER_PIO;

  MAX_CHAR_IN_MESSAGE = 8;

  TIMEOUTVALUE    = 100;
  MCP_SIDH        = 0;
  MCP_SIDL        = 1;
  MCP_EID8        = 2;
  MCP_EID0        = 3;

  MCP_TXB_EXIDE_M     = $08;                                        // In TXBnSIDL                  */
  MCP_DLC_MASK        = $0F;                                     // 4 LSBits                     */
  MCP_RTR_MASK        = $40;                                     // (1<<6) Bit 6                 */

  MCP_RXB_RX_ANY      = $60;
  MCP_RXB_RX_EXT      = $40;
  MCP_RXB_RX_STD      = $20;
  MCP_RXB_RX_STDEXT   = $00;
  MCP_RXB_RX_MASK     = $60;
  MCP_RXB_BUKT_MASK   = (1<<2);

{
** Bits in the TXBnCTRL registers.
}
  MCP_TXB_TXBUFE_M    = $80;
  MCP_TXB_ABTF_M      = $40;
  MCP_TXB_MLOA_M      = $20;
  MCP_TXB_TXERR_M     = $10;
  MCP_TXB_TXREQ_M     = $08;
  MCP_TXB_TXIE_M      = $04;
  MCP_TXB_TXP10_M     = $03;

  MCP_TXB_RTR_M       = $40;                                        //* In TXBnDLC                   */
  MCP_RXB_IDE_M       = $08;                                        //* In RXBnSIDL                  */
  MCP_RXB_RTR_M       = $40;                                        //* In RXBnDLC                   */

  MCP_STAT_RXIF_MASK   = ($03);
  MCP_STAT_RX0IF       = (1<<0);
  MCP_STAT_RX1IF       = (1<<1);

  MCP_EFLG_RX1OVR     = (1<<7);
  MCP_EFLG_RX0OVR     = (1<<6);
  MCP_EFLG_TXBO       = (1<<5);
  MCP_EFLG_TXEP       = (1<<4);
  MCP_EFLG_RXEP       = (1<<3);
  MCP_EFLG_TXWAR      = (1<<2);
  MCP_EFLG_RXWAR      = (1<<1);
  MCP_EFLG_EWARN      = (1<<0);
  MCP_EFLG_ERRORMASK  = ($F8);                                      //* 5 MS-Bits                    */

  MCP_BxBFS_MASK    = $30;
  MCP_BxBFE_MASK    = $0C;
  MCP_BxBFM_MASK    = $03;

  MCP_BxRTS_MASK    = $38;
  MCP_BxRTSM_MASK   = $07;

{/*
 *   Define MCP2515 register addresses
 */
 }
  MCP_RXF0SIDH    = $00;
  MCP_RXF0SIDL    = $01;
  MCP_RXF0EID8    = $02;
  MCP_RXF0EID0    = $03;
  MCP_RXF1SIDH    = $04;
  MCP_RXF1SIDL    = $05;
  MCP_RXF1EID8    = $06;
  MCP_RXF1EID0    = $07;
  MCP_RXF2SIDH    = $08;
  MCP_RXF2SIDL    = $09;
  MCP_RXF2EID8    = $0A;
  MCP_RXF2EID0    = $0B;
  MCP_BFPCTRL     = $0C;
  MCP_TXRTSCTRL   = $0D;
  MCP_CANSTAT     = $0E;
  MCP_CANCTRL     = $0F;
  MCP_RXF3SIDH    = $10;
  MCP_RXF3SIDL    = $11;
  MCP_RXF3EID8    = $12;
  MCP_RXF3EID0    = $13;
  MCP_RXF4SIDH    = $14;
  MCP_RXF4SIDL    = $15;
  MCP_RXF4EID8    = $16;
  MCP_RXF4EID0    = $17;
  MCP_RXF5SIDH    = $18;
  MCP_RXF5SIDL    = $19;
  MCP_RXF5EID8    = $1A;
  MCP_RXF5EID0    = $1B;
  MCP_TEC            = $1C;
  MCP_REC            = $1D;
  MCP_RXM0SIDH    = $20;
  MCP_RXM0SIDL    = $21;
  MCP_RXM0EID8    = $22;
  MCP_RXM0EID0    = $23;
  MCP_RXM1SIDH    = $24;
  MCP_RXM1SIDL    = $25;
  MCP_RXM1EID8    = $26;
  MCP_RXM1EID0    = $27;
  MCP_CNF3        = $28;
  MCP_CNF2        = $29;
  MCP_CNF1        = $2A;
  MCP_CANINTE        = $2B;
  MCP_CANINTF        = $2C;
  MCP_EFLG        = $2D;
  MCP_TXB0CTRL    = $30;
  MCP_TXB1CTRL    = $40;
  MCP_TXB2CTRL    = $50;
  MCP_RXB0CTRL    = $60;
  MCP_RXB0SIDH    = $61;
  MCP_RXB1CTRL    = $70;
  MCP_RXB1SIDH    = $71;


  MCP_TX_INT          = $1C;                                    //* Enable all transmit interrup ts  */
  MCP_TX01_INT        = $0C;                                    //* Enable TXB0 and TXB1 interru pts */
  MCP_RX_INT          = $03;                                    //* Enable receive interrupts        */
  MCP_NO_INT          = $00;                                    //* Disable all interrupts           */

  MCP_TX01_MASK       = $14;
  MCP_TX_MASK        = $54;

{/*
 *   Define SPI Instruction Set
 */}

  MCP_WRITE           = $02;

  MCP_READ            = $03;

  MCP_BITMOD          = $05;

  MCP_LOAD_TX0        = $40;
  MCP_LOAD_TX1        = $42;
  MCP_LOAD_TX2        = $44;

  MCP_RTS_TX0         = $81;
  MCP_RTS_TX1         = $82;
  MCP_RTS_TX2         = $84;
  MCP_RTS_ALL         = $87;

  MCP_READ_RX0        = $90;
  MCP_READ_RX1        = $94;

  MCP_READ_STATUS     = $A0;

  MCP_RX_STATUS       = $B0;

  MCP_RESET           = $C0;


{/*
 *   CANCTRL Register Values
 */}

  MCP_NORMAL     = $00;
  MCP_SLEEP      = $20;
  MCP_LOOPBACK   = $40;
  MCP_LISTENONLY = $60;
  MODE_CONFIG     = $80;
  MODE_POWERUP    = $E0;
  MODE_MASK       = $E0;
  ABORT_TX        = $10;
  MODE_ONESHOT    = $08;
  CLKOUT_ENABLE   = $04;
  CLKOUT_DISABLE  = $00;
  CLKOUT_PS1      = $00;
  CLKOUT_PS2      = $01;
  CLKOUT_PS4      = $02;
  CLKOUT_PS8      = $03;


{/*
 *   CNF1 Register Values
 */}

  SJW1            = $00;
  SJW2            = $40;
  SJW3            = $80;
  SJW4            = $C0;


{/*
 *   CNF2 Register Values
 */}

  BTLMODE         = $80;
  SAMPLE_1X       = $00;
  SAMPLE_3X       = $40;


{/*
 *   CNF3 Register Values
 */}

  SOF_ENABLE      = $80;
  SOF_DISABLE     = $00;
  WAKFIL_ENABLE   = $40;
  WAKFIL_DISABLE  = $00;


{/*
 *   CANINTF Register Bits
 */}

  MCP_RX0IF       = $01;
  MCP_RX1IF       = $02;
  MCP_TX0IF       = $04;
  MCP_TX1IF       = $08;
  MCP_TX2IF       = $10;
  MCP_ERRIF       = $20;
  MCP_WAKIF       = $40;
  MCP_MERRF       = $80;


{/*
 *  Speed 8M
 */}

  MCP_8MHz_1000kBPS_CFG1 = ($00);
  MCP_8MHz_1000kBPS_CFG2 = ($C0);  // Enabled SAM bit     */
  MCP_8MHz_1000kBPS_CFG3 = ($80);  // Sample point at 75% */

  MCP_8MHz_500kBPS_CFG1 = ($00);
  MCP_8MHz_500kBPS_CFG2 = ($D1);   // Enabled SAM bit     */
  MCP_8MHz_500kBPS_CFG3 = ($81);   // Sample point at 75% */

  MCP_8MHz_250kBPS_CFG1 = ($80);   // Increased SJW       */
  MCP_8MHz_250kBPS_CFG2 = ($E5);   // Enabled SAM bit     */
  MCP_8MHz_250kBPS_CFG3 = ($83);   // Sample point at 75% */

  MCP_8MHz_200kBPS_CFG1 = ($80);   // Increased SJW       */
  MCP_8MHz_200kBPS_CFG2 = ($F6);   // Enabled SAM bit     */
  MCP_8MHz_200kBPS_CFG3 = ($84);   // Sample point at 75% */

  MCP_8MHz_125kBPS_CFG1 = ($81);   // Increased SJW       */
  MCP_8MHz_125kBPS_CFG2 = ($E5);   // Enabled SAM bit     */
  MCP_8MHz_125kBPS_CFG3 = ($83);   // Sample point at 75% */

  MCP_8MHz_100kBPS_CFG1 = ($81);   // Increased SJW       */
  MCP_8MHz_100kBPS_CFG2 = ($F6);   // Enabled SAM bit     */
  MCP_8MHz_100kBPS_CFG3 = ($84);   // Sample point at 75% */

  MCP_8MHz_80kBPS_CFG1 = ($84);    // Increased SJW       */
  MCP_8MHz_80kBPS_CFG2 = ($D3);    // Enabled SAM bit     */
  MCP_8MHz_80kBPS_CFG3 = ($81);    // Sample point at 75% */

  MCP_8MHz_50kBPS_CFG1 = ($84);    // Increased SJW       */
  MCP_8MHz_50kBPS_CFG2 = ($E5);    // Enabled SAM bit     */
  MCP_8MHz_50kBPS_CFG3 = ($83);    // Sample point at 75% */

  MCP_8MHz_40kBPS_CFG1 = ($84);    // Increased SJW       */
  MCP_8MHz_40kBPS_CFG2 = ($F6);    // Enabled SAM bit     */
  MCP_8MHz_40kBPS_CFG3 = ($84);    // Sample point at 75% */

  MCP_8MHz_33k3BPS_CFG1 = ($85);   // Increased SJW       */
  MCP_8MHz_33k3BPS_CFG2 = ($F6);   // Enabled SAM bit     */
  MCP_8MHz_33k3BPS_CFG3 = ($84);   // Sample point at 75% */

  MCP_8MHz_31k25BPS_CFG1 = ($87);  // Increased SJW       */
  MCP_8MHz_31k25BPS_CFG2 = ($E5);  // Enabled SAM bit     */
  MCP_8MHz_31k25BPS_CFG3 = ($83);  // Sample point at 75% */

  MCP_8MHz_20kBPS_CFG1 = ($89);    // Increased SJW       */
  MCP_8MHz_20kBPS_CFG2 = ($F6);    // Enabled SAM bit     */
  MCP_8MHz_20kBPS_CFG3 = ($84);    // Sample point at 75% */

  MCP_8MHz_10kBPS_CFG1 = ($93);    // Increased SJW       */
  MCP_8MHz_10kBPS_CFG2 = ($F6);    // Enabled SAM bit     */
  MCP_8MHz_10kBPS_CFG3 = ($84);    // Sample point at 75% */

  MCP_8MHz_5kBPS_CFG1 = ($A7);     // Increased SJW       */
  MCP_8MHz_5kBPS_CFG2 = ($F6);     // Enabled SAM bit     */
  MCP_8MHz_5kBPS_CFG3 = ($84);     // Sample point at 75% */

{
 speed 16M
}
  MCP_16MHz_1000kBPS_CFG1 = ($00);
  MCP_16MHz_1000kBPS_CFG2 = ($CA);
  MCP_16MHz_1000kBPS_CFG3 = ($81);    // Sample point at 75% */

  MCP_16MHz_500kBPS_CFG1 = ($40);     // Increased SJW       */
  MCP_16MHz_500kBPS_CFG2 = ($E5);
  MCP_16MHz_500kBPS_CFG3 = ($83);     // Sample point at 75% */

  MCP_16MHz_250kBPS_CFG1 = ($41);
  MCP_16MHz_250kBPS_CFG2 = ($E5);
  MCP_16MHz_250kBPS_CFG3 = ($83);     // Sample point at 75% */

  MCP_16MHz_200kBPS_CFG1 = ($41);     // Increased SJW       */
  MCP_16MHz_200kBPS_CFG2 = ($F6);
  MCP_16MHz_200kBPS_CFG3 = ($84);     // Sample point at 75% */

  MCP_16MHz_125kBPS_CFG1 = ($43);     // Increased SJW       */
  MCP_16MHz_125kBPS_CFG2 = ($E5);
  MCP_16MHz_125kBPS_CFG3 = ($83);     // Sample point at 75% */

  MCP_16MHz_100kBPS_CFG1 = ($44);     // Increased SJW       */
  MCP_16MHz_100kBPS_CFG2 = ($E5);
  MCP_16MHz_100kBPS_CFG3 = ($83);     // Sample point at 75% */

  MCP_16MHz_80kBPS_CFG1 = ($44);      // Increased SJW       */
  MCP_16MHz_80kBPS_CFG2 = ($F6);
  MCP_16MHz_80kBPS_CFG3 = ($84);      // Sample point at 75% */

  MCP_16MHz_50kBPS_CFG1 = ($47);      // Increased SJW       */
  MCP_16MHz_50kBPS_CFG2 = ($F6);
  MCP_16MHz_50kBPS_CFG3 = ($84);      // Sample point at 75% */

  MCP_16MHz_40kBPS_CFG1 = ($49);      // Increased SJW       */
  MCP_16MHz_40kBPS_CFG2 = ($F6);
  MCP_16MHz_40kBPS_CFG3 = ($84);      // Sample point at 75% */

  MCP_16MHz_33k3BPS_CFG1 = ($4E);
  MCP_16MHz_33k3BPS_CFG2 = ($E5);
  MCP_16MHz_33k3BPS_CFG3 = ($83);     // Sample point at 75% */

  MCP_16MHz_20kBPS_CFG1 = ($53);      // Increased SJW       */
  MCP_16MHz_20kBPS_CFG2 = ($F6);
  MCP_16MHz_20kBPS_CFG3 = ($84);      // Sample point at 75% */

  MCP_16MHz_10kBPS_CFG1 = ($67);      // Increased SJW       */
  MCP_16MHz_10kBPS_CFG2 = ($F6);
  MCP_16MHz_10kBPS_CFG3 = ($84);      // Sample point at 75% */

  MCP_16MHz_5kBPS_CFG1 = ($3F);
  MCP_16MHz_5kBPS_CFG2 = ($FF);
  MCP_16MHz_5kBPS_CFG3 = ($87);       // Sample point at 68% */

{
 *  speed 20M
 */}

  MCP_20MHz_1000kBPS_CFG1 = ($00);
  MCP_20MHz_1000kBPS_CFG2 = ($D9);
  MCP_20MHz_1000kBPS_CFG3 = ($82);     // Sample point at 80% */

  MCP_20MHz_500kBPS_CFG1 = ($40);     // Increased SJW       */
  MCP_20MHz_500kBPS_CFG2 = ($F6);
  MCP_20MHz_500kBPS_CFG3 = ($84);     // Sample point at 75% */

  MCP_20MHz_250kBPS_CFG1 = ($41);     // Increased SJW       */
  MCP_20MHz_250kBPS_CFG2 = ($F6);
  MCP_20MHz_250kBPS_CFG3 = ($84);     // Sample point at 75% */

  MCP_20MHz_200kBPS_CFG1 = ($44);     // Increased SJW       */
  MCP_20MHz_200kBPS_CFG2 = ($D3);
  MCP_20MHz_200kBPS_CFG3 = ($81);     // Sample point at 80% */

  MCP_20MHz_125kBPS_CFG1 = ($44);     // Increased SJW       */
  MCP_20MHz_125kBPS_CFG2 = ($E5);
  MCP_20MHz_125kBPS_CFG3 = ($83);     // Sample point at 75% */

  MCP_20MHz_100kBPS_CFG1 = ($44);     // Increased SJW       */
  MCP_20MHz_100kBPS_CFG2 = ($F6);
  MCP_20MHz_100kBPS_CFG3 = ($84);     // Sample point at 75% */

  MCP_20MHz_80kBPS_CFG1 = ($C4);      // Increased SJW       */
  MCP_20MHz_80kBPS_CFG2 = ($FF);
  MCP_20MHz_80kBPS_CFG3 = ($87);      // Sample point at 68% */

  MCP_20MHz_50kBPS_CFG1 = ($49);      // Increased SJW       */
  MCP_20MHz_50kBPS_CFG2 = ($F6);
  MCP_20MHz_50kBPS_CFG3 = ($84);      // Sample point at 75% */

  MCP_20MHz_40kBPS_CFG1 = ($18);
  MCP_20MHz_40kBPS_CFG2 = ($D3);
  MCP_20MHz_40kBPS_CFG3 = ($81);      // Sample point at 80% */


  MCPDEBUG        = (0);
  MCPDEBUG_TXBUF  = (0);
  MCP_N_TXBUFFERS = (3);

  MCP_RXBUF_0 = (MCP_RXB0SIDH);
  MCP_RXBUF_1 = (MCP_RXB1SIDH);

  MCP2515_OK         = 0;
  MCP2515_FAIL       = 1;
  MCP_ALLTXBUSY      = 2;

  CANDEBUG   = 1;

  CANUSELOOP = 0;

  CANSENDTIMEOUT = (200);                                            //* milliseconds                 */

{/*
 *   initial value of gCANAutoProcess
 */}

  CANAUTOPROCESS = (1);
  CANAUTOON  = (1);
  CANAUTOOFF = (0);

  CAN_STDID = (0);
  CAN_EXTID = (1);

  CANDEFAULTIDENT    = ($55CC);
  CANDEFAULTIDENTEXT = (CAN_EXTID);

  MCP_STDEXT   = 0;                                                  //* Standard and Extended        */
  MCP_STD      = 1;                                                  //* Standard IDs ONLY            */
  MCP_EXT      = 2;                                                  //* Extended IDs ONLY            */
  MCP_ANY      = 3;                                                  //* Disables Masks and Filters   */

  MCP_20MHZ    = 0;
  MCP_16MHZ    = 1;
  MCP_8MHZ     = 2;

  CAN_4K096BPS = 0;
  CAN_5KBPS    = 1;
  CAN_10KBPS   = 2;
  CAN_20KBPS   = 3;
  CAN_31K25BPS = 4;
  CAN_33K3BPS  = 5;
  CAN_40KBPS   = 6;
  CAN_50KBPS   = 7;
  CAN_80KBPS   = 8;
  CAN_100KBPS  = 9;
  CAN_125KBPS  = 10;
  CAN_200KBPS  = 11;
  CAN_250KBPS  = 12;
  CAN_500KBPS  = 13;
  CAN_1000KBPS = 14;

  CAN_OK             = 0;
  CAN_FAILINIT       = 1;
  CAN_FAILTX         = 2;
  CAN_MSGAVAIL       = 3;
  CAN_NOMSG          = 4;
  CAN_CTRLERROR      = 5;
  CAN_GETTXBFTIMEOUT = 6;
  CAN_SENDMSGTIMEOUT = 7;
  CAN_SENDMSGABORT   = 8;
  CAN_MESSAGELOST    = 9;
  CAN_TXERRORDETECTED = 10;
  CAN_FAIL       = ($ff);

  CAN_MAX_CHAR_IN_MESSAGE = (8);


type
  MCP_CAN=packed class(TObject)

  private
    FCanbusLock : TSpinHandle;

    m_nExtFlg : INT8U;                                                  // Identifier Type
                                                                        // Extended (29 bit) or Standard (11 bit)
    m_nID : INT32U;                                                      // CAN ID
    m_nDlc : INT8U;                                                     // Data Length Code
    m_nDta : packed array[0..MAX_CHAR_IN_MESSAGE - 1] of INT8U;                // Data array
    m_nRtr : INT8U;                                                     // Remote request flag
    m_nfilhit : INT8U;                                                  // The number of the filter that matched the message
    mcpMode : INT8U;                                                    // Mode to return to after configurations are performed.
    SPIDevice : PSPIDevice;
    MCP_CS : INT8U;                                                     // SPI port being used

    procedure mcp2515_reset;                                           // Soft Reset MCP2515

    function mcp2515_readRegister(address : INT8U) : INT8U;                    // Read MCP2515 register

    procedure mcp2515_readRegisterS(address : INT8U;                     // Read MCP2515 successive registers
	                            values : PINT8U;                     // INT8U values[],
                                    n : INT8U);

    procedure mcp2515_setRegister(address : INT8U;                       // Set MCP2515 register
                                  value : INT8U);

    procedure mcp2515_setRegisterS(address : INT8U;                      // Set MCP2515 successive registers
                                   values : PINT8U;                      // INT8U values[],
                                   n : INT8U);

    procedure mcp2515_initCANBuffers;

    procedure mcp2515_modifyRegister(address : INT8U;                    // Set specific bit(s) of a register
                                     mask : INT8U;
                                     data : INT8U);

    function mcp2515_readStatus : INT8U;                                     // Read MCP2515 Status
    function mcp2515_setCANCTRL_Mode(newmode : INT8U) : INT8U;                 // Set mode
    function mcp2515_configRate(canSpeed : INT8U;                      // Set baud rate
                                canClock : INT8U) : INT8U ;

    function mcp2515_init(canIDMode : INT8U;                            // Initialize Controller
                       canSpeed : INT8U;
                       canClock : INT8U) : INT8U;

    procedure mcp2515_write_mf(mcp_addr : INT8U;                        // Write CAN Mask or Filter
                            ext : INT8U;
                            id : INT32U);

    procedure mcp2515_write_id(mcp_addr : INT8U;                        // Write CAN ID
                            ext : INT8U;
                            id : INT32U);

    procedure mcp2515_read_id(mcp_addr : INT8U ;                 // Read CAN ID
                                var ext : INT8U;
                                var id : INT32U);

    procedure mcp2515_write_canMsg(buffer_sidh_addr : INT8U);          // Write CAN message
    procedure mcp2515_read_canMsg(buffer_sidh_addr : INT8U);            // Read CAN message
    function mcp2515_getNextFreeTXBuf(txbuf_n : PINT8U) : INT8U;                     // Find empty transmit buffer

{/*********************************************************************************************************
 *  CAN operator function
 *********************************************************************************************************/
 }

    function setMsg(id : INT32U; rtr : INT8U; ext : INT8U; len : INT8U; pData : PINT8U) : INT8U;        // Set message
    function clearMsg : INT8U;                                                   // Clear all message to zero
    function readMsg : INT8U;                                                    // Read message
    function sendMsg : INT8U;                                                    // Send message

  public
    m_bufsource : int8u;
    m_readstatusclocks : int64;
    m_modifyregisterclocks : int64;
    m_readregisterclocks : int64;
    m_readregistersclocks : int64;
    m_setregisterclocks : int64;
    m_setregistersclocks : int64;
    constructor Create(_CS : INT8U );
    destructor Destroy; override;
    function begincan(idmodeset : INT8U; speedset : INT8U; clockset : INT8U) : INT8U;       // Initialize controller parameters
    function init_Mask(num : INT8U; ext : INT8U; ulData : INT32U) : INT8U;               // Initialize Mask(s)
    function init_Mask(num : INT8U; ulData : INT32U) : INT8U;                          // Initialize Mask(s)
    function init_Filt(num : INT8U; ext : INT8U; ulData :  INT32U) : INT8U;               // Initialize Filter(s)
    function init_Filt(num : INT8U; ulData :  INT32U) : INT8U;                          // Initialize Filter(s)
    function setMode(opMode : INT8U) : INT8U;                                        // Set operational mode
    function sendMsgBuf(id : INT32U; ext : INT8U; len : INT8U; buf : PINT8U) : INT8U;      // Send message to transmit buffer
    function sendMsgBuf(id : INT32U; len : INT8U; buf :  PINT8U) : INT8U;                 // Send message to transmit buffer
    function readMsgBuf(id : PINT32U; ext : PINT8U; len : PINT8U; buf : PINT8U) : INT8U;   // Read message from receive buffer
    function readMsgBuf(id : PINT32U; len : PINT8U; buf : PINT8U) : INT8U;               // Read message from receive buffer
    function checkReceive : INT8U;                                           // Check for received data
    function checkError : INT8U;                                             // Check for errors
    function getError : INT8U;                                               // Check for errors
    function errorCountRX : INT8U;                                           // Get error count
    function errorCountTX : INT8U;                                           // Get error count
    function enOneShotTX : INT8U;                                            // Enable one-shot transmission
    function disOneShotTX : INT8U;                                           // Disable one-shot transmission
    function abortTX : INT8U;                                                // Abort queued transmission(s)
    function setGPO(data : INT8U) : INT8U;                                           // Sets GPO
    function getGPI : INT8U;                                                 // Reads GPI
    function CanResultToString(res : INT8U) : string;
    property spidev : PSPIDevice read SPIDevice;
  end;

  TLoggerProc = procedure(amsg : string);

implementation

uses
  platform,
  logoutput;


{/*********************************************************************************************************
** Function name:           mcp2515_reset
** Descriptions:            Performs a software reset
*********************************************************************************************************/}

procedure MCP_CAN.mcp2515_reset;
var
  b, r : byte;
  count : longword;
  res : longword;
begin
  b := MCP_RESET;
  count := 0;

  res := SPIDeviceWriteRead(SPIDevice, MCP_CS, @b, @r, 1, SPI_TRANSFER, count);
  if (res <> ERROR_SUCCESS) then
     log('mcp2515_reset: error returned from SPIDeviceWriteRead ' + inttostr(res));
  sleep(1);
end;

{********************************************************************************************************
** Function name:           mcp2515_readRegister
** Descriptions:            Read data register
********************************************************************************************************}
function MCP_CAN.mcp2515_readRegister(address : INT8U) : INT8U;
var
  count : longword;
  outbuf, inbuf : packed array[1..3] of byte;
  res : longword;
begin
  outbuf[1] := MCP_READ;
  outbuf[2] := address;
  count := 0;
  m_readregisterclocks := ClockGetTotal;
  res := SPIDeviceWriteRead(SPIDevice, MCP_CS, @outbuf[1], @inbuf[1], 3, SPI_TRANSFER, count);
  m_readregisterclocks := ClockGetTotal - m_readregisterclocks;
  if (res <> ERROR_SUCCESS) then
     log('mcp2515_readRegister: error returned from SPIDeviceWriteRead ' + inttostr(res));
  Result := inbuf[3];
end;

{********************************************************************************************************
** Function name:           mcp2515_readRegisterS
** Descriptions:            Reads sucessive data registers
********************************************************************************************************}
procedure MCP_CAN.mcp2515_readRegisterS(address : INT8U;
	                            values : PINT8U;
                                    n : INT8U);
var
  count : longword;
  outbuf, inbuf : packed array[1..50] of byte;
  res : longword;
begin
  outbuf[1] := MCP_READ;
  outbuf[2] := address;
  // mcp2515 has auto-increment of address-pointer
  // note that values must be a large enough array to hold the resulting data.
  count := 0;
  m_readregistersclocks := ClockGetTotal;
  res := SPIDeviceWriteRead(SPIDevice, MCP_CS, @outbuf[1], @inbuf[1], n+2, SPI_TRANSFER, count);
  m_readregistersclocks := ClockGetTotal - m_readregistersclocks;
  if (res <> ERROR_SUCCESS) then
     log('mcp2515_readRegisterS: error returned from SPIDeviceWriteRead ' + inttostr(res));
  move(inbuf[3], values^, n);
end;

{********************************************************************************************************
** Function name:           mcp2515_setRegister
** Descriptions:            Sets data register
********************************************************************************************************}
procedure MCP_CAN.mcp2515_setRegister(address : INT8U;
                              value : INT8U);
var
  res, count : longword;
  inbuf, outbuf : packed array[1..3] of byte;
begin
  outbuf[1] := MCP_WRITE;
  outbuf[2] := address;
  outbuf[3] := value;
  count := 0;
  m_setregisterclocks := ClockGetTotal;
  res := SPIDeviceWriteRead(SPIDevice, MCP_CS, @outbuf[1], @inbuf[1], 3, SPI_TRANSFER, count);
  m_setregisterclocks := ClockGetTotal - m_setregisterclocks;
  if (res <> ERROR_SUCCESS) then
   log('mcp2515_setRegister: error returned from SPIDeviceWriteRead ' + inttostr(res));
end;

{********************************************************************************************************
** Function name:           mcp2515_setRegisterS
** Descriptions:            Sets sucessive data registers
********************************************************************************************************}
procedure MCP_CAN.mcp2515_setRegisterS(address : INT8U;
                                   values : PINT8U;
                                   n : INT8U);
var
  i : INT8U;
  res, count : longword;
  outbuf, inbuf : packed array[1..50] of byte;
begin

  outbuf[1] := MCP_WRITE;
  outbuf[2] := address;
  for i := 0 to n-1 do
    outbuf[3+i] := (values+i)^;
  count := 0;

  m_setregistersclocks := ClockGetTotal;
  res := SPIDeviceWriteRead(SPIDevice, MCP_CS, @outbuf[1], @inbuf[1], n+2, SPI_TRANSFER, count);

  m_setregistersclocks := ClockGetTotal - m_setregistersclocks;
  if (res <> ERROR_SUCCESS) then
     log('mcp2515_setRegisterS: error returned from SPIDeviceWriteRead ' + inttostr(res));
end;

{********************************************************************************************************
** Function name:           mcp2515_modifyRegister
** Descriptions:            Sets specific bits of a register
********************************************************************************************************}
//void mcp2515_modifyRegister(const INT8U address, const INT8U mask, const INT8U data)
procedure MCP_CAN.mcp2515_modifyRegister(address : INT8U;
                                     mask : INT8U;
                                     data : INT8U);
var
  res, count : longword;
  outbuf : packed array[1..4] of byte;
  inbuf : packed array[1..4] of byte;
begin
  outbuf[1] := MCP_BITMOD;
  outbuf[2] := address;
  outbuf[3] := mask;
  outbuf[4] := data;
  count := 0;
  m_modifyregisterclocks := ClockGetTotal;
  res := SPIDeviceWriteRead(SPIDevice, MCP_CS, @outbuf[1], @inbuf[1], 4, SPI_TRANSFER, count);
  m_modifyregisterclocks := ClockGetTotal - m_modifyregisterclocks;
  if (res <> ERROR_SUCCESS) then
     log('mcp2515_modifyRegister: error returned from SPIDeviceWriteRead ' + inttostr(res));
end;

{********************************************************************************************************
** Function name:           mcp2515_readStatus
** Descriptions:            Reads status register
********************************************************************************************************}
function MCP_CAN.mcp2515_readStatus : INT8U;
var
  inbuf, outbuf : packed array[1..2] of byte;
  res, count : longword;
begin
  outbuf[1] := MCP_READ_STATUS;
  count := 0;
  m_readstatusclocks := ClockGetTotal;
  res := SPIDeviceWriteRead(SPIDevice, MCP_CS, @outbuf, @inbuf, 2, SPI_TRANSFER, count);
  m_readstatusclocks := ClockGetTotal - m_readstatusclocks;
  if (res <> ERROR_SUCCESS) then
  begin
     log('mcp2515_readStatus: error returned from SPIDeviceWriteRead ' + inttostr(res)
      + ' spidevice=' + inttohex(longword(SPIDevice), 8)
      + ' device signature=' +inttohex(longword(spidevice^.device.signature), 8));
     threadhalt(0);
  end;

  Result := inbuf[2];
end;

{********************************************************************************************************
** Function name:           setMode
** Descriptions:            Sets control mode
********************************************************************************************************}
function MCP_CAN.setMode(opMode : INT8U) : INT8U;
begin
  mcpMode := opMode;
  Result := mcp2515_setCANCTRL_Mode(mcpMode);
end;

{********************************************************************************************************
** Function name:           mcp2515_setCANCTRL_Mode
** Descriptions:            Set control mode
********************************************************************************************************}
function MCP_CAN.mcp2515_setCANCTRL_Mode(newmode : INT8U) : INT8U;
var
  i :   INT8U;
begin
  mcp2515_modifyRegister(MCP_CANCTRL, MODE_MASK, newmode);

  i := mcp2515_readRegister(MCP_CANCTRL);
  i := i and MODE_MASK;

  if (i = newmode) then
    Result := MCP2515_OK
  else
    Result := MCP2515_FAIL;
end;

{********************************************************************************************************
** Function name:           mcp2515_configRate
** Descriptions:            Set baudrate
********************************************************************************************************}
function MCP_CAN.mcp2515_configRate(canSpeed : INT8U;
                            canClock : INT8U) : INT8U;
var
  cfg1, cfg2, cfg3 : INT8U;
  aset : boolean;
begin
    aset := true;
    case (canClock) of
      MCP_8MHZ:
      begin
          case canSpeed of
              CAN_5KBPS:                                               //   5KBPS
              begin
              cfg1 := MCP_8MHz_5kBPS_CFG1;
              cfg2 := MCP_8MHz_5kBPS_CFG2;
              cfg3 := MCP_8MHz_5kBPS_CFG3;
              end;

              CAN_10KBPS:                                              //  10KBPS
              begin
              cfg1 := MCP_8MHz_10kBPS_CFG1;
              cfg2 := MCP_8MHz_10kBPS_CFG2;
              cfg3 := MCP_8MHz_10kBPS_CFG3;
              end;

              CAN_20KBPS:                                              //  20KBPS
              begin
              cfg1 := MCP_8MHz_20kBPS_CFG1;
              cfg2 := MCP_8MHz_20kBPS_CFG2;
              cfg3 := MCP_8MHz_20kBPS_CFG3;
              end;

              CAN_31K25BPS:                                            //  31.25KBPS
              begin
              cfg1 := MCP_8MHz_31k25BPS_CFG1;
              cfg2 := MCP_8MHz_31k25BPS_CFG2;
              cfg3 := MCP_8MHz_31k25BPS_CFG3;
              end;

              CAN_33K3BPS:                                             //  33.33KBPS
              begin
              cfg1 := MCP_8MHz_33k3BPS_CFG1;
              cfg2 := MCP_8MHz_33k3BPS_CFG2;
              cfg3 := MCP_8MHz_33k3BPS_CFG3;
              end;

              CAN_40KBPS:                                              //  40Kbps
              begin
              cfg1 := MCP_8MHz_40kBPS_CFG1;
              cfg2 := MCP_8MHz_40kBPS_CFG2;
              cfg3 := MCP_8MHz_40kBPS_CFG3;
              end;

              CAN_50KBPS:                                              //  50Kbps
              begin
              cfg1 := MCP_8MHz_50kBPS_CFG1;
              cfg2 := MCP_8MHz_50kBPS_CFG2;
              cfg3 := MCP_8MHz_50kBPS_CFG3;
              end;

              CAN_80KBPS:                                              //  80Kbps
              begin
              cfg1 := MCP_8MHz_80kBPS_CFG1;
              cfg2 := MCP_8MHz_80kBPS_CFG2;
              cfg3 := MCP_8MHz_80kBPS_CFG3;
              end;

              CAN_100KBPS:                                             // 100Kbps
              begin
              cfg1 := MCP_8MHz_100kBPS_CFG1;
              cfg2 := MCP_8MHz_100kBPS_CFG2;
              cfg3 := MCP_8MHz_100kBPS_CFG3;
              end;

              CAN_125KBPS:                                             // 125Kbps
              begin
              cfg1 := MCP_8MHz_125kBPS_CFG1;
              cfg2 := MCP_8MHz_125kBPS_CFG2;
              cfg3 := MCP_8MHz_125kBPS_CFG3;
              end;

              CAN_200KBPS:                                             // 200Kbps
              begin
              cfg1 := MCP_8MHz_200kBPS_CFG1;
              cfg2 := MCP_8MHz_200kBPS_CFG2;
              cfg3 := MCP_8MHz_200kBPS_CFG3;
              end;

              CAN_250KBPS:                                             // 250Kbps
              begin
              cfg1 := MCP_8MHz_250kBPS_CFG1;
              cfg2 := MCP_8MHz_250kBPS_CFG2;
              cfg3 := MCP_8MHz_250kBPS_CFG3;
              end;

              CAN_500KBPS:                                             // 500Kbps
              begin
              cfg1 := MCP_8MHz_500kBPS_CFG1;
              cfg2 := MCP_8MHz_500kBPS_CFG2;
              cfg3 := MCP_8MHz_500kBPS_CFG3;
              end;

              CAN_1000KBPS:                                            //   1Mbps
              begin
              cfg1 := MCP_8MHz_1000kBPS_CFG1;
              cfg2 := MCP_8MHz_1000kBPS_CFG2;
              cfg3 := MCP_8MHz_1000kBPS_CFG3;
              end
          else
          begin
            aset := false;
	    Result := MCP2515_FAIL;
          end;
        end;
      end;

      MCP_16MHZ:
      begin
        case canSpeed of
            CAN_5KBPS:                                               //   5Kbps
            begin
            cfg1 := MCP_16MHz_5kBPS_CFG1;
            cfg2 := MCP_16MHz_5kBPS_CFG2;
            cfg3 := MCP_16MHz_5kBPS_CFG3;
            end;

            CAN_10KBPS:                                              //  10Kbps
            begin
            cfg1 := MCP_16MHz_10kBPS_CFG1;
            cfg2 := MCP_16MHz_10kBPS_CFG2;
            cfg3 := MCP_16MHz_10kBPS_CFG3;
            end;

            CAN_20KBPS:                                              //  20Kbps
            begin
            cfg1 := MCP_16MHz_20kBPS_CFG1;
            cfg2 := MCP_16MHz_20kBPS_CFG2;
            cfg3 := MCP_16MHz_20kBPS_CFG3;
            end;

            CAN_33K3BPS:                                              //  20Kbps
            begin
            cfg1 := MCP_16MHz_33k3BPS_CFG1;
            cfg2 := MCP_16MHz_33k3BPS_CFG2;
            cfg3 := MCP_16MHz_33k3BPS_CFG3;
            end;

            CAN_40KBPS:                                              //  40Kbps
            begin
            cfg1 := MCP_16MHz_40kBPS_CFG1;
            cfg2 := MCP_16MHz_40kBPS_CFG2;
            cfg3 := MCP_16MHz_40kBPS_CFG3;
            end;

            CAN_50KBPS:                                              //  50Kbps
            begin
            cfg1 := MCP_16MHz_50kBPS_CFG1;
            cfg2 := MCP_16MHz_50kBPS_CFG2;
            cfg3 := MCP_16MHz_50kBPS_CFG3;
            end;

            CAN_80KBPS:                                              //  80Kbps
            begin
            cfg1 := MCP_16MHz_80kBPS_CFG1;
            cfg2 := MCP_16MHz_80kBPS_CFG2;
            cfg3 := MCP_16MHz_80kBPS_CFG3;
            end;

            CAN_100KBPS:                                             // 100Kbps
            begin
            cfg1 := MCP_16MHz_100kBPS_CFG1;
            cfg2 := MCP_16MHz_100kBPS_CFG2;
            cfg3 := MCP_16MHz_100kBPS_CFG3;
            end;

            CAN_125KBPS:                                             // 125Kbps
            begin
            cfg1 := MCP_16MHz_125kBPS_CFG1;
            cfg2 := MCP_16MHz_125kBPS_CFG2;
            cfg3 := MCP_16MHz_125kBPS_CFG3;
            end;

            CAN_200KBPS:                                             // 200Kbps
            begin
            cfg1 := MCP_16MHz_200kBPS_CFG1;
            cfg2 := MCP_16MHz_200kBPS_CFG2;
            cfg3 := MCP_16MHz_200kBPS_CFG3;
            end;

            CAN_250KBPS:                                             // 250Kbps
            begin
            cfg1 := MCP_16MHz_250kBPS_CFG1;
            cfg2 := MCP_16MHz_250kBPS_CFG2;
            cfg3 := MCP_16MHz_250kBPS_CFG3;
            end;

            CAN_500KBPS:                                             // 500Kbps
            begin
            cfg1 := MCP_16MHz_500kBPS_CFG1;
            cfg2 := MCP_16MHz_500kBPS_CFG2;
            cfg3 := MCP_16MHz_500kBPS_CFG3;
            end;

            CAN_1000KBPS:                                            //   1Mbps
            begin
            cfg1 := MCP_16MHz_1000kBPS_CFG1;
            cfg2 := MCP_16MHz_1000kBPS_CFG2;
            cfg3 := MCP_16MHz_1000kBPS_CFG3;
            end;
          else
          begin
            aset := false;
            Result := MCP2515_FAIL;
          end;
        end;
      end;

      MCP_20MHZ:
      begin
        case canSpeed of
            CAN_40KBPS:                                              //  40Kbps
            begin
            cfg1 := MCP_20MHz_40kBPS_CFG1;
            cfg2 := MCP_20MHz_40kBPS_CFG2;
            cfg3 := MCP_20MHz_40kBPS_CFG3;
            end;

            CAN_50KBPS:                                              //  50Kbps
            begin
            cfg1 := MCP_20MHz_50kBPS_CFG1;
            cfg2 := MCP_20MHz_50kBPS_CFG2;
            cfg3 := MCP_20MHz_50kBPS_CFG3;
            end;

            CAN_80KBPS:                                              //  80Kbps
            begin
            cfg1 := MCP_20MHz_80kBPS_CFG1;
            cfg2 := MCP_20MHz_80kBPS_CFG2;
            cfg3 := MCP_20MHz_80kBPS_CFG3;
            end;

            CAN_100KBPS:                                             // 100Kbps
            begin
            cfg1 := MCP_20MHz_100kBPS_CFG1;
            cfg2 := MCP_20MHz_100kBPS_CFG2;
            cfg3 := MCP_20MHz_100kBPS_CFG3;
            end;

            CAN_125KBPS:                                             // 125Kbps
            begin
            cfg1 := MCP_20MHz_125kBPS_CFG1;
            cfg2 := MCP_20MHz_125kBPS_CFG2;
            cfg3 := MCP_20MHz_125kBPS_CFG3;
            end;

            CAN_200KBPS:                                             // 200Kbps
            begin
            cfg1 := MCP_20MHz_200kBPS_CFG1;
            cfg2 := MCP_20MHz_200kBPS_CFG2;
            cfg3 := MCP_20MHz_200kBPS_CFG3;
            end;

            CAN_250KBPS:                                             // 250Kbps
            begin
            cfg1 := MCP_20MHz_250kBPS_CFG1;
            cfg2 := MCP_20MHz_250kBPS_CFG2;
            cfg3 := MCP_20MHz_250kBPS_CFG3;
            end;

            CAN_500KBPS:                                             // 500Kbps
            begin
            cfg1 := MCP_20MHz_500kBPS_CFG1;
            cfg2 := MCP_20MHz_500kBPS_CFG2;
            cfg3 := MCP_20MHz_500kBPS_CFG3;
            end;

            CAN_1000KBPS:                                            //   1Mbps
            begin
            cfg1 := MCP_20MHz_1000kBPS_CFG1;
            cfg2 := MCP_20MHz_1000kBPS_CFG2;
            cfg3 := MCP_20MHz_1000kBPS_CFG3;
            end;
          else
          begin
            aset := false;
            Result := MCP2515_FAIL;
          end;
        end;
      end;
      else
      begin
        aset := false;
        Result := MCP2515_FAIL;
      end;
    end;

    if (aset) then
    begin
      mcp2515_setRegister(MCP_CNF1, cfg1);
      mcp2515_setRegister(MCP_CNF2, cfg2);
      mcp2515_setRegister(MCP_CNF3, cfg3);
      Result := MCP2515_OK;
    end
    else
     Result := MCP2515_FAIL;
end;

{********************************************************************************************************
** Function name:           mcp2515_initCANBuffers
** Descriptions:            Initialize Buffers, Masks, and Filters
********************************************************************************************************}
procedure MCP_CAN.mcp2515_initCANBuffers;
var
  i, a1, a2, a3 :  INT8U;

  std : INT8U = 0;
  ext : INT8U = 1;
  ulMask : INT32U = $00;
  ulFilt : INT32U = $00;
begin
  mcp2515_write_mf(MCP_RXM0SIDH, ext, ulMask);			{Set both masks to 0           }
  mcp2515_write_mf(MCP_RXM1SIDH, ext, ulMask);			{Mask register ignores ext bit }

                                                                      { Set all filters to 0         }
  mcp2515_write_mf(MCP_RXF0SIDH, ext, ulFilt);			{ RXB0: extended               }
  mcp2515_write_mf(MCP_RXF1SIDH, std, ulFilt);			{ RXB1: standard               }
  mcp2515_write_mf(MCP_RXF2SIDH, ext, ulFilt);			{ RXB2: extended               }
  mcp2515_write_mf(MCP_RXF3SIDH, std, ulFilt);			{ RXB3: standard               }
  mcp2515_write_mf(MCP_RXF4SIDH, ext, ulFilt);
  mcp2515_write_mf(MCP_RXF5SIDH, std, ulFilt);

                                                                      { Clear, deactivate the three  }
                                                                      { transmit buffers             }
                                                                      { TXBnCTRL -> TXBnD7           }
  a1 := MCP_TXB0CTRL;
  a2 := MCP_TXB1CTRL;
  a3 := MCP_TXB2CTRL;
  for i := 0 to 13 do
  begin                                          { in-buffer loop               }
      mcp2515_setRegister(a1, 0);
      mcp2515_setRegister(a2, 0);
      mcp2515_setRegister(a3, 0);
      a1 := a1 + 1;
      a2 := a2 + 1;
      a3 := a3 + 1;
  end;

  mcp2515_setRegister(MCP_RXB0CTRL, 0);
  mcp2515_setRegister(MCP_RXB1CTRL, 0);
end;


{********************************************************************************************************
** Function name:           mcp2515_init
** Descriptions:            Initialize the controller
********************************************************************************************************}
function MCP_CAN.mcp2515_init(canIDMode : INT8U;
                   canSpeed : INT8U;
                   canClock : INT8U) : INT8U;

var
  res : INT8U;
begin
  mcp2515_reset;

  mcpMode := MCP_LOOPBACK;

  res := mcp2515_setCANCTRL_Mode(MODE_CONFIG);
  if (res > 0) then
  begin
{$ifdef DEBUG_MODE}
    Log('Entering Configuration Mode Failure...');
{$endif}
    Result := res;
    exit;
  end;
{$ifdef DEBUG_MODE}
  Log('Entering Configuration Mode Successful!');
{$endif}

  // Set Baudrate
  if (mcp2515_configRate(canSpeed, canClock) <> MCP2515_OK) then
  begin
{$ifdef DEBUG_MODE}
    Log('Setting Baudrate Failure...');
{$endif}
    Result := res;
    exit;
  end;

{$ifdef DEBUG_MODE}
  Log('Setting Baudrate Successful!');
{$endif}

  if (res = MCP2515_OK) then
  begin
      { init canbuffers              }
      mcp2515_initCANBuffers();
      { interrupt mode               }
      mcp2515_setRegister(MCP_CANINTE, MCP_RX0IF or MCP_RX1IF);

      //Sets BF pins as GPO
      mcp2515_setRegister(MCP_BFPCTRL,MCP_BxBFS_MASK or MCP_BxBFE_MASK);

      //Sets RTS pins as GPI
      mcp2515_setRegister(MCP_TXRTSCTRL,$00);

      case canIDMode of
      MCP_ANY:
      begin
          mcp2515_modifyRegister(MCP_RXB0CTRL,
            MCP_RXB_RX_MASK or MCP_RXB_BUKT_MASK,
            MCP_RXB_RX_ANY or MCP_RXB_BUKT_MASK);

          mcp2515_modifyRegister(MCP_RXB1CTRL, MCP_RXB_RX_MASK,
            MCP_RXB_RX_ANY);
      end;
{
The followinng two functions of the MCP2515 do not work, there is a bug in the silicon.
      MCP_STD:
      begin
          mcp2515_modifyRegister(MCP_RXB0CTRL,
          MCP_RXB_RX_MASK | MCP_RXB_BUKT_MASK,
          MCP_RXB_RX_STD | MCP_RXB_BUKT_MASK );
          mcp2515_modifyRegister(MCP_RXB1CTRL, MCP_RXB_RX_MASK,
          MCP_RXB_RX_STD);
      end;

      MCP_EXT:
      begin
          mcp2515_modifyRegister(MCP_RXB0CTRL,
          MCP_RXB_RX_MASK | MCP_RXB_BUKT_MASK,
          MCP_RXB_RX_EXT | MCP_RXB_BUKT_MASK );
          mcp2515_modifyRegister(MCP_RXB1CTRL, MCP_RXB_RX_MASK,
          MCP_RXB_RX_EXT);
      end;
}
      MCP_STDEXT:
      begin
          mcp2515_modifyRegister(MCP_RXB0CTRL,
            MCP_RXB_RX_MASK or MCP_RXB_BUKT_MASK,
            MCP_RXB_RX_STDEXT or MCP_RXB_BUKT_MASK );

          mcp2515_modifyRegister(MCP_RXB1CTRL, MCP_RXB_RX_MASK,
            MCP_RXB_RX_STDEXT);
      end;

      else
{$ifdef DEBUG_MODE}
          Log('`Setting ID Mode Failure...');
{$endif}
        begin
            Result := MCP2515_FAIL;
            exit;
        end;
      end;

      res := mcp2515_setCANCTRL_Mode(mcpMode);
      if (res = MCP2515_FAIL) then
      begin
{$ifdef DEBUG_MODE}
        Log('Returning to Previous Mode Failure...');

{$endif}
        Result := res;
      end;

  end;

  Result := res;
end;

{********************************************************************************************************
** Function name:           mcp2515_write_id
** Descriptions:            Write CAN ID
********************************************************************************************************}
procedure MCP_CAN.mcp2515_write_id(mcp_addr : INT8U;
                        ext : INT8U;
                        id : INT32U);

var
  canid : uint16_t;
  tbufdata : packed array[0..3] of INT8U;
begin
  canid := id and $0FFFF;

  if (ext = 1) then
  begin
    tbufdata[MCP_EID0] := canid and $FF;
    tbufdata[MCP_EID8] := canid >> 8;
    canid := id >> 16;
    tbufdata[MCP_SIDL] := canid and $03;
    tbufdata[MCP_SIDL] := tbufdata[MCP_SIDL] + ((canid and $1C) << 3);
    tbufdata[MCP_SIDL] := tbufdata[MCP_SIDL] or MCP_TXB_EXIDE_M;
    tbufdata[MCP_SIDH] := INT8U(canid >> 5);
  end
  else
  begin
    tbufdata[MCP_SIDH] := canid >> 3;
    tbufdata[MCP_SIDL] := (canid and $07 ) << 5;
    tbufdata[MCP_EID0] := 0;
    tbufdata[MCP_EID8] := 0;
  end;

  mcp2515_setRegisterS( mcp_addr, tbufdata, 4 );
end;

{********************************************************************************************************
** Function name:           mcp2515_write_mf
** Descriptions:            Write Masks and Filters
********************************************************************************************************}
procedure MCP_CAN.mcp2515_write_mf(mcp_addr : INT8U;
                        ext : INT8U;
                        id : INT32U);
var
  canid : uint16_t;
  tbufdata : packed array[0..3] of INT8U;
begin
  canid := id and $0FFFF;

  if (ext = 1) then
  begin
    tbufdata[MCP_EID0] := canid and $FF;
    tbufdata[MCP_EID8] := canid >> 8;
    canid := id >> 16;
    tbufdata[MCP_SIDL] := canid and $03;
    tbufdata[MCP_SIDL] := tbufdata[MCP_SIDL] + ((canid and $1C) << 3);
    tbufdata[MCP_SIDL] := tbufdata[MCP_SIDL] or MCP_TXB_EXIDE_M;
    tbufdata[MCP_SIDH] := (canid >> 5);
  end
  else
  begin
    tbufdata[MCP_EID0] := (canid and $FF);
    tbufdata[MCP_EID8] := (canid >> 8);
    canid := (id >> 16);
    tbufdata[MCP_SIDL] := ((canid and $07) << 5);
    tbufdata[MCP_SIDH] := (canid >> 3 ) and $ff;  // added "and $ff" to this to fix range check error?
  end;

  mcp2515_setRegisterS( mcp_addr, tbufdata, 4 );
end;

{********************************************************************************************************
** Function name:           mcp2515_read_id
** Descriptions:            Read CAN ID
********************************************************************************************************}
procedure MCP_CAN.mcp2515_read_id(mcp_addr : INT8U ; var ext : INT8U; var id : INT32U);
var
  tbufdata : packed array[0..3] of INT8U;
begin
  ext := 0;
  id := 0;

  mcp2515_readRegisterS( mcp_addr, @tbufdata[0], 4 );

  id := (tbufdata[MCP_SIDH]<<3) + (tbufdata[MCP_SIDL]>>5);

  if ( (tbufdata[MCP_SIDL] and MCP_TXB_EXIDE_M) =  MCP_TXB_EXIDE_M ) then
  begin
    // extended id
    id := (id<<2) + (tbufdata[MCP_SIDL] and $03);
    id := (id<<8) + tbufdata[MCP_EID8];
    id := (id<<8) + tbufdata[MCP_EID0];
    ext := 1;
  end;
end;

{********************************************************************************************************
** Function name:           mcp2515_write_canMsg
** Descriptions:            Write message
********************************************************************************************************
}
procedure MCP_CAN.mcp2515_write_canMsg(buffer_sidh_addr : INT8U);
var
  mcp_addr : INT8U;
  logstr : string;
  i : integer;
begin
  mcp_addr := buffer_sidh_addr;
  mcp2515_setRegisterS(mcp_addr+5, m_nDta, m_nDlc );                  { write data bytes             }

  if (m_nRtr = 1) then                                                   { if RTR set bit in byte       }
    m_nDlc := m_nDlc or MCP_RTR_MASK;

  mcp2515_setRegister((mcp_addr+4), m_nDlc );                         { write the RTR and DLC        }
  mcp2515_write_id(mcp_addr, m_nExtFlg, m_nID );                      { write CAN id                 }
end;

{********************************************************************************************************
** Function name:           mcp2515_read_canMsg
** Descriptions:            Read message
********************************************************************************************************}
procedure MCP_CAN.mcp2515_read_canMsg(buffer_sidh_addr : INT8U);
var
  mcp_addr, ctrl, premask : INT8U;
  l : integer;
  logstr : string;
begin
  mcp_addr := buffer_sidh_addr;

  mcp2515_read_id( mcp_addr, m_nExtFlg, m_nID );

  ctrl := mcp2515_readRegister( mcp_addr-1 );
  m_nDlc := mcp2515_readRegister( mcp_addr+4 );

  if (ctrl and $08) = $08 then
    m_nRtr := 1
  else
    m_nRtr := 0;

  premask := m_nDlc;
  m_nDlc := m_nDlc and MCP_DLC_MASK;
{$ifdef DEBUG_MODE}
  if (m_nDlc > 8) then
  begin
    log('Error - CAN Read Msg attempting to read more than 8 characters (len=' + inttohex(m_nDlc, 2)+') pre mask ='+inttohex(premask, 2) + ' canid='+inttohex(m_nID, 8));
    m_nDlc := 8;
  end;
{$endif}

  mcp2515_readRegisterS( mcp_addr+5, @(m_nDta[0]), m_nDlc );
end;

{********************************************************************************************************
** Function name:           mcp2515_getNextFreeTXBuf
** Descriptions:            Send message
********************************************************************************************************}
function MCP_CAN.mcp2515_getNextFreeTXBuf(txbuf_n : PINT8U) : INT8U;
var
  i, ctrlval : INT8U;
  ctrlregs : packed array[0..MCP_N_TXBUFFERS - 1] of INT8U = (MCP_TXB0CTRL, MCP_TXB1CTRL, MCP_TXB2CTRL);
begin
  Result := MCP_ALLTXBUSY;
  txbuf_n^ := $00;

  { check all 3 TX-Buffers       }
  for i := 0 to MCP_N_TXBUFFERS - 1 do
  begin
    ctrlval := mcp2515_readRegister( ctrlregs[i] );
    if ( (ctrlval and MCP_TXB_TXREQ_M) = 0 ) then
    begin
      txbuf_n^ := ctrlregs[i]+1;                                   { return SIDH-address of Buffer}
      Result := MCP2515_OK;
      exit;
    end
  end;
end;

{********************************************************************************************************
** Function name:           MCP_CAN
** Descriptions:            Public function to declare CAN class and the /CS pin.
********************************************************************************************************}
constructor MCP_CAN.Create(_CS : INT8U);
var
  res : longword;
begin
  inherited Create;

  FCanbusLock := SpinCreate;

{$ifdef ZERO}
  SPIDevice:=PSPIDevice(DeviceFindByDescription(BCM2708_SPI0_DESCRIPTION));
{$endif}
{$ifdef RPI1}
  SPIDevice:=PSPIDevice(DeviceFindByDescription(BCM2708_SPI0_DESCRIPTION));
{$endif}
{$ifdef RPI2}
  SPIDevice:=PSPIDevice(DeviceFindByDescription(BCM2709_SPI0_DESCRIPTION));
{$endif}
{$ifdef RPI3}
  SPIDevice:=PSPIDevice(DeviceFindByDescription(BCM2710_SPI0_DESCRIPTION));
{$endif}

  res := SPIDeviceStart(SPIDevice, SPI_MODE_4WIRE, 10000000,
              SPI_CLOCK_PHASE_LOW, SPI_CLOCK_POLARITY_LOW);

  if (res <> ERROR_SUCCESS) then
    log('Failed to start SPI device')
  else
    log('SPI Device successfully opened');

  MCP_CS := _CS;
end;

destructor MCP_CAN.Destroy;
begin
  SPIDeviceStop(SPIDevice);
  SpinDestroy(FCanbusLock);

  inherited Destroy;
end;

{********************************************************************************************************
** Function name:           begin
** Descriptions:            Public function to declare controller initialization parameters.
********************************************************************************************************}
function MCP_CAN.begincan(idmodeset : INT8U; speedset : INT8U; clockset : INT8U) : INT8U;
var
  res : INT8U;
begin
  res := mcp2515_init(idmodeset, speedset, clockset);
  if (res = MCP2515_OK) then
    res := CAN_OK
  else
    res := CAN_FAILINIT;

  Result := res;
end;

{********************************************************************************************************
** Function name:           init_Mask
** Descriptions:            Public function to set mask(s).
********************************************************************************************************}
function MCP_CAN.init_Mask(num : INT8U; ext : INT8U; ulData : INT32U) : INT8U;
var
  res : INT8U;
begin
  res := MCP2515_OK;
{$ifdef DEBUG_MODE}
  Log('Starting to Set Mask');
{$endif}
  res := mcp2515_setCANCTRL_Mode(MODE_CONFIG);
  if (res > 0) then
  begin
{$ifdef DEBUG_MODE}
    Log('Entering Configuration Mode Failure...');
{$endif}
    Result := res;
    exit;
  end;

  try
  if (num = 0) then
     mcp2515_write_mf(MCP_RXM0SIDH, ext, ulData)
  else
  if (num = 1) then
    mcp2515_write_mf(MCP_RXM1SIDH, ext, ulData)
  else
    res :=  MCP2515_FAIL;
  except
    on e : exception do
      log('exception ' + e.message + ' ' + inttohex(longword(exceptaddr), 8));
  end;

  res := mcp2515_setCANCTRL_Mode(mcpMode);

  if(res > 0) then
  begin
{$ifdef DEBUG_MODE}
    Log('Entering Previous Mode Failure...Setting Mask Failure...');
{$endif}
    Result := res;
    exit;
  end;
{$ifdef DEBUG_MODE}
  Log('Setting Mask Successful.');
{$endif}
  Result := res;
end;

{********************************************************************************************************
** Function name:           init_Mask
** Descriptions:            Public function to set mask(s).
********************************************************************************************************}
function MCP_CAN.init_Mask(num : INT8U; ulData : INT32U) : INT8U;
var
  res, ext : INT8U;
begin
  res := MCP2515_OK;
  ext := 0;
{$ifdef DEBUG_MODE}
  Log('Starting to Set Mask.');
{$endif}
  res := mcp2515_setCANCTRL_Mode(MODE_CONFIG);
  if (res > 0) then
  begin
{$ifdef DEBUG_MODE}
    Log('Entering Configuration Mode Failure...');
{$endif}
    Result := res;
    exit;
  end;

  if ((ulData and $80000000) = $80000000) then
      ext := 1;

  if (num = 0) then
    mcp2515_write_mf(MCP_RXM0SIDH, ext, ulData)
  else
  if (num = 1) then
      mcp2515_write_mf(MCP_RXM1SIDH, ext, ulData)
  else
    res := MCP2515_FAIL;

  res := mcp2515_setCANCTRL_Mode(mcpMode);
  if (res > 0) then
  begin
{$ifdef DEBUG_MODE}
    Log('Entering Previous Mode Failure...Setting Mask Failure...');
{$endif}
    Result := res;
    exit;
  end;
{$ifdef DEBUG_MODE}
  Log('Setting Mask Successful.');
{$endif}
  Result := res;
end;

{********************************************************************************************************
** Function name:           init_Filt
** Descriptions:            Public function to set filter(s).
********************************************************************************************************}
function MCP_CAN.init_Filt(num : INT8U; ext : INT8U; ulData :  INT32U) : INT8U;
var
  res : INT8U = MCP2515_OK;
begin
{$ifdef DEBUG_MODE}
  Log('Starting to Set Filter.');
{$endif}
  res := mcp2515_setCANCTRL_Mode(MODE_CONFIG);
  if (res > 0) then
  begin
{$ifdef DEBUG_MODE}
    Log('Enter Configuration Mode Failure...');
{$endif}
    Result := res;
    exit;
  end;

  case num of
    0: mcp2515_write_mf(MCP_RXF0SIDH, ext, ulData);
    1: mcp2515_write_mf(MCP_RXF1SIDH, ext, ulData);
    2: mcp2515_write_mf(MCP_RXF2SIDH, ext, ulData);
    3: mcp2515_write_mf(MCP_RXF3SIDH, ext, ulData);
    4: mcp2515_write_mf(MCP_RXF4SIDH, ext, ulData);
    5: mcp2515_write_mf(MCP_RXF5SIDH, ext, ulData);
  else
    res := MCP2515_FAIL;
  end;

  res := mcp2515_setCANCTRL_Mode(mcpMode);
  if (res > 0) then
  begin
{$ifdef DEBUG_MODE}
    Log('Entering Previous Mode Failure...Setting Filter Failure...');
{$endif}
    Result := res;
    exit;
  end;
{$ifdef DEBUG_MODE}
  Log('Setting Filter Successful.');
{$endif}

  Result := res;
end;

{********************************************************************************************************
** Function name:           init_Filt
** Descriptions:            Public function to set filter(s).
********************************************************************************************************}
function MCP_CAN.init_Filt(num : INT8U; ulData :  INT32U) : INT8U;
var
  res : INT8U = MCP2515_OK;
  ext : INT8U = 0;
begin
{$ifdef DEBUG_MODE}
  Log('Starting to Set Filter!');
{$endif}
  res := mcp2515_setCANCTRL_Mode(MODE_CONFIG);
  if (res > 0) then
  begin
{$ifdef DEBUG_MODE}
    Log('Enter Configuration Mode Failure...');
{$endif}
    Result := res;
    exit;
  end;

  if((ulData and $80000000) = $80000000) then
      ext := 1;

  case num of
    0: mcp2515_write_mf(MCP_RXF0SIDH, ext, ulData);
    1: mcp2515_write_mf(MCP_RXF1SIDH, ext, ulData);
    2: mcp2515_write_mf(MCP_RXF2SIDH, ext, ulData);
    3: mcp2515_write_mf(MCP_RXF3SIDH, ext, ulData);
    4: mcp2515_write_mf(MCP_RXF4SIDH, ext, ulData);
    5: mcp2515_write_mf(MCP_RXF5SIDH, ext, ulData);
  else
    res := MCP2515_FAIL;
  end;

  res := mcp2515_setCANCTRL_Mode(mcpMode);
  if (res > 0) then
  begin
{$ifdef DEBUG_MODE}
    Log('Entering Previous Mode Failure...Setting Filter Failure...');
{$endif}
    Result := res;
    exit;
  end;
{$ifdef DEBUG_MODE}
  Log('Setting Filter Successful!');
{$endif}

  Result := res;
end;

{********************************************************************************************************
** Function name:           setMsg
** Descriptions:            Set can message, such as dlc, id, dta[] and so on
********************************************************************************************************}
function MCP_CAN.setMsg(id : INT32U; rtr : INT8U; ext : INT8U; len : INT8U; pData : PINT8U) : INT8U;
var
  i : byte;
  logstr : string;
begin
  m_nID     := id;
  m_nRtr    := rtr;
  m_nExtFlg := ext;
  m_nDlc    := len;
  for i := 0 to MAX_CHAR_IN_MESSAGE - 1 do
    m_nDta[i] := (pData+i)^;

  Result := MCP2515_OK;
end;

{********************************************************************************************************
** Function name:           clearMsg
** Descriptions:            Set all messages to zero
********************************************************************************************************}
function MCP_CAN.clearMsg : INT8U;
var
  i : byte;
begin
  m_nID       := 0;
  m_nDlc      := 0;
  m_nExtFlg   := 0;
  m_nRtr      := 0;
  m_nfilhit   := 0;
  for i := 0 to m_nDlc - 1 do
    m_nDta[i] := $00;

  Result := MCP2515_OK;
end;

{********************************************************************************************************
** Function name:           sendMsg
** Descriptions:            Send message
********************************************************************************************************}
function MCP_CAN.sendMsg : INT8U;
var
  res, res1, txbuf_n : INT8U;
  uiTimeOut : uint16_t = 0;
begin
  res := MCP_ALLTXBUSY;
  while ((res = MCP_ALLTXBUSY) and (uiTimeOut < TIMEOUTVALUE)) do
  begin
    res := mcp2515_getNextFreeTXBuf(@txbuf_n);                       { info = addr. 0x31, 0x41, or 0x51 buffer 1,2,3                }
    uiTimeOut := uiTimeOut + 1;
  end;

  if (uiTimeOut = TIMEOUTVALUE) then
  begin
    Result := CAN_GETTXBFTIMEOUT;                                      { get tx buff time out         }
    exit;
  end;

  uiTimeOut := 0;
  mcp2515_write_canMsg( txbuf_n);
  mcp2515_modifyRegister( txbuf_n-1 , MCP_TXB_TXREQ_M, MCP_TXB_TXREQ_M );

  {
  Here we loop until the controller tells us exactly what happened after us
  trying to send the message. As it's polled it is quickest but obviously
  ties the caller up a bit. Thus there is no longer a timeout in this part
  like there used to be.
  }
  res1 := 1;
  while (res1 > 0) do
  begin
      MicrosecondDelay(70);
      uiTimeOut := uiTimeOut + 1;
      res1 := mcp2515_readRegister(txbuf_n-1);                         { read send buff ctrl reg 	}

      if ((res1 and 64) = 64) then // bit 6 set = TX Aborted
      begin
        Result := CAN_SENDMSGABORT;
        exit;
      end
      else
      if ((res1 and 32) = 32) then // bit 5 set = message lost
      begin
        Result := CAN_MESSAGELOST;
        exit;
      end
      else
      if ((res1 and 16) = 16) then // bit 4 set = TX error detected
      begin
        Result := CAN_TXERRORDETECTED;
        exit;
      end
      else
        res1 := res1 and $08;
  end;

  Result := CAN_OK;
end;

{********************************************************************************************************
** Function name:           sendMsgBuf
** Descriptions:            Send message to transmitt buffer
********************************************************************************************************}
function MCP_CAN.sendMsgBuf(id : INT32U; ext : INT8U; len : INT8U; buf : PINT8U) : INT8U;
var
  res : INT8U;
  rtr : INT8U = 0;
begin
  SpinLock(FCanbusLock);
  try
    // use of rtr here is not in the original code, but it turns out that to send
    // a remote frame request you must send an extended id due to where the bit is
    // located in the id. Therefore, we add it in as per the other version of sendmsgbuf.
    // Alternatively, you must or in the extended bit ($8000000) into the id as well as
    // $40000000 hence or in $c0000000 in total, and then call the other version
    // of this function.
    if ((id and $40000000) = $40000000) then
    begin
        rtr := 1;
        ext := 1;
    end;

    setMsg(id, rtr, ext, len, buf);
    res := sendMsg();
    Result := res;
  finally
    SpinUnlock(FCanbusLock);
  end;
end;

{********************************************************************************************************
** Function name:           sendMsgBuf
** Descriptions:            Send message to transmitt buffer
********************************************************************************************************}
function MCP_CAN.sendMsgBuf(id : INT32U; len : INT8U; buf :  PINT8U) : INT8U;
var
  ext : INT8U = 0;
  rtr : INT8U = 0;
  res : INT8U;
begin
  SpinLock(FCanbusLock);
  try
    if ((id and $80000000) = $80000000) then
        ext := 1;

    if ((id and $40000000) = $40000000) then
        rtr := 1;

    setMsg(id, rtr, ext, len, buf);
    res := sendMsg();
    Result := res;

  finally
    SpinUnlock(FCanbusLock);
  end;
end;

{********************************************************************************************************
** Function name:           readMsg
** Descriptions:            Read message
********************************************************************************************************}
function MCP_CAN.readMsg : INT8U;
var
  stat, res : INT8U;
begin
  stat := mcp2515_readStatus;

  if (stat and MCP_STAT_RX0IF) = MCP_STAT_RX0IF then                                        { Msg in Buffer 0              }
  begin
    mcp2515_read_canMsg( MCP_RXBUF_0);
    mcp2515_modifyRegister(MCP_CANINTF, MCP_RX0IF, 0);
    res := CAN_OK;
    m_bufsource := 0;
  end
  else if ( stat and MCP_STAT_RX1IF ) = MCP_STAT_RX1IF then                                   { Msg in Buffer 1              }
  begin
    mcp2515_read_canMsg( MCP_RXBUF_1);
    mcp2515_modifyRegister(MCP_CANINTF, MCP_RX1IF, 0);
    res := CAN_OK;
    m_bufsource := 1;
  end
  else
    res := CAN_NOMSG;

  Result := res;
end;


{********************************************************************************************************
** Function name:           readMsgBuf
** Descriptions:            Public function, Reads message from receive buffer.
********************************************************************************************************}
function MCP_CAN.readMsgBuf(id : PINT32U; ext : PINT8U; len : PINT8U; buf : PINT8U) : INT8U;
var
  i : byte;
begin
  Result := CAN_NOMSG;
  SpinLock(FCanbusLock);
  try
    if (readMsg = CAN_NOMSG) then
    begin
      exit;
    end;

    id^  := m_nID;
    len^ := m_nDlc;
    ext^ := m_nExtFlg;

    for i := 0 to m_nDlc - 1 do
      PINT8U(buf+i)^ := m_nDta[i];

    Result := CAN_OK;

  finally
    SpinUnlock(FCanbusLock);
  end;
end;

{********************************************************************************************************
** Function name:           readMsgBuf
** Descriptions:            Public function, Reads message from receive buffer.
********************************************************************************************************}
function MCP_CAN.readMsgBuf(id : PINT32U; len : PINT8U; buf : PINT8U) : INT8U;               // Read message from receive buffer
var
  i : INT8U;
begin
  Result := CAN_NOMSG;
  SpinLock(FCanbusLock);
  try
    if (readMsg = CAN_NOMSG) then
    begin
      exit;
    end;

    if (m_nExtFlg > 0) then
      m_nID := m_nID or $80000000;

    if (m_nRtr > 0) then
      m_nID := m_nID or $40000000;

    id^ := m_nID;
    len^ := m_nDlc;

    for i := 0 to m_nDlc - 1 do
      PINT8U(buf + i)^ := m_nDta[i];

    Result := CAN_OK;
  finally
    SpinUnlock(FCanbusLock);
  end;
end;


{********************************************************************************************************
** Function name:           checkReceive
** Descriptions:            Public function, Checks for received data.  (Used if not using the interrupt output)
********************************************************************************************************}
function MCP_CAN.checkReceive : INT8U;
var
  res : INT8U;
begin
  SpinLock(FCanbusLock);
  try
    res := mcp2515_readStatus;                                         { RXnIF in Bit 1 and 0         }
    if (res and MCP_STAT_RXIF_MASK ) > 0 then
      Res := CAN_MSGAVAIL
    else
      Res := CAN_NOMSG;

    Result := Res;

  finally
    SpinUnlock(FCanbusLock);
  end;

end;


{********************************************************************************************************
** Function name:           checkError
** Descriptions:            Public function, Returns error register data.
********************************************************************************************************}
function MCP_CAN.checkError : INT8U;
var
  eflg : INT8U;
begin
  SpinLock(FCanbusLock);
  try

    eflg := mcp2515_readRegister(MCP_EFLG);

    if ( eflg and MCP_EFLG_ERRORMASK ) > 0 then
      Result := CAN_CTRLERROR
    else
      REsult := CAN_OK;

  finally
    SpinUnlock(FCanbusLock);
  end;

end;

{********************************************************************************************************
** Function name:           getError
** Descriptions:            Returns error register value.
********************************************************************************************************}
function MCP_CAN.getError : INT8U;
begin
  SpinLock(FCanbusLock);
  try
    Result := mcp2515_readRegister(MCP_EFLG);
  finally
    SpinUnlock(FCanbusLock);
  end;
end;

{********************************************************************************************************
** Function name:           mcp2515_errorCountRX
** Descriptions:            Returns REC register value
********************************************************************************************************}
function MCP_CAN.errorCountRX : INT8U;
begin
  SpinLock(FCanbusLock);
  try
    Result := mcp2515_readRegister(MCP_REC);
  finally
    SpinUnlock(FCanbusLock);
  end;
end;

{********************************************************************************************************
** Function name:           mcp2515_errorCountTX
** Descriptions:            Returns TEC register value
********************************************************************************************************}
function MCP_CAN.errorCountTX : INT8U;
begin
  SpinLock(FCanbusLock);
  try
    Result := mcp2515_readRegister(MCP_TEC);
  finally
    SpinUnlock(FCanbusLock);
  end;
end;

{********************************************************************************************************
** Function name:           mcp2515_enOneShotTX
** Descriptions:            Enables one shot transmission mode
********************************************************************************************************}
function MCP_CAN.enOneShotTX : INT8U;
begin
  SpinLock(FCanbusLock);
  try
    mcp2515_modifyRegister(MCP_CANCTRL, MODE_ONESHOT, MODE_ONESHOT);
    if ((mcp2515_readRegister(MCP_CANCTRL) and MODE_ONESHOT) <> MODE_ONESHOT) then
      Result := CAN_FAIL
    else
      Result := CAN_OK;
  finally
    SpinUnlock(FCanbusLock);
  end;

end;

{********************************************************************************************************
** Function name:           mcp2515_disOneShotTX
** Descriptions:            Disables one shot transmission mode
********************************************************************************************************}
function MCP_CAN.disOneShotTX : INT8U;
begin
  SpinLock(FCanbusLock);
  try
    mcp2515_modifyRegister(MCP_CANCTRL, MODE_ONESHOT, 0);
    if ((mcp2515_readRegister(MCP_CANCTRL) and MODE_ONESHOT) <> 0) then
      Result := CAN_FAIL
    else
      Result := CAN_OK;

  finally
    SpinUnlock(FCanbusLock);
  end;
end;

{********************************************************************************************************
** Function name:           mcp2515_abortTX
** Descriptions:            Aborts any queued transmissions
********************************************************************************************************}
function MCP_CAN.abortTX : INT8U;
begin
  SpinLock(FCanbusLock);
  try

    mcp2515_modifyRegister(MCP_CANCTRL, ABORT_TX, ABORT_TX);

    // Maybe check to see if the TX buffer transmission request bits are cleared instead?
    if((mcp2515_readRegister(MCP_CANCTRL) and ABORT_TX) <> ABORT_TX) then
      Result := CAN_FAIL
    else
      Result := CAN_OK;

  finally
    SpinUnlock(FCanbusLock);
  end;
end;

{********************************************************************************************************
** Function name:           setGPO
** Descriptions:            Public function, Checks for r
********************************************************************************************************}
function MCP_CAN.setGPO(data : INT8U) : INT8U;
begin
  SpinLock(FCanbusLock);
  try
    mcp2515_modifyRegister(MCP_BFPCTRL, MCP_BxBFS_MASK, (data<<4));
    REsult := 0;
  finally
    SpinUnlock(FCanbusLock);
  end;
end;

{********************************************************************************************************
** Function name:           getGPI
** Descriptions:            Public function, Checks for r
********************************************************************************************************}
function MCP_CAN.getGPI : INT8U;
var
  res : INT8U;
begin
  SpinLock(FCanbusLock);
  try
    res := mcp2515_readRegister(MCP_TXRTSCTRL) and MCP_BxRTS_MASK;
    Result := (res >> 3);
  finally
    SpinUnlock(FCanbusLock);
  end;
end;

function MCP_CAN.CanResultToString(res : INT8U) : string;
begin
  case res of
    0 : Result := 'CAN_OK';
    1 : Result := 'CAN_FAILINIT';
    2 : Result := 'CAN_FAILTX';
    3 : Result := 'CAN_MSGAVAIL';
    4 : Result := 'CAN_NOMSG';
    5 : Result := 'CAN_CTRLERROR';
    6 : Result := 'CAN_GETTXBFTIMEOUT';
    7 : Result := 'CAN_SENDMSGTIMEOUT';
    8 : Result := 'CAN_SENDMSGABORT';
    9 : Result := 'CAN_MESSAGELOST';
    10 : Result := 'CAN_TXERRORDETECTED';
  end;
end;

{********************************************************************************************************
  END FILE
********************************************************************************************************}

end.

