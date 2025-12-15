// Infinite-ISP RTL Simulation Filelist
// Include directories
+incdir+./rtl
+incdir+./tb

// RTL Source Files
./rtl/isp_utils.v
./rtl/isp_crop.v
./rtl/isp_dpc.v
./rtl/isp_blc.v
./rtl/isp_oecf.v
./rtl/isp_dgain.v
./rtl/isp_bnr.v
./rtl/isp_jbf.v
./rtl/isp_greenIntrp.v
./rtl/isp_wb.v
./rtl/isp_demosaic.v
./rtl/isp_ccm.v
./rtl/isp_gamma.v
./rtl/isp_csc.v
./rtl/isp_sharpen.v
./rtl/isp_2dnr.v
./rtl/isp_ae.v
./rtl/isp_awb.v
./rtl/crop_awb_ae.v
./rtl/isp_dgain_update.v
./rtl/isp_top.v
./rtl/vip_yuv2rgb.v
./rtl/vip_crop.v
./rtl/vip_dscale.v
./rtl/vip_scale_crop.v
./rtl/vip_osd.v
./rtl/vip_YUVConvFormat.v
./rtl/vip_top.v
./rtl/infinite_isp.v

// Testbench Source Files
./tb/tb_dvp_helper.v
./tb/Clock_divider_sim.v
./tb/tb_seq_simulation.sv
