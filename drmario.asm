################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Dr Mario.
#
# Student 1: Siddharth Iyer, 1010077827
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       2
# - Unit height in pixels:      2
# - Display width in pixels:    64
# - Display height in pixels:   64
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

.data
    
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000

# COLOURS
colour_red:         .word       0xff0000       # address for colour red
colour_yellow:      .word       0xffff00       # address for colour yellow
colour_blue:        .word       0x0000ff       # address for colour blue
colour_white:       .word       0xffffff       # address for colour white
colour_black:       .word       0x000000       # address for colour black
colour_virus_red:   .word       0xfc6603       # address for virus colour red/orange
colour_virus_yellow:.word       0x84fc03      # address for virus colour yellow/green
colour_virus_blue:  .word       0x6b05fa       # address for virus colour blue/purple
colour_mario_skin:   .word       0xffe5b4        # address for mario head colour
colour_mario_shoes: .word       0x964B00

# CONSTANT WORDS
CAPSULE_left:       .word       0              # left coord of pill
CAPSULE_right:      .word       0              # right coord of pill
frame_counter:      .word       0       # multi-value for a certain amount of frames till the pill auto drops
max_fall_frames:    .word       15       # value cap in how many frames it should fall when iterating
virus_count:        .word       4       # number of viruses
next_pill_place:    .word      0       # location of next pill so that it can continuously get swaped 492

# 4 in a row logic
starting_point:     .word
consecutive_pixels:  .space     256      # a place to store memory addresses 76
list_size:                .word      0        # current size
next_index:           .word      consecutive_pixels  # next available slot


# BYTES
CAPSULE_COLOUR1:    .byte       0       # 3-value variable for the colour of the capsule (first part) 0 - red, 1 - yellow, 2 - blue
CAPSULE_COLOUR2:    .byte       0       # 3-value variable for the colour of the capsule (second part)0 - red, 1 - yellow, 2 - blue
PRE_CAPSULE_COLOUR1: .byte      0       # 3 val var for colour of predicted capsule
PRE_CAPSULE_COLOUR2: .byte      0       # 3 val var for colour of predicted capsule
CAPSULE_orientation:.byte       0       # 2-value variable for the orientation of the capsule 0 - horizontal, 1 - vertical

    
##############################################################################
# Mutable Data
##############################################################################

##############################################################################
# Code
##############################################################################
	.text
	.globl main

.macro push (%reg)#Macro for pushing value onto stack
    addi $sp, $sp, -4
    sw %reg, 0($sp)
.end_macro

.macro pop (%reg) #Macro for popping from stack
    lw %reg, 0($sp)
    addi $sp, $sp, 4
.end_macro

    # Run the game.
main:
# Initialize the game


lw $t0, ADDR_DSPL       # $t0 = base address for display

addi $s0, $t0, 828     # initializes the value of the original pill left location
addi $s1, $t0, 832       # initializes the value of original pill right location
lw $s2, ADDR_KBRD       # holds keyboard address


addi $a0, $zero, 13 # x coord for bottle top left
addi $a1, $zero, 5 # y coord for bottle top left
jal erase_screen

jal draw_bottle

    li $v0, 42                  # Random int syscall
    li $a1, 3                   
    move $a0, $zero             # Randomize first half
    syscall
    sb $a0, PRE_CAPSULE_COLOUR1
    
    move $a0, $zero             # Randomize second half
    syscall
    sb $a0, PRE_CAPSULE_COLOUR2

jal draw_pill_initial

jal draw_viruses

jal draw_mario


game_loop:
            # 1a. Check if key has been pressed
            lw $t8, 0($s2) # Load first word from keyboard
            beq $t8, 1, keyboard_input # If first word 1, key is pressed
            
            jal next_pill_preview
            # 2b. Update locations (capsules)
            jal auto_fall
            
            lw $t2, frame_counter
            beq $t2, 0, skip_matches
            # 2a. Check for collisions 
            jal check_matches
            jal check_falling_pixels
            
            skip_matches:
        	# 3. Draw the screen
        	jal check_win_condition
        	jal erase_pill
        	jal draw_pill
        	jal draw_screen
        	
            # 4. Sleep
            li 	$v0, 32
        	li 	$a0, 16
        	syscall
        
        # 5. Go back to Step 1
        j game_loop


keyboard_input:
            # 1b. Check which key has been pressed
            lw $a0, 4($s2)                  # Load second word from keyboard
            beq $a0, 0x71, respond_to_Q     # Check if the key q was pressed
            beq $a0, 97, move_left        # Check if key = A
            beq $a0, 100, move_right       # Check if key = D
            beq $a0, 119, rotate_pill      # Check if key = W
            beq $a0, 115, speed_drop       # Check it key = S
            beq $a0, 112, pause
            j game_loop




    next_pill_preview:
    push($ra)
    push($t0)    # For ADDR_DSPL
    push($t1)    # For display position
    push($t2)    # For color black
    push($t3)    # For current color value
    push($t4)    # For color addresses
    push($t5)    # For loaded color

    # Load display base address
    la $t0, ADDR_DSPL
    lw $t1, 0($t0)          # $t1 = base display address
    addi $t1, $t1, 492      # $t1 = preview position (right side)
    sw $t1, next_pill_place  # Store for future reference

    # Clear old preview (set to black)
    la $t2, colour_black
    lw $t3, 0($t2)          # Load black color
    sw $t3, 0($t1)          # Clear left preview pixel
    sw $t3, 128($t1)        # Clear right preview pixel

    # Draw left preview pixel
    lb $t3, PRE_CAPSULE_COLOUR1  # Load color index (0-2)
    beq $t3, 0, preview_left_red
    beq $t3, 1, preview_left_yellow
    beq $t3, 2, preview_left_blue

preview_left_red:
    la $t4, colour_red
    lw $t5, 0($t4)
    sw $t5, 0($t1)          # Draw left pixel red
    j draw_right_preview

preview_left_yellow:
    la $t4, colour_yellow
    lw $t5, 0($t4)
    sw $t5, 0($t1)          # Draw left pixel yellow
    j draw_right_preview

preview_left_blue:
    la $t4, colour_blue
    lw $t5, 0($t4)
    sw $t5, 0($t1)          # Draw left pixel blue

draw_right_preview:
    # Draw right preview pixel
    lb $t3, PRE_CAPSULE_COLOUR2  # Load color index (0-2)
    beq $t3, 0, preview_right_red
    beq $t3, 1, preview_right_yellow
    beq $t3, 2, preview_right_blue

preview_right_red:
    la $t4, colour_red
    lw $t5, 0($t4)
    sw $t5, 128($t1)        # Draw right pixel red
    j preview_end

preview_right_yellow:
    la $t4, colour_yellow
    lw $t5, 0($t4)
    sw $t5, 128($t1)        # Draw right pixel yellow
    j preview_end

preview_right_blue:
    la $t4, colour_blue
    lw $t5, 0($t4)
    sw $t5, 128($t1)        # Draw right pixel blue

preview_end:
    pop($t5)
    pop($t4)
    pop($t3)
    pop($t2)
    pop($t1)
    pop($t0)
    pop($ra)
    jr $ra

