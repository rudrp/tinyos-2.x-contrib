/*
 * "Copyright (c) 2008 The Regents of the University  of California.
 * All rights reserved."
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 *
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 */

#include <IPDispatch.h>
#include <IP.h>
#include <router_address.h>

#include "UDPReport.h"
#include "PrintfUART.h"

#define REPORT_PERIOD 15L

module UDPEchoP {
  uses {
    interface Boot;
    interface SplitControl as RadioControl;
    interface UDPSend;
    interface UDPReceive;
    interface Leds;
    
    interface BufferPool;
    
    interface Timer<TMilli> as RouteTimer;
    interface UDPSend as RouteSend;
    interface IPPacket;
    interface BasicPacket as UdpPacket;
   
    interface Statistics<ip_statistics_t> as IPStats;
    interface Statistics<route_statistics_t> as RouteStats;
    interface Statistics<icmp_statistics_t> as ICMPStats;

    interface Random;
  }

} implementation {

  bool timerStarted;
  udp_statistics_t stats;
  struct sockaddr route_dest;

  event void Boot.booted() {
    call RadioControl.start();
    call RouteTimer.startOneShot(call Random.rand16() % (1024 * REPORT_PERIOD));
    timerStarted = FALSE;

    call IPStats.clear();
    call RouteStats.clear();
    call ICMPStats.clear();
    printfUART_init();

    stats.total = 0;
    stats.failed = 0;

    route_dest.sin_port = hton16(7000);
    memcpy(&route_dest.sin_addr, router_address, 16);
  }

  event void RadioControl.startDone(error_t e) {

  }

  event void RadioControl.stopDone(error_t e) {

  }

  event ip_msg_t *UDPReceive.receive(struct sockaddr *from, ip_msg_t *msg,
                                     void *data, uint16_t len) {
    if (call UDPSend.send(from, msg, len) != SUCCESS)
      return msg;
    return NULL;
  }

  event void UDPSend.sendDone(ip_msg_t *msg, error_t error) {
    printfUART("signal sendDone\n");
    call BufferPool.put(msg);
    if (error != SUCCESS)
      stats.failed++;
  }

  event void RouteTimer.fired() {
    uint8_t stats_size = sizeof(ip_statistics_t) + sizeof(route_statistics_t) 
      + sizeof(icmp_statistics_t) + sizeof(udp_statistics_t);
    ip_msg_t *msg = call BufferPool.get(sizeof(hw_addr_t) * 5 + sizeof(struct source_header) + stats_size);
    struct udp_report *payload;

    stats.total++;

    if (!timerStarted) {
      call RouteTimer.startPeriodic(1024 * REPORT_PERIOD);
      timerStarted = TRUE;
    }

    if (msg == NULL) return;
    
    call IPPacket.addSourceHeader(msg, 5, TRUE);
    payload = (struct udp_report *)call UdpPacket.getPayload(msg);
    
    stats.seqno++;
    stats.sender = TOS_NODE_ID;

    memcpy(&payload->ip,    call IPStats.get(),    sizeof(ip_statistics_t));
    memcpy(&payload->route, call RouteStats.get(), sizeof(route_statistics_t));
    memcpy(&payload->icmp,  call ICMPStats.get(),  sizeof(icmp_statistics_t));
    memcpy(&payload->udp,   &stats,                sizeof(udp_statistics_t));

    call Leds.led0Toggle();

    if (call RouteSend.send(&route_dest, msg, stats_size) != SUCCESS) {
      call BufferPool.put(msg);
      stats.failed++;
    }
  }

  event void RouteSend.sendDone(ip_msg_t *msg, error_t error) {
    printfUART("Route sendDone\n");
    call BufferPool.put(msg);
  }
}