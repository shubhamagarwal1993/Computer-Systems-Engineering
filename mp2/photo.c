/*									tab:8
 *
 * photo.c - photo display functions
 *
 * "Copyright (c) 2011 by Steven S. Lumetta."
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
 * Version:	    3
 * Creation Date:   Fri Sep  9 21:44:10 2011
 * Filename:	    photo.c
 * History:
 *	SL	1	Fri Sep  9 21:44:10 2011
 *		First written (based on mazegame code).
 *	SL	2	Sun Sep 11 14:57:59 2011
 *		Completed initial implementation of functions.
 *	SL	3	Wed Sep 14 21:49:44 2011
 *		Cleaned up code for distribution.
 */


#include <string.h>

#include "assert.h"
#include "modex.h"
#include "photo.h"
#include "photo_headers.h"
#include "world.h"


/* types local to this file (declared in types.h) */

/* 
 * A room photo.  Note that you must write the code that selects the
 * optimized palette colors and fills in the pixel data using them as 
 * well as the code that sets up the VGA to make use of these colors.
 * Pixel data are stored as one-byte values starting from the upper
 * left and traversing the top row before returning to the left of
 * the second row, and so forth.  No padding should be used.
 */
struct photo_t {
    photo_header_t hdr;			/* defines height and width */
    uint8_t        palette[192][3];     /* optimized palette colors */
    uint8_t*       img;                 /* pixel data               */
};

/* 
 * An object image.  The code for managing these images has been given
 * to you.  The data are simply loaded from a file, where they have 
 * been stored as 2:2:2-bit RGB values (one byte each), including 
 * transparent pixels (value OBJ_CLR_TRANSP).  As with the room photos, 
 * pixel data are stored as one-byte values starting from the upper 
 * left and traversing the top row before returning to the left of the 
 * second row, and so forth.  No padding is used.
 */
struct image_t {
    photo_header_t hdr;			/* defines height and width */
    uint8_t*       img;                 /* pixel data               */
};


/* file-scope variables */

/* 
 * The room currently shown on the screen.  This value is not known to 
 * the mode X code, but is needed when filling buffers in callbacks from 
 * that code (fill_horiz_buffer/fill_vert_buffer).  The value is set 
 * by calling prep_room.
 */
static const room_t* cur_room = NULL; 


/* 
 * fill_horiz_buffer
 *   DESCRIPTION: Given the (x,y) map pixel coordinate of the leftmost 
 *                pixel of a line to be drawn on the screen, this routine 
 *                produces an image of the line.  Each pixel on the line
 *                is represented as a single byte in the image.
 *
 *                Note that this routine draws both the room photo and
 *                the objects in the room.
 *
 *   INPUTS: (x,y) -- leftmost pixel of line to be drawn 
 *   OUTPUTS: buf -- buffer holding image data for the line
 *   RETURN VALUE: none
 *   SIDE EFFECTS: none
 */
void
fill_horiz_buffer (int x, int y, unsigned char buf[SCROLL_X_DIM])
{
    int            idx;   /* loop index over pixels in the line          */ 
    object_t*      obj;   /* loop index over objects in the current room */
    int            imgx;  /* loop index over pixels in object image      */ 
    int            yoff;  /* y offset into object image                  */ 
    uint8_t        pixel; /* pixel from object image                     */
    const photo_t* view;  /* room photo                                  */
    int32_t        obj_x; /* object x position                           */
    int32_t        obj_y; /* object y position                           */
    const image_t* img;   /* object image                                */

    /* Get pointer to current photo of current room. */
    view = room_photo (cur_room);

    /* Loop over pixels in line. */
    for (idx = 0; idx < SCROLL_X_DIM; idx++) {
        buf[idx] = (0 <= x + idx && view->hdr.width > x + idx ?
		    view->img[view->hdr.width * y + x + idx] : 0);
    }

    /* Loop over objects in the current room. */
    for (obj = room_contents_iterate (cur_room); NULL != obj;
    	 obj = obj_next (obj)) {
	obj_x = obj_get_x (obj);
	obj_y = obj_get_y (obj);
	img = obj_image (obj);

        /* Is object outside of the line we're drawing? */
	if (y < obj_y || y >= obj_y + img->hdr.height ||
	    x + SCROLL_X_DIM <= obj_x || x >= obj_x + img->hdr.width) {
	    continue;
	}

	/* The y offset of drawing is fixed. */
	yoff = (y - obj_y) * img->hdr.width;

	/* 
	 * The x offsets depend on whether the object starts to the left
	 * or to the right of the starting point for the line being drawn.
	 */
	if (x <= obj_x) {
	    idx = obj_x - x;
	    imgx = 0;
	} else {
	    idx = 0;
	    imgx = x - obj_x;
	}

	/* Copy the object's pixel data. */
	for (; SCROLL_X_DIM > idx && img->hdr.width > imgx; idx++, imgx++) {
	    pixel = img->img[yoff + imgx];

	    /* Don't copy transparent pixels. */
	    if (OBJ_CLR_TRANSP != pixel) {
		buf[idx] = pixel;
	    }
	}
    }
}


