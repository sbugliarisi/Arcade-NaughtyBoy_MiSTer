//============================================================================
//  Arcade: Naughty Boy
//
//  Port to MiSTer
//  Copyright (C) 2017 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	`include "sys/emu_ports.vh"
);

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;

assign VGA_F1    = 0;
assign VGA_SCALER= 0;
assign USER_OUT  = '1;
assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;
assign AUDIO_MIX = 0;
assign FB_FORCE_BLANK = 0;
assign HDMI_FREEZE = 0;
assign VGA_DISABLE = 0;

wire [1:0] ar = status[20:19];

assign VIDEO_ARX = (!ar) ? ((status[2] ) ? 12'd478 : 12'd373) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? ((status[2] ) ? 12'd373 : 12'd478) : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"A.NBOY;;",
	"H0OJK,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"H0O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"OF,Flip Screen,Off,On;",
	"-;",
	"O89,Lives,2,3,4,5;",
	"OA,Difficulty,Easier,Harder;",
	"ODE,Bonus Life,10k,30k,50k,70k;",
	"OC,Cabinet,Upright,Cocktail;",
	"-;",
	"H1OR,Autosave Hiscores,Off,On;",
	"P1,Pause options;",
	"P1OP,Pause when OSD is open,On,Off;",
	"P1OQ,Dim video after 10s,On,Off;",
	"-;",
	"R0,Reset;",
	"J1,Fire,Start 1P,Start 2P,Coin,Pause;",
	"jn,A,B,Start,Select,R,C;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys, clk_hdmi,clk_44;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys), // 11
	.outclk_1(clk_hdmi), // 22
	.outclk_2(clk_44), // 44
	.locked(pll_locked)
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;
wire  [7:0] ioctl_index;
wire        ioctl_wait;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1;

wire [21:0] gamma_bus;


hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.status_menumask({~hs_configured,direct_video}),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),
	.video_rotated(video_rotated),

	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_upload_req(ioctl_upload_req),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1)
);


wire m_right  = joy[0];
wire m_left   = joy[1];
wire m_down   = joy[2];
wire m_up     = joy[3];
wire m_fire   = joy[4];

wire m_right_2 = joy[0];
wire m_left_2  = joy[1];
wire m_down_2  = joy[2];
wire m_up_2    = joy[3];
wire m_fire_2  = joy[4];

wire m_start1 = joy[5];
wire m_start2 = joy[6];
wire m_coin   = joy[7];
wire m_pause  = joy[8];

// PAUSE SYSTEM
wire pause_cpu;
wire [5:0] rgb_out;
pause #(2,2,2,11) pause
(
	.*,
	.user_button(m_pause),
	.pause_request(hs_pause),
	.options(~status[26:25])
);

wire hblank, vblank;
wire hs, vs;
wire [1:0] r,g,b;

reg ce_pix;
always @(posedge clk_44) begin
	reg [2:0] div;

	div <= div + 1'd1;
	ce_pix <= !div;
end

wire ce_vid;
wire rotate_ccw = 0;
wire no_rotate = status[2] | direct_video  ;
wire flip = 0;
wire video_rotated;
screen_rotate screen_rotate (.*);

arcade_video#(288,6) arcade_video
(
	.*,

	.clk_video(clk_44),

	.RGB_in(rgb_out),
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(hs),
	.VSync(vs),

	.fx(status[5:3])
);

wire [11:0] audio;
assign AUDIO_L = {audio, 4'b0000};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;

//   SWITCH 1:     SWITCH 2:    Lives:
//   ---------     ---------    ------
//     OFF           OFF           5
//     ON            OFF           4
//     OFF           ON            3
//     ON            ON            2
//                               
//   SWITCH 3:     SWITCH 4:     Extra
//  ---------     ---------     -------
//     OFF           OFF         70000
//     ON            OFF         50000
//     OFF           ON          30000
//     ON            ON          10000
//

wire [7:0] dip_switch = { status[12],status[10],1'b0,1'b1,status[14:13],status[9:8]};

wire rom_download = ioctl_download && !ioctl_index;
wire reset = RESET | status[0] | buttons[1] | rom_download;


naughty_boy naughty_boy
(
	.clock_50(0),
	.clock_12(clk_sys),

	.reset(reset),
	.pause(pause_cpu),


	.dn_addr(ioctl_addr[15:0]),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr & rom_download),

	.video_r(r),
	.video_g(g),
	.video_b(b),
	.ce_pix(ce_vid),
	
//	video_csync
	
	.video_hs(hs),
	.video_vs(vs),
	
	.video_hblank(hblank),
	.video_vblank(vblank),

//	.audio_select(0),
	.audio(audio),

	.dip_switch(dip_switch),
	.flip_screen(status[15]),

	.coin(m_coin),
	.starts({m_start2, m_start1}),
	.player1_btns({m_left,m_right,m_down,m_up,m_fire}),
	.player2_btns({m_left_2,m_right_2,m_down_2,m_up_2,m_fire_2}),

//	.hs_address(hs_address),
//	.hs_data_out(hs_data_out),
//	.hs_data_in(hs_data_in),
//	.hs_write(hs_write)
);


// HISCORE SYSTEM
// --------------

wire [15:0]hs_address;
wire [7:0]hs_data_out;
wire [7:0]hs_data_in;
wire hs_write;
wire hs_pause;
wire hs_configured;

hiscore #(
	.HS_ADDRESSWIDTH(16),
	.CFG_ADDRESSWIDTH(6),
	.CFG_LENGTHWIDTH(2)
) hi (
	.*,
	.clk(clk_sys),
	.paused(pause_cpu),
	.autosave(status[27]),
	.ram_address(hs_address),
	.data_from_ram(hs_data_out),
	.data_to_ram(hs_data_in),
	.data_from_hps(ioctl_dout),
	.data_to_hps(ioctl_din),
	.ram_write(hs_write),
	.ram_intent_read(),
	.ram_intent_write(),
	.pause_cpu(hs_pause),
	.configured(hs_configured)
);
endmodule
