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

#define led_size_buf 6
/************************ Protocol Implementation *************************/

/* tuxctl_handle_packet()
 * IMPORTANT : Read the header for tuxctl_ldisc_data_callback() in 
 * tuxctl-ld.c. It calls this function, so all warnings there apply 
 * here as well.
 */

/************	ALL THE FLAGS WHICH ARE DECLARED GLOBALLY ***********************
 *																				*
 *	These variables are flags and are used to acknowledge packets, errors,		*
 *	the clock in the background which keeps running and reset.					*
 * 	The variable/flags in this case are volatile to avoid errors due			*
 *	to compiler optimizations. So every time the code runs, these variables		*
 *	are actually computed as per the code.										*
 *	I have gone ahead and commented the use of all the flags. 					*
 *******************************************************************************/
volatile int error_flag = 0; 		//1 would indicate error in last packet
volatile int ACK_FLAG = 0; 			//1 would indicate that the code waits for an acknowledgement
volatile int gen_poll_flag = 0; 	//1 would indicate a poll for the clock and the buttons was received
volatile int reset_flag = 0; 		//1 would indicate  that we have reset going on  reset is in progress
volatile int on_flag = 0; 			//1 would indicate  that the TUX is on
volatile int clk_flag = 0; 			//1 would indicate that the clock has crossed the max display capacity
volatile int led_poll_flag = 0; 	//1 would indicate that we get the last packet/ there are 2 packets every time 
volatile int poll_type = 0; 		//1 would indicate  that the button is polled and 2 for clock is polled.



/************** BUFFERS WHICH ARE DECLARED GLOBALLY USED FOR PACKET MANIPULATION ****************
 *																								*
 *	We will handle packet manipulations here. The incoming packets have a predefined format		*
 * 	and we will use it to our advantage by parsing the incoming packets and storing the 		*
 * 	data in a contiguous form to send instructions back to the TUX again						*
************************************************************************************************/
volatile char led_regular_buffer[led_size_buf] = {0, 0, 0, 0, 0, 0};		//stores led value which is send to tux to indicate which led should go on
volatile char regular_buffer[2];								//Used as a temporary buffer to parse 2nd(b) and 3rd(c) byte of packets going from TUX to the PC 
volatile char button_buffer[2];									//stores button values which parses incoming packets from TUX and maps it to what the PC should do
int previous_led_status = 0;									//keeps a track if the led was on so as to know if that has to be checked or not


/***************************  LOCKS WHICH ARE USED THROUGHTOUT THE CODE  ****************************************
 *																												*	 
 *	This locks the incoming packets together as we don't want interrupts when we read the packets and parse it.	*
 *	If no locks then we might be sending error messages when we might be generating interrupts from the TUX 	*
 *	and as a result our code will keep trying to send packets and resend them. 									*		
****************************************************************************************************************/	
spinlock_t lock = SPIN_LOCK_UNLOCKED;							//This is a lock declaration in which we lock segments of code which have to be carried out together without any interruptions.

char nums[16] = {0xE7, 0x06, 0xCB, 0x8F, 0x2E, 0xAD, 0xED, 0x86, 0xEF, 0xAE, 0xEE, 0x6D, 0xE1, 0x4F, 0xE9, 0xE8};
//				  0	    1     2     3     4     5     6     7     8     9     10    11    12    13    14    15
  
/*	THE HELPER FUNCTIONS WHICH ARE USED TO HANDLE SMALL TASKS IN PARSING PACKETS */
void process_rcvd_pckt0(unsigned a, unsigned b, unsigned c);	//will check 1st packet received from TUX, parse it, and store in a temp buffer which we can read
void process_rcvd_pckt1(unsigned a, unsigned b, unsigned c);	//will check 2nd packet received from TUX, parse it, and store in a temp buffer which we can read


