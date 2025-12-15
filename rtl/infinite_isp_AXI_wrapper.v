module infinite_isp_AXI_wrapper #
	(
		// Users to add parameters here
		parameter IO_BITS = 10,
		parameter EXT_BITS = 0,
		parameter VIP1_BITS = 8,
		parameter VIP2_BITS = 8,		
		parameter SNS_WIDTH = 1920,
	    parameter SNS_HEIGHT = 1080,
	    parameter CROP_WIDTH = 1920,
	    parameter CROP_HEIGHT = 1080,
		parameter BAYER = 0, //0:RGGB 1:GRBG 2:GBRG 3:BGGR
		parameter FEATURE_FULL = 1,

		// Width of S_AXI data bus
		parameter C_S_AXI_DATA_WIDTH	= 32,
		// Width of S_AXI address bus
		parameter C_S_AXI_ADDR_WIDTH	= 17 // Mode + Module ID + Register ID
	)
	(
		// Users to add ports here
		input pclk,
		input scale_pclk1,
		input scale_pclk2,
		input rst_n,

		input in_href,
		input in_vsync,
		input [IO_BITS-1:0] in_raw,

		input in_href_rgb,
	    input in_vsync_rgb,
		input [IO_BITS-1:0] in_r,
	    input [IO_BITS-1:0] in_g,
	    input [IO_BITS-1:0] in_b,

		output out_pclk1,
		output out_href1,
		output out_vsync1,
		output [VIP1_BITS-1:0] out_r1,
		output [VIP1_BITS-1:0] out_g1,
		output [VIP1_BITS-1:0] out_b1,
		//VIP2
		output out_pclk2,
		output out_href2,
		output out_vsync2,
		output [VIP2_BITS-1:0] out_r2,
		output [VIP2_BITS-1:0] out_g2,
		output [VIP2_BITS-1:0] out_b2,
		output isp_irq,
		// User ports ends
		// Do not modify the ports beyond this line

		// Global Clock Signal
		input wire  S_AXI_ACLK,
		// Global Reset Signal. This Signal is Active LOW
		input wire  S_AXI_ARESETN,
		// Write address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
		// Write channel Protection type. This signal indicates the
    		// privilege and security level of the transaction, and whether
    		// the transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_AWPROT,
		// Write address valid. This signal indicates that the master signaling
    		// valid write address and control information.
		input wire  S_AXI_AWVALID,
		// Write address ready. This signal indicates that the slave is ready
    		// to accept an address and associated control signals.
		output wire  S_AXI_AWREADY,
		// Write data (issued by master, acceped by Slave) 
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
		// Write strobes. This signal indicates which byte lanes hold
    		// valid data. There is one write strobe bit for each eight
    		// bits of the write data bus.    
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
		// Write valid. This signal indicates that valid write
    		// data and strobes are available.
		input wire  S_AXI_WVALID,
		// Write ready. This signal indicates that the slave
    		// can accept the write data.
		output wire  S_AXI_WREADY,
		// Write response. This signal indicates the status
    		// of the write transaction.
		output wire [1 : 0] S_AXI_BRESP,
		// Write response valid. This signal indicates that the channel
    		// is signaling a valid write response.
		output wire  S_AXI_BVALID,
		// Response ready. This signal indicates that the master
    		// can accept a write response.
		input wire  S_AXI_BREADY,
		// Read address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
		// Protection type. This signal indicates the privilege
    		// and security level of the transaction, and whether the
    		// transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_ARPROT,
		// Read address valid. This signal indicates that the channel
    		// is signaling valid read address and control information.
		input wire  S_AXI_ARVALID,
		// Read address ready. This signal indicates that the slave is
    		// ready to accept an address and associated control signals.
		output wire  S_AXI_ARREADY,
		// Read data (issued by slave)
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
		// Read response. This signal indicates the status of the
    		// read transfer.
		output wire [1 : 0] S_AXI_RRESP,
		// Read valid. This signal indicates that the channel is
    		// signaling the required read data.
		output wire  S_AXI_RVALID,
		// Read ready. This signal indicates that the master can
    		// accept the read data and response information.
		input wire  S_AXI_RREADY
	);
	
	localparam BITS = IO_BITS + EXT_BITS;
	localparam OECF_R_LUT = "OECF_R_LUT_INIT.mem";
	localparam OECF_GR_LUT = "OECF_GR_LUT_INIT.mem";
	localparam OECF_GB_LUT = "OECF_GB_LUT_INIT.mem";
	localparam OECF_B_LUT = "OECF_B_LUT_INIT.mem";
	localparam BNR_WEIGHT_BITS = 8;
	localparam DGAIN_ARRAY_SIZE = 100;
	localparam GAMMA_R_LUT = "GAMMA_R_LUT_INIT.mem";
	localparam GAMMA_G_LUT = "GAMMA_G_LUT_INIT.mem";
	localparam GAMMA_B_LUT = "GAMMA_B_LUT_INIT.mem";
	localparam SHARP_WEIGHT_BITS = 20;
	localparam NR2D_WEIGHT_BITS = 5;
	localparam STAT_OUT_BITS = 32;
	localparam STAT_HIST_BITS = 16;
	//vip
	// Module's Hardware Instantiation goes here
	localparam USE_CROP = 1;
	localparam USE_DPC = 1;
	localparam USE_BLC = 1;
	localparam USE_OECF = 1;
	localparam USE_DGAIN = 1;
	localparam USE_LSC = 0;
	localparam USE_BNR = 1;	
	localparam USE_WB = 1;
	localparam USE_DEMOSIC = 1;	
	localparam USE_CCM = 1;
	localparam USE_GAMMA = 1;
	localparam USE_CSC = 1;
	localparam USE_LDCI = 0;
	localparam USE_2DNR = 1;
	localparam USE_SHARP = 1;
	localparam USE_STAT_AE = 0;
	localparam USE_AWB = 1;
	localparam USE_AE = 1;
	//vip
	localparam VIP1_USE_HIST_EQU = 0;
	localparam VIP1_USE_SOBEL = 0;
	localparam VIP1_USE_RGBC = 1;
	localparam VIP1_USE_IRC = 1;
	localparam VIP1_USE_SCALE = 1;
	localparam VIP1_USE_OSD = 1;
	localparam VIP1_USE_YUVConvFormat = 1;
	localparam VIP1_OSD_RAM_ADDR_BITS = 9;
	localparam VIP1_OSD_RAM_DATA_BITS = 32;


	localparam VIP2_USE_HIST_EQU = 0;
	localparam VIP2_USE_SOBEL = 0;
	localparam VIP2_USE_RGBC = 1;
	localparam VIP2_USE_IRC = 1;
	localparam VIP2_USE_SCALE = 1;
	localparam VIP2_USE_OSD = 1;
	localparam VIP2_USE_YUVConvFormat = 1;	
	localparam VIP2_OSD_RAM_ADDR_BITS = 9;
	localparam VIP2_OSD_RAM_DATA_BITS = 32;


	localparam DGAIN_ARRAY_BITS = $clog2(DGAIN_ARRAY_SIZE);
	localparam AWB_CROP_LEFT = 8; // 2 (DPC) + 6 (BNR)
	localparam AWB_CROP_RIGHT = 8; // 2 (DPC) + 6 (BNR)
	localparam AWB_CROP_TOP = 16; // 2 x ( DPC + BNR )
	localparam AWB_CROP_BOTTOM = 0;
	
	// AXI4LITE signals
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awready;
	reg  	axi_wready;
	reg [1 : 0] 	axi_bresp;
	reg  	axi_bvalid;
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arready;
	reg [C_S_AXI_DATA_WIDTH-1 : 0] 	axi_rdata;
	reg [1 : 0] 	axi_rresp;
	reg  	axi_rvalid;
	
	// Example-specific design signals
	// local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	// ADDR_LSB is used for addressing 32/64 bit registers/memories
	// ADDR_LSB = 2 for 32 bits (n downto 2)
	// ADDR_LSB = 3 for 64 bits (n downto 3)
	localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
	localparam integer MODE_ID_BITS = 2;
	localparam integer MODULE_ID_BITS = 6;
	localparam integer REG_ID_BITS = 7;
	
    wire [MODE_ID_BITS-1:0] axi_araddr_mode_id = axi_araddr[(C_S_AXI_ADDR_WIDTH-1)-:(MODE_ID_BITS)];
	wire [MODE_ID_BITS-1:0] axi_awaddr_mode_id = axi_awaddr[(C_S_AXI_ADDR_WIDTH-1)-:(MODE_ID_BITS)];
	wire [MODULE_ID_BITS-1:0] axi_araddr_module_id = axi_araddr[(C_S_AXI_ADDR_WIDTH-MODE_ID_BITS-1)-:(MODULE_ID_BITS)];
	wire [MODULE_ID_BITS-1:0] axi_awaddr_module_id = axi_awaddr[(C_S_AXI_ADDR_WIDTH-MODE_ID_BITS-1)-:(MODULE_ID_BITS)];

	//----------------------------------------------
	//-- Signals for user logic register space example
	//------------------------------------------------
	//-- Mode IDs
	localparam MODE_REGISTERS            = 0;
	localparam MODE_GAMMA_LUT            = 1;
	localparam MODE_VIP1_OSD_RAM         = 1;
	localparam MODE_VIP2_OSD_RAM         = 1;
	localparam MODE_OECF_LUT1            = 2;
	localparam MODE_OECF_LUT2            = 3;
	
	//-- Module IDs
	localparam MODULE_CONFIG             = 0;
	localparam MODULE_DPC                = 1;
	localparam MODULE_BLC                = 2;
	localparam MODULE_AE                 = 3;
	localparam MODULE_DGAIN              = 4;
	localparam MODULE_LSC                = 5;
	localparam MODULE_AWB                = 6;
	localparam MODULE_WB                 = 7;
	localparam MODULE_CFA                = 8;
	localparam MODULE_CCM                = 9;
	localparam MODULE_CSC                = 10;
	localparam MODULE_LDCI               = 11;
	localparam MODULE_SHARP              = 14;
	localparam MODULE_BNR              	 = 16;
	localparam MODULE_2DNR               = 21;
	
    //vip1
	localparam VIP1_MODULE_CONFIG             = 32;
    localparam VIP1_MODULE_RGBC               = 33;
	localparam VIP1_MODULE_IRC                = 34;
	localparam VIP1_MODULE_SCALE              = 35;
	localparam VIP1_MODULE_OSD                = 36;
	localparam VIP1_MODULE_YUV444TO422        = 37;
	//vip2
	localparam VIP2_MODULE_CONFIG             = 48;
	localparam VIP2_MODULE_RGBC               = 49;
	localparam VIP2_MODULE_IRC                = 50;
	localparam VIP2_MODULE_SCALE              = 51;
	localparam VIP2_MODULE_OSD                = 52;
	localparam VIP2_MODULE_YUV444TO422        = 53;
	
	//-- Register IDs
	
	//-- MODULE_CONFIG
	localparam REG_RESET                 = MODULE_CONFIG*(1<<(REG_ID_BITS)) + 0;
	localparam REG_SNS_WIDTH             = MODULE_CONFIG*(1<<(REG_ID_BITS)) + 1;
	localparam REG_SNS_HEIGHT            = MODULE_CONFIG*(1<<(REG_ID_BITS)) + 2;
	localparam REG_CROP_WIDTH            = MODULE_CONFIG*(1<<(REG_ID_BITS)) + 3;
	localparam REG_CROP_HEIGHT           = MODULE_CONFIG*(1<<(REG_ID_BITS)) + 4;
	localparam REG_BITS                  = MODULE_CONFIG*(1<<(REG_ID_BITS)) + 5;
	localparam REG_BAYER                 = MODULE_CONFIG*(1<<(REG_ID_BITS)) + 6;
	localparam REG_TOP_EN                = MODULE_CONFIG*(1<<(REG_ID_BITS)) + 16;
	localparam REG_INT_STATUS            = MODULE_CONFIG*(1<<(REG_ID_BITS)) + 17;
	localparam REG_INT_MASK              = MODULE_CONFIG*(1<<(REG_ID_BITS)) + 18;
	//-- MODULE_DPC
	localparam REG_DPC_THRESHOLD         = MODULE_DPC*(1<<(REG_ID_BITS)) + 0;
	//-- MODULE_BLC
	localparam REG_BLC_R                 = MODULE_BLC*(1<<(REG_ID_BITS)) + 0;
	localparam REG_BLC_GR                = MODULE_BLC*(1<<(REG_ID_BITS)) + 1;
	localparam REG_BLC_GB                = MODULE_BLC*(1<<(REG_ID_BITS)) + 2;
	localparam REG_BLC_B                 = MODULE_BLC*(1<<(REG_ID_BITS)) + 3;
	localparam REG_LINEAR_R              = MODULE_BLC*(1<<(REG_ID_BITS)) + 4;
	localparam REG_LINEAR_GR             = MODULE_BLC*(1<<(REG_ID_BITS)) + 5;
	localparam REG_LINEAR_GB             = MODULE_BLC*(1<<(REG_ID_BITS)) + 6;
	localparam REG_LINEAR_B              = MODULE_BLC*(1<<(REG_ID_BITS)) + 7;
	//-- MODULE_AE
	localparam REG_AE_CENTER_ILLUMINANCE = MODULE_AE*(1<<(REG_ID_BITS)) + 0;
	localparam REG_AE_SKEWNESS           = MODULE_AE*(1<<(REG_ID_BITS)) + 1;
	localparam REG_AE_CROP_LEFT          = MODULE_AE*(1<<(REG_ID_BITS)) + 2;
	localparam REG_AE_CROP_RIGHT         = MODULE_AE*(1<<(REG_ID_BITS)) + 3;
	localparam REG_AE_CROP_TOP           = MODULE_AE*(1<<(REG_ID_BITS)) + 4;
	localparam REG_AE_CROP_BOTTOM        = MODULE_AE*(1<<(REG_ID_BITS)) + 5;
	localparam REG_AE_RESPONSE           = MODULE_AE*(1<<(REG_ID_BITS)) + 6;
	localparam REG_AE_RESULT_SKEWNESS    = MODULE_AE*(1<<(REG_ID_BITS)) + 7;
	localparam REG_AE_RESPONSE_DEBUG     = MODULE_AE*(1<<(REG_ID_BITS)) + 8;
	localparam REG_AE_DONE               = MODULE_AE*(1<<(REG_ID_BITS)) + 9;
	//-- MODULE_DGAIN
	localparam REG_DGAIN_ISMANUAL        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 0;
	localparam REG_DGAIN_MAN_INDEX       = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 1;
	localparam REG_DGAIN_INDEX_OUT       = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 2;
	localparam REG_DGAIN_ARRAY_00        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 16;
	localparam REG_DGAIN_ARRAY_01        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 17;
	localparam REG_DGAIN_ARRAY_02        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 18;
	localparam REG_DGAIN_ARRAY_03        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 19;
	localparam REG_DGAIN_ARRAY_04        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 20;
	localparam REG_DGAIN_ARRAY_05        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 21;
	localparam REG_DGAIN_ARRAY_06        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 22;
	localparam REG_DGAIN_ARRAY_07        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 23;
	localparam REG_DGAIN_ARRAY_08        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 24;
	localparam REG_DGAIN_ARRAY_09        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 25;
	localparam REG_DGAIN_ARRAY_0A        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 26;
	localparam REG_DGAIN_ARRAY_0B        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 27;
	localparam REG_DGAIN_ARRAY_0C        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 28;
	localparam REG_DGAIN_ARRAY_0D        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 29;
	localparam REG_DGAIN_ARRAY_0E        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 30;
	localparam REG_DGAIN_ARRAY_0F        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 31;
	localparam REG_DGAIN_ARRAY_10        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 32;
	localparam REG_DGAIN_ARRAY_11        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 33;
	localparam REG_DGAIN_ARRAY_12        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 34;
	localparam REG_DGAIN_ARRAY_13        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 35;
	localparam REG_DGAIN_ARRAY_14        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 36;
	localparam REG_DGAIN_ARRAY_15        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 37;
	localparam REG_DGAIN_ARRAY_16        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 38;
	localparam REG_DGAIN_ARRAY_17        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 39;
	localparam REG_DGAIN_ARRAY_18        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 40;
	localparam REG_DGAIN_ARRAY_19        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 41;
	localparam REG_DGAIN_ARRAY_1A        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 42;
	localparam REG_DGAIN_ARRAY_1B        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 43;
	localparam REG_DGAIN_ARRAY_1C        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 44;
	localparam REG_DGAIN_ARRAY_1D        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 45;
	localparam REG_DGAIN_ARRAY_1E        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 46;
	localparam REG_DGAIN_ARRAY_1F        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 47;
	localparam REG_DGAIN_ARRAY_20        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 48;
	localparam REG_DGAIN_ARRAY_21        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 49;
	localparam REG_DGAIN_ARRAY_22        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 50;
	localparam REG_DGAIN_ARRAY_23        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 51;
	localparam REG_DGAIN_ARRAY_24        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 52;
	localparam REG_DGAIN_ARRAY_25        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 53;
	localparam REG_DGAIN_ARRAY_26        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 54;
	localparam REG_DGAIN_ARRAY_27        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 55;
	localparam REG_DGAIN_ARRAY_28        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 56;
	localparam REG_DGAIN_ARRAY_29        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 57;
	localparam REG_DGAIN_ARRAY_2A        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 58;
	localparam REG_DGAIN_ARRAY_2B        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 59;
	localparam REG_DGAIN_ARRAY_2C        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 60;
	localparam REG_DGAIN_ARRAY_2D        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 61;
	localparam REG_DGAIN_ARRAY_2E        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 62;
	localparam REG_DGAIN_ARRAY_2F        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 63;
	localparam REG_DGAIN_ARRAY_30        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 64;
	localparam REG_DGAIN_ARRAY_31        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 65;
	localparam REG_DGAIN_ARRAY_32        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 66;
	localparam REG_DGAIN_ARRAY_33        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 67;
	localparam REG_DGAIN_ARRAY_34        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 68;
	localparam REG_DGAIN_ARRAY_35        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 69;
	localparam REG_DGAIN_ARRAY_36        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 70;
	localparam REG_DGAIN_ARRAY_37        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 71;
	localparam REG_DGAIN_ARRAY_38        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 72;
	localparam REG_DGAIN_ARRAY_39        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 73;
	localparam REG_DGAIN_ARRAY_3A        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 74;
	localparam REG_DGAIN_ARRAY_3B        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 75;
	localparam REG_DGAIN_ARRAY_3C        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 76;
	localparam REG_DGAIN_ARRAY_3D        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 77;
	localparam REG_DGAIN_ARRAY_3E        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 78;
	localparam REG_DGAIN_ARRAY_3F        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 79;
	localparam REG_DGAIN_ARRAY_40        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 80;
	localparam REG_DGAIN_ARRAY_41        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 81;
	localparam REG_DGAIN_ARRAY_42        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 82;
	localparam REG_DGAIN_ARRAY_43        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 83;
	localparam REG_DGAIN_ARRAY_44        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 84;
	localparam REG_DGAIN_ARRAY_45        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 85;
	localparam REG_DGAIN_ARRAY_46        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 86;
	localparam REG_DGAIN_ARRAY_47        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 87;
	localparam REG_DGAIN_ARRAY_48        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 88;
	localparam REG_DGAIN_ARRAY_49        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 89;
	localparam REG_DGAIN_ARRAY_4A        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 90;
	localparam REG_DGAIN_ARRAY_4B        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 91;
	localparam REG_DGAIN_ARRAY_4C        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 92;
	localparam REG_DGAIN_ARRAY_4D        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 93;
	localparam REG_DGAIN_ARRAY_4E        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 94;
	localparam REG_DGAIN_ARRAY_4F        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 95;
	localparam REG_DGAIN_ARRAY_50        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 96;
	localparam REG_DGAIN_ARRAY_51        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 97;
	localparam REG_DGAIN_ARRAY_52        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 98;
	localparam REG_DGAIN_ARRAY_53        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 99;
	localparam REG_DGAIN_ARRAY_54        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 100;
	localparam REG_DGAIN_ARRAY_55        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 101;
	localparam REG_DGAIN_ARRAY_56        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 102;
	localparam REG_DGAIN_ARRAY_57        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 103;
	localparam REG_DGAIN_ARRAY_58        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 104;
	localparam REG_DGAIN_ARRAY_59        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 105;
	localparam REG_DGAIN_ARRAY_5A        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 106;
	localparam REG_DGAIN_ARRAY_5B        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 107;
	localparam REG_DGAIN_ARRAY_5C        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 108;
	localparam REG_DGAIN_ARRAY_5D        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 109;
	localparam REG_DGAIN_ARRAY_5E        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 110;
	localparam REG_DGAIN_ARRAY_5F        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 111;
	localparam REG_DGAIN_ARRAY_60        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 112;
	localparam REG_DGAIN_ARRAY_61        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 113;
	localparam REG_DGAIN_ARRAY_62        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 114;
	localparam REG_DGAIN_ARRAY_63        = MODULE_DGAIN*(1<<(REG_ID_BITS)) + 115;
	//-- MODULE_AWB
	localparam REG_AWB_UNDEREXPOSED_LIMIT= MODULE_AWB*(1<<(REG_ID_BITS)) + 0;
	localparam REG_AWB_OVEREXPOSED_LIMIT = MODULE_AWB*(1<<(REG_ID_BITS)) + 1;
	localparam REG_AWB_FRAMES            = MODULE_AWB*(1<<(REG_ID_BITS)) + 2;
	localparam REG_AWB_FINAL_RGAIN       = MODULE_AWB*(1<<(REG_ID_BITS)) + 3;
	localparam REG_AWB_FINAL_BGAIN       = MODULE_AWB*(1<<(REG_ID_BITS)) + 4;
	//-- MODULE_WB
	localparam REG_WB_RGAIN              = MODULE_WB*(1<<(REG_ID_BITS)) + 0;
	localparam REG_WB_BGAIN              = MODULE_WB*(1<<(REG_ID_BITS)) + 1;
	//-- MODULE_CCM
	localparam REG_CCM_RR                = MODULE_CCM*(1<<(REG_ID_BITS)) + 0;
	localparam REG_CCM_RG                = MODULE_CCM*(1<<(REG_ID_BITS)) + 1;
	localparam REG_CCM_RB                = MODULE_CCM*(1<<(REG_ID_BITS)) + 2;
	localparam REG_CCM_GR                = MODULE_CCM*(1<<(REG_ID_BITS)) + 3;
	localparam REG_CCM_GG                = MODULE_CCM*(1<<(REG_ID_BITS)) + 4;
	localparam REG_CCM_GB                = MODULE_CCM*(1<<(REG_ID_BITS)) + 5;
	localparam REG_CCM_BR                = MODULE_CCM*(1<<(REG_ID_BITS)) + 6;
	localparam REG_CCM_BG                = MODULE_CCM*(1<<(REG_ID_BITS)) + 7;
	localparam REG_CCM_BB                = MODULE_CCM*(1<<(REG_ID_BITS)) + 8;
	//-- MODULE_CSC
	localparam REG_CSC_CONV_STD          = MODULE_CSC*(1<<(REG_ID_BITS)) + 0;
	//-- SHARP
	localparam REG_SHARP_STRENGTH		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 0;
	localparam REG_SHARP_KERNEL_00		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 16;
	localparam REG_SHARP_KERNEL_01		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 17;
	localparam REG_SHARP_KERNEL_02		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 18;
	localparam REG_SHARP_KERNEL_03		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 19;
	localparam REG_SHARP_KERNEL_04		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 20;
	localparam REG_SHARP_KERNEL_05		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 21;
	localparam REG_SHARP_KERNEL_06		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 22;
	localparam REG_SHARP_KERNEL_07		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 23;
	localparam REG_SHARP_KERNEL_08		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 24;
	localparam REG_SHARP_KERNEL_10		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 25;
	localparam REG_SHARP_KERNEL_11		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 26;
	localparam REG_SHARP_KERNEL_12		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 27;
	localparam REG_SHARP_KERNEL_13		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 28;
	localparam REG_SHARP_KERNEL_14		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 29;
	localparam REG_SHARP_KERNEL_15		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 30;
	localparam REG_SHARP_KERNEL_16		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 31;
	localparam REG_SHARP_KERNEL_17		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 32;
	localparam REG_SHARP_KERNEL_18		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 33;
	localparam REG_SHARP_KERNEL_20		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 34;
	localparam REG_SHARP_KERNEL_21		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 35;
	localparam REG_SHARP_KERNEL_22		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 36;
	localparam REG_SHARP_KERNEL_23		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 37;
	localparam REG_SHARP_KERNEL_24		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 38;
	localparam REG_SHARP_KERNEL_25		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 39;
	localparam REG_SHARP_KERNEL_26		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 40;
	localparam REG_SHARP_KERNEL_27		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 41;
	localparam REG_SHARP_KERNEL_28		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 42;
	localparam REG_SHARP_KERNEL_30		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 43;
	localparam REG_SHARP_KERNEL_31		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 44;
	localparam REG_SHARP_KERNEL_32		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 45;
	localparam REG_SHARP_KERNEL_33		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 46;
	localparam REG_SHARP_KERNEL_34		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 47;
	localparam REG_SHARP_KERNEL_35		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 48;
	localparam REG_SHARP_KERNEL_36		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 49;
	localparam REG_SHARP_KERNEL_37		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 50;
	localparam REG_SHARP_KERNEL_38		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 51;
	localparam REG_SHARP_KERNEL_40		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 52;
	localparam REG_SHARP_KERNEL_41		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 53;
	localparam REG_SHARP_KERNEL_42		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 54;
	localparam REG_SHARP_KERNEL_43		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 55;
	localparam REG_SHARP_KERNEL_44		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 56;
	localparam REG_SHARP_KERNEL_45		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 57;
	localparam REG_SHARP_KERNEL_46		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 58;
	localparam REG_SHARP_KERNEL_47		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 59;
	localparam REG_SHARP_KERNEL_48		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 60;
	localparam REG_SHARP_KERNEL_50		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 61;
	localparam REG_SHARP_KERNEL_51		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 62;
	localparam REG_SHARP_KERNEL_52		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 63;
	localparam REG_SHARP_KERNEL_53		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 64;
	localparam REG_SHARP_KERNEL_54		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 65;
	localparam REG_SHARP_KERNEL_55		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 66;
	localparam REG_SHARP_KERNEL_56		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 67;
	localparam REG_SHARP_KERNEL_57		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 68;
	localparam REG_SHARP_KERNEL_58		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 69;
	localparam REG_SHARP_KERNEL_60		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 70;
	localparam REG_SHARP_KERNEL_61		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 71;
	localparam REG_SHARP_KERNEL_62		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 72;
	localparam REG_SHARP_KERNEL_63		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 73;
	localparam REG_SHARP_KERNEL_64		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 74;
	localparam REG_SHARP_KERNEL_65		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 75;
	localparam REG_SHARP_KERNEL_66		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 76;
	localparam REG_SHARP_KERNEL_67		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 77;
	localparam REG_SHARP_KERNEL_68		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 78;
	localparam REG_SHARP_KERNEL_70		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 79;
	localparam REG_SHARP_KERNEL_71		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 80;
	localparam REG_SHARP_KERNEL_72		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 81;
	localparam REG_SHARP_KERNEL_73		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 82;
	localparam REG_SHARP_KERNEL_74		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 83;
	localparam REG_SHARP_KERNEL_75		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 84;
	localparam REG_SHARP_KERNEL_76		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 85;
	localparam REG_SHARP_KERNEL_77		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 86;
	localparam REG_SHARP_KERNEL_78		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 87;
	localparam REG_SHARP_KERNEL_80		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 88;
	localparam REG_SHARP_KERNEL_81		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 89;
	localparam REG_SHARP_KERNEL_82		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 90;
	localparam REG_SHARP_KERNEL_83		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 91;
	localparam REG_SHARP_KERNEL_84		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 92;
	localparam REG_SHARP_KERNEL_85		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 93;
	localparam REG_SHARP_KERNEL_86		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 94;
	localparam REG_SHARP_KERNEL_87		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 95;
	localparam REG_SHARP_KERNEL_88		 = MODULE_SHARP*(1<<(REG_ID_BITS)) + 96;
	//-- MODULE_BNR
	localparam REG_BNR_SK_R_00           = MODULE_BNR*(1<<(REG_ID_BITS)) + 0;
	localparam REG_BNR_SK_R_04           = MODULE_BNR*(1<<(REG_ID_BITS)) + 1;
	localparam REG_BNR_SK_R_10           = MODULE_BNR*(1<<(REG_ID_BITS)) + 2;
	localparam REG_BNR_SK_R_14           = MODULE_BNR*(1<<(REG_ID_BITS)) + 3;
	localparam REG_BNR_SK_R_20           = MODULE_BNR*(1<<(REG_ID_BITS)) + 4;
	localparam REG_BNR_SK_R_24           = MODULE_BNR*(1<<(REG_ID_BITS)) + 5;
	localparam REG_BNR_SK_R_30           = MODULE_BNR*(1<<(REG_ID_BITS)) + 6;
	localparam REG_BNR_SK_R_34           = MODULE_BNR*(1<<(REG_ID_BITS)) + 7;
	localparam REG_BNR_SK_R_40           = MODULE_BNR*(1<<(REG_ID_BITS)) + 8;
	localparam REG_BNR_SK_R_44           = MODULE_BNR*(1<<(REG_ID_BITS)) + 9;
	
	localparam REG_BNR_SK_G_00           = MODULE_BNR*(1<<(REG_ID_BITS)) + 16;
	localparam REG_BNR_SK_G_04           = MODULE_BNR*(1<<(REG_ID_BITS)) + 17;
	localparam REG_BNR_SK_G_10           = MODULE_BNR*(1<<(REG_ID_BITS)) + 18;
	localparam REG_BNR_SK_G_14           = MODULE_BNR*(1<<(REG_ID_BITS)) + 19;
	localparam REG_BNR_SK_G_20           = MODULE_BNR*(1<<(REG_ID_BITS)) + 20;
	localparam REG_BNR_SK_G_24           = MODULE_BNR*(1<<(REG_ID_BITS)) + 21;
	localparam REG_BNR_SK_G_30           = MODULE_BNR*(1<<(REG_ID_BITS)) + 22;
	localparam REG_BNR_SK_G_34           = MODULE_BNR*(1<<(REG_ID_BITS)) + 23;
	localparam REG_BNR_SK_G_40           = MODULE_BNR*(1<<(REG_ID_BITS)) + 24;
	localparam REG_BNR_SK_G_44           = MODULE_BNR*(1<<(REG_ID_BITS)) + 25;
	
	localparam REG_BNR_SK_B_00           = MODULE_BNR*(1<<(REG_ID_BITS)) + 32;
	localparam REG_BNR_SK_B_04           = MODULE_BNR*(1<<(REG_ID_BITS)) + 33;
	localparam REG_BNR_SK_B_10           = MODULE_BNR*(1<<(REG_ID_BITS)) + 34;
	localparam REG_BNR_SK_B_14           = MODULE_BNR*(1<<(REG_ID_BITS)) + 35;
	localparam REG_BNR_SK_B_20           = MODULE_BNR*(1<<(REG_ID_BITS)) + 36;
	localparam REG_BNR_SK_B_24           = MODULE_BNR*(1<<(REG_ID_BITS)) + 37;
	localparam REG_BNR_SK_B_30           = MODULE_BNR*(1<<(REG_ID_BITS)) + 38;
	localparam REG_BNR_SK_B_34           = MODULE_BNR*(1<<(REG_ID_BITS)) + 39;
	localparam REG_BNR_SK_B_40           = MODULE_BNR*(1<<(REG_ID_BITS)) + 40;
	localparam REG_BNR_SK_B_44           = MODULE_BNR*(1<<(REG_ID_BITS)) + 41;
	
	localparam REG_BNR_CC_R_0           = MODULE_BNR*(1<<(REG_ID_BITS)) + 64;
	localparam REG_BNR_CC_R_1           = MODULE_BNR*(1<<(REG_ID_BITS)) + 65;
	localparam REG_BNR_CC_R_2           = MODULE_BNR*(1<<(REG_ID_BITS)) + 66;
	localparam REG_BNR_CC_R_3           = MODULE_BNR*(1<<(REG_ID_BITS)) + 67;
	localparam REG_BNR_CC_R_4           = MODULE_BNR*(1<<(REG_ID_BITS)) + 68;
	localparam REG_BNR_CC_R_5           = MODULE_BNR*(1<<(REG_ID_BITS)) + 69;
	localparam REG_BNR_CC_R_6           = MODULE_BNR*(1<<(REG_ID_BITS)) + 70;
	localparam REG_BNR_CC_R_7           = MODULE_BNR*(1<<(REG_ID_BITS)) + 71;
	localparam REG_BNR_CC_R_8           = MODULE_BNR*(1<<(REG_ID_BITS)) + 72;
	
	localparam REG_BNR_CC_G_0           = MODULE_BNR*(1<<(REG_ID_BITS)) + 80;
	localparam REG_BNR_CC_G_1           = MODULE_BNR*(1<<(REG_ID_BITS)) + 81;
	localparam REG_BNR_CC_G_2           = MODULE_BNR*(1<<(REG_ID_BITS)) + 82;
	localparam REG_BNR_CC_G_3           = MODULE_BNR*(1<<(REG_ID_BITS)) + 83;
	localparam REG_BNR_CC_G_4           = MODULE_BNR*(1<<(REG_ID_BITS)) + 84;
	localparam REG_BNR_CC_G_5           = MODULE_BNR*(1<<(REG_ID_BITS)) + 85;
	localparam REG_BNR_CC_G_6           = MODULE_BNR*(1<<(REG_ID_BITS)) + 86;
	localparam REG_BNR_CC_G_7           = MODULE_BNR*(1<<(REG_ID_BITS)) + 87;
	localparam REG_BNR_CC_G_8           = MODULE_BNR*(1<<(REG_ID_BITS)) + 88;
	
	localparam REG_BNR_CC_B_0           = MODULE_BNR*(1<<(REG_ID_BITS)) + 96;
	localparam REG_BNR_CC_B_1           = MODULE_BNR*(1<<(REG_ID_BITS)) + 97;
	localparam REG_BNR_CC_B_2           = MODULE_BNR*(1<<(REG_ID_BITS)) + 98;
	localparam REG_BNR_CC_B_3           = MODULE_BNR*(1<<(REG_ID_BITS)) + 99;
	localparam REG_BNR_CC_B_4           = MODULE_BNR*(1<<(REG_ID_BITS)) + 100;
	localparam REG_BNR_CC_B_5           = MODULE_BNR*(1<<(REG_ID_BITS)) + 101;
	localparam REG_BNR_CC_B_6           = MODULE_BNR*(1<<(REG_ID_BITS)) + 102;
	localparam REG_BNR_CC_B_7           = MODULE_BNR*(1<<(REG_ID_BITS)) + 103;
	localparam REG_BNR_CC_B_8           = MODULE_BNR*(1<<(REG_ID_BITS)) + 104;
	//-- MODULE_2DNR
	localparam REG_2DNR_DIFF_00          = MODULE_2DNR*(1<<(REG_ID_BITS)) + 0;
	localparam REG_2DNR_DIFF_04          = MODULE_2DNR*(1<<(REG_ID_BITS)) + 1;
	localparam REG_2DNR_DIFF_08          = MODULE_2DNR*(1<<(REG_ID_BITS)) + 2;
	localparam REG_2DNR_DIFF_0C          = MODULE_2DNR*(1<<(REG_ID_BITS)) + 3;
	localparam REG_2DNR_DIFF_10          = MODULE_2DNR*(1<<(REG_ID_BITS)) + 4;
	localparam REG_2DNR_DIFF_14          = MODULE_2DNR*(1<<(REG_ID_BITS)) + 5;
	localparam REG_2DNR_DIFF_18          = MODULE_2DNR*(1<<(REG_ID_BITS)) + 6;
	localparam REG_2DNR_DIFF_1C          = MODULE_2DNR*(1<<(REG_ID_BITS)) + 7;
	
	localparam REG_2DNR_WEIGHT_00        = MODULE_2DNR*(1<<(REG_ID_BITS)) + 16;
	localparam REG_2DNR_WEIGHT_04        = MODULE_2DNR*(1<<(REG_ID_BITS)) + 17;
	localparam REG_2DNR_WEIGHT_08        = MODULE_2DNR*(1<<(REG_ID_BITS)) + 18;
	localparam REG_2DNR_WEIGHT_0C        = MODULE_2DNR*(1<<(REG_ID_BITS)) + 19;
	localparam REG_2DNR_WEIGHT_10        = MODULE_2DNR*(1<<(REG_ID_BITS)) + 20;
	localparam REG_2DNR_WEIGHT_14        = MODULE_2DNR*(1<<(REG_ID_BITS)) + 21;
	localparam REG_2DNR_WEIGHT_18        = MODULE_2DNR*(1<<(REG_ID_BITS)) + 22;
	localparam REG_2DNR_WEIGHT_1C        = MODULE_2DNR*(1<<(REG_ID_BITS)) + 23;
	//-- VIP1_MODULE_CONFIG
	localparam REG_VIP1_RESET                 = VIP1_MODULE_CONFIG*(1<<REG_ID_BITS) + 0;
	localparam REG_VIP1_WIDTH                 = VIP1_MODULE_CONFIG*(1<<REG_ID_BITS) + 1;
	localparam REG_VIP1_HEIGHT                = VIP1_MODULE_CONFIG*(1<<REG_ID_BITS) + 2;
	localparam REG_VIP1_BITS                  = VIP1_MODULE_CONFIG*(1<<REG_ID_BITS) + 3;
	localparam REG_VIP1_TOP_EN                = VIP1_MODULE_CONFIG*(1<<REG_ID_BITS) + 16;
	localparam REG_VIP1_INT_STATUS            = VIP1_MODULE_CONFIG*(1<<REG_ID_BITS) + 17;
	localparam REG_VIP1_INT_MASK              = VIP1_MODULE_CONFIG*(1<<REG_ID_BITS) + 18;
    //-- VIP1_MODULE_RGBC
    localparam REG_VIP1_RGBC_CONV_STD         = VIP1_MODULE_RGBC*(1<<REG_ID_BITS) + 0;
    //-- VIP1_MODULE_IRC
    localparam REG_VIP1_IRC_X                 = VIP1_MODULE_IRC*(1<<REG_ID_BITS) + 0;
    localparam REG_VIP1_IRC_Y                 = VIP1_MODULE_IRC*(1<<REG_ID_BITS) + 1;
	localparam REG_VIP1_IRC_OUTPUT            = VIP1_MODULE_IRC*(1<<REG_ID_BITS) + 2;
    //-- VIP1_MODULE_SCALE
    localparam REG_VIP1_SCALE_IN_CROP_W       = VIP1_MODULE_SCALE*(1<<REG_ID_BITS) + 0;
	localparam REG_VIP1_SCALE_IN_CROP_H       = VIP1_MODULE_SCALE*(1<<REG_ID_BITS) + 1;
	localparam REG_VIP1_SCALE_OUT_CROP_W      = VIP1_MODULE_SCALE*(1<<REG_ID_BITS) + 2;
	localparam REG_VIP1_SCALE_OUT_CROP_H      = VIP1_MODULE_SCALE*(1<<REG_ID_BITS) + 3;
	localparam REG_VIP1_SCALE_DSCALE_W        = VIP1_MODULE_SCALE*(1<<REG_ID_BITS) + 4;
	localparam REG_VIP1_SCALE_DSCALE_H        = VIP1_MODULE_SCALE*(1<<REG_ID_BITS) + 5;
    //-- VIP1_MODULE_OSD
    localparam REG_VIP1_OSD_X                 = VIP1_MODULE_OSD*(1<<REG_ID_BITS) + 0;
	localparam REG_VIP1_OSD_Y                 = VIP1_MODULE_OSD*(1<<REG_ID_BITS) + 1;
	localparam REG_VIP1_OSD_W                 = VIP1_MODULE_OSD*(1<<REG_ID_BITS) + 2;
	localparam REG_VIP1_OSD_H                 = VIP1_MODULE_OSD*(1<<REG_ID_BITS) + 3;
	localparam REG_VIP1_OSD_COLOR_FG          = VIP1_MODULE_OSD*(1<<REG_ID_BITS) + 4;
	localparam REG_VIP1_OSD_COLOR_BG          = VIP1_MODULE_OSD*(1<<REG_ID_BITS) + 5;
	localparam REG_VIP1_ALPHA				  = VIP1_MODULE_OSD*(1<<REG_ID_BITS) + 6;
    //-- VIP1_MODULE_YUV444TO422
    localparam REG_VIP1_YUV_YUV444TO422       = VIP1_MODULE_YUV444TO422*(1<<REG_ID_BITS) + 0;

	//-- VIP2_MODULE_CONFIG
	localparam REG_VIP2_RESET                 = VIP2_MODULE_CONFIG*(1<<REG_ID_BITS) + 0;
	localparam REG_VIP2_WIDTH                 = VIP2_MODULE_CONFIG*(1<<REG_ID_BITS) + 1;
	localparam REG_VIP2_HEIGHT                = VIP2_MODULE_CONFIG*(1<<REG_ID_BITS) + 2;
	localparam REG_VIP2_BITS                  = VIP2_MODULE_CONFIG*(1<<REG_ID_BITS) + 3;
	localparam REG_VIP2_TOP_EN                = VIP2_MODULE_CONFIG*(1<<REG_ID_BITS) + 16;
	localparam REG_VIP2_INT_STATUS            = VIP2_MODULE_CONFIG*(1<<REG_ID_BITS) + 17;
	localparam REG_VIP2_INT_MASK              = VIP2_MODULE_CONFIG*(1<<REG_ID_BITS) + 18;
    //-- VIP2_MODULE_RGBC
    localparam REG_VIP2_RGBC_CONV_STD         = VIP2_MODULE_RGBC*(1<<REG_ID_BITS) + 0;
    //-- VIP2_MODULE_IRC
    localparam REG_VIP2_IRC_X                 = VIP2_MODULE_IRC*(1<<REG_ID_BITS) + 0;
    localparam REG_VIP2_IRC_Y                 = VIP2_MODULE_IRC*(1<<REG_ID_BITS) + 1;
	localparam REG_VIP2_IRC_OUTPUT            = VIP2_MODULE_IRC*(1<<REG_ID_BITS) + 2;
    //-- VIP2_MODULE_SCALE
    localparam REG_VIP2_SCALE_IN_CROP_W       = VIP2_MODULE_SCALE*(1<<REG_ID_BITS) + 0;
	localparam REG_VIP2_SCALE_IN_CROP_H       = VIP2_MODULE_SCALE*(1<<REG_ID_BITS) + 1;
	localparam REG_VIP2_SCALE_OUT_CROP_W      = VIP2_MODULE_SCALE*(1<<REG_ID_BITS) + 2;
	localparam REG_VIP2_SCALE_OUT_CROP_H      = VIP2_MODULE_SCALE*(1<<REG_ID_BITS) + 3;
	localparam REG_VIP2_SCALE_DSCALE_W        = VIP2_MODULE_SCALE*(1<<REG_ID_BITS) + 4;
	localparam REG_VIP2_SCALE_DSCALE_H        = VIP2_MODULE_SCALE*(1<<REG_ID_BITS) + 5;
    //-- VIP2_MODULE_OSD
    localparam REG_VIP2_OSD_X                 = VIP2_MODULE_OSD*(1<<REG_ID_BITS) + 0;
	localparam REG_VIP2_OSD_Y                 = VIP2_MODULE_OSD*(1<<REG_ID_BITS) + 1;
	localparam REG_VIP2_OSD_W                 = VIP2_MODULE_OSD*(1<<REG_ID_BITS) + 2;
	localparam REG_VIP2_OSD_H                 = VIP2_MODULE_OSD*(1<<REG_ID_BITS) + 3;
	localparam REG_VIP2_OSD_COLOR_FG          = VIP2_MODULE_OSD*(1<<REG_ID_BITS) + 4;
	localparam REG_VIP2_OSD_COLOR_BG          = VIP2_MODULE_OSD*(1<<REG_ID_BITS) + 5;
	localparam REG_VIP2_ALPHA				  = VIP2_MODULE_OSD*(1<<REG_ID_BITS) + 6;
    //-- VIP2_MODULE_YUV444TO422
    localparam REG_VIP2_YUV_YUV444TO422       = VIP2_MODULE_YUV444TO422*(1<<REG_ID_BITS) + 0;
	
	reg module_reset;
	// Module Enables
	reg crop_en, dpc_en, blc_en, linear_en, oecf_en, dgain_en, lsc_en, bnr_en, wb_en, demosic_en, ccm_en, gamma_en, csc_en, ldci_en, nr2d_en, sharp_en, stat_ae_en, awb_en, ae_en;
    // DPC
	reg [BITS-1:0] dpc_threshold;
	// BLC
	reg [BITS-1:0] blc_r, blc_gr, blc_gb, blc_b;
	reg [15:0] linear_r, linear_gr, linear_gb, linear_b;
	// DG
	reg dgain_isManual;
	reg [DGAIN_ARRAY_BITS-1:0] dgain_man_index;
	reg [DGAIN_ARRAY_SIZE*8-1:0] dgain_array;
	wire [DGAIN_ARRAY_BITS-1:0] dgain_index_out; // Read Only
	// BNR
	reg [5*5*BNR_WEIGHT_BITS-1:0] bnr_space_kernel_r;	
	reg [5*5*BNR_WEIGHT_BITS-1:0] bnr_space_kernel_g;
	reg [5*5*BNR_WEIGHT_BITS-1:0] bnr_space_kernel_b;  
	reg [9*BITS-1:0]              bnr_color_curve_x_r;   
	reg [9*BNR_WEIGHT_BITS-1:0]   bnr_color_curve_y_r;
	reg [9*BITS-1:0]              bnr_color_curve_x_g;   
	reg [9*BNR_WEIGHT_BITS-1:0]   bnr_color_curve_y_g;
	reg [9*BITS-1:0]              bnr_color_curve_x_b;   
	reg [9*BNR_WEIGHT_BITS-1:0]   bnr_color_curve_y_b;
	// WB
	reg [11:0] wb_rgain, wb_bgain;
	// CCM
	reg [15:0] ccm_rr, ccm_rg, ccm_rb;
	reg [15:0] ccm_gr, ccm_gg, ccm_gb;
	reg [15:0] ccm_br, ccm_bg, ccm_bb;
	// CSC
	reg [1:0] in_conv_standard;
	// SHARP
	reg [9*9*SHARP_WEIGHT_BITS-1:0] luma_kernel;
	reg [11:0] sharpen_strength;	
    // 2DNR
	reg [32*8-1:0]                  nr2d_diff;
	reg [32*NR2D_WEIGHT_BITS-1:0]   nr2d_weight;

	reg [15:0] stat_ae_rect_x, stat_ae_rect_y, stat_ae_rect_w, stat_ae_rect_h;
	wire stat_ae_done;
	wire [STAT_OUT_BITS-1:0] stat_ae_pix_cnt, stat_ae_sum;
	// AE
	reg [7:0] center_illuminance;
    reg [15:0] skewness;
	reg [11:0] ae_crop_left;
	reg [11:0] ae_crop_right;
	reg [11:0] ae_crop_top;
	reg [11:0] ae_crop_bottom; 
    wire [1:0] ae_response;         // Read Only
    wire [15:0] ae_result_skewness; // Read Only
    wire [1:0] ae_response_debug;   // Read Only
    wire ae_done;                   // Read Only
	// AWB
	reg [BITS-1:0] awb_underexposed_limit, awb_overexposed_limit, awb_frames;

	reg vip1_module_reset;
	reg vip1_yuv444to422_en, vip1_osd_en, vip1_dscale_en, vip1_crop_en, vip1_yuv2rgb_en;

    // Hist Eq

	// RGBC
	reg [1:0] vip1_vip_in_conv_standard;
	
	// IRC
	reg [15:0] vip1_crop_x;
	reg [15:0] vip1_crop_y;
	reg [1:0] vip1_irc_output;
	
	// Scale
    
    reg [11:0] vip1_s_in_crop_w;
    reg [11:0] vip1_s_in_crop_h;
	reg [11:0] vip1_s_out_crop_w;
	reg [11:0] vip1_s_out_crop_h;
	reg [2:0] vip1_dscale_w;
	reg [2:0] vip1_dscale_h;
	
	// OSD
	reg [15:0] vip1_osd_x, vip1_osd_y, vip1_osd_w, vip1_osd_h;
	reg [(3*VIP1_BITS)-1:0] vip1_osd_color_fg, vip1_osd_color_bg;
	reg [7:0] vip1_alpha ;
	
	// vip1_YUV444TO422
	reg vip1_YUV444TO422;

	reg vip2_module_reset;
	reg vip2_yuv444to422_en, vip2_osd_en, vip2_dscale_en, vip2_crop_en, vip2_yuv2rgb_en;
	// Hist Eq

	// RGBC
	reg [1:0] vip2_vip_in_conv_standard;
	
	// IRC
	reg [15:0] vip2_crop_x;
	reg [15:0] vip2_crop_y;
	reg [1:0] vip2_irc_output;
	
	// Scale
    
    reg [11:0] vip2_s_in_crop_w;
    reg [11:0] vip2_s_in_crop_h;
	reg [11:0] vip2_s_out_crop_w;
	reg [11:0] vip2_s_out_crop_h;
	reg [2:0] vip2_dscale_w;
	reg [2:0] vip2_dscale_h;
	
	// OSD
	reg [15:0] vip2_osd_x, vip2_osd_y, vip2_osd_w, vip2_osd_h;
	reg [(3*VIP2_BITS)-1:0] vip2_osd_color_fg, vip2_osd_color_bg;
	reg [7:0] vip2_alpha ;
	
	// vip2_YUV444TO422
	reg vip2_YUV444TO422;

    wire [11:0] final_r_gain, final_b_gain;