draw_mario:
        push($ra)
        push($t0)
        push($t1)
        push($t2)
        push($t3)
        push($t4)
        
        la $t0, ADDR_DSPL
        lw $t1, 0($t0)
        
        la $t0, colour_mario_skin
        lw $t2, 0($t0)
        
        la $t0, colour_white
        lw $t3, 0($t0)
        
        la $t0, colour_yellow
        lw $t4, 0($t0)
        
        addi $t1, $t1, 500
        sw $t4, 0($t1)
        sw $t3, 384($t1)
        
        la $t0, colour_mario_shoes
        lw $t4, 0($t0)
        
        addi $t1, $t1, 128
        
        sw $t2, 4($t1)
        sw $t2, 128($t1)
        sw $t2, 132($t1)
        
        addi $t1, $t1, 256
        
        sw $t3, 4($t1)
        sw $t3, 128($t1)
        sw $t3, 132($t1)
        sw $t3, 256($t1)
        sw $t3, 260($t1)
        sw $t3, 384($t1)
        sw $t3, 388($t1)
        sw $t3, 512($t1)
        sw $t3, 640($t1)
        sw $t3, 768($t1)
        sw $t4, 896($t1)# shoe
        
        sw $t3, 124($t1)
        sw $t3, 120($t1)
        sw $t4, -8($t1)
        

        
        pop($t4)
        pop($t3)
        pop($t2)
        pop($t1)
        pop($t0)
        pop($ra)
        jr $ra

pause:
    push($ra)
    push($t0)
    push($t1)
    push($t2)
    push($t3)
    push($t4)
    
    
    la $t1, colour_white
    lw $t2, 0($t1)
    la $t0, ADDR_DSPL
    lw $t4, 0($t0)
    addi $t1, $t4, 264
    
    add $t3, $zero, $zero
    
    left_pause1:
        sw $t2, 0($t1)
        addi $t1, $t1, 128
        addi $t3, $t3, 1
        blt $t3, 4, left_pause1
        
        addi $t1, $t1, 4
        add $t3, $zero, $zero
    left_pause2:
        addi $t1, $t1, -128
        sw $t2, 0($t1)
        addi $t3, $t3, 1
        blt $t3, 4, left_pause2 # created pause symbols left
    
        addi $t1, $t1, 8
        add $t3, $zero, $zero
    right_pause1:
        sw $t2, 0($t1)
        addi $t1, $t1, 128
        addi $t3, $t3, 1
        blt $t3, 4, right_pause1
    
        addi $t1, $t1, 4
        add $t3, $zero, $zero
    right_pause2:
        addi $t1, $t1, -128
        sw $t2, 0($t1)
        addi $t3, $t3, 1
        blt $t3, 4, right_pause2
    
    wait_pause:
    lw $t1, 0($s2)
    beq $t1, 1, check_for_pause
    j wait_pause
    
    check_for_pause:
        lw $t2, 4($s2)
        beq $t2, 112 unpause
        beq $t2, 113, respond_to_Q
        j wait_pause
    
    unpause:
    la $t1, colour_black
    lw $t2, 0($t1)
    la $t0, ADDR_DSPL
    lw $t4, 0($t0)
    addi $t1, $t4, 264
    
    add $t3, $zero, $zero
    
    left_pause1_erase:
        sw $t2, 0($t1)
        addi $t1, $t1, 128
        addi $t3, $t3, 1
        blt $t3, 4, left_pause1_erase
        
        addi $t1, $t1, 4
        add $t3, $zero, $zero
    left_pause2_erase:
        addi $t1, $t1, -128
        sw $t2, 0($t1)
        addi $t3, $t3, 1
        blt $t3, 4, left_pause2_erase # created pause symbols left
    
        addi $t1, $t1, 8
        add $t3, $zero, $zero
    right_pause1_erase:
        sw $t2, 0($t1)
        addi $t1, $t1, 128
        addi $t3, $t3, 1
        blt $t3, 12, right_pause1_erase
    
        addi $t1, $t1, 4
        add $t3, $zero, $zero
    right_pause2_erase:
        addi $t1, $t1, -128
        sw $t2, 0($t1)
       
        addi $t3, $t3, 1
        blt $t3, 16, right_pause2_erase
    
    pop($t4)
    pop($t3)
    pop($t2)
    pop($t1)
    pop($t0)
    pop($ra)
    j game_loop


auto_fall:
            push ($ra)
            push ($t1)
            push ($t2)
            push ($t3)
            push ($a0)
            
            la $t1, colour_black # load black
            lw $t2, 0($t1)
            
            lb $t3, CAPSULE_orientation # check horizontal or vertical
            beq $t3, 0, horizontal_auto_fall_collision_check
            beq $t3, 1, vertical_auto_fall_collision_check
            
            horizontal_auto_fall_collision_check:
                lw $t1, CAPSULE_left
                addi $t1, $t1, 128
                lw $t3, 0($t1)
                bne $t2, $t3, pill_stopped # check that bottom of left is not black
                
                lw $t1, CAPSULE_right
                addi $t1, $t1, 128
                lw $t3, 0($t1)
                bne $t2, $t3, pill_stopped # check that bottom of right is not black
                j continue_auto_fall
            
            vertical_auto_fall_collision_check:
                lw $t1, CAPSULE_right
                addi $t1, $t1, 128
                lw $t3, 0($t1)
                bne $t2, $t3, pill_stopped # check that bottom of right is not black
            
            continue_auto_fall:
                # Increment frame counter
                lw $t3, frame_counter
                addi $t3, $t3, 1
                sw $t3, frame_counter
                
                # # Check if enough frames have passed
                lw $t2, max_fall_frames
                blt $t3, $t2, skip_auto_fall
                
                # Reset counter and move pill
                sw $zero, frame_counter
                
                jal erase_pill
                lw $t1, CAPSULE_left # brings the pill down one
                lw $t2, CAPSULE_right
                addi $t1, $t1, 128
                addi $t2, $t2, 128
                sw $t1, CAPSULE_left
                sw $t2, CAPSULE_right
                
                jal draw_pill
                j skip_auto_fall
            
            pill_stopped:
                sw $zero frame_counter # resets frame counter for new pill
                jal draw_pill  # Draw the stopped pill first
                jal check_loss_barrier  # NOW check if game is lost
                jal draw_pill_initial  # Spawn new pill
            
            skip_auto_fall:
                pop ($a0)
                pop ($t3)
                pop ($t2)
                pop ($t1)
                pop ($ra)
                jr $ra



move_left:
            push($ra)
            push($t0)
            push($t1) 
            push($t2)# Hold vals in stack
            push($t3)
            
            
            lw $t0, CAPSULE_left
            addi $t0, $t0, -4
            lw $t1, 0($t0)
            la $t0, colour_black
            lw $t2, 0($t0)
            bne $t1, $t2, skip_move_left
            
            
            lb $t3, CAPSULE_orientation  # check if capsule vertical so top pixel can't enter other colours
            beq $t3, 0, continue_move_left # if horizontal go ahead and rotate because right coord has already been checked
            
            lw $t0, CAPSULE_right
            addi $t0, $t0, -4
            lw $t1, 0($t0)
            la $t0, colour_black
            lw $t2, 0($t0)
            bne $t1, $t2, skip_move_left
            
            continue_move_left:
            jal erase_pill
            lw $t0, CAPSULE_left # Get left coord
            lw $t1, CAPSULE_right # Get right coord
            addi $t0, $t0, -4 # Move left coord one left
            addi $t1, $t1, -4 # Move right coord one right
            sw $t0, CAPSULE_left # store left coord
            sw $t1, CAPSULE_right # store right coord
            jal draw_pill
            
            skip_move_left: # made for collision
                pop($t3)
                pop($t2)
                pop($t1)
                pop($t0)
                pop($ra) # Restore stack
                j game_loop # go back for keyboard inputs

