module tetris
	(
		CLOCK_50,						//	On Board 50 MHz
		// Your inputs and outputs here
		KEY,
		SW,// On Board Keys
		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B,   						//	VGA Blue[9:0]
		AUD_ADCDAT,
		AUD_BCLK,
		AUD_ADCLRCK,
		AUD_DACLRCK,
		FPGA_I2C_SDAT,
		AUD_XCK,
		AUD_DACDAT,
		FPGA_I2C_SCLK
	);

	input  CLOCK_50;				//	50 MHz
	input	[3:0]	KEY;
	input [9:0] SW;
	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output wire		VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[7:0]	VGA_R;   				//	VGA Red[7:0] Changed from 10 to 8-bit DAC
	output	[7:0]	VGA_G;	 				//	VGA Green[7:0]
	output	[7:0]	VGA_B;   				//	VGA Blue[7:0]
	
	wire resetn;
	assign resetn = !SW[0];

	wire [2:0] colour;
	wire [7:0] x;
	wire [6:0] y;
	wire writeEn = 1;
	
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour), // if there's an error change this line
			.x(x),
			.y(y),
			.plot(writeEn),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(vsync),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "tetris.mif";

		wire [15:0] b_1; // b_1 - b_3 connects current piece to draw
		wire [15:0] b_2;
		wire [15:0] b_3;
		wire [7:0] x_init; // connects output x from pieceController to x_init of draw
		wire [6:0] y_init; // connects output x from pieceController to y_init of draw
		wire enable;		 // connects rate divider to pieceController and pieceSwitcher
		wire initialize_piece;	// sends signal to intialize a new piece
		wire collision;			// sends signal to indicate a collision
		wire reset_board;			// sends signal to reset board
		wire savePiece;			// sends signal to save piece into board memory
		wire [2:0] pieceType;	// 3 bit value indicating piece type, doubles as RGB value in draw module
		wire [7:0] score;			// unused currently
		wire [3:0] rows_cleared;// unused currently
		wire lose;		// indicates that a piece has reached the top of the screen
		wire vsync;		// active low --> goes low when screen refreshes --> stays high otherwise
		
		assign VGA_VS = vsync;
		
		wire [299:0] game_board; // stores a 1 at every location on the board where a block exists
		// access location (x,y) by indexing game_board[4'b1010 * (y / 3'b100) + (x / 3'b100)] where 0 <= x <= 1001 and 0 <= y <= 10011
		
					  
		controlPath main_controlPath(.rows_cleared(rows_cleared), 
											  .score(score), 
											  .clock(CLOCK_50), 
											  .game_board(game_board), 
											  .start(!KEY[1]), 
											  .savePiece(savePiece), 
											  .reset_board(reset_board), 
											  .initialize_piece(initialize_piece), 
											  .collision(collision));
		
//		rateDivider #(.frequency(26'b101111101011110000100000)) pieceMovement(.enable(enable), 
//																			  .clock(CLOCK_50), 
//																			  .reset(resetn));
		
		rateDivider #(.frequency(26'b101111101011110000100000)) pieceMovement(.enable(enable), 
																			  .clock(CLOCK_50), 
																			  .reset(resetn));		
																			  
		pieceController main_pieceController(.clock(CLOCK_50), 
														 .initialize_piece(initialize_piece), 
														 .collision(collision), 
														 .x(x_init), 
														 .y(y_init), 
														 .b_1(b_1), 
														 .b_2(b_2), 
														 .b_3(b_3), 
														 .enable(enable), 
														 .move_r(KEY[2]), 
														 .move_l(KEY[3]), 
														 .startErase(startErase), 
														 .game_board(game_board));
		
		pieceSwitcher main_pieceSwitcher(.selection(pieceType), 
													.savePiece(savePiece), 
													.r_cw(KEY[0]), 
													.r_ccw(KEY[1]), 
													.initialize_piece(initialize_piece), 
													.enable(enable), 
													.clock(CLOCK_50), 
													.game_board(game_board), 
													.x(x_init), 
													.y(y_init), 
													.b_1(b_1), 
													.b_2(b_2), 
													.b_3(b_3));
		
		draw main_draw(.reset_board(reset_board), 
							.pieceType(pieceType), 
							.x_block(x_init), 
							.y_block(y_init), 
							.startErase(startErase), 
							.clock(CLOCK_50), 
							.x(x), 
							.y(y), 
							.b_1(b_1), 
							.b_2(b_2), 
							.b_3(b_3), 
							.colour(colour),
							.vsync(vsync),
							.game_board(game_board));
		
		updateBoard main_updateBoard(.rows_cleared(rows_cleared), 
											  .clock(CLOCK_50), 
											  .savePiece(savePiece), 
											  .game_board(game_board), 
											  .reset_board(reset_board), 
											  .x(x_init), 
											  .y(y_init), 
											  .b_1(b_1), 
											  .b_2(b_2), 
											  .b_3(b_3));