/* 
 * fill_vert_buffer
 *   DESCRIPTION: Given the (x,y) map pixel coordinate of the top pixel of 
 *                a vertical line to be drawn on the screen, this routine 
 *                produces an image of the line.  Each pixel on the line
 *                is represented as a single byte in the image.
 *
 *                Note that this routine draws both the room photo and
 *                the objects in the room.
 *
 *   INPUTS: (x,y) -- top pixel of line to be drawn 
 *   OUTPUTS: buf -- buffer holding image data for the line
 *   RETURN VALUE: none
 *   SIDE EFFECTS: none
 */
void
fill_vert_buffer (int x, int y, unsigned char buf[SCROLL_Y_DIM])
{
    int            idx;   /* loop index over pixels in the line          */ 
    object_t*      obj;   /* loop index over objects in the current room */
    int            imgy;  /* loop index over pixels in object image      */ 
    int            xoff;  /* x offset into object image                  */ 
    uint8_t        pixel; /* pixel from object image                     */
    const photo_t* view;  /* room photo                                  */
    int32_t        obj_x; /* object x position                           */
    int32_t        obj_y; /* object y position                           */
    const image_t* img;   /* object image                                */

    /* Get pointer to current photo of current room. */
    view = room_photo (cur_room);

    /* Loop over pixels in line. */
    for (idx = 0; idx < SCROLL_Y_DIM; idx++) {
        buf[idx] = (0 <= y + idx && view->hdr.height > y + idx ?
		    view->img[view->hdr.width * (y + idx) + x] : 0);
    }

    /* Loop over objects in the current room. */
    for (obj = room_contents_iterate (cur_room); NULL != obj;
    	 obj = obj_next (obj)) {
	obj_x = obj_get_x (obj);
	obj_y = obj_get_y (obj);
	img = obj_image (obj);

        /* Is object outside of the line we're drawing? */
	if (x < obj_x || x >= obj_x + img->hdr.width ||
	    y + SCROLL_Y_DIM <= obj_y || y >= obj_y + img->hdr.height) {
	    continue;
	}

	/* The x offset of drawing is fixed. */
	xoff = x - obj_x;

	/* 
	 * The y offsets depend on whether the object starts below or 
	 * above the starting point for the line being drawn.
	 */
	if (y <= obj_y) {
	    idx = obj_y - y;
	    imgy = 0;
	} else {
	    idx = 0;
	    imgy = y - obj_y;
	}

	/* Copy the object's pixel data. */
	for (; SCROLL_Y_DIM > idx && img->hdr.height > imgy; idx++, imgy++) {
	    pixel = img->img[xoff + img->hdr.width * imgy];

	    /* Don't copy transparent pixels. */
	    if (OBJ_CLR_TRANSP != pixel) {
		buf[idx] = pixel;
	    }
	}
    }
}


/* 
 * image_height
 *   DESCRIPTION: Get height of object image in pixels.
 *   INPUTS: im -- object image pointer
 *   OUTPUTS: none
 *   RETURN VALUE: height of object image im in pixels
 *   SIDE EFFECTS: none
 */
uint32_t 
image_height (const image_t* im)
{
    return im->hdr.height;
}


/* 
 * image_width
 *   DESCRIPTION: Get width of object image in pixels.
 *   INPUTS: im -- object image pointer
 *   OUTPUTS: none
 *   RETURN VALUE: width of object image im in pixels
 *   SIDE EFFECTS: none
 */