void tuxctl_handle_packet (struct tty_struct* tty, unsigned char* packet)
{
    unsigned a, b, c;												//indicate 1st, 2nd, and 3rd bytes of received packets
	unsigned long irq;												//used in the lock which will lock packet manipulation.

	spin_lock_irqsave(&lock, irq);									//we start the lock here which will continue till the end of packet manipulation 
	
    a = packet[0]; 													
    b = packet[1]; 													//store packet 0,1,2 from incoming packet
    c = packet[2];													

    /*printk("packet : %x %x %x\n", a, b, c); */

    switch(a)														//'a' contains the opcode so we can decide what type of packet it is and
    {																//accordingly use it. The cases below are those which match 'a'.
    /*	general cases. this is an extra case	*/
    	case MTCP_ERROR:											//decides if the packet is erroneous				
    		error_flag = 1;											//set flag
    		break;	

/*	decides if MTCP successfully completes a command  */
    	case MTCP_ACK:											
    		ACK_FLAG = 1;											//use it for bioc_on and bioc_off and led_set
    		break;

/*	resets the flags and the packet values	*/
       	case MTCP_RESET: 																
			regular_buffer[0] = (char)MTCP_BIOC_ON;					//Use temp buffer to store the bioc_on value
			tuxctl_ldisc_put(tty, (char *)regular_buffer, 1);		
			tuxctl_ldisc_put(tty, (char *)led_regular_buffer, led_size_buf);	//sends the led packet which contains led info as to which is on the last 4 tell which led should go on on the display		
			reset_flag = 0;											
			ACK_FLAG = 0;											//reset the flags when packet transfer done	
			break;
       	
    	/*	This case is used for buttons	*/
    	case MTCP_BIOC_EVENT:										//Generated when the Button Interrupt-on-change mode is enabled and a button is either pressed or released.
    	{	
			button_buffer[0] = b;									
			button_buffer[1] = c;    								//store value for 3rd byte in the buffer dedicated to buttons
			break;
    	}

       	case MTCP_LEDS_POLL0:										//opcode - 010100 | 0 | 0
       	{
       		process_rcvd_pckt0(a, b, c);
       		break;
       	}
       	case __LEDS_POLL01:											//opcode - 010100 | 0 | 1
       	{
       		process_rcvd_pckt0(a, b, c);
       		break;
       	}
       	case __LEDS_POLL02:											//opcode - 010100 | 1 | 0
       	{
       		process_rcvd_pckt0(a, b, c);
       		break;
       	}
       	case __LEDS_POLL012:										//opcode - 010100 | 1 | 1	
       	{
       		process_rcvd_pckt0(a, b, c);
       		break;
       	}
       	case MTCP_LEDS_POLL1:										//opcode - 010101 | 0 | 0
       	{
       		process_rcvd_pckt1(a, b, c);
       		break;
       	}
       	case __LEDS_POLL11:											//opcode - 010101 | 0 | 1	
       	{
       		process_rcvd_pckt1(a, b, c);
       		break;
       	}
       	case __LEDS_POLL12:											//opcode - 010101 | 1 | 0
       	{
       		process_rcvd_pckt1(a, b, c);
       		break;
       	}
       	case __LEDS_POLL112:										//opcode - 010101 | 1 | 1
       	{
       		process_rcvd_pckt1(a, b, c);
       		break;
       	}
       	default:
       		break;
    }
    /* clear packet data */
	a = 0x00;
	b = 0x00;
	c = 0x00;
////////////////////////////////////////////////////////////////////
////////	IMPLEMENTING LOCKS 	////////////////////////////////////
	spin_unlock_irqrestore(&lock, irq);
////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////
    return;
}

