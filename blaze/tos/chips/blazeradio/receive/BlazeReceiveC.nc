

/**
 * Lowest level implementation on the receive branch.
 *
 * @author Jared Hill
 * @author David Moss
 */


configuration BlazeReceiveC {

  provides {
    interface Receive[ radio_id_t id ];
    interface ReceiveController[ radio_id_t id ];
    
  }
  
  uses {
    interface GeneralIO as Csn[ radio_id_t id ];
  }
}

implementation {

  components BlazeReceiveP;
  Receive = BlazeReceiveP;
  ReceiveController = BlazeReceiveP;
  Csn = BlazeReceiveP.Csn;
  
  components BlazePacketC,
      BlazeSpiC as Spi;
      
  BlazeReceiveP.CheckRadio -> Spi.CheckRadio;
  BlazeReceiveP.SNOP -> Spi.SNOP;
  BlazeReceiveP.SRX -> Spi.SRX;
  BlazeReceiveP.SFRX -> Spi.SFRX;
  BlazeReceiveP.SFTX -> Spi.SFTX;
  BlazeReceiveP.STX -> Spi.STX;
  BlazeReceiveP.RXFIFO -> Spi.RXFIFO;
  BlazeReceiveP.TXFIFO -> Spi.TXFIFO;
  BlazeReceiveP.SIDLE -> Spi.SIDLE;
  BlazeReceiveP.RxReg -> Spi.RXREG;
  BlazeReceiveP.PktStatus -> Spi.PKTSTATUS;
  
  BlazeReceiveP.RadioStatus -> Spi.RadioStatus;

  BlazeReceiveP.BlazePacket -> BlazePacketC;
  BlazeReceiveP.BlazePacketBody -> BlazePacketC;
  
  components new StateC();
  BlazeReceiveP.State -> StateC;
  
  components LedsC;
  BlazeReceiveP.Leds -> LedsC;
  
}