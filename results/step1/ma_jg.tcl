clear -all

analyze -sv12 +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/ibex/original +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/stubs {/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/ibex/original/ibex_pkg.sv}
analyze -sv12 +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/ibex/original +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/stubs {/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/ibex/original/ibex_load_store_unit.sv}
analyze -sv12 +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/ibex/original +incdir+/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/rtl/stubs {/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/assertions/translated/ma_bind.sv}

elaborate -top ibex_load_store_unit -bbox_m prim_buf -bbox_m prim_secded_inv_39_32_dec -bbox_m prim_secded_inv_39_32_enc
clock clk_i
reset -expression {!rst_ni}

prove -all

report -results -force -file {/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/results/step1/ma_fpv_baseline.txt}
catch {report -vacuity -force -file {/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/results/step1/ma_vacuity.txt}}
catch {report -cov     -force -file {/home/sharjeel/sharjeelphd/Research/Ai_autoasser_rv/ai-autotrans-rv/results/step1/ma_cov.txt}}
exit
