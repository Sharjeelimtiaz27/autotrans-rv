clear -all

analyze -sv12 +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/ibex/original +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/stubs {/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/ibex/original/ibex_pkg.sv}
analyze -sv12 +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/ibex/original +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/stubs {/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/ibex/original/ibex_alu.sv}
analyze -sv12 +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/ibex/original +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/stubs {/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/ibex/original/ibex_multdiv_fast.sv}
analyze -sv12 +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/ibex/original +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/stubs {/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/ibex/original/ibex_multdiv_slow.sv}
analyze -sv12 +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/ibex/original +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/stubs {/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/ibex/original/ibex_ex_block.sv}
analyze -sv12 +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/ibex/original +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/stubs {/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/ibex/original/ibex_decoder.sv}
analyze -sv12 +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/ibex/original +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/stubs {/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/ibex/original/ibex_controller.sv}
analyze -sv12 +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/ibex/original +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/stubs {/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/ibex/original/ibex_id_stage.sv}
analyze -sv12 +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/ibex/original +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/stubs {/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/assertions/translated/ie_bind.sv}

elaborate -top ibex_id_stage
clock clk_i
reset -expression {!rst_ni}

prove -all

report -results -force -file {/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/results/step1/ie_fpv_baseline.txt}
catch {report -vacuity -force -file {/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/results/step1/ie_vacuity.txt}}
catch {report -cov     -force -file {/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/results/step1/ie_cov.txt}}
exit
