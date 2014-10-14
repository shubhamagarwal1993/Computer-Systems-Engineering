/*									tab:8
 *
 * input.c - source file for input control to maze game
 *
 * "Copyright (c) 2004-2011 by Steven S. Lumetta."
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice and the following
 * two paragraphs appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE AUTHOR OR THE UNIVERSITY OF ILLINOIS BE LIABLE TO 
 * ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL 
 * DAMAGES ARISING OUT  OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, 
 * EVEN IF THE AUTHOR AND/OR THE UNIVERSITY OF ILLINOIS HAS BEEN ADVISED 
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE AUTHOR AND THE UNIVERSITY OF ILLINOIS SPECIFICALLY DISCLAIM ANY 
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE 
 * PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND NEITHER THE AUTHOR NOR
 * THE UNIVERSITY OF ILLINOIS HAS ANY OBLIGATION TO PROVIDE MAINTENANCE, 
 * SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 * Author:	    Steve Lumetta
 * Version:	    7
 * Creation Date:   Thu Sep  9 22:25:48 2004
 * Filename:	    input.c
 * History:
 *	SL	1	Thu Sep  9 22:25:48 2004
 *		First written.
 *	SL	2	Sat Sep 12 14:34:19 2009
 *		Integrated original release back into main code base.
 *	SL	3	Sun Sep 13 03:51:23 2009
 *		Replaced parallel port with Tux controller code for demo.
 *	SL	4	Sun Sep 13 12:49:02 2009
 *		Changed init_input order slightly to avoid leaving keyboard
 *              in odd state on failure.
 *	SL	5	Sun Sep 13 16:30:32 2009
 *		Added a reasonably robust direct Tux control for demo mode.
 *	SL	6	Wed Sep 14 02:06:41 2011
 *		Updated input control and test driver for adventure game.
 *	SL	7	Wed Sep 14 17:07:38 2011
 *		Added keyboard input support when using Tux kernel mode.
 */



#include <ctype.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/io.h>
#include <termio.h>
#include <termios.h>
#include <unistd.h>
#include <pthread.h>								//include this to run threads

#include "assert.h"
#include "input.h"

#include "module/tuxctl-ioctl.h"					//included to use functions and variables from tuxctl-ioctl and module


/* set to 1 and compile this file by itself to test functionality */
#define TEST_INPUT_DRIVER 0				

/* set to 1 to use tux controller; otherwise, uses keyboard input */
#define USE_TUX_CONTROLLER 0

/************************
*	magic numbers		*
************************/
#define time_limit 60
#define one_sec 1000000
#define max_min_tux 99
#define max_sec_tux 59
static struct termios tio_orig;
/* stores original terminal settings */

	/**********************************************************
	 *	Declaring global variables
	 *	We declare a thread here to take care of timing issues
	*************************************************************/ 
// pthread_t clock_display;
int fd;									
cmd_t pressedbutton = CMD_NONE;
int pushedbutton;

/* 
 * init_input
 *   DESCRIPTION: Initializes the input controller.  As both keyboard and
 *                Tux controller control modes use the keyboard for the quit
 *                command, this function puts stdin into character mode
 *                rather than the usual terminal mode.
 *   INPUTS: none
 *   OUTPUTS: none
 *   RETURN VALUE: 0 on success, -1 on failure 
 *   SIDE EFFECTS: changes terminal settings on stdin; prints an error
 *                 message on failure
 */