move_right:
            push($ra)
            push($t0)
            push($t1) 
            push($t2) # Hold vals in stack
            push($t3)
            
            lw $t0, CAPSULE_right # right held
            addi $t0, $t0, 4 # right of right
            lw $t1, 0($t0)
            la $t0, colour_black # check if right of right coord is not black so they can't move.
            lw $t2, 0($t0)
            bne $t1, $t2, skip_move_right
            
            lb $t3, CAPSULE_orientation  # check if capsule vertical so top pixel can't enter other colours
            beq $t3, 0, continue_move_right # if horizontal go ahead and rotate because right coord has already been checked
            
            
            lw $t0, CAPSULE_left # left held
            addi $t0, $t0, 4 # right of right
            lw $t1, 0($t0)
            la $t0, colour_black # check if right of right coord is not black so they can't move.
            lw $t2, 0($t0)
            bne $t1, $t2, skip_move_right
            
            
            continue_move_right:
            jal erase_pill
            lw $t0, CAPSULE_left # Get left coord
            lw $t1, CAPSULE_right # Get right coord
            addi $t0, $t0, 4 # Move left coord one right
            addi $t1, $t1, 4 # Move right coord one right
            sw $t0, CAPSULE_left #store left coord
            sw $t1, CAPSULE_right #store left coord
            jal draw_pill
            
            skip_move_right: # made for collision
                pop($t3)
                pop($t2)
                pop($t1)
                pop($t0)
                pop($ra) # Restore stack
                j game_loop # go back for keyboard inputs

rotate_pill:
            push($ra)
            push($t4)
            push($t5)
            push($t6)
            push($t7)
            push($t8)
            
            lw $t4, CAPSULE_left # load the left coord of pill
            lw $t5, CAPSULE_right # load right coord of pill
            
            lb $t6, CAPSULE_orientation # check capsule direction
            
            beq $t6, 0, horizontal_to_vertical # t6 is horizontal
            beq $t6, 1, vertical_to_horizontal # t6 is vertical
            
            horizontal_to_vertical: 
                
                la $t6, colour_black
                lw $t8, 0($t6)
                
                addi $t4, $t4, -128 #check above left pixel
                lw $t7, 0($t4)
                bne $t8, $t7, finish_rotate # check left above is not black
                
                addi $t5, $t5, -128 # check above right pixel
                lw $t7, 0($t5)
                bne $t8, $t7, finish_rotate # check right above is not black
                
                
                jal erase_pill # erase pill for rotation
                lw $t4, CAPSULE_left # load the left coord of pill
                lw $t5, CAPSULE_right # load right coord of pill
                addi $t4, $t4, -124 #t4 goes one up and one right
                addi $t6, $zero, 1 # switch position for next call
                sb $t6, CAPSULE_orientation
                sw $t4, CAPSULE_left
                sw $t5, CAPSULE_right
                jal draw_pill
                j finish_rotate
            
            vertical_to_horizontal:
                addi $t4, $t4, -4
                lw $t5, 0($t4)
                la $t6, colour_black
                lw $t7, 0($t6)
                bne $t5, $t7, finish_rotate
                
                
                jal erase_pill # erase pill for rotation
                lw $t4, CAPSULE_left # load the left coord of pill
                lw $t5, CAPSULE_right # load right coord of pill
                addi $t4, $t4, 128 # t4 goes one down
                addi $t5, $t5, -4 # t5 goes one left
                add $t6, $zero, $zero # capsule state switch
                sb $t6, CAPSULE_orientation
                sw $t4, CAPSULE_right # coordinate stored
                sw $t5, CAPSULE_left # coordinate stored
                
                lb $t7, CAPSULE_COLOUR1 # COLORS HAVE TO BE CHANGED HERE ONLY BECAUSE THIS IS WHERE A SWAP OCCURS
                lb $t8, CAPSULE_COLOUR2
                sb $t7, CAPSULE_COLOUR2
                sb $t8, CAPSULE_COLOUR1
                jal draw_pill
                
                
            finish_rotate:
                pop($t8)
                pop($t7)
                pop($t6)
                pop($t5)
                pop($t4)
                pop($ra)
                j game_loop
    
speed_drop:
            push($ra)
            push($t2)
            push($t3)
            push($t4)
            
            la $t2, colour_black # load black
            lw $t3, 0($t2)
            
            lb $t4, CAPSULE_orientation # check horizontal or vertical
            beq $t4, 0, horizontal_speed_drop_collision_check
            beq $t4, 1, vertical_speed_drop_collision_check
            
            horizontal_speed_drop_collision_check:
                lw $t2, CAPSULE_left
                addi $t2, $t2, 128
                lw $t4, 0($t2)
                bne $t3, $t4, draw_pill_initial # check that bottom of left is not black
                
                lw $t2, CAPSULE_right
                addi $t2, $t2, 128
                lw $t4, 0($t2)
                bne $t3, $t4, draw_pill_initial # check that bottom of right is not black
                j continue_speed_drop
            
            vertical_speed_drop_collision_check:
                lw $t2, CAPSULE_right
                addi $t2, $t2, 128
                lw $t4, 0($t2)
                bne $t3, $t4, draw_pill_initial # check that bottom of right is not black
            
            continue_speed_drop:
            jal erase_pill
            
            lw $t3, CAPSULE_left # capsule positions received
            lw $t4, CAPSULE_right
            addi $t3, $t3, 128 # both capsules pushed down
            addi $t4, $t4, 128
            sw $t3, CAPSULE_left # both capsules coords restored
            sw $t4, CAPSULE_right
            
            jal draw_pill
            
            skip_speed_drop:
                pop($t4)
                pop($t3)
                pop($t2)
                pop($ra)
                j game_loop
    
check_loss_barrier:
    push($ra)
    push($t1)
    push($t2)
    push($t3)
    push($t4)
    push($t5)
    push($t6)
    push($t7)
    push($s0)
    push($s1)
    
    la $t1, ADDR_DSPL
    lw $t2, 0($t1)          
    addi $t2, $t2, 1080     # Barrier line
    
    la $t7, colour_black   
    lw $t4, 0($t7)          # Black color
    
    la $t7, colour_white
    lw $t6, 0($t7)          # White color (bottle walls)
    
    # Load current pill positions to EXCLUDE them
    lw $s0, CAPSULE_left
    lw $s1, CAPSULE_right
    
    li $t1, 0    # counter

barrier_loop:
    # Skip if this is the active pill
    beq $t2, $s0, skip_pixel_check
    beq $t2, $s1, skip_pixel_check
    
    lw $t5, 0($t2)          # Load pixel color at barrier
    beq $t5, $t4, skip_pixel_check  # Skip if black (empty)
    beq $t5, $t6, skip_pixel_check  # Skip if white (bottle wall)
    
    # Found a settled colored pixel at barrier
    # Check if there's a non-black pixel directly below it
    addi $t3, $t2, 128
    lw $t7, 0($t3)
    beq $t7, $t4, skip_pixel_check  # Black below = can still fall, OK
    
    # Non-black below = stacked to top, game over!
    j game_over_loser

skip_pixel_check:
    addi $t2, $t2, 4       
    addi $t1, $t1, 1        
    blt $t1, 18, barrier_loop   # Check 18 pixels across (the bottle width)

finish_barrier_check:
    pop($s1)
    pop($s0)
    pop($t7)
    pop($t6)
    pop($t5)
    pop($t4)
    pop($t3)
    pop($t2)
    pop($t1)
    pop($ra)
    jr $ra


    