uint32_t 
image_width (const image_t* im)
{
    return im->hdr.width;
}

/* 
 * photo_height
 *   DESCRIPTION: Get height of room photo in pixels.
 *   INPUTS: p -- room photo pointer
 *   OUTPUTS: none
 *   RETURN VALUE: height of room photo p in pixels
 *   SIDE EFFECTS: none
 */
uint32_t 
photo_height (const photo_t* p)
{
    return p->hdr.height;
}


/* 
 * photo_width
 *   DESCRIPTION: Get width of room photo in pixels.
 *   INPUTS: p -- room photo pointer
 *   OUTPUTS: none
 *   RETURN VALUE: width of room photo p in pixels
 *   SIDE EFFECTS: none
 */
uint32_t 
photo_width (const photo_t* p)
{
    return p->hdr.width;
}


/* 
 * prep_room
 *   DESCRIPTION: Prepare a new room for display.  You might want to set
 *                up the VGA palette registers according to the color
 *                palette that you chose for this room.
 *   INPUTS: r -- pointer to the new room
 *   OUTPUTS: none
 *   RETURN VALUE: none
 *   SIDE EFFECTS: changes recorded cur_room for this file
 */
void
prep_room (const room_t* r)
{
    /* Record the current room. */
    cur_room = r;
    photo_t * photo = room_photo(r);
    int i;
    for (i=0; i<192; i++)
    	write_palette(64+i, (photo->palette[i][0] << 1) & 0x3F, photo->palette[i][1]& 0x3F, (photo->palette[i][2] << 1) & 0x3F);
}


/* 
 * read_obj_image
 *   DESCRIPTION: Read size and pixel data in 2:2:2 RGB format from a
 *                photo file and create an image structure from it.
 *   INPUTS: fname -- file name for input
 *   OUTPUTS: none
 *   RETURN VALUE: pointer to newly allocated photo on success, or NULL
 *                 on failure
 *   SIDE EFFECTS: dynamically allocates memory for the image
 */
image_t*
read_obj_image (const char* fname)
{
    FILE*    in;		/* input file               */
    image_t* img = NULL;	/* image structure          */
    uint16_t x;			/* index over image columns */
    uint16_t y;			/* index over image rows    */
    uint8_t  pixel;		/* one pixel from the file  */

    /* 
     * Open the file, allocate the structure, read the header, do some
     * sanity checks on it, and allocate space to hold the image pixels.
     * If anything fails, clean up as necessary and return NULL.
     */
    if (NULL == (in = fopen (fname, "r+b")) ||
	NULL == (img = malloc (sizeof (*img))) ||
	NULL != (img->img = NULL) || /* false clause for initialization */
	1 != fread (&img->hdr, sizeof (img->hdr), 1, in) ||
	MAX_OBJECT_WIDTH < img->hdr.width ||
	MAX_OBJECT_HEIGHT < img->hdr.height ||
	NULL == (img->img = malloc 
		 (img->hdr.width * img->hdr.height * sizeof (img->img[0])))) {
	if (NULL != img) {
	    if (NULL != img->img) {
	        free (img->img);
	    }
	    free (img);
	}
	if (NULL != in) {
	    (void)fclose (in);
	}
	return NULL;
    }

    /* 
     * Loop over rows from bottom to top.  Note that the file is stored
     * in this order, whereas in memory we store the data in the reverse
     * order (top to bottom).
     */
    for (y = img->hdr.height; y-- > 0; ) {

	/* Loop over columns from left to right. */
	for (x = 0; img->hdr.width > x; x++) {

	    /* 
	     * Try to read one 8-bit pixel.  On failure, clean up and 
	     * return NULL.
	     */
	    if (1 != fread (&pixel, sizeof (pixel), 1, in)) {
		free (img->img);
		free (img);
	        (void)fclose (in);
		return NULL;
	    }

	    /* Store the pixel in the image data. */
	    img->img[img->hdr.width * y + x] = pixel;
	}
    }

    /* All done.  Return success. */
    (void)fclose (in);
    return img;
}