int
init_input ()
{
    struct termios tio_new;

    /*
     * Set non-blocking mode so that stdin can be read without blocking
     * when no new keystrokes are available.
     */
    if (fcntl (fileno (stdin), F_SETFL, O_NONBLOCK) != 0) {
        perror ("fcntl to make stdin non-blocking");
	return -1;
    }

	/****************************************
	 *	open file and set file descriptor	*
	 *	we call the ioctls					*
	 *	We have the mouse to the ldisc 		*
	 * 	becasue the TUX looks like a mouse	*
	 *	to the computer						*
	****************************************/
 
    fd = open("/dev/ttyS0", O_RDWR | O_NOCTTY);					
	int ldisc_num = N_MOUSE;
	ioctl (fd, TIOCSETD, &ldisc_num);								
	
  
	/*
     * Save current terminal attributes for stdin.
     */
    if (tcgetattr (fileno (stdin), &tio_orig) != 0) {
	perror ("tcgetattr to read stdin terminal settings");
	return -1;
    }

	/****************************************************************
	* start a timer thread to act as a counter which is displayed	*
	* It is the same as using the predefined clock					*	
	****************************************************************/
    // pthread_create (&clock_display, NULL, timer, NULL);
    /*
     * Turn off canonical (line-buffered) mode and echoing of keystrokes
     * to the monitor.  Set minimal character and timing parameters so as
     * to prevent delays in delivery of keystrokes to the program.
     */
    tio_new = tio_orig;
    tio_new.c_lflag &= ~(ICANON | ECHO);
    tio_new.c_cc[VMIN] = 1;
    tio_new.c_cc[VTIME] = 0;
    if (tcsetattr (fileno (stdin), TCSANOW, &tio_new) != 0) {
	perror ("tcsetattr to set stdin terminal settings");
	return -1;
    }

    /* Return success. */
    return 0;
}

static char typing[MAX_TYPED_LEN + 1] = {'\0'};

const char*
get_typed_command ()
{
    return typing;
}

void
reset_typed_command ()
{
    typing[0] = '\0';
}

static int32_t
valid_typing (char c)
{
    /* Valid typing include letters, numbers, space, and backspace/delete. */
    return (isalpha (c) || isdigit (c) || ' ' == c || 8 == c || 127 == c);
}

static void
typed_a_char (char c)
{
    int32_t len = strlen (typing);

    if (8 == c || 127 == c) {
        if (0 < len) {
	    typing[len - 1] = '\0';
	}
    } else if (MAX_TYPED_LEN > len) {
	typing[len] = c;
	typing[len + 1] = '\0';
    }
}
	
	/************************************************************************
	*	This function takes in a parameter and initializes the clock on		*
	*	the display. We basically use this to convert into seconds and 		*
	*	minutes. Moreover, we get a clock working in hexadecimal and 		*
	*	we need to convert it to decimal numbers to show on the LEDsd		*
	* It is the same as using the predefined clock							*	
	************************************************************************/
void *timer(void * arg)
{
	int counter = 0; 									//keeps count of the time lapse 
	int minutes = 0;									
	int seconds = 0;									
	
	while(1)											//start infinite loop so that time not affected
	{
		minutes = counter / time_limit;							//convert time in hex to decimals
		seconds = counter % time_limit;							
		if(minutes > max_min_tux)								//to reset clock to zero when it goes to 99 min and 59 sec
			minutes = 0;
		if(seconds > max_sec_tux)
			seconds = 0;
		unsigned long buf_time = 0xF4FF0000;			//This call SET_LED so we follow the convention of the received arg
		if(minutes < 10)
			buf_time = buf_time & 0xFFF7FFFF;		
		buf_time = buf_time | ((minutes & 0x000000FF)<<8);	
		buf_time = buf_time | (seconds & 0x000000FF);		//have final arg value in buffer
		ioctl (fd, TUX_SET_LED, buf_time);					//this sends to tux to display. 	
		counter++;										 		
		usleep(one_sec);								//this just slows the loop to 1 sec so that the timer increases by 1 sec  
	}													
}

	/************************************************************************ 
	 * get_command 															*		
	 *   DESCRIPTION: Reads a command from the input controller.  As some 	*
	 *                controllers provide only absolute input (e.g., go 	*
	 *                right), the current direction is needed as an input 	*
	 *                to this routine.										*
	 *   INPUTS: cur_dir -- current direction of motion 					*
	 *   OUTPUTS: none 														*
	 *   RETURN VALUE: command issued by the input controller 				*
	 *   SIDE EFFECTS: drains any keyboard input 							*
	 ***********************************************************************/

	/************************************************************************
	*	This function used GET COMMAND to take in values from the TUX and 	*
	*	map it to the commands. Up, down, left, right , quiz, enter,  		*
	*	move_left, and move right are mapped to the respective buttons.		*
	*	This enables us to use the TUX in the game and we can control the 	*
	* 	motion of the display or the picture. 								*	
	* 	This is exactly similar to the get_command function in advecture.c	*
	* 																		*
	*	Handle synchronous events--in this case, only player commands.		* 
	* 	Note that typed commands that move objects may cause the room		*
	* 	to be redrawn.														*
	************************************************************************/