void process_rcvd_pckt0(unsigned a, unsigned b, unsigned c)
{
	switch(a)
	{
		case 0x50:									//check if both A0 and A1 are 0
			b = b & 0x7F;
			c = c & 0x7F;
			led_regular_buffer[2] = b;
			led_regular_buffer[3] = c;
			break;
		case 0x51:									//check if A0 is 0 and A1 is 1
			c = c & 0x7F;
			led_regular_buffer[2] = c;
			b = b | 0x80;
			led_regular_buffer[3] = b;
			break;
		case 0x52:									//check if A1 is 0 and A0 is 1
			b = b & 0x7F;
			led_regular_buffer[2] = b;
			c = c | 0x80;
			led_regular_buffer[3] = c;
			break;
		case 0x53:									//check if both A0 and A1 are 1
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
		case 0x54:									//check if both A0 and A1 are 0
			b = b & 0x7F;
			c = c & 0x7F;							//parse to 1 byte
			led_regular_buffer[4] = b;
			led_regular_buffer[5] = c;
			break;
		case 0x55:									//check if A0 is 0 and A1 is 1
			c = c & 0x7F;							
			led_regular_buffer[4] = c;
			b = b | 0x80;							//parse to 1 byte	
			led_regular_buffer[5] = b;
			break;
		case 0x56:									//check if A1 is 0 and A0 is 1
			b = b & 0x7F;
			led_regular_buffer[4] = b;
			c = c | 0x80;							//parse to 1 byte
			led_regular_buffer[5] = c;
			break;
		case 0x57:									//check if both A0 and A1 are 1
			c = c | 0x80;
			led_regular_buffer[4] = c;
			b = b | 0x80;							//parse to 1 byte
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
 *****************************************************************************/
int 
tuxctl_ioctl (struct tty_struct* tty, struct file* file, 
	      unsigned cmd, unsigned long arg)
{
	
	int ret_val = 1;													// default return value. Will be given value as it goes through each 

	if(error_flag)														//We check for the error flag as an error might have been generated from incoming packets				
	{
			regular_buffer[0] = MTCP_BIOC_ON;							//store bioc value
			tuxctl_ldisc_put(tty, (char *)regular_buffer, 1);			//return to tux to respond
			reset_flag = 0;												//reset the flag 
			ACK_FLAG = 0;												//reset the flag
	}

    switch (cmd) 														//will check for the ioctls and if not will return a default return value
    {	

/**************** TUX_INIT ***************************************************
 *                                                                            *
 * 	Takes no arguments. Initializes any variables associated with the driver  * 
 *	and returns 0. Assume that any user-level code that interacts with your   *
 *	device will call this ioctl before any others. 							  *
 *                                                                            *
 ******************************************************************************/
		case TUX_INIT: 													// Initializes variables which are given in mtcp.h
		{
			char regular_buf_one[1];									//temporary buffer used only here. Buffer had to be created to pass in same format in tuxctl_ldisc_put() function
			regular_buf_one[0] = MTCP_BIOC_ON;		
			tuxctl_ldisc_put(tty, regular_buf_one, 1);					//return bioc value

			regular_buf_one[0] = MTCP_LED_USR;							
			tuxctl_ldisc_put(tty, regular_buf_one, 1);					//return led value

			regular_buf_one[0] = MTCP_CLK_RESET;
			tuxctl_ldisc_put(tty, regular_buf_one, 1);					//reset the clock
	
			regular_buf_one[0] = MTCP_CLK_UP;
			tuxctl_ldisc_put(tty, regular_buf_one, 1);					//increase the clock of the game.	
			ACK_FLAG = 1;
			ret_val = 0;
			break;							
		}


/***************  TUX_BUTTONS ***************************************************		
*																				*
*	Takes a pointer to a 32-bit integer. Returns -EINVAL error if this			*
*	pointer is not valid. Otherwise, sets the bits of the low byte				*
*	corresponding to the currently pressed buttons								*
*																				*			
********************************************************************************/		
		
		case TUX_BUTTONS:
		{
			int int_ptr = 0x00000000;
			char a, b;
			a = button_buffer[0];
			b = button_buffer[1];
			
			int_ptr = (int_ptr | (a & 0x0F));							//we use the last 4 values of the reveived packet(1) for buttons
			int_ptr = (int_ptr | ((b & 0x0F)<<4));						//we use the last 4 values of the reveived packet(2) for buttons. We have to mask it to get all 8 values in one integer
			ret_val = copy_to_user((int *)arg, &int_ptr, 4);			//We have to copy from kernel space to user space to copy button values from kernel so that they can mapped in the PC
			
			if(ret_val>0)												//If the number of bytes copied from kernal space to user space are > 0 then there was an error
				ret_val = -1;
			else ret_val = 0;											//copying done properly.
			break;
		}
		
		
/******************* TUX_SET_LED **********************************************
 *                                                                            *
 * 	The argument is a 32-bit integer of the following form: The low 16-bits   *
 *	specify a number whose hexadecimal value is to be displayed on the        *
 *	7-segment displays. The low 4 bits of the third byte specifies which      *
 *	LED’s should be turned on. The low 4 bits of the highest byte(bits 27:24) * 
 *	specify whether the corresponding decimal points should be turned on.     *
 *	This ioctl should return 0. 							  				  *
 *                                                                            *
 ******************************************************************************/
		case TUX_SET_LED:
		{
			int i;
			char regular_buf[6];										//make this temp buffer to complete parsing first and then work on copying
			int num_display;											//the number to be displayed on the LEDS will be stored here
			int LED_ON;													//the LEDs to be switched on will be stored here 
			int DP_ON;													//the dp position to be switched on will be stored here
			int convert_sec;
			int convert_min;
			int temp_buf_convert[4];
//			the general format that we will be following
//			_7____________ 4____3______2_______1_____0____
//			|mtcp_led_set| 1 | led3 | led2 | led1 | led0 |
//			----------------------------------------------

			regular_buf[0] = MTCP_LED_SET;								
			regular_buf[1] = 0xF;				

		// Bits 15:0 specify hexdecimal number whose value is to be displayed on the 7 segment display
		// Bits 19:16 specify which LED is to be turned on
		// Bits 23:20 are garbage
		// Bits 27:24 specify which decimal points should be turned on. 
		// Bits 31:28 are garbage

			num_display = (arg & 0x0000FFFF);							//we have to fit into buffer so we have to but shift here to get proper format for number to be displayed
			LED_ON = (arg & 0x000F0000)>>16;							//we have to fit into buffer so we have to but shift here to get proper format for led to be put on
			DP_ON = (arg & 0x0F000000)>>24;								//we have to fit into buffer so we have to but shift here to get proper format for the dp position
			convert_min = (num_display & 0x0000FF00)>>8;
			convert_sec = num_display & 0x000000FF;
			temp_buf_convert[0] = convert_sec%10;
			temp_buf_convert[1] = convert_sec/10;
			temp_buf_convert[2] = convert_min%10;
			temp_buf_convert[3] = convert_min/10;

			for(i=0; i<4; i++)											//this loop stores LEDS values in the last 4 positions and the dp position as well
			{
				regular_buf[2+i] = 0;									
				if((LED_ON>>i) & 0x1)									//decides which led
					regular_buf[2+i] = nums[temp_buf_convert[i]/*(num_display>>(4*i)) & 0xF*/];

				if((DP_ON>>i) & 0x1)									//decides which dp position
					regular_buf[2+i] = regular_buf[2+i] | 0x10;
			}	
			

			// if(regular_buf[3] == 0)
			// 	regular_buf[4] = 0x3;
			// else
			// 	regular_buf[4] = 0xF; 
			
			tuxctl_ldisc_put(tty, regular_buf, 6);						//writes the buffer to the TUX to display the final values that have been stored in regular_buf[6] 

			for(i=0; i<6; i++)											//We have to save the state of the LEDs so that we can display them on reset		
				led_regular_buffer[i] = regular_buf[i];
			
			ACK_FLAG = 1;												//reset flags	
			ret_val = 0;												//reset flags
			break;
		}

		default:
	    	return -EINVAL;
    }
return ret_val;															//final value to be returned from each ioctl.
}