/* 
 * read_photo
 *   DESCRIPTION: Read size and pixel data in 5:6:5 RGB format from a
 *                photo file and create a photo structure from it.
 *                Code provided simply maps to 2:2:2 RGB.  You must
 *                replace this code with palette color selection, and
 *                must map the image pixels into the palette colors that
 *                you have defined.
 *   INPUTS: fname -- file name for input
 *   OUTPUTS: none
 *   RETURN VALUE: pointer to newly allocated photo on success, or NULL
 *                 on failure
 *   SIDE EFFECTS: dynamically allocates memory for the photo
 */
photo_t*
read_photo (const char* fname)
{
    FILE*    in;	/* input file               */
    photo_t* p = NULL;	/* photo structure          */
    uint16_t x;		/* index over image columns */
    uint16_t y;		/* index over image rows    */
    uint16_t pixel;	/* one pixel from the file  */

    /* 
     * Open the file, allocate the structure, read the header, do some
     * sanity checks on it, and allocate space to hold the photo pixels.
     * If anything fails, clean up as necessary and return NULL.
     */
    if (NULL == (in = fopen (fname, "r+b")) ||
	NULL == (p = malloc (sizeof (*p))) ||
	NULL != (p->img = NULL) || /* false clause for initialization */
	1 != fread (&p->hdr, sizeof (p->hdr), 1, in) ||
	MAX_PHOTO_WIDTH < p->hdr.width ||
	MAX_PHOTO_HEIGHT < p->hdr.height ||
	NULL == (p->img = malloc 
		 (p->hdr.width * p->hdr.height * sizeof (p->img[0])))) {
	if (NULL != p) {
	    if (NULL != p->img) {
	        free (p->img);
	    }
	    free (p);
	}
	if (NULL != in) {
	    (void)fclose (in);
	}
	return NULL;
    }

    arr_initialize();

     /* 
     * Loop over rows from bottom to top.  Note that the file is stored
     * in this order, whereas in memory we store the data in the reverse
     * order (top to bottom).
     */
    for (y = p->hdr.height; y-- > 0; )
    {

	/* Loop over columns from left to right. */
		for (x = 0; p->hdr.width > x; x++)
		{

		    /* 
		     * Try to read one 16-bit pixel.  On failure, clean up and 
		     * return NULL.
		     */
		    if (1 != fread (&pixel, sizeof (pixel), 1, in))
		    {
				free (p->img);
				free (p);
			    (void)fclose (in);
				return NULL;
		    }
		    else {
		    insert_values(pixel);
			}
		    /* 
		     * 16-bit pixel is coded as 5:6:5 RGB (5 bits red, 6 bits green,
		     * and 6 bits blue).  We change to 2:2:2, which we've set for the
		     * game objects.  You need to use the other 192 palette colors
		     * to specialize the appearance of each photo.
		     *
		     * In this code, you need to calculate the p->palette values,
		     * which encode 6-bit RGB as arrays of three uint8_t's.  When
		     * the game puts up a photo, you should then change the palette 
		     * to match the colors needed for that photo.
		     */
		    /*p->img[p->hdr.width * y + x] = (((pixel >> 14) << 4) |
						    (((pixel >> 9) & 0x3) << 2) |
						    ((pixel >> 3) & 0x3));*/
		}
    }

    set_plt_values(p->palette);
    fseek(in, 0, SEEK_SET);
   

    /* 
     * Loop over rows from bottom to top.  Note that the file is stored
     * in this order, whereas in memory we store the data in the reverse
     * order (top to bottom).
     */
    for (y = p->hdr.height; y-- > 0; ) {

	/* Loop over columns from left to right. */
	for (x = 0; p->hdr.width > x; x++) {

	    /* 
	     * Try to read one 16-bit pixel.  On failure, clean up and 
	     * return NULL.
	     */
	    if (1 != fread (&pixel, sizeof (pixel), 1, in)) {
		free (p->img);
		free (p);
	        (void)fclose (in);
		return NULL;

	    }
	    /* 
	     * 16-bit pixel is coded as 5:6:5 RGB (5 bits red, 6 bits green,
	     * and 6 bits blue).  We change to 2:2:2, which we've set for the
	     * game objects.  You need to use the other 192 palette colors
	     * to specialize the appearance of each photo.
	     *
	     * In this code, you need to calculate the p->palette values,
	     * which encode 6-bit RGB as arrays of three uint8_t's.  When
	     * the game puts up a photo, you should then change the palette 
	     * to match the colors needed for that photo.
	     */
	    /*p->img[p->hdr.width * y + x] = (((pixel >> 14) << 4) |
					    (((pixel >> 9) & 0x3) << 2) |
					    ((pixel >> 3) & 0x3));*/
		p->img[p->hdr.width * y + x] = calculate_vga(pixel);
	}
    }

    /* All done.  Return success. */
    (void)fclose (in);
    return p;
}