respond_to_Q:
        	li $v0, 10                      # Quit gracefully
        	syscall

draw_screen:
            push($ra)
            
            # Redraw bottle
            addi $a0, $zero, 13  # x coord
            addi $a1, $zero, 5   # y coord
            jal draw_bottle
            
            # Redraw current pill
            jal draw_pill
            
            pop($ra)
            jr $ra

erase_pill:
            addi $sp, $sp, -4        # Save return address
            sw $ra, 0($sp)      
            la $t9, colour_black    # get black colour address
            lw $t1, 0($t9) # set t1 to black
            lw $t2, CAPSULE_left #get capsule address
            sw $t1, 0($t2) #set to black
            lw $t3, CAPSULE_right 
            sw $t1, 0($t3)
            lw $ra, 0($sp)          # Restore return address
            addi $sp, $sp, 4
            jr $ra
    
draw_pill:
            push($ra)
            push($t1)
            push($t2)
            push($t3)
            push($t4)
            push($t5)
            
            lb $t1, CAPSULE_COLOUR1 # load color byte 0, 1, 2
            lb $t2, CAPSULE_COLOUR2 # load color byte 0, 1, 2
            
            
            beq $t1, 0, left_red ### check for color
            beq $t1, 1, left_yellow
            beq $t1, 2, left_blue
            
            left_red: ### Setting t3 to color and jumping to draw function
                la $t3, colour_red
                j draw_left
            left_yellow:
                la $t3, colour_yellow
                j draw_left
            left_blue:
                la $t3, colour_blue
                j draw_left
            
            draw_left:
                lw $t4, 0($t3) # set t4 to colour
                lw $t5, CAPSULE_left
                sw $t4, 0($t5)
            
            beq $t2, 0, right_red
            beq $t2, 1, right_yellow
            beq $t2, 2, right_blue
            
            right_red: ### Setting t3 to color and jumping to draw function
                la $t3, colour_red
                j draw_right
            right_yellow:
                la $t3, colour_yellow
                j draw_right
            right_blue:
                la $t3, colour_blue
                j draw_right
                
            draw_right:
                lw $t4, 0($t3) # set t4 to colour
                lw $t5, CAPSULE_right # get capsule memory
                sw $t4, 0($t5)
                
            pop($t5)
            pop($t4)
            pop($t3)
            pop($t2)
            pop($t1)
            pop($ra)
            jr $ra


# == Function to draw bottle == #
# - a0 x coord of top left bottleneck
# - a1 y coord of top left bottleneck * 128 
# - a2 diff between left and right of bottle (not inputted)
draw_bottle:
            push($ra)
            push($t0)
            push($t9)
            
            add $t1, $zero, $zero # initialize loop variable
            sll $t5, $a0, 2       # multiply x by 4
            sll $t6, $a1, 7       # multiply x by 128
            add $t2, $t0, $t5     # add x and t0 vals to t2 reg
            add $t2, $t2, $t6     # add y to t2
            add $t3, $t0, $t5     # initialize t3 for right side tracking with t0
            addi $t3, $t3, 20     # offset t3 from t2
            add $t3, $t3, $t6     # add y coord to right 
            
            
            la $t9, colour_white # load color white
            lw $t4, 0($t9) # store in t4
            
            draw_bottleneck: # code to draw just the neck
                sw $t4, 0($t2) # draw left bottleneck
                sw $t4, 0($t3) # draw right bottleneck
                addi $t1, $t1, 1 # increment counter
                addi $t2, $t2, 128 #increment left pos
                addi $t3, $t3, 128 #increment right pos
                addi $t6, $t6, 128 #add to parameter for next function
                blt $t1, 3, draw_bottleneck # draw shoulders when neck pixels are drawn 5 times
            
            add $t1, $zero, $zero # initialize loop variable
            draw_shoulders:
                sw $t4, 0($t2) # draw to left shoulder
                sw $t4, 0($t3) # draw to right shoulder
                addi $t2, $t2, -4 # go backwards/left for left shoulder
                addi $t3, $t3, 4 # go forwards/right for right shoulder
                addi $t1, $t1, 1 # increment counter
                blt $t1, 7, draw_shoulders # move to torse
                
            add $t1, $zero, $zero # initialize loop variable
            draw_torso:
                sw $t4, 0($t2) #draw to left torso
                sw $t4, 0($t3) #draw to right torso
                addi $t2, $t2, 128 # go downwards for torso left
                addi $t3, $t3, 128 # go downwards for torso right
                addi $t1, $t1, 1 # increment counter
                blt $t1, 20, draw_torso
                
            add $t1, $zero, $zero # initialize loop variable
            draw_base:
                sw $t4, 0($t2) #draw to left base
                sw $t4, 0($t3) #draw to right base
                addi $t2, $t2, 4 #go right from the left 
                addi $t3, $t3, -4 #go left from the right
                addi $t1, $t1, 1 #increment counter
                blt $t1, 10, draw_base

end_bottle:
            pop($t9)
            pop($t0)
            pop($ra)
            jr $ra            # return address

            
            
    draw_pill_initial:
    push ($ra)
    push ($t0)
    push ($t1)
    push ($t2)
    push ($t3)
    push ($t4)
    
    # Set initial positions and orientation
    sw $s0, CAPSULE_left        # Set left position (from $s0)
    sw $s1, CAPSULE_right       # Set right position (from $s1)
    sb $zero, CAPSULE_orientation # Reset to horizontal orientation

    # TRANSFER PREVIEW COLORS TO ACTIVE PILL
    lb $t0, PRE_CAPSULE_COLOUR1
    sb $t0, CAPSULE_COLOUR1
    lb $t0, PRE_CAPSULE_COLOUR2
    sb $t0, CAPSULE_COLOUR2

    # Draw the pill using the transferred colors
    jal draw_pill               # Use your existing draw_pill functionrr

    li $v0, 42                  # Random int syscall
    li $a1, 3                   
    move $a0, $zero             # Randomize first half
    syscall
    sb $a0, PRE_CAPSULE_COLOUR1
    
    move $a0, $zero             # Randomize second half
    syscall
    sb $a0, PRE_CAPSULE_COLOUR2

    # Update the preview display with new colors
    jal next_pill_preview
    
     
    
    pop ($t4)
    pop ($t3)
    pop ($t2)
    pop ($t1)
    pop ($t0)
    pop ($ra)
    jr $ra


