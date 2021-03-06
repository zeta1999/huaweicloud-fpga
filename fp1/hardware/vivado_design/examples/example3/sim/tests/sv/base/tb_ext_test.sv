//
//------------------------------------------------------------------------------
//     Copyright (c) 2017 Huawei Technologies Co., Ltd. All Rights Reserved.
//
//     This program is free software; you can redistribute it and/or modify
//     it under the terms of the Huawei Software License (the "License").
//     A copy of the License is located in the "LICENSE" file accompanying 
//     this file.
//
//     This program is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//     Huawei Software License for more details. 
//------------------------------------------------------------------------------


`ifndef _TB_EXT_TEST_SV_
`define _TB_EXT_TEST_SV_

// ./tb_pkg.svh
`include "tb_pkg.svh"

// ./common/common_reg.svh
`include "common_reg.svh"

// ./common/tb_reg_cfg.svh
`include "tb_reg_cfg.svh"

// ./common/ext_stims.sv
`include "ext_stims.sv"

// ./common/ext_rm.sv
`include "ext_rm.sv"

// ./common/ext_cpu_model_cb.svh
`include "ext_cpu_model_cb.svh"

// `ifdef EXAMPLE_ENABLE

class tb_ext_test extends tb_test;

    protected tb_reg_cfg m_cfg;

    ext_stims            m_ext_stim;

    ext_rm               m_ext_rm;

    ext_cpu_model_cb     m_cpu_cb;

    // Register tb_ext_test into test_top

    `tb_register_test(tb_ext_test)

    function new(string name = "tb_ext_test");
        super.new(name);
    endfunction : new

    function void build();
        m_cpu_cb  = new("m_cpu_cb"  );
        m_ext_stim= new("m_ext_stim");
        m_ext_rm  = new("m_ext_rm"  );
        super.build();
    endfunction : build

    function void connect();
        super.connect();
        // Register Axi stims to generator
        m_tb_env.m_axi_gen.reg_stims(m_ext_stim);
        // Bind rm and rm_wrapper
        m_tb_env.m_rm_wrapper.bind_rm(m_ext_rm);
        // Append Cpu callback to cpu model
        m_tb_env.m_cpu_model.append_callback(m_cpu_cb);
    endfunction : connect

    task start();
        super.start();
        m_tb_env.m_axi_gen.start();
        m_tb_env.m_axismc_bfm.start();
        m_tb_env.m_axismd_bfm.start();
        m_tb_env.m_axissc_bfm.start();
        m_tb_env.m_axissd_bfm.start();
        m_tb_env.m_cpu_model.start();
        m_tb_env.m_rm_wrapper.start();
        // Force DUT ddr initial_done to accelerate simulation
        `tb_ddr_dut_disable_init(a)
        `tb_ddr_dut_disable_init(b)
        `tb_ddr_dut_disable_init(d)
    endtask : start

    task run();
        bit    check;
        string info, err_info;
        REG_ADDR_t addr;
        REG_DATA_t ver_time, ver_type;
        REG_DATA_t oppos;
        REG_DATA_t wdata, rdata;
        m_cfg = new();
        // ----------------------------------------
        // STEP1: Check version
        // ----------------------------------------
        `tb_info(m_inst_name, {"\n----------------------------------------\n", 
                               " STEP1: Checking DUV Infomation\n", 
                               "----------------------------------------\n"})
        m_tb_env.m_reg_gen.read(g_reg_ver_time, ver_time);
        m_tb_env.m_reg_gen.read(g_reg_ver_type, ver_type);
        $sformat(info, {"+-------------------------------+\n", 
                        "|    DEMO version : %08x    |\n", 
                        "|    DEMO type    : %08x    |\n", 
                        "+-------------------------------+"}, ver_time, ver_type);
        `tb_info(m_inst_name, info)
        check = (ver_type == m_cfg.vertype);
        $sformat(info, {"+-------------------------------+\n", 
                        "|    Demo Check   : %s        |\n", 
                        "+-------------------------------+"}, check ? "PASS" : "FAIL");
        if (!check) begin
            $sformat(info, "%s\n\nDetail info: Type of Example3 should be 0x%x but get 0x%x!\n",
                     info, m_cfg.vertype, ver_type);
            `tb_error(m_inst_name, info)
            return;
        end else begin
            `tb_info(m_inst_name, info)
        end
        #10ns;

        // ----------------------------------------
        // STEP2: Test register
        // ----------------------------------------
        `tb_info(m_inst_name, {"\n----------------------------------------\n", 
                               " STEP2: Checking DUV Test Register\n", 
                               "----------------------------------------\n"})
        wdata = 'h5a5aa5a5;
        m_tb_env.m_reg_gen.write(g_reg_oppos_data, wdata);
        #10ns;
        m_tb_env.m_reg_gen.read(g_reg_oppos_data, oppos);
        check = (wdata == (~oppos));

        m_tb_env.m_reg_gen.read(g_reg_oppos_addr, rdata);

        // No not check test register
        // $sformat(info, {"+-------------------------------+\n", 
        //                 "|    Test Register: %s        |\n", 
        //                 "+-------------------------------+"}, check ? "PASS" : "FAIL");
        // if (!check) begin
        //     $sformat(err_info, "\n\nDetail info: Write 0x%x but read 0x%x which should be 0x%x!\n",
        //              wdata, oppos, ~wdata);
        // end
        info  = "+-------------------------------+";
        oppos = {~g_reg_oppos_data[17 : 2], ~g_reg_oppos_data[17 : 2]};
        check &= (oppos == rdata);
        begin
            string info_tmp;
            $sformat(info_tmp, {"%s\n|    Addr Test Register: %s   |\n", 
                                "+-------------------------------+"}, info, check ? "PASS" : "FAIL");
            info = info_tmp;
        end
        if (!check) begin
            info = {info, err_info};
            $sformat(info, "%s\n\nDetail info: Write addr 0x%x but read 0x%x which should be 0x%x!\n",
                     info, g_reg_oppos_data, rdata, oppos);
            `tb_error(m_inst_name, info)
            return;
        end else begin
            `tb_info(m_inst_name, info)
        end
        #25us;

        // ----------------------------------------
        // STEP3: Test DMA
        // ----------------------------------------
        `tb_info(m_inst_name, {"\n----------------------------------------\n", 
                               " STEP3: Checking DMA\n", 
                               "----------------------------------------\n"})
        // Start sending stimulate
        m_ext_stim.start(); 
        // Wait stimulate sending over
        m_ext_stim.wait_done();

        // Wait sometimes until all data have been processed by DUT
        #5us;

        check &= m_ext_rm.get_check_status();
        $sformat(info, {"+-------------------------------+\n", 
                        "|    Test DMA     : %s        |\n", 
                        "+-------------------------------+"}, check ? "PASS" : "FAIL");
        if (!check) begin
            `tb_error(m_inst_name, info)
            return;
        end else begin
            `tb_info(m_inst_name, info)
        end
        $display("\nTestcase PASSED!\n");
    endtask : run

    task stop();
        super.stop();
        m_tb_env.m_axi_gen.stop();
        m_tb_env.m_axismc_bfm.stop();
        m_tb_env.m_axismd_bfm.stop();
        m_tb_env.m_axissc_bfm.stop();
        m_tb_env.m_axissd_bfm.stop();
        m_tb_env.m_cpu_model.stop();
        m_tb_env.m_rm_wrapper.stop();
    endtask : stop

endclass : tb_ext_test

// `endif // EXAMPLE_ENABLE

`endif // _TB_EXT_TEST_SV_