//______________________________________________________________________

/********************************************************************
*	second_lev and fourth_lev are the two arrays that represent 	*
*	the required octree levels. 									*
*																	*
*																	*
********************************************************************/
node_t second_lev[64];					//64 is size of second level  
node_t fourth_lev[4096];				//4096 is size of second level

/******************************************************************** 
 *  This function sets up the arrays representing the two 			*
 *	required levels. It also initializes all the elements of the 	*
 *	arrays to 0 so that we dont have stray elements stored here.	*
 *																	*
 *   INPUTS: -- 													*
 *   OUTPUTS: --													*
 *   RETURN VALUE: none												*
 *   																*
 *******************************************************************/
void
arr_initialize()
{
	int i = 0;
	for(i = 0; i < 4096; i++)
	{		
		fourth_lev[i].total_red = 0;								//sum of red, green and blue respectively
		fourth_lev[i].total_green = 0;
		fourth_lev[i].total_blue = 0;
		fourth_lev[i].counter = 0;									//counter for pixels in index range		
		fourth_lev[i].color = i;									//initializing color as index
	}

	for(i = 0; i < 64; i++)
	{
		second_lev[i].total_red = 0;					
		second_lev[i].total_green = 0;								//sum of red, green and blue respectively 
		second_lev[i].total_blue = 0;
		second_lev[i].counter = 0;									//counter for pixels in index range
		second_lev[i].color = i;									//initializing color as index
	}
}

/********************************************************************************
 *																				*
 *	In this fuctin, we will take a given pixel. We will first check for the 	*
 *	respective significant bits and adds color of the pixel to the elements of 	*
 *	both the second level and the fourth level arrays. 							*
 *	Thus, we will be able to prepare for both the second and the fourth level 	*
 *	of the octrees.																*
 *																				*
 *  INPUTS: the pixel that is to be read 										*
 *  OUTPUTS: --																	*
 *  RETURN VALUE: none															*
 *  SIDE EFFECTS: changes the information stored in a cell 						*
 *	of the second_lev and fourth_lev arrays.									*
 *																				*
 *******************************************************************************/
void
insert_values(unsigned short pixel)
{
	/*	We will bit shift to get the red, green and blue colors from each pixel's
		5:6:5 red/green/blue structure	*/
	unsigned char red =	(pixel >> 11) & 0x1F;																				 							
	unsigned char green = (pixel >> 5) & 0x3F;										
	unsigned char blue = (pixel) & 0x1F;											//blue in first 5, then green in 6 and then red in 5

	/*	Calculating index in second array depending on obtained red,green and blue values 	*/
	int i2 = ((red >> 3) << 4 | (green >> 4) << 2 | (blue >> 3));;
	

	/*	Getting the red, green and blue color for second level array	*/
	second_lev[i2].total_red = second_lev[i2].total_red 	+ red;
	second_lev[i2].total_green = second_lev[i2].total_green + green;
	second_lev[i2].total_blue = second_lev[i2].total_blue	+ blue;				
	second_lev[i2].counter++;															//This basically keeps track of the indices

	/*	Calculating index in fourth array depending on obtained red,green and blue values 	*/
	int i4 = ((red >> 1) << 8 | (green >> 2) << 4 | (blue >> 1));
	
	/*	Getting the red, green and blue color for fourth level array	*/
	fourth_lev[i4].total_red = fourth_lev[i4].total_red 	+ red;
	fourth_lev[i4].total_green = fourth_lev[i4].total_green + green;
	fourth_lev[i4].total_blue = fourth_lev[i4].total_blue	+ blue;
	fourth_lev[i4].counter++;															//This basically keeps track of the indices
}