draw_viruses:
            push ($ra)
            push ($t1)
            push ($t2)
            push ($t3)
            push ($t4)
            push ($t5)
            push ($t6)
            push ($t7)
            push ($t8)
            push ($a0)
            
            lw $t1, virus_count
            add $t2, $zero, $zero
            
            draw_virus_loop:
                addi $t3, $t0, 2460 # starting pixel for bottom half of bottle
                
                # random for horizontal pixel
                li $v0, 42  # 42 is system call code to generate random int
                li $a1, 18 # $a1 is where you set the upper bound
                add $a0, $zero, $zero # reset $a0
                syscall
                
                sll $t5, $a0, 2 # multiply by 4
                
                add $t3, $t3, $t5 # add to initial coordinate
                
                # random for vertical pixel
                li $v0, 42  # 42 is system call code to generate random int
                li $a1, 10 # $a1 is where you set the upper bound
                add $a0, $zero, $zero # reset $a0
                syscall
                
                sll $t5, $a0, 7 # multiply by 128
                
                add $t3, $t3, $t5 # add to initial coordinate
                
                #random for color select
                li $v0, 42  # 42 is system call code to generate random int
                li $a1, 3 # $a1 is where you set the upper bound
                add $a0, $zero, $zero # reset $a0
                syscall
                
                beq $a0, 0, draw_red_virus
                beq $a0, 1, draw_yellow_virus
                beq $a0, 2, draw_blue_virus
                
                draw_red_virus:
                    la $t4, colour_virus_red # load colour
                    lw $t5, 0($t4) # hold colour
                    la $t6, colour_black
                    lw $t7, 0($t6)
                    lw $t8, 0($t3)
                    bne $t7, $t8, try_finish_virus
                    sw $t5, 0($t3) # draw onto choice pixel
                    j increment_viruses
                
                draw_yellow_virus:
                    la $t4, colour_virus_yellow
                    lw $t5, 0($t4)
                    la $t6, colour_black
                    lw $t7, 0($t6)
                    lw $t8, 0($t3)
                    bne $t7, $t8, try_finish_virus
                    sw $t5, 0($t3)
                    j increment_viruses
                
                draw_blue_virus: 
                    la $t4, colour_virus_blue
                    lw $t5, 0($t4)
                    la $t6, colour_black
                    lw $t7, 0($t6)
                    lw $t8, 0($t3)
                    bne $t7, $t8, try_finish_virus
                    sw $t5, 0($t3)
                    j increment_viruses
                
                increment_viruses:
                addi $t2, $t2, 1
                try_finish_virus:
                beq $t2, $t1, finish_viruses
                j draw_virus_loop
        
finish_viruses:
            pop ($a0)
            pop ($t8)
            pop ($t7)
            pop ($t6)
            pop ($t5)
            pop ($t4)
            pop ($t3)
            pop ($t2)
            pop ($t1)
            pop ($ra)
            jr $ra
            
            
