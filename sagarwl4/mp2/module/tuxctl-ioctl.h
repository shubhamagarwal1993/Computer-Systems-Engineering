// All necessary declarations for the Tux Controller driver must be in this file

#ifndef TUXCTL_H
#define TUXCTL_H

#define TUX_SET_LED _IOR('E', 0x10, unsigned long)
#define TUX_BUTTONS _IOW('E', 0x12, unsigned long*)
#define TUX_INIT _IO('E', 0x13)
#define TUX_READ_LED _IOW('E', 0x11, unsigned long*)
#define TUX_LED_REQUEST _IO('E', 0x14)
#define TUX_LED_ACK _IO('E', 0x15)

void process_rcvd_pckt0(unsigned a, unsigned b, unsigned c);	//will check 1st packet received from TUX, parse it, and store in a temp buffer which we can read
void process_rcvd_pckt1(unsigned a, unsigned b, unsigned c);	//will check 2nd packet received from TUX, parse it, and store in a temp buffer which we can read

#endif