int sort_cmp(const void *a, const void *b)
{
	return ((*(node_t*)a).counter < (*(node_t*)b).counter);
}

/************************************************************************************ 
 * 																					*
 *  This function sets up the palette which is provided to us by photo.c. 			*	
 *	A pixel which is stored in thg fourth level has to be removed from the second 	*
 *	level and that is also done here.												*
 *																					*
 *  INPUTS: the current photo's 2D palette 											*
 *  OUTPUTS: --																		*
 *  RETURN VALUE: none																*	
 *  SIDE EFFECTS: changes the information stored in the photo palette 				*
 * 	as well as the second_lev nodes.												*
 ***********************************************************************************/
void
set_plt_values(unsigned char palette[192][3])
{
	qsort(fourth_lev, 4096, sizeof(node_t), sort_cmp);						//sort the array

	/*	add pixels to the fourth level 	*/
	int i = 0;
	while(i < 128)
	{
		if(fourth_lev[i].counter)												//putting the average colors
		{
		  palette[i + 64][0] = fourth_lev[i].total_red / fourth_lev[i].counter;
		  palette[i + 64][1] = fourth_lev[i].total_green / fourth_lev[i].counter;	
		  palette[i + 64][2] = fourth_lev[i].total_blue / fourth_lev[i].counter;		//avergae colors for red, green and blue respectively.
		}	
		/*	removing contribution of fourth level 	*/
		unsigned char red 	= fourth_lev[i].color >> 10 & 0x3;				
		unsigned char green = fourth_lev[i].color >> 6  & 0x3;			//for red, green and blue respectively
		unsigned char blue 	= fourth_lev[i].color >> 2  & 0x3;
		int i2 = (red << 4) | (green << 2) | blue;

		second_lev[i2].total_red 	-= fourth_lev[i].total_red;			//for red, green and blue respectively
		second_lev[i2].total_green 	-= fourth_lev[i].total_green;			
		second_lev[i2].total_blue 	-= fourth_lev[i].total_blue;		//for red, green and blue respectively
		second_lev[i2].counter 		-= fourth_lev[i].counter;

		fourth_lev[i].index = i + 64;									//updating index
		i++;
	}
	/*	add pixels to the second level	*/
	i = 0;
	while(i < 64)
	{
		if(second_lev[i].counter)
		{
		  palette[i][0] = second_lev[i].total_red / second_lev[i].counter;
		  palette[i][1] = second_lev[i].total_green / second_lev[i].counter;			//for red, green and blue respectively
		  palette[i][2] = second_lev[i].total_blue / second_lev[i].counter;
		}
		
		second_lev[i].index = i;													//updating index
		i++;
	}

	return;
}

/******************************************************************************** 	
 *	This function takes a pixel. It calculates the correct value that the 		*
 *	VGA will need. These values that the VGA gets are actually printed on the 	*
 *	screen depending on the second and fourth level arrays.						*
 *																				*
 *	INPUTS: the pixel that is to be read 										*
 *  OUTPUTS: the value for the VGA.												*	
 *  RETURN VALUE: unsigned char													*	
 *  SIDE EFFECTS: --															*
 *******************************************************************************/
unsigned char
calculate_vga(unsigned short pixel)
{
	/*	We will bit shift to get the red, green and blue colors from each pixel's
		5:6:5 red/green/blue structure	*/ 
	unsigned char red = (pixel >> 11) & 0x1F;
	unsigned char green = (pixel >> 5) & 0x3F;	
	unsigned char blue = pixel & 0x1F;

	/*	Calculating current index based on red, blue and green values 	*/
	int vga_index = ((red >> 1) << 8) | ((green >> 2) << 4) | (blue >> 1);
	int i = 0;

	/*	checking if the color value in fourth level was in the second level as well as mentioned above	*/
	for(i = 0; i < 128; i++)
	{
		if(fourth_lev[i].color == vga_index)								//checking if the index is valid
			return fourth_lev[i].index + 64;								//if valid then return the index	
	}

	/*	If the checking above is done and if color value not in fourth level then it will be in second level	*/
	vga_index = ((red >> 3) << 4) | ((green >> 4) << 2) | (blue >> 3);		//obtaining second level index
	return vga_index + 64;													//if valid then return the index

	return 0;
}
