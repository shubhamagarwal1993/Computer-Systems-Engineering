/*									tab:8
 *
 * text.h - font data and text to mode X conversion utility header file
 *
 * "Copyright (c) 2004-2009 by Steven S. Lumetta."
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
 * Version:	    2
 * Creation Date:   Thu Sep  9 22:08:16 2004
 * Filename:	    text.h
 * History:
 *	SL	1	Thu Sep  9 22:08:16 2004
 *		First written.
 *	SL	2	Sat Sep 12 13:40:11 2009
 *		Integrated original release back into main code base.
 */

#ifndef TEXT_H
#define TEXT_H

/* The default VGA text mode font is 8x16 pixels. */
#define FONT_WIDTH   8
#define FONT_HEIGHT 16

/* Standard VGA text font. */
extern unsigned char font_data[256][16];

//////////////// HELPER FUNCTION WRITTEN BY ME//////////////////////////////////////////////////////////////////
void text_to_graphics(unsigned char * buffer, const char* written_on_screen, const char* present_room, const char* status_msg);
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#endif /* TEXT_H */


/*		EXPLAINGING HOW THE BASIC "text_to_graphics" function operates
*	We take the input from the given functions like typed_command and status message and store it in a string.
*	The string is of length 40 as that is the total number of characters that can fit on the screen at one time
*	We store the inputs on this temporary string as we want it to appear on the screen and then take each character
*	from the string, process it, color it and put it in the buffer.
*	We return this buffer.  
*/	