cmd_t
get_tux_command(cmd_t *pushed)
{
									
	int arg = 0xFFFFFF00;									//since we take active low, we make all 1s to show no button is pressesed  
		
	ioctl(fd, TUX_BUTTONS, &arg);							//this ioctl updates the arg to tell which button is kept pressed
/*	We separate these buttons to basically show which buttons should work when kept pressed */
	switch (arg)
	{
	    case 239: *pushed = CMD_UP;							
	    	break; 								
	    case 127: *pushed = CMD_RIGHT;  						//these buttons work when kept pressed
	    	break; 				
	    case 191: *pushed = CMD_DOWN;    
	    	break; 				
	    case 223: *pushed = CMD_LEFT; 						//direction mapped with above comment
	    	break;  			
	    default: 
	    	break;
	}
/*	We separate these buttons to basically show which buttons should not work when kept pressed */
	if(arg != pushedbutton)
	{
		pushedbutton = arg;
		switch(arg)
		{
			case 253: *pushed = CMD_MOVE_LEFT;				
				break;		
	    	case 251: *pushed = CMD_ENTER;	 				//these buttons only work when presses again and again
	    		break;		
	    	case 247: *pushed = CMD_MOVE_RIGHT;	
	    		break;		
			case 254: *pushed = CMD_QUIT; 					//direction mapped with above comment
				break;		
			default:
				break;
		}
	}
return *pushed;
}

/* 
 * get_command
 *   DESCRIPTION: Reads a command from the input controller.  As some
 *                controllers provide only absolute input (e.g., go
 *                right), the current direction is needed as an input
 *                to this routine.
 *   INPUTS: cur_dir -- current direction of motion
 *   OUTPUTS: none
 *   RETURN VALUE: command issued by the input controller
 *   SIDE EFFECTS: drains any keyboard input
 */