check_matches:
    push($ra)
    push($t0)
    push($t1)
    push($t2)
    push($t3)
    push($t4)
    push($t5)
    push($t6)
    push($t7)
    push($t8)
    push($t9)
    push($s0)
    push($s1)
    push($s2)
    push($s3)
    push($s4)
    push($s5)
    push($s6)
    push($s7)
    push($a0)
    
    # lw $t2, frame_counter
    # bne $t2, 0, finish_check_matches
    
    lw $t0, ADDR_DSPL
    
    jal empty_list
    
    la $t2, colour_black
    lw $t3, 0($t2) # load black
    la $t2, colour_red
    lw $t4, 0($t2) # load red
    la $t2, colour_virus_red
    lw $s4, 0($t2) # load virus red
    la $t2, colour_yellow
    lw $t5, 0($t2) # load yellow
    la $t2, colour_virus_yellow
    lw $s5, 0($t2) # load virus yellow
    la $t2, colour_blue
    lw $t6, 0($t2) # load blue
    la $t2, colour_virus_blue
    lw $s6, 0($t2) # load virus blue
    
    li $t7, 0 # counter for going downwards
    addi $t0, $t0, 1180 # starting point on the right of the first pixel inside the bottle body (not bottleneck) (top left)
  
    # t3 = black
    # t4 = red
    # t5 = yellow
    # t6 = blue
    check_horizontal_loop:
        li $t2, 0 #counter set up for going sideways
        jal empty_list
        
        scan_row:
            lw $s3, 0($t0) # load current pixel colour  
            beq $s3, $t3, skip_pixel_h #ignore black
        
            lw $t8, list_size
            beq $t8, 0, first_pixel_h
            
            lw $t1, next_index
            addi $t1, $t1, -4
            lw $t9, 0($t1) 
            lw $s2, 0($t9)
            
    bne $s2, $s3, check_virus_groups_h  # if it doesn't match check the group
    j check_colour_h                  
    
        check_virus_groups_h:
            beq $s3, $t4, red_current_h
            beq $s3, $s4, red_current_h
            beq $s3, $t5, yellow_current_h
            beq $s3, $s5, yellow_current_h
            beq $s3, $t6, blue_current_h
            beq $s3, $s6, blue_current_h
            j dont_increment_h           # not in any group, break sequence
        
        red_current_h:
            beq $s2, $t4, check_colour_h  # last was regular red
            beq $s2, $s4, check_colour_h  # last was virus red
            j dont_increment_h            
        
        yellow_current_h:
            beq $s2, $t5, check_colour_h
            beq $s2, $s5, check_colour_h
            j dont_increment_h
        
        blue_current_h:
            beq $s2, $t6, check_colour_h
            beq $s2, $s6, check_colour_h
            j dont_increment_h
            
        check_colour_h:
            beq $s3, $t4, check_red_h    # check if current pixel is red
            beq $s3, $s4,  check_red_h    
            beq $s3, $t5, check_yellow_h # check if current pixel is yellow
            beq $s3, $s5, check_yellow_h 
            beq $s3, $t6, check_blue_h   # check if current pixel is blue
            beq $s3, $s6, check_blue_h
            j dont_increment_h           # if not any of our colors, don't increment
            
        check_red_h:
            lw $t8, list_size
            beq $t8, 0, first_pixel_h      # if list is empty, this is the first pixel
            
            lw $t1, next_index           # check color of last appended pixel
            addi $t1, $t1, -4          
            lw $t9, 0($t1)             
            lw $s2, 0($t9)               # get color of last pixel
            
            beq $s2, $t4, red_match_h  # if last pixel wasn't red, reset sequence
            beq $s2, $s4, red_match_h
            j dont_increment_h
           
            red_match_h:
            add $a0, $t0, $zero          # prepare pixel address for appending
            jal list_append
            j next_pixel_h
            
        check_yellow_h:
            lw $t8, list_size
            beq $t8, 0, first_pixel_h      # if list is empty, this is the first pixel
            
            lw $t1, next_index           # check color of last appended pixel
            addi $t1, $t1, -4           
            lw $t9, 0($t1)              
            lw $s2, 0($t9)               # get color of last pixel
            
            beq $s2, $t5, yellow_match_h  # if last pixel wasn't yellow, reset sequence
            beq $s2, $s5, yellow_match_h
            j dont_increment_h
            
            yellow_match_h:
            add $a0, $t0, $zero          # prepare pixel address for appending
            jal list_append
            j next_pixel_h
    
        check_blue_h:
            lw $t8, list_size
            beq $t8, 0, first_pixel_h      # if list is empty, this is the first pixel
            
            lw $t1, next_index           # check color of last appended pixel
            addi $t1, $t1, -4            
            lw $t9, 0($t1)               
            lw $s2, 0($t9)               # get color of last pixel
            
            beq $s2, $t6, blue_match_h  # if last pixel wasn't blue, reset sequence
            beq $s2, $s6, blue_match_h
            j dont_increment_h
            
            blue_match_h:
            add $a0, $t0, $zero          # prepare pixel address for appending
            jal list_append
            j next_pixel_h

        first_pixel_h:
            add $a0, $t0, $zero          # prepare pixel address for appending
            jal list_append
            j next_pixel_h
        
        dont_increment_h:
            lw $s0, list_size
            blt $s0, 4, reset_sequence_h # if there are 4 or more elements in the list, we tetris them and empty the list
            jal paint_all_black
            j reset_sequence_h
            
        reset_sequence_h:
            jal empty_list
            add $a0, $t0, $zero
            jal list_append
        
        next_pixel_h:
            addi $t2, $t2, 1      #increment counter for rows
            beq $t2, 18, end_row_h  
            addi $t0, $t0, 4      
            j scan_row
        
        skip_pixel_h:
            lw $s0, list_size
            blt $s0, 4, incrementer_h
            jal paint_all_black
            
        incrementer_h:
            jal empty_list # goes to next pixel but empties
            addi $t2, $t2, 1 
            beq $t2, 18, end_row_h
            addi $t0, $t0, 4
            j scan_row
            
        end_row_h:
            lw $s0, list_size 
            blt $s0, 4, next_row
            jal paint_all_black
    
        next_row:
            addi $t0, $t0, 60 # go down to next traversal row
            addi $t7, $t7, 1 # add to y counter
            beq $t7, 19, check_vertical
            j check_horizontal_loop

 ### Vertical Checking ###3
 
    check_vertical:
        li $t2, 0              # x counter (columns)
        lw $t0, ADDR_DSPL      # Reset base address
        addi $t0, $t0, 1180    # Starting pixel inside bottle
        
    check_vertical_loop:
        li $t7, 0  # reverse counter due to column and row order of incrementing flip
        jal empty_list
        
        scan_column: # same logic as horizontal throughout, except 
            lw $s3, 0($t0)
            
            beq $s3, $t3, skip_pixel_v
            
            lw $t8, list_size
            beq $t8, 0, first_pixel_v
            
            lw $t1, next_index
            addi $t1, $t1, -4
            lw $t9, 0($t1)       
            lw $s2, 0($t9)       
            
            bne $s2, $s3, check_virus_groups_v  # if not match, check groups
            j check_colour_v                    
    
            check_virus_groups_v:
                beq $s3, $t4, red_current_v
                beq $s3, $s4, red_current_v
                beq $s3, $t5, yellow_current_v
                beq $s3, $s5, yellow_current_v
                beq $s3, $t6, blue_current_v
                beq $s3, $s6, blue_current_v
                j dont_increment_v          
            
            red_current_v:
                beq $s2, $t4, check_colour_v  # last was regular red
                beq $s2, $s4, check_colour_v  # last was virus red
                j dont_increment_v            
            
            yellow_current_v:
                beq $s2, $t5, check_colour_v # yellow and virus
                beq $s2, $s5, check_colour_v
                j dont_increment_v
            
            blue_current_v:
                beq $s2, $t6, check_colour_v # blue and virus
                beq $s2, $s6, check_colour_v
                j dont_increment_v
            
            
        check_colour_v:
        beq $s3, $t4, check_red_v    # check if current pixel is red
        beq $s3, $s4, check_red_v
        beq $s3, $t5, check_yellow_v # check if current pixel is yellow
        beq $s3, $s5, check_yellow_v
        beq $s3, $t6, check_blue_v   # check if current pixel is blue
        beq $s3, $s6, check_blue_v
        j dont_increment_v           # if not any of our colors, don't increment
        
        check_red_v:
            lw $t8, list_size
            beq $t8, 0, first_pixel_v      # if list is empty, this is the first pixel
            
            lw $t1, next_index           # check color of last appended pixel
            addi $t1, $t1, -4           
            lw $t9, 0($t1)               
            lw $s2, 0($t9)               # get color of last pixel
            
            beq $s2, $t4, red_match_v  # if last pixel wasn't red, reset sequence
            beq $s2, $s4, red_match_v
            j dont_increment_v
            
        red_match_v:
            add $a0, $t0, $zero          # prepare pixel address for appending
            jal list_append
            j next_pixel_v
            
        check_yellow_v:
            lw $t8, list_size
            beq $t8, 0, first_pixel_v      # if list is empty, this is the first pixel
            
            lw $t1, next_index           # check color of last appended pixel
            addi $t1, $t1, -4            
            lw $t9, 0($t1)               
            lw $s2, 0($t9)               # get color of last pixel
            
            beq $s2, $t5, yellow_match_v  # if last pixel wasn't yellow, reset sequence
            beq $s2, $s5, yellow_match_v
            j dont_increment_v
            
            yellow_match_v:
            add $a0, $t0, $zero          # prepare pixel address for appending
            jal list_append
            j next_pixel_v
            
        check_blue_v:
            lw $t8, list_size
            beqz $t8, first_pixel_v      # if list is empty, this is the first pixel
            
            lw $t1, next_index           # check color of last appended pixel
            addi $t1, $t1, -4            
            lw $t9, 0($t1)               
            lw $s2, 0($t9)               # get color of last pixel
            
            beq $s2, $t6, blue_match_v  # if last pixel wasn't blue, reset sequence
            beq $s2, $s6, blue_match_v
            j dont_increment_v
            
            blue_match_v:
            add $a0, $t0, $zero          # prepare pixel address for appending
            jal list_append
            j next_pixel_v
            
        first_pixel_v:
            add $a0, $t0, $zero 
            jal list_append
            j next_pixel_v
            
        dont_increment_v:
            lw $s0, list_size
            blt $s0, 4, reset_sequence_v
            jal paint_all_black
            j reset_sequence_v
            
        reset_sequence_v:
            jal empty_list     
            add $a0, $t0, $zero 
            jal list_append
            
        next_pixel_v:
            addi $t7, $t7, 1   
            beq $t7, 19, end_column  
            addi $t0, $t0, 128   
            j scan_column
            
        skip_pixel_v:
            lw $s0, list_size
            blt $s0, 4, increment_v
            jal paint_all_black
            
        increment_v:
            jal empty_list
            addi $t7, $t7, 1      
            beq $t7, 19, end_column
            addi $t0, $t0, 128    
            j scan_column
            
        end_column:
            lw $s0, list_size
            blt $s0, 4, next_column
            jal paint_all_black
            
        next_column:
            lw $t0, ADDR_DSPL    
            addi $t0, $t0, 1180  
            addi $t2, $t2, 1     
            
            move $t1, $t2
            sll $t1, $t1, 2      
            add $t0, $t0, $t1    
            
            beq $t2, 18, finish_check_matches
            j check_vertical_loop

finish_check_matches:
    pop($a0)
    pop($s7)
    pop($s6)
    pop($s5)
    pop($s4)
    pop($s3)
    pop($s2)
    pop($s1)
    pop($s0)
    pop($t9)
    pop($t8)
    pop($t7)
    pop($t6)
    pop($t5)
    pop($t4)
    pop($t3)
    pop($t2)
    pop($t1)
    pop($t0)
    pop($ra)
    jr $ra


list_append:
    push($ra)
    push($t1)
    push($t2)
    
    lw   $t1, next_index      # Go to index
    sw   $a0, 0($t1)          # Store pixel memory address in list
    
    addi $t1, $t1, 4          # Move to next slot in memory
    sw   $t1, next_index      # Update next_index
    
    lw   $t2, list_size       # increment list_size
    addi $t2, $t2, 1
    sw   $t2, list_size
    
    pop($t2)
    pop($t1)
    pop($ra)
    jr $ra

paint_all_black:
    push($ra)
    push($t0)   
    push($t1)       
    push($t2)       
    push($t3)      
    push($t4)
    push($t5)
    push($t6)
    push($t7)
    push($t8)
    
    
    la $t0, consecutive_pixels 
    lw $t1, list_size           # number of pixels to paint
    la $t2, colour_black        # load black
    lw $t3, 0($t2)              
    la $t2, colour_virus_red
    lw $t4, 0($t2)
    la $t2, colour_virus_yellow # virus colours
    lw $t5, 0($t2)
    la $t2, colour_virus_blue
    lw $t6, 0($t2)
    
    beq $t1, 0, end_black_paint  