// audio controller starts here
											  
	input	AUD_ADCDAT;

	// Bidirectionals
	inout	AUD_BCLK;
	inout	AUD_ADCLRCK;
	inout	AUD_DACLRCK;

	inout	FPGA_I2C_SDAT;

	// Outputs
	output AUD_XCK;
	output AUD_DACDAT;

	output FPGA_I2C_SCLK;

	wire audio_in_available;
	wire [31:0] left_channel_audio_in;
	wire [31:0] right_channel_audio_in;
	wire read_audio_in;

	wire audio_out_allowed;
	wire [31:0] left_channel_audio_out;
	wire [31:0] right_channel_audio_out;
	wire write_audio_out;

	reg [18:0] delay_cnt;
	wire [18:0] delay;

	reg snd;
	
	reg collisionPulse;
	reg [23:0] collisionPulseCounter;
	
	always @(posedge CLOCK_50) begin
		if (collision == 1'b1) begin
			collisionPulse = 1'b1;
			collisionPulseCounter = 24'b0;
		end
		
		collisionPulseCounter = collisionPulseCounter + 1'b1;
		
		if (collisionPulseCounter == 24'b101111101011110000100000) begin
			collisionPulse = 1'b0;
		end
	end
	
	always @(posedge CLOCK_50)
		if(delay_cnt == delay) begin
			delay_cnt <= 0;
			snd <= !snd;
		end else delay_cnt <= delay_cnt + 1;

	assign delay = {4'b0010, 15'd3000};

	wire [31:0] sound = (collisionPulse == 0) ? 0 : snd ? 32'd10000000 : -32'd10000000;

	assign read_audio_in	= audio_in_available & audio_out_allowed;

	assign left_channel_audio_out = left_channel_audio_in + sound;
	assign right_channel_audio_out = right_channel_audio_in + sound;
	assign write_audio_out = audio_in_available & audio_out_allowed;

	Audio_Controller Audio_Controller(
		// Inputs
		.CLOCK_50(CLOCK_50),
		.reset(1'b0),

		.clear_audio_in_memory(),
		.read_audio_in(read_audio_in),
		
		.clear_audio_out_memory(),
		.left_channel_audio_out(left_channel_audio_out),
		.right_channel_audio_out(right_channel_audio_out),
		.write_audio_out(write_audio_out),

		.AUD_ADCDAT(AUD_ADCDAT),

		// Bidirectionals
		.AUD_BCLK(AUD_BCLK),
		.AUD_ADCLRCK(AUD_ADCLRCK),
		.AUD_DACLRCK(AUD_DACLRCK),


		// Outputs
		.audio_in_available(audio_in_available),
		.left_channel_audio_in(left_channel_audio_in),
		.right_channel_audio_in(right_channel_audio_in),

		.audio_out_allowed(audio_out_allowed),

		.AUD_XCK(AUD_XCK),
		.AUD_DACDAT(AUD_DACDAT));
		
	avconf #(.USE_MIC_INPUT(1)) avc (
			.FPGA_I2C_SCLK(FPGA_I2C_SCLK),
			.FPGA_I2C_SDAT(FPGA_I2C_SDAT),
			.CLOCK_50(CLOCK_50),
			.reset(1'b0));
endmodule

 //controlPath controls the states that the game is in

module controlPath(clock, start, reset_board, collision, initialize_piece, savePiece, game_board, rows_cleared, score);
	
	input start;
	input clock;
	input collision;
	input [299:0] game_board;
	input [2:0] rows_cleared;	// clear is an input for how many rows have been cleared (max = 4)
	
	output reg reset_board;
	output reg initialize_piece;
	output reg savePiece;
	output reg [7:0] score;
	
	reg lose;
	reg [5:0] current_state, next_state;
	
	localparam WAIT_START_HIGH = 6'b0,
				  WAIT_START_LOW = 6'b1,
				  INITIALIZE_PIECE = 6'b10,
				  MOVE_PIECE = 6'b11,
				  STOP_PIECE = 6'b100,
				  CLEAR_ROW = 6'b101,
				  CHECK_LOSE = 6'b111,
				  END_GAME = 6'b1000,
				  INITIALIZE_BOARD = 6'b1001,
				  INITIALIZE_PIECE_PAUSE = 6'b1010,
				  STOP_PIECE_PAUSE = 6'b1011;
				   
	always@(*)
	begin: state_table
		case (current_state)
			// wait for user to press start
			WAIT_START_HIGH: next_state = start ? WAIT_START_LOW : WAIT_START_HIGH;
			
			// wait for user to release start
			WAIT_START_LOW: next_state = start ? WAIT_START_LOW : INITIALIZE_BOARD;
			
			// initialize game board by clearing
			INITIALIZE_BOARD: next_state = INITIALIZE_PIECE;
			
			// pick piece to give control to player, position at top centre of screen
			INITIALIZE_PIECE: next_state = INITIALIZE_PIECE_PAUSE;
			
			INITIALIZE_PIECE_PAUSE: next_state = MOVE_PIECE;
			
			// allow player to move piece until it collides with something below
			MOVE_PIECE: next_state = collision ? STOP_PIECE : MOVE_PIECE;
			
			// if collided, remove control from player and add piece to the board memory
			STOP_PIECE: next_state = CLEAR_ROW;
			
			// clear row that player has filled - once clear, check if player lost (edge case)
			CLEAR_ROW: next_state = CHECK_LOSE;
			
			// check if a piece was placed the top of the screen - if yes, end the game, if no, initialize the next piece
			CHECK_LOSE: next_state = lose ? END_GAME : INITIALIZE_PIECE;
			
			// end game by calculating score - maybe some fancy text if we have time
			END_GAME: next_state = WAIT_START_HIGH;
			
			default: next_state = WAIT_START_HIGH;
		endcase
	end
	
	always @(posedge clock)
	begin
		case (current_state)
			INITIALIZE_BOARD: begin
				reset_board = 1'b1;
				score = 8'b0;
			end
			INITIALIZE_PIECE: begin
				reset_board = 1'b0;
				initialize_piece = 1'b1;
			end
			MOVE_PIECE: begin
				initialize_piece = 1'b0;
			end
			STOP_PIECE: begin
				savePiece = 1'b1;
			end
			CLEAR_ROW: begin
				savePiece = 1'b0;
				score = score + rows_cleared;
			end
			CHECK_LOSE: begin
				if (game_board[9:0] != 10'b0)
					lose = 1'b1;
				else
					lose = 1'b0;
			end
//			END_GAME: begin
//			
//			end
		endcase
	end
	
	always@(posedge clock)
	begin
			current_state <= next_state;
	end
	
endmodule

// pieceController gives or takes control from the player. Thus it must also handle collision detection and send a signal to update the board

module pieceController(clock, initialize_piece, x, y, b_1, b_2, b_3, enable, move_r, move_l, startErase, game_board, collision);
	input clock;
	input enable;
	input move_r;
	input move_l;
	input initialize_piece;
	
	input [15:0] b_1;
	input [15:0] b_2;
	input [15:0] b_3;
	input [299:0] game_board;
	
	output reg [7:0] x;
	output reg [6:0] y;
	output reg startErase;
	output reg collision;
	
	reg [6:0] eraseCounter;
	reg is_moving;

	always@(posedge clock) begin
		if (initialize_piece == 1'b1) begin
			x = 8'b1010000;	// initialize x to 80px, which is the leftmost px of the 5th block from the left of the gameboard
			y = 7'b0;	// set y to 0px, which is at the top of the screen
			collision = 1'b0;
			is_moving = 1'b1;
		end
		
		if (is_moving == 1'b1) begin
			if (enable == 1'b1) begin
			
				// check if it can move down - if yes, move down, if no, send signal that piece has stopped moving
				if (y == 7'b1110100 
				|| y + b_1[7:0] * 3'b100 == 7'b1110100 
				|| y + b_2[7:0] * 3'b100 == 7'b1110100 
				|| y + b_3[7:0] * 3'b100 == 7'b1110100) begin
					// reached bottom - send signal to stop moving piece
					collision = 1'b1;
					is_moving = 1'b0;
				end
				else if (game_board[9'b1010 * (y / 3'b100 + 1'b1) + (x - 6'b111100) / 3'b100] == 1'b1 
				|| game_board[9'b1010 * (y / 3'b100 + {b_1[7], b_1[7:0]} + 1'b1) + (x - 6'b111100) / 3'b100 + {b_1[15], b_1[15:8]}] == 1'b1
				|| game_board[9'b1010 * (y / 3'b100 + {b_2[7], b_2[7:0]} + 1'b1) + (x - 6'b111100) / 3'b100 + {b_2[15], b_2[15:8]}] == 1'b1
				|| game_board[9'b1010 * (y / 3'b100 + {b_3[7], b_3[7:0]} + 1'b1) + (x - 6'b111100) / 3'b100 + {b_3[15], b_3[15:8]}] == 1'b1) begin
					// has block below - send signal to stop moving piece
					collision = 1'b1;
					is_moving = 1'b0;
				end
				else if (collision == 1'b0) begin
//					startErase = 1'b1;
//					eraseCounter = 7'b0;
					y = y + 3'b100;
				end
				
				if (is_moving == 1'b1) begin
					// check if it can move left or right - if yes, move left and right, if no, prevent movement (this should send no signals)
					if (move_r == 1'b0) begin
						if (x == 8'b1100000
						|| x + 3'b100 * b_1[15:8] == 8'b1100000
						|| x + 3'b100 * b_2[15:8] == 8'b1100000
						|| x + 3'b100 * b_3[15:8] == 8'b1100000
						) begin
							// do nothing
						end
						else if (game_board[9'b1010 * y / 3'b100 + (x - 6'b111100) / 3'b100 + 1'b1] == 1'b1 
						|| game_board[9'b1010 * (y / 3'b100 + {b_1[7], b_1[7:0]}) + (x - 6'b111100) / 3'b100 + {b_1[15], b_1[15:8]} + 1'b1] == 1'b1
						|| game_board[9'b1010 * (y / 3'b100 + {b_2[7], b_2[7:0]}) + (x - 6'b111100) / 3'b100 + {b_2[15], b_2[15:8]} + 1'b1] == 1'b1
						|| game_board[9'b1010 * (y / 3'b100 + {b_3[7], b_3[7:0]}) + (x - 6'b111100) / 3'b100 + {b_3[15], b_3[15:8]} + 1'b1] == 1'b1) begin
							// do nothing
						end
						else begin
							x = x + 3'b100;
						end
					end
					else if (move_l == 1'b0) begin
						if (x == 8'b111100
						|| x + 3'b100 * b_1[15:8] == 8'b111100
						|| x + 3'b100 * b_2[15:8] == 8'b111100 
						|| x + 3'b100 * b_3[15:8] == 8'b111100) begin
							// do nothing
						end
						else if (game_board[9'b1010 * y / 3'b100 + (x - 6'b111100) / 3'b100 - 1'b1] == 1'b1 
						|| game_board[9'b1010 * (y / 3'b100 + {b_1[7], b_1[7:0]}) + (x - 6'b111100) / 3'b100 + {b_1[15], b_1[15:8]} - 1'b1] == 1'b1
						|| game_board[9'b1010 * (y / 3'b100 + {b_2[7], b_2[7:0]}) + (x - 6'b111100) / 3'b100 + {b_2[15], b_2[15:8]} - 1'b1] == 1'b1
						|| game_board[9'b1010 * (y / 3'b100 + {b_3[7], b_3[7:0]}) + (x - 6'b111100) / 3'b100 + {b_3[15], b_3[15:8]} - 1'b1] == 1'b1) begin
							// do nothing
						end
						else begin
							x = x - 3'b100;
						end
					end
				end
					
			end
			else begin
//				eraseCounter = eraseCounter + 1'b1;
//				if (eraseCounter == 7'b1000100) begin
//					startErase = 1'b0;
//					eraseCounter = 7'b0;
//				end
			end
		end
	end
	
endmodule

module pieceSwitcher(savePiece, r_cw, r_ccw, initialize_piece, enable, clock, game_board, x, y, b_1, b_2, b_3, selection);
	input savePiece;
	input r_cw;
	input r_ccw;
	input initialize_piece;
	input enable;
	input clock;
	input [299:0] game_board;
	input [7:0] x;
	input [6:0] y;
	
	output reg [15:0] b_1;
	output reg [15:0] b_2;
	output reg [15:0] b_3;
	
	wire [15:0] t_1;
	wire [15:0] t_2;
	wire [15:0] t_3;
	
	wire [15:0] o_1;
	wire [15:0] o_2;
	wire [15:0] o_3;
	
	wire [15:0] s_1;
	wire [15:0] s_2;
	wire [15:0] s_3;
	
	wire [15:0] z_1;
	wire [15:0] z_2;
	wire [15:0] z_3;
	
	wire [15:0] i_1;
	wire [15:0] i_2;
	wire [15:0] i_3;
	
	wire [15:0] l_1;
	wire [15:0] l_2;
	wire [15:0] l_3;
	
	wire [15:0] j_1;
	wire [15:0] j_2;
	wire [15:0] j_3;
	
	output reg [2:0] selection;
	initial selection = 3'b1;
	
	T u1(.b_1(t_1), .b_2(t_2), .b_3(t_3), .r_cw(r_cw), .r_ccw(r_ccw), .initialize_piece(initialize_piece), .enable_rotate(enable), .clock(clock), .game_board(game_board), .x(x), .y(y));
	O u2(.b_1(o_1), .b_2(o_2), .b_3(o_3), .r_cw(r_cw), .r_ccw(r_ccw), .initialize_piece(initialize_piece), .enable_rotate(enable), .clock(clock), .game_board(game_board), .x(x), .y(y));
	S u3(.b_1(s_1), .b_2(s_2), .b_3(s_3), .r_cw(r_cw), .r_ccw(r_ccw), .initialize_piece(initialize_piece), .enable_rotate(enable), .clock(clock), .game_board(game_board), .x(x), .y(y));
	Z u4(.b_1(z_1), .b_2(z_2), .b_3(z_3), .r_cw(r_cw), .r_ccw(r_ccw), .initialize_piece(initialize_piece), .enable_rotate(enable), .clock(clock), .game_board(game_board), .x(x), .y(y));
	I u5(.b_1(i_1), .b_2(i_2), .b_3(i_3), .r_cw(r_cw), .r_ccw(r_ccw), .initialize_piece(initialize_piece), .enable_rotate(enable), .clock(clock), .game_board(game_board), .x(x), .y(y));
	L u6(.b_1(l_1), .b_2(l_2), .b_3(l_3), .r_cw(r_cw), .r_ccw(r_ccw), .initialize_piece(initialize_piece), .enable_rotate(enable), .clock(clock), .game_board(game_board), .x(x), .y(y));
	J u7(.b_1(j_1), .b_2(j_2), .b_3(j_3), .r_cw(r_cw), .r_ccw(r_ccw), .initialize_piece(initialize_piece), .enable_rotate(enable), .clock(clock), .game_board(game_board), .x(x), .y(y));
	
	localparam T = 3'b101,
				  O = 3'b110,
				  S = 3'b100,
				  Z = 3'b010,
				  I = 3'b011,
				  L = 3'b111,
				  J = 3'b001;
				  
	always@(posedge savePiece) begin
		selection = selection + 1'b1;
		if (selection == 3'b000) begin
			selection = 3'b1;
		end
	end
	
	always@(*) begin
		case(selection)
			T: begin
				b_1 = t_1;
				b_2 = t_2;
				b_3 = t_3;
			end
			O: begin
				b_1 = o_1;
				b_2 = o_2;
				b_3 = o_3;
			end
			S: begin
				b_1 = s_1;
				b_2 = s_2;
				b_3 = s_3;
			end
			Z: begin
				b_1 = z_1;
				b_2 = z_2;
				b_3 = z_3;
			end
			I: begin
				b_1 = i_1;
				b_2 = i_2;
				b_3 = i_3;
			end
			L: begin
				b_1 = l_1;
				b_2 = l_2;
				b_3 = l_3;
			end
			J: begin
				b_1 = j_1;
				b_2 = j_2;
				b_3 = j_3;
			end
		endcase
	end
				  
endmodule

// receives an update from pieceController (savePiece) that saves the current piece in the game_board. It then checks if any row has been filled.
// if a row is filled, it sends out a clear signal and sets that row to 0, moves the board down (anything above that row)
// maximum rows cleared at a time is 4

module updateBoard(clock, game_board, reset_board, x, y, b_1, b_2, b_3, savePiece, rows_cleared);
	// the inputs below represent the current position of the piece
	// when savePiece goes high, the position should NOT CHANGE while the piece is being saved, as that piece has collided with the bottom
	input [7:0] x;
	input [6:0] y;
	input [15:0] b_1;
	input [15:0] b_2;
	input [15:0] b_3;
	input savePiece;
	input clock;
	input reset_board;
	
	output reg [299:0] game_board;
	output reg [2:0] rows_cleared;

	
	always@(posedge savePiece or posedge reset_board) begin
		rows_cleared = 3'b0;
		if (reset_board == 1'b1) begin
			game_board = 300'b0;
		end
		else begin
			game_board[9'b1010 * (y / 3'b100) + (x - 6'b111100) / 3'b100] = 1'b1;
			game_board[9'b1010 * (y / 3'b100 + {b_1[7], b_1[7:0]}) + (x - 6'b111100) / 3'b100 + {b_1[15], b_1[15:8]}] = 1'b1;
			game_board[9'b1010 * (y / 3'b100 + {b_2[7], b_2[7:0]}) + (x - 6'b111100) / 3'b100 + {b_2[15], b_2[15:8]}] = 1'b1;
			game_board[9'b1010 * (y / 3'b100 + {b_3[7], b_3[7:0]}) + (x - 6'b111100) / 3'b100 + {b_3[15], b_3[15:8]}] = 1'b1;
		end
		
//		if (game_board[199 : 190] == 10'b1111111111) begin
////			game_board[199 : 10] = game_board[190 : 0];
//			rows_cleared = rows_cleared + 1'b1;
//		end
//		
//		if (game_board[189 : 180] == 10'b1111111111) begin
////			game_board[199 : 10] = game_board[190 : 0];
//			rows_cleared = rows_cleared + 1'b1;
//		end
//		
//		if (game_board[179 : 170] == 10'b1111111111) begin
////			game_board[199 : 10] = game_board[190 : 0];
//			rows_cleared = rows_cleared + 1'b1;
//		end
//		
//		if (game_board[169 : 160] == 10'b1111111111) begin
////			game_board[199 : 10] = game_board[190 : 0];
//			rows_cleared = rows_cleared + 1'b1;
//		end
//		
	end
	
endmodule


module draw(vsync, game_board, x_block, y_block, clock, x, y, b_1, b_2, b_3, colour, startErase, pieceType, reset_board);
	
	input [7:0] x_block;
	input [6:0] y_block;
	input clock;
	input [15:0] b_1;
	input [15:0] b_2;
	input [15:0] b_3;
	input startErase;
	input reset_board;
	input [2:0] pieceType;
	input vsync; // active LOW
	input [299:0] game_board;
	
	reg [7:0] x_internal;
	reg [6:0] y_internal;
	
	output reg [7:0] x;
	output reg [6:0] y;
	output reg [2:0] colour;
	
	reg [3:0] counter;
	reg [2:0] block_counter;
	reg done_reset_board_1;
	reg done_reset_board_2;
	reg done_erase_background;
	reg done_draw_block;
	
	initial x_internal = 8'b111100;
	initial y_internal = 7'b0;
	initial counter = 4'b0000;
	initial block_counter = 3'b000;
	
	reg [3:0] current_state;
	reg [3:0] next_state;
	
	localparam 
//				  startup = 4'b0010,
//				  draw_empty_frame_1 = 4'b0111,
//				  draw_empty_frame_2 = 4'b0001,
				  erase_background = 4'b0000,
				  draw_block = 4'b0011,
				  wait_vsync = 4'b0100;
//				  wait_vsync_empty_frame_2 = 4'b0101,
//				  wait_vsync_erase = 4'b0110;
				  
	always@(*) begin
		case(current_state)
//			startup: next_state = draw_empty_frame_1;
//			draw_empty_frame_1: next_state = done_reset_board_1 ? wait_vsync_empty_frame_2 : draw_empty_frame_1;
//			draw_empty_frame_2: next_state = done_reset_board_2 ? wait_vsync_erase : draw_empty_frame_2;
			erase_background: next_state = done_erase_background ? draw_block : erase_background;
			draw_block: next_state = done_draw_block ? wait_vsync : draw_block;
			wait_vsync: next_state = vsync ? erase_background : wait_vsync;
//			wait_vsync_empty_frame_2: next_state = vsync ? draw_empty_frame_2 : wait_vsync_empty_frame_2;
//			wait_vsync_erase: next_state = vsync ? erase_background : wait_vsync_erase;
		endcase
	end
	
	always@(posedge clock) begin
		case(current_state)
//			startup: begin
//				x = 8'b0;
//				y = 7'b0;
//				colour = 3'b000;
//			end
//			draw_empty_frame_1: begin
//				x = x + 1'b1;
//				if (x == 8'b10011111) begin
//					x = 8'b0;
//					y = y + 1'b1;
//				end
//				if ((x == 8'b111011) || (x == 8'b1100100))
//					colour = 3'b111;
//				else
//					colour = 3'b001;
//				if (y == 7'b1111000) begin
//					x = 8'b0;
//					y = 7'b0;
//					done_reset_board_1 = 1'b1;
//				end
//			end
//			draw_empty_frame_2: begin
//				x = x + 1'b1;
//				if (x == 8'b10011111) begin
//					x = 8'b0;
//					y = y + 1'b1;
//				end
//				if ((x == 8'b111011) || (x == 8'b1100100))
//					colour = 3'b111;
//				else
//					colour = 3'b001;
//				if (y == 7'b1111000) begin
//					x = 8'b0;
//					y = 7'b0;
//					done_reset_board_2 = 1'b1;
//				end
//			end
			erase_background: begin
				// if space on the board is occupied, skip			
				if(game_board[9'b1010 * (y_internal / 3'b100) + (x_internal - 6'b111100) / 3'b100] == 1'b1
					|| ((y_internal == y_block) && (x_internal == x_block)) 
					|| ((y_internal == (y_block + 3'b100 * b_1[6:0])) && (x_internal == (x_block + 8'b100 * b_1[15:8]))) 
					|| ((y_internal == (y_block + 3'b100 * b_2[6:0])) && (x_internal == (x_block + 8'b100 * b_2[15:8]))) 
					|| ((y_internal == (y_block + 3'b100 * b_3[6:0])) && (x_internal == (x_block + 8'b100 * b_3[15:8]))) 	)begin
					x_internal = x_internal + 3'b100;
					if (x_internal == 8'b1100100) begin
						// if you reach the right edge of the screen, go back to left edge and increment y
						x_internal = 8'b111100;
						y_internal = y_internal + 3'b100;
					end
					counter = 4'b0;
					if (y_internal == 7'b1111000) begin
						// if you go past the bottom edge of the screen, this state is done
						done_erase_background = 1'b1;
					end
				end
				// if not occupied, start drawing black at that space. when done, increment x and y
				else begin
					colour = 3'b000;
					y = y_internal + counter[3:2];
					x = x_internal + counter[1:0];
					counter = counter + 1'b1;
					
					if (counter == 4'b0) begin
						x_internal = x_internal + 3'b100;
						if (x_internal == 8'b1100100) begin
							// if you reach the right edge of the screen, go back to left edge and increment y
							x_internal = 8'b111100;
							y_internal = y_internal + 3'b100;
						end
						if (y_internal == 7'b1111000) begin
							// if you go past the bottom edge of the screen, this state is done
							done_erase_background = 1'b1;
						end
					end
				end
			end
			draw_block: begin
				if (block_counter == 3'b000) begin
					colour = pieceType;
					y = y_block + counter[3:2];
					x = x_block + counter[1:0];
					counter = counter + 1'b1;
					if (counter == 4'b0) begin
						block_counter = block_counter + 1'b1;
					end
				end
				
				else if (block_counter == 3'b001) begin
					y = y_block + 7'b100 * b_1[6:0] + counter[3:2];
					x = x_block + 8'b100 * b_1[15:8] + counter[1:0];
					counter = counter + 1'b1;
					if (counter == 4'b0) begin
						block_counter = block_counter + 1'b1;
					end
				end
				
				else if (block_counter == 3'b010) begin
					y = y_block + 7'b100 * b_2[6:0] + counter[3:2];
					x = x_block + 8'b100 * b_2[15:8] + counter[1:0];
					counter = counter + 1'b1;
					if (counter == 4'b0) begin
						block_counter = block_counter + 1'b1;
					end
				end
				
				else if (block_counter == 3'b011) begin
					y = y_block + 7'b100 * b_3[6:0] + counter[3:2];
					x = x_block + 8'b100 * b_3[15:8] + counter[1:0];
					counter = counter + 1'b1;
					if (counter == 4'b0) begin
						block_counter = 3'b0;
						done_draw_block = 1'b1;
					end
				end	
			end
			wait_vsync: begin
				done_draw_block = 1'b0;
				done_erase_background = 1'b0;
				done_reset_board_1 = 1'b0;
				done_reset_board_2 = 1'b0;
				counter = 4'b0;
				block_counter = 3'b0;
			end
		endcase
	end
	
	always@(posedge clock) begin
		current_state = next_state;
	end

endmodule

module rateDivider(clock, reset, enable);
	parameter frequency = 26'b10111110101111000010000000;
	
	input clock;
	input reset;
	
	output enable;
	
	reg [25:0] count;
	
	always@(posedge clock)
	begin
		if (reset == 1'b0)
			count = 26'b0;
		else begin
			if (count == frequency - 1'b1)
				count = 26'b0;
			else
				count = count + 1'b1;
		end
	end
	
	assign enable = (count == frequency - 1'b1)?1'b1:1'b0;
	
endmodule

module T(enable_rotate, clock, r_cw, r_ccw, x, y, b_1, b_2, b_3, initialize_piece, game_board);
		
	input clock;
	input initialize_piece;
	input r_cw;
	input r_ccw;
	input enable_rotate;
	input [7:0] x;
	input [6:0] y;
	input [299:0] game_board;
			
	output reg [15:0] b_1; // b_1[15:8] is x, b_1[7:0] is y --> last 7 bits of y is b_1[6:0]
	output reg [15:0] b_2;
	output reg [15:0] b_3;
			  
	// b_0 - b_3 are the relative position of each block
	// b_0 is the centre (axis of rotation)
	
	// 11111111 is -1, 11111110 is -2, 1 is 1, 10 is 2, 0 is 0
	
	// cw and ccw rotations are determined by rotation matrix (see notebook)
	
	always@(posedge clock) begin
		if (initialize_piece == 1'b1) begin
			b_1[15:8] = 8'b11111111;
			b_1[7:0] = 8'b0;
			b_2[15:8] = 8'b0;
			b_2[7:0] = 8'b1;
			b_3[15:8] = 8'b1;
			b_3[7:0] = 8'b0;
		end
		if (enable_rotate == 1'b1) begin
			if (r_ccw == 1'b0) begin
				b_1 <= {b_1[7:0], b_1[15:8] * 8'b11111111};
				b_2 <= {b_2[7:0], b_2[15:8] * 8'b11111111};
				b_3 <= {b_3[7:0], b_3[15:8] * 8'b11111111};
			end
			else if (r_cw == 1'b0) begin
				b_1 <= {b_1[7:0] * 8'b11111111, b_1[15:8]};
				b_2 <= {b_2[7:0] * 8'b11111111, b_2[15:8]};
				b_3 <= {b_3[7:0] * 8'b11111111, b_3[15:8]};
			end
		end
	end
	
endmodule

module O(enable_rotate, clock, r_cw, r_ccw, x, y, b_1, b_2, b_3, initialize_piece, game_board);
		
	input clock;
	input initialize_piece;
	input r_cw;
	input r_ccw;
	input enable_rotate;
	input [7:0] x;
	input [6:0] y;
	input [299:0] game_board;
			
	output reg [15:0] b_1; // b_1[15:8] is x, b_1[7:0] is y --> last 7 bits of y is b_1[6:0]
	output reg [15:0] b_2;
	output reg [15:0] b_3;
			  
	// b_0 - b_3 are the relative position of each block
	// b_0 is the centre (axis of rotation)
	
	// 11111111 is -1, 11111110 is -2, 1 is 1, 10 is 2, 0 is 0
	
	// cw and ccw rotations are determined by rotation matrix (see notebook)
	
	always@(posedge clock) begin
		if (initialize_piece == 1'b1) begin
			b_1[15:8] = 8'b1;
			b_1[7:0] = 8'b0;
			b_2[15:8] = 8'b0;
			b_2[7:0] = 8'b1;
			b_3[15:8] = 8'b1;
			b_3[7:0] = 8'b1;
		end
	end
	
endmodule

module S(enable_rotate, clock, r_cw, r_ccw, x, y, b_1, b_2, b_3, initialize_piece, game_board);
		
	input clock;
	input initialize_piece;
	input r_cw;
	input r_ccw;
	input enable_rotate;
	input [7:0] x;
	input [6:0] y;
	input [299:0] game_board;
			
	output reg [15:0] b_1; // b_1[15:8] is x, b_1[7:0] is y --> last 7 bits of y is b_1[6:0]
	output reg [15:0] b_2;
	output reg [15:0] b_3;
			  
	// b_0 - b_3 are the relative position of each block
	// b_0 is the centre (axis of rotation)
	
	// 11111111 is -1, 11111110 is -2, 1 is 1, 10 is 2, 0 is 0
	
	// cw and ccw rotations are determined by rotation matrix (see notebook)
	
	always@(posedge clock) begin
		if (initialize_piece == 1'b1) begin
			b_1[15:8] = 8'b1;
			b_1[7:0] = 8'b0;
			b_2[15:8] = 8'b11111111;
			b_2[7:0] = 8'b1;
			b_3[15:8] = 8'b0;
			b_3[7:0] = 8'b1;
		end
		if (enable_rotate == 1'b1) begin
			if (r_ccw == 1'b0) begin
				b_1 <= {b_1[7:0], b_1[15:8] * 8'b11111111};
				b_2 <= {b_2[7:0], b_2[15:8] * 8'b11111111};
				b_3 <= {b_3[7:0], b_3[15:8] * 8'b11111111};
			end
			else if (r_cw == 1'b0) begin
				b_1 <= {b_1[7:0] * 8'b11111111, b_1[15:8]};
				b_2 <= {b_2[7:0] * 8'b11111111, b_2[15:8]};
				b_3 <= {b_3[7:0] * 8'b11111111, b_3[15:8]};
			end
		end
	end
	
endmodule

module Z(enable_rotate, clock, r_cw, r_ccw, x, y, b_1, b_2, b_3, initialize_piece, game_board);
		
	input clock;
	input initialize_piece;
	input r_cw;
	input r_ccw;
	input enable_rotate;
	input [7:0] x;
	input [6:0] y;
	input [299:0] game_board;
			
	output reg [15:0] b_1; // b_1[15:8] is x, b_1[7:0] is y --> last 7 bits of y is b_1[6:0]
	output reg [15:0] b_2;
	output reg [15:0] b_3;
			  
	// b_0 - b_3 are the relative position of each block
	// b_0 is the centre (axis of rotation)
	
	// 11111111 is -1, 11111110 is -2, 1 is 1, 10 is 2, 0 is 0
	
	// cw and ccw rotations are determined by rotation matrix (see notebook)
	
	always@(posedge clock) begin
		if (initialize_piece == 1'b1) begin
			b_1[15:8] = 8'b11111111;
			b_1[7:0] = 8'b0;
			b_2[15:8] = 8'b0;
			b_2[7:0] = 8'b1;
			b_3[15:8] = 8'b1;
			b_3[7:0] = 8'b1;
		end
		if (enable_rotate == 1'b1) begin
			if (r_ccw == 1'b0) begin
				b_1 <= {b_1[7:0], b_1[15:8] * 8'b11111111};
				b_2 <= {b_2[7:0], b_2[15:8] * 8'b11111111};
				b_3 <= {b_3[7:0], b_3[15:8] * 8'b11111111};
			end
			else if (r_cw == 1'b0) begin
				b_1 <= {b_1[7:0] * 8'b11111111, b_1[15:8]};
				b_2 <= {b_2[7:0] * 8'b11111111, b_2[15:8]};
				b_3 <= {b_3[7:0] * 8'b11111111, b_3[15:8]};
			end
		end
	end
	
endmodule

module I(enable_rotate, clock, r_cw, r_ccw, x, y, b_1, b_2, b_3, initialize_piece, game_board);
		
	input clock;
	input initialize_piece;
	input r_cw;
	input r_ccw;
	input enable_rotate;
	input [7:0] x;
	input [6:0] y;
	input [299:0] game_board;
			
	output reg [15:0] b_1; // b_1[15:8] is x, b_1[7:0] is y --> last 7 bits of y is b_1[6:0]
	output reg [15:0] b_2;
	output reg [15:0] b_3;
			  
	// b_0 - b_3 are the relative position of each block
	// b_0 is the centre (axis of rotation)
	
	// 11111111 is -1, 11111110 is -2, 1 is 1, 10 is 2, 0 is 0
	
	// cw and ccw rotations are determined by rotation matrix (see notebook)
	
	always@(posedge clock) begin
		if (initialize_piece == 1'b1) begin
			b_1[15:8] = 8'b11111111;
			b_1[7:0] = 8'b0;
			b_2[15:8] = 8'b1;
			b_2[7:0] = 8'b0;
			b_3[15:8] = 8'b10;
			b_3[7:0] = 8'b0;
		end
		if (enable_rotate == 1'b1) begin
			if (r_ccw == 1'b0) begin
				b_1 <= {b_1[7:0], b_1[15:8] * 8'b11111111};
				b_2 <= {b_2[7:0], b_2[15:8] * 8'b11111111};
				b_3 <= {b_3[7:0], b_3[15:8] * 8'b11111111};
			end
			else if (r_cw == 1'b0) begin
				b_1 <= {b_1[7:0] * 8'b11111111, b_1[15:8]};
				b_2 <= {b_2[7:0] * 8'b11111111, b_2[15:8]};
				b_3 <= {b_3[7:0] * 8'b11111111, b_3[15:8]};
			end
		end
	end
	
endmodule

module L(enable_rotate, clock, r_cw, r_ccw, x, y, b_1, b_2, b_3, initialize_piece, game_board);
		
	input clock;
	input initialize_piece;
	input r_cw;
	input r_ccw;
	input enable_rotate;
	input [7:0] x;
	input [6:0] y;
	input [299:0] game_board;
			
	output reg [15:0] b_1; // b_1[15:8] is x, b_1[7:0] is y --> last 7 bits of y is b_1[6:0]
	output reg [15:0] b_2;
	output reg [15:0] b_3;
			  
	// b_0 - b_3 are the relative position of each block
	// b_0 is the centre (axis of rotation)
	
	// 11111111 is -1, 11111110 is -2, 1 is 1, 10 is 2, 0 is 0
	
	// cw and ccw rotations are determined by rotation matrix (see notebook)
	
	always@(posedge clock) begin
		if (initialize_piece == 1'b1) begin
			b_1[15:8] = 8'b1;
			b_1[7:0] = 8'b0;
			b_2[15:8] = 8'b11111111;
			b_2[7:0] = 8'b0;
			b_3[15:8] = 8'b11111111;
			b_3[7:0] = 8'b1;
		end
		if (enable_rotate == 1'b1) begin
			if (r_ccw == 1'b0) begin
				b_1 <= {b_1[7:0], b_1[15:8] * 8'b11111111};
				b_2 <= {b_2[7:0], b_2[15:8] * 8'b11111111};
				b_3 <= {b_3[7:0], b_3[15:8] * 8'b11111111};
			end
			else if (r_cw == 1'b0) begin
				b_1 <= {b_1[7:0] * 8'b11111111, b_1[15:8]};
				b_2 <= {b_2[7:0] * 8'b11111111, b_2[15:8]};
				b_3 <= {b_3[7:0] * 8'b11111111, b_3[15:8]};
			end
		end
	end
	
endmodule

module J(enable_rotate, clock, r_cw, r_ccw, x, y, b_1, b_2, b_3, initialize_piece, game_board);
		
	input clock;
	input initialize_piece;
	input r_cw;
	input r_ccw;
	input enable_rotate;
	input [7:0] x;
	input [6:0] y;
	input [299:0] game_board;
			
	output reg [15:0] b_1; // b_1[15:8] is x, b_1[7:0] is y --> last 7 bits of y is b_1[6:0]
	output reg [15:0] b_2;
	output reg [15:0] b_3;
			  
	// b_0 - b_3 are the relative position of each block
	// b_0 is the centre (axis of rotation)
	
	// 11111111 is -1, 11111110 is -2, 1 is 1, 10 is 2, 0 is 0
	
	// cw and ccw rotations are determined by rotation matrix (see notebook)
	
	always@(posedge clock) begin
		if (initialize_piece == 1'b1) begin
			b_1[15:8] = 8'b1;
			b_1[7:0] = 8'b0;
			b_2[15:8] = 8'b1;
			b_2[7:0] = 8'b1;
			b_3[15:8] = 8'b11111111;
			b_3[7:0] = 8'b0;
		end
		if (enable_rotate == 1'b1) begin
			if (r_ccw == 1'b0) begin
				b_1 <= {b_1[7:0], b_1[15:8] * 8'b11111111};
				b_2 <= {b_2[7:0], b_2[15:8] * 8'b11111111};
				b_3 <= {b_3[7:0], b_3[15:8] * 8'b11111111};
			end
			else if (r_cw == 1'b0) begin
				b_1 <= {b_1[7:0] * 8'b11111111, b_1[15:8]};
				b_2 <= {b_2[7:0] * 8'b11111111, b_2[15:8]};
				b_3 <= {b_3[7:0] * 8'b11111111, b_3[15:8]};
			end
		end
	end
	
endmodule