cmd_t 
get_command ()
{
	   
#if (USE_TUX_CONTROLLER == 0) /* use keyboard control with arrow keys */
    static int state = 0;             /* small FSM for arrow keys */

#endif
    static cmd_t command = CMD_NONE;
    cmd_t pushed = CMD_NONE;
    int ch;

    /* Read all characters from stdin. */
    while ((ch = getc (stdin)) != EOF) {

	/* Backquote is used to quit the game. */
	if (ch == '`')
	    return CMD_QUIT;
	
#if (USE_TUX_CONTROLLER == 0) /* use keyboard control with arrow keys */
	/*
	 * Arrow keys deliver the byte sequence 27, 91, and 'A' to 'D';
	 * we use a small finite state machine to identify them.
	 *
	 * Insert, home, and page up keys deliver 27, 91, '2'/'1'/'5' and
	 * then a tilde.  We recognize the digits and don't check for the
	 * tilde.
	 */
	switch (state) {
	    case 0:
	        if (27 == ch) {
		    state = 1;
		} else if (valid_typing (ch)) {
		    typed_a_char (ch);
		} else if (10 == ch || 13 == ch) {
		    pushed = CMD_TYPED;
		}
		break;
	    case 1:
		if (91 == ch) {
		    state = 2;
		} else {
		    state = 0;
		    if (valid_typing (ch)) {
			/*
			 * Note that we may be discarding an ESC (27), but
			 * we don't use that as typed input anyway.
			 */
			typed_a_char (ch);
		    } else if (10 == ch || 13 == ch) {
			pushed = CMD_TYPED;
		    }
		}
		break;
	    case 2:
	        if (ch >= 'A' && ch <= 'D') {
		    switch (ch) {
			case 'A': pushed = CMD_UP; break;
			case 'B': pushed = CMD_DOWN; break;
			case 'C': pushed = CMD_RIGHT; break;
			case 'D': pushed = CMD_LEFT; break;
		    }
		    state = 0;
		} else if (ch == '1' || ch == '2' || ch == '5') {
		    switch (ch) {
			case '2': pushed = CMD_MOVE_LEFT; break;
			case '1': pushed = CMD_ENTER; break;
			case '5': pushed = CMD_MOVE_RIGHT; break;
		    }
		    state = 3; /* Consume a '~'. */
		} else {
		    state = 0;
		    if (valid_typing (ch)) {
			/*
			 * Note that we may be discarding an ESC (27) and 
			 * a bracket (91), but we don't use either as 
			 * typed input anyway.
			 */
			typed_a_char (ch);
		    } else if (10 == ch || 13 == ch) {
			pushed = CMD_TYPED;
		    }
		}
		break;
	    case 3:
		state = 0;
	        if ('~' == ch) {
		    /* Consume it silently. */
		} else if (valid_typing (ch)) {
		    typed_a_char (ch);
		} else if (10 == ch || 13 == ch) {
		    pushed = CMD_TYPED;
		}
		break;
	}
#else /* USE_TUX_CONTROLLER */





/********************************************************************************
* 	To decide the case number for the various cases, we will follow the 	*
*	diagram below. This has been taken from mtcp.h in modules.		*
*										*
*	+---7---+--6---+---5--+-4--+-3-+-2-+-1-+---0---+			*	
*	| right | down | left | up | C | B | A | START |			*	
*	+-------+------+------+----+---+---+---+-------+			*	
*										*
*	Since we are checking active low/high here we will use the commands	*
*	right - 01111111(127)   down - 10111111(191)	left - 11011111(223)	*
*	up - 11101111(239)	C - 11110111(247)	B - 11111011(251)	*	
*	A - 11111101(253)      	START - 11111110(254)				*					
********************************************************************************/

	/* Tux controller mode; still need to support typed commands. */
	if (valid_typing (ch)) {
	    typed_a_char (ch);
	} else if (10 == ch || 13 == ch) {
	    pushed = CMD_TYPED;

	}

#endif /* USE_TUX_CONTROLLER */
    }
    pushed = get_tux_command(&pushed);
 
    /*
     * Once a direction is pushed, that command remains active
     * until a turn is taken.
     */
    if (pushed == CMD_NONE) {
        command = CMD_NONE;
    }
    return pushed;
}

/* 
 * shutdown_input
 *   DESCRIPTION: Cleans up state associated with input control.  Restores
 *                original terminal settings.
 *   INPUTS: none
 *   OUTPUTS: none
 *   RETURN VALUE: none 
 *   SIDE EFFECTS: restores original terminal settings
 */
void
shutdown_input ()
{
    (void)tcsetattr (fileno (stdin), TCSANOW, &tio_orig);
}


/* 
 * display_time_on_tux
 *   DESCRIPTION: Show number of elapsed seconds as minutes:seconds
 *                on the Tux controller's 7-segment displays.
 *   INPUTS: num_seconds -- total seconds elapsed so far
 *   OUTPUTS: none
 *   RETURN VALUE: none 
 *   SIDE EFFECTS: changes state of controller's display
 */


//#error "Tux controller code is not operational yet."


#if (TEST_INPUT_DRIVER == 1)
int
main ()
{
	int tick = 0;
	printf("starting here");
	ioctl (fd, TUX_INIT);										

	
    cmd_t last_cmd = CMD_NONE;
    cmd_t cmd;
    static const char* const cmd_name[NUM_COMMANDS] = {
        "none", "right", "left", "up", "down", 
	"move left", "enter", "move right", "typed command", "quit"
    };

    /* Grant ourselves permission to use ports 0-1023 */
    if (ioperm (0, 1024, 1) == -1) {
	perror ("ioperm");
	return 3;
    }

    init_input ();
    while (1) {
        while ((cmd = get_tux_command ()) == last_cmd);
	last_cmd = cmd;
	printf ("command issued: %s\n", cmd_name[cmd]);
	if (cmd == CMD_QUIT)
	    break;
	display_time_on_tux (tick++);
    }
    close(fd);
    shutdown_input ();
    return 0;
}
#endif