paint_black_loop:
    
    lw $t2, 0($t0)          # load pixel
    lw $t7, 0($t2)
    sw $t3, 0($t2)          
    
    
    beq $t7, $t4, is_virus # check for viruses
    beq $t7, $t5, is_virus
    beq $t7, $t6, is_virus
    j no_virus
    
    is_virus:
    lw $t8, virus_count
    # ble $t8, 0, no_virus
    addi $t8, $t8, -1
    sw $t8, virus_count
    
    no_virus:
    addi $t0, $t0, 4        # Move to next list index
    addi $t1, $t1, -1       
    bne $t1, 0, paint_black_loop  

end_black_paint:
    pop($t8)
    pop($t7)
    pop($t6)
    pop($t5)
    pop($t4)
    pop($t3)
    pop($t2)
    pop($t1)
    pop($t0)
    pop($ra)
    jr $ra



empty_list:
    push($ra)
    push($t0)
    la $t0, consecutive_pixels   # address of the list
    sw $t0, next_index           # Reset next_index to beginning
    sw $zero, list_size          # Reset size counter to 0
    pop($t0)
    pop($ra)
    jr $ra
    

check_falling_pixels:
    push($ra)
    push($t0)
    push($t1)
    push($t2)
    push($t3)
    push($t4)
    push($t5)
    push($t6)
    push($t7)
    push($t8)
    push($t9)
    push($s0)
    push($s1)
    push($s2)
    push($s3)
    push($s4)
    
    lw $t0, ADDR_DSPL
    la $t2, colour_black
    lw $t1, 0($t2) # load black
    la $t2, colour_virus_red
    lw $s2, 0($t2)
    la $t2, colour_virus_yellow
    lw $s3, 0($t2)
    la $t2, colour_virus_blue
    lw $s4, 0($t2)
    
    lw $s0, CAPSULE_left
    lw $s0, CAPSULE_right
    
    addi $t0, $t0, 3740 # top left as usual for iterating
    li $t3, 0 # set counter for column
    
    check_falling:
    li $t4, 0 # set counter for row
    move $t7, $t0
        
        falling_loop:
            beq $t7, $s0, no_falling
            beq $t7, $s1, no_falling
        
            lw $t5, 0($t7) # current pixel colour
            beq $t5, $t1, no_falling
            beq $t5, $s2, no_falling
            beq $t5, $s3, no_falling
            beq $t5, $s4, no_falling
            
            addi $t9, $t7, 4 # check the right of this pixel, if not black, move on
            lw $t8, 0($t9)
            bne $t8, $t1, no_falling
            
            addi $t9, $t7, -4 # check the right of this pixel, if not black, move on
            lw $t8, 0($t9)
            bne $t8, $t1, no_falling
            
            addi $t9, $t7, 128 # check the right of this pixel, if not black, move on
            lw $t8, 0($t9)
            bne $t8, $t1, no_falling
            
        pixel_falls:
            move $t6, $t7 # move the info so it is unchanged for next loop
            addi $t6, $t6, 128
            lw $t8, 0($t6) # check the pixel under and dont go if it is not black
            bne $t8, $t1, no_falling
            
            sw $t1, 0($t7)
            sw $t5, 0($t6)
            move $t7, $t6 # reset the new pixel as the current pixel
            j pixel_falls
            
        no_falling:
            addi $t4, $t4, 1 # checks if it is a new column or just a new 
            beq $t4, 19, column_end_falling
            addi $t7, $t7, -128 # you have to go bottom to top because otherwise you will miss pixels every frame
            j falling_loop
    
        column_end_falling:
            addi $t3, $t3, 1 # goes to next column downwards
            beq $t3, 18, finish_pixel_falling
            lw $t0, ADDR_DSPL
            addi $t0, $t0, 3740
            sll $t9, $t3, 2 # multiply by 4 for the amount of columns already covered. This variable is dynamic with the count
            add $t0, $t0, $t9
            j check_falling
            
    finish_pixel_falling:
    pop($s4)
    pop($s3)
    pop($s2)
    pop($s1)
    pop($s0)
    pop($t9)
    pop($t8)
    pop($t7)
    pop($t6)
    pop($t5)
    pop($t4)
    pop($t3)
    pop($t2)
    pop($t1)
    pop($t0)
    pop($ra)
    jr $ra


game_over_loser:
        push($ra)
        push($t0)
        push($t1)
        push($t2)
        push($t3)
        push($t4)
        
        jal erase_screen
        
        la $t0, ADDR_DSPL
        lw $t1, 0($t0) # load address
        
        addi $t1, $t1, 1032 #starting point
        
        la $t0, colour_white
        lw $t2, 0($t0) # load white
        
        li $t3, 0 # counter
        
        
        draw_O1_top:
            sw $t2, 0($t1) # draw
            addi $t1, $t1, 4
            addi $t3, $t3, 1
            
            blt $t3, 4, draw_O1_top
        li $t3, 0
        addi $t1, $t1, 108
        
        draw_O1_sides:
            sw $t2, 0($t1)
            sw $t2, 20($t1)
            addi $t1, $t1, 128
            addi $t3, $t3, 1
            blt $t3, 7, draw_O1_sides
            
        li $t3, 0
        
        draw_O1_bottom:
            addi $t1, $t1, 4
            addi $t3, $t3, 1
            sw $t2, 0($t1)
            blt $t3, 4, draw_O1_bottom
        
        li $t3, 0 # reset
        addi $t1, $t1, 16
        
        draw_H_sides:
            sw $t2, 0($t1)
            sw $t2, 20($t1)
            addi $t1, $t1, -128
            addi $t3, $t3, 1
            blt $t3, 9, draw_H_sides
        
        addi $t1, $t1, 640 # middle of h
        li $t3, 0
        draw_middle_H:
            addi $t1, $t1, 4
            addi $t3, $t3, 1
            sw $t2, 0($t1)
            blt $t3, 4, draw_middle_H
        
        addi $t1, $t1, 528
        li $t3, 0
        
        draw_N_loss_sides:
            sw $t2, 0($t1)
            sw $t2, 20($t1)
            addi $t1, $t1, -128
            addi $t3, $t3, 1
            blt $t3, 9, draw_N_loss_sides
        
        li $t3, 0
        addi $t1, $t1, 132
        draw_N_dash_loss:
            sw $t2, 0($t1)
            sw $t2, 128($t1)
            addi $t3, $t3, 1
            addi $t1, $t1, 260
            blt $t3, 4, draw_N_dash_loss
        
        add $t1, $t1, -1012 
        li $t3, 0
        draw_O2_top:
            sw $t2, 0($t1) # draw
            addi $t1, $t1, 4
            addi $t3, $t3, 1
            blt $t3, 4, draw_O2_top
            
        li $t3, 0
        addi $t1, $t1, 108
        
        draw_O2_sides:
            sw $t2, 0($t1)
            sw $t2, 20($t1)
            addi $t1, $t1, 128
            addi $t3, $t3, 1
            blt $t3, 7, draw_O2_sides
        
         li $t3, 0
        
        draw_O2_bottom:
            addi $t1, $t1, 4
            addi $t3, $t3, 1
            sw $t2, 0($t1)
            blt $t3, 4, draw_O2_bottom
            
        
        pop($t4)
        pop($t3)
        pop($t2)
        pop($t1)
        pop($t0)
        pop($ra)
        j again

check_win_condition:
    push($ra)
    push($t0)
    lw $t0, virus_count
    ble $t0, 0, game_over_winner
    pop($t0)
    pop($ra)
    jr $ra