//    wire [11:0] r_gain, b_gain;
//    wire high;
	wire isp_out_vsync;

	reg int_isp_frame_start, int_isp_frame_done, int_ae_done, int_awb_done;
	reg int_vip1_frame_start, int_vip1_frame_done;
	reg int_vip2_frame_start, int_vip2_frame_done;
	reg int_isp_mask_frame_start, int_isp_mask_frame_done, int_mask_ae_done, int_mask_awb_done;
	reg int_vip1_mask_frame_start, int_vip1_mask_frame_done;
	reg int_vip2_mask_frame_start, int_vip2_mask_frame_done;
	
	wire vip1_irq, vip2_irq;
	assign vip1_irq	= (int_vip1_frame_start&(~int_vip1_mask_frame_start) | int_vip1_frame_done&(~int_vip1_mask_frame_done));
	assign vip2_irq	= (int_vip2_frame_start&(~int_vip2_mask_frame_start) | int_vip2_frame_done&(~int_vip2_mask_frame_done));
	assign isp_irq = int_isp_frame_start&(~int_isp_mask_frame_start) | int_isp_frame_done&(~int_isp_mask_frame_done)
					| int_ae_done&(~int_mask_ae_done) | int_awb_done&(~int_mask_awb_done) | vip1_irq | vip2_irq;

	reg [1:0] in_vsync_prev;
	always @ (posedge S_AXI_ACLK) in_vsync_prev <= {in_vsync_prev[0],in_vsync};
	wire isp_frame_start = ~in_vsync_prev[0] & in_vsync_prev[1];

	reg [1:0] isp_out_vsync_prev;
	always @ (posedge S_AXI_ACLK) isp_out_vsync_prev <= {isp_out_vsync_prev[0],isp_out_vsync};
	wire isp_frame_done = isp_out_vsync_prev[0] & (~isp_out_vsync_prev[1]);
	
	reg [1:0] vip1_in_vsync_prev;
	always @ (posedge S_AXI_ACLK) vip1_in_vsync_prev <= {vip1_in_vsync_prev[0],isp_out_vsync};
	wire vip1_frame_start = ~vip1_in_vsync_prev[0] & vip1_in_vsync_prev[1];
	wire vip2_frame_start = vip1_frame_start;

	reg [1:0] vip1_out_vsync_prev;
	always @ (posedge S_AXI_ACLK) vip1_out_vsync_prev <= {vip1_out_vsync_prev[0],out_vsync1};
	wire vip1_frame_done = vip1_out_vsync_prev[0] & (~vip1_out_vsync_prev[1]);
	
	reg [1:0] vip2_out_vsync_prev;
	always @ (posedge S_AXI_ACLK) vip2_out_vsync_prev <= {vip2_out_vsync_prev[0],out_vsync2};
	wire vip2_frame_done = vip2_out_vsync_prev[0] & (~vip2_out_vsync_prev[1]);

	wire	 slv_reg_rden;
	wire	 slv_reg_wren;
	reg [C_S_AXI_DATA_WIDTH-1:0]	 reg_data_out;
	integer	 byte_index;
	reg	 aw_en;

	// I/O Connections assignments

	assign S_AXI_AWREADY	= axi_awready;
	assign S_AXI_WREADY	= axi_wready;
	assign S_AXI_BRESP	= axi_bresp;
	assign S_AXI_BVALID	= axi_bvalid;
	assign S_AXI_ARREADY	= axi_arready;
	//assign S_AXI_RDATA	= axi_rdata;
	assign S_AXI_RRESP	= axi_rresp;
	assign S_AXI_RVALID	= axi_rvalid;
	// Implement axi_awready generation
	// axi_awready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
	// de-asserted when reset is low.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awready <= 1'b0;
	      aw_en <= 1'b1;
	    end 
	  else
	    begin    
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
	        begin
	          // slave is ready to accept write address when 
	          // there is a valid write address and write data
	          // on the write address and data bus. This design 
	          // expects no outstanding transactions. 
	          axi_awready <= 1'b1;
	          aw_en <= 1'b0;
	        end
	        else if (S_AXI_BREADY && axi_bvalid)
	            begin
	              aw_en <= 1'b1;
	              axi_awready <= 1'b0;
	            end
	      else           
	        begin
	          axi_awready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_awaddr latching
	// This process is used to latch the address when both 
	// S_AXI_AWVALID and S_AXI_WVALID are valid. 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awaddr <= 0;
	    end 
	  else
	    begin    
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
	        begin
	          // Write Address latching 
	          axi_awaddr <= S_AXI_AWADDR;
	        end
	    end 
	end       

	// Implement axi_wready generation
	// axi_wready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
	// de-asserted when reset is low. 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_wready <= 1'b0;
	    end 
	  else
	    begin    
	      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en )
	        begin
	          // slave is ready to accept write data when 
	          // there is a valid write address and write data
	          // on the write address and data bus. This design 
	          // expects no outstanding transactions. 
	          axi_wready <= 1'b1;
	        end
	      else
	        begin
	          axi_wready <= 1'b0;
	        end
	    end 
	end       

	// Implement memory mapped register select and write logic generation
	// The write data is accepted and written to memory mapped registers when
	// axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
	// select byte enables of slave registers while writing.
	// These registers are cleared when reset (active low) is applied.
	// Slave register write enable is asserted when valid address and data are available
	// and the slave is ready to accept the write address and write data.
	assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	        // Initial Values Go Here

            module_reset <= 0;
			vip1_module_reset <= 0;
			vip2_module_reset <= 0;
			// Module Enables
			crop_en <= 1;
			dpc_en <= 1;
			blc_en <= 1;
			linear_en <= 1;
			oecf_en <= 1;
			dgain_en <= 1;
			lsc_en <= 0;
			bnr_en <= 1;
			wb_en <= 1;
			demosic_en <= 1;
			ccm_en <= 1;
			gamma_en <= 1;
			csc_en <= 1;
			sharp_en <= 1;
			ldci_en <= 0;
			nr2d_en <= 1;
			stat_ae_en <= 0;
			awb_en <= 1;
			ae_en <= 1;
            //vip
			vip1_yuv2rgb_en <= 1;
			vip1_crop_en <= 1;
			vip1_dscale_en <= 1;
			vip1_osd_en <= 1;
			vip1_yuv444to422_en <= 1;
			vip2_yuv2rgb_en <= 1;
			vip2_crop_en <= 1;
			vip2_dscale_en <= 1;
			vip2_osd_en <= 1;
			vip2_yuv444to422_en <= 1;
			// DPC
			dpc_threshold <= 2;
			// BLC
			blc_r <= 8'd16 << (BITS-8);
			blc_gr <= 8'd16 << (BITS-8);
			blc_gb <= 8'd16 << (BITS-8);
			blc_b <= 8'd16 << (BITS-8);
			linear_r <= 16'b0100010001000101;
			linear_gr <= 16'b0100010001000101;
			linear_gb <= 16'b0100010001000101;
			linear_b <= 16'b0100010001000101;
			// DG
			dgain_isManual <= 0;
			dgain_man_index <= 0;
			dgain_array <= {{8'd100},{8'd99},{8'd98},{8'd97},{8'd96},{8'd95},{8'd94},{8'd93},{8'd92},{8'd91},{8'd90},{8'd89},{8'd88},{8'd87},{8'd86},{8'd85},{8'd84},{8'd83},{8'd82},{8'd81},{8'd80},{8'd79},{8'd78},{8'd77},{8'd76},{8'd75},{8'd74},{8'd73},{8'd72},{8'd71},{8'd70},{8'd69},{8'd68},{8'd67},{8'd66},{8'd65},{8'd64},{8'd63},{8'd62},{8'd61},{8'd60},{8'd59},{8'd58},{8'd57},{8'd56},{8'd55},{8'd54},{8'd53},{8'd52},{8'd51},{8'd50},{8'd49},{8'd48},{8'd47},{8'd46},{8'd45},{8'd44},{8'd43},{8'd42},{8'd41},{8'd40},{8'd39},{8'd38},{8'd37},{8'd36},{8'd35},{8'd34},{8'd33},{8'd32},{8'd31},{8'd30},{8'd29},{8'd28},{8'd27},{8'd26},{8'd25},{8'd24},{8'd23},{8'd22},{8'd21},{8'd20},{8'd19},{8'd18},{8'd17},{8'd16},{8'd15},{8'd14},{8'd13},{8'd12},{8'd11},{8'd10},{8'd9},{8'd8},{8'd7},{8'd6},{8'd5},{8'd4},{8'd3},{8'd2},{8'd1}};
			// BNR
			bnr_space_kernel_r <= {{8'd0},{8'd3},{8'd7},{8'd3},{8'd0},
									 {8'd3},{8'd43},{8'd105},{8'd43},{8'd3},
									 {8'd7},{8'd105},{8'd255},{8'd105},{8'd7},
									 {8'd3},{8'd43},{8'd105},{8'd43},{8'd3},
									 {8'd0},{8'd3},{8'd7},{8'd3},{8'd0}};
			bnr_space_kernel_g <= {{8'd0},{8'd3},{8'd7},{8'd3},{8'd0},
									 {8'd3},{8'd43},{8'd105},{8'd43},{8'd3},
									 {8'd7},{8'd105},{8'd255},{8'd105},{8'd7},
									 {8'd3},{8'd43},{8'd105},{8'd43},{8'd3},
									 {8'd0},{8'd3},{8'd7},{8'd3},{8'd0}};
			bnr_space_kernel_b <= {{8'd0},{8'd3},{8'd7},{8'd3},{8'd0},
									 {8'd3},{8'd43},{8'd105},{8'd43},{8'd3},
									 {8'd7},{8'd105},{8'd255},{8'd105},{8'd7},
									 {8'd3},{8'd43},{8'd105},{8'd43},{8'd3},
									 {8'd0},{8'd3},{8'd7},{8'd3},{8'd0}};
			bnr_color_curve_x_r <= {{10'd257},{10'd229},{10'd200},{10'd171},{10'd143},{10'd114},{10'd85},{10'd57},{10'd28}};
			bnr_color_curve_y_r <= {{8'd51},{8'd71},{8'd96},{8'd125},{8'd155},{8'd186},{8'd214},{8'd236},{8'd250}};
			bnr_color_curve_x_g <= {{10'd92},{10'd81},{10'd71},{10'd61},{10'd51},{10'd40},{10'd30},{10'd20},{10'd10}};
			bnr_color_curve_y_g <= {{8'd51},{8'd73},{8'd97},{8'd125},{8'd155},{8'd188},{8'd215},{8'd236},{8'd250}};
			bnr_color_curve_x_b <= {{10'd257},{10'd229},{10'd200},{10'd171},{10'd143},{10'd114},{10'd85},{10'd57},{10'd28}};
			bnr_color_curve_y_b <= {{8'd51},{8'd71},{8'd96},{8'd125},{8'd155},{8'd186},{8'd214},{8'd236},{8'd250}};
			// WB
			wb_rgain <= 12'b0001_00111111;
			wb_bgain <= 12'b0010_11001111;
			// CCM
			ccm_rr <=  16'd2966;
			ccm_rg <= -1*(16'd1687);
			ccm_rb <= -1*(16'd255);
			ccm_gr <= -1*(16'd663);
			ccm_gg <=  16'd2312;
			ccm_gb <= -1*(16'd625);
			ccm_br <= -1*(16'd104);
			ccm_bg <= -1*(16'd1049);
			ccm_bb <=  16'd2177;
			// CSC
			in_conv_standard <= 2'd2;
			// SHARP
			sharpen_strength = 12'b001110011001;
			luma_kernel = { {20'd764},{20'd1833},{20'd3424},{20'd4982},{20'd5646},{20'd4982},{20'd3424},{20'd1833},{20'd764},
							{20'd1833},{20'd4397},{20'd8215},{20'd11953},{20'd13544},{20'd11953},{20'd8215},{20'd4397},{20'd1833},
							{20'd3424},{20'd8215},{20'd15348},{20'd22331},{20'd25305},{20'd22331},{20'd15348},{20'd8215},{20'd3424},
							{20'd4982},{20'd11953},{20'd22331},{20'd32492},{20'd36819},{20'd32492},{20'd22331},{20'd11953},{20'd4982},
							{20'd5646},{20'd13544},{20'd25305},{20'd36819},{20'd41721},{20'd36819},{20'd25305},{20'd13544},{20'd5646},
							{20'd4982},{20'd11953},{20'd22331},{20'd32492},{20'd36819},{20'd32492},{20'd22331},{20'd11953},{20'd4982},
							{20'd3424},{20'd8215},{20'd15348},{20'd22331},{20'd25305},{20'd22331},{20'd15348},{20'd8215},{20'd3424},
							{20'd1833},{20'd4397},{20'd8215},{20'd11953},{20'd13544},{20'd11953},{20'd8215},{20'd4397},{20'd1833},
							{20'd764},{20'd1833},{20'd3424},{20'd4982},{20'd5646},{20'd4982},{20'd3424},{20'd1833},{20'd764}};
			// 2DNR
			nr2d_diff <= {{8'd255},{8'd246},{8'd238},{8'd230},{8'd222},{8'd213},{8'd205},{8'd197},{8'd189},{8'd180},{8'd172},{8'd164},{8'd156},{8'd148},{8'd139},{8'd131},{8'd123},{8'd115},{8'd106},{8'd98},{8'd90},{8'd82},{8'd74},{8'd65},{8'd57},{8'd49},{8'd41},{8'd32},{8'd24},{8'd16},{8'd8},{8'd0}};
	        nr2d_weight <= {{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd0},{5'd2},{5'd9},{5'd22},{5'd31}};
			
			stat_ae_rect_x <= 0;
			stat_ae_rect_y <= 0;
			stat_ae_rect_w <= 0;
			stat_ae_rect_h <= 0;
			// AE
			center_illuminance <= 110;
			skewness <= 275;
			ae_crop_left <= 12;
			ae_crop_right <= 12;
			ae_crop_top <= 22;
			ae_crop_bottom <= 2;
			// AWB
			awb_underexposed_limit <=  51;
			awb_overexposed_limit <=  972;
			awb_frames <= 1;
            // RGBC
            vip1_vip_in_conv_standard <= 2;
            // IRC
			vip1_crop_x <= 16;
			vip1_crop_y <= 30;
			vip1_irc_output <= 1;
			// SCALE
            
            vip1_s_in_crop_w <= 1920;
            vip1_s_in_crop_h <= 1080;
            vip1_s_out_crop_w <= 1920;
            vip1_s_out_crop_h <= 1080;
            vip1_dscale_w <= 1;
            vip1_dscale_h <= 1;
			// OSD
			vip1_osd_x <= 16;
			vip1_osd_y <= 16;
			vip1_osd_w <= 128;
			vip1_osd_h <= 64;
			vip1_osd_color_fg <= 24'h0000ff;
			vip1_osd_color_bg <= 24'hffffff;
			vip1_alpha <= 50;
			// vip1_YUV444TO422
			vip1_YUV444TO422 <= 0;

			// RGBC
            vip2_vip_in_conv_standard <= 2;
            // IRC
			vip2_crop_x <= 16;
			vip2_crop_y <= 30;
			vip2_irc_output <= 1;
			// SCALE
            
            vip2_s_in_crop_w <= 1920;
            vip2_s_in_crop_h <= 1080;
            vip2_s_out_crop_w <= 1920;
            vip2_s_out_crop_h <= 1080;
            vip2_dscale_w <= 1;
            vip2_dscale_h <= 1;
			// OSD
			vip2_osd_x <= 16;
			vip2_osd_y <= 16;
			vip2_osd_w <= 128;
			vip2_osd_h <= 64;
			vip2_osd_color_fg <= 24'h0000ff;
			vip2_osd_color_bg <= 24'hffffff;
			vip2_alpha <= 50;
			// vip2_YUV444TO422
			vip2_YUV444TO422 <= 0;
			
			int_isp_frame_start <= 0;
			int_isp_frame_done <= 0;
			int_vip1_frame_start <= 0;
			int_vip1_frame_done <= 0;
			int_ae_done <= 0;
			int_awb_done <= 0;
			int_isp_mask_frame_start <= 1;
			int_isp_mask_frame_done <= 1;
			int_vip1_mask_frame_start <= 1;
			int_vip1_mask_frame_done <= 1;
			int_mask_ae_done <= 1;
			int_mask_awb_done <= 1;
	    end 
	  else begin

	    if (slv_reg_wren && axi_awaddr_mode_id == 0)
	      begin
	        case ( axi_awaddr[ADDR_LSB+MODULE_ID_BITS+REG_ID_BITS-1:ADDR_LSB] )
	            // AXI Write Logic For Module Registerss
				REG_RESET: module_reset <= S_AXI_WDATA[0];
				REG_SNS_WIDTH: ;
				REG_SNS_HEIGHT: ;
				REG_CROP_WIDTH: ;
				REG_CROP_HEIGHT: ;
				REG_BITS: ;
				REG_BAYER: ;
				// Module Enables
				REG_TOP_EN: {crop_en, awb_en, ae_en, sharp_en, nr2d_en, ldci_en, csc_en, gamma_en, ccm_en, demosic_en, wb_en, bnr_en, lsc_en, dgain_en, oecf_en, linear_en, blc_en, dpc_en} <= S_AXI_WDATA[17:0];
				// DPC
				REG_DPC_THRESHOLD: dpc_threshold <= S_AXI_WDATA[BITS-1:0];
				// BLC
				REG_BLC_R: blc_r <= S_AXI_WDATA[BITS-1:0];
				REG_BLC_GR: blc_gr <= S_AXI_WDATA[BITS-1:0];
				REG_BLC_GB: blc_gb <= S_AXI_WDATA[BITS-1:0];
				REG_BLC_B: blc_b <= S_AXI_WDATA[BITS-1:0];
				REG_LINEAR_R: linear_r <= S_AXI_WDATA[15:0];
				REG_LINEAR_GR: linear_gr <= S_AXI_WDATA[15:0];
				REG_LINEAR_GB: linear_gb <= S_AXI_WDATA[15:0];
				REG_LINEAR_B: linear_b <= S_AXI_WDATA[15:0];
				// DG
				REG_DGAIN_ISMANUAL: dgain_isManual <= S_AXI_WDATA[0];
				REG_DGAIN_MAN_INDEX: dgain_man_index <= S_AXI_WDATA[3:0];
				REG_DGAIN_ARRAY_00: dgain_array[ 0*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_01: dgain_array[ 1*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_02: dgain_array[ 2*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_03: dgain_array[ 3*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_04: dgain_array[ 4*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_05: dgain_array[ 5*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_06: dgain_array[ 6*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_07: dgain_array[ 7*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_08: dgain_array[ 8*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_09: dgain_array[ 9*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_0A: dgain_array[10*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_0B: dgain_array[11*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_0C: dgain_array[12*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_0D: dgain_array[13*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_0E: dgain_array[14*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_0F: dgain_array[15*8+:8] <= S_AXI_WDATA[7:0];			
				REG_DGAIN_ARRAY_10: dgain_array[16*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_11: dgain_array[17*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_12: dgain_array[18*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_13: dgain_array[19*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_14: dgain_array[20*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_15: dgain_array[21*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_16: dgain_array[22*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_17: dgain_array[23*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_18: dgain_array[24*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_19: dgain_array[25*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_1A: dgain_array[26*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_1B: dgain_array[27*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_1C: dgain_array[28*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_1D: dgain_array[29*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_1E: dgain_array[30*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_1F: dgain_array[31*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_20: dgain_array[32*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_21: dgain_array[33*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_22: dgain_array[34*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_23: dgain_array[35*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_24: dgain_array[36*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_25: dgain_array[37*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_26: dgain_array[38*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_27: dgain_array[39*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_28: dgain_array[40*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_29: dgain_array[41*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_2A: dgain_array[42*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_2B: dgain_array[43*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_2C: dgain_array[44*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_2D: dgain_array[45*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_2E: dgain_array[46*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_2F: dgain_array[47*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_30: dgain_array[48*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_31: dgain_array[49*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_32: dgain_array[50*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_33: dgain_array[51*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_34: dgain_array[52*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_35: dgain_array[53*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_36: dgain_array[54*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_37: dgain_array[55*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_38: dgain_array[56*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_39: dgain_array[57*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_3A: dgain_array[58*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_3B: dgain_array[59*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_3C: dgain_array[60*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_3D: dgain_array[61*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_3E: dgain_array[62*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_3F: dgain_array[63*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_40: dgain_array[64*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_41: dgain_array[65*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_42: dgain_array[66*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_43: dgain_array[67*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_44: dgain_array[68*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_45: dgain_array[69*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_46: dgain_array[70*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_47: dgain_array[71*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_48: dgain_array[72*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_49: dgain_array[73*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_4A: dgain_array[74*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_4B: dgain_array[75*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_4C: dgain_array[76*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_4D: dgain_array[77*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_4E: dgain_array[78*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_4F: dgain_array[79*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_50: dgain_array[80*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_51: dgain_array[81*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_52: dgain_array[82*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_53: dgain_array[83*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_54: dgain_array[84*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_55: dgain_array[85*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_56: dgain_array[86*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_57: dgain_array[87*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_58: dgain_array[88*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_59: dgain_array[89*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_5A: dgain_array[90*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_5B: dgain_array[91*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_5C: dgain_array[92*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_5D: dgain_array[93*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_5E: dgain_array[94*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_5F: dgain_array[95*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_60: dgain_array[96*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_61: dgain_array[97*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_62: dgain_array[98*8+:8] <= S_AXI_WDATA[7:0];
				REG_DGAIN_ARRAY_63: dgain_array[99*8+:8] <= S_AXI_WDATA[7:0];
				// BNR
				REG_BNR_SK_R_00: {bnr_space_kernel_r[(5*0+3)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_r[(5*0+2)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_r[(5*0+1)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_r[(5*0+0)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]} <= S_AXI_WDATA;
				REG_BNR_SK_R_04:  bnr_space_kernel_r[(5*0+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[BNR_WEIGHT_BITS-1:0];
				REG_BNR_SK_R_10: {bnr_space_kernel_r[(5*1+3)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_r[(5*1+2)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_r[(5*1+1)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_r[(5*1+0)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]} <= S_AXI_WDATA;
				REG_BNR_SK_R_14:  bnr_space_kernel_r[(5*1+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[BNR_WEIGHT_BITS-1:0];
				REG_BNR_SK_R_20: {bnr_space_kernel_r[(5*2+3)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_r[(5*2+2)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_r[(5*2+1)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_r[(5*2+0)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]} <= S_AXI_WDATA;
				REG_BNR_SK_R_24:  bnr_space_kernel_r[(5*2+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[BNR_WEIGHT_BITS-1:0];
				REG_BNR_SK_R_30: {bnr_space_kernel_r[(5*3+3)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_r[(5*3+2)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_r[(5*3+1)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_r[(5*3+0)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]} <= S_AXI_WDATA;
				REG_BNR_SK_R_34:  bnr_space_kernel_r[(5*3+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[BNR_WEIGHT_BITS-1:0];
				REG_BNR_SK_R_40: {bnr_space_kernel_r[(5*4+3)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_r[(5*4+2)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_r[(5*4+1)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_r[(5*4+0)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]} <= S_AXI_WDATA;
				REG_BNR_SK_R_44:  bnr_space_kernel_r[(5*4+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[BNR_WEIGHT_BITS-1:0];
				
				REG_BNR_SK_G_00: {bnr_space_kernel_g[(5*0+3)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_g[(5*0+2)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_g[(5*0+1)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_g[(5*0+0)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]} <= S_AXI_WDATA;
				REG_BNR_SK_G_04:  bnr_space_kernel_g[(5*0+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[BNR_WEIGHT_BITS-1:0];
				REG_BNR_SK_G_10: {bnr_space_kernel_g[(5*1+3)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_g[(5*1+2)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_g[(5*1+1)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_g[(5*1+0)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]} <= S_AXI_WDATA;
				REG_BNR_SK_G_14:  bnr_space_kernel_g[(5*1+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[BNR_WEIGHT_BITS-1:0];
				REG_BNR_SK_G_20: {bnr_space_kernel_g[(5*2+3)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_g[(5*2+2)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_g[(5*2+1)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_g[(5*2+0)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]} <= S_AXI_WDATA;
				REG_BNR_SK_G_24:  bnr_space_kernel_g[(5*2+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[BNR_WEIGHT_BITS-1:0];
				REG_BNR_SK_G_30: {bnr_space_kernel_g[(5*3+3)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_g[(5*3+2)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_g[(5*3+1)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_g[(5*3+0)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]} <= S_AXI_WDATA;
				REG_BNR_SK_G_34:  bnr_space_kernel_g[(5*3+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[BNR_WEIGHT_BITS-1:0];
				REG_BNR_SK_G_40: {bnr_space_kernel_g[(5*4+3)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_g[(5*4+2)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_g[(5*4+1)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_g[(5*4+0)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]} <= S_AXI_WDATA;
				REG_BNR_SK_G_44:  bnr_space_kernel_g[(5*4+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[BNR_WEIGHT_BITS-1:0];
				
				REG_BNR_SK_B_00: {bnr_space_kernel_b[(5*0+3)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_b[(5*0+2)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_b[(5*0+1)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_b[(5*0+0)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]} <= S_AXI_WDATA;
				REG_BNR_SK_B_04:  bnr_space_kernel_b[(5*0+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[BNR_WEIGHT_BITS-1:0];
				REG_BNR_SK_B_10: {bnr_space_kernel_b[(5*1+3)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_b[(5*1+2)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_b[(5*1+1)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_b[(5*1+0)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]} <= S_AXI_WDATA;
				REG_BNR_SK_B_14:  bnr_space_kernel_b[(5*1+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[BNR_WEIGHT_BITS-1:0];
				REG_BNR_SK_B_20: {bnr_space_kernel_b[(5*2+3)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_b[(5*2+2)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_b[(5*2+1)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_b[(5*2+0)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]} <= S_AXI_WDATA;
				REG_BNR_SK_B_24:  bnr_space_kernel_b[(5*2+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[BNR_WEIGHT_BITS-1:0];
				REG_BNR_SK_B_30: {bnr_space_kernel_b[(5*3+3)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_b[(5*3+2)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_b[(5*3+1)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_b[(5*3+0)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]} <= S_AXI_WDATA;
				REG_BNR_SK_B_34:  bnr_space_kernel_b[(5*3+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[BNR_WEIGHT_BITS-1:0];
				REG_BNR_SK_B_40: {bnr_space_kernel_b[(5*4+3)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_b[(5*4+2)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_b[(5*4+1)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], bnr_space_kernel_b[(5*4+0)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]} <= S_AXI_WDATA;
				REG_BNR_SK_B_44:  bnr_space_kernel_b[(5*4+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[BNR_WEIGHT_BITS-1:0];
				
				REG_BNR_CC_R_0: begin 
					bnr_color_curve_x_r[0*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_r[0*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end
				REG_BNR_CC_R_1: begin
					bnr_color_curve_x_r[1*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_r[1*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end
				REG_BNR_CC_R_2: begin
					bnr_color_curve_x_r[2*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_r[2*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end
				REG_BNR_CC_R_3: begin
					bnr_color_curve_x_r[3*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_r[3*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end 
				REG_BNR_CC_R_4: begin
					bnr_color_curve_x_r[4*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_r[4*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end 
				REG_BNR_CC_R_5: begin
					bnr_color_curve_x_r[5*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_r[5*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end 
				REG_BNR_CC_R_6: begin
					bnr_color_curve_x_r[6*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_r[6*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end 
				REG_BNR_CC_R_7: begin
					bnr_color_curve_x_r[7*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_r[7*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end 
				REG_BNR_CC_R_8: begin
					bnr_color_curve_x_r[8*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_r[8*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end 
				
				REG_BNR_CC_G_0: begin
					bnr_color_curve_x_g[0*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_g[0*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end
				REG_BNR_CC_G_1: begin
					bnr_color_curve_x_g[1*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_g[1*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end
				REG_BNR_CC_G_2: begin
					bnr_color_curve_x_g[2*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_g[2*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end
				REG_BNR_CC_G_3: begin
					bnr_color_curve_x_g[3*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_g[3*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end
				REG_BNR_CC_G_4: begin
					bnr_color_curve_x_g[4*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_g[4*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end
				REG_BNR_CC_G_5: begin
					bnr_color_curve_x_g[5*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_g[5*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end
				REG_BNR_CC_G_6: begin
					bnr_color_curve_x_g[6*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_g[6*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end
				REG_BNR_CC_G_7: begin
					bnr_color_curve_x_g[7*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_g[7*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end
				REG_BNR_CC_G_8: begin
					bnr_color_curve_x_g[8*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_g[8*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end
				
				REG_BNR_CC_B_0: begin
					bnr_color_curve_x_b[0*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_b[0*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end
				REG_BNR_CC_B_1: begin
					bnr_color_curve_x_b[1*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_b[1*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end
				REG_BNR_CC_B_2: begin
					bnr_color_curve_x_b[2*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_b[2*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end
				REG_BNR_CC_B_3: begin
					bnr_color_curve_x_b[3*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_b[3*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end
				REG_BNR_CC_B_4: begin
					bnr_color_curve_x_b[4*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_b[4*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end
				REG_BNR_CC_B_5: begin
					bnr_color_curve_x_b[5*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_b[5*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end
				REG_BNR_CC_B_6: begin
					bnr_color_curve_x_b[6*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_b[6*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end
				REG_BNR_CC_B_7: begin
					bnr_color_curve_x_b[7*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_b[7*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end
				REG_BNR_CC_B_8: begin
					bnr_color_curve_x_b[8*BITS+:BITS] <= S_AXI_WDATA[15:0];
					bnr_color_curve_y_b[8*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS] <= S_AXI_WDATA[31:16];
				end
				// WB
				REG_WB_RGAIN: wb_rgain <= S_AXI_WDATA[11:0];
				REG_WB_BGAIN: wb_bgain <= S_AXI_WDATA[11:0];
				// CCM
				REG_CCM_RR: ccm_rr <= S_AXI_WDATA[15:0];
				REG_CCM_RG: ccm_rg <= S_AXI_WDATA[15:0];
				REG_CCM_RB: ccm_rb <= S_AXI_WDATA[15:0];
				REG_CCM_GR: ccm_gr <= S_AXI_WDATA[15:0];
				REG_CCM_GG: ccm_gg <= S_AXI_WDATA[15:0];
				REG_CCM_GB: ccm_gb <= S_AXI_WDATA[15:0];
				REG_CCM_BR: ccm_br <= S_AXI_WDATA[15:0];
				REG_CCM_BG: ccm_bg <= S_AXI_WDATA[15:0];
				REG_CCM_BB: ccm_bb <= S_AXI_WDATA[15:0];
				// CSC
				REG_CSC_CONV_STD: in_conv_standard <= S_AXI_WDATA[1:0];
				// SHARP
				REG_SHARP_STRENGTH:	sharpen_strength <= S_AXI_WDATA[11:0];
				REG_SHARP_KERNEL_00: luma_kernel[(0*9+0)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_01: luma_kernel[(0*9+1)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_02: luma_kernel[(0*9+2)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_03: luma_kernel[(0*9+3)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_04: luma_kernel[(0*9+4)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_05: luma_kernel[(0*9+5)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_06: luma_kernel[(0*9+6)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_07: luma_kernel[(0*9+7)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_08: luma_kernel[(0*9+8)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_10: luma_kernel[(1*9+0)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_11: luma_kernel[(1*9+1)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_12: luma_kernel[(1*9+2)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_13: luma_kernel[(1*9+3)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_14: luma_kernel[(1*9+4)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_15: luma_kernel[(1*9+5)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_16: luma_kernel[(1*9+6)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_17: luma_kernel[(1*9+7)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_18: luma_kernel[(1*9+8)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_20: luma_kernel[(2*9+0)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_21: luma_kernel[(2*9+1)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_22: luma_kernel[(2*9+2)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_23: luma_kernel[(2*9+3)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_24: luma_kernel[(2*9+4)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_25: luma_kernel[(2*9+5)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_26: luma_kernel[(2*9+6)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_27: luma_kernel[(2*9+7)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_28: luma_kernel[(2*9+8)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_30: luma_kernel[(3*9+0)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_31: luma_kernel[(3*9+1)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_32: luma_kernel[(3*9+2)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_33: luma_kernel[(3*9+3)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_34: luma_kernel[(3*9+4)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_35: luma_kernel[(3*9+5)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_36: luma_kernel[(3*9+6)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_37: luma_kernel[(3*9+7)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_38: luma_kernel[(3*9+8)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_40: luma_kernel[(4*9+0)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_41: luma_kernel[(4*9+1)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_42: luma_kernel[(4*9+2)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_43: luma_kernel[(4*9+3)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_44: luma_kernel[(4*9+4)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_45: luma_kernel[(4*9+5)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_46: luma_kernel[(4*9+6)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_47: luma_kernel[(4*9+7)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_48: luma_kernel[(4*9+8)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_50: luma_kernel[(5*9+0)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_51: luma_kernel[(5*9+1)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_52: luma_kernel[(5*9+2)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_53: luma_kernel[(5*9+3)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_54: luma_kernel[(5*9+4)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_55: luma_kernel[(5*9+5)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_56: luma_kernel[(5*9+6)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_57: luma_kernel[(5*9+7)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_58: luma_kernel[(5*9+8)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_60: luma_kernel[(6*9+0)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_61: luma_kernel[(6*9+1)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_62: luma_kernel[(6*9+2)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_63: luma_kernel[(6*9+3)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_64: luma_kernel[(6*9+4)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_65: luma_kernel[(6*9+5)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_66: luma_kernel[(6*9+6)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_67: luma_kernel[(6*9+7)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_68: luma_kernel[(6*9+8)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_70: luma_kernel[(7*9+0)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_71: luma_kernel[(7*9+1)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_72: luma_kernel[(7*9+2)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_73: luma_kernel[(7*9+3)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_74: luma_kernel[(7*9+4)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_75: luma_kernel[(7*9+5)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_76: luma_kernel[(7*9+6)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_77: luma_kernel[(7*9+7)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_78: luma_kernel[(7*9+8)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_80: luma_kernel[(8*9+0)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_81: luma_kernel[(8*9+1)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_82: luma_kernel[(8*9+2)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_83: luma_kernel[(8*9+3)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_84: luma_kernel[(8*9+4)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_85: luma_kernel[(8*9+5)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_86: luma_kernel[(8*9+6)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_87: luma_kernel[(8*9+7)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
				REG_SHARP_KERNEL_88: luma_kernel[(8*9+8)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS] <= S_AXI_WDATA[SHARP_WEIGHT_BITS-1:0];
                // 2DNR
                REG_2DNR_DIFF_00: nr2d_diff[0*8*4+:32] <= S_AXI_WDATA;
                REG_2DNR_DIFF_04: nr2d_diff[1*8*4+:32] <= S_AXI_WDATA;
                REG_2DNR_DIFF_08: nr2d_diff[2*8*4+:32] <= S_AXI_WDATA;
                REG_2DNR_DIFF_0C: nr2d_diff[3*8*4+:32] <= S_AXI_WDATA;
                REG_2DNR_DIFF_10: nr2d_diff[4*8*4+:32] <= S_AXI_WDATA;
                REG_2DNR_DIFF_14: nr2d_diff[5*8*4+:32] <= S_AXI_WDATA;
                REG_2DNR_DIFF_18: nr2d_diff[6*8*4+:32] <= S_AXI_WDATA;
                REG_2DNR_DIFF_1C: nr2d_diff[7*8*4+:32] <= S_AXI_WDATA;
                REG_2DNR_WEIGHT_00: nr2d_weight[0*NR2D_WEIGHT_BITS*4+:4*NR2D_WEIGHT_BITS] <= {S_AXI_WDATA[(3*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(2*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(1*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(0*8)+:NR2D_WEIGHT_BITS]};
                REG_2DNR_WEIGHT_04: nr2d_weight[1*NR2D_WEIGHT_BITS*4+:4*NR2D_WEIGHT_BITS] <= {S_AXI_WDATA[(3*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(2*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(1*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(0*8)+:NR2D_WEIGHT_BITS]};
                REG_2DNR_WEIGHT_08: nr2d_weight[2*NR2D_WEIGHT_BITS*4+:4*NR2D_WEIGHT_BITS] <= {S_AXI_WDATA[(3*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(2*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(1*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(0*8)+:NR2D_WEIGHT_BITS]};
                REG_2DNR_WEIGHT_0C: nr2d_weight[3*NR2D_WEIGHT_BITS*4+:4*NR2D_WEIGHT_BITS] <= {S_AXI_WDATA[(3*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(2*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(1*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(0*8)+:NR2D_WEIGHT_BITS]};
                REG_2DNR_WEIGHT_10: nr2d_weight[4*NR2D_WEIGHT_BITS*4+:4*NR2D_WEIGHT_BITS] <= {S_AXI_WDATA[(3*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(2*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(1*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(0*8)+:NR2D_WEIGHT_BITS]};
                REG_2DNR_WEIGHT_14: nr2d_weight[5*NR2D_WEIGHT_BITS*4+:4*NR2D_WEIGHT_BITS] <= {S_AXI_WDATA[(3*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(2*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(1*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(0*8)+:NR2D_WEIGHT_BITS]};
                REG_2DNR_WEIGHT_18: nr2d_weight[6*NR2D_WEIGHT_BITS*4+:4*NR2D_WEIGHT_BITS] <= {S_AXI_WDATA[(3*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(2*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(1*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(0*8)+:NR2D_WEIGHT_BITS]};
                REG_2DNR_WEIGHT_1C: nr2d_weight[7*NR2D_WEIGHT_BITS*4+:4*NR2D_WEIGHT_BITS] <= {S_AXI_WDATA[(3*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(2*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(1*8)+:NR2D_WEIGHT_BITS], S_AXI_WDATA[(0*8)+:NR2D_WEIGHT_BITS]};
                
//				REG_STAT_AE_RECT_X: stat_ae_rect_x <= S_AXI_WDATA[15:0];
//				REG_STAT_AE_RECT_Y: stat_ae_rect_y <= S_AXI_WDATA[15:0];
//				REG_STAT_AE_RECT_W: stat_ae_rect_w <= S_AXI_WDATA[15:0];
//				REG_STAT_AE_RECT_H: stat_ae_rect_h <= S_AXI_WDATA[15:0];
//				REG_STAT_AE_PIX_CNT_L:;
//				REG_STAT_AE_PIX_CNT_H:;
//				REG_STAT_AE_SUM_L:;
//				REG_STAT_AE_SUM_H:;
                // AE
                REG_AE_CENTER_ILLUMINANCE: center_illuminance <= S_AXI_WDATA[7:0];
                REG_AE_SKEWNESS: skewness <= S_AXI_WDATA[15:0];
				REG_AE_CROP_LEFT: ae_crop_left <= S_AXI_WDATA[11:0];
				REG_AE_CROP_RIGHT: ae_crop_right <= S_AXI_WDATA[11:0];
				REG_AE_CROP_TOP: ae_crop_top <= S_AXI_WDATA[11:0];
				REG_AE_CROP_BOTTOM: ae_crop_bottom <= S_AXI_WDATA[11:0];
				// AWB
				REG_AWB_UNDEREXPOSED_LIMIT: awb_underexposed_limit <= S_AXI_WDATA[BITS-1:0];
				REG_AWB_OVEREXPOSED_LIMIT: awb_overexposed_limit <= S_AXI_WDATA[BITS-1:0];
				REG_AWB_FRAMES: awb_frames <= S_AXI_WDATA[BITS-1:0];
				// VIP1_CONFIG
				REG_VIP1_RESET: vip1_module_reset <= S_AXI_WDATA[0];
				REG_VIP1_WIDTH: ;
				REG_VIP1_HEIGHT: ;
				REG_VIP1_BITS: ;
				REG_VIP1_TOP_EN: {vip1_yuv444to422_en, vip1_osd_en, vip1_dscale_en, vip1_crop_en, vip1_yuv2rgb_en/*, sobel_en, hist_equ_en*/} <= S_AXI_WDATA[4:0];
				REG_VIP1_INT_STATUS: {int_vip1_frame_done, int_vip1_frame_start} <= 2'd0;
				REG_VIP1_INT_MASK: {int_vip1_mask_frame_done,int_vip1_mask_frame_start} <= S_AXI_WDATA[1:0];
                // RGBC
                REG_VIP1_RGBC_CONV_STD: vip1_vip_in_conv_standard <= S_AXI_WDATA[1:0];
				// IRC
				REG_VIP1_IRC_X: vip1_crop_x <= S_AXI_WDATA[15:0];
				REG_VIP1_IRC_Y: vip1_crop_y <= S_AXI_WDATA[15:0];
				REG_VIP1_IRC_OUTPUT: vip1_irc_output <= S_AXI_WDATA[1:0];
				// SCALE
				REG_VIP1_SCALE_IN_CROP_W: vip1_s_in_crop_w <= S_AXI_WDATA[11:0];
				REG_VIP1_SCALE_IN_CROP_H: vip1_s_in_crop_h <= S_AXI_WDATA[11:0];
				REG_VIP1_SCALE_OUT_CROP_W: vip1_s_out_crop_w <= S_AXI_WDATA[11:0];
				REG_VIP1_SCALE_OUT_CROP_H: vip1_s_out_crop_h <= S_AXI_WDATA[11:0];
				REG_VIP1_SCALE_DSCALE_W: vip1_dscale_w <= S_AXI_WDATA[2:0];
				REG_VIP1_SCALE_DSCALE_H: vip1_dscale_h <= S_AXI_WDATA[2:0];
				// OSD
				REG_VIP1_OSD_X: vip1_osd_x <= S_AXI_WDATA[15:0];
				REG_VIP1_OSD_Y: vip1_osd_y <= S_AXI_WDATA[15:0];
				REG_VIP1_OSD_W: vip1_osd_w <= S_AXI_WDATA[15:0];
				REG_VIP1_OSD_H: vip1_osd_h <= S_AXI_WDATA[15:0];
				REG_VIP1_OSD_COLOR_FG: vip1_osd_color_fg <= S_AXI_WDATA[24:0];
				REG_VIP1_OSD_COLOR_BG: vip1_osd_color_bg <= S_AXI_WDATA[24:0];
				REG_VIP1_ALPHA : vip1_alpha <= S_AXI_WDATA[7:0];
				// vip1_YUV444TO422
				REG_VIP1_YUV_YUV444TO422: vip1_YUV444TO422 <= S_AXI_WDATA[0];
				// VIP2_CONFIG
				REG_VIP2_RESET: vip2_module_reset <= S_AXI_WDATA[0];
				REG_VIP2_WIDTH: ;
				REG_VIP2_HEIGHT: ;
				REG_VIP2_BITS: ;
				REG_VIP2_TOP_EN: {vip2_yuv444to422_en, vip2_osd_en, vip2_dscale_en, vip2_crop_en, vip2_yuv2rgb_en/*, sobel_en, hist_equ_en*/} <= S_AXI_WDATA[4:0];
				REG_VIP2_INT_STATUS: {int_vip2_frame_done, int_vip2_frame_start} <= 2'd0;
				REG_VIP2_INT_MASK: {int_vip2_mask_frame_done,int_vip2_mask_frame_start} <= S_AXI_WDATA[1:0];
				// RGBC
                REG_VIP2_RGBC_CONV_STD: vip2_vip_in_conv_standard <= S_AXI_WDATA[1:0];
				// IRC
				REG_VIP2_IRC_X: vip2_crop_x <= S_AXI_WDATA[15:0];
				REG_VIP2_IRC_Y: vip2_crop_y <= S_AXI_WDATA[15:0];
				REG_VIP2_IRC_OUTPUT: vip2_irc_output <= S_AXI_WDATA[1:0];
				// SCALE
				REG_VIP2_SCALE_IN_CROP_W: vip2_s_in_crop_w <= S_AXI_WDATA[11:0];
				REG_VIP2_SCALE_IN_CROP_H: vip2_s_in_crop_h <= S_AXI_WDATA[11:0];
				REG_VIP2_SCALE_OUT_CROP_W: vip2_s_out_crop_w <= S_AXI_WDATA[11:0];
				REG_VIP2_SCALE_OUT_CROP_H: vip2_s_out_crop_h <= S_AXI_WDATA[11:0];
				REG_VIP2_SCALE_DSCALE_W: vip2_dscale_w <= S_AXI_WDATA[2:0];
				REG_VIP2_SCALE_DSCALE_H: vip2_dscale_h <= S_AXI_WDATA[2:0];
				// OSD
				REG_VIP2_OSD_X: vip2_osd_x <= S_AXI_WDATA[15:0];
				REG_VIP2_OSD_Y: vip2_osd_y <= S_AXI_WDATA[15:0];
				REG_VIP2_OSD_W: vip2_osd_w <= S_AXI_WDATA[15:0];
				REG_VIP2_OSD_H: vip2_osd_h <= S_AXI_WDATA[15:0];
				REG_VIP2_OSD_COLOR_FG: vip2_osd_color_fg <= S_AXI_WDATA[24:0];
				REG_VIP2_OSD_COLOR_BG: vip2_osd_color_bg <= S_AXI_WDATA[24:0];
				REG_VIP2_ALPHA : vip2_alpha <= S_AXI_WDATA[7:0];

				// vip2_YUV444TO422
				REG_VIP2_YUV_YUV444TO422: vip2_YUV444TO422 <= S_AXI_WDATA[0];
				
				REG_INT_STATUS: {int_awb_done, int_ae_done, int_isp_frame_done, int_isp_frame_start} <= 4'd0;
				REG_INT_MASK: {int_mask_awb_done, int_mask_ae_done, int_isp_mask_frame_done, int_isp_mask_frame_start} <= S_AXI_WDATA[3:0];
				 default: ;
	        endcase
	      end
		if (isp_frame_start) int_isp_frame_start <= 1'b1;
		if (isp_frame_done) int_isp_frame_done <= 1'b1;
		if (stat_ae_done) int_ae_done <= 1'b1;
		if (vip1_frame_start) int_vip1_frame_start <= 1'b1;
		if (vip1_frame_done) int_vip1_frame_done <= 1'b1;
		if (vip2_frame_start) int_vip2_frame_start <= 1'b1;
		if (vip2_frame_done) int_vip2_frame_done <= 1'b1;
//		if (stat_awb_done) int_awb_done <= 1'b1;
	  end
	end    

	// Implement write response logic generation
	// The write response and response valid signals are asserted by the slave 
	// when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
	// This marks the acceptance of address and indicates the status of 
	// write transaction.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_bvalid  <= 0;
	      axi_bresp   <= 2'b0;
	    end 
	  else
	    begin    
	      if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
	        begin
	          // indicates a valid write response is available
	          axi_bvalid <= 1'b1;
	          axi_bresp  <= 2'b0; // 'OKAY' response 
	        end                   // work error responses in future
	      else
	        begin
	          if (S_AXI_BREADY && axi_bvalid) 
	            //check if bready is asserted while bvalid is high) 
	            //(there is a possibility that bready is always asserted high)   
	            begin
	              axi_bvalid <= 1'b0; 
	            end  
	        end
	    end
	end   

	// Implement axi_arready generation
	// axi_arready is asserted for one S_AXI_ACLK clock cycle when
	// S_AXI_ARVALID is asserted. axi_awready is 
	// de-asserted when reset (active low) is asserted. 
	// The read address is also latched when S_AXI_ARVALID is 
	// asserted. axi_araddr is reset to zero on reset assertion.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_arready <= 1'b0;
	      axi_araddr  <= 32'b0;
	    end 
	  else
	    begin    
	      if (~axi_arready && S_AXI_ARVALID)
	        begin
	          // indicates that the slave has acceped the valid read address
	          axi_arready <= 1'b1;
	          // Read address latching
	          axi_araddr  <= S_AXI_ARADDR;
	        end
	      else
	        begin
	          axi_arready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_arvalid generation
	// axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
	// S_AXI_ARVALID and axi_arready are asserted. The slave registers 
	// data are available on the axi_rdata bus at this instance. The 
	// assertion of axi_rvalid marks the validity of read data on the 
	// bus and axi_rresp indicates the status of read transaction.axi_rvalid 
	// is deasserted on reset (active low). axi_rresp and axi_rdata are 
	// cleared to zero on reset (active low).  
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rvalid <= 0;
	      axi_rresp  <= 0;
	    end 
	  else
	    begin    
	      if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
	        begin
	          // Valid read data is available at the read data bus
	          axi_rvalid <= 1'b1;
	          axi_rresp  <= 2'b0; // 'OKAY' response
	        end   
	      else if (axi_rvalid && S_AXI_RREADY)
	        begin
	          // Read data is accepted by the master
	          axi_rvalid <= 1'b0;
	        end                
	    end
	end    

	// Implement memory mapped register select and read logic generation
	// Slave register read enable is asserted when valid address is available
	// and the slave is ready to accept the read address.
	assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
	always @(*)
	begin
	      // Address decoding for reading registers
	      case ( axi_araddr[ADDR_LSB+MODULE_ID_BITS+REG_ID_BITS-1:ADDR_LSB])
	        // AXI Read Logic for Module Registers
			REG_RESET: reg_data_out = {31'd0, module_reset};
			REG_SNS_WIDTH: reg_data_out = SNS_WIDTH;
			REG_SNS_HEIGHT: reg_data_out = SNS_HEIGHT;
			REG_CROP_WIDTH: reg_data_out = CROP_WIDTH;
			REG_CROP_HEIGHT: reg_data_out = CROP_HEIGHT;
			REG_BITS: reg_data_out = BITS;
			REG_BAYER: reg_data_out = BAYER;
			// Module Enables
			REG_TOP_EN: reg_data_out = {14'd0, crop_en, awb_en, ae_en, sharp_en, nr2d_en, ldci_en, csc_en, gamma_en, ccm_en, demosic_en, wb_en, bnr_en, lsc_en, dgain_en, oecf_en, linear_en, blc_en, dpc_en}; //TODO:
			// DPC
			REG_DPC_THRESHOLD: reg_data_out = dpc_threshold;
			// BLC
			REG_BLC_R: reg_data_out = blc_r;
			REG_BLC_GR: reg_data_out = blc_gr;
			REG_BLC_GB: reg_data_out = blc_gb;
			REG_BLC_B: reg_data_out = blc_b;
			REG_LINEAR_R: reg_data_out = linear_r;
			REG_LINEAR_GR: reg_data_out = linear_gr;
			REG_LINEAR_GB: reg_data_out = linear_gb;
			REG_LINEAR_B: reg_data_out = linear_b;
			// DG
			REG_DGAIN_ISMANUAL: reg_data_out = {31'd0, dgain_isManual};
			REG_DGAIN_MAN_INDEX: reg_data_out = {28'd0, dgain_man_index};
			REG_DGAIN_INDEX_OUT: reg_data_out = {28'd0, dgain_index_out};
            REG_DGAIN_ARRAY_00: reg_data_out = dgain_array[ 0*8+:8];
            REG_DGAIN_ARRAY_01: reg_data_out = dgain_array[ 1*8+:8];
            REG_DGAIN_ARRAY_02: reg_data_out = dgain_array[ 2*8+:8];
            REG_DGAIN_ARRAY_03: reg_data_out = dgain_array[ 3*8+:8];
            REG_DGAIN_ARRAY_04: reg_data_out = dgain_array[ 4*8+:8];
            REG_DGAIN_ARRAY_05: reg_data_out = dgain_array[ 5*8+:8];
            REG_DGAIN_ARRAY_06: reg_data_out = dgain_array[ 6*8+:8];
            REG_DGAIN_ARRAY_07: reg_data_out = dgain_array[ 7*8+:8];
            REG_DGAIN_ARRAY_08: reg_data_out = dgain_array[ 8*8+:8];
            REG_DGAIN_ARRAY_09: reg_data_out = dgain_array[ 9*8+:8];
            REG_DGAIN_ARRAY_0A: reg_data_out = dgain_array[10*8+:8];
            REG_DGAIN_ARRAY_0B: reg_data_out = dgain_array[11*8+:8];
            REG_DGAIN_ARRAY_0C: reg_data_out = dgain_array[12*8+:8];
            REG_DGAIN_ARRAY_0D: reg_data_out = dgain_array[13*8+:8];
            REG_DGAIN_ARRAY_0E: reg_data_out = dgain_array[14*8+:8];
            REG_DGAIN_ARRAY_0F: reg_data_out = dgain_array[15*8+:8];
            REG_DGAIN_ARRAY_10: reg_data_out = dgain_array[16*8+:8];
            REG_DGAIN_ARRAY_11: reg_data_out = dgain_array[17*8+:8];
            REG_DGAIN_ARRAY_12: reg_data_out = dgain_array[18*8+:8];
            REG_DGAIN_ARRAY_13: reg_data_out = dgain_array[19*8+:8];
            REG_DGAIN_ARRAY_14: reg_data_out = dgain_array[20*8+:8];
            REG_DGAIN_ARRAY_15: reg_data_out = dgain_array[21*8+:8];
            REG_DGAIN_ARRAY_16: reg_data_out = dgain_array[22*8+:8];
            REG_DGAIN_ARRAY_17: reg_data_out = dgain_array[23*8+:8];
            REG_DGAIN_ARRAY_18: reg_data_out = dgain_array[24*8+:8];
            REG_DGAIN_ARRAY_19: reg_data_out = dgain_array[25*8+:8];
            REG_DGAIN_ARRAY_1A: reg_data_out = dgain_array[26*8+:8];
            REG_DGAIN_ARRAY_1B: reg_data_out = dgain_array[27*8+:8];
            REG_DGAIN_ARRAY_1C: reg_data_out = dgain_array[28*8+:8];
            REG_DGAIN_ARRAY_1D: reg_data_out = dgain_array[29*8+:8];
            REG_DGAIN_ARRAY_1E: reg_data_out = dgain_array[30*8+:8];
            REG_DGAIN_ARRAY_1F: reg_data_out = dgain_array[31*8+:8];
            REG_DGAIN_ARRAY_20: reg_data_out = dgain_array[32*8+:8];
            REG_DGAIN_ARRAY_21: reg_data_out = dgain_array[33*8+:8];
            REG_DGAIN_ARRAY_22: reg_data_out = dgain_array[34*8+:8];
            REG_DGAIN_ARRAY_23: reg_data_out = dgain_array[35*8+:8];
            REG_DGAIN_ARRAY_24: reg_data_out = dgain_array[36*8+:8];
            REG_DGAIN_ARRAY_25: reg_data_out = dgain_array[37*8+:8];
            REG_DGAIN_ARRAY_26: reg_data_out = dgain_array[38*8+:8];
            REG_DGAIN_ARRAY_27: reg_data_out = dgain_array[39*8+:8];
            REG_DGAIN_ARRAY_28: reg_data_out = dgain_array[40*8+:8];
            REG_DGAIN_ARRAY_29: reg_data_out = dgain_array[41*8+:8];
            REG_DGAIN_ARRAY_2A: reg_data_out = dgain_array[42*8+:8];
            REG_DGAIN_ARRAY_2B: reg_data_out = dgain_array[43*8+:8];
            REG_DGAIN_ARRAY_2C: reg_data_out = dgain_array[44*8+:8];
            REG_DGAIN_ARRAY_2D: reg_data_out = dgain_array[45*8+:8];
            REG_DGAIN_ARRAY_2E: reg_data_out = dgain_array[46*8+:8];
            REG_DGAIN_ARRAY_2F: reg_data_out = dgain_array[47*8+:8];
            REG_DGAIN_ARRAY_30: reg_data_out = dgain_array[48*8+:8];
            REG_DGAIN_ARRAY_31: reg_data_out = dgain_array[49*8+:8];
            REG_DGAIN_ARRAY_32: reg_data_out = dgain_array[50*8+:8];
            REG_DGAIN_ARRAY_33: reg_data_out = dgain_array[51*8+:8];
            REG_DGAIN_ARRAY_34: reg_data_out = dgain_array[52*8+:8];
            REG_DGAIN_ARRAY_35: reg_data_out = dgain_array[53*8+:8];
            REG_DGAIN_ARRAY_36: reg_data_out = dgain_array[54*8+:8];
            REG_DGAIN_ARRAY_37: reg_data_out = dgain_array[55*8+:8];
            REG_DGAIN_ARRAY_38: reg_data_out = dgain_array[56*8+:8];
            REG_DGAIN_ARRAY_39: reg_data_out = dgain_array[57*8+:8];
            REG_DGAIN_ARRAY_3A: reg_data_out = dgain_array[58*8+:8];
            REG_DGAIN_ARRAY_3B: reg_data_out = dgain_array[59*8+:8];
            REG_DGAIN_ARRAY_3C: reg_data_out = dgain_array[60*8+:8];
            REG_DGAIN_ARRAY_3D: reg_data_out = dgain_array[61*8+:8];
            REG_DGAIN_ARRAY_3E: reg_data_out = dgain_array[62*8+:8];
            REG_DGAIN_ARRAY_3F: reg_data_out = dgain_array[63*8+:8];
            REG_DGAIN_ARRAY_40: reg_data_out = dgain_array[64*8+:8];
            REG_DGAIN_ARRAY_41: reg_data_out = dgain_array[65*8+:8];
            REG_DGAIN_ARRAY_42: reg_data_out = dgain_array[66*8+:8];
            REG_DGAIN_ARRAY_43: reg_data_out = dgain_array[67*8+:8];
            REG_DGAIN_ARRAY_44: reg_data_out = dgain_array[68*8+:8];
            REG_DGAIN_ARRAY_45: reg_data_out = dgain_array[69*8+:8];
            REG_DGAIN_ARRAY_46: reg_data_out = dgain_array[70*8+:8];
            REG_DGAIN_ARRAY_47: reg_data_out = dgain_array[71*8+:8];
            REG_DGAIN_ARRAY_48: reg_data_out = dgain_array[72*8+:8];
            REG_DGAIN_ARRAY_49: reg_data_out = dgain_array[73*8+:8];
            REG_DGAIN_ARRAY_4A: reg_data_out = dgain_array[74*8+:8];
            REG_DGAIN_ARRAY_4B: reg_data_out = dgain_array[75*8+:8];
            REG_DGAIN_ARRAY_4C: reg_data_out = dgain_array[76*8+:8];
            REG_DGAIN_ARRAY_4D: reg_data_out = dgain_array[77*8+:8];
            REG_DGAIN_ARRAY_4E: reg_data_out = dgain_array[78*8+:8];
            REG_DGAIN_ARRAY_4F: reg_data_out = dgain_array[79*8+:8];
            REG_DGAIN_ARRAY_50: reg_data_out = dgain_array[80*8+:8];
            REG_DGAIN_ARRAY_51: reg_data_out = dgain_array[81*8+:8];
            REG_DGAIN_ARRAY_52: reg_data_out = dgain_array[82*8+:8];
            REG_DGAIN_ARRAY_53: reg_data_out = dgain_array[83*8+:8];
            REG_DGAIN_ARRAY_54: reg_data_out = dgain_array[84*8+:8];
            REG_DGAIN_ARRAY_55: reg_data_out = dgain_array[85*8+:8];
            REG_DGAIN_ARRAY_56: reg_data_out = dgain_array[86*8+:8];
            REG_DGAIN_ARRAY_57: reg_data_out = dgain_array[87*8+:8];
            REG_DGAIN_ARRAY_58: reg_data_out = dgain_array[88*8+:8];
            REG_DGAIN_ARRAY_59: reg_data_out = dgain_array[89*8+:8];
            REG_DGAIN_ARRAY_5A: reg_data_out = dgain_array[90*8+:8];
            REG_DGAIN_ARRAY_5B: reg_data_out = dgain_array[91*8+:8];
            REG_DGAIN_ARRAY_5C: reg_data_out = dgain_array[92*8+:8];
            REG_DGAIN_ARRAY_5D: reg_data_out = dgain_array[93*8+:8];
            REG_DGAIN_ARRAY_5E: reg_data_out = dgain_array[94*8+:8];
            REG_DGAIN_ARRAY_5F: reg_data_out = dgain_array[95*8+:8];
            REG_DGAIN_ARRAY_60: reg_data_out = dgain_array[96*8+:8];
            REG_DGAIN_ARRAY_61: reg_data_out = dgain_array[97*8+:8];
            REG_DGAIN_ARRAY_62: reg_data_out = dgain_array[98*8+:8];
            REG_DGAIN_ARRAY_63: reg_data_out = dgain_array[99*8+:8];			
			// BNR
			REG_BNR_SK_R_00: reg_data_out = bnr_space_kernel_r[(5*0+0)*BNR_WEIGHT_BITS+:4*BNR_WEIGHT_BITS];
			REG_BNR_SK_R_04: reg_data_out = {24'd0,bnr_space_kernel_r[(5*0+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]};
			REG_BNR_SK_R_10: reg_data_out = bnr_space_kernel_r[(5*1+0)*BNR_WEIGHT_BITS+:4*BNR_WEIGHT_BITS];
			REG_BNR_SK_R_14: reg_data_out = {24'd0,bnr_space_kernel_r[(5*1+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]};
			REG_BNR_SK_R_20: reg_data_out = bnr_space_kernel_r[(5*2+0)*BNR_WEIGHT_BITS+:4*BNR_WEIGHT_BITS];
			REG_BNR_SK_R_24: reg_data_out = {24'd0,bnr_space_kernel_r[(5*2+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]};
			REG_BNR_SK_R_30: reg_data_out = bnr_space_kernel_r[(5*3+0)*BNR_WEIGHT_BITS+:4*BNR_WEIGHT_BITS];
			REG_BNR_SK_R_34: reg_data_out = {24'd0,bnr_space_kernel_r[(5*3+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]};
			REG_BNR_SK_R_40: reg_data_out = bnr_space_kernel_r[(5*4+0)*BNR_WEIGHT_BITS+:4*BNR_WEIGHT_BITS];
			REG_BNR_SK_R_44: reg_data_out = {24'd0,bnr_space_kernel_r[(5*4+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]};
			
			REG_BNR_SK_G_00: reg_data_out = bnr_space_kernel_g[(5*0+0)*BNR_WEIGHT_BITS+:4*BNR_WEIGHT_BITS];
			REG_BNR_SK_G_04: reg_data_out = {24'd0,bnr_space_kernel_g[(5*0+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]};
			REG_BNR_SK_G_10: reg_data_out = bnr_space_kernel_g[(5*1+0)*BNR_WEIGHT_BITS+:4*BNR_WEIGHT_BITS];
			REG_BNR_SK_G_14: reg_data_out = {24'd0,bnr_space_kernel_g[(5*1+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]};
			REG_BNR_SK_G_20: reg_data_out = bnr_space_kernel_g[(5*2+0)*BNR_WEIGHT_BITS+:4*BNR_WEIGHT_BITS];
			REG_BNR_SK_G_24: reg_data_out = {24'd0,bnr_space_kernel_g[(5*2+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]};
			REG_BNR_SK_G_30: reg_data_out = bnr_space_kernel_g[(5*3+0)*BNR_WEIGHT_BITS+:4*BNR_WEIGHT_BITS];
			REG_BNR_SK_G_34: reg_data_out = {24'd0,bnr_space_kernel_g[(5*3+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]};
			REG_BNR_SK_G_40: reg_data_out = bnr_space_kernel_g[(5*4+0)*BNR_WEIGHT_BITS+:4*BNR_WEIGHT_BITS];
			REG_BNR_SK_G_44: reg_data_out = {24'd0,bnr_space_kernel_g[(5*4+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]};
			
			REG_BNR_SK_B_00: reg_data_out = bnr_space_kernel_b[(5*0+0)*BNR_WEIGHT_BITS+:4*BNR_WEIGHT_BITS];
			REG_BNR_SK_B_04: reg_data_out = {24'd0,bnr_space_kernel_b[(5*0+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]};
			REG_BNR_SK_B_10: reg_data_out = bnr_space_kernel_b[(5*1+0)*BNR_WEIGHT_BITS+:4*BNR_WEIGHT_BITS];
			REG_BNR_SK_B_14: reg_data_out = {24'd0,bnr_space_kernel_b[(5*1+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]};
			REG_BNR_SK_B_20: reg_data_out = bnr_space_kernel_b[(5*2+0)*BNR_WEIGHT_BITS+:4*BNR_WEIGHT_BITS];
			REG_BNR_SK_B_24: reg_data_out = {24'd0,bnr_space_kernel_b[(5*2+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]};
			REG_BNR_SK_B_30: reg_data_out = bnr_space_kernel_b[(5*3+0)*BNR_WEIGHT_BITS+:4*BNR_WEIGHT_BITS];
			REG_BNR_SK_B_34: reg_data_out = {24'd0,bnr_space_kernel_b[(5*3+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]};
			REG_BNR_SK_B_40: reg_data_out = bnr_space_kernel_b[(5*4+0)*BNR_WEIGHT_BITS+:4*BNR_WEIGHT_BITS];
			REG_BNR_SK_B_44: reg_data_out = {24'd0,bnr_space_kernel_b[(5*4+4)*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS]};
			
			REG_BNR_CC_R_0: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_r[0*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_r[0*BITS+:BITS]};
			REG_BNR_CC_R_1: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_r[1*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_r[1*BITS+:BITS]};
			REG_BNR_CC_R_2: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_r[2*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_r[2*BITS+:BITS]};
			REG_BNR_CC_R_3: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_r[3*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_r[3*BITS+:BITS]};
			REG_BNR_CC_R_4: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_r[4*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_r[4*BITS+:BITS]};
			REG_BNR_CC_R_5: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_r[5*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_r[5*BITS+:BITS]};
			REG_BNR_CC_R_6: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_r[6*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_r[6*BITS+:BITS]};
			REG_BNR_CC_R_7: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_r[7*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_r[7*BITS+:BITS]};
			REG_BNR_CC_R_8: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_r[8*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_r[8*BITS+:BITS]};
			                                                                                                              
			REG_BNR_CC_G_0: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_g[0*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_g[0*BITS+:BITS]};
			REG_BNR_CC_G_1: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_g[1*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_g[1*BITS+:BITS]};
			REG_BNR_CC_G_2: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_g[2*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_g[2*BITS+:BITS]};
			REG_BNR_CC_G_3: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_g[3*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_g[3*BITS+:BITS]};
			REG_BNR_CC_G_4: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_g[4*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_g[4*BITS+:BITS]};
			REG_BNR_CC_G_5: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_g[5*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_g[5*BITS+:BITS]};
			REG_BNR_CC_G_6: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_g[6*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_g[6*BITS+:BITS]};
			REG_BNR_CC_G_7: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_g[7*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_g[7*BITS+:BITS]};
			REG_BNR_CC_G_8: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_g[8*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_g[8*BITS+:BITS]};
			                                                                                                              
			REG_BNR_CC_B_0: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_b[0*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_b[0*BITS+:BITS]};
			REG_BNR_CC_B_1: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_b[1*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_b[1*BITS+:BITS]};
			REG_BNR_CC_B_2: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_b[2*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_b[2*BITS+:BITS]};
			REG_BNR_CC_B_3: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_b[3*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_b[3*BITS+:BITS]};
			REG_BNR_CC_B_4: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_b[4*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_b[4*BITS+:BITS]};
			REG_BNR_CC_B_5: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_b[5*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_b[5*BITS+:BITS]};
			REG_BNR_CC_B_6: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_b[6*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_b[6*BITS+:BITS]};
			REG_BNR_CC_B_7: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_b[7*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_b[7*BITS+:BITS]};
			REG_BNR_CC_B_8: reg_data_out = {{(16-BNR_WEIGHT_BITS){1'b0}}, bnr_color_curve_y_b[8*BNR_WEIGHT_BITS+:BNR_WEIGHT_BITS], {(16-BITS){1'b0}}, bnr_color_curve_x_b[8*BITS+:BITS]};
			// WB
			REG_WB_RGAIN: reg_data_out = {20'd0, wb_rgain};
			REG_WB_BGAIN: reg_data_out = {20'd0, wb_bgain};
			// CCM
			REG_CCM_RR: reg_data_out = {16'd0, ccm_rr};
			REG_CCM_RG: reg_data_out = {16'd0, ccm_rg};
			REG_CCM_RB: reg_data_out = {16'd0, ccm_rb};
			REG_CCM_GR: reg_data_out = {16'd0, ccm_gr};
			REG_CCM_GG: reg_data_out = {16'd0, ccm_gg};
			REG_CCM_GB: reg_data_out = {16'd0, ccm_gb};
			REG_CCM_BR: reg_data_out = {16'd0, ccm_br};
			REG_CCM_BG: reg_data_out = {16'd0, ccm_bg};
			REG_CCM_BB: reg_data_out = {16'd0, ccm_bb};
			// CSC
			REG_CSC_CONV_STD: reg_data_out = {30'd0, in_conv_standard};
			// SHARP
			REG_SHARP_STRENGTH: reg_data_out = {20'd0, sharpen_strength};
			REG_SHARP_KERNEL_00: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(0*9+0)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_01: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(0*9+1)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_02: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(0*9+2)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_03: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(0*9+3)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_04: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(0*9+4)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_05: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(0*9+5)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_06: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(0*9+6)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_07: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(0*9+7)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_08: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(0*9+8)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_10: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(1*9+0)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_11: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(1*9+1)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_12: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(1*9+2)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_13: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(1*9+3)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_14: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(1*9+4)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_15: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(1*9+5)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_16: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(1*9+6)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_17: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(1*9+7)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_18: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(1*9+8)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_20: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(2*9+0)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_21: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(2*9+1)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_22: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(2*9+2)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_23: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(2*9+3)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_24: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(2*9+4)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_25: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(2*9+5)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_26: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(2*9+6)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_27: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(2*9+7)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_28: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(2*9+8)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_30: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(3*9+0)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_31: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(3*9+1)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_32: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(3*9+2)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_33: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(3*9+3)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_34: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(3*9+4)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_35: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(3*9+5)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_36: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(3*9+6)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_37: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(3*9+7)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_38: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(3*9+8)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_40: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(4*9+0)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_41: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(4*9+1)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_42: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(4*9+2)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_43: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(4*9+3)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_44: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(4*9+4)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_45: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(4*9+5)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_46: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(4*9+6)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_47: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(4*9+7)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_48: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(4*9+8)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_50: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(5*9+0)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_51: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(5*9+1)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_52: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(5*9+2)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_53: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(5*9+3)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_54: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(5*9+4)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_55: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(5*9+5)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_56: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(5*9+6)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_57: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(5*9+7)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_58: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(5*9+8)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_60: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(6*9+0)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_61: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(6*9+1)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_62: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(6*9+2)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_63: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(6*9+3)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_64: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(6*9+4)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_65: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(6*9+5)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_66: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(6*9+6)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_67: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(6*9+7)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_68: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(6*9+8)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_70: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(7*9+0)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_71: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(7*9+1)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_72: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(7*9+2)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_73: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(7*9+3)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_74: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(7*9+4)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_75: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(7*9+5)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_76: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(7*9+6)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_77: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(7*9+7)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_78: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(7*9+8)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_80: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(8*9+0)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_81: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(8*9+1)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_82: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(8*9+2)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_83: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(8*9+3)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_84: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(8*9+4)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_85: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(8*9+5)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_86: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(8*9+6)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_87: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(8*9+7)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			REG_SHARP_KERNEL_88: reg_data_out = {{(C_S_AXI_DATA_WIDTH-SHARP_WEIGHT_BITS){1'b0}}, luma_kernel[(8*9+8)*SHARP_WEIGHT_BITS+:SHARP_WEIGHT_BITS]};
			// 2DNR
			REG_2DNR_DIFF_00: reg_data_out = nr2d_diff[0*8*4+:32];
			REG_2DNR_DIFF_04: reg_data_out = nr2d_diff[1*8*4+:32];
			REG_2DNR_DIFF_08: reg_data_out = nr2d_diff[2*8*4+:32];
			REG_2DNR_DIFF_0C: reg_data_out = nr2d_diff[3*8*4+:32];
			REG_2DNR_DIFF_10: reg_data_out = nr2d_diff[4*8*4+:32];
			REG_2DNR_DIFF_14: reg_data_out = nr2d_diff[5*8*4+:32];
			REG_2DNR_DIFF_18: reg_data_out = nr2d_diff[6*8*4+:32];
			REG_2DNR_DIFF_1C: reg_data_out = nr2d_diff[7*8*4+:32];
			REG_2DNR_WEIGHT_00: reg_data_out = {{(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[ 3*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[ 2*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[ 1*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[ 0*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS]};
			REG_2DNR_WEIGHT_04: reg_data_out = {{(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[ 7*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[ 6*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[ 5*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[ 4*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS]};
			REG_2DNR_WEIGHT_08: reg_data_out = {{(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[11*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[10*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[ 9*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[ 8*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS]};
			REG_2DNR_WEIGHT_0C: reg_data_out = {{(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[15*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[14*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[13*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[12*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS]};
			REG_2DNR_WEIGHT_10: reg_data_out = {{(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[19*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[18*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[17*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[16*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS]};
			REG_2DNR_WEIGHT_14: reg_data_out = {{(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[23*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[22*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[21*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[20*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS]};
			REG_2DNR_WEIGHT_18: reg_data_out = {{(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[27*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[26*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[25*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[24*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS]};
			REG_2DNR_WEIGHT_1C: reg_data_out = {{(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[31*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[30*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[29*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS], {(8-NR2D_WEIGHT_BITS){1'b0}}, nr2d_weight[28*NR2D_WEIGHT_BITS+:NR2D_WEIGHT_BITS]};
			
//			REG_STAT_AE_RECT_X: reg_data_out = stat_ae_rect_x;
//			REG_STAT_AE_RECT_Y: reg_data_out = stat_ae_rect_y;
//			REG_STAT_AE_RECT_W: reg_data_out = stat_ae_rect_w;
//			REG_STAT_AE_RECT_H: reg_data_out = stat_ae_rect_h;
//			REG_STAT_AE_PIX_CNT_L: reg_data_out = stat_ae_pix_cnt;
//			REG_STAT_AE_SUM_L: reg_data_out = stat_ae_sum;
//			REG_STAT_AE_PIX_CNT_H: reg_data_out = (STAT_OUT_BITS > C_S_AXI_DATA_WIDTH) ? stat_ae_pix_cnt[STAT_OUT_BITS-1:C_S_AXI_DATA_WIDTH] : 0;
//			REG_STAT_AE_SUM_H: reg_data_out = (STAT_OUT_BITS > C_S_AXI_DATA_WIDTH) ? stat_ae_sum[STAT_OUT_BITS-1:C_S_AXI_DATA_WIDTH] : 0;
			// AE
			REG_AE_CENTER_ILLUMINANCE: reg_data_out = center_illuminance;
			REG_AE_SKEWNESS: reg_data_out = skewness;
			REG_AE_CROP_LEFT: reg_data_out = ae_crop_left;
			REG_AE_CROP_RIGHT: reg_data_out = ae_crop_right;
			REG_AE_CROP_TOP: reg_data_out = ae_crop_top;
			REG_AE_CROP_BOTTOM: reg_data_out = ae_crop_bottom;
			REG_AE_RESPONSE: reg_data_out = ae_response;
			REG_AE_RESULT_SKEWNESS: reg_data_out = ae_result_skewness;
			REG_AE_RESPONSE_DEBUG: reg_data_out = ae_response_debug;
			REG_AE_DONE: reg_data_out = ae_done;
			// AWB
			REG_AWB_UNDEREXPOSED_LIMIT: reg_data_out = {{(C_S_AXI_DATA_WIDTH-BITS){1'b0}},awb_underexposed_limit};
			REG_AWB_OVEREXPOSED_LIMIT: reg_data_out = {{(C_S_AXI_DATA_WIDTH-BITS){1'b0}},awb_overexposed_limit};
			REG_AWB_FRAMES: reg_data_out = {{(C_S_AXI_DATA_WIDTH-BITS){1'b0}},awb_frames};
			REG_AWB_FINAL_RGAIN: reg_data_out = {20'd0,final_r_gain};
			REG_AWB_FINAL_BGAIN: reg_data_out = {20'd0,final_b_gain};
//			REG_AWB_RGAIN: reg_data_out = {20'd0,r_gain};
//			REG_AWB_BGAIN: reg_data_out = {20'd0,b_gain};
//			REG_AWB_HIGH: reg_data_out = {31'd0,high};
			// VIP1_CONFIG
			REG_VIP1_RESET: reg_data_out <= {31'd0, vip1_module_reset};
			REG_VIP1_WIDTH: reg_data_out = CROP_WIDTH;
			REG_VIP1_HEIGHT: reg_data_out = CROP_HEIGHT;
			REG_VIP1_BITS: reg_data_out = BITS;
			REG_VIP1_TOP_EN: reg_data_out <= {27'd0, vip1_yuv444to422_en, vip1_osd_en, vip1_dscale_en, vip1_crop_en, vip1_yuv2rgb_en/*, sobel_en, hist_equ_en*/};
			REG_VIP1_INT_STATUS: reg_data_out <= {30'd0, int_vip1_frame_done, int_vip1_frame_start};
			REG_VIP1_INT_MASK: reg_data_out <= {30'd0, int_vip1_mask_frame_done,int_vip1_mask_frame_start};
            // RGBC
            REG_VIP1_RGBC_CONV_STD: reg_data_out <= {30'd0, vip1_vip_in_conv_standard};
			// IRC
			REG_VIP1_IRC_X: reg_data_out <= {16'd0, vip1_crop_x};
			REG_VIP1_IRC_Y: reg_data_out <= {16'd0, vip1_crop_y};
			REG_VIP1_IRC_OUTPUT: reg_data_out <= {30'd0, vip1_irc_output};
			// SCALE
            REG_VIP1_SCALE_IN_CROP_W: reg_data_out <= {20'd0,vip1_s_in_crop_w};
			REG_VIP1_SCALE_IN_CROP_H: reg_data_out <= {20'd0,vip1_s_in_crop_h};
			REG_VIP1_SCALE_OUT_CROP_W: reg_data_out <= {20'd0,vip1_s_out_crop_w};
			REG_VIP1_SCALE_OUT_CROP_H: reg_data_out <= {20'd0,vip1_s_out_crop_h};
			REG_VIP1_SCALE_DSCALE_W: reg_data_out <= {29'd0,vip1_dscale_w};
			REG_VIP1_SCALE_DSCALE_H: reg_data_out <= {29'd0,vip1_dscale_h};
			// OSD
			REG_VIP1_OSD_X: reg_data_out <= {16'd0, vip1_osd_x};
			REG_VIP1_OSD_Y: reg_data_out <= {16'd0, vip1_osd_y};
			REG_VIP1_OSD_W: reg_data_out <= {16'd0, vip1_osd_w};
			REG_VIP1_OSD_H: reg_data_out <= {16'd0, vip1_osd_h};
			REG_VIP1_OSD_COLOR_FG: reg_data_out <= {8'd0,vip1_osd_color_fg};
			REG_VIP1_OSD_COLOR_BG: reg_data_out <= {8'd0,vip1_osd_color_bg};
			REG_VIP1_ALPHA: reg_data_out <= {24'd0,vip1_alpha};
			// vip1_YUV444TO422
			REG_VIP1_YUV_YUV444TO422: reg_data_out <= {31'd0, vip1_YUV444TO422};
			//VIP2_CONFIG
			REG_VIP2_RESET: reg_data_out <= {31'd0, vip2_module_reset};
			REG_VIP2_WIDTH: reg_data_out = CROP_WIDTH;
			REG_VIP2_HEIGHT: reg_data_out = CROP_HEIGHT;
			REG_VIP2_BITS: reg_data_out = BITS;
			REG_VIP2_TOP_EN: reg_data_out <= {27'd0, vip2_yuv444to422_en, vip2_osd_en, vip2_dscale_en, vip2_crop_en, vip2_yuv2rgb_en/*, sobel_en, hist_equ_en*/};
			REG_VIP2_INT_STATUS: reg_data_out <= {30'd0, int_vip2_frame_done, int_vip2_frame_start};
			REG_VIP2_INT_MASK: reg_data_out <= {30'd0, int_vip2_mask_frame_done,int_vip2_mask_frame_start};
			// RGBC
            REG_VIP2_RGBC_CONV_STD: reg_data_out <= {30'd0, vip2_vip_in_conv_standard};
			// IRC
			REG_VIP2_IRC_X: reg_data_out <= {16'd0, vip2_crop_x};
			REG_VIP2_IRC_Y: reg_data_out <= {16'd0, vip2_crop_y};
			REG_VIP2_IRC_OUTPUT: reg_data_out <= {30'd0, vip2_irc_output};
			// SCALE
            REG_VIP2_SCALE_IN_CROP_W: reg_data_out <= {20'd0,vip2_s_in_crop_w};
			REG_VIP2_SCALE_IN_CROP_H: reg_data_out <= {20'd0,vip2_s_in_crop_h};
			REG_VIP2_SCALE_OUT_CROP_W: reg_data_out <= {20'd0,vip2_s_out_crop_w};
			REG_VIP2_SCALE_OUT_CROP_H: reg_data_out <= {20'd0,vip2_s_out_crop_h};
			REG_VIP2_SCALE_DSCALE_W: reg_data_out <= {29'd0,vip2_dscale_w};
			REG_VIP2_SCALE_DSCALE_H: reg_data_out <= {29'd0,vip2_dscale_h};
			// OSD
			REG_VIP2_OSD_X: reg_data_out <= {16'd0, vip2_osd_x};
			REG_VIP2_OSD_Y: reg_data_out <= {16'd0, vip2_osd_y};
			REG_VIP2_OSD_W: reg_data_out <= {16'd0, vip2_osd_w};
			REG_VIP2_OSD_H: reg_data_out <= {16'd0, vip2_osd_h};
			REG_VIP2_OSD_COLOR_FG: reg_data_out <= {8'd0,vip2_osd_color_fg};
			REG_VIP2_OSD_COLOR_BG: reg_data_out <= {8'd0,vip2_osd_color_bg};
			REG_VIP2_ALPHA: reg_data_out <= {24'd0,vip2_alpha};

			// vip2_YUV444TO422
			REG_VIP2_YUV_YUV444TO422: reg_data_out <= {31'd0, vip2_YUV444TO422};
			
			REG_INT_STATUS: reg_data_out = {28'd0, int_awb_done, int_ae_done, int_isp_frame_done, int_isp_frame_start};
			REG_INT_MASK: reg_data_out = {28'd0, int_mask_awb_done, int_mask_ae_done, int_isp_mask_frame_done, int_isp_mask_frame_start};
			default: reg_data_out = 0;
	      endcase
	end

	// Output register or memory read data
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rdata  <= 0;
	    end 
	  else
	    begin    
	      // When there is a valid read address (S_AXI_ARVALID) with 
	      // acceptance of read address by the slave (axi_arready), 
	      // output the read dada 
	      if (slv_reg_rden)
	        begin
	          axi_rdata <= reg_data_out;     // register read data
	        end   
	    end
	end    

	// Add user logic here
	// shadow config registers
	reg s_module_reset;
	reg s_vip1_module_reset, s_vip2_module_reset;
	// Module Enables
	reg s_crop_en, s_dpc_en, s_blc_en, s_linear_en, s_oecf_en, s_dgain_en, s_lsc_en, s_bnr_en, s_wb_en, s_demosic_en, s_ccm_en, s_gamma_en, s_csc_en, s_ldci_en, s_2dnr_en, s_sharp_en, s_stat_ae_en, s_awb_en, s_ae_en,
        s_vip1_hist_equ_en, s_vip1_sobel_en, s_vip1_yuv2rgb_en, s_vip1_crop_en, s_vip1_dscale_en, s_vip1_osd_en, s_vip1_yuv444to422_en, s_vip2_hist_equ_en, s_vip2_sobel_en, s_vip2_yuv2rgb_en, s_vip2_crop_en, s_vip2_dscale_en, s_vip2_osd_en, s_vip2_yuv444to422_en;
    // DPC
	reg [BITS-1:0] s_dpc_threshold;
	// BLC
	reg [BITS-1:0] s_blc_r, s_blc_gr, s_blc_gb, s_blc_b;
	reg [15:0] s_linear_r, s_linear_gr, s_linear_gb, s_linear_b;
	// DG
	reg s_dgain_isManual;
	reg [DGAIN_ARRAY_BITS-1:0] s_dgain_man_index;
	reg [DGAIN_ARRAY_SIZE*8-1:0] s_dgain_array;
	// BNR
	reg [5*5*BNR_WEIGHT_BITS-1:0] s_bnr_space_kernel_r;	
	reg [5*5*BNR_WEIGHT_BITS-1:0] s_bnr_space_kernel_g;
	reg [5*5*BNR_WEIGHT_BITS-1:0] s_bnr_space_kernel_b;  
	reg [9*BITS-1:0]              s_bnr_color_curve_x_r;   
	reg [9*BNR_WEIGHT_BITS-1:0]   s_bnr_color_curve_y_r;
	reg [9*BITS-1:0]              s_bnr_color_curve_x_g;   
	reg [9*BNR_WEIGHT_BITS-1:0]   s_bnr_color_curve_y_g;
	reg [9*BITS-1:0]              s_bnr_color_curve_x_b;   
	reg [9*BNR_WEIGHT_BITS-1:0]   s_bnr_color_curve_y_b;
	// WB
	reg [11:0] s_wb_rgain, s_wb_bgain;
	// CCM
	reg [15:0] s_ccm_rr, s_ccm_rg, s_ccm_rb;
	reg [15:0] s_ccm_gr, s_ccm_gg, s_ccm_gb;
	reg [15:0] s_ccm_br, s_ccm_bg, s_ccm_bb;
	// CSC
	reg [1:0] s_in_conv_standard;
	// SHARP
	reg [9*9*SHARP_WEIGHT_BITS-1:0] s_luma_kernel;
	reg [11:0] s_sharpen_strength;
    // 2DNR
    reg [32*8-1:0]                 s_nr2d_diff;
	reg [32*NR2D_WEIGHT_BITS-1:0]  s_nr2d_weight;
    
	reg [15:0] s_stat_ae_rect_x, s_stat_ae_rect_y, s_stat_ae_rect_w, s_stat_ae_rect_h;
	// AE
	reg [7:0] s_center_illuminance;
    reg [15:0] s_skewness;
	reg [11:0] s_ae_crop_left;
	reg [11:0] s_ae_crop_right;
	reg [11:0] s_ae_crop_top;
	reg [11:0] s_ae_crop_bottom;
	// AWB
	reg [BITS-1:0] s_awb_underexposed_limit, s_awb_overexposed_limit, s_awb_frames;

    // RGBC
    reg [1:0] s_vip1_in_conv_standard;
    // IRC
	reg [15:0] s_vip1_crop_x;
	reg [15:0] s_vip1_crop_y;
	reg [1:0] s_vip1_irc_output;
	// SCALE
    reg [11:0] s_vip1_s_in_crop_w;
    reg [11:0] s_vip1_s_in_crop_h;
	reg [11:0] s_vip1_s_out_crop_w;
	reg [11:0] s_vip1_s_out_crop_h;
	reg [2:0] s_vip1_dscale_w;
	reg [2:0] s_vip1_dscale_h;
    // OSD
	reg [15:0] s_vip1_osd_x, s_vip1_osd_y, s_vip1_osd_w, s_vip1_osd_h;
	reg [3*VIP1_BITS-1:0] s_vip1_osd_color_fg, s_vip1_osd_color_bg;
	reg [7:0] s_vip1_alpha; 
    // vip1_YUV444TO422
    reg s_vip1_YUV444TO422;
	// RGBC
    reg [1:0] s_vip2_in_conv_standard;
    // IRC
	reg [15:0] s_vip2_crop_x;
	reg [15:0] s_vip2_crop_y;
	reg [1:0] s_vip2_irc_output;
	// SCALE
    reg [11:0] s_vip2_s_in_crop_w;
    reg [11:0] s_vip2_s_in_crop_h;
	reg [11:0] s_vip2_s_out_crop_w;
	reg [11:0] s_vip2_s_out_crop_h;
	reg [2:0] s_vip2_dscale_w;
	reg [2:0] s_vip2_dscale_h;
    // OSD
	reg [15:0] s_vip2_osd_x, s_vip2_osd_y, s_vip2_osd_w, s_vip2_osd_h;
	reg [3*VIP2_BITS-1:0] s_vip2_osd_color_fg, s_vip2_osd_color_bg;
	reg [7:0] s_vip2_alpha; 

    // vip2_YUV444TO422
    reg s_vip2_YUV444TO422;
	
	reg prev_vsync_r;
	always @ (posedge pclk) prev_vsync_r <= in_vsync;

	wire cfg_sync = ~in_vsync & prev_vsync_r; //frame_start with pclk
	wire reset_n = rst_n & (~s_module_reset);
    
    // LUTs Go Here

	// GAMMA
	wire                        gamma_table_r_clk = S_AXI_ACLK;
	wire                        gamma_table_r_wen = slv_reg_wren && (axi_awaddr_mode_id == 1) && (axi_awaddr_module_id[5] == 0);
	wire                        gamma_table_r_ren = slv_reg_rden && (axi_araddr_mode_id == 1) && (axi_araddr_module_id[5] == 0);
	wire [BITS-1:0] gamma_table_r_addr = slv_reg_wren ? axi_awaddr[ADDR_LSB+:BITS] : axi_araddr[ADDR_LSB+:BITS];
	wire [BITS-1:0] gamma_table_r_wdata = S_AXI_WDATA[BITS-1:0];
	wire [BITS-1:0] gamma_table_r_rdata;
	
	wire                        gamma_table_g_clk = S_AXI_ACLK;
	wire                        gamma_table_g_wen = slv_reg_wren && (axi_awaddr_mode_id == 1) && (axi_awaddr_module_id[5] == 0);
	wire                        gamma_table_g_ren = slv_reg_rden && (axi_araddr_mode_id == 1) && (axi_araddr_module_id[5] == 0);
	wire [BITS-1:0] gamma_table_g_addr = slv_reg_wren ? axi_awaddr[ADDR_LSB+:BITS] : axi_araddr[ADDR_LSB+:BITS];
	wire [BITS-1:0] gamma_table_g_wdata = S_AXI_WDATA[BITS-1:0];
	wire [BITS-1:0] gamma_table_g_rdata;
	
	wire                        gamma_table_b_clk = S_AXI_ACLK;
	wire                        gamma_table_b_wen = slv_reg_wren && (axi_awaddr_mode_id == 1) && (axi_awaddr_module_id[5] == 0);
	wire                        gamma_table_b_ren = slv_reg_rden && (axi_araddr_mode_id == 1) && (axi_araddr_module_id[5] == 0);
	wire [BITS-1:0] gamma_table_b_addr = slv_reg_wren ? axi_awaddr[ADDR_LSB+:BITS] : axi_araddr[ADDR_LSB+:BITS];
	wire [BITS-1:0] gamma_table_b_wdata = S_AXI_WDATA[BITS-1:0];
	wire [BITS-1:0] gamma_table_b_rdata;
	
	// OECF
	wire                           r_table_clk = S_AXI_ACLK;
	wire                           r_table_wen = slv_reg_wren && (axi_awaddr_mode_id == 2) && (axi_awaddr_module_id[5] == 1'b0);
	wire                           r_table_ren = slv_reg_rden && (axi_araddr_mode_id == 2) && (axi_araddr_module_id[5] == 1'b0);
	wire [BITS-1:0]                r_table_addr = slv_reg_wren ? axi_awaddr[ADDR_LSB+:BITS] : axi_araddr[ADDR_LSB+:BITS];
	wire [C_S_AXI_DATA_WIDTH-1:0]  r_table_wdata = S_AXI_WDATA[31:0];
	wire [C_S_AXI_DATA_WIDTH-1:0]  r_table_rdata;
	
	wire                           gr_table_clk = S_AXI_ACLK;
	wire                           gr_table_wen = slv_reg_wren && (axi_awaddr_mode_id == 2) && (axi_awaddr_module_id[5] == 1'b1);
	wire                           gr_table_ren = slv_reg_rden && (axi_araddr_mode_id == 2) && (axi_araddr_module_id[5] == 1'b1);
	wire [BITS-1:0]                gr_table_addr = slv_reg_wren ? axi_awaddr[ADDR_LSB+:BITS] : axi_araddr[ADDR_LSB+:BITS];
	wire [C_S_AXI_DATA_WIDTH-1:0]  gr_table_wdata = S_AXI_WDATA[31:0];
	wire [C_S_AXI_DATA_WIDTH-1:0]  gr_table_rdata;
    
    wire                           b_table_clk = S_AXI_ACLK;
	wire                           b_table_wen = slv_reg_wren && (axi_awaddr_mode_id == 3) && (axi_awaddr_module_id[5] == 1'b1);
	wire                           b_table_ren = slv_reg_rden && (axi_araddr_mode_id == 3) && (axi_araddr_module_id[5] == 1'b1);
	wire [BITS-1:0]                b_table_addr = slv_reg_wren ? axi_awaddr[ADDR_LSB+:BITS] : axi_araddr[ADDR_LSB+:BITS];
	wire [C_S_AXI_DATA_WIDTH-1:0]  b_table_wdata = S_AXI_WDATA[31:0];
	wire [C_S_AXI_DATA_WIDTH-1:0]  b_table_rdata;
	
	wire                           gb_table_clk = S_AXI_ACLK;
	wire                           gb_table_wen = slv_reg_wren && (axi_awaddr_mode_id == 3) && (axi_awaddr_module_id[5] == 1'b0);
	wire                           gb_table_ren = slv_reg_rden && (axi_araddr_mode_id == 3) && (axi_araddr_module_id[5] == 1'b0);
	wire [BITS-1:0]                gb_table_addr = slv_reg_wren ? axi_awaddr[ADDR_LSB+:BITS] : axi_araddr[ADDR_LSB+:BITS];
	wire [C_S_AXI_DATA_WIDTH-1:0]  gb_table_wdata = S_AXI_WDATA[31:0];
	wire [C_S_AXI_DATA_WIDTH-1:0]  gb_table_rdata;

    //VIP1 OSD RAM接�?�
	wire                         vip1_osd_ram_clk = S_AXI_ACLK;
	wire                         vip1_osd_ram_wen = slv_reg_wren && axi_awaddr_mode_id == 1 && axi_awaddr_module_id[5:4] == 2'b10;
	wire                         vip1_osd_ram_ren = slv_reg_rden && axi_araddr_mode_id == 1 && axi_araddr_module_id[5:4] == 2'b10;
	wire [VIP1_OSD_RAM_ADDR_BITS-1:0] vip1_osd_ram_addr = slv_reg_wren ? axi_awaddr[ADDR_LSB+:VIP1_OSD_RAM_ADDR_BITS] : axi_araddr[ADDR_LSB+:VIP1_OSD_RAM_ADDR_BITS];
	wire [VIP1_OSD_RAM_DATA_BITS-1:0] vip1_osd_ram_wdata = S_AXI_WDATA[VIP1_OSD_RAM_DATA_BITS-1:0];
	wire [VIP1_OSD_RAM_DATA_BITS-1:0] vip1_osd_ram_rdata;
	//VIP2 OSD RAM
	wire                         vip2_osd_ram_clk = S_AXI_ACLK;
	wire                         vip2_osd_ram_wen = slv_reg_wren && axi_awaddr_mode_id == 1 && axi_awaddr_module_id[5:4] == 2'b11;
	wire                         vip2_osd_ram_ren = slv_reg_rden && axi_araddr_mode_id == 1 && axi_araddr_module_id[5:4] == 2'b11;
	wire [VIP1_OSD_RAM_ADDR_BITS-1:0] vip2_osd_ram_addr = slv_reg_wren ? axi_awaddr[ADDR_LSB+:VIP1_OSD_RAM_ADDR_BITS] : axi_araddr[ADDR_LSB+:VIP1_OSD_RAM_ADDR_BITS];
	wire [VIP1_OSD_RAM_DATA_BITS-1:0] vip2_osd_ram_wdata = S_AXI_WDATA[VIP1_OSD_RAM_DATA_BITS-1:0];
	wire [VIP1_OSD_RAM_DATA_BITS-1:0] vip2_osd_ram_rdata;
	
	//link AE/AWB hist ram to S_AXI_RDATA
	always @ (*) begin
		case (axi_araddr_mode_id)
			MODE_REGISTERS : S_AXI_RDATA = axi_rdata;
			MODE_GAMMA_LUT, MODE_VIP1_OSD_RAM, MODE_VIP2_OSD_RAM : begin
				case (axi_araddr_module_id[5:4])
					//Gamma LUT
					2'b00, 2'b01: S_AXI_RDATA = gamma_table_r_rdata;
					//VIP1 OSD RAM
					2'b10: S_AXI_RDATA = vip1_osd_ram_rdata;
								
					//VIP2 OSD RAM
					2'b11: S_AXI_RDATA = vip2_osd_ram_rdata;
					default: S_AXI_RDATA = 0;
				endcase
			end
			MODE_OECF_LUT1 : begin
				case (axi_araddr_module_id[5])
					1'b0 : S_AXI_RDATA = r_table_rdata;
					1'b1 : S_AXI_RDATA = gr_table_rdata;
					default: S_AXI_RDATA = 0;
				endcase
			end
			MODE_OECF_LUT2 : begin
				case (axi_araddr_module_id[5])
					1'b0 : S_AXI_RDATA = gb_table_rdata;
					1'b1 : S_AXI_RDATA = b_table_rdata;
					default: S_AXI_RDATA = 0;
				endcase
			end
			default: S_AXI_RDATA = 0;
		endcase
	end
    //link OSD ram to S_AXI_RDATA
	// always @ (*) begin
	// 	case (axi_araddr_area_id)
	// 		2'b00 : S_AXI_RDATA = axi_rdata;
	// 		2'b01 : S_AXI_RDATA = vip_osd_ram_rdata;
	// 		2'b10 : S_AXI_RDATA = axi_rdata;
	// 		2'b11 : S_AXI_RDATA = axi_rdata;
	// 		default: S_AXI_RDATA = axi_rdata;
	// 	endcase
	// end

	always @ (posedge pclk) begin
		s_module_reset <= module_reset;
		s_vip1_module_reset <= vip1_module_reset;
		s_vip2_module_reset <= vip2_module_reset;
		if (cfg_sync) begin
			// Module Enables
			s_crop_en <= crop_en;
			s_dpc_en <= dpc_en;
			s_blc_en <= blc_en;
			s_linear_en <= linear_en;
			s_oecf_en <= oecf_en;
			s_dgain_en <= dgain_en;
			s_lsc_en <= lsc_en;
			s_bnr_en <= bnr_en;
			s_wb_en <= wb_en;
			s_demosic_en <= demosic_en;
			s_ccm_en <= ccm_en;
			s_gamma_en <= gamma_en;
			s_csc_en <= csc_en;
			s_sharp_en <= sharp_en;
			s_ldci_en <= ldci_en;
			s_2dnr_en <= nr2d_en;
			s_stat_ae_en <= stat_ae_en;
			s_awb_en <= awb_en;
			s_ae_en <= ae_en;
            //vip
			s_vip1_yuv2rgb_en <= vip1_yuv2rgb_en;
			s_vip1_crop_en <= vip1_crop_en;
			s_vip1_dscale_en <= vip1_dscale_en;
			s_vip1_osd_en <= vip1_osd_en;
			s_vip1_yuv444to422_en <= vip1_yuv444to422_en;

			s_vip2_yuv2rgb_en <= vip2_yuv2rgb_en;
			s_vip2_crop_en <= vip2_crop_en;
			s_vip2_dscale_en <= vip2_dscale_en;
			s_vip2_osd_en <= vip2_osd_en;
			s_vip2_yuv444to422_en <= vip2_yuv444to422_en;
			// DPC
			s_dpc_threshold <= dpc_threshold;
			// BLC
			s_blc_r <= blc_r;
			s_blc_gr <= blc_gr;
			s_blc_gb <= blc_gb;
			s_blc_b <= blc_b;
			s_linear_r <= linear_r;
			s_linear_gr <= linear_gr;
			s_linear_gb <= linear_gb;
			s_linear_b <= linear_b;
			// DG
			s_dgain_isManual <= dgain_isManual;
			s_dgain_man_index <= dgain_man_index;
			s_dgain_array <= dgain_array;
			// BNR
			s_bnr_space_kernel_r  <= bnr_space_kernel_r;	
            s_bnr_space_kernel_g  <= bnr_space_kernel_g; 
            s_bnr_space_kernel_b  <= bnr_space_kernel_b; 
            s_bnr_color_curve_x_r <= bnr_color_curve_x_r;
            s_bnr_color_curve_y_r <= bnr_color_curve_y_r;
            s_bnr_color_curve_x_g <= bnr_color_curve_x_g;
            s_bnr_color_curve_y_g <= bnr_color_curve_y_g;
            s_bnr_color_curve_x_b <= bnr_color_curve_x_b;
            s_bnr_color_curve_y_b <= bnr_color_curve_y_b;
			// WB
			s_wb_rgain <= wb_rgain;
			s_wb_bgain <= wb_bgain;
			// CCM
			s_ccm_rr <= ccm_rr;
			s_ccm_rg <= ccm_rg;
			s_ccm_rb <= ccm_rb;
			s_ccm_gr <= ccm_gr;
			s_ccm_gg <= ccm_gg;
			s_ccm_gb <= ccm_gb;
			s_ccm_br <= ccm_br;
			s_ccm_bg <= ccm_bg;
			s_ccm_bb <= ccm_bb;
			// CSC
			s_in_conv_standard <= in_conv_standard;
			// SHARP
			s_luma_kernel <= luma_kernel;
			s_sharpen_strength <= sharpen_strength;
			// 2DNR
			s_nr2d_diff <= nr2d_diff;
			s_nr2d_weight <= nr2d_weight;
			
			s_stat_ae_rect_x <= stat_ae_rect_x;
			s_stat_ae_rect_y <= stat_ae_rect_y;
			s_stat_ae_rect_w <= stat_ae_rect_w;
			s_stat_ae_rect_h <= stat_ae_rect_h;
			// AE
			s_center_illuminance <= center_illuminance;
			s_skewness <= skewness;
			s_ae_crop_left <= ae_crop_left;
			s_ae_crop_right <= ae_crop_right;
			s_ae_crop_top <= ae_crop_top;
			s_ae_crop_bottom <= ae_crop_bottom;
			// AWB
			s_awb_underexposed_limit <= awb_underexposed_limit;
			s_awb_overexposed_limit <= awb_overexposed_limit;
			s_awb_frames <= awb_frames;
            // RGBC
            s_vip1_in_conv_standard <= vip1_vip_in_conv_standard;
            // IRC
			s_vip1_crop_x <= vip1_crop_x;
			s_vip1_crop_y <= vip1_crop_y;
			s_vip1_irc_output <= vip1_irc_output;
			// SCALE
            s_vip1_s_in_crop_w <= vip1_s_in_crop_w;
            s_vip1_s_in_crop_h <= vip1_s_in_crop_h;
            s_vip1_s_out_crop_w <= vip1_s_out_crop_w;
            s_vip1_s_out_crop_h <= vip1_s_out_crop_h;
            s_vip1_dscale_w <= vip1_dscale_w;
            s_vip1_dscale_h <= vip1_dscale_h;
			// OSD
			s_vip1_osd_x <= vip1_osd_x;
			s_vip1_osd_y <= vip1_osd_y;
			s_vip1_osd_w <= vip1_osd_w;
			s_vip1_osd_h <= vip1_osd_h;
			s_vip1_osd_color_fg <= vip1_osd_color_fg;
			s_vip1_osd_color_bg <= vip1_osd_color_bg;
			s_vip1_alpha <= vip1_alpha;
			// vip1_YUV444TO422
			s_vip1_YUV444TO422 <= vip1_YUV444TO422;
			// RGBC
            s_vip2_in_conv_standard <= vip2_vip_in_conv_standard;
            // IRC
			s_vip2_crop_x <= vip2_crop_x;
			s_vip2_crop_y <= vip2_crop_y;
			s_vip2_irc_output <= vip2_irc_output;
			// SCALE
            s_vip2_s_in_crop_w <= vip2_s_in_crop_w;
            s_vip2_s_in_crop_h <= vip2_s_in_crop_h;
            s_vip2_s_out_crop_w <= vip2_s_out_crop_w;
            s_vip2_s_out_crop_h <= vip2_s_out_crop_h;
            s_vip2_dscale_w <= vip2_dscale_w;
            s_vip2_dscale_h <= vip2_dscale_h;
			// OSD
			s_vip2_osd_x <= vip2_osd_x;
			s_vip2_osd_y <= vip2_osd_y;
			s_vip2_osd_w <= vip2_osd_w;
			s_vip2_osd_h <= vip2_osd_h;
			s_vip2_osd_color_fg <= vip2_osd_color_fg;
			s_vip2_osd_color_bg <= vip2_osd_color_bg;
			s_vip2_alpha <= vip2_alpha;
			// vip2_YUV444TO422
			s_vip2_YUV444TO422 <= vip2_YUV444TO422;
		end
		else begin
			// Module Enables
			s_crop_en <= s_crop_en;
			s_dpc_en <= s_dpc_en;
			s_blc_en <= s_blc_en;
			s_linear_en <= s_linear_en;
			s_oecf_en <= s_oecf_en;
			s_dgain_en <= s_dgain_en;
			s_lsc_en <= s_lsc_en;
			s_bnr_en <= s_bnr_en;
			s_wb_en <= s_wb_en;
			s_demosic_en <= s_demosic_en;
			s_ccm_en <= s_ccm_en;
			s_gamma_en <= s_gamma_en;
			s_csc_en <= s_csc_en;
			s_sharp_en <= s_sharp_en;
			s_ldci_en <= s_ldci_en;
			s_2dnr_en <= s_2dnr_en;
			s_stat_ae_en <= s_stat_ae_en;
			s_awb_en <= s_awb_en;
			s_ae_en <= s_ae_en;
            //vip
            s_vip1_hist_equ_en <= s_vip1_hist_equ_en;
			s_vip1_sobel_en <= s_vip1_sobel_en;
			s_vip1_yuv2rgb_en <= s_vip1_yuv2rgb_en;
			s_vip1_crop_en <= s_vip1_crop_en;
			s_vip1_dscale_en <= s_vip1_dscale_en;
			s_vip1_yuv444to422_en <= s_vip1_yuv444to422_en;
			s_vip2_hist_equ_en <= s_vip2_hist_equ_en;
			s_vip2_sobel_en <= s_vip2_sobel_en;
			s_vip2_yuv2rgb_en <= s_vip2_yuv2rgb_en;
			s_vip2_crop_en <= s_vip2_crop_en;
			s_vip2_dscale_en <= s_vip2_dscale_en;
			s_vip2_yuv444to422_en <= s_vip2_yuv444to422_en;
			// DPC
			s_dpc_threshold <= s_dpc_threshold;
			// BLC
			s_blc_b <= s_blc_b;
			s_blc_gb <= s_blc_gb;
			s_blc_gr <= s_blc_gr;
			s_blc_r <= s_blc_r;
			s_linear_r <= s_linear_r;
			s_linear_gr <= s_linear_gr;
			s_linear_gb <= s_linear_gb;
			s_linear_b <= s_linear_b;
			// DG
			s_dgain_isManual <= s_dgain_isManual;
			s_dgain_man_index <= s_dgain_man_index;
			s_dgain_array <= s_dgain_array;
			// BNR
			s_bnr_space_kernel_r  <= s_bnr_space_kernel_r;	
            s_bnr_space_kernel_g  <= s_bnr_space_kernel_g; 
            s_bnr_space_kernel_b  <= s_bnr_space_kernel_b; 
            s_bnr_color_curve_x_r <= s_bnr_color_curve_x_r;
            s_bnr_color_curve_y_r <= s_bnr_color_curve_y_r;
            s_bnr_color_curve_x_g <= s_bnr_color_curve_x_g;
            s_bnr_color_curve_y_g <= s_bnr_color_curve_y_g;
            s_bnr_color_curve_x_b <= s_bnr_color_curve_x_b;
            s_bnr_color_curve_y_b <= s_bnr_color_curve_y_b;
			// WB
			s_wb_rgain <= s_wb_rgain;
			s_wb_bgain <= s_wb_bgain;
			// CCM
			s_ccm_rr <= s_ccm_rr;
			s_ccm_rg <= s_ccm_rg;
			s_ccm_rb <= s_ccm_rb;
			s_ccm_gr <= s_ccm_gr;
			s_ccm_gg <= s_ccm_gg;
			s_ccm_gb <= s_ccm_gb;
			s_ccm_br <= s_ccm_br;
			s_ccm_bg <= s_ccm_bg;
			s_ccm_bb <= s_ccm_bb;
			// CSC
			s_in_conv_standard <= s_in_conv_standard;
			// SHARP
			s_luma_kernel <= s_luma_kernel;
			s_sharpen_strength <= s_sharpen_strength;
			// 2DNR
			s_nr2d_diff <= s_nr2d_diff;
			s_nr2d_weight <= s_nr2d_weight;
			
			s_stat_ae_rect_x <= s_stat_ae_rect_x;
			s_stat_ae_rect_y <= s_stat_ae_rect_y;
			s_stat_ae_rect_w <= s_stat_ae_rect_w;
			s_stat_ae_rect_h <= s_stat_ae_rect_h;
			// AE
			s_center_illuminance <= s_center_illuminance;
			s_skewness <= s_skewness;
			s_ae_crop_left <= s_ae_crop_left;
			s_ae_crop_right <= s_ae_crop_right;
			s_ae_crop_top <= s_ae_crop_top;
			s_ae_crop_bottom <= s_ae_crop_bottom;
			// AWB
			s_awb_underexposed_limit <= s_awb_underexposed_limit;
			s_awb_overexposed_limit <= s_awb_overexposed_limit;
			s_awb_frames <= s_awb_frames;
            // RGBC
            s_vip1_in_conv_standard <= s_vip1_in_conv_standard;
            // IRC
			s_vip1_crop_x <= s_vip1_crop_x;
			s_vip1_crop_y <= s_vip1_crop_y;
			s_vip1_irc_output <= s_vip1_irc_output;
			// SCALE
            s_vip1_s_in_crop_w <= s_vip1_s_in_crop_w;
            s_vip1_s_in_crop_h <= s_vip1_s_in_crop_h;
            s_vip1_s_out_crop_w <= s_vip1_s_out_crop_w;
            s_vip1_s_out_crop_h <= s_vip1_s_out_crop_h;
            s_vip1_dscale_w <= s_vip1_dscale_w;
            s_vip1_dscale_h <= s_vip1_dscale_h;
			// OSD
			s_vip1_osd_x <= s_vip1_osd_x;
			s_vip1_osd_y <= s_vip1_osd_y;
			s_vip1_osd_w <= s_vip1_osd_w;
			s_vip1_osd_h <= s_vip1_osd_h;
			s_vip1_osd_color_fg <= s_vip1_osd_color_fg;
			s_vip1_osd_color_bg <= s_vip1_osd_color_bg;
			s_vip1_alpha <= s_vip1_alpha;
			// vip1_YUV444TO422
			s_vip1_YUV444TO422 <= s_vip1_YUV444TO422;
			// RGBC
            s_vip2_in_conv_standard <= s_vip2_in_conv_standard;
            // IRC
			s_vip2_crop_x <= s_vip2_crop_x;
			s_vip2_crop_y <= s_vip2_crop_y;
			s_vip2_irc_output <= s_vip2_irc_output;
			// SCALE
            s_vip2_s_in_crop_w <= s_vip2_s_in_crop_w;
            s_vip2_s_in_crop_h <= s_vip2_s_in_crop_h;
            s_vip2_s_out_crop_w <= s_vip2_s_out_crop_w;
            s_vip2_s_out_crop_h <= s_vip2_s_out_crop_h;
            s_vip2_dscale_w <= s_vip2_dscale_w;
            s_vip2_dscale_h <= s_vip2_dscale_h;
			// OSD
			s_vip2_osd_x <= s_vip2_osd_x;
			s_vip2_osd_y <= s_vip2_osd_y;
			s_vip2_osd_w <= s_vip2_osd_w;
			s_vip2_osd_h <= s_vip2_osd_h;
			s_vip2_osd_color_fg <= s_vip2_osd_color_fg;
			s_vip2_osd_color_bg <= s_vip2_osd_color_bg;
			s_vip2_alpha <= s_vip2_alpha;
			// vip2_YUV444TO422
			s_vip2_YUV444TO422 <= s_vip2_YUV444TO422;
		end
	end

	// wire [8-1:0] out_y, out_u, out_v;
    // wire isp_href_o, isp_vsync_o;
	// assign out_yuv = {out_v[8-1:0], out_u[8-1:0], out_y[8-1:0]};


infinite_isp # ( 
		    .BITS(BITS),
			.SNS_WIDTH(SNS_WIDTH),
			.SNS_HEIGHT(SNS_HEIGHT),
			.CROP_WIDTH(CROP_WIDTH),
			.CROP_HEIGHT(CROP_HEIGHT),
			.BAYER(BAYER),
			.OECF_R_LUT(OECF_R_LUT),
			.OECF_GR_LUT(OECF_GR_LUT),
			.OECF_GB_LUT(OECF_GB_LUT),
			.OECF_B_LUT(OECF_B_LUT),
			.BNR_WEIGHT_BITS(BNR_WEIGHT_BITS),
			.DGAIN_ARRAY_SIZE(DGAIN_ARRAY_SIZE),
			.DGAIN_ARRAY_BITS(DGAIN_ARRAY_BITS),
			.AWB_CROP_LEFT(AWB_CROP_LEFT),
			.AWB_CROP_RIGHT(AWB_CROP_RIGHT),
			.AWB_CROP_TOP(AWB_CROP_TOP),
			.AWB_CROP_BOTTOM(AWB_CROP_BOTTOM),
			.GAMMA_R_LUT(GAMMA_R_LUT),
			.GAMMA_G_LUT(GAMMA_G_LUT),
			.GAMMA_B_LUT(GAMMA_B_LUT),
			.SHARP_WEIGHT_BITS(SHARP_WEIGHT_BITS),
			.NR2D_WEIGHT_BITS(NR2D_WEIGHT_BITS),
			.STAT_OUT_BITS(STAT_OUT_BITS),
			.STAT_HIST_BITS(STAT_HIST_BITS),
			.USE_CROP(USE_CROP),
			.USE_DPC(USE_DPC),
			.USE_BLC(USE_BLC),
			.USE_OECF(USE_OECF),
			.USE_DGAIN(USE_DGAIN),
			.USE_LSC(USE_LSC),
			.USE_BNR(USE_BNR),
			.USE_WB(USE_WB),
			.USE_DEMOSIC(USE_DEMOSIC),
			.USE_CCM(USE_CCM),
			.USE_GAMMA(USE_GAMMA),
			.USE_CSC(USE_CSC),
			.USE_SHARP(USE_SHARP),
			.USE_LDCI(USE_LDCI),
			.USE_2DNR(USE_2DNR),
			.USE_STAT_AE(USE_STAT_AE),
			.USE_AWB(USE_AWB),
			.USE_AE(USE_AE),

			///* ****** VIP1 parameters ******* */
	      	 .VIP1_BITS(VIP1_BITS),
             .VIP1_OSD_RAM_ADDR_BITS(VIP1_OSD_RAM_ADDR_BITS),
	         .VIP1_OSD_RAM_DATA_BITS(VIP1_OSD_RAM_DATA_BITS),
	         .VIP1_USE_HIST_EQU(VIP1_USE_HIST_EQU),
	         .VIP1_USE_SOBEL(VIP1_USE_SOBEL),
	         .VIP1_USE_RGBC(VIP1_USE_RGBC),	  
	         .VIP1_USE_IRC(VIP1_USE_IRC),
	         .VIP1_USE_SCALE(VIP1_USE_SCALE),
	         .VIP1_USE_OSD(VIP1_USE_OSD),					
	         .VIP1_USE_YUVConvFormat(VIP1_USE_YUVConvFormat),
	        

			///* ****** VIP2 parameters ******* */
	      	 .VIP2_BITS(VIP2_BITS),
             .VIP2_OSD_RAM_ADDR_BITS(VIP2_OSD_RAM_ADDR_BITS),
	         .VIP2_OSD_RAM_DATA_BITS(VIP2_OSD_RAM_DATA_BITS),
	         .VIP2_USE_HIST_EQU(VIP1_USE_HIST_EQU),
	         .VIP2_USE_SOBEL(VIP1_USE_SOBEL),
	         .VIP2_USE_RGBC(VIP1_USE_RGBC),	  
	         .VIP2_USE_IRC(VIP1_USE_IRC),
	         .VIP2_USE_SCALE(VIP1_USE_SCALE),
	         .VIP2_USE_OSD(VIP1_USE_OSD),					
	         .VIP2_USE_YUVConvFormat(VIP1_USE_YUVConvFormat)
	    
) infinite_isp_inst

(
	// Clock and Reset
		.pclk(pclk),
		.rst_n(reset_n),
	    // AXI Input
		.in_href(in_href),
		.in_vsync(in_vsync),
		.in_raw(in_raw),
	    .in_href_rgb(in_href_rgb),
	    .in_vsync_rgb(in_vsync_rgb),
	    .in_r(in_r),
	    .in_g(in_g),
	    .in_b(in_b),
	    .isp_out_href(isp_out_href),
	    .isp_out_vsync(isp_out_vsync),		
	    // AXI Output
		//.out_href(out_href1),
		//.out_vsync(out_vsync1),
		// .out_r(out_y),
		// .out_g(out_u),
		// .out_b(out_v),
		.rgb_inp_en(1'b0),
	    // Module Enables
	    .crop_en(s_crop_en),
		.dpc_en(s_dpc_en), 
		.blc_en(s_blc_en),
		.linear_en(s_linear_en),
		.oecf_en(s_oecf_en),
		.dgain_en(s_dgain_en),
		.lsc_en(s_lsc_en), 
		.bnr_en(s_bnr_en),
		.wb_en(s_wb_en),
		.demosic_en(s_demosic_en),
		.ccm_en(s_ccm_en),
		.gamma_en(s_gamma_en),
		.csc_en(s_csc_en),
		.sharp_en(s_sharp_en),
		.ldci_en(s_ldci_en),
		.nr2d_en(s_2dnr_en&FEATURE_FULL[0]),
		.stat_ae_en(s_stat_ae_en),
		.awb_en(s_awb_en),
		.ae_en(s_ae_en),
	    // DPC
		.dpc_threshold(s_dpc_threshold),
		// BLC and Linearization
		.blc_r(s_blc_r), .blc_gr(s_blc_gr), .blc_gb(s_blc_gb), .blc_b(s_blc_b),
		.linear_r(s_linear_r), .linear_gr(s_linear_gr), .linear_gb(s_linear_gb), .linear_b(s_linear_b),
	    // OECF
	    .r_table_clk(r_table_clk), .gr_table_clk(gr_table_clk), .gb_table_clk(gb_table_clk), .b_table_clk(b_table_clk),
	    .r_table_wen(r_table_wen), .gr_table_wen(gr_table_wen), .gb_table_wen(gb_table_wen), .b_table_wen(b_table_wen),
	    .r_table_ren(r_table_ren), .gr_table_ren(gr_table_ren), .gb_table_ren(gb_table_ren), .b_table_ren(b_table_ren),
	    .r_table_addr(r_table_addr), .gr_table_addr(gr_table_addr), .gb_table_addr(gb_table_addr), .b_table_addr(b_table_addr),
	    .r_table_wdata(r_table_wdata), .gr_table_wdata(gr_table_wdata), .gb_table_wdata(gb_table_wdata), .b_table_wdata(b_table_wdata),
	    .r_table_rdata(r_table_rdata), .gr_table_rdata(gr_table_rdata), .gb_table_rdata(gb_table_rdata), .b_table_rdata(b_table_rdata),
	    // BNR 
	    .bnr_space_kernel_r(s_bnr_space_kernel_r), .bnr_space_kernel_g(s_bnr_space_kernel_g), .bnr_space_kernel_b(s_bnr_space_kernel_b),
	    .bnr_color_curve_x_r(s_bnr_color_curve_x_r), .bnr_color_curve_y_r(s_bnr_color_curve_y_r),
	    .bnr_color_curve_x_g(s_bnr_color_curve_x_g), .bnr_color_curve_y_g(s_bnr_color_curve_y_g),
	    .bnr_color_curve_x_b(s_bnr_color_curve_x_b), .bnr_color_curve_y_b(s_bnr_color_curve_y_b),
		// DG
		.dgain_isManual(s_dgain_isManual),
		.dgain_man_index(s_dgain_man_index),
		.dgain_array(s_dgain_array),
		.dgain_index_out(dgain_index_out), 
		// WB
		.wb_rgain(s_wb_rgain), .wb_bgain(s_wb_bgain),
		// CCM
		.ccm_rr(s_ccm_rr), .ccm_rg(s_ccm_rg), .ccm_rb(s_ccm_rb),
		.ccm_gr(s_ccm_gr), .ccm_gg(s_ccm_gg), .ccm_gb(s_ccm_gb),
		.ccm_br(s_ccm_br), .ccm_bg(s_ccm_bg), .ccm_bb(s_ccm_bb),
	    // GAMMA
		.gamma_table_r_clk  (gamma_table_r_clk),
		.gamma_table_r_wen  (gamma_table_r_wen),
		.gamma_table_r_ren  (gamma_table_r_ren),
		.gamma_table_r_addr (gamma_table_r_addr),
		.gamma_table_r_wdata(gamma_table_r_wdata),
		.gamma_table_r_rdata(gamma_table_r_rdata),
		
		.gamma_table_g_clk  (gamma_table_g_clk),
		.gamma_table_g_wen  (gamma_table_g_wen),
		.gamma_table_g_ren  (gamma_table_g_ren),
		.gamma_table_g_addr (gamma_table_g_addr),
		.gamma_table_g_wdata(gamma_table_g_wdata),
		.gamma_table_g_rdata(gamma_table_g_rdata),
		
		.gamma_table_b_clk  (gamma_table_b_clk),
		.gamma_table_b_wen  (gamma_table_b_wen),
		.gamma_table_b_ren  (gamma_table_b_ren),
		.gamma_table_b_addr (gamma_table_b_addr),
		.gamma_table_b_wdata(gamma_table_b_wdata),
		.gamma_table_b_rdata(gamma_table_b_rdata),
	    // CSC
		.in_conv_standard(s_in_conv_standard),
		// SHARP
		.luma_kernel(s_luma_kernel),
		.sharpen_strength(s_sharpen_strength),
	    // 2DNR
		.nr2d_diff(s_nr2d_diff),
		.nr2d_weight(s_nr2d_weight),
		/*
	    // STAT_AE
		.stat_ae_rect_x(s_stat_ae_rect_x), .stat_ae_rect_y(s_stat_ae_rect_y), .stat_ae_rect_w(s_stat_ae_rect_w), .stat_ae_rect_h(s_stat_ae_rect_h),
		.stat_ae_done(stat_ae_done), .stat_ae_pix_cnt(stat_ae_pix_cnt), .stat_ae_sum(stat_ae_sum),
		.stat_ae_hist_clk(stat_ae_hist_clk), .stat_ae_hist_out(stat_ae_hist_out), .stat_ae_hist_addr(stat_ae_hist_addr), .stat_ae_hist_data(stat_ae_hist_data),
		*/
	    // AE
	    .center_illuminance(s_center_illuminance),
	    .skewness(s_skewness),
		.ae_crop_left(s_ae_crop_left),
		.ae_crop_right(s_ae_crop_right),
		.ae_crop_top(s_ae_crop_top),
		.ae_crop_bottom(s_ae_crop_bottom),
	    .ae_response(ae_response),
	    .ae_result_skewness(ae_result_skewness),
	    .ae_response_debug(ae_response_debug),
	    .ae_done(ae_done),
	    // AWB
		//.r_gain(r_gain), .b_gain(b_gain), .high(high),
		.awb_underexposed_limit(s_awb_underexposed_limit), .awb_overexposed_limit(s_awb_overexposed_limit), .awb_frames(s_awb_frames), .final_r_gain(final_r_gain), .final_b_gain(final_b_gain),

		// .in_y(out_y),
		// .in_u(out_u),
		// .in_v(out_v),
		
		// VIP1
        .scale_pclk1(scale_pclk1),
		.out_pclk(out_pclk1),
		.out_href(out_href1),
		.out_vsync(out_vsync1),
		.out_r(out_r1),
		.out_g(out_g1),
		.out_b(out_b1),
		// Module Enables
		.hist_equ_en(s_vip1_hist_equ_en&FEATURE_FULL[0]),
		.sobel_en(s_vip1_sobel_en),
		.rgbc_en(s_vip1_yuv2rgb_en),
		.irc_en(s_vip1_crop_en),
		.dscale_en(s_vip1_dscale_en),
		.osd_en(s_vip1_osd_en),
		.yuv444to422_en(s_vip1_yuv444to422_en),

		// RGBC
		.in_conv_standard_rgbc(s_vip1_in_conv_standard),
		// IRC
		.crop_x(s_vip1_crop_x),
		.crop_y(s_vip1_crop_y),  // TODO: NO support in Wrapper 
		.irc_output(s_vip1_irc_output),
		// SCALE
		.s_in_crop_w(s_vip1_s_in_crop_w),
		.s_in_crop_h(s_vip1_s_in_crop_h),
		.s_out_crop_w(s_vip1_s_out_crop_w),
		.s_out_crop_h(s_vip1_s_out_crop_h),
		.dscale_w(s_vip1_dscale_w),
		.dscale_h(s_vip1_dscale_h),
		// OSD
		.osd_x(s_vip1_osd_x), .osd_y(s_vip1_osd_y), .osd_w(s_vip1_osd_w), .osd_h(s_vip1_osd_h),
		.osd_color_fg(s_vip1_osd_color_fg), .osd_color_bg(s_vip1_osd_color_bg),
		.osd_alpha(s_vip1_alpha),
		.osd_ram_clk(vip1_osd_ram_clk),
		.osd_ram_wen(vip1_osd_ram_wen),
		.osd_ram_ren(vip1_osd_ram_ren),
		.osd_ram_addr(vip1_osd_ram_addr),
		.osd_ram_wdata(vip1_osd_ram_wdata),
		.osd_ram_rdata(vip1_osd_ram_rdata),
		// vip1_YUV444TO422
		.YUV444TO422(s_vip1_YUV444TO422),

        // VIP2 
        .scale_pclk2(scale_pclk2),
		.out_pclk2(out_pclk2),
		.out_href2(out_href2),
		.out_vsync2(out_vsync2),
		.out_r2(out_r2),
		.out_g2(out_g2),
		.out_b2(out_b2),
		// Module Enables
		.hist_equ_en2(s_vip2_hist_equ_en&FEATURE_FULL[0]),
		.sobel_en2(s_vip2_sobel_en),
		.rgbc_en2(s_vip2_yuv2rgb_en),
		.irc_en2(s_vip2_crop_en),
		.dscale_en2(s_vip2_dscale_en),
		.osd_en2(s_vip2_osd_en),
		.yuv444to422_en2(s_vip2_yuv444to422_en),

		// RGBC
		.in_conv_standard_rgbc2(s_vip2_in_conv_standard),
		// IRC
		.crop_x2(s_vip2_crop_x),
		.crop_y2(s_vip2_crop_y),  // TODO: NO support in Wrapper 
		.irc_output2(s_vip2_irc_output),
		// SCALE
		.s_in_crop_w2(s_vip2_s_in_crop_w),
		.s_in_crop_h2(s_vip2_s_in_crop_h),
		.s_out_crop_w2(s_vip2_s_out_crop_w),
		.s_out_crop_h2(s_vip2_s_out_crop_h),
		.dscale_w2(s_vip2_dscale_w),
		.dscale_h2(s_vip2_dscale_h),
		// OSD
		.osd_x2(s_vip2_osd_x), .osd_y2(s_vip2_osd_y), .osd_w2(s_vip2_osd_w), .osd_h2(s_vip2_osd_h),
		.osd_color_fg2(s_vip2_osd_color_fg), .osd_color_bg2(s_vip2_osd_color_bg),
		.osd_alpha2(s_vip2_alpha),
		.osd_ram_clk2(vip2_osd_ram_clk),
		.osd_ram_wen2(vip2_osd_ram_wen),
		.osd_ram_ren2(vip2_osd_ram_ren),
		.osd_ram_addr2(vip2_osd_ram_addr),
		.osd_ram_wdata2(vip2_osd_ram_wdata),
		.osd_ram_rdata2(vip2_osd_ram_rdata),
		// vip1_YUV444TO422
		.YUV444TO4222(s_vip2_YUV444TO422)

);

endmodule