/* tuxctl-ioctl.c
 *
 * Driver (skeleton) for the mp2 tuxcontrollers for ECE391 at UIUC.
 *
 * Mark Murphy 2006
 * Andrew Ofisher 2007
 * Steve Lumetta 12-13 Sep 2009
 * Puskar Naha 2013
 */

#include <asm/current.h>
#include <asm/uaccess.h>

#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/module.h>
#include <linux/fs.h>
#include <linux/sched.h>
#include <linux/file.h>
#include <linux/miscdevice.h>
#include <linux/kdev_t.h>
#include <linux/tty.h>
#include <linux/spinlock.h>

#include "tuxctl-ld.h"
#include "tuxctl-ioctl.h"
#include "mtcp.h"

#define debug(str, ...) \
	printk(KERN_DEBUG "%s: " str, __FUNCTION__, ## __VA_ARGS__)

/************************ Protocol Implementation *************************/

/* tuxctl_handle_packet()
 * IMPORTANT : Read the header for tuxctl_ldisc_data_callback() in 
 * tuxctl-ld.c. It calls this function, so all warnings there apply 
 * here as well.
 */
//////////////////////////	GLOBAL VARIABLES FOR FLAGS/////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
volatile int error_flag = 0; 		//1 means error in last packet
volatile int ACK_FLAG = 0; 			//1 means waiting for ack
volatile int gen_poll_flag = 0; 	//1 means poll for buttons or clk was received
volatile int reset_flag = 0; 		//1 means reset is in progress
volatile int on_flag = 0; 			//1 means tux is on
volatile int clk_flag = 0; 			//1 means clock hit limit
volatile int led_poll_flag = 0; 	//1 means next packet is second 
volatile int poll_type = 0; 		//1 means button poll, 2 means clock poll.
///////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////	GLOBAL VARIABLES FOR DATA   /////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
volatile char led_regular_buffer[6];
volatile char regular_buffer[2];
int previous_led_status = 0;
///////////////////////////////////////////////////////////////////////////////////////////////


char nums[16] = {0xE7, 0x06, 0xCB, 0x8F, 0x2E, 0xAD, 0xED, 0x86, 0xEF, 0xAE, 0xEE, 0x6D, 0xE1, 0x4F, 0xE9, 0xE8};


//////////////////////////	FUNCTIONS   /////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
void process_rcvd_pckt0(unsigned a, unsigned b, unsigned c);
void process_rcvd_pckt1(unsigned a, unsigned b, unsigned c);
///////////////////////////////////////////////////////////////////////////////////////////////

void tuxctl_handle_packet (struct tty_struct* tty, unsigned char* packet)
{
    unsigned a, b, c;
	
    a = packet[0]; /* Avoid printk() sign extending the 8-bit */
    b = packet[1]; /* values when printing them. */
    c = packet[2];

    /*printk("packet : %x %x %x\n", a, b, c); */

    switch(a)
    {
    	case MTCP_ERROR:
    		error_flag = 1;
    		break;

    	case MTCP_ACK:						//Response when the MTC successfully completes a command. / bioc_on bioc_off led_set
    		ACK_FLAG = 1;
    		break;


       	case MTCP_RESET: 					//Generated when devide re-initializes itself;					
			regular_buffer[0] = (char)MTCP_BIOC_ON;
			tuxctl_ldisc_put(tty, (char *)regular_buffer, 1);
			reset_flag = 0;
			ACK_FLAG = 0;
			break;
       	
    	//for buttons
    	case MTCP_BIOC_EVENT:				//Generated when the Button Interrupt-on-change mode is enabled and a button is either pressed or released.
    	{
/*
    		b = ~b;
    		c = ~c;
    		down = c;
    		down = (down>>2) % 2;
    		left = c;
    		left = (left>>1) % 2;
    		buttons = (b & 0x0F);
    		buttons = (c<<4) | buttons;
			buttons = buttons & 0x9F;
			buttons = buttons | (left <<6);
			buttons = buttons | (down <<5);
*/
			break;
    	}

       	case MTCP_LEDS_POLL0:
       	{
       		process_rcvd_pckt0(a, b, c);
       		break;
       	}
       	case __LEDS_POLL01:
       	{
       		process_rcvd_pckt0(a, b, c);
       		break;
       	}
       	case __LEDS_POLL02:
       	{
       		process_rcvd_pckt0(a, b, c);
       		break;
       	}
       	case __LEDS_POLL012:
       	{
       		process_rcvd_pckt0(a, b, c);
       		break;
       	}
       	case MTCP_LEDS_POLL1:
       	{
       		process_rcvd_pckt1(a, b, c);
       		break;
       	}
       	case __LEDS_POLL11:
       	{
       		process_rcvd_pckt1(a, b, c);
       		break;
       	}
       	case __LEDS_POLL12:
       	{
       		process_rcvd_pckt1(a, b, c);
       		break;
       	}
       	case __LEDS_POLL112:
       	{
       		process_rcvd_pckt1(a, b, c);
       		break;
       	}
       	default:
       		break;
    }
    return;
}

void process_rcvd_pckt0(unsigned a, unsigned b, unsigned c)
{
	switch(a)
	{
		case 0x50:			//modifying b and c to get the entire data we need to store.
			b = b & 0x7F;
			c = c & 0x7F;
			led_regular_buffer[2] = b;
			led_regular_buffer[3] = c;
			break;
		case 0x51:
			c = c & 0x7F;
			led_regular_buffer[2] = c;
			b = b | 0x80;
			led_regular_buffer[3] = b;
			break;
		case 0x52:
			b = b & 0x7F;
			led_regular_buffer[2] = b;
			c = c | 0x80;
			led_regular_buffer[3] = c;
			break;
		case 0x53:
			c = c | 0x80;
			led_regular_buffer[2] = c;
			b = b | 0x80;
			led_regular_buffer[3] = b;
			break;
	}
	return;
}

void process_rcvd_pckt1(unsigned a, unsigned b, unsigned c)
{
	switch(a)
	{
		case 0x54:				//modifying b and c to get the entire data we need to store.
			b = b & 0x7F;
			c = c & 0x7F;
			led_regular_buffer[4] = b;
			led_regular_buffer[5] = c;
			break;
		case 0x55:
			c = c & 0x7F;
			led_regular_buffer[4] = c;
			b = b | 0x80;
			led_regular_buffer[5] = b;
			break;
		case 0x56:
			b = b & 0x7F;
			led_regular_buffer[4] = b;
			c = c | 0x80;
			led_regular_buffer[5] = c;
			break;
		case 0x57:
			c = c | 0x80;
			led_regular_buffer[4] = c;
			b = b | 0x80;
			led_regular_buffer[5] = b;
			break;
	}
	led_poll_flag = 1;
	return;
}
/******** IMPORTANT NOTE: READ THIS BEFORE IMPLEMENTING THE IOCTLS ************
 *                                                                            *
 * The ioctls should not spend any time waiting for responses to the commands *
 * they send to the controller. The data is sent over the serial line at      *
 * 9600 BAUD. At this rate, a byte takes approximately 1 millisecond to       *
 * transmit; this means that there will be about 9 milliseconds between       *
 * the time you request that the low-level serial driver send the             *
 * 6-byte SET_LEDS packet and the time the 3-byte ACK packet finishes         *
 * arriving. This is far too long a time for a system call to take. The       *
 * ioctls should return immediately with success if their parameters are      *
 * valid.                                                                     *
 *                                                                            *
 ******************************************************************************/
int 
tuxctl_ioctl (struct tty_struct* tty, struct file* file, 
	      unsigned cmd, unsigned long arg)
{
	
	int ret_val;

	if(error_flag)
	{
			regular_buffer[0] = MTCP_BIOC_ON;
			tuxctl_ldisc_put(tty, (char *)regular_buffer, 1);
			reset_flag = 0;
			ACK_FLAG = 0;
	}

    switch (cmd) 
    {
    	printk("in the switch case before cases");
		case TUX_INIT: 									// Initializes variables associated with driver
		{
			//unsigned char* regular_buf;					
			//regular_buf = (unsigned char*)MTCP_BIOC_ON;
			//tuxctl_ldisc_put(tty, regular_buf, 1);
			char regular_buf_one[1];
			printk("inside TUX_INIT\n");
			regular_buf_one[0] = MTCP_BIOC_ON;
			tuxctl_ldisc_put(tty, regular_buf_one, 1);

			regular_buf_one[0] = MTCP_LED_USR;
			printk("inside TUX_INIT\n");
			tuxctl_ldisc_put(tty, regular_buf_one, 1);
			ACK_FLAG = 1;
			ret_val = 0;
			break;							//do we need this
		}
//

//-------------------------**********************************************************--------------------------------------
/* Check with the TA tomorrow about how to handle packets as well as using locks for the button interrupts. Also check up 
about interrupt vs polling modes for buttons and ask about responses to the computer from the Tux controller
*/



		case TUX_BUTTONS:
		{
			/*
			unsigned int temp;
			int ret;
			printk("inside TUX_BUTTONS\n");
			if (arg == 0)
				return -EINVAL;	

			temp = 0;
			temp = temp | buttons;
			ret = copy_to_user((int *)arg, &temp, 4);
			if(ret>0)
				return -EFAULT;
			else return 0;
			*/
			ret_val = 0;
			break;
		}
		
		case TUX_SET_LED:
		{
			int i;
			char regular_buf[6];
			int num_display;		// Number to be displayed
			int LED_ON;				// LEDs to be switched on
			int DP_ON;				// DPs to be swtiched on
			

			//char regular_buf_one[1];
			printk("inside TUX_SET_LED\n");
			
			//if(ACK_FLAG)
			//{
			//	return -1;
			//}
			regular_buf[0] = MTCP_LED_SET;
			regular_buf[1] = 0xF;				

			// Bits 15:0 specify hexdecimal number whose value is to be displayed on the 7 segment display
			// Bits 19:16 specify which LED is to be turned on
			// Bits 23:20 are garbage
			// Bits 27:24 specify which decimal points should be turned on. 
			// Bits 31:28 are garbage

			num_display = (arg & 0x0000FFFF);
			LED_ON = (arg & 0x000F0000)>>16;
			DP_ON = (arg & 0x0F000000)>>24;
			printk(" %x %x %x", num_display, LED_ON, DP_ON);
			printk("Before loading Data into buffer");
			for(i=0; i<4; i++)
			{
				
				regular_buf[2+i] = 0;
				if((LED_ON>>i) & 0x1)
				{
					regular_buf[2+i] = nums[(num_display>>(4*i)) & 0xF];
					//regular_buf[2+i] = 0xE7;
				}

				if((DP_ON>>i) & 0x1)
				{
					regular_buf[2+i] = regular_buf[2+i] | 0x10;
				}
			}	
			printk("AFter loading Data into buffer");
			// Where i write the LED 7 segment data into the regular_buffer
			printk(" %x %x %x", regular_buf[3], regular_buf[4], regular_buf[5]);
			tuxctl_ldisc_put(tty, regular_buf, 6);
			ACK_FLAG = 1;
			return 0;
		}

		case TUX_LED_ACK:
		if(ACK_FLAG==1)
			return 1;
		else
			return 0;
	
	default:
	    return -EINVAL;
    }
return 0;
}