game_over_winner:
    push($ra)
    push($t0)
    push($t1)
    push($t2)
    push($t3)
    push($t4)
    
    jal erase_screen
    
    la $t0, ADDR_DSPL
    lw $t1, 0($t0)
    
    la $t0, colour_white
    lw $t2, 0($t0)
    
    li $t3, 0 # counter
    
    addi $t1, $t1, 1032
    
    draw_W_sides:
        sw $t2, 0($t1)
        sw $t2, 20($t1)
        addi $t3, $t3, 1
        addi $t1, $t1, 128
        blt $t3, 7, draw_W_sides
    
    li $t3, 0
    draw_W_bottom:
        sw $t2, 0($t1)
        addi $t3, $t3, 1
        addi $t1, $t1, 4
        blt $t3, 5, draw_W_bottom
    
    li $t3, 0
    addi $t1, $t1, -8
    draw_W_mid:
        sw $t2, 0($t1)
        addi $t3, $t3, 1
        addi $t1, $t1, -128
        blt $t3, 4, draw_W_mid
    
    li $t3, 0
    addi $t1, $t1, -348
    draw_i:
        sw $t2, 0($t1)
        addi $t1, $t1, 128
        addi $t3, $t3, 1
        blt $t3, 8, draw_i
    
    li $t3, 0
    addi $t1, $t1, 32
    
    draw_N_win_sides:
            sw $t2, 0($t1)
            sw $t2, 20($t1)
            addi $t1, $t1, -128
            addi $t3, $t3, 1
            blt $t3, 9, draw_N_win_sides
        
    li $t3, 0
    addi $t1, $t1, 132
    draw_N_dash_win:
        sw $t2, 0($t1)
        sw $t2, 128($t1)
        addi $t3, $t3, 1
        addi $t1, $t1, 260
        blt $t3, 4, draw_N_dash_win
    
    
    
    pop($t4)
    pop($t3)
    pop($t2)
    pop($t1)
    pop($t0)
    pop($ra)
    j again

erase_screen:
        push($ra)
        push($t0)
        push($t1)
        push($t2)
        push($t3)
        
        la $t0, ADDR_DSPL
        lw $t1, 0($t0) # hold address
        
        la $t0, colour_black
        lw $t2, 0($t0) # load black
        
        li $t3, 0 # counter for x
        
        erase_loop:
            sw $t2, 0($t1) # paint pixel black
            addi $t1, $t1, 4
            addi $t3, $t3, 1
            blt $t3, 1024, erase_loop
            
        pop($t3)
        pop($t2)
        pop($t1)
        pop($t0)
        pop($ra)
        jr $ra

again:
    push($ra)
    push($t0)
    push($t1)
    push($t2)
    push($t3)
    push($t4)
    
    la $t0, ADDR_DSPL
    lw $t1, 0($t0) # load address
    
    la $t0, colour_white
    lw $t2, 0($t0) # load white
    
    li $t3, 0 # counter
    addi $t1, $t1, 2948
    draw_A_top1:
        sw $t2, 0($t1)
        addi $t1, $t1, 4
        addi $t3, $t3, 1
        blt $t3, 4, draw_A_top1
    
    li $t3, 0
    addi $t1, $t1 368
    
    draw_middle_line_A1:
        sw $t2, 0($t1)
        addi $t1, $t1, 4
        addi $t3, $t3, 1
        blt $t3, 4, draw_middle_line_A1
    
    li $t3, 0
    addi $t1, $t1, -400
    
    draw_A1_sides:
        sw $t2, 0($t1)
        sw $t2, 16($t1)
        addi $t3, $t3, 1
        addi $t1, $t1, 128
        blt $t3, 6, draw_A1_sides
    
    li $t3, 0
    addi $t1, $t1, -728
    
    draw_G_top:
        sw $t2, 0($t1)
        addi $t1, $t1, -4
        addi $t3, $t3, 1
        blt $t3, 4, draw_G_top
    
    li $t3, 0
    
    draw_G_side:
        sw $t2, 0($t1)
        addi $t1, $t1, 128
        addi $t3, $t3, 1
        blt $t3, 5, draw_G_side
    
    li $t3, 0
    
    draw_G_bottom:
        sw $t2, 0($t1)
        addi $t1, $t1, 4
        addi $t3, $t3, 1
        blt $t3, 4, draw_G_bottom
    
    li $t3, 0
    
    draw_G_side_up:
        sw $t2, 0($t1)
        addi $t1, $t1, -128
        addi $t3, $t3, 1
        blt $t3, 2, draw_G_side_up
    
    li $t3, 0
    
    draw_g_lip:
        sw $t2, 0($t1)
        addi $t1, $t1, -4
        addi $t3, $t3, 1
        blt $t3, 2, draw_g_lip
    
    li $t3, 0
    addi $t1, $t1, -368
    
    draw_A_top2:
        sw $t2, 0($t1)
        addi $t1, $t1, 4
        addi $t3, $t3, 1
        blt $t3, 4, draw_A_top2
    
    li $t3, 0
    addi $t1, $t1 368
    
    draw_middle_line_A2:
        sw $t2, 0($t1)
        addi $t1, $t1, 4
        addi $t3, $t3, 1
        blt $t3, 4, draw_middle_line_A2
    
    li $t3, 0
    addi $t1, $t1, -400
    
    draw_A2_sides:
        sw $t2, 0($t1)
        sw $t2, 16($t1)
        addi $t3, $t3, 1
        addi $t1, $t1, 128
        blt $t3, 6, draw_A2_sides
    
    li $t3, 0
    addi $t1, $t1, -744
    
    draw_i_end:
        sw $t2, 0($t1)
        addi $t1, $t1, 128
        addi $t3, $t3, 1
        blt $t3, 6, draw_i_end
    
    li $t3, 0
    addi $t1, $t1, -120
    
    draw_N_end_sides:
            sw $t2, 0($t1)
            sw $t2, 20($t1)
            addi $t1, $t1, -128
            addi $t3, $t3, 1
            blt $t3, 6, draw_N_end_sides
        
        li $t3, 0
        addi $t1, $t1, 132
        draw_N_dash_end:
            sw $t2, 0($t1)
            sw $t2, 128($t1)
            addi $t3, $t3, 1
            addi $t1, $t1, 132
            blt $t3, 4, draw_N_dash_end
        
        li $t3, 0
        addi $t1, $t1, -504
        draw_question_mark_top:
            sw $t2, 0($t1)
            addi $t3, $t3, 1
            addi $t1, $t1, 4
            blt $t3, 3, draw_question_mark_top
        
        li $t3, 0
        draw_question_side:
            sw $t2, 0($t1)
            addi $t3, $t3, 1
            addi $t1, $t1, 128
            blt $t3, 4, draw_question_side
        
        li $t3, 0
        draw_question_bottom:
            sw $t2, 0($t1)
            addi $t3, $t3, 1
            addi $t1, $t1, -4
            blt $t3, 3, draw_question_bottom
        addi $t1, $t1, 132
        sw $t2, 0($t1)
        sw $t2, 256($t1)
            
    wait_again:
    lw $t1, 0($s2)
    beq $t1, 1, check_for_again
    j wait_again
    
    check_for_again:
        lw $t2, 4($s2)
        beq $t2, 114, restart
        beq $t2, 113, respond_to_Q
        j wait_again
    restart:
    li $t0, 4
    sw $t0, virus_count
    pop($t3)
    pop($t2)
    pop($t1)
    pop($t0)
    pop($ra)
    j main