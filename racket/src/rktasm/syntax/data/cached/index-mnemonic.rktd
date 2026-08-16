;; 助记符索引: mnemonic -> ((encoding-id template constraints) ...)
;; 生成命令: racket syntax/gen-cached.rkt

(stp
  ("STP_32_ldstpair_post" "WZR, WZR, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option" "imm__12"))
  ("STP_S_ldstpair_post" "SUInteger, SUInteger, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St1" "St2" "XnSP_option" "imm__12"))
  ("STP_D_ldstpair_post" "DUInteger, DUInteger, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt1" "Dt2" "XnSP_option" "imm__15"))
  ("STP_64_ldstpair_post" "XZR, XZR, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__15"))
  ("STP_Q_ldstpair_post" "QUInteger, QUInteger, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm__16"))
  ("STP_32_ldstpair_off" "WZR, WZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option" "imm7_option"))
  ("STP_S_ldstpair_off" "SUInteger, SUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St1" "St2" "XnSP_option" "imm7_option"))
  ("STP_D_ldstpair_off" "DUInteger, DUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt1" "Dt2" "XnSP_option" "imm7_option__2"))
  ("STP_64_ldstpair_off" "XZR, XZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm7_option__2"))
  ("STP_Q_ldstpair_off" "QUInteger, QUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm7_option__3"))
  ("STP_32_ldstpair_pre" "WZR, WZR, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option" "imm__12"))
  ("STP_S_ldstpair_pre" "SUInteger, SUInteger, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St1" "St2" "XnSP_option" "imm__12"))
  ("STP_D_ldstpair_pre" "DUInteger, DUInteger, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt1" "Dt2" "XnSP_option" "imm__15"))
  ("STP_64_ldstpair_pre" "XZR, XZR, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__15"))
  ("STP_Q_ldstpair_pre" "QUInteger, QUInteger, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm__16"))
)

(sunpklo
  ("sunpklo_z_z_" "ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(ldp
  ("LDP_32_ldstpair_post" "WZR, WZR, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option" "imm__12"))
  ("LDP_S_ldstpair_post" "SUInteger, SUInteger, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St1" "St2" "XnSP_option" "imm__12"))
  ("LDP_D_ldstpair_post" "DUInteger, DUInteger, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt1" "Dt2" "XnSP_option" "imm__15"))
  ("LDP_64_ldstpair_post" "XZR, XZR, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__15"))
  ("LDP_Q_ldstpair_post" "QUInteger, QUInteger, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm__16"))
  ("LDP_32_ldstpair_off" "WZR, WZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option" "imm7_option"))
  ("LDP_S_ldstpair_off" "SUInteger, SUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St1" "St2" "XnSP_option" "imm7_option"))
  ("LDP_D_ldstpair_off" "DUInteger, DUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt1" "Dt2" "XnSP_option" "imm7_option__2"))
  ("LDP_64_ldstpair_off" "XZR, XZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm7_option__2"))
  ("LDP_Q_ldstpair_off" "QUInteger, QUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm7_option__3"))
  ("LDP_32_ldstpair_pre" "WZR, WZR, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option" "imm__12"))
  ("LDP_S_ldstpair_pre" "SUInteger, SUInteger, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St1" "St2" "XnSP_option" "imm__12"))
  ("LDP_D_ldstpair_pre" "DUInteger, DUInteger, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt1" "Dt2" "XnSP_option" "imm__15"))
  ("LDP_64_ldstpair_pre" "XZR, XZR, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__15"))
  ("LDP_Q_ldstpair_pre" "QUInteger, QUInteger, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm__16"))
)

(blraaz
  ("BLRAAZ_64_branch_reg" "XZR" (("Rn" (reg-range 0 31))) ("XnOrXZR"))
)

(sqcvtu
  ("sqcvtu_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("sqcvtu_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
)

(sabdl
  ("SABDL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(cpyfmrt
  ("CPYFMRT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(cpymt
  ("CPYMT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(cpyfpwn
  ("CPYFPWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(zipq2
  ("zipq2_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(ld1sw
  ("ld1sw_z_p_br_s64" "{Z UInteger .D}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1sw_z_p_bi_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1sw_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1sw_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1sw_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ld1sw_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1sw_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
)

(cbz
  ("CBZ_32_compbranch" "WZR, SInteger" (("imm19" (imm-range 0 524287 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "imm19_offset"))
  ("CBZ_64_compbranch" "XZR, SInteger" (("imm19" (imm-range 0 524287 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "imm19_offset"))
)

(casalt
  ("CASALT_C64_comswap_unpriv" "XZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
)

(usubwb
  ("usubwb_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(sttxr
  ("STTXR_SR32_ldstexclr_unpriv" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "WtOrWZR__4" "XnSP_option"))
  ("STTXR_SR64_ldstexclr_unpriv" "WZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "XtOrXZR__11" "XnSP_option"))
)

(setgoptn
  ("SETGOPTN_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__4" "XnOrXZR__8"))
)

(rcwsswppl
  ("RCWSSWPPL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(sha1p
  ("SHA1P_QSV_cryptosha3" "QUInteger, SUInteger, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Qd" "Sn__2" "Vm__7"))
)

(addhn
  ("ADDHN_asimddiff_N" "VUInteger.8B, VUInteger.8H, VUInteger.8H" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(ldtrsw
  ("LDTRSW_64_ldst_unpriv" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
)

(fminv
  ("fminv_v_p_z_" "HUInteger, PUInteger, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V__5" "Pg" "Zn"))
  ("FMINV_asimdall_only_H" "HUInteger, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_hv" "Vn"))
  ("FMINV_asimdall_only_SD" "SUInteger, VUInteger.4S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vn"))
)

(uxth
  ("uxth_z_p_z_m" "ZUInteger.S, PUInteger/M, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("uxth_z_p_z_z" "ZUInteger.S, PUInteger/Z, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
)

(ldnf1b
  ("ldnf1b_z_p_bi_u8" "{Z UInteger .B}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldnf1b_z_p_bi_u16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldnf1b_z_p_bi_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldnf1b_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
)

(autibsppcr
  ("AUTIBSPPCR_64LRR_dp_1src" "XZR" (("Rn" (reg-range 0 31))) ("XnOrXZR__11"))
)

(str
  ("str_p_bi_" "PUInteger, [SP]" (("imm9h" (imm-range 0 63 1)) ("imm9l" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Pt" (reg-range 0 15))) ("Pt__2" "XnSP__3"))
  ("str_z_bi_" "ZUInteger, [SP]" (("imm9h" (imm-range 0 63 1)) ("imm9l" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "XnSP__3"))
  ("str_za_ri_" "ZA[WUInteger, UInteger, [SP]" (("Rn" (reg-range 0 31)) ("off4" (imm-range 0 15 1))) ("Wv__2" "offs__7" "XnSP__3"))
  ("str_zt_br_" "ZT0, [SP]" (("Rn" (reg-range 0 31))) ("XnSP__3"))
  ("STR_B_ldst_immpost" "BUInteger, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option"))
  ("STR_Q_ldst_immpost" "QUInteger, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option"))
  ("STR_H_ldst_immpost" "HUInteger, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option"))
  ("STR_32_ldst_immpost" "WZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("STR_S_ldst_immpost" "SUInteger, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option"))
  ("STR_64_ldst_immpost" "XZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
  ("STR_D_ldst_immpost" "DUInteger, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option"))
  ("STR_B_ldst_immpre" "BUInteger, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option"))
  ("STR_Q_ldst_immpre" "QUInteger, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option"))
  ("STR_H_ldst_immpre" "HUInteger, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option"))
  ("STR_32_ldst_immpre" "WZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("STR_S_ldst_immpre" "SUInteger, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option"))
  ("STR_64_ldst_immpre" "XZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
  ("STR_D_ldst_immpre" "DUInteger, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option"))
  ("STR_B_ldst_regoff" "BUInteger, [SP WZR UXTW]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option" "WorX_choice" "S_option"))
  ("STR_BL_ldst_regoff" "BUInteger, [SP XZR]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option" "XmOrXZR__2"))
  ("STR_Q_ldst_regoff" "QUInteger, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option" "WorX_choice"))
  ("STR_H_ldst_regoff" "HUInteger, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option" "WorX_choice"))
  ("STR_32_ldst_regoff" "WZR, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "WorX_choice"))
  ("STR_S_ldst_regoff" "SUInteger, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option" "WorX_choice"))
  ("STR_64_ldst_regoff" "XZR, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "WorX_choice"))
  ("STR_D_ldst_regoff" "DUInteger, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option" "WorX_choice"))
  ("STR_B_ldst_pos" "BUInteger, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option" "imm12_option"))
  ("STR_Q_ldst_pos" "QUInteger, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option" "imm12_option__3"))
  ("STR_H_ldst_pos" "HUInteger, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option" "imm12_option__4"))
  ("STR_32_ldst_pos" "WZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm12_option__6"))
  ("STR_S_ldst_pos" "SUInteger, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option" "imm12_option__6"))
  ("STR_64_ldst_pos" "XZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm12_option__8"))
  ("STR_D_ldst_pos" "DUInteger, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option" "imm12_option__8"))
)

(blr
  ("BLR_64_branch_reg" "XZR" (("Rn" (reg-range 0 31))) ("XnOrXZR"))
)

(ctermeq
  ("ctermeq_rr_" "WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ())
)

(ldumaxl
  ("LDUMAXL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDUMAXL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(ldbfmin
  ("LDBFMIN_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(usmmla
  ("usmmla_z_zzz_" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("USMMLA_asimdsame2_G" "VUInteger.4S, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "Vm"))
)

(orrs
  ("orrs_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
)

(ld1rsw
  ("ld1rsw_z_p_bi_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
)

(bfm
  ("BFM_32M_bitfield" "WZR, WZR, UInteger, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR" "immr" "imms"))
  ("BFM_64M_bitfield" "XZR, XZR, UInteger, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11" "immr__2" "imms__2"))
)

(f1cvtl
  ("f1cvtl_mz2_z8_" "{Z UInteger .H- Z UInteger .H}, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
  ("F1CVTL_asimdmisc_V" "VUInteger.8H, VUInteger.8B" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(cpyfmrtn
  ("CPYFMRTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(cblt
  ("CBLT_32_imm" "WZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "imm_cbr" "imm9_offset"))
  ("CBLT_64_imm" "XZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "imm_cbr" "imm9_offset"))
)

(shadd
  ("shadd_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("SHADD_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(crc32w
  ("CRC32W_32C_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR__2" "WnOrWZR__4" "WmOrWZR__5"))
)

(bfmop4s
  ("bfmop4s_za32_zz_h1x1" "ZAUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
  ("bfmop4s_za32_zz_h1x2" "ZAUInteger.S, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("bfmop4s_za32_zz_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("bfmop4s_za32_zz_h2x2" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("bfmop4s_za_zz_h1x1" "ZAUInteger.H, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn_mortlach" "Zm_mortlach"))
  ("bfmop4s_za_zz_h1x2" "ZAUInteger.H, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("bfmop4s_za_zz_h2x1" "ZAUInteger.H, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("bfmop4s_za_zz_h2x2" "ZAUInteger.H, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
)

(stur
  ("STUR_B_ldst_unscaled" "BUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option" "imm9_option"))
  ("STUR_Q_ldst_unscaled" "QUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option" "imm9_option"))
  ("STUR_H_ldst_unscaled" "HUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option" "imm9_option"))
  ("STUR_32_ldst_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
  ("STUR_S_ldst_unscaled" "SUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option" "imm9_option"))
  ("STUR_64_ldst_unscaled" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
  ("STUR_D_ldst_unscaled" "DUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option" "imm9_option"))
)

(uqrshr
  ("uqrshr_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}, UInteger" (("imm4" (imm-range 0 15 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("uqrshr_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}, UInteger" (("imm5" (imm-range 0 31 1)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
)

(sqxtn
  ("SQXTN_asisdmisc_N" "BUInteger, HUInteger" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vb_option__3" "Va_option__3"))
  ("SQXTN_asimdmisc_N" "VUInteger.8B, VUInteger.8H" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(adr
  ("adr_z_az_d_s32_scaled" "ZUInteger.D, [Z UInteger .D Z UInteger .D SXTW]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__3" "Zm__3"))
  ("adr_z_az_d_u32_scaled" "ZUInteger.D, [Z UInteger .D Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__3" "Zm__3"))
  ("adr_z_az_sd_same_scaled" "ZUInteger.S, [Z UInteger . S Z UInteger . S]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__3" "Zm__3"))
  ("ADR_only_pcreladdr" "XZR, SInteger" (("immlo" (imm-range 0 3 1)) ("immhi" (imm-range 0 524287 1)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "immhiimmlo_offset"))
)

(cpyert
  ("CPYERT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(cntp
  ("cntp_r_p_p_" "XUInteger, PUInteger, PUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Rd" (reg-range 0 31))) ("Xd__2" "Pg__2" "Pn__3"))
  ("cntp_r_pn_" "XUInteger, PNUInteger.B, VLx2" (("size" (element-size B H S D)) ("PNn" (reg-range 0 15)) ("Rd" (reg-range 0 31))) ("Xd__2" "PNn"))
)

(decb
  ("decb_r_rs_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(cpymtrn
  ("CPYMTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(gcsb
  ("GCSB_HD_hints" "DSYNC" () ())
)

(setgmtn
  ("SETGMTN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__9" "XsOrXZR__8"))
)

(rcwsseta
  ("RCWSSETA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(sel
  ("sel_z_p_zz_" "ZUInteger.B, PUInteger, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pv" "Zn__2" "Zm"))
  ("sel_p_p_pp_" "PUInteger.B, PUInteger, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
  ("sel_mz_p_zz_2" "{Z UInteger . B - Z UInteger . B}, PNUInteger, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "PNv" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("sel_mz_p_zz_4" "{Z UInteger . B - Z UInteger . B}, PNUInteger, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "PNv" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
)

(nbsl
  ("nbsl_z_zzz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm" "Zk"))
)

(compact
  ("compact_z_p_z_s" "ZUInteger.B, PUInteger, ZUInteger.B" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("compact_z_p_z_" "ZUInteger.S, PUInteger, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
)

(smlal
  ("smlal_za_zzi_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
  ("smlal_za_zzi_2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm__2"))
  ("smlal_za_zzi_4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm__2"))
  ("smlal_za_zzv_2x1" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn2" "Zm__2"))
  ("smlal_za_zzv_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
  ("smlal_za_zzv_4x1" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn4" "Zm__2"))
  ("smlal_za_zzw_2x2" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("smlal_za_zzw_4x4" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("SMLAL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("SMLAL_asimdelem_L" "VUInteger.4S, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
)

(strb
  ("STRB_32_ldst_immpost" "WZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("STRB_32_ldst_immpre" "WZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("STRB_32B_ldst_regoff" "WZR, [SP WZR UXTW]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "WorX_choice" "S_option"))
  ("STRB_32BL_ldst_regoff" "WZR, [SP XZR]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "XmOrXZR__2"))
  ("STRB_32_ldst_pos" "WZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm12_option"))
)

(sm3partw2
  ("SM3PARTW2_VVV4_cryptosha512_3" "VUInteger.4S, VUInteger.4S, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6" "Vm__7"))
)

(sysp
  ("SYSP_CR_syspairinstrs" "UInteger, CUInteger, CUInteger, UInteger" (("Rt" (reg-range 0 31))) ("SYSP_optional_xt1_xt2"))
)

(ldfmaxnmal
  ("LDFMAXNMAL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMAXNMAL_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMAXNMAL_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(autibsppc
  ("AUTIBSPPC_only_dp_1src_imm" "SInteger" (("imm16" (imm-range 0 65535 1))) ("imm16_offset"))
)

(fscale
  ("fscale_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("fscale_mz_zzv_2x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
  ("fscale_mz_zzv_4x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
  ("fscale_mz_zzw_2x2" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
  ("fscale_mz_zzw_4x4" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
  ("FSCALE_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FSCALE_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(stlurb
  ("STLURB_32_ldapstl_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
)

(sbcs
  ("SBCS_32_addsub_carry" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("SBCS_64_addsub_carry" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
)

(st1
  ("ST1_asisdlse_R4_4v" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
  ("ST1_asisdlse_R3_3v" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
  ("ST1_asisdlse_R1_1v" "{V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
  ("ST1_asisdlse_R2_2v" "{V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
  ("ST1_asisdlsep_R4_r4" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
  ("ST1_asisdlsep_R3_r3" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
  ("ST1_asisdlsep_R1_r1" "{V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "Xm__2"))
  ("ST1_asisdlsep_R2_r2" "{V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
  ("ST1_asisdlsep_I4_i4" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], 32" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "imm_option"))
  ("ST1_asisdlsep_I3_i3" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], 24" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "imm_option__3"))
  ("ST1_asisdlsep_I1_i1" "{V UInteger . 8B}, [SP], 8" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "imm_option__5"))
  ("ST1_asisdlsep_I2_i2" "{V UInteger . 8B V UInteger . 8B}, [SP], 16" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "imm_option__6"))
  ("ST1_asisdlso_B1_1b" "{V UInteger . B}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
  ("ST1_asisdlso_H1_1h" "{V UInteger . H}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
  ("ST1_asisdlso_S1_1s" "{V UInteger . S}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
  ("ST1_asisdlso_D1_1d" "{V UInteger . D}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
  ("ST1_asisdlsop_BX1_r1b" "{V UInteger . B}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "Xm__2"))
  ("ST1_asisdlsop_HX1_r1h" "{V UInteger . H}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "Xm__2"))
  ("ST1_asisdlsop_SX1_r1s" "{V UInteger . S}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "Xm__2"))
  ("ST1_asisdlsop_DX1_r1d" "{V UInteger . D}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "Xm__2"))
  ("ST1_asisdlsop_B1_i1b" "{V UInteger . B}, [UInteger], [SP], 1" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
  ("ST1_asisdlsop_H1_i1h" "{V UInteger . H}, [UInteger], [SP], 2" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
  ("ST1_asisdlsop_S1_i1s" "{V UInteger . S}, [UInteger], [SP], 4" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
  ("ST1_asisdlsop_D1_i1d" "{V UInteger . D}, [UInteger], [SP], 8" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
)

(rprfm
  ("RPRFM_R_ldst_regoff" "PLDKEEP, XZR, [SP]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XmOrXZR__3" "XnSP_option"))
)

(fcvtn
  ("fcvtn_z8_mz2_h2b" "ZUInteger.B, {Z UInteger .H- Z UInteger .H}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("fcvtn_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("fcvtn_z8_mz4_" "ZUInteger.B, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
  ("FCVTN_asimdsame2_H" "VUInteger.8B, VUInteger.4S, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FCVTN_asimdsame2_D" "VUInteger.8B, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FCVTN_asimdmisc_N" "VUInteger.4H, VUInteger.4S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(rcwscaspl
  ("RCWSCASPL_C64_rcwcomswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
)

(mad
  ("mad_z_p_zzz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Za" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zm" "Za"))
)

(umullb
  ("umullb_z_zzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__78"))
  ("umullb_z_zzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__2" "imm__88"))
  ("umullb_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(rcwswppal
  ("RCWSWPPAL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(stbfminl
  ("STBFMINL_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
)

(setget
  ("SETGET_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__10" "XsOrXZR__7"))
)

(sm3tt1a
  ("SM3TT1A_VVV4_crypto3_imm2" "VUInteger.4S, VUInteger.4S, VUInteger.S[UInteger]" (("Rm" (reg-range 0 31)) ("imm2" (imm-range 0 3 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6" "Vm__7"))
)

(cbhgt
  ("CBHGT_16_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
)

(sqdecp
  ("sqdecp_z_p_z_" "ZUInteger.H, PUInteger.H" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pm__3"))
  ("sqdecp_r_p_r_sx" "XUInteger, PUInteger.B, WUInteger" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Rdn" (reg-range 0 31))) ("Xdn" "Pm__3" "Wdn"))
  ("sqdecp_r_p_r_x" "XUInteger, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Rdn" (reg-range 0 31))) ("Xdn" "Pm__3"))
)

(umlalt
  ("umlalt_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("umlalt_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
  ("umlalt_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
)

(cpyfewtrn
  ("CPYFEWTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(nmatch
  ("nmatch_p_p_zz_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
)

(sxtw
  ("sxtw_z_p_z_m" "ZUInteger.D, PUInteger/M, ZUInteger.D" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("sxtw_z_p_z_z" "ZUInteger.D, PUInteger/Z, ZUInteger.D" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
)

(fcvtl
  ("fcvtl_mz2_z_" "{Z UInteger .S- Z UInteger .S}, ZUInteger.H" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
  ("FCVTL_asimdmisc_L" "VUInteger.4S, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(ldclr
  ("LDCLR_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDCLR_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(addsvl
  ("addsvl_r_ri_" "SP, SP, SInteger" (("Rn" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rd" (reg-range 0 31))) ("XdSP__2" "XnSP__2" "imm__28"))
)

(ld3q
  ("ld3q_z_p_br_contiguous" "{Z UInteger .Q Z UInteger .Q Z UInteger .Q}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3" "Xm__4"))
  ("ld3q_z_p_bi_contiguous" "{Z UInteger .Q Z UInteger .Q Z UInteger .Q}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3"))
)

(ldsetb
  ("LDSETB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(st2h
  ("st2h_z_p_br_contiguous" "{Z UInteger .H Z UInteger .H}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3" "Xm__4"))
  ("st2h_z_p_bi_contiguous" "{Z UInteger .H Z UInteger .H}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3"))
)

(udf
  ("UDF_only_perm_undef" "UInteger" (("imm16" (imm-range 0 65535 1))) ("imm__21"))
)

(rcwssetpal
  ("RCWSSETPAL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(orns
  ("orns_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
)

(ld1roh
  ("ld1roh_z_p_br_contiguous" "{Z UInteger .H}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1roh_z_p_bi_u16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
)

(st3
  ("ST3_asisdlse_R3" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
  ("ST3_asisdlsep_R3_r" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
  ("ST3_asisdlsep_I3_i" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], 24" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "imm_option__3"))
  ("ST3_asisdlso_B3_3b" "{V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
  ("ST3_asisdlso_H3_3h" "{V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
  ("ST3_asisdlso_S3_3s" "{V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
  ("ST3_asisdlso_D3_3d" "{V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
  ("ST3_asisdlsop_BX3_r3b" "{V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
  ("ST3_asisdlsop_HX3_r3h" "{V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
  ("ST3_asisdlsop_SX3_r3s" "{V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
  ("ST3_asisdlsop_DX3_r3d" "{V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
  ("ST3_asisdlsop_B3_i3b" "{V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP], 3" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
  ("ST3_asisdlsop_H3_i3h" "{V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP], 6" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
  ("ST3_asisdlsop_S3_i3s" "{V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP], 12" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
  ("ST3_asisdlsop_D3_i3d" "{V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP], 24" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
)

(stxrb
  ("STXRB_SR32_ldstexclr" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "WtOrWZR__4" "XnSP_option"))
)

(rcwsswpal
  ("RCWSSWPAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(srhadd
  ("srhadd_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("SRHADD_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(fcmeq
  ("fcmeq_p_p_zz_" "PUInteger.H, PUInteger/Z, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
  ("fcmeq_p_p_z0_" "PUInteger.H, PUInteger/Z, ZUInteger.H, 0.0" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn"))
  ("FCMEQ_asisdsamefp16_only" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
  ("FCMEQ_asisdmiscfp16_FZ" "HUInteger, HUInteger, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
  ("FCMEQ_asisdmisc_FZ" "SUInteger, SUInteger, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("FCMEQ_asisdsame_only" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9" "V_option__9"))
  ("FCMEQ_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FCMEQ_asimdmiscfp16_FZ" "VUInteger.4H, VUInteger.4H, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCMEQ_asimdmisc_FZ" "VUInteger.2S, VUInteger.2S, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCMEQ_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(fcvtzun
  ("fcvtzun_z_mz2_" "ZUInteger.B, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
)

(bif
  ("BIF_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(cpymn
  ("CPYMN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(frecps
  ("frecps_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("FRECPS_asisdsamefp16_only" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
  ("FRECPS_asisdsame_only" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9" "V_option__9"))
  ("FRECPS_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FRECPS_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(cmla
  ("cmla_z_zzz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B, 0" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("cmla_z_zzzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger, 0" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__41"))
  ("cmla_z_zzzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger, 0" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__42"))
)

(tchangeb
  ("TCHANGEB_tc_reg" "UInteger, XUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Xd_tchange" "Xn_tchange"))
  ("TCHANGEB_tc_imm" "UInteger, UInteger" (("imm7" (imm-range 0 127 1)) ("Rd" (reg-range 0 31))) ("Xd_tchange" "imm_tindex"))
)

(cpyfpwt
  ("CPYFPWT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(rcwswpp
  ("RCWSWPP_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(uvdot
  ("uvdot_za32_zzi_2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("uvdot_za_zzi_s4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
  ("uvdot_za_zzi_d4xi" "ZA.D[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
)

(psb
  ("PSB_HC_hints" "CSYNC" () ())
)

(cmle
  ("CMLE_asisdmisc_Z" "DUInteger, DUInteger, 0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("CMLE_asimdmisc_Z" "VUInteger.8B, VUInteger.8B, 0" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(cpyfmwtwn
  ("CPYFMWTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(fcvtpu
  ("FCVTPU_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
  ("FCVTPU_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("FCVTPU_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCVTPU_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCVTPU_32S_float2int" "WZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
  ("FCVTPU_32D_float2int" "WZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
  ("FCVTPU_32H_float2int" "WZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
  ("FCVTPU_64S_float2int" "XZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
  ("FCVTPU_64D_float2int" "XZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
  ("FCVTPU_64H_float2int" "XZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
  ("FCVTPU_sisd_32D" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
  ("FCVTPU_sisd_32H" "SUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Hn__2"))
  ("FCVTPU_sisd_64H" "DUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Hn__2"))
  ("FCVTPU_sisd_64S" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
)

(lastp
  ("lastp_r_p_p_" "XUInteger, PUInteger, PUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Rd" (reg-range 0 31))) ("Xd__2" "Pg__2" "Pn__3"))
)

(ldsetlb
  ("LDSETLB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(fnmad
  ("fnmad_z_p_zzz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Za" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zm" "Za"))
)

(smull
  ("SMULL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("SMULL_asimdelem_L" "VUInteger.4S, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
)

(udivr
  ("udivr_z_p_zz_" "ZUInteger.S, PUInteger/M, ZUInteger.S, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
)

(eortb
  ("eortb_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(fsub
  ("fsub_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("fsub_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("fsub_z_p_zs_" "ZUInteger.H, PUInteger/M, ZUInteger.H, 0.5" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
  ("fsub_za_zw_2x2" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1" "Zm2"))
  ("fsub_za_zw_2x2_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1" "Zm2"))
  ("fsub_za_zw_4x4" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1__2" "Zm4"))
  ("fsub_za_zw_4x4_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1__2" "Zm4"))
  ("FSUB_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FSUB_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FSUB_S_floatdp2" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__3" "Sm"))
  ("FSUB_D_floatdp2" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__2" "Dm"))
  ("FSUB_H_floatdp2" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
)

(rcwswpal
  ("RCWSWPAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(ldfmaxnm
  ("LDFMAXNM_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMAXNM_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMAXNM_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(cpyfpt
  ("CPYFPT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(fcvtps
  ("FCVTPS_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
  ("FCVTPS_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("FCVTPS_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCVTPS_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCVTPS_32S_float2int" "WZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
  ("FCVTPS_32D_float2int" "WZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
  ("FCVTPS_32H_float2int" "WZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
  ("FCVTPS_64S_float2int" "XZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
  ("FCVTPS_64D_float2int" "XZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
  ("FCVTPS_64H_float2int" "XZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
  ("FCVTPS_sisd_32D" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
  ("FCVTPS_sisd_32H" "SUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Hn__2"))
  ("FCVTPS_sisd_64H" "DUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Hn__2"))
  ("FCVTPS_sisd_64S" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
)

(ldfminnml
  ("LDFMINNML_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMINNML_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMINNML_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(uqsub
  ("uqsub_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("uqsub_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__27"))
  ("uqsub_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("UQSUB_asisdsame_only" "BUInteger, BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7" "V_option__7"))
  ("UQSUB_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(uaddw
  ("UADDW_asimddiff_W" "VUInteger.8H, VUInteger.8H, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(texit
  ("TEXIT_te_branch_reg" "" () ())
)

(fcvtzu
  ("fcvtzu_z_p_z_s2wz" "ZUInteger.S, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzu_z_p_z_d2wz" "ZUInteger.S, PUInteger/Z, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzu_z_p_z_s2xz" "ZUInteger.D, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzu_z_p_z_d2xz" "ZUInteger.D, PUInteger/Z, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzu_z_p_z_fp162hz" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzu_z_p_z_fp162wz" "ZUInteger.S, PUInteger/Z, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzu_z_p_z_fp162xz" "ZUInteger.D, PUInteger/Z, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzu_z_p_z_s2w" "ZUInteger.S, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzu_z_p_z_d2w" "ZUInteger.S, PUInteger/M, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzu_z_p_z_s2x" "ZUInteger.D, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzu_z_p_z_d2x" "ZUInteger.D, PUInteger/M, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzu_z_p_z_fp162h" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzu_z_p_z_fp162w" "ZUInteger.S, PUInteger/M, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzu_z_p_z_fp162x" "ZUInteger.D, PUInteger/M, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzu_mz_z_2" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__4" "Zn2__3"))
  ("fcvtzu_mz_z_4" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
  ("FCVTZU_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
  ("FCVTZU_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("FCVTZU_asisdshf_C" "HUInteger, HUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__6" "V_option__6" "immh_shift__3"))
  ("FCVTZU_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCVTZU_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCVTZU_asimdshf_C" "VUInteger.4H, VUInteger.4H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__9"))
  ("FCVTZU_32S_float2fix" "WZR, SUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
  ("FCVTZU_32D_float2fix" "WZR, DUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
  ("FCVTZU_32H_float2fix" "WZR, HUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
  ("FCVTZU_64S_float2fix" "XZR, SUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
  ("FCVTZU_64D_float2fix" "XZR, DUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
  ("FCVTZU_64H_float2fix" "XZR, HUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
  ("FCVTZU_32S_float2int" "WZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
  ("FCVTZU_32D_float2int" "WZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
  ("FCVTZU_32H_float2int" "WZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
  ("FCVTZU_64S_float2int" "XZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
  ("FCVTZU_64D_float2int" "XZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
  ("FCVTZU_64H_float2int" "XZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
  ("FCVTZU_sisd_32D" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
  ("FCVTZU_sisd_32H" "SUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Hn__2"))
  ("FCVTZU_sisd_64H" "DUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Hn__2"))
  ("FCVTZU_sisd_64S" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
)

(uabal
  ("uabal_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("UABAL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(cpyewn
  ("CPYEWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(rshrn
  ("RSHRN_asimdshf_N" "VUInteger.8B, VUInteger.8H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__6"))
)

(ldnf1h
  ("ldnf1h_z_p_bi_u16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldnf1h_z_p_bi_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldnf1h_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
)

(casal
  ("CASAL_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
  ("CASAL_C64_comswap" "XZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
)

(cpyertn
  ("CPYERTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(movt
  ("movt_r_zt_" "XUInteger, ZT0[UInteger" (("off3" (imm-range 0 7 1)) ("Rt" (reg-range 0 31))) ("Xt__3" "offs__8"))
  ("movt_zt_r_" "ZT0[UInteger, XUInteger" (("off3" (imm-range 0 7 1)) ("Rt" (reg-range 0 31))) ("offs__8" "Xt__3"))
  ("movt_zt_z_" "ZT0, ZUInteger" (("off2" (imm-range 0 3 1)) ("Zt" (reg-range 0 31))) ("Zt"))
)

(uxtb
  ("uxtb_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("uxtb_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
)

(fmsb
  ("fmsb_z_p_zzz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Za" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zm" "Za"))
)

(sha1h
  ("SHA1H_SS_cryptosha2" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
)

(ldraa
  ("LDRAA_64_ldst_pac" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "Simm9_option"))
  ("LDRAA_64W_ldst_pac" "XZR, [SP], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "Simm9_option"))
)

(st3b
  ("st3b_z_p_br_contiguous" "{Z UInteger .B Z UInteger .B Z UInteger .B}, PUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3" "Xm__4"))
  ("st3b_z_p_bi_contiguous" "{Z UInteger .B Z UInteger .B Z UInteger .B}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3"))
)

(uhadd
  ("uhadd_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("UHADD_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(ldlarb
  ("LDLARB_LR32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
)

(uqshlr
  ("uqshlr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
)

(fnmla
  ("fnmla_z_p_zzz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Pg" "Zn__2" "Zm"))
)

(st1w
  ("st1w_z_p_br_u128" "{Z UInteger .Q}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("st1w_z_p_br_" "{Z UInteger . S}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("st1w_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("st1w_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("st1w_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("st1w_z_p_bz_s_x32_scaled" "{Z UInteger .S}, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("st1w_z_p_bz_d_64_unscaled" "{Z UInteger . D}, PUInteger, [SP Z UInteger . D]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("st1w_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("st1w_z_p_ai_d" "{Z UInteger .D}, PUInteger, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("st1w_z_p_ai_s" "{Z UInteger .S}, PUInteger, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("st1w_z_p_bi_u128" "{Z UInteger .Q}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("st1w_z_p_bi_" "{Z UInteger . S}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("st1w_mz_p_br_2" "{Z UInteger .S- Z UInteger .S}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
  ("st1w_mz_p_br_4" "{Z UInteger .S- Z UInteger .S}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
  ("st1w_mz_p_bi_2" "{Z UInteger .S- Z UInteger .S}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
  ("st1w_mz_p_bi_4" "{Z UInteger .S- Z UInteger .S}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
  ("st1w_mzx_p_br_2x8" "{Z UInteger .S Z UInteger .S}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
  ("st1w_mzx_p_br_4x4" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
  ("st1w_mzx_p_bi_2x8" "{Z UInteger .S Z UInteger .S}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
  ("st1w_mzx_p_bi_4x4" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
  ("st1w_za_p_rrr_" "{ZA UInteger H .S [W UInteger UInteger]}, PUInteger, [SP]" (("Rm" (reg-range 0 31)) ("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("ZAt__4" "HV" "Ws__3" "offs__6" "Pg" "XnSP__3"))
)

(aesdimc
  ("aesdimc_mz_zzi_2x1" "{Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}, ZUInteger.Q[UInteger" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm"))
  ("aesdimc_mz_zzi_4x1" "{Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}, ZUInteger.Q[UInteger" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm"))
)

(uqrshl
  ("uqrshl_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("UQRSHL_asisdsame_only" "BUInteger, BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7" "V_option__7"))
  ("UQRSHL_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(ldumaxh
  ("LDUMAXH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(fminp
  ("fminp_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("FMINP_asisdpair_only_H" "HUInteger, VUInteger.2H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vn"))
  ("FMINP_asisdpair_only_SD" "SUInteger, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__4" "Vn"))
  ("FMINP_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMINP_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(cpyprtn
  ("CPYPRTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(ftmad
  ("ftmad_z_zzi_" "ZUInteger.H, ZUInteger.H, ZUInteger.H, UInteger" (("size" (element-size B H S D)) ("imm3" (imm-range 0 7 1)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm" "imm__57"))
)

(fcmne
  ("fcmne_p_p_zz_" "PUInteger.H, PUInteger/Z, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
  ("fcmne_p_p_z0_" "PUInteger.H, PUInteger/Z, ZUInteger.H, 0.0" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn"))
)

(ldlarh
  ("LDLARH_LR32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
)

(f1cvt
  ("f1cvt_z_z8_b2h" "ZUInteger.H, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
  ("f1cvt_mz2_z8_" "{Z UInteger .H- Z UInteger .H}, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
)

(scvtflt
  ("scvtflt_z_z_" "ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(smulh
  ("smulh_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("smulh_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("SMULH_64_dp_3src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__13" "XmOrXZR__9"))
)

(smmla
  ("smmla_z_zzz_" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("SMMLA_asimdsame2_G" "VUInteger.4S, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "Vm"))
)

(urecpe
  ("urecpe_z_p_z_m" "ZUInteger.S, PUInteger/M, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("urecpe_z_p_z_z" "ZUInteger.S, PUInteger/Z, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("URECPE_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(st3d
  ("st3d_z_p_br_contiguous" "{Z UInteger .D Z UInteger .D Z UInteger .D}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3" "Xm__4"))
  ("st3d_z_p_bi_contiguous" "{Z UInteger .D Z UInteger .D Z UInteger .D}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3"))
)

(csdb
  ("CSDB_HI_hints" "" () ())
)

(swppl
  ("SWPPL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(f2cvtlt
  ("f2cvtlt_z_z8_b2h" "ZUInteger.H, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(bfadd
  ("bfadd_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("bfadd_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("bfadd_za_zw_2x2_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1" "Zm2"))
  ("bfadd_za_zw_4x4_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1__2" "Zm4"))
)

(fvdotb
  ("fvdotb_za32_z8z8i_2xi" "ZA.S[WUInteger, UInteger, VGx4], {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
)

(ldset
  ("LDSET_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDSET_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(rcwsclra
  ("RCWSCLRA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(setgen
  ("SETGEN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__10" "XsOrXZR__7"))
)

(ftssel
  ("ftssel_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(ldfadd
  ("LDFADD_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFADD_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFADD_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(fcmgt
  ("fcmgt_p_p_zz_" "PUInteger.H, PUInteger/Z, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
  ("fcmgt_p_p_z0_" "PUInteger.H, PUInteger/Z, ZUInteger.H, 0.0" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn"))
  ("FCMGT_asisdsamefp16_only" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
  ("FCMGT_asisdmiscfp16_FZ" "HUInteger, HUInteger, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
  ("FCMGT_asisdmisc_FZ" "SUInteger, SUInteger, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("FCMGT_asisdsame_only" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9" "V_option__9"))
  ("FCMGT_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FCMGT_asimdmiscfp16_FZ" "VUInteger.4H, VUInteger.4H, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCMGT_asimdmisc_FZ" "VUInteger.2S, VUInteger.2S, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCMGT_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(stfmaxnml
  ("STFMAXNML_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
  ("STFMAXNML_32" "SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
  ("STFMAXNML_64" "DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
)

(csinv
  ("CSINV_32_condsel" "WZR, WZR, WZR, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("CSINV_64_condsel" "XZR, XZR, XZR, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
)

(shsubr
  ("shsubr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
)

(addspl
  ("addspl_r_ri_" "SP, SP, SInteger" (("Rn" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rd" (reg-range 0 31))) ("XdSP__2" "XnSP__2" "imm__28"))
)

(autdza
  ("AUTDZA_64Z_dp_1src" "XZR" (("Rd" (reg-range 0 31))) ("XdOrXZR__6"))
)

(uaba
  ("uaba_z_zzz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("UABA_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(stlurh
  ("STLURH_32_ldapstl_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
)

(cmpne
  ("cmpne_p_p_zw_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
  ("cmpne_p_p_zz_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
  ("cmpne_p_p_zi_" "PUInteger.B, PUInteger/Z, ZUInteger.B, SInteger" (("size" (element-size B H S D)) ("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn" "imm__43"))
)

(fmlal
  ("fmlal_za_zzi_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
  ("fmlal_za_z8z8i_1" "ZA.H[WUInteger, UInteger:UInteger, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
  ("fmlal_za_zzi_2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm__2"))
  ("fmlal_za_z8z8i_2xi" "ZA.H[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm__2"))
  ("fmlal_za_zzi_4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm__2"))
  ("fmlal_za_z8z8i_4xi" "ZA.H[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm__2"))
  ("fmlal_za_zzv_2x1" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn2" "Zm__2"))
  ("fmlal_za_z8z8v_2x1" "ZA.H[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn2" "Zm__2"))
  ("fmlal_za_zzv_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
  ("fmlal_za_zzv_4x1" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn4" "Zm__2"))
  ("fmlal_za_z8z8v_4x1" "ZA.H[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn4" "Zm__2"))
  ("fmlal_za_z8z8v_1" "ZA.H[WUInteger, UInteger:UInteger, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
  ("fmlal_za_zzw_2x2" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("fmlal_za_z8z8w_2x2" "ZA.H[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("fmlal_za_zzw_4x4" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("fmlal_za_z8z8w_4x4" "ZA.H[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("FMLAL_asimdsame_F" "VUInteger.2S, VUInteger.2H, VUInteger.2H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMLAL_asimdelem_LH" "VUInteger.2S, VUInteger.2H, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(cbbgt
  ("CBBGT_8_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
)

(cas
  ("CAS_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
  ("CAS_C64_comswap" "XZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
)

(casah
  ("CASAH_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
)

(irg
  ("IRG_64I_dp_2src" "SP, SP" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option" "XnSP_option__6"))
)

(eretaa
  ("ERETAA_64E_branch_reg" "" () ())
)

(msubpt
  ("MSUBPT_64A_dp_3src" "XZR, XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__13" "XmOrXZR__9" "XaOrXZR__2"))
)

(ldumaxlb
  ("LDUMAXLB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(ldnf1d
  ("ldnf1d_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
)

(ld2r
  ("LD2R_asisdlso_R2" "{V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
  ("LD2R_asisdlsop_RX2_r" "{V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
  ("LD2R_asisdlsop_R2_i" "{V UInteger . 8B V UInteger . 8B}, [SP], 2" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "imm_option__10"))
)

(ldsetlh
  ("LDSETLH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(sqdmlslbt
  ("sqdmlslbt_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
)

(braa
  ("BRAA_64P_branch_reg" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rm" (reg-range 0 31))) ("XnOrXZR" "XmSP_option"))
)

(rcwclrpal
  ("RCWCLRPAL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(suqadd
  ("suqadd_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("SUQADD_asisdmisc_R" "BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7"))
  ("SUQADD_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(ldclralh
  ("LDCLRALH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(rev
  ("rev_z_z_" "ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
  ("rev_p_p_" "PUInteger.B, PUInteger.B" (("size" (element-size B H S D)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pn__3"))
  ("REV_32_dp_1src" "WZR, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
  ("REV_64_dp_1src" "XZR, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
)

(sqdmull
  ("SQDMULL_asisddiff_only" "SUInteger, HUInteger, HUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Va_option__2" "Vb_option__2" "Vb_option__2"))
  ("SQDMULL_asisdelem_L" "SUInteger, HUInteger, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Va_option__2" "Vb_option__2" "Vm__5"))
  ("SQDMULL_asimddiff_L" "VUInteger.4S, VUInteger.4H, VUInteger.4H" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("SQDMULL_asimdelem_L" "VUInteger.4S, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
)

(st1q
  ("st1q_z_p_ar_d_64_unscaled" "{Z UInteger .Q}, PUInteger, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("st1q_za_p_rrr_" "{ZA UInteger H .Q [W UInteger 0]}, PUInteger, [SP]" (("Rm" (reg-range 0 31)) ("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("ZAt__3" "HV" "Ws__3" "offs__5" "Pg" "XnSP__3"))
)

(addg
  ("ADDG_64_addsub_immtags" "SP, SP, UInteger, UInteger" (("imm6" (imm-range 0 63 1)) ("imm4" (imm-range 0 15 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option" "XnSP_option__3"))
)

(cmeq
  ("CMEQ_asisdmisc_Z" "DUInteger, DUInteger, 0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("CMEQ_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("CMEQ_asimdmisc_Z" "VUInteger.8B, VUInteger.8B, 0" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("CMEQ_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(setp
  ("SETP_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XnOrXZR__5" "XsOrXZR__7"))
)

(usqadd
  ("usqadd_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("USQADD_asisdmisc_R" "BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7"))
  ("USQADD_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(cnt
  ("cnt_z_p_z_m" "ZUInteger.B, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("cnt_z_p_z_z" "ZUInteger.B, PUInteger/Z, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("CNT_32_dp_1src" "WZR, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
  ("CNT_64_dp_1src" "XZR, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
  ("CNT_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(sqincp
  ("sqincp_z_p_z_" "ZUInteger.H, PUInteger.H" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pm__3"))
  ("sqincp_r_p_r_sx" "XUInteger, PUInteger.B, WUInteger" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Rdn" (reg-range 0 31))) ("Xdn" "Pm__3" "Wdn"))
  ("sqincp_r_p_r_x" "XUInteger, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Rdn" (reg-range 0 31))) ("Xdn" "Pm__3"))
)

(umull
  ("UMULL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("UMULL_asimdelem_L" "VUInteger.4S, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
)

(ldapurb
  ("LDAPURB_32_ldapstl_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
)

(ssubwb
  ("ssubwb_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(cpyewtn
  ("CPYEWTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(rsubhnb
  ("rsubhnb_z_zz_" "ZUInteger.B, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(ldar
  ("LDAR_LR32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("LDAR_LR64_ldstord" "XZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
)

(sabd
  ("sabd_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("SABD_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(umlalb
  ("umlalb_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("umlalb_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
  ("umlalb_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
)

(rcwsswpa
  ("RCWSSWPA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(ldfadda
  ("LDFADDA_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFADDA_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFADDA_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(cntb
  ("cntb_r_s_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rd" (reg-range 0 31))) ("Xd__2"))
)

(fdiv
  ("fdiv_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("FDIV_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FDIV_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FDIV_S_floatdp2" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__3" "Sm"))
  ("FDIV_D_floatdp2" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__2" "Dm"))
  ("FDIV_H_floatdp2" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
)

(sqdecb
  ("sqdecb_r_rs_sx" "XUInteger, WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn" "Wdn"))
  ("sqdecb_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(cmphs
  ("cmphs_p_p_zz_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
  ("cmphs_p_p_zw_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
  ("cmphs_p_p_zi_" "PUInteger.B, PUInteger/Z, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm7" (imm-range 0 127 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn" "imm__44"))
)

(autizb
  ("AUTIZB_64Z_dp_1src" "XZR" (("Rd" (reg-range 0 31))) ("XdOrXZR__6"))
)

(fminqv
  ("fminqv_z_p_z_" "VUInteger.8H, PUInteger, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
)

(bit
  ("BIT_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(sqdmlslt
  ("sqdmlslt_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("sqdmlslt_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
  ("sqdmlslt_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
)

(cbhi
  ("CBHI_32_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
  ("CBHI_64_regs" "XZR, XZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "XmOrXZR__4" "imm9_offset"))
  ("CBHI_32_imm" "WZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "imm_cbr" "imm9_offset"))
  ("CBHI_64_imm" "XZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "imm_cbr" "imm9_offset"))
)

(sbc
  ("SBC_32_addsub_carry" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("SBC_64_addsub_carry" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
)

(cpyfetrn
  ("CPYFETRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(cpyetrn
  ("CPYETRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(cpyfmwtrn
  ("CPYFMWTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(fcvtzs
  ("fcvtzs_z_p_z_s2wz" "ZUInteger.S, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzs_z_p_z_d2wz" "ZUInteger.S, PUInteger/Z, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzs_z_p_z_s2xz" "ZUInteger.D, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzs_z_p_z_d2xz" "ZUInteger.D, PUInteger/Z, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzs_z_p_z_fp162hz" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzs_z_p_z_fp162wz" "ZUInteger.S, PUInteger/Z, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzs_z_p_z_fp162xz" "ZUInteger.D, PUInteger/Z, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzs_z_p_z_s2w" "ZUInteger.S, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzs_z_p_z_d2w" "ZUInteger.S, PUInteger/M, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzs_z_p_z_s2x" "ZUInteger.D, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzs_z_p_z_d2x" "ZUInteger.D, PUInteger/M, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzs_z_p_z_fp162h" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzs_z_p_z_fp162w" "ZUInteger.S, PUInteger/M, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzs_z_p_z_fp162x" "ZUInteger.D, PUInteger/M, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtzs_mz_z_2" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__4" "Zn2__3"))
  ("fcvtzs_mz_z_4" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
  ("FCVTZS_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
  ("FCVTZS_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("FCVTZS_asisdshf_C" "HUInteger, HUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__6" "V_option__6" "immh_shift__3"))
  ("FCVTZS_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCVTZS_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCVTZS_asimdshf_C" "VUInteger.4H, VUInteger.4H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__9"))
  ("FCVTZS_32S_float2fix" "WZR, SUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
  ("FCVTZS_32D_float2fix" "WZR, DUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
  ("FCVTZS_32H_float2fix" "WZR, HUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
  ("FCVTZS_64S_float2fix" "XZR, SUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
  ("FCVTZS_64D_float2fix" "XZR, DUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
  ("FCVTZS_64H_float2fix" "XZR, HUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
  ("FCVTZS_32S_float2int" "WZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
  ("FCVTZS_32D_float2int" "WZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
  ("FCVTZS_32H_float2int" "WZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
  ("FCVTZS_64S_float2int" "XZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
  ("FCVTZS_64D_float2int" "XZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
  ("FCVTZS_64H_float2int" "XZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
  ("FCVTZS_sisd_32D" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
  ("FCVTZS_sisd_32H" "SUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Hn__2"))
  ("FCVTZS_sisd_64H" "DUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Hn__2"))
  ("FCVTZS_sisd_64S" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
)

(uqincd
  ("uqincd_z_zs_" "ZUInteger.D" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
  ("uqincd_r_rs_uw" "WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Wdn"))
  ("uqincd_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(addhnb
  ("addhnb_z_zz_" "ZUInteger.B, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(ld1rqb
  ("ld1rqb_z_p_br_contiguous" "{Z UInteger .B}, PUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1rqb_z_p_bi_u8" "{Z UInteger .B}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
)

(ldbfminnma
  ("LDBFMINNMA_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(smlalb
  ("smlalb_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("smlalb_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
  ("smlalb_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
)

(tchangef
  ("TCHANGEF_tc_reg" "UInteger, XUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Xd_tchange" "Xn_tchange"))
  ("TCHANGEF_tc_imm" "UInteger, UInteger" (("imm7" (imm-range 0 127 1)) ("Rd" (reg-range 0 31))) ("Xd_tchange" "imm_tindex"))
)

(ldarb
  ("LDARB_LR32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
)

(rcwswpl
  ("RCWSWPL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(decp
  ("decp_z_p_z_" "ZUInteger.H, PUInteger.H" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pm__3"))
  ("decp_r_p_r_" "XUInteger, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Rdn" (reg-range 0 31))) ("Xdn" "Pm__3"))
)

(stbfminnml
  ("STBFMINNML_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
)

(ldap
  ("LDAP_64_ldiappstilp" "XZR, XZR, [SP 0]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(ldsminlh
  ("LDSMINLH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(ldsminal
  ("LDSMINAL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDSMINAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(bfmop4a
  ("bfmop4a_za32_zz_h1x1" "ZAUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
  ("bfmop4a_za32_zz_h1x2" "ZAUInteger.S, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("bfmop4a_za32_zz_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("bfmop4a_za32_zz_h2x2" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("bfmop4a_za_zz_h1x1" "ZAUInteger.H, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn_mortlach" "Zm_mortlach"))
  ("bfmop4a_za_zz_h1x2" "ZAUInteger.H, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("bfmop4a_za_zz_h2x1" "ZAUInteger.H, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("bfmop4a_za_zz_h2x2" "ZAUInteger.H, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
)

(setgopt
  ("SETGOPT_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__4" "XnOrXZR__8"))
)

(cpypt
  ("CPYPT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(whilele
  ("whilele_pn_rr_" "PNUInteger.B, XUInteger, XUInteger, VLx2" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("PNd" (reg-range 0 7))) ("PNd" "Xn__4" "Xm__6"))
  ("whilele_pp_rr_" "{P UInteger . B P UInteger . B}, XUInteger, XUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 7))) ("Pd1__2" "Pd2__2" "Xn__4" "Xm__6"))
  ("whilele_p_p_rr_" "PUInteger.B, WZR, WZR" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd"))
)

(brk
  ("BRK_EX_exception" "UInteger" (("imm16" (imm-range 0 65535 1))) ("imm"))
)

(ldnt1sb
  ("ldnt1sb_z_p_ar_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ldnt1sb_z_p_ar_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
)

(stnt1b
  ("stnt1b_z_p_ar_d_64_unscaled" "{Z UInteger .D}, PUInteger, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("stnt1b_z_p_ar_s_x32_unscaled" "{Z UInteger .S}, PUInteger, [Z UInteger .S]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("stnt1b_z_p_br_contiguous" "{Z UInteger .B}, PUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("stnt1b_z_p_bi_contiguous" "{Z UInteger .B}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("stnt1b_mz_p_br_2" "{Z UInteger .B- Z UInteger .B}, PNUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
  ("stnt1b_mz_p_br_4" "{Z UInteger .B- Z UInteger .B}, PNUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
  ("stnt1b_mz_p_bi_2" "{Z UInteger .B- Z UInteger .B}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
  ("stnt1b_mz_p_bi_4" "{Z UInteger .B- Z UInteger .B}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
  ("stnt1b_mzx_p_br_2x8" "{Z UInteger .B Z UInteger .B}, PNUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
  ("stnt1b_mzx_p_br_4x4" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PNUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
  ("stnt1b_mzx_p_bi_2x8" "{Z UInteger .B Z UInteger .B}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
  ("stnt1b_mzx_p_bi_4x4" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
)

(rcwscas
  ("RCWSCAS_C64_rcwcomswap" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
)

(stnt1d
  ("stnt1d_z_p_ar_d_64_unscaled" "{Z UInteger .D}, PUInteger, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("stnt1d_z_p_br_contiguous" "{Z UInteger .D}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("stnt1d_z_p_bi_contiguous" "{Z UInteger .D}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("stnt1d_mz_p_br_2" "{Z UInteger .D- Z UInteger .D}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
  ("stnt1d_mz_p_br_4" "{Z UInteger .D- Z UInteger .D}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
  ("stnt1d_mz_p_bi_2" "{Z UInteger .D- Z UInteger .D}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
  ("stnt1d_mz_p_bi_4" "{Z UInteger .D- Z UInteger .D}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
  ("stnt1d_mzx_p_br_2x8" "{Z UInteger .D Z UInteger .D}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
  ("stnt1d_mzx_p_br_4x4" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
  ("stnt1d_mzx_p_bi_2x8" "{Z UInteger .D Z UInteger .D}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
  ("stnt1d_mzx_p_bi_4x4" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
)

(umlslt
  ("umlslt_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("umlslt_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
  ("umlslt_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
)

(ldapursw
  ("LDAPURSW_64_ldapstl_unscaled" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
)

(fmaxnmv
  ("fmaxnmv_v_p_z_" "HUInteger, PUInteger, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V__5" "Pg" "Zn"))
  ("FMAXNMV_asimdall_only_H" "HUInteger, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_hv" "Vn"))
  ("FMAXNMV_asimdall_only_SD" "SUInteger, VUInteger.4S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vn"))
)

(index
  ("index_z_ii_" "ZUInteger.B, SInteger, SInteger" (("size" (element-size B H S D)) ("imm5b" (imm-range 0 31 1)) ("imm5" (imm-range 0 31 1)) ("Zd" (reg-range 0 31))) ("Zd" "imm1" "imm2"))
  ("index_z_ri_" "ZUInteger.B, WZR, SInteger" (("size" (element-size B H S D)) ("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "imm__43"))
  ("index_z_ir_" "ZUInteger.B, SInteger, WZR" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("imm5" (imm-range 0 31 1)) ("Zd" (reg-range 0 31))) ("Zd" "imm__43"))
  ("index_z_rr_" "ZUInteger.B, WZR, WZR" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd"))
)

(sqneg
  ("sqneg_z_p_z_m" "ZUInteger.B, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("sqneg_z_p_z_z" "ZUInteger.B, PUInteger/Z, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("SQNEG_asisdmisc_R" "BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7"))
  ("SQNEG_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(ldtp
  ("LDTP_64_ldstpair_post" "XZR, XZR, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__15"))
  ("LDTP_Q_ldstpair_post" "QUInteger, QUInteger, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm__16"))
  ("LDTP_64_ldstpair_off" "XZR, XZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm7_option__2"))
  ("LDTP_Q_ldstpair_off" "QUInteger, QUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm7_option__3"))
  ("LDTP_64_ldstpair_pre" "XZR, XZR, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__15"))
  ("LDTP_Q_ldstpair_pre" "QUInteger, QUInteger, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm__16"))
)

(caspa
  ("CASPA_CP32_comswappr" "WUInteger, WUInteger, WUInteger, WUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ws" "WsPlus1" "Wt" "WtPlus1" "XnSP_option"))
  ("CASPA_CP64_comswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
)

(ld1rqd
  ("ld1rqd_z_p_br_contiguous" "{Z UInteger .D}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1rqd_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
)

(sqdmulh
  ("sqdmulh_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("sqdmulh_z_zzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__78"))
  ("sqdmulh_z_zzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__41"))
  ("sqdmulh_z_zzi_d" "ZUInteger.D, ZUInteger.D, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__2" "imm__42"))
  ("sqdmulh_mz_zzv_2x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
  ("sqdmulh_mz_zzv_4x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
  ("sqdmulh_mz_zzw_2x2" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
  ("sqdmulh_mz_zzw_4x4" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
  ("SQDMULH_asisdsame_only" "HUInteger, HUInteger, HUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__8" "V_option__8" "V_option__8"))
  ("SQDMULH_asisdelem_R" "HUInteger, HUInteger, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__8" "V_option__8" "Vm__5"))
  ("SQDMULH_asimdsame_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("SQDMULH_asimdelem_R" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
)

(autia
  ("AUTIA_64P_dp_1src" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__7"))
)

(umax
  ("umax_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("umax_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__37"))
  ("umax_mz_zzv_2x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
  ("umax_mz_zzv_4x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
  ("umax_mz_zzw_2x2" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
  ("umax_mz_zzw_4x4" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
  ("UMAX_32U_minmax_imm" "WZR, WZR, UInteger" (("imm8" (imm-range 0 255 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
  ("UMAX_64U_minmax_imm" "XZR, XZR, UInteger" (("imm8" (imm-range 0 255 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
  ("UMAX_32_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("UMAX_64_dp_2src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
  ("UMAX_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(ldarh
  ("LDARH_LR32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
)

(ldclra
  ("LDCLRA_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDCLRA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(setgopn
  ("SETGOPN_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__4" "XnOrXZR__8"))
)

(prfm
  ("PRFM_P_loadlit" "PLDL1KEEP, SInteger" (("imm19" (imm-range 0 524287 1)) ("Rt" (reg-range 0 31))) ("imm19_offset__2"))
  ("PRFM_P_ldst_regoff" "PLDL1KEEP, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option" "WorX_choice"))
  ("PRFM_P_ldst_pos" "PLDL1KEEP, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option" "imm12_option__8"))
)

(whilewr
  ("whilewr_p_rr_" "PUInteger.B, XUInteger, XUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Xn__4" "Xm__6"))
)

(ldaddab
  ("LDADDAB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(ldtr
  ("LDTR_32_ldst_unpriv" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
  ("LDTR_64_ldst_unpriv" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
)

(sev
  ("SEV_HI_hints" "" () ())
)

(umop4s
  ("umop4s_za_zz_b1x1" "ZAUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
  ("umop4s_za_zz_b1x2" "ZAUInteger.S, ZUInteger.B, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("umop4s_za_zz_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("umop4s_za_zz_b2x2" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("umop4s_za32_zz_h1x1" "ZAUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
  ("umop4s_za32_zz_h1x2" "ZAUInteger.S, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("umop4s_za32_zz_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("umop4s_za32_zz_h2x2" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("umop4s_za_zz_h1x1" "ZAUInteger.D, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm_mortlach"))
  ("umop4s_za_zz_h1x2" "ZAUInteger.D, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("umop4s_za_zz_h2x1" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("umop4s_za_zz_h2x2" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
)

(uqinch
  ("uqinch_z_zs_" "ZUInteger.H" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
  ("uqinch_r_rs_uw" "WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Wdn"))
  ("uqinch_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(ssubl
  ("SSUBL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(asrd
  ("asrd_z_p_zi_" "ZUInteger.B, PUInteger/M, ZUInteger.B, UInteger" (("Pg" (reg-range 0 7)) ("imm3" (imm-range 0 7 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
)

(frecpe
  ("frecpe_z_z_" "ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
  ("FRECPE_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
  ("FRECPE_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("FRECPE_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FRECPE_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(sqxtnb
  ("sqxtnb_z_zz_" "ZUInteger.B, ZUInteger.H" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(sqshlu
  ("sqshlu_z_p_zi_" "ZUInteger.B, PUInteger/M, ZUInteger.B, UInteger" (("Pg" (reg-range 0 7)) ("imm3" (imm-range 0 7 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
  ("SQSHLU_asisdshf_R" "BUInteger, BUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__5" "V_option__5" "immh_shift"))
  ("SQSHLU_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__5"))
)

(sminp
  ("sminp_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("SMINP_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(cpyewt
  ("CPYEWT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(ldsminah
  ("LDSMINAH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(setgoet
  ("SETGOET_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__10"))
)

(clastb
  ("clastb_z_p_zz_" "ZUInteger.B, PUInteger, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("clastb_v_p_z_" "BUInteger, PUInteger, BUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31))) ("V__2" "Pg" "V__2" "Zm__5"))
  ("clastb_r_p_z_" "WZR, PUInteger, WZR, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Rdn" (reg-range 0 31))) ("Pg" "Zm__5"))
)

(st3h
  ("st3h_z_p_br_contiguous" "{Z UInteger .H Z UInteger .H Z UInteger .H}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3" "Xm__4"))
  ("st3h_z_p_bi_contiguous" "{Z UInteger .H Z UInteger .H Z UInteger .H}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3"))
)

(casab
  ("CASAB_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
)

(ldbfminnmal
  ("LDBFMINNMAL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(uzpq1
  ("uzpq1_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(ldsminh
  ("LDSMINH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(cpyertrn
  ("CPYERTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(sm3ss1
  ("SM3SS1_VVV4_crypto4" "VUInteger.4S, VUInteger.4S, VUInteger.4S, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm" "Va"))
)

(setgp
  ("SETGP_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__4" "XnOrXZR__8" "XsOrXZR__8"))
)

(umlall
  ("umlall_za_zzi_s" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
  ("umlall_za_zzi_d" "ZA.D[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
  ("umlall_za_zzi_s2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm__2"))
  ("umlall_za_zzi_d2xi" "ZA.D[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm__2"))
  ("umlall_za_zzi_s4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm__2"))
  ("umlall_za_zzi_d4xi" "ZA.D[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm__2"))
  ("umlall_za_zzv_2x1" "ZA.S, [W UInteger UInteger : UInteger VGx2], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn2" "Zm__2"))
  ("umlall_za_zzv_1" "ZA.S, [W UInteger UInteger : UInteger], ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
  ("umlall_za_zzv_4x1" "ZA.S, [W UInteger UInteger : UInteger VGx4], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn4" "Zm__2"))
  ("umlall_za_zzw_2x2" "ZA.S, [W UInteger UInteger : UInteger VGx2], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("umlall_za_zzw_4x4" "ZA.S, [W UInteger UInteger : UInteger VGx4], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
)

(sttr
  ("STTR_32_ldst_unpriv" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
  ("STTR_64_ldst_unpriv" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
)

(sm3tt2a
  ("SM3TT2A_VVV4_crypto3_imm2" "VUInteger.4S, VUInteger.4S, VUInteger.S[UInteger]" (("Rm" (reg-range 0 31)) ("imm2" (imm-range 0 3 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6" "Vm__7"))
)

(ldtclr
  ("LDTCLR_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDTCLR_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(ldgm
  ("LDGM_64bulk_ldsttags" "XZR, [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__4" "XnSP_option"))
)

(trn1
  ("trn1_z_zz_q" "ZUInteger.Q, ZUInteger.Q, ZUInteger.Q" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("trn1_p_pp_" "PUInteger.B, PUInteger.B, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pn__2" "Pm__2"))
  ("trn1_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("TRN1_asimdperm_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(fcvtns
  ("FCVTNS_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
  ("FCVTNS_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("FCVTNS_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCVTNS_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCVTNS_32S_float2int" "WZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
  ("FCVTNS_32D_float2int" "WZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
  ("FCVTNS_32H_float2int" "WZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
  ("FCVTNS_64S_float2int" "XZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
  ("FCVTNS_64D_float2int" "XZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
  ("FCVTNS_64H_float2int" "XZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
  ("FCVTNS_sisd_32D" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
  ("FCVTNS_sisd_32H" "SUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Hn__2"))
  ("FCVTNS_sisd_64H" "DUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Hn__2"))
  ("FCVTNS_sisd_64S" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
)

(pmullb
  ("pmullb_z_zz_q" "ZUInteger.Q, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("pmullb_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(ld4q
  ("ld4q_z_p_br_contiguous" "{Z UInteger .Q Z UInteger .Q Z UInteger .Q Z UInteger .Q}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3" "Xm__4"))
  ("ld4q_z_p_bi_contiguous" "{Z UInteger .Q Z UInteger .Q Z UInteger .Q Z UInteger .Q}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3"))
)

(cmplt
  ("cmplt_p_p_zw_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
  ("cmplt_p_p_zi_" "PUInteger.B, PUInteger/Z, ZUInteger.B, SInteger" (("size" (element-size B H S D)) ("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn" "imm__43"))
)

(whilerw
  ("whilerw_p_rr_" "PUInteger.B, XUInteger, XUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Xn__4" "Xm__6"))
)

(ftsmul
  ("ftsmul_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(cbhs
  ("CBHS_32_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
  ("CBHS_64_regs" "XZR, XZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "XmOrXZR__4" "imm9_offset"))
)

(fjcvtzs
  ("FJCVTZS_32D_float2int" "WZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
)

(punpklo
  ("punpklo_p_p_" "PUInteger.H, PUInteger.B" (("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pn__3"))
)

(cmphi
  ("cmphi_p_p_zz_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
  ("cmphi_p_p_zw_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
  ("cmphi_p_p_zi_" "PUInteger.B, PUInteger/Z, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm7" (imm-range 0 127 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn" "imm__44"))
)

(cnth
  ("cnth_r_s_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rd" (reg-range 0 31))) ("Xd__2"))
)

(dech
  ("dech_z_zs_" "ZUInteger.H" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
  ("dech_r_rs_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(sqdech
  ("sqdech_z_zs_" "ZUInteger.H" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
  ("sqdech_r_rs_sx" "XUInteger, WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn" "Wdn"))
  ("sqdech_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(sqinch
  ("sqinch_z_zs_" "ZUInteger.H" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
  ("sqinch_r_rs_sx" "XUInteger, WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn" "Wdn"))
  ("sqinch_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(setgoen
  ("SETGOEN_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__10"))
)

(brabz
  ("BRABZ_64_branch_reg" "XZR" (("Rn" (reg-range 0 31))) ("XnOrXZR"))
)

(fnmsub
  ("FNMSUB_S_floatdp3" "SUInteger, SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__6" "Sm__2" "Sa__2"))
  ("FNMSUB_D_floatdp3" "DUInteger, DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__5" "Dm__2" "Da__2"))
  ("FNMSUB_H_floatdp3" "HUInteger, HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__5" "Hm__2" "Ha__2"))
)

(whilehs
  ("whilehs_pn_rr_" "PNUInteger.B, XUInteger, XUInteger, VLx2" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("PNd" (reg-range 0 7))) ("PNd" "Xn__4" "Xm__6"))
  ("whilehs_pp_rr_" "{P UInteger . B P UInteger . B}, XUInteger, XUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 7))) ("Pd1__2" "Pd2__2" "Xn__4" "Xm__6"))
  ("whilehs_p_p_rr_" "PUInteger.B, WZR, WZR" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd"))
)

(fcvtnu
  ("FCVTNU_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
  ("FCVTNU_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("FCVTNU_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCVTNU_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCVTNU_32S_float2int" "WZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
  ("FCVTNU_32D_float2int" "WZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
  ("FCVTNU_32H_float2int" "WZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
  ("FCVTNU_64S_float2int" "XZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
  ("FCVTNU_64D_float2int" "XZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
  ("FCVTNU_64H_float2int" "XZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
  ("FCVTNU_sisd_32D" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
  ("FCVTNU_sisd_32H" "SUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Hn__2"))
  ("FCVTNU_sisd_64H" "DUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Hn__2"))
  ("FCVTNU_sisd_64S" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
)

(sqrshrn
  ("sqrshrn_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}, UInteger" (("imm4" (imm-range 0 15 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("sqrshrn_z_mz2_b" "ZUInteger.B, {Z UInteger .H- Z UInteger .H}, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("sqrshrn_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}, UInteger" (("imm5" (imm-range 0 31 1)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
  ("SQRSHRN_asisdshf_N" "BUInteger, HUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vb_option" "Va_option" "immh_shift__2"))
  ("SQRSHRN_asimdshf_N" "VUInteger.8B, VUInteger.8H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__6"))
)

(mvni
  ("MVNI_asimdimm_L_sl" "VUInteger.2S, UInteger" (("Rd" (reg-range 0 31))) ("Vd"))
  ("MVNI_asimdimm_L_hl" "VUInteger.4H, UInteger" (("Rd" (reg-range 0 31))) ("Vd"))
  ("MVNI_asimdimm_M_sm" "VUInteger.2S, UInteger, MSL, 8" (("Rd" (reg-range 0 31))) ("Vd"))
)

(usublb
  ("usublb_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(cbgt
  ("CBGT_32_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
  ("CBGT_64_regs" "XZR, XZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "XmOrXZR__4" "imm9_offset"))
  ("CBGT_32_imm" "WZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "imm_cbr" "imm9_offset"))
  ("CBGT_64_imm" "XZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "imm_cbr" "imm9_offset"))
)

(ldbfminal
  ("LDBFMINAL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(uhsub
  ("uhsub_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("UHSUB_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(bcax
  ("bcax_z_zzz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm" "Zk"))
  ("BCAX_VVV16_crypto4" "VUInteger.16B, VUInteger.16B, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm" "Va"))
)

(ldsminlb
  ("LDSMINLB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(smops
  ("smops_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
  ("smops_za32_pp_zz_16" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
  ("smops_za_pp_zz_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn__2" "Zm"))
)

(fcvtxn
  ("FCVTXN_asisdmisc_N" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("FCVTXN_asimdmisc_N" "VUInteger.2S, VUInteger.2D" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(swpalb
  ("SWPALB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
)

(stnt1h
  ("stnt1h_z_p_ar_d_64_unscaled" "{Z UInteger .D}, PUInteger, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("stnt1h_z_p_ar_s_x32_unscaled" "{Z UInteger .S}, PUInteger, [Z UInteger .S]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("stnt1h_z_p_br_contiguous" "{Z UInteger .H}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("stnt1h_z_p_bi_contiguous" "{Z UInteger .H}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("stnt1h_mz_p_br_2" "{Z UInteger .H- Z UInteger .H}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
  ("stnt1h_mz_p_br_4" "{Z UInteger .H- Z UInteger .H}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
  ("stnt1h_mz_p_bi_2" "{Z UInteger .H- Z UInteger .H}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
  ("stnt1h_mz_p_bi_4" "{Z UInteger .H- Z UInteger .H}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
  ("stnt1h_mzx_p_br_2x8" "{Z UInteger .H Z UInteger .H}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
  ("stnt1h_mzx_p_br_4x4" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
  ("stnt1h_mzx_p_bi_2x8" "{Z UInteger .H Z UInteger .H}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
  ("stnt1h_mzx_p_bi_4x4" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
)

(incw
  ("incw_z_zs_" "ZUInteger.S" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
  ("incw_r_rs_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(saddv
  ("saddv_r_p_z_" "DUInteger, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Dd__2" "Pg" "Zn"))
)

(cntd
  ("cntd_r_s_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rd" (reg-range 0 31))) ("Xd__2"))
)

(clrex
  ("CLREX_BN_barriers" "" () ())
)

(sqdecd
  ("sqdecd_z_zs_" "ZUInteger.D" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
  ("sqdecd_r_rs_sx" "XUInteger, WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn" "Wdn"))
  ("sqdecd_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(swpta
  ("SWPTA_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
  ("SWPTA_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(fmlal2
  ("FMLAL2_asimdsame_F" "VUInteger.2S, VUInteger.2H, VUInteger.2H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMLAL2_asimdelem_LH" "VUInteger.2S, VUInteger.2H, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(subps
  ("SUBPS_64S_dp_2src" "XZR, SP, SP" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__6" "XmSP_option__2"))
)

(ldnt1w
  ("ldnt1w_z_p_ar_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ldnt1w_z_p_br_contiguous" "{Z UInteger .S}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ldnt1w_z_p_bi_contiguous" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldnt1w_z_p_ar_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ldnt1w_mz_p_br_2" "{Z UInteger .S- Z UInteger .S}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
  ("ldnt1w_mz_p_br_4" "{Z UInteger .S- Z UInteger .S}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
  ("ldnt1w_mz_p_bi_2" "{Z UInteger .S- Z UInteger .S}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
  ("ldnt1w_mz_p_bi_4" "{Z UInteger .S- Z UInteger .S}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
  ("ldnt1w_mzx_p_br_2x8" "{Z UInteger .S Z UInteger .S}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
  ("ldnt1w_mzx_p_br_4x4" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
  ("ldnt1w_mzx_p_bi_2x8" "{Z UInteger .S Z UInteger .S}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
  ("ldnt1w_mzx_p_bi_4x4" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
)

(lduminab
  ("LDUMINAB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(uaddwb
  ("uaddwb_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(ldxrh
  ("LDXRH_LR32_ldstexclr" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
)

(fcvtzsn
  ("fcvtzsn_z_mz2_" "ZUInteger.B, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
)

(uadalp
  ("uadalp_z_p_z_" "ZUInteger.H, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda__2" "Pg" "Zn__2"))
  ("UADALP_asimdmisc_P" "VUInteger.4H, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(uqincp
  ("uqincp_z_p_z_" "ZUInteger.H, PUInteger.H" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pm__3"))
  ("uqincp_r_p_r_uw" "WUInteger, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Rdn" (reg-range 0 31))) ("Wdn" "Pm__3"))
  ("uqincp_r_p_r_x" "XUInteger, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Rdn" (reg-range 0 31))) ("Xdn" "Pm__3"))
)

(blrabz
  ("BLRABZ_64_branch_reg" "XZR" (("Rn" (reg-range 0 31))) ("XnOrXZR"))
)

(decd
  ("decd_z_zs_" "ZUInteger.D" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
  ("decd_r_rs_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(ldapurh
  ("LDAPURH_32_ldapstl_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
)

(lastb
  ("lastb_v_p_z_" "BUInteger, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V__7" "Pg" "Zn"))
  ("lastb_r_p_z_" "WZR, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Pg" "Zn"))
)

(extr
  ("EXTR_32_extract" "WZR, WZR, WZR, UInteger" (("Rm" (reg-range 0 31)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("EXTR_64_extract" "XZR, XZR, XZR, UInteger" (("Rm" (reg-range 0 31)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
)

(prfw
  ("prfw_i_p_bz_s_x32_scaled" "PLDL1KEEP, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
  ("prfw_i_p_bi_s" "PLDL1KEEP, PUInteger, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3"))
  ("prfw_i_p_br_s" "PLDL1KEEP, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Xm__4"))
  ("prfw_i_p_ai_s" "PLDL1KEEP, PUInteger, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("Pg" "Zn__3"))
  ("prfw_i_p_bz_d_x32_scaled" "PLDL1KEEP, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
  ("prfw_i_p_ai_d" "PLDL1KEEP, PUInteger, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("Pg" "Zn__3"))
  ("prfw_i_p_bz_d_64_scaled" "PLDL1KEEP, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
)

(autiasp
  ("AUTIASP_HI_hints" "" () ())
)

(b
  ("B_only_condbranch" "SInteger" (("imm19" (imm-range 0 524287 1))) ("imm19_offset"))
  ("B_only_branch_imm" "SInteger" (("imm26" (imm-range 0 67108863 1))) ("imm26_offset"))
)

(sqincb
  ("sqincb_r_rs_sx" "XUInteger, WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn" "Wdn"))
  ("sqincb_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(movz
  ("MOVZ_32_movewide" "WZR, UInteger" (("imm16" (imm-range 0 65535 1)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "imm__18"))
  ("MOVZ_64_movewide" "XZR, UInteger" (("imm16" (imm-range 0 65535 1)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "imm__18"))
  ("MOVZ_32_movewide_shift" "WZR, UInteger, lsl, UInteger" (("imm16" (imm-range 0 65535 1)) ("hw" (imm-range 0 1 1)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "imm" "lsl" "shift"))
  ("MOVZ_64_movewide_shift" "XZR, UInteger, lsl, UInteger" (("imm16" (imm-range 0 65535 1)) ("hw" (imm-range 0 3 1)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "imm" "lsl" "shift"))
)

(uabalt
  ("uabalt_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
)

(ssra
  ("ssra_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2"))
  ("SSRA_asisdshf_R" "DUInteger, DUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("SSRA_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__4"))
)

(sminv
  ("sminv_r_p_z_" "BUInteger, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V" "Pg" "Zn"))
  ("SMINV_asimdall_only" "BUInteger, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__2" "Vn"))
)

(cpypn
  ("CPYPN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(rcwssetpl
  ("RCWSSETPL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(bfmax
  ("bfmax_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("bfmax_mz_zzv_2x1" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
  ("bfmax_mz_zzv_4x1" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
  ("bfmax_mz_zzw_2x2" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, {Z UInteger . H- Z UInteger . H}" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
  ("bfmax_mz_zzw_4x4" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, {Z UInteger . H- Z UInteger . H}" (("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
)

(umlsll
  ("umlsll_za_zzi_s" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
  ("umlsll_za_zzi_d" "ZA.D[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
  ("umlsll_za_zzi_s2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm__2"))
  ("umlsll_za_zzi_d2xi" "ZA.D[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm__2"))
  ("umlsll_za_zzi_s4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm__2"))
  ("umlsll_za_zzi_d4xi" "ZA.D[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm__2"))
  ("umlsll_za_zzv_2x1" "ZA.S, [W UInteger UInteger : UInteger VGx2], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn2" "Zm__2"))
  ("umlsll_za_zzv_1" "ZA.S, [W UInteger UInteger : UInteger], ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
  ("umlsll_za_zzv_4x1" "ZA.S, [W UInteger UInteger : UInteger VGx4], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn4" "Zm__2"))
  ("umlsll_za_zzw_2x2" "ZA.S, [W UInteger UInteger : UInteger VGx2], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("umlsll_za_zzw_4x4" "ZA.S, [W UInteger UInteger : UInteger VGx4], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
)

(adds
  ("ADDS_32S_addsub_imm" "WZR, WSP, UInteger" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnWSP_option" "imm__17"))
  ("ADDS_64S_addsub_imm" "XZR, SP, UInteger" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__3" "imm__17"))
  ("ADDS_32_addsub_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("ADDS_64_addsub_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
  ("ADDS_32S_addsub_ext" "WZR, WSP, WZR, UXTB, UInteger" (("Rm" (reg-range 0 31)) ("imm3" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnWSP_option__2" "WmOrWZR__2"))
  ("ADDS_64S_addsub_ext" "XZR, SP, WZR, UXTB, UInteger" (("Rm" (reg-range 0 31)) ("imm3" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__6"))
)

(st64b
  ("ST64B_64L_memop" "XZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__9" "XnSP_option"))
)

(ldsminab
  ("LDSMINAB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(ldeora
  ("LDEORA_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDEORA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(uhsubr
  ("uhsubr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
)

(zip
  ("zip_mz_zz_2" "{Z UInteger . B - Z UInteger . B}, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn__2" "Zm"))
  ("zip_mz_zz_2q" "{Z UInteger .Q- Z UInteger .Q}, ZUInteger.Q, ZUInteger.Q" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn__2" "Zm"))
  ("zip_mz_z_4" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
  ("zip_mz_z_4q" "{Z UInteger .Q- Z UInteger .Q}, {Z UInteger .Q- Z UInteger .Q}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
)

(usubl
  ("USUBL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(ldfmaxnma
  ("LDFMAXNMA_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMAXNMA_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMAXNMA_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(cpymwtwn
  ("CPYMWTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(sqincd
  ("sqincd_z_zs_" "ZUInteger.D" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
  ("sqincd_r_rs_sx" "XUInteger, WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn" "Wdn"))
  ("sqincd_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(pacib
  ("PACIB_64P_dp_1src" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__7"))
)

(ldbfmaxnm
  ("LDBFMAXNM_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(fmaxnmp
  ("fmaxnmp_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("FMAXNMP_asisdpair_only_H" "HUInteger, VUInteger.2H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vn"))
  ("FMAXNMP_asisdpair_only_SD" "SUInteger, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__4" "Vn"))
  ("FMAXNMP_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMAXNMP_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(rcwclrl
  ("RCWCLRL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(ldsminb
  ("LDSMINB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(sttp
  ("STTP_64_ldstpair_post" "XZR, XZR, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__15"))
  ("STTP_Q_ldstpair_post" "QUInteger, QUInteger, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm__16"))
  ("STTP_64_ldstpair_off" "XZR, XZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm7_option__2"))
  ("STTP_Q_ldstpair_off" "QUInteger, QUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm7_option__3"))
  ("STTP_64_ldstpair_pre" "XZR, XZR, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__15"))
  ("STTP_Q_ldstpair_pre" "QUInteger, QUInteger, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm__16"))
)

(ctermne
  ("ctermne_rr_" "WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ())
)

(ldnt1sh
  ("ldnt1sh_z_p_ar_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ldnt1sh_z_p_ar_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
)

(ld3w
  ("ld3w_z_p_br_contiguous" "{Z UInteger .S Z UInteger .S Z UInteger .S}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3" "Xm__4"))
  ("ld3w_z_p_bi_contiguous" "{Z UInteger .S Z UInteger .S Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3"))
)

(sevl
  ("SEVL_HI_hints" "" () ())
)

(sha1su1
  ("SHA1SU1_VV_cryptosha2" "VUInteger.4S, VUInteger.4S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6"))
)

(swpa
  ("SWPA_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
  ("SWPA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(fmlallbb
  ("fmlallbb_z32_z8z8z8_" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("fmlallbb_z32_z8z8z8i_" "ZUInteger.S, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__56"))
  ("FMLALLBB_asimdsame2_G" "VUInteger.4S, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMLALLBB_asimdelem_J" "VUInteger.4S, VUInteger.16B, VUInteger.B[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__6"))
)

(fmlslt
  ("fmlslt_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
  ("fmlslt_z_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
)

(ldbfadda
  ("LDBFADDA_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(facgt
  ("facgt_p_p_zz_" "PUInteger.H, PUInteger/Z, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
  ("FACGT_asisdsamefp16_only" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
  ("FACGT_asisdsame_only" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9" "V_option__9"))
  ("FACGT_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FACGT_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(sqrdmlsh
  ("sqrdmlsh_z_zzz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("sqrdmlsh_z_zzzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
  ("sqrdmlsh_z_zzzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__41"))
  ("sqrdmlsh_z_zzzi_d" "ZUInteger.D, ZUInteger.D, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__42"))
  ("SQRDMLSH_asisdsame2_only" "HUInteger, HUInteger, HUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__8" "V_option__8" "V_option__8"))
  ("SQRDMLSH_asisdelem_R" "HUInteger, HUInteger, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__8" "V_option__8" "Vm__5"))
  ("SQRDMLSH_asimdsame2_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("SQRDMLSH_asimdelem_R" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
)

(fmlallbt
  ("fmlallbt_z32_z8z8z8_" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("fmlallbt_z32_z8z8z8i_" "ZUInteger.S, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__56"))
  ("FMLALLBT_asimdsame2_G" "VUInteger.4S, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMLALLBT_asimdelem_J" "VUInteger.4S, VUInteger.16B, VUInteger.B[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__6"))
)

(gcssttr
  ("GCSSTTR_64_ldst_gcs" "XZR, [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
)

(ld1b
  ("ld1b_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1b_z_p_ai_s" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ld1b_z_p_br_u8" "{Z UInteger .B}, PUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1b_z_p_br_u16" "{Z UInteger .H}, PUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1b_z_p_br_u32" "{Z UInteger .S}, PUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1b_z_p_br_u64" "{Z UInteger .D}, PUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1b_z_p_bi_u8" "{Z UInteger .B}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1b_z_p_bi_u16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1b_z_p_bi_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1b_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1b_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1b_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ld1b_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1b_mz_p_br_2" "{Z UInteger .B- Z UInteger .B}, PNUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
  ("ld1b_mz_p_br_4" "{Z UInteger .B- Z UInteger .B}, PNUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
  ("ld1b_mz_p_bi_2" "{Z UInteger .B- Z UInteger .B}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
  ("ld1b_mz_p_bi_4" "{Z UInteger .B- Z UInteger .B}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
  ("ld1b_mzx_p_br_2x8" "{Z UInteger .B Z UInteger .B}, PNUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
  ("ld1b_mzx_p_br_4x4" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PNUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
  ("ld1b_mzx_p_bi_2x8" "{Z UInteger .B Z UInteger .B}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
  ("ld1b_mzx_p_bi_4x4" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
  ("ld1b_za_p_rrr_" "{ZA0 H .B [W UInteger UInteger]}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("off4" (imm-range 0 15 1))) ("HV" "Ws__3" "offs__2" "Pg" "XnSP__3"))
)

(sudot
  ("sudot_z_zzzi_s" "ZUInteger.S, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__40"))
  ("sudot_za_zzi_s2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("sudot_za_zzi_s4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
  ("sudot_za_zzv_s2x1" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
  ("sudot_za_zzv_s4x1" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
  ("SUDOT_asimdelem_D" "VUInteger.2S, VUInteger.8B, VUInteger.4B[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "H_L"))
)

(ldur
  ("LDUR_B_ldst_unscaled" "BUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option" "imm9_option"))
  ("LDUR_Q_ldst_unscaled" "QUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option" "imm9_option"))
  ("LDUR_H_ldst_unscaled" "HUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option" "imm9_option"))
  ("LDUR_32_ldst_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
  ("LDUR_S_ldst_unscaled" "SUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option" "imm9_option"))
  ("LDUR_64_ldst_unscaled" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
  ("LDUR_D_ldst_unscaled" "DUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option" "imm9_option"))
)

(sm4ekey
  ("sm4ekey_z_zz_" "ZUInteger.S, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("SM4EKEY_VVV4_cryptosha512_3" "VUInteger.4S, VUInteger.4S, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(cpymwn
  ("CPYMWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(uabdlt
  ("uabdlt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(ldaxr
  ("LDAXR_LR32_ldstexclr" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("LDAXR_LR64_ldstexclr" "XZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
)

(rcwsetl
  ("RCWSETL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(cbbne
  ("CBBNE_8_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
)

(stfminnml
  ("STFMINNML_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
  ("STFMINNML_32" "SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
  ("STFMINNML_64" "DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
)

(umlal
  ("umlal_za_zzi_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
  ("umlal_za_zzi_2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm__2"))
  ("umlal_za_zzi_4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm__2"))
  ("umlal_za_zzv_2x1" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn2" "Zm__2"))
  ("umlal_za_zzv_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
  ("umlal_za_zzv_4x1" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn4" "Zm__2"))
  ("umlal_za_zzw_2x2" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("umlal_za_zzw_4x4" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("UMLAL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("UMLAL_asimdelem_L" "VUInteger.4S, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
)

(srshl
  ("srshl_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("srshl_mz_zzv_2x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
  ("srshl_mz_zzv_4x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
  ("srshl_mz_zzw_2x2" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
  ("srshl_mz_zzw_4x4" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
  ("SRSHL_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("SRSHL_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(saddlt
  ("saddlt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(fdup
  ("fdup_z_i_" "ZUInteger.H, Real" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zd" (reg-range 0 31))) ("Zd"))
)

(cpyprt
  ("CPYPRT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(sumlall
  ("sumlall_za_zzi_s" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
  ("sumlall_za_zzi_s2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm__2"))
  ("sumlall_za_zzi_s4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm__2"))
  ("sumlall_za_zzv_s2x1" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger . B- Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn2" "Zm__2"))
  ("sumlall_za_zzv_s4x1" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger . B- Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn4" "Zm__2"))
)

(ushll
  ("USHLL_asimdshf_L" "VUInteger.8H, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__new"))
)

(sli
  ("sli_z_zzi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
  ("SLI_asisdshf_R" "DUInteger, DUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("SLI_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__5"))
)

(cpyfertwn
  ("CPYFERTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(bfcvt
  ("bfcvt_z_p_z_s2bfz" "ZUInteger.H, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("bfcvt_z_p_z_s2bf" "ZUInteger.H, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("bfcvt_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("bfcvt_z8_mz2_" "ZUInteger.B, {Z UInteger .H- Z UInteger .H}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("BFCVT_BS_floatdp1" "HUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Sn"))
)

(ld1d
  ("ld1d_z_p_bi_u128" "{Z UInteger .Q}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1d_z_p_br_u64" "{Z UInteger .D}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1d_z_p_br_u128" "{Z UInteger .Q}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1d_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1d_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1d_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1d_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ld1d_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1d_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1d_mz_p_br_2" "{Z UInteger .D- Z UInteger .D}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
  ("ld1d_mz_p_br_4" "{Z UInteger .D- Z UInteger .D}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
  ("ld1d_mz_p_bi_2" "{Z UInteger .D- Z UInteger .D}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
  ("ld1d_mz_p_bi_4" "{Z UInteger .D- Z UInteger .D}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
  ("ld1d_mzx_p_br_2x8" "{Z UInteger .D Z UInteger .D}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
  ("ld1d_mzx_p_br_4x4" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
  ("ld1d_mzx_p_bi_2x8" "{Z UInteger .D Z UInteger .D}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
  ("ld1d_mzx_p_bi_4x4" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
  ("ld1d_za_p_rrr_" "{ZA UInteger H .D [W UInteger UInteger]}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("ZAt" "HV" "Ws__3" "offs__3" "Pg" "XnSP__3"))
)

(pacibsp
  ("PACIBSP_HI_hints" "" () ())
)

(cpyptn
  ("CPYPTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(stllr
  ("STLLR_SL32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("STLLR_SL64_ldstord" "XZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
)

(mla
  ("mla_z_p_zzz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Pg" "Zn__2" "Zm"))
  ("mla_z_zzzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
  ("mla_z_zzzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__41"))
  ("mla_z_zzzi_d" "ZUInteger.D, ZUInteger.D, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__42"))
  ("MLA_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("MLA_asimdelem_R" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
)

(braaz
  ("BRAAZ_64_branch_reg" "XZR" (("Rn" (reg-range 0 31))) ("XnOrXZR"))
)

(cpymtn
  ("CPYMTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(rcwclr
  ("RCWCLR_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(cmple
  ("cmple_p_p_zw_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
  ("cmple_p_p_zi_" "PUInteger.B, PUInteger/Z, ZUInteger.B, SInteger" (("size" (element-size B H S D)) ("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn" "imm__43"))
)

(cpyet
  ("CPYET_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(uqxtnb
  ("uqxtnb_z_zz_" "ZUInteger.B, ZUInteger.H" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(ldff1b
  ("ldff1b_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1b_z_p_ai_s" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ldff1b_z_p_br_u8" "{Z UInteger .B}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldff1b_z_p_br_u16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldff1b_z_p_br_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldff1b_z_p_br_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldff1b_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1b_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ldff1b_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
)

(udot
  ("udot_z_zzz_" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("udot_z16_zzz_h" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("udot_z32_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("udot_z32_zzzi_" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__35"))
  ("udot_z_zzzi_s" "ZUInteger.S, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__40"))
  ("udot_z_zzzi_d" "ZUInteger.D, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__39"))
  ("udot_z16_zzzi_h" "ZUInteger.H, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__53"))
  ("udot_za32_zzi_2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("udot_za_zzi_s2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("udot_za_zzi_d2xi" "ZA.D[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("udot_za32_zzi_4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
  ("udot_za_zzi_s4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
  ("udot_za_zzi_d4xi" "ZA.D[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
  ("udot_za_zzv_2x1" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
  ("udot_za32_zzv_2x1" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
  ("udot_za_zzv_4x1" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
  ("udot_za32_zzv_4x1" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
  ("udot_za_zzw_2x2" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("udot_za32_zzw_2x2" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("udot_za_zzw_4x4" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("udot_za32_zzw_4x4" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("UDOT_asimdsame2_D" "VUInteger.2S, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "Vm"))
  ("UDOT_asimdelem_D" "VUInteger.2S, VUInteger.8B, VUInteger.4B[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2"))
)

(umulh
  ("umulh_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("umulh_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("UMULH_64_dp_3src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__13" "XmOrXZR__9"))
)

(smlall
  ("smlall_za_zzi_s" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
  ("smlall_za_zzi_d" "ZA.D[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
  ("smlall_za_zzi_s2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm__2"))
  ("smlall_za_zzi_d2xi" "ZA.D[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm__2"))
  ("smlall_za_zzi_s4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm__2"))
  ("smlall_za_zzi_d4xi" "ZA.D[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm__2"))
  ("smlall_za_zzv_2x1" "ZA.S, [W UInteger UInteger : UInteger VGx2], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn2" "Zm__2"))
  ("smlall_za_zzv_1" "ZA.S, [W UInteger UInteger : UInteger], ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
  ("smlall_za_zzv_4x1" "ZA.S, [W UInteger UInteger : UInteger VGx4], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn4" "Zm__2"))
  ("smlall_za_zzw_2x2" "ZA.S, [W UInteger UInteger : UInteger VGx2], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("smlall_za_zzw_4x4" "ZA.S, [W UInteger UInteger : UInteger VGx4], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
)

(sqshrnt
  ("sqshrnt_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(autibz
  ("AUTIBZ_HI_hints" "" () ())
)

(ldurh
  ("LDURH_32_ldst_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
)

(fcmla
  ("fcmla_z_p_zzz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H, 0" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Pg" "Zn__2" "Zm"))
  ("fcmla_z_zzzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger, 0" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__51"))
  ("fcmla_z_zzzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger, 0" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__52"))
  ("FCMLA_asimdsame2_C" "VUInteger.4H, VUInteger.4H, VUInteger.4H, 0" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FCMLA_advsimd_elt" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger], 0" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2"))
)

(ssubltb
  ("ssubltb_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(mrrs
  ("MRRS_RS_systemmovepr" "XZR, XUInteger, ACTLR_EL3" (("Rt" (reg-range 0 31))) ("XtOrXZR__7" "XtPlus1__2"))
)

(ldumaxalh
  ("LDUMAXALH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(ands
  ("ands_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
  ("ANDS_32S_log_imm" "WZR, WZR, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR" "imm__bitmask_w"))
  ("ANDS_64S_log_imm" "XZR, XZR, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11" "imm__bitmask_x"))
  ("ANDS_32_log_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("ANDS_64_log_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
)

(saddl
  ("SADDL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(fminnmv
  ("fminnmv_v_p_z_" "HUInteger, PUInteger, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V__5" "Pg" "Zn"))
  ("FMINNMV_asimdall_only_H" "HUInteger, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_hv" "Vn"))
  ("FMINNMV_asimdall_only_SD" "SUInteger, VUInteger.4S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vn"))
)

(urhadd
  ("urhadd_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("URHADD_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(frint32x
  ("frint32x_z_p_z_z" "ZUInteger.S, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("frint32x_z_p_z_m" "ZUInteger.S, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("FRINT32X_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FRINT32X_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
  ("FRINT32X_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
)

(saddlp
  ("SADDLP_asimdmisc_P" "VUInteger.4H, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(adclt
  ("adclt_z_zzz_" "ZUInteger.S, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
)

(uqsubr
  ("uqsubr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
)

(ldfminnma
  ("LDFMINNMA_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMINNMA_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMINNMA_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(ldtadd
  ("LDTADD_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDTADD_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(ldtxr
  ("LDTXR_LR32_ldstexclr_unpriv" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("LDTXR_LR64_ldstexclr_unpriv" "XZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
)

(caspalt
  ("CASPALT_CP64_comswappr_unpriv" "XUInteger, XUInteger, XUInteger, XUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
)

(raddhnb
  ("raddhnb_z_zz_" "ZUInteger.B, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(uabalb
  ("uabalb_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
)

(eret
  ("ERET_64E_branch_reg" "" () ())
)

(lsrv
  ("LSRV_32_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__4"))
  ("LSRV_64_dp_2src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__7"))
)

(sumops
  ("sumops_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
  ("sumops_za_pp_zz_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn__2" "Zm"))
)

(uqadd
  ("uqadd_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("uqadd_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__27"))
  ("uqadd_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("UQADD_asisdsame_only" "BUInteger, BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7" "V_option__7"))
  ("UQADD_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(fcadd
  ("fcadd_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H, 90" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("FCADD_asimdsame2_C" "VUInteger.4H, VUInteger.4H, VUInteger.4H, 90" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(sub
  ("sub_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("sub_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("sub_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__27"))
  ("sub_za_zzv_2x1" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}, ZUInteger.S" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
  ("sub_za_zzv_4x1" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}, ZUInteger.S" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
  ("sub_za_zzw_2x2" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}, {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("sub_za_zw_2x2" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1" "Zm2"))
  ("sub_za_zzw_4x4" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}, {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("sub_za_zw_4x4" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1__2" "Zm4"))
  ("SUB_32_addsub_imm" "WSP, WSP, UInteger" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdWSP_option" "WnWSP_option" "imm__17"))
  ("SUB_64_addsub_imm" "SP, SP, UInteger" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option" "XnSP_option__3" "imm__17"))
  ("SUB_32_addsub_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("SUB_64_addsub_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
  ("SUB_32_addsub_ext" "WSP, WSP, WZR" (("Rm" (reg-range 0 31)) ("imm3" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdWSP_option" "WnWSP_option__2" "WmOrWZR__2"))
  ("SUB_64_addsub_ext" "SP, SP, WZR, UXTB, UInteger" (("Rm" (reg-range 0 31)) ("imm3" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option" "XnSP_option__6"))
  ("SUB_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("SUB_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(nands
  ("nands_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
)

(uqincb
  ("uqincb_r_rs_uw" "WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Wdn"))
  ("uqincb_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(ldaxp
  ("LDAXP_LP32_ldstexclp" "WZR, WZR, [SP 0]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option"))
  ("LDAXP_LP64_ldstexclp" "XZR, XZR, [SP 0]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(bfmul
  ("bfmul_z_zzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__36"))
  ("bfmul_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("bfmul_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("bfmul_mz_zzw_2x2" "{Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("bfmul_mz_zzw_4x4" "{Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("bfmul_mz_zzv_2x1" "{Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__2" "Zn2__2" "Zm__2"))
  ("bfmul_mz_zzv_4x1" "{Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__3" "Zn4__2" "Zm__2"))
)

(bfmlsl
  ("bfmlsl_za_zzi_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
  ("bfmlsl_za_zzi_2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm__2"))
  ("bfmlsl_za_zzi_4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm__2"))
  ("bfmlsl_za_zzv_2x1" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn2" "Zm__2"))
  ("bfmlsl_za_zzv_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
  ("bfmlsl_za_zzv_4x1" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn4" "Zm__2"))
  ("bfmlsl_za_zzw_2x2" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("bfmlsl_za_zzw_4x4" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
)

(ldclral
  ("LDCLRAL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDCLRAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(msub
  ("MSUB_32A_dp_3src" "WZR, WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__5" "WmOrWZR__6" "WaOrWZR__2"))
  ("MSUB_64A_dp_3src" "XZR, XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__13" "XmOrXZR__9" "XaOrXZR__2"))
)

(cpyprn
  ("CPYPRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(cpymrtn
  ("CPYMRTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(rcwswppl
  ("RCWSWPPL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(ldumin
  ("LDUMIN_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDUMIN_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(uaddwt
  ("uaddwt_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(cbbhi
  ("CBBHI_8_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
)

(stbfmaxnml
  ("STBFMAXNML_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
)

(pmullt
  ("pmullt_z_zz_q" "ZUInteger.Q, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("pmullt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(frint32z
  ("frint32z_z_p_z_z" "ZUInteger.S, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("frint32z_z_p_z_m" "ZUInteger.S, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("FRINT32Z_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FRINT32Z_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
  ("FRINT32Z_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
)

(sqincw
  ("sqincw_z_zs_" "ZUInteger.S" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
  ("sqincw_r_rs_sx" "XUInteger, WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn" "Wdn"))
  ("sqincw_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(hvc
  ("HVC_EX_exception" "UInteger" (("imm16" (imm-range 0 65535 1))) ("imm"))
)

(swppal
  ("SWPPAL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(ldclrpa
  ("LDCLRPA_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(cnot
  ("cnot_z_p_z_m" "ZUInteger.B, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("cnot_z_p_z_z" "ZUInteger.B, PUInteger/Z, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
)

(ld1h
  ("ld1h_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1h_z_p_bz_s_x32_scaled" "{Z UInteger .S}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1h_z_p_ai_s" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ld1h_z_p_br_u16" "{Z UInteger .H}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1h_z_p_br_u32" "{Z UInteger .S}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1h_z_p_br_u64" "{Z UInteger .D}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1h_z_p_bi_u16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1h_z_p_bi_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1h_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1h_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1h_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1h_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ld1h_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1h_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1h_mz_p_br_2" "{Z UInteger .H- Z UInteger .H}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
  ("ld1h_mz_p_br_4" "{Z UInteger .H- Z UInteger .H}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
  ("ld1h_mz_p_bi_2" "{Z UInteger .H- Z UInteger .H}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
  ("ld1h_mz_p_bi_4" "{Z UInteger .H- Z UInteger .H}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
  ("ld1h_mzx_p_br_2x8" "{Z UInteger .H Z UInteger .H}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
  ("ld1h_mzx_p_br_4x4" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
  ("ld1h_mzx_p_bi_2x8" "{Z UInteger .H Z UInteger .H}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
  ("ld1h_mzx_p_bi_4x4" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
  ("ld1h_za_p_rrr_" "{ZA UInteger H .H [W UInteger UInteger]}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("ZAt__2" "HV" "Ws__3" "offs__4" "Pg" "XnSP__3"))
)

(ld1rqh
  ("ld1rqh_z_p_br_contiguous" "{Z UInteger .H}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1rqh_z_p_bi_u16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
)

(ldsetpa
  ("LDSETPA_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(pacia1716
  ("PACIA1716_HI_hints" "" () ())
)

(rax1
  ("rax1_z_zz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("RAX1_VVV2_cryptosha512_3" "VUInteger.2D, VUInteger.2D, VUInteger.2D" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(fmaxqv
  ("fmaxqv_z_p_z_" "VUInteger.8H, PUInteger, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
)

(smullb
  ("smullb_z_zzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__78"))
  ("smullb_z_zzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__2" "imm__88"))
  ("smullb_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(yield
  ("YIELD_HI_hints" "" () ())
)

(rcwcasp
  ("RCWCASP_C64_rcwcomswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
)

(crc32b
  ("CRC32B_32C_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR__2" "WnOrWZR__4" "WmOrWZR__5"))
)

(rcwcasl
  ("RCWCASL_C64_rcwcomswap" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
)

(stgm
  ("STGM_64bulk_ldsttags" "XZR, [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__3" "XnSP_option"))
)

(cbhne
  ("CBHNE_16_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
)

(umaxp
  ("umaxp_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("UMAXP_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(ucvtf
  ("ucvtf_z_p_z_w2sz" "ZUInteger.S, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("ucvtf_z_p_z_w2dz" "ZUInteger.D, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("ucvtf_z_p_z_x2sz" "ZUInteger.S, PUInteger/Z, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("ucvtf_z_p_z_x2dz" "ZUInteger.D, PUInteger/Z, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("ucvtf_z_p_z_h2fp16z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("ucvtf_z_p_z_w2fp16z" "ZUInteger.H, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("ucvtf_z_p_z_x2fp16z" "ZUInteger.H, PUInteger/Z, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("ucvtf_z_p_z_w2s" "ZUInteger.S, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("ucvtf_z_p_z_w2d" "ZUInteger.D, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("ucvtf_z_p_z_x2s" "ZUInteger.S, PUInteger/M, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("ucvtf_z_p_z_x2d" "ZUInteger.D, PUInteger/M, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("ucvtf_z_p_z_h2fp16" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("ucvtf_z_p_z_w2fp16" "ZUInteger.H, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("ucvtf_z_p_z_x2fp16" "ZUInteger.H, PUInteger/M, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("ucvtf_z_z_" "ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
  ("ucvtf_mz_z_2" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__4" "Zn2__3"))
  ("ucvtf_mz_z_4" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
  ("UCVTF_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
  ("UCVTF_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("UCVTF_asisdshf_C" "HUInteger, HUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__6" "V_option__6" "immh_shift__3"))
  ("UCVTF_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("UCVTF_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("UCVTF_asimdshf_C" "VUInteger.4H, VUInteger.4H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__9"))
  ("UCVTF_S32_float2fix" "SUInteger, WZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "WnOrWZR"))
  ("UCVTF_D32_float2fix" "DUInteger, WZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "WnOrWZR"))
  ("UCVTF_H32_float2fix" "HUInteger, WZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "WnOrWZR"))
  ("UCVTF_S64_float2fix" "SUInteger, XZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "XnOrXZR__11"))
  ("UCVTF_D64_float2fix" "DUInteger, XZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "XnOrXZR__11"))
  ("UCVTF_H64_float2fix" "HUInteger, XZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "XnOrXZR__11"))
  ("UCVTF_S32_float2int" "SUInteger, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "WnOrWZR"))
  ("UCVTF_D32_float2int" "DUInteger, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "WnOrWZR"))
  ("UCVTF_H32_float2int" "HUInteger, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "WnOrWZR"))
  ("UCVTF_S64_float2int" "SUInteger, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "XnOrXZR__11"))
  ("UCVTF_D64_float2int" "DUInteger, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "XnOrXZR__11"))
  ("UCVTF_H64_float2int" "HUInteger, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "XnOrXZR__11"))
  ("UCVTF_sisd_32D" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
  ("UCVTF_sisd_32H" "HUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Sn"))
  ("UCVTF_sisd_64H" "HUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Dn"))
  ("UCVTF_sisd_64S" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
)

(xar
  ("xar_z_zzi_" "ZUInteger.B, ZUInteger.B, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm"))
  ("XAR_VVV2_crypto3_imm6" "VUInteger.2D, VUInteger.2D, VUInteger.2D, UInteger" (("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm" "imm6"))
)

(bc
  ("BC_only_condbranch" "SInteger" (("imm19" (imm-range 0 524287 1))) ("imm19_offset"))
)

(pacdza
  ("PACDZA_64Z_dp_1src" "XZR" (("Rd" (reg-range 0 31))) ("XdOrXZR__6"))
)

(sqrdcmlah
  ("sqrdcmlah_z_zzz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B, 0" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("sqrdcmlah_z_zzzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger, 0" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__41"))
  ("sqrdcmlah_z_zzzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger, 0" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__42"))
)

(st3w
  ("st3w_z_p_br_contiguous" "{Z UInteger .S Z UInteger .S Z UInteger .S}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3" "Xm__4"))
  ("st3w_z_p_bi_contiguous" "{Z UInteger .S Z UInteger .S Z UInteger .S}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3"))
)

(setmt
  ("SETMT_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__3" "XnOrXZR__6" "XsOrXZR__7"))
)

(smsubl
  ("SMSUBL_64WA_dp_3src" "XZR, WZR, WZR, XZR" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "WnOrWZR__5" "WmOrWZR__6" "XaOrXZR__2"))
)

(ldff1sw
  ("ldff1sw_z_p_br_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldff1sw_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1sw_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1sw_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ldff1sw_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1sw_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
)

(luti6
  ("luti6_z_zzz_8" "ZUInteger.B, {Z UInteger .B Z UInteger .B}, ZUInteger" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__7" "Zn2__5" "Zm__5"))
  ("luti6_z_zzz_16" "ZUInteger.H, {Z UInteger .H Z UInteger .H}, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__7" "Zn2__5" "Zm__5"))
  ("luti6_z_ztz_" "ZUInteger.B, ZT0, ZUInteger" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
  ("luti6_mz4_ztmz3_1" "{Z UInteger .B - Z UInteger .B}, ZT0, {Z UInteger - Z UInteger}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__9" "Zn3"))
  ("luti6_mz4_ztmz3_4" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, ZT0, {Z UInteger - Z UInteger}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 3))) ("Zd1__4" "Zd2__3" "Zd3" "Zd4__2" "Zn1__9" "Zn3"))
  ("luti6_mz4_zmz2_1" "{Z UInteger .H - Z UInteger .H}, {Z UInteger .H Z UInteger .H}, {Z UInteger - Z UInteger}, [UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__7" "Zn2__5" "Zm1__5" "Zm2__3"))
  ("luti6_mz4_zmz2_4" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, {Z UInteger .H Z UInteger .H}, {Z UInteger - Z UInteger}, [UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 3))) ("Zd1__4" "Zd2__3" "Zd3" "Zd4__2" "Zn1__7" "Zn2__5" "Zm1__5" "Zm2__3"))
)

(revw
  ("revw_z_z_m" "ZUInteger.D, PUInteger/M, ZUInteger.D" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("revw_z_z_z" "ZUInteger.D, PUInteger/Z, ZUInteger.D" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
)

(stfminl
  ("STFMINL_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
  ("STFMINL_32" "SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
  ("STFMINL_64" "DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
)

(stbfaddl
  ("STBFADDL_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
)

(smlalt
  ("smlalt_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("smlalt_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
  ("smlalt_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
)

(cfinv
  ("CFINV_M_pstate" "" () ())
)

(sumop4a
  ("sumop4a_za_zz_b1x1" "ZAUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
  ("sumop4a_za_zz_b1x2" "ZAUInteger.S, ZUInteger.B, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("sumop4a_za_zz_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("sumop4a_za_zz_b2x2" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("sumop4a_za_zz_h1x1" "ZAUInteger.D, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm_mortlach"))
  ("sumop4a_za_zz_h1x2" "ZAUInteger.D, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("sumop4a_za_zz_h2x1" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("sumop4a_za_zz_h2x2" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
)

(rdvl
  ("rdvl_r_i_" "XUInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("Rd" (reg-range 0 31))) ("Xd__2" "imm__28"))
)

(rcwsetpl
  ("RCWSETPL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(ldclrah
  ("LDCLRAH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(brkns
  ("brkns_p_p_pp_" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pdm" (reg-range 0 15))) ("Pdm" "Pg__2" "Pn__2" "Pdm"))
)

(st1b
  ("st1b_z_p_br_" "{Z UInteger . B}, PUInteger, [SP X UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("st1b_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("st1b_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("st1b_z_p_bz_d_64_unscaled" "{Z UInteger . D}, PUInteger, [SP Z UInteger . D]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("st1b_z_p_ai_d" "{Z UInteger .D}, PUInteger, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("st1b_z_p_ai_s" "{Z UInteger .S}, PUInteger, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("st1b_z_p_bi_" "{Z UInteger . B}, PUInteger, [SP]" (("size" (element-size B H S D)) ("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("st1b_mz_p_br_2" "{Z UInteger .B- Z UInteger .B}, PNUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
  ("st1b_mz_p_br_4" "{Z UInteger .B- Z UInteger .B}, PNUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
  ("st1b_mz_p_bi_2" "{Z UInteger .B- Z UInteger .B}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
  ("st1b_mz_p_bi_4" "{Z UInteger .B- Z UInteger .B}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
  ("st1b_mzx_p_br_2x8" "{Z UInteger .B Z UInteger .B}, PNUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
  ("st1b_mzx_p_br_4x4" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PNUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
  ("st1b_mzx_p_bi_2x8" "{Z UInteger .B Z UInteger .B}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
  ("st1b_mzx_p_bi_4x4" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
  ("st1b_za_p_rrr_" "{ZA0 H .B [W UInteger UInteger]}, PUInteger, [SP]" (("Rm" (reg-range 0 31)) ("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("off4" (imm-range 0 15 1))) ("HV" "Ws__3" "offs__2" "Pg" "XnSP__3"))
)

(ldtaddl
  ("LDTADDL_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDTADDL_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(pacnbiasppc
  ("PACNBIASPPC_64LR_dp_1src" "" () ())
)

(hint
  ("HINT_HM_hints" "UInteger" () ())
)

(cpyen
  ("CPYEN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(subp
  ("subp_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("SUBP_64S_dp_2src" "XZR, SP, SP" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__6" "XmSP_option__2"))
)

(bf1cvtlt
  ("bf1cvtlt_z_z8_b2bf" "ZUInteger.H, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(cmgt
  ("CMGT_asisdmisc_Z" "DUInteger, DUInteger, 0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("CMGT_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("CMGT_asimdmisc_Z" "VUInteger.8B, VUInteger.8B, 0" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("CMGT_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(ldaddalh
  ("LDADDALH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(fmad
  ("fmad_z_p_zzz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Za" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zm" "Za"))
)

(setf8
  ("SETF8_only_setf" "WZR" (("Rn" (reg-range 0 31))) ("WnOrWZR"))
)

(ldeorl
  ("LDEORL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDEORL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(bfmin
  ("bfmin_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("bfmin_mz_zzv_2x1" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
  ("bfmin_mz_zzv_4x1" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
  ("bfmin_mz_zzw_2x2" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, {Z UInteger . H- Z UInteger . H}" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
  ("bfmin_mz_zzw_4x4" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, {Z UInteger . H- Z UInteger . H}" (("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
)

(cpyfmtrn
  ("CPYFMTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(lsrr
  ("lsrr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
)

(ldumaxalb
  ("LDUMAXALB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(pacib171615
  ("PACIB171615_64LR_dp_1src" "" () ())
)

(sha256su1
  ("SHA256SU1_VVV_cryptosha3" "VUInteger.4S, VUInteger.4S, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6" "Vm__7"))
)

(fabs
  ("fabs_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fabs_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("FABS_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FABS_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FABS_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
  ("FABS_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
  ("FABS_H_floatdp1" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
)

(ldumax
  ("LDUMAX_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDUMAX_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(addvl
  ("addvl_r_ri_" "SP, SP, SInteger" (("Rn" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rd" (reg-range 0 31))) ("XdSP__2" "XnSP__2" "imm__28"))
)

(tbx
  ("tbx_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("TBX_asimdtbl_L1_1" "VUInteger.8B, {V UInteger . 16B}, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__3" "Vm__3"))
  ("TBX_asimdtbl_L2_2" "VUInteger.8B, {V UInteger . 16B V UInteger . 16B}, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__4" "VnPlus1" "Vm__3"))
  ("TBX_asimdtbl_L3_3" "VUInteger.8B, {V UInteger . 16B V UInteger . 16B V UInteger . 16B}, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__4" "VnPlus1" "VnPlus2" "Vm__3"))
  ("TBX_asimdtbl_L4_4" "VUInteger.8B, {V UInteger . 16B V UInteger . 16B V UInteger . 16B V UInteger . 16B}, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__4" "VnPlus1" "VnPlus2" "VnPlus3" "Vm__3"))
)

(sqcvt
  ("sqcvt_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("sqcvt_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
)

(luti2
  ("luti2_z_zz_8" "ZUInteger.B, {Z UInteger .B}, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__4" "Zm__5"))
  ("luti2_z_zz_16" "ZUInteger.H, {Z UInteger .H}, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__4" "Zm__5"))
  ("luti2_mz2_ztz_1" "{Z UInteger . B - Z UInteger . B}, ZT0, ZUInteger[UInteger]" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
  ("luti2_mz4_ztz_1" "{Z UInteger . B - Z UInteger . B}, ZT0, ZUInteger[UInteger]" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn"))
  ("luti2_z_ztz_" "ZUInteger.B, ZT0, ZUInteger[UInteger]" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
  ("luti2_mz2_ztz_8" "{Z UInteger . B Z UInteger . B}, ZT0, ZUInteger[UInteger]" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 7))) ("Zd1__3" "Zd2__2" "Zn"))
  ("luti2_mz4_ztz_4" "{Z UInteger . B Z UInteger . B Z UInteger . B Z UInteger . B}, ZT0, ZUInteger[UInteger]" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 3))) ("Zd1__4" "Zd2__3" "Zd3" "Zd4__2" "Zn"))
  ("LUTI2_asimdtbl_L5" "VUInteger.16B, {V UInteger . 16B}, VUInteger[UInteger]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__3" "Vm__4"))
  ("LUTI2_asimdtbl_L6" "VUInteger.8H, {V UInteger . 8H}, VUInteger[UInteger]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__3" "Vm__4"))
)

(sshllb
  ("sshllb_z_zi_" "ZUInteger.H, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(ssubw
  ("SSUBW_asimddiff_W" "VUInteger.8H, VUInteger.8H, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(fcmle
  ("fcmle_p_p_z0_" "PUInteger.H, PUInteger/Z, ZUInteger.H, 0.0" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn"))
  ("FCMLE_asisdmiscfp16_FZ" "HUInteger, HUInteger, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
  ("FCMLE_asisdmisc_FZ" "SUInteger, SUInteger, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("FCMLE_asimdmiscfp16_FZ" "VUInteger.4H, VUInteger.4H, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCMLE_asimdmisc_FZ" "VUInteger.2S, VUInteger.2S, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(whilelt
  ("whilelt_pn_rr_" "PNUInteger.B, XUInteger, XUInteger, VLx2" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("PNd" (reg-range 0 7))) ("PNd" "Xn__4" "Xm__6"))
  ("whilelt_pp_rr_" "{P UInteger . B P UInteger . B}, XUInteger, XUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 7))) ("Pd1__2" "Pd2__2" "Xn__4" "Xm__6"))
  ("whilelt_p_p_rr_" "PUInteger.B, WZR, WZR" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd"))
)

(tbz
  ("TBZ_only_testbranch" "WZR, UInteger, SInteger" (("imm14" (imm-range 0 16383 1)) ("Rt" (reg-range 0 31))) ("imm_0_63" "imm14_offset"))
)

(rcwclrp
  ("RCWCLRP_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(casb
  ("CASB_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
)

(ssubwt
  ("ssubwt_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(rev16
  ("REV16_32_dp_1src" "WZR, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
  ("REV16_64_dp_1src" "XZR, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
  ("REV16_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(fnmul
  ("FNMUL_S_floatdp2" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__3" "Sm"))
  ("FNMUL_D_floatdp2" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__2" "Dm"))
  ("FNMUL_H_floatdp2" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
)

(ld1rw
  ("ld1rw_z_p_bi_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1rw_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
)

(sabalb
  ("sabalb_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
)

(usvdot
  ("usvdot_za_zzi_s4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
)

(cbhhi
  ("CBHHI_16_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
)

(ldtnp
  ("LDTNP_64_ldstnapair_offs" "XZR, XZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm7_option__2"))
  ("LDTNP_Q_ldstnapair_offs" "QUInteger, QUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm7_option__3"))
)

(rcwscasa
  ("RCWSCASA_C64_rcwcomswap" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
)

(mova
  ("mova_za_p_rz_b" "ZA0H.B[WUInteger, UInteger, PUInteger/M, ZUInteger.B" (("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("off4" (imm-range 0 15 1))) ("HV__7" "Ws__3" "offs__2" "Pg" "Zn"))
  ("mova_za_p_rz_h" "ZAUIntegerH.H[WUInteger, UInteger, PUInteger/M, ZUInteger.H" (("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("ZAd__2" "HV__7" "Ws__3" "offs__4" "Pg" "Zn"))
  ("mova_za_p_rz_w" "ZAUIntegerH.S[WUInteger, UInteger, PUInteger/M, ZUInteger.S" (("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("ZAd__3" "HV__7" "Ws__3" "offs__6" "Pg" "Zn"))
  ("mova_za_p_rz_d" "ZAUIntegerH.D[WUInteger, UInteger, PUInteger/M, ZUInteger.D" (("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAd" "HV__7" "Ws__3" "offs__3" "Pg" "Zn"))
  ("mova_za_p_rz_q" "ZAUIntegerH.Q[WUInteger, 0, PUInteger/M, ZUInteger.Q" (("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAd__4" "HV__7" "Ws__3" "offs__5" "Pg" "Zn"))
  ("mova_za2_z_b1" "ZA0H.B[WUInteger, UInteger:UInteger, {Z UInteger .B- Z UInteger .B}" (("Rs" (reg-range 0 3)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("HV__5" "Ws__3" "offs1__5" "offs2__3" "Zn1__4" "Zn2__3"))
  ("mova_za2_z_h1" "ZAUIntegerH.H[WUInteger, UInteger:UInteger, {Z UInteger .H- Z UInteger .H}" (("Rs" (reg-range 0 3)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("ZAd__2" "HV__5" "Ws__3" "offs1__7" "offs2__5" "Zn1__4" "Zn2__3"))
  ("mova_za2_z_w1" "ZAUIntegerH.S[WUInteger, UInteger:UInteger, {Z UInteger .S- Z UInteger .S}" (("Rs" (reg-range 0 3)) ("Zn" (reg-range 0 15))) ("ZAd__3" "HV__5" "Ws__3" "offs1__8" "offs2__6" "Zn1__4" "Zn2__3"))
  ("mova_za2_z_d1" "ZAUIntegerH.D[WUInteger, 0:1, {Z UInteger .D- Z UInteger .D}" (("Rs" (reg-range 0 3)) ("Zn" (reg-range 0 15))) ("ZAd" "HV__5" "Ws__3" "offs1__6" "offs2__4" "Zn1__4" "Zn2__3"))
  ("mova_za4_z_b1" "ZA0H.B[WUInteger, UInteger:UInteger, {Z UInteger .B- Z UInteger .B}" (("Rs" (reg-range 0 3)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("HV__6" "Ws__3" "offs1__9" "offs4__3" "Zn1__6" "Zn4__3"))
  ("mova_za4_z_h1" "ZAUIntegerH.H[WUInteger, UInteger:UInteger, {Z UInteger .H- Z UInteger .H}" (("Rs" (reg-range 0 3)) ("Zn" (reg-range 0 7))) ("ZAd__2" "HV__6" "Ws__3" "offs1__10" "offs4__5" "Zn1__6" "Zn4__3"))
  ("mova_za4_z_w1" "ZAUIntegerH.S[WUInteger, 0:3, {Z UInteger .S- Z UInteger .S}" (("Rs" (reg-range 0 3)) ("Zn" (reg-range 0 7))) ("ZAd__3" "HV__6" "Ws__3" "offs1__6" "offs4__4" "Zn1__6" "Zn4__3"))
  ("mova_za4_z_d1" "ZAUIntegerH.D[WUInteger, 0:3, {Z UInteger .D- Z UInteger .D}" (("Rs" (reg-range 0 3)) ("Zn" (reg-range 0 7))) ("ZAd" "HV__6" "Ws__3" "offs1__6" "offs4__4" "Zn1__6" "Zn4__3"))
  ("mova_za_mz2_1" "ZA.D[WUInteger, UInteger, VGx2, {Z UInteger .D- Z UInteger .D}" (("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__4" "Zn2__3"))
  ("mova_za_mz4_1" "ZA.D[WUInteger, UInteger, VGx4, {Z UInteger .D- Z UInteger .D}" (("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__6" "Zn4__3"))
  ("mova_z_p_rza_b" "ZUInteger.B, PUInteger/M, ZA0H.B[WUInteger, UInteger" (("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("off4" (imm-range 0 15 1)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "HV__4" "Ws__3" "offs__2"))
  ("mova_z_p_rza_h" "ZUInteger.H, PUInteger/M, ZAUIntegerH.H[WUInteger, UInteger" (("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("off3" (imm-range 0 7 1)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "ZAn__2" "HV__4" "Ws__3" "offs__4"))
  ("mova_z_p_rza_w" "ZUInteger.S, PUInteger/M, ZAUIntegerH.S[WUInteger, UInteger" (("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("off2" (imm-range 0 3 1)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "ZAn__3" "HV__4" "Ws__3" "offs__6"))
  ("mova_z_p_rza_d" "ZUInteger.D, PUInteger/M, ZAUIntegerH.D[WUInteger, UInteger" (("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "ZAn" "HV__4" "Ws__3" "offs__3"))
  ("mova_z_p_rza_q" "ZUInteger.Q, PUInteger/M, ZAUIntegerH.Q[WUInteger, 0" (("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "ZAn__4" "HV__4" "Ws__3" "offs__5"))
  ("mova_mz2_za_b1" "{Z UInteger .B- Z UInteger .B}, ZA0H.B[WUInteger, UInteger:UInteger" (("Rs" (reg-range 0 3)) ("off3" (imm-range 0 7 1)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "HV__2" "Ws__3" "offs1__5" "offs2__3"))
  ("mova_mz2_za_h1" "{Z UInteger .H- Z UInteger .H}, ZAUIntegerH.H[WUInteger, UInteger:UInteger" (("Rs" (reg-range 0 3)) ("off2" (imm-range 0 3 1)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "ZAn__2" "HV__2" "Ws__3" "offs1__7" "offs2__5"))
  ("mova_mz2_za_w1" "{Z UInteger .S- Z UInteger .S}, ZAUIntegerH.S[WUInteger, UInteger:UInteger" (("Rs" (reg-range 0 3)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "ZAn__3" "HV__2" "Ws__3" "offs1__8" "offs2__6"))
  ("mova_mz2_za_d1" "{Z UInteger .D- Z UInteger .D}, ZAUIntegerH.D[WUInteger, 0:1" (("Rs" (reg-range 0 3)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "ZAn" "HV__2" "Ws__3" "offs1__6" "offs2__4"))
  ("mova_mz4_za_b1" "{Z UInteger .B- Z UInteger .B}, ZA0H.B[WUInteger, UInteger:UInteger" (("Rs" (reg-range 0 3)) ("off2" (imm-range 0 3 1)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "HV__3" "Ws__3" "offs1__9" "offs4__3"))
  ("mova_mz4_za_h1" "{Z UInteger .H- Z UInteger .H}, ZAUIntegerH.H[WUInteger, UInteger:UInteger" (("Rs" (reg-range 0 3)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "ZAn__2" "HV__3" "Ws__3" "offs1__10" "offs4__5"))
  ("mova_mz4_za_w1" "{Z UInteger .S- Z UInteger .S}, ZAUIntegerH.S[WUInteger, 0:3" (("Rs" (reg-range 0 3)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "ZAn__3" "HV__3" "Ws__3" "offs1__6" "offs4__4"))
  ("mova_mz4_za_d1" "{Z UInteger .D- Z UInteger .D}, ZAUIntegerH.D[WUInteger, 0:3" (("Rs" (reg-range 0 3)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "ZAn" "HV__3" "Ws__3" "offs1__6" "offs4__4"))
  ("mova_mz_za2_1" "{Z UInteger .D- Z UInteger .D}, ZA.D[WUInteger, UInteger, VGx2" (("off3" (imm-range 0 7 1)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Wv" "offs"))
  ("mova_mz_za4_1" "{Z UInteger .D- Z UInteger .D}, ZA.D[WUInteger, UInteger, VGx4" (("off3" (imm-range 0 7 1)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Wv" "offs"))
)

(caspat
  ("CASPAT_CP64_comswappr_unpriv" "XUInteger, XUInteger, XUInteger, XUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
)

(rcwsset
  ("RCWSSET_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(cls
  ("cls_z_p_z_m" "ZUInteger.B, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("cls_z_p_z_z" "ZUInteger.B, PUInteger/Z, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("CLS_32_dp_1src" "WZR, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
  ("CLS_64_dp_1src" "XZR, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
  ("CLS_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(setmn
  ("SETMN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__3" "XnOrXZR__6" "XsOrXZR__7"))
)

(rcwsclr
  ("RCWSCLR_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(ldeorh
  ("LDEORH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(fminnmp
  ("fminnmp_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("FMINNMP_asisdpair_only_H" "HUInteger, VUInteger.2H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vn"))
  ("FMINNMP_asisdpair_only_SD" "SUInteger, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__4" "Vn"))
  ("FMINNMP_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMINNMP_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(gmi
  ("GMI_64G_dp_2src" "XZR, SP, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__6" "XmOrXZR__4"))
)

(movaz
  ("movaz_z_rza_b" "ZUInteger.B, ZA0H.B[WUInteger, UInteger" (("Rs" (reg-range 0 3)) ("off4" (imm-range 0 15 1)) ("Zd" (reg-range 0 31))) ("Zd" "HV__4" "Ws__3" "offs__2"))
  ("movaz_z_rza_h" "ZUInteger.H, ZAUIntegerH.H[WUInteger, UInteger" (("Rs" (reg-range 0 3)) ("off3" (imm-range 0 7 1)) ("Zd" (reg-range 0 31))) ("Zd" "ZAn__2" "HV__4" "Ws__3" "offs__4"))
  ("movaz_z_rza_w" "ZUInteger.S, ZAUIntegerH.S[WUInteger, UInteger" (("Rs" (reg-range 0 3)) ("off2" (imm-range 0 3 1)) ("Zd" (reg-range 0 31))) ("Zd" "ZAn__3" "HV__4" "Ws__3" "offs__6"))
  ("movaz_z_rza_d" "ZUInteger.D, ZAUIntegerH.D[WUInteger, UInteger" (("Rs" (reg-range 0 3)) ("Zd" (reg-range 0 31))) ("Zd" "ZAn" "HV__4" "Ws__3" "offs__3"))
  ("movaz_z_rza_q" "ZUInteger.Q, ZAUIntegerH.Q[WUInteger, 0" (("Rs" (reg-range 0 3)) ("Zd" (reg-range 0 31))) ("Zd" "ZAn__4" "HV__4" "Ws__3" "offs__5"))
  ("movaz_mz2_za_b1" "{Z UInteger .B- Z UInteger .B}, ZA0H.B[WUInteger, UInteger:UInteger" (("Rs" (reg-range 0 3)) ("off3" (imm-range 0 7 1)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "HV__2" "Ws__3" "offs1__5" "offs2__3"))
  ("movaz_mz2_za_h1" "{Z UInteger .H- Z UInteger .H}, ZAUIntegerH.H[WUInteger, UInteger:UInteger" (("Rs" (reg-range 0 3)) ("off2" (imm-range 0 3 1)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "ZAn__2" "HV__2" "Ws__3" "offs1__7" "offs2__5"))
  ("movaz_mz2_za_w1" "{Z UInteger .S- Z UInteger .S}, ZAUIntegerH.S[WUInteger, UInteger:UInteger" (("Rs" (reg-range 0 3)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "ZAn__3" "HV__2" "Ws__3" "offs1__8" "offs2__6"))
  ("movaz_mz2_za_d1" "{Z UInteger .D- Z UInteger .D}, ZAUIntegerH.D[WUInteger, 0:1" (("Rs" (reg-range 0 3)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "ZAn" "HV__2" "Ws__3" "offs1__6" "offs2__4"))
  ("movaz_mz4_za_b1" "{Z UInteger .B- Z UInteger .B}, ZA0H.B[WUInteger, UInteger:UInteger" (("Rs" (reg-range 0 3)) ("off2" (imm-range 0 3 1)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "HV__3" "Ws__3" "offs1__9" "offs4__3"))
  ("movaz_mz4_za_h1" "{Z UInteger .H- Z UInteger .H}, ZAUIntegerH.H[WUInteger, UInteger:UInteger" (("Rs" (reg-range 0 3)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "ZAn__2" "HV__3" "Ws__3" "offs1__10" "offs4__5"))
  ("movaz_mz4_za_w1" "{Z UInteger .S- Z UInteger .S}, ZAUIntegerH.S[WUInteger, 0:3" (("Rs" (reg-range 0 3)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "ZAn__3" "HV__3" "Ws__3" "offs1__6" "offs4__4"))
  ("movaz_mz4_za_d1" "{Z UInteger .D- Z UInteger .D}, ZAUIntegerH.D[WUInteger, 0:3" (("Rs" (reg-range 0 3)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "ZAn" "HV__3" "Ws__3" "offs1__6" "offs4__4"))
  ("movaz_mz_za2_1" "{Z UInteger .D- Z UInteger .D}, ZA.D[WUInteger, UInteger, VGx2" (("off3" (imm-range 0 7 1)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Wv" "offs"))
  ("movaz_mz_za4_1" "{Z UInteger .D- Z UInteger .D}, ZA.D[WUInteger, UInteger, VGx4" (("off3" (imm-range 0 7 1)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Wv" "offs"))
)

(luti4
  ("luti4_z_zz_8" "ZUInteger.B, {Z UInteger .B}, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__4" "Zm__5"))
  ("luti4_z_zz_2x16" "ZUInteger.H, {Z UInteger .H Z UInteger . H}, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__7" "Zn2__5" "Zm__5"))
  ("luti4_z_zz_1x16" "ZUInteger.H, {Z UInteger .H}, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__4" "Zm__5"))
  ("luti4_mz2_ztz_1" "{Z UInteger . B - Z UInteger . B}, ZT0, ZUInteger[UInteger]" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
  ("luti4_mz4_ztz_1" "{Z UInteger . H - Z UInteger . H}, ZT0, ZUInteger[UInteger]" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn"))
  ("luti4_z_ztz_" "ZUInteger.B, ZT0, ZUInteger[UInteger]" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
  ("luti4_mz4_ztmz2_1" "{Z UInteger .B- Z UInteger .B}, ZT0, {Z UInteger - Z UInteger}" (("size" (element-size B H S D)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__4" "Zn2__3"))
  ("luti4_mz2_ztz_8" "{Z UInteger . B Z UInteger . B}, ZT0, ZUInteger[UInteger]" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 7))) ("Zd1__3" "Zd2__2" "Zn"))
  ("luti4_mz4_ztz_4" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, ZT0, ZUInteger[UInteger]" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 3))) ("Zd1__4" "Zd2__3" "Zd3" "Zd4__2" "Zn"))
  ("luti4_mz4_ztmz2_4" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, ZT0, {Z UInteger - Z UInteger}" (("size" (element-size B H S D)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 3))) ("Zd1__4" "Zd2__3" "Zd3" "Zd4__2" "Zn1__4" "Zn2__3"))
  ("LUTI4_asimdtbl_L7" "VUInteger.8H, {V UInteger . 8H V UInteger . 8H}, VUInteger[UInteger]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn1" "Vn2" "Vm__4"))
  ("LUTI4_asimdtbl_L5" "VUInteger.16B, {V UInteger . 16B}, VUInteger[UInteger]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__3" "Vm__4"))
)

(sqdmlsl
  ("SQDMLSL_asisddiff_only" "SUInteger, HUInteger, HUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Va_option__2" "Vb_option__2" "Vb_option__2"))
  ("SQDMLSL_asisdelem_L" "SUInteger, HUInteger, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Va_option__2" "Vb_option__2" "Vm__5"))
  ("SQDMLSL_asimddiff_L" "VUInteger.4S, VUInteger.4H, VUInteger.4H" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("SQDMLSL_asimdelem_L" "VUInteger.4S, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
)

(setmtn
  ("SETMTN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__3" "XnOrXZR__6" "XsOrXZR__7"))
)

(xpacd
  ("XPACD_64Z_dp_1src" "XZR" (("Rd" (reg-range 0 31))) ("XdOrXZR__6"))
)

(msb
  ("msb_z_p_zzz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Za" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zm" "Za"))
)

(swpalh
  ("SWPALH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
)

(cbhhs
  ("CBHHS_16_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
)

(crc32cx
  ("CRC32CX_64C_dp_2src" "WZR, WZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR__2" "WnOrWZR__4" "XmOrXZR__8"))
)

(subhnt
  ("subhnt_z_zz_" "ZUInteger.B, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(fmop4s
  ("fmop4s_za_zz_s1x1" "ZAUInteger.S, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
  ("fmop4s_za_zz_s1x2" "ZAUInteger.S, ZUInteger.S, {Z UInteger .S- Z UInteger .S}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("fmop4s_za_zz_s2x1" "ZAUInteger.S, {Z UInteger .S- Z UInteger .S}, ZUInteger.S" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("fmop4s_za_zz_s2x2" "ZAUInteger.S, {Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("fmop4s_za32_zz_h1x1" "ZAUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
  ("fmop4s_za32_zz_h1x2" "ZAUInteger.S, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("fmop4s_za32_zz_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("fmop4s_za32_zz_h2x2" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("fmop4s_za_zz_h1x1" "ZAUInteger.H, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn_mortlach" "Zm_mortlach"))
  ("fmop4s_za_zz_h1x2" "ZAUInteger.H, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("fmop4s_za_zz_h2x1" "ZAUInteger.H, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("fmop4s_za_zz_h2x2" "ZAUInteger.H, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("fmop4s_za_zz_d1x1" "ZAUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm_mortlach"))
  ("fmop4s_za_zz_d1x2" "ZAUInteger.D, ZUInteger.D, {Z UInteger .D- Z UInteger .D}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("fmop4s_za_zz_d2x1" "ZAUInteger.D, {Z UInteger .D- Z UInteger .D}, ZUInteger.D" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("fmop4s_za_zz_d2x2" "ZAUInteger.D, {Z UInteger .D- Z UInteger .D}, {Z UInteger .D- Z UInteger .D}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
)

(autda
  ("AUTDA_64P_dp_1src" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__7"))
)

(cpym
  ("CPYM_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(blrab
  ("BLRAB_64P_branch_reg" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rm" (reg-range 0 31))) ("XnOrXZR" "XmSP_option"))
)

(aesd
  ("aesd_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm"))
  ("aesd_mz_zzi_2x1" "{Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}, ZUInteger.Q[UInteger" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm"))
  ("aesd_mz_zzi_4x1" "{Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}, ZUInteger.Q[UInteger" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm"))
  ("AESD_B_cryptoaes" "VUInteger.16B, VUInteger.16B" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6"))
)

(ldsmaxa
  ("LDSMAXA_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDSMAXA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(cash
  ("CASH_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
)

(ld2b
  ("ld2b_z_p_br_contiguous" "{Z UInteger .B Z UInteger .B}, PUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3" "Xm__4"))
  ("ld2b_z_p_bi_contiguous" "{Z UInteger .B Z UInteger .B}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3"))
)

(rcwclrpl
  ("RCWCLRPL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(shll
  ("SHLL_asimdmisc_S" "VUInteger.8H, VUInteger.8B, 8" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "shift_option__4"))
)

(fdot
  ("fdot_z_zzzi_" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__35"))
  ("fdot_z_zz8z8i_" "ZUInteger.H, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__53"))
  ("fdot_z32_zz8z8i_" "ZUInteger.S, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__40"))
  ("fdot_z_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("fdot_z_zz8z8_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("fdot_z32_zz8z8_" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("fdot_za32_z8z8i_2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("fdot_za_zzi_2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("fdot_za_z8z8i_2xi" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("fdot_za_z8z8i_4xi" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
  ("fdot_za32_z8z8i_4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
  ("fdot_za_zzi_4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
  ("fdot_za_zzv_2x1" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
  ("fdot_za_z8z8v_2x1" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
  ("fdot_za32_z8z8v_2x1" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
  ("fdot_za_zzv_4x1" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
  ("fdot_za_z8z8v_4x1" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
  ("fdot_za32_z8z8v_4x1" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
  ("fdot_za_zzw_2x2" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("fdot_za_z8z8w_2x2" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("fdot_za32_z8z8w_2x2" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("fdot_za_zzw_4x4" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("fdot_za_z8z8w_4x4" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("fdot_za32_z8z8w_4x4" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("FDOT_asimdsame2_DD" "VUInteger.2S, VUInteger.8B, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FDOT_asimdsame2_D" "VUInteger.4H, VUInteger.8B, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FDOT_asimdsame2_FP16FP32" "VUInteger.2S, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FDOT_asimdelem_D" "VUInteger.2S, VUInteger.8B, VUInteger.4B[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "H_L"))
  ("FDOT_asimdelem_G" "VUInteger.4H, VUInteger.8B, VUInteger.2B[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__2" "H_L_M"))
  ("FDOT_asimdelem_FP16FP32" "VUInteger.2S, VUInteger.4H, VUInteger.2H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "H_L__2"))
)

(fmopa
  ("fmopa_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
  ("fmopa_za32_pp_zz_16" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
  ("fmopa_za32_pp_z8z8_8" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
  ("fmopa_za16_pp_z8z8_8" "ZAUInteger.H, PUInteger/M, PUInteger/M, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__3" "Pn" "Pm" "Zn__2" "Zm"))
  ("fmopa_za_pp_zz_16" "ZAUInteger.H, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__3" "Pn" "Pm" "Zn__2" "Zm"))
  ("fmopa_za_pp_zz_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn__2" "Zm"))
)

(cpyewtwn
  ("CPYEWTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(flogb
  ("flogb_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("flogb_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
)

(autia1716
  ("AUTIA1716_HI_hints" "" () ())
)

(famin
  ("famin_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("famin_mz_zzw_2x2" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
  ("famin_mz_zzw_4x4" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
  ("FAMIN_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FAMIN_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(dcps1
  ("DCPS1_DC_exception" "" (("imm16" (imm-range 0 65535 1))) ())
)

(bfmaxnm
  ("bfmaxnm_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("bfmaxnm_mz_zzv_2x1" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
  ("bfmaxnm_mz_zzv_4x1" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
  ("bfmaxnm_mz_zzw_2x2" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, {Z UInteger . H- Z UInteger . H}" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
  ("bfmaxnm_mz_zzw_4x4" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, {Z UInteger . H- Z UInteger . H}" (("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
)

(cbne
  ("CBNE_32_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
  ("CBNE_64_regs" "XZR, XZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "XmOrXZR__4" "imm9_offset"))
  ("CBNE_32_imm" "WZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "imm_cbr" "imm9_offset"))
  ("CBNE_64_imm" "XZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "imm_cbr" "imm9_offset"))
)

(rcwsswppal
  ("RCWSSWPPAL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(dup
  ("dup_z_zi_" "ZUInteger.Q, ZUInteger.Q[UInteger]" (("imm2" (imm-range 0 3 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn" "imm__47"))
  ("dup_z_r_" "ZUInteger.B, WSP" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd"))
  ("dup_z_i_" "ZUInteger.B, SInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zd" (reg-range 0 31))) ("Zd" "imm__46"))
  ("DUP_asisdone_only" "BUInteger, VUInteger.B[UInteger]" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__3" "Vn" "imm5_index__7"))
  ("DUP_asimdins_DV_v" "VUInteger.8B, VUInteger.B[UInteger]" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "imm5_index"))
  ("DUP_asimdins_DR_r" "VUInteger.8B, WZR" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd"))
)

(stbfadd
  ("STBFADD_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
)

(hlt
  ("HLT_EX_exception" "UInteger" (("imm16" (imm-range 0 65535 1))) ("imm"))
)

(ldumina
  ("LDUMINA_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDUMINA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(ldr
  ("ldr_p_bi_" "PUInteger, [SP]" (("imm9h" (imm-range 0 63 1)) ("imm9l" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Pt" (reg-range 0 15))) ("Pt" "XnSP__3"))
  ("ldr_z_bi_" "ZUInteger, [SP]" (("imm9h" (imm-range 0 63 1)) ("imm9l" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "XnSP__3"))
  ("ldr_za_ri_" "ZA[WUInteger, UInteger, [SP]" (("Rn" (reg-range 0 31)) ("off4" (imm-range 0 15 1))) ("Wv__2" "offs__7" "XnSP__3"))
  ("ldr_zt_br_" "ZT0, [SP]" (("Rn" (reg-range 0 31))) ("XnSP__3"))
  ("LDR_32_loadlit" "WZR, SInteger" (("imm19" (imm-range 0 524287 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR__2" "imm19_offset__2"))
  ("LDR_S_loadlit" "SUInteger, SInteger" (("imm19" (imm-range 0 524287 1)) ("Rt" (reg-range 0 31))) ("imm19_offset__2"))
  ("LDR_64_loadlit" "XZR, SInteger" (("imm19" (imm-range 0 524287 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR__8" "imm19_offset__2"))
  ("LDR_D_loadlit" "DUInteger, SInteger" (("imm19" (imm-range 0 524287 1)) ("Rt" (reg-range 0 31))) ("imm19_offset__2"))
  ("LDR_Q_loadlit" "QUInteger, SInteger" (("imm19" (imm-range 0 524287 1)) ("Rt" (reg-range 0 31))) ("Qt__2" "imm19_offset__2"))
  ("LDR_B_ldst_immpost" "BUInteger, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option"))
  ("LDR_Q_ldst_immpost" "QUInteger, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option"))
  ("LDR_H_ldst_immpost" "HUInteger, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option"))
  ("LDR_32_ldst_immpost" "WZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("LDR_S_ldst_immpost" "SUInteger, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option"))
  ("LDR_64_ldst_immpost" "XZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
  ("LDR_D_ldst_immpost" "DUInteger, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option"))
  ("LDR_B_ldst_immpre" "BUInteger, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option"))
  ("LDR_Q_ldst_immpre" "QUInteger, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option"))
  ("LDR_H_ldst_immpre" "HUInteger, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option"))
  ("LDR_32_ldst_immpre" "WZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("LDR_S_ldst_immpre" "SUInteger, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option"))
  ("LDR_64_ldst_immpre" "XZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
  ("LDR_D_ldst_immpre" "DUInteger, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option"))
  ("LDR_B_ldst_regoff" "BUInteger, [SP WZR UXTW]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option" "WorX_choice" "S_option"))
  ("LDR_BL_ldst_regoff" "BUInteger, [SP XZR]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option" "XmOrXZR__2"))
  ("LDR_Q_ldst_regoff" "QUInteger, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option" "WorX_choice"))
  ("LDR_H_ldst_regoff" "HUInteger, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option" "WorX_choice"))
  ("LDR_32_ldst_regoff" "WZR, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "WorX_choice"))
  ("LDR_S_ldst_regoff" "SUInteger, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option" "WorX_choice"))
  ("LDR_64_ldst_regoff" "XZR, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "WorX_choice"))
  ("LDR_D_ldst_regoff" "DUInteger, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option" "WorX_choice"))
  ("LDR_B_ldst_pos" "BUInteger, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option" "imm12_option"))
  ("LDR_Q_ldst_pos" "QUInteger, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option" "imm12_option__3"))
  ("LDR_H_ldst_pos" "HUInteger, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option" "imm12_option__4"))
  ("LDR_32_ldst_pos" "WZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm12_option__6"))
  ("LDR_S_ldst_pos" "SUInteger, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option" "imm12_option__6"))
  ("LDR_64_ldst_pos" "XZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm12_option__8"))
  ("LDR_D_ldst_pos" "DUInteger, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option" "imm12_option__8"))
)

(cpyfp
  ("CPYFP_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(movi
  ("MOVI_asimdimm_L_sl" "VUInteger.2S, UInteger" (("Rd" (reg-range 0 31))) ("Vd"))
  ("MOVI_asimdimm_L_hl" "VUInteger.4H, UInteger" (("Rd" (reg-range 0 31))) ("Vd"))
  ("MOVI_asimdimm_M_sm" "VUInteger.2S, UInteger, MSL, 8" (("Rd" (reg-range 0 31))) ("Vd"))
  ("MOVI_asimdimm_N_b" "VUInteger.8B, UInteger, LSL, 0" (("Rd" (reg-range 0 31))) ("Vd"))
  ("MOVI_asimdimm_D_ds" "DUInteger, UInteger" (("Rd" (reg-range 0 31))) ("Dd"))
  ("MOVI_asimdimm_D2_d" "VUInteger.2D, UInteger" (("Rd" (reg-range 0 31))) ("Vd"))
)

(adcs
  ("ADCS_32_addsub_carry" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("ADCS_64_addsub_carry" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
)

(match
  ("match_p_p_zz_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
)

(whilegt
  ("whilegt_pn_rr_" "PNUInteger.B, XUInteger, XUInteger, VLx2" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("PNd" (reg-range 0 7))) ("PNd" "Xn__4" "Xm__6"))
  ("whilegt_pp_rr_" "{P UInteger . B P UInteger . B}, XUInteger, XUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 7))) ("Pd1__2" "Pd2__2" "Xn__4" "Xm__6"))
  ("whilegt_p_p_rr_" "PUInteger.B, WZR, WZR" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd"))
)

(fvdott
  ("fvdott_za32_z8z8i_2xi" "ZA.S[WUInteger, UInteger, VGx4], {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
)

(cpyfetwn
  ("CPYFETWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(tblq
  ("tblq_z_zz_" "ZUInteger.B, {Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(ld2d
  ("ld2d_z_p_br_contiguous" "{Z UInteger .D Z UInteger .D}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3" "Xm__4"))
  ("ld2d_z_p_bi_contiguous" "{Z UInteger .D Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3"))
)

(stmopa
  ("stmopa_za_zzzi_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
  ("stmopa_za32_zzzi_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
)

(rbit
  ("rbit_z_p_z_m" "ZUInteger.B, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("rbit_z_p_z_z" "ZUInteger.B, PUInteger/Z, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("RBIT_32_dp_1src" "WZR, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
  ("RBIT_64_dp_1src" "XZR, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
  ("RBIT_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(frintn
  ("frintn_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("frintn_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("frintn_mz_z_2" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__4" "Zn2__3"))
  ("frintn_mz_z_4" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
  ("FRINTN_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FRINTN_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FRINTN_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
  ("FRINTN_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
  ("FRINTN_H_floatdp1" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
)

(ldsetpal
  ("LDSETPAL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(ld1sh
  ("ld1sh_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1sh_z_p_bz_s_x32_scaled" "{Z UInteger .S}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1sh_z_p_ai_s" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ld1sh_z_p_br_s64" "{Z UInteger .D}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1sh_z_p_br_s32" "{Z UInteger .S}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1sh_z_p_bi_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1sh_z_p_bi_s32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1sh_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1sh_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1sh_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ld1sh_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1sh_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
)

(sqxtnt
  ("sqxtnt_z_zz_" "ZUInteger.B, ZUInteger.H" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(sttnp
  ("STTNP_64_ldstnapair_offs" "XZR, XZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm7_option__2"))
  ("STTNP_Q_ldstnapair_offs" "QUInteger, QUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm7_option__3"))
)

(fcvtlt
  ("fcvtlt_z_p_z_h2sz" "ZUInteger.S, PUInteger/Z, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtlt_z_p_z_s2dz" "ZUInteger.D, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtlt_z_p_z_h2s" "ZUInteger.S, PUInteger/M, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtlt_z_p_z_s2d" "ZUInteger.D, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
)

(fccmpe
  ("FCCMPE_S_floatccmp" "SUInteger, SUInteger, UInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Sn__3" "Sm"))
  ("FCCMPE_D_floatccmp" "DUInteger, DUInteger, UInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Dn__2" "Dm"))
  ("FCCMPE_H_floatccmp" "HUInteger, HUInteger, UInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Hn" "Hm"))
)

(caspal
  ("CASPAL_CP32_comswappr" "WUInteger, WUInteger, WUInteger, WUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ws" "WsPlus1" "Wt" "WtPlus1" "XnSP_option"))
  ("CASPAL_CP64_comswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
)

(bftmopa
  ("bftmopa_za32_zzzi_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
  ("bftmopa_za_zzzi_h2x1" "ZAUInteger.H, {Z UInteger .H- Z UInteger .H}, ZUInteger.H, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda__3" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
)

(cpyfprtrn
  ("CPYFPRTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(raddhnt
  ("raddhnt_z_zz_" "ZUInteger.B, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(st2b
  ("st2b_z_p_br_contiguous" "{Z UInteger .B Z UInteger .B}, PUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3" "Xm__4"))
  ("st2b_z_p_bi_contiguous" "{Z UInteger .B Z UInteger .B}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3"))
)

(eors
  ("eors_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
)

(brkpa
  ("brkpa_p_p_pp_" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
)

(bext
  ("bext_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(stbfminnm
  ("STBFMINNM_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
)

(fmmla
  ("fmmla_z32_zz8z8_" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("fmmla_z16_zz8z8_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("fmmla_z_zzz_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("fmmla_z32_zzz_h" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("fmmla_z_zzz_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("fmmla_z_zzz_d" "ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("FMMLA_asimd_FP16FP16" "VUInteger.8H, VUInteger.8H, VUInteger.8H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "Vm"))
  ("FMMLA_asimd_FP8FP16" "VUInteger.8H, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "Vm"))
  ("FMMLA_asimd_FP16FP32" "VUInteger.4S, VUInteger.8H, VUInteger.8H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "Vm"))
  ("FMMLA_asimd_FP8FP32" "VUInteger.4S, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "Vm"))
)

(subr
  ("subr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("subr_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__27"))
)

(ldapp
  ("LDAPP_64_ldiappstilp" "XZR, XZR, [SP 0]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(strh
  ("STRH_32_ldst_immpost" "WZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("STRH_32_ldst_immpre" "WZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("STRH_32_ldst_regoff" "WZR, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "WorX_choice"))
  ("STRH_32_ldst_pos" "WZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm12_option__4"))
)

(ldfmaxl
  ("LDFMAXL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMAXL_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMAXL_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(ldtclral
  ("LDTCLRAL_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDTCLRAL_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(sunpk
  ("sunpk_mz_z_2" "{Z UInteger . H - Z UInteger . H}, ZUInteger.B" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
  ("sunpk_mz_z_4" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__4" "Zn2__3"))
)

(fmsub
  ("FMSUB_S_floatdp3" "SUInteger, SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__6" "Sm__2" "Sa__2"))
  ("FMSUB_D_floatdp3" "DUInteger, DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__5" "Dm__2" "Da__2"))
  ("FMSUB_H_floatdp3" "HUInteger, HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__5" "Hm__2" "Ha__2"))
)

(paciza
  ("PACIZA_64Z_dp_1src" "XZR" (("Rd" (reg-range 0 31))) ("XdOrXZR__6"))
)

(fmin
  ("fmin_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("fmin_z_p_zs_" "ZUInteger.H, PUInteger/M, ZUInteger.H, 0.0" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
  ("fmin_mz_zzv_2x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
  ("fmin_mz_zzv_4x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
  ("fmin_mz_zzw_2x2" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
  ("fmin_mz_zzw_4x4" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
  ("FMIN_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMIN_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMIN_S_floatdp2" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__3" "Sm"))
  ("FMIN_D_floatdp2" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__2" "Dm"))
  ("FMIN_H_floatdp2" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
)

(cpyfprtn
  ("CPYFPRTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(ldaddalb
  ("LDADDALB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(ldapr
  ("LDAPR_32L_ldapstl_writeback" "WZR, [SP], 4" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__2" "XnSP_option"))
  ("LDAPR_64L_ldapstl_writeback" "XZR, [SP], 8" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__8" "XnSP_option"))
  ("LDAPR_32L_memop" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__2" "XnSP_option"))
  ("LDAPR_64L_memop" "XZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__8" "XnSP_option"))
)

(sqrshlr
  ("sqrshlr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
)

(st2d
  ("st2d_z_p_br_contiguous" "{Z UInteger .D Z UInteger .D}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3" "Xm__4"))
  ("st2d_z_p_bi_contiguous" "{Z UInteger .D Z UInteger .D}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3"))
)

(shsub
  ("shsub_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("SHSUB_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(ld2h
  ("ld2h_z_p_br_contiguous" "{Z UInteger .H Z UInteger .H}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3" "Xm__4"))
  ("ld2h_z_p_bi_contiguous" "{Z UInteger .H Z UInteger .H}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3"))
)

(frintp
  ("frintp_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("frintp_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("frintp_mz_z_2" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__4" "Zn2__3"))
  ("frintp_mz_z_4" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
  ("FRINTP_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FRINTP_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FRINTP_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
  ("FRINTP_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
  ("FRINTP_H_floatdp1" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
)

(pacia171615
  ("PACIA171615_64LR_dp_1src" "" () ())
)

(setgpt
  ("SETGPT_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__4" "XnOrXZR__8" "XsOrXZR__8"))
)

(ld1r
  ("LD1R_asisdlso_R1" "{V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
  ("LD1R_asisdlsop_RX1_r" "{V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "Xm__2"))
  ("LD1R_asisdlsop_R1_i" "{V UInteger . 8B}, [SP], 1" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "imm_option__8"))
)

(ldbfmaxa
  ("LDBFMAXA_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(ldrsh
  ("LDRSH_64_ldst_immpost" "XZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
  ("LDRSH_32_ldst_immpost" "WZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("LDRSH_64_ldst_immpre" "XZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
  ("LDRSH_32_ldst_immpre" "WZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("LDRSH_64_ldst_regoff" "XZR, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "WorX_choice"))
  ("LDRSH_32_ldst_regoff" "WZR, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "WorX_choice"))
  ("LDRSH_64_ldst_pos" "XZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm12_option__4"))
  ("LDRSH_32_ldst_pos" "WZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm12_option__4"))
)

(sha256h
  ("SHA256H_QQV_cryptosha3" "QUInteger, QUInteger, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Qd" "Qn" "Vm__7"))
)

(f2cvtl
  ("f2cvtl_mz2_z8_" "{Z UInteger .H- Z UInteger .H}, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
  ("F2CVTL_asimdmisc_V" "VUInteger.8H, VUInteger.8B" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(ld3
  ("LD3_asisdlse_R3" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
  ("LD3_asisdlsep_R3_r" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
  ("LD3_asisdlsep_I3_i" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], 24" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "imm_option__3"))
  ("LD3_asisdlso_B3_3b" "{V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
  ("LD3_asisdlso_H3_3h" "{V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
  ("LD3_asisdlso_S3_3s" "{V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
  ("LD3_asisdlso_D3_3d" "{V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
  ("LD3_asisdlsop_BX3_r3b" "{V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
  ("LD3_asisdlsop_HX3_r3h" "{V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
  ("LD3_asisdlsop_SX3_r3s" "{V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
  ("LD3_asisdlsop_DX3_r3d" "{V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
  ("LD3_asisdlsop_B3_i3b" "{V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP], 3" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
  ("LD3_asisdlsop_H3_i3h" "{V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP], 6" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
  ("LD3_asisdlsop_S3_i3s" "{V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP], 12" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
  ("LD3_asisdlsop_D3_i3d" "{V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP], 24" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
)

(sttrh
  ("STTRH_32_ldst_unpriv" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
)

(tsb
  ("TSB_HC_hints" "CSYNC" () ())
)

(sysl
  ("SYSL_RC_systeminstrs" "XZR, UInteger, CUInteger, CUInteger, UInteger" (("Rt" (reg-range 0 31))) ("XtOrXZR__4"))
)

(stbfmaxnm
  ("STBFMAXNM_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
)

(cpymrtrn
  ("CPYMRTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(sttrb
  ("STTRB_32_ldst_unpriv" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
)

(setge
  ("SETGE_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__10" "XsOrXZR__7"))
)

(ldtclrl
  ("LDTCLRL_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDTCLRL_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(stcph
  ("STCPH_HI_hints" "" () ())
)

(ldclrab
  ("LDCLRAB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(dcps3
  ("DCPS3_DC_exception" "" (("imm16" (imm-range 0 65535 1))) ())
)

(rcwcaspl
  ("RCWCASPL_C64_rcwcomswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
)

(bfcvtnt
  ("bfcvtnt_z_p_z_s2bfz" "ZUInteger.H, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("bfcvtnt_z_p_z_s2bf" "ZUInteger.H, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
)

(ld1
  ("LD1_asisdlse_R4_4v" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
  ("LD1_asisdlse_R3_3v" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
  ("LD1_asisdlse_R1_1v" "{V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
  ("LD1_asisdlse_R2_2v" "{V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
  ("LD1_asisdlsep_R4_r4" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
  ("LD1_asisdlsep_R3_r3" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
  ("LD1_asisdlsep_R1_r1" "{V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "Xm__2"))
  ("LD1_asisdlsep_R2_r2" "{V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
  ("LD1_asisdlsep_I4_i4" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], 32" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "imm_option"))
  ("LD1_asisdlsep_I3_i3" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], 24" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "imm_option__3"))
  ("LD1_asisdlsep_I1_i1" "{V UInteger . 8B}, [SP], 8" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "imm_option__5"))
  ("LD1_asisdlsep_I2_i2" "{V UInteger . 8B V UInteger . 8B}, [SP], 16" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "imm_option__6"))
  ("LD1_asisdlso_B1_1b" "{V UInteger . B}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
  ("LD1_asisdlso_H1_1h" "{V UInteger . H}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
  ("LD1_asisdlso_S1_1s" "{V UInteger . S}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
  ("LD1_asisdlso_D1_1d" "{V UInteger . D}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
  ("LD1_asisdlsop_BX1_r1b" "{V UInteger . B}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "Xm__2"))
  ("LD1_asisdlsop_HX1_r1h" "{V UInteger . H}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "Xm__2"))
  ("LD1_asisdlsop_SX1_r1s" "{V UInteger . S}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "Xm__2"))
  ("LD1_asisdlsop_DX1_r1d" "{V UInteger . D}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "Xm__2"))
  ("LD1_asisdlsop_B1_i1b" "{V UInteger . B}, [UInteger], [SP], 1" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
  ("LD1_asisdlsop_H1_i1h" "{V UInteger . H}, [UInteger], [SP], 2" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
  ("LD1_asisdlsop_S1_i1s" "{V UInteger . S}, [UInteger], [SP], 4" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
  ("LD1_asisdlsop_D1_i1d" "{V UInteger . D}, [UInteger], [SP], 8" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
)

(fnmadd
  ("FNMADD_S_floatdp3" "SUInteger, SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__6" "Sm__2" "Sa"))
  ("FNMADD_D_floatdp3" "DUInteger, DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__5" "Dm__2" "Da"))
  ("FNMADD_H_floatdp3" "HUInteger, HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__5" "Hm__2" "Ha"))
)

(ldbfmax
  ("LDBFMAX_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(st64bv
  ("ST64BV_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__3" "XtOrXZR__9" "XnSP_option"))
)

(fadd
  ("fadd_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("fadd_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("fadd_z_p_zs_" "ZUInteger.H, PUInteger/M, ZUInteger.H, 0.5" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
  ("fadd_za_zw_2x2" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1" "Zm2"))
  ("fadd_za_zw_2x2_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1" "Zm2"))
  ("fadd_za_zw_4x4" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1__2" "Zm4"))
  ("fadd_za_zw_4x4_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1__2" "Zm4"))
  ("FADD_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FADD_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FADD_S_floatdp2" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__3" "Sm"))
  ("FADD_D_floatdp2" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__2" "Dm"))
  ("FADD_H_floatdp2" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
)

(setgetn
  ("SETGETN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__10" "XsOrXZR__7"))
)

(splice
  ("splice_z_p_zz_des" "ZUInteger.B, PUInteger, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pv__2" "Zdn" "Zm"))
  ("splice_z_p_zz_con" "ZUInteger.B, PUInteger, {Z UInteger . B Z UInteger . B}" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pv__2" "Zn1__5" "Zn2__4"))
)

(ptrues
  ("ptrues_p_s_" "PUInteger.B" (("size" (element-size B H S D)) ("Pd" (reg-range 0 15))) ("Pd"))
)

(shrnt
  ("shrnt_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(cpyfmrn
  ("CPYFMRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(sha512su0
  ("SHA512SU0_VV2_cryptosha512_2" "VUInteger.2D, VUInteger.2D" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6"))
)

(rcwswp
  ("RCWSWP_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(asrr
  ("asrr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
)

(ldap1
  ("LDAP1_asisdlso_D1" "{V UInteger . D}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
)

(caslb
  ("CASLB_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
)

(sqabs
  ("sqabs_z_p_z_m" "ZUInteger.B, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("sqabs_z_p_z_z" "ZUInteger.B, PUInteger/Z, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("SQABS_asisdmisc_R" "BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7"))
  ("SQABS_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(ldumaxb
  ("LDUMAXB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(brka
  ("brka_p_p_p_" "PUInteger.B, PUInteger/Z, PUInteger.B" (("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "ZM" "Pn__3"))
)

(saddlv
  ("SADDLV_asimdall_only" "HUInteger, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option" "Vn"))
)

(sabdlb
  ("sabdlb_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(shl
  ("SHL_asisdshf_R" "DUInteger, DUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("SHL_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__5"))
)

(setgomt
  ("SETGOMT_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__9"))
)

(ldursh
  ("LDURSH_64_ldst_unscaled" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
  ("LDURSH_32_ldst_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
)

(asrv
  ("ASRV_32_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__4"))
  ("ASRV_64_dp_2src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__7"))
)

(bfminnm
  ("bfminnm_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("bfminnm_mz_zzv_2x1" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
  ("bfminnm_mz_zzv_4x1" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
  ("bfminnm_mz_zzw_2x2" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, {Z UInteger . H- Z UInteger . H}" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
  ("bfminnm_mz_zzw_4x4" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, {Z UInteger . H- Z UInteger . H}" (("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
)

(sminqv
  ("sminqv_z_p_z_" "VUInteger.16B, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
)

(fcvtas
  ("FCVTAS_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
  ("FCVTAS_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("FCVTAS_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCVTAS_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCVTAS_32S_float2int" "WZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
  ("FCVTAS_32D_float2int" "WZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
  ("FCVTAS_32H_float2int" "WZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
  ("FCVTAS_64S_float2int" "XZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
  ("FCVTAS_64D_float2int" "XZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
  ("FCVTAS_64H_float2int" "XZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
  ("FCVTAS_sisd_32D" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
  ("FCVTAS_sisd_32H" "SUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Hn__2"))
  ("FCVTAS_sisd_64H" "DUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Hn__2"))
  ("FCVTAS_sisd_64S" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
)

(bfvdot
  ("bfvdot_za_zzi_2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
)

(suvdot
  ("suvdot_za_zzi_s4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
)

(cpyfptwn
  ("CPYFPTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(ext
  ("ext_z_zi_des" "ZUInteger.B, ZUInteger.B, ZUInteger.B, UInteger" (("imm8h" (imm-range 0 31 1)) ("imm8l" (imm-range 0 7 1)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm" "imm__49"))
  ("ext_z_zi_con" "ZUInteger.B, {Z UInteger .B Z UInteger .B}, UInteger" (("imm8h" (imm-range 0 31 1)) ("imm8l" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__5" "Zn2__4" "imm__49"))
  ("EXT_asimdext_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B, UInteger" (("Rm" (reg-range 0 31)) ("imm4" (imm-range 0 15 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm" "imm420"))
)

(setgpn
  ("SETGPN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__4" "XnOrXZR__8" "XsOrXZR__8"))
)

(uqxtnt
  ("uqxtnt_z_zz_" "ZUInteger.B, ZUInteger.H" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(tbl
  ("tbl_z_zz_2" "ZUInteger.B, {Z UInteger . B Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__8" "Zn2__6" "Zm"))
  ("tbl_z_zz_1" "ZUInteger.B, {Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("TBL_asimdtbl_L1_1" "VUInteger.8B, {V UInteger . 16B}, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__3" "Vm__3"))
  ("TBL_asimdtbl_L2_2" "VUInteger.8B, {V UInteger . 16B V UInteger . 16B}, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__4" "VnPlus1" "Vm__3"))
  ("TBL_asimdtbl_L3_3" "VUInteger.8B, {V UInteger . 16B V UInteger . 16B V UInteger . 16B}, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__4" "VnPlus1" "VnPlus2" "Vm__3"))
  ("TBL_asimdtbl_L4_4" "VUInteger.8B, {V UInteger . 16B V UInteger . 16B V UInteger . 16B V UInteger . 16B}, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__4" "VnPlus1" "VnPlus2" "VnPlus3" "Vm__3"))
)

(casp
  ("CASP_CP32_comswappr" "WUInteger, WUInteger, WUInteger, WUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ws" "WsPlus1" "Wt" "WtPlus1" "XnSP_option"))
  ("CASP_CP64_comswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
)

(msr
  ("MSR_SI_pstate" "UAO, UInteger" () ())
  ("MSR_SR_systemmove" "ACTLR_EL3, XZR" (("Rt" (reg-range 0 31))) ("XtOrXZR__3"))
)

(rcwssetp
  ("RCWSSETP_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(rcwsclrpal
  ("RCWSCLRPAL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(smaxqv
  ("smaxqv_z_p_z_" "VUInteger.16B, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
)

(punpkhi
  ("punpkhi_p_p_" "PUInteger.H, PUInteger.B" (("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pn__3"))
)

(retab
  ("RETAB_64E_branch_reg" "" () ())
)

(rcwsetp
  ("RCWSETP_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(ldurb
  ("LDURB_32_ldst_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
)

(fcvtau
  ("FCVTAU_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
  ("FCVTAU_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("FCVTAU_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCVTAU_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCVTAU_32S_float2int" "WZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
  ("FCVTAU_32D_float2int" "WZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
  ("FCVTAU_32H_float2int" "WZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
  ("FCVTAU_64S_float2int" "XZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
  ("FCVTAU_64D_float2int" "XZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
  ("FCVTAU_64H_float2int" "XZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
  ("FCVTAU_sisd_32D" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
  ("FCVTAU_sisd_32H" "SUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Hn__2"))
  ("FCVTAU_sisd_64H" "DUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Hn__2"))
  ("FCVTAU_sisd_64S" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
)

(cpyfewt
  ("CPYFEWT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(setgomn
  ("SETGOMN_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__9"))
)

(stlur
  ("STLUR_32_ldapstl_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
  ("STLUR_64_ldapstl_unscaled" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
  ("STLUR_B_ldapstl_simd" "BUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option" "imm9_option"))
  ("STLUR_Q_ldapstl_simd" "QUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option" "imm9_option"))
  ("STLUR_H_ldapstl_simd" "HUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option" "imm9_option"))
  ("STLUR_S_ldapstl_simd" "SUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option" "imm9_option"))
  ("STLUR_D_ldapstl_simd" "DUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option" "imm9_option"))
)

(paciasppc
  ("PACIASPPC_64LR_dp_1src" "" () ())
)

(uqdecw
  ("uqdecw_z_zs_" "ZUInteger.S" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
  ("uqdecw_r_rs_uw" "WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Wdn"))
  ("uqdecw_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(crc32ch
  ("CRC32CH_32C_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR__2" "WnOrWZR__4" "WmOrWZR__5"))
)

(rcwset
  ("RCWSET_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(faddqv
  ("faddqv_z_p_z_" "VUInteger.8H, PUInteger, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
)

(rmif
  ("RMIF_only_rmif" "XZR, UInteger, UInteger" (("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31))) ("XnOrXZR__11" "shift__9"))
)

(adrp
  ("ADRP_only_pcreladdr" "XZR, SInteger" (("immlo" (imm-range 0 3 1)) ("immhi" (imm-range 0 524287 1)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "immhiimmlo_offset__2"))
)

(sqdmullb
  ("sqdmullb_z_zzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__78"))
  ("sqdmullb_z_zzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__2" "imm__88"))
  ("sqdmullb_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(cpyfertrn
  ("CPYFERTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(ldff1d
  ("ldff1d_z_p_br_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldff1d_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1d_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1d_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ldff1d_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1d_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
)

(umaddl
  ("UMADDL_64WA_dp_3src" "XZR, WZR, WZR, XZR" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "WnOrWZR__5" "WmOrWZR__6" "XaOrXZR"))
)

(sdivr
  ("sdivr_z_p_zz_" "ZUInteger.S, PUInteger/M, ZUInteger.S, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
)

(pfirst
  ("pfirst_p_p_p_" "PUInteger.B, PUInteger, PUInteger.B" (("Pg" (reg-range 0 15))) ("Pdn" "Pg__2" "Pdn"))
)

(ld1sb
  ("ld1sb_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1sb_z_p_ai_s" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ld1sb_z_p_br_s64" "{Z UInteger .D}, PUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1sb_z_p_br_s32" "{Z UInteger .S}, PUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1sb_z_p_br_s16" "{Z UInteger .H}, PUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1sb_z_p_bi_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1sb_z_p_bi_s32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1sb_z_p_bi_s16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1sb_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1sb_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ld1sb_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
)

(isb
  ("ISB_BI_barriers" "" () ())
)

(setgm
  ("SETGM_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__9" "XsOrXZR__8"))
)

(uxtw
  ("uxtw_z_p_z_m" "ZUInteger.D, PUInteger/M, ZUInteger.D" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("uxtw_z_p_z_z" "ZUInteger.D, PUInteger/Z, ZUInteger.D" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
)

(stbfmin
  ("STBFMIN_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
)

(csel
  ("CSEL_32_condsel" "WZR, WZR, WZR, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("CSEL_64_condsel" "XZR, XZR, XZR, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
)

(frintx
  ("frintx_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("frintx_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("FRINTX_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FRINTX_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FRINTX_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
  ("FRINTX_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
  ("FRINTX_H_floatdp1" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
)

(sclamp
  ("sclamp_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("sclamp_mz_zz_2" "{Z UInteger . B - Z UInteger . B}, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn__2" "Zm"))
  ("sclamp_mz_zz_4" "{Z UInteger . B - Z UInteger . B}, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn__2" "Zm"))
)

(srsra
  ("srsra_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2"))
  ("SRSRA_asisdshf_R" "DUInteger, DUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("SRSRA_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__4"))
)

(fmop4a
  ("fmop4a_za_zz_s1x1" "ZAUInteger.S, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
  ("fmop4a_za_zz_s1x2" "ZAUInteger.S, ZUInteger.S, {Z UInteger .S- Z UInteger .S}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("fmop4a_za_zz_s2x1" "ZAUInteger.S, {Z UInteger .S- Z UInteger .S}, ZUInteger.S" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("fmop4a_za_zz_s2x2" "ZAUInteger.S, {Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("fmop4a_za32_z8z8_b1x1" "ZAUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
  ("fmop4a_za32_z8z8_b1x2" "ZAUInteger.S, ZUInteger.B, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("fmop4a_za32_z8z8_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("fmop4a_za32_z8z8_b2x2" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("fmop4a_za32_zz_h1x1" "ZAUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
  ("fmop4a_za32_zz_h1x2" "ZAUInteger.S, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("fmop4a_za32_zz_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("fmop4a_za32_zz_h2x2" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("fmop4a_za16_z8z8_b1x1" "ZAUInteger.H, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn_mortlach" "Zm_mortlach"))
  ("fmop4a_za16_z8z8_b1x2" "ZAUInteger.H, ZUInteger.B, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("fmop4a_za16_z8z8_b2x1" "ZAUInteger.H, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("fmop4a_za16_z8z8_b2x2" "ZAUInteger.H, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("fmop4a_za_zz_h1x1" "ZAUInteger.H, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn_mortlach" "Zm_mortlach"))
  ("fmop4a_za_zz_h1x2" "ZAUInteger.H, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("fmop4a_za_zz_h2x1" "ZAUInteger.H, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("fmop4a_za_zz_h2x2" "ZAUInteger.H, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("fmop4a_za_zz_d1x1" "ZAUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm_mortlach"))
  ("fmop4a_za_zz_d1x2" "ZAUInteger.D, ZUInteger.D, {Z UInteger .D- Z UInteger .D}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("fmop4a_za_zz_d2x1" "ZAUInteger.D, {Z UInteger .D- Z UInteger .D}, ZUInteger.D" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("fmop4a_za_zz_d2x2" "ZAUInteger.D, {Z UInteger .D- Z UInteger .D}, {Z UInteger .D- Z UInteger .D}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
)

(crc32cb
  ("CRC32CB_32C_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR__2" "WnOrWZR__4" "WmOrWZR__5"))
)

(ldrsb
  ("LDRSB_64_ldst_immpost" "XZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
  ("LDRSB_32_ldst_immpost" "WZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("LDRSB_64_ldst_immpre" "XZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
  ("LDRSB_32_ldst_immpre" "WZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("LDRSB_64B_ldst_regoff" "XZR, [SP WZR UXTW]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "WorX_choice" "S_option"))
  ("LDRSB_64BL_ldst_regoff" "XZR, [SP XZR]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "XmOrXZR__2"))
  ("LDRSB_32B_ldst_regoff" "WZR, [SP WZR UXTW]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "WorX_choice" "S_option"))
  ("LDRSB_32BL_ldst_regoff" "WZR, [SP XZR]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "XmOrXZR__2"))
  ("LDRSB_64_ldst_pos" "XZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm12_option"))
  ("LDRSB_32_ldst_pos" "WZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm12_option"))
)

(sqsubr
  ("sqsubr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
)

(ldtseta
  ("LDTSETA_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDTSETA_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(orqv
  ("orqv_z_p_z_" "VUInteger.16B, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
)

(cpyfewn
  ("CPYFEWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(setgop
  ("SETGOP_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__4" "XnOrXZR__8"))
)

(ldbfmina
  ("LDBFMINA_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(zip2
  ("zip2_z_zz_q" "ZUInteger.Q, ZUInteger.Q, ZUInteger.Q" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("zip2_p_pp_" "PUInteger.B, PUInteger.B, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pn__2" "Pm__2"))
  ("zip2_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("ZIP2_asimdperm_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(sumopa
  ("sumopa_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
  ("sumopa_za_pp_zz_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn__2" "Zm"))
)

(adc
  ("ADC_32_addsub_carry" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("ADC_64_addsub_carry" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
)

(ldfmina
  ("LDFMINA_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMINA_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMINA_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(neg
  ("neg_z_p_z_m" "ZUInteger.B, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("neg_z_p_z_z" "ZUInteger.B, PUInteger/Z, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("NEG_asisdmisc_R" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("NEG_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(ins
  ("INS_asimdins_IR_r" "VUInteger.B[UInteger], WZR" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "imm5_index"))
  ("INS_asimdins_IV_v" "VUInteger.B[UInteger], VUInteger.B[UInteger]" (("imm5" (imm-range 0 31 1)) ("imm4" (imm-range 0 15 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "imm5_index__5" "Vn" "imm5_index__6"))
)

(frintz
  ("frintz_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("frintz_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("FRINTZ_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FRINTZ_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FRINTZ_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
  ("FRINTZ_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
  ("FRINTZ_H_floatdp1" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
)

(cpyfpn
  ("CPYFPN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(ldff1h
  ("ldff1h_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1h_z_p_bz_s_x32_scaled" "{Z UInteger .S}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1h_z_p_ai_s" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ldff1h_z_p_br_u16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldff1h_z_p_br_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldff1h_z_p_br_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldff1h_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1h_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1h_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ldff1h_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1h_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
)

(fmadd
  ("FMADD_S_floatdp3" "SUInteger, SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__6" "Sm__2" "Sa"))
  ("FMADD_D_floatdp3" "DUInteger, DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__5" "Dm__2" "Da"))
  ("FMADD_H_floatdp3" "HUInteger, HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__5" "Hm__2" "Ha"))
)

(autia171615
  ("AUTIA171615_64LR_dp_1src" "" () ())
)

(fmlslb
  ("fmlslb_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
  ("fmlslb_z_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
)

(fcvtx
  ("fcvtx_z_p_z_d2sz" "ZUInteger.S, PUInteger/Z, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtx_z_p_z_d2s" "ZUInteger.S, PUInteger/M, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
)

(ssublbt
  ("ssublbt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(srshr
  ("srshr_z_p_zi_" "ZUInteger.B, PUInteger/M, ZUInteger.B, UInteger" (("Pg" (reg-range 0 7)) ("imm3" (imm-range 0 7 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
  ("SRSHR_asisdshf_R" "DUInteger, DUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("SRSHR_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__4"))
)

(pmul
  ("pmul_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("PMUL_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(ldbfmaxnml
  ("LDBFMAXNML_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(casl
  ("CASL_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
  ("CASL_C64_comswap" "XZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
)

(ldursb
  ("LDURSB_64_ldst_unscaled" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
  ("LDURSB_32_ldst_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
)

(sri
  ("sri_z_zzi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
  ("SRI_asisdshf_R" "DUInteger, DUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("SRI_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__4"))
)

(addha
  ("addha_za_pp_z_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.S" (("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn"))
  ("addha_za_pp_z_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.D" (("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn"))
)

(casat
  ("CASAT_C64_comswap_unpriv" "XZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
)

(uzp2
  ("uzp2_z_zz_q" "ZUInteger.Q, ZUInteger.Q, ZUInteger.Q" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("uzp2_p_pp_" "PUInteger.B, PUInteger.B, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pn__2" "Pm__2"))
  ("uzp2_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("UZP2_asimdperm_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(ldadda
  ("LDADDA_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDADDA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(movk
  ("MOVK_32_movewide" "WZR, UInteger" (("imm16" (imm-range 0 65535 1)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "imm__18"))
  ("MOVK_64_movewide" "XZR, UInteger" (("imm16" (imm-range 0 65535 1)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "imm__18"))
  ("MOVK_32_movewide_shift" "WZR, UInteger, lsl, UInteger" (("imm16" (imm-range 0 65535 1)) ("hw" (imm-range 0 1 1)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "imm" "lsl" "shift"))
  ("MOVK_64_movewide_shift" "XZR, UInteger, lsl, UInteger" (("imm16" (imm-range 0 65535 1)) ("hw" (imm-range 0 3 1)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "imm" "lsl" "shift"))
)

(pacda
  ("PACDA_64P_dp_1src" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__7"))
)

(rcwssetl
  ("RCWSSETL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(swph
  ("SWPH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
)

(sqshrnb
  ("sqshrnb_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(ldiapp
  ("LDIAPP_32LE_ldiappstilp" "WZR, WZR, [SP], 8" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option"))
  ("LDIAPP_32L_ldiappstilp" "WZR, WZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option"))
  ("LDIAPP_64LS_ldiappstilp" "XZR, XZR, [SP], 16" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
  ("LDIAPP_64L_ldiappstilp" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(ldclrlh
  ("LDCLRLH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(rev32
  ("REV32_64_dp_1src" "XZR, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
  ("REV32_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(st4q
  ("st4q_z_p_bi_contiguous" "{Z UInteger .Q Z UInteger .Q Z UInteger .Q Z UInteger .Q}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3"))
  ("st4q_z_p_br_contiguous" "{Z UInteger .Q Z UInteger .Q Z UInteger .Q Z UInteger .Q}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3" "Xm__4"))
)

(ldeoralh
  ("LDEORALH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(stnt1w
  ("stnt1w_z_p_ar_d_64_unscaled" "{Z UInteger .D}, PUInteger, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("stnt1w_z_p_ar_s_x32_unscaled" "{Z UInteger .S}, PUInteger, [Z UInteger .S]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("stnt1w_z_p_br_contiguous" "{Z UInteger .S}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("stnt1w_z_p_bi_contiguous" "{Z UInteger .S}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("stnt1w_mz_p_br_2" "{Z UInteger .S- Z UInteger .S}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
  ("stnt1w_mz_p_br_4" "{Z UInteger .S- Z UInteger .S}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
  ("stnt1w_mz_p_bi_2" "{Z UInteger .S- Z UInteger .S}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
  ("stnt1w_mz_p_bi_4" "{Z UInteger .S- Z UInteger .S}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
  ("stnt1w_mzx_p_br_2x8" "{Z UInteger .S Z UInteger .S}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
  ("stnt1w_mzx_p_br_4x4" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
  ("stnt1w_mzx_p_bi_2x8" "{Z UInteger .S Z UInteger .S}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
  ("stnt1w_mzx_p_bi_4x4" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
)

(ld4d
  ("ld4d_z_p_br_contiguous" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3" "Xm__4"))
  ("ld4d_z_p_bi_contiguous" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3"))
)

(frint64x
  ("frint64x_z_p_z_z" "ZUInteger.S, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("frint64x_z_p_z_m" "ZUInteger.S, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("FRINT64X_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FRINT64X_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
  ("FRINT64X_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
)

(pmull
  ("pmull_mz_zzw_1x2" "{Z UInteger .Q- Z UInteger .Q}, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn__2" "Zm"))
  ("PMULL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(addqp
  ("addqp_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(ldeoral
  ("LDEORAL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDEORAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(tbxq
  ("tbxq_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(sdot
  ("sdot_z_zzz_" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("sdot_z16_zzz_h" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("sdot_z32_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("sdot_z32_zzzi_" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__35"))
  ("sdot_z_zzzi_s" "ZUInteger.S, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__40"))
  ("sdot_z_zzzi_d" "ZUInteger.D, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__39"))
  ("sdot_z16_zzzi_h" "ZUInteger.H, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__53"))
  ("sdot_za32_zzi_2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("sdot_za_zzi_s2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("sdot_za_zzi_d2xi" "ZA.D[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("sdot_za32_zzi_4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
  ("sdot_za_zzi_s4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
  ("sdot_za_zzi_d4xi" "ZA.D[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
  ("sdot_za_zzv_2x1" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
  ("sdot_za32_zzv_2x1" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
  ("sdot_za_zzv_4x1" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
  ("sdot_za32_zzv_4x1" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
  ("sdot_za_zzw_2x2" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("sdot_za32_zzw_2x2" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("sdot_za_zzw_4x4" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("sdot_za32_zzw_4x4" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("SDOT_asimdsame2_D" "VUInteger.2S, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "Vm"))
  ("SDOT_asimdelem_D" "VUInteger.2S, VUInteger.8B, VUInteger.4B[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2"))
)

(frecpx
  ("frecpx_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("frecpx_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("FRECPX_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
  ("FRECPX_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
)

(setf16
  ("SETF16_only_setf" "WZR" (("Rn" (reg-range 0 31))) ("WnOrWZR"))
)

(cpyfen
  ("CPYFEN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(ldeorlh
  ("LDEORLH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(sha1m
  ("SHA1M_QSV_cryptosha3" "QUInteger, SUInteger, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Qd" "Sn__2" "Vm__7"))
)

(uqrshrn
  ("uqrshrn_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}, UInteger" (("imm4" (imm-range 0 15 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("uqrshrn_z_mz2_b" "ZUInteger.B, {Z UInteger .H- Z UInteger .H}, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("uqrshrn_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}, UInteger" (("imm5" (imm-range 0 31 1)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
  ("UQRSHRN_asisdshf_N" "BUInteger, HUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vb_option" "Va_option" "immh_shift__2"))
  ("UQRSHRN_asimdshf_N" "VUInteger.8B, VUInteger.8H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__6"))
)

(stzg
  ("STZG_64Spost_ldsttags" "SP, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option"))
  ("STZG_64Soffset_ldsttags" "SP, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option" "imm9_option__2"))
  ("STZG_64Spre_ldsttags" "SP, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option"))
)

(ldatxr
  ("LDATXR_LR32_ldstexclr_unpriv" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("LDATXR_LR64_ldstexclr_unpriv" "XZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
)

(ld4b
  ("ld4b_z_p_br_contiguous" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3" "Xm__4"))
  ("ld4b_z_p_bi_contiguous" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3"))
)

(cpyfprt
  ("CPYFPRT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(autib171615
  ("AUTIB171615_64LR_dp_1src" "" () ())
)

(bsl
  ("bsl_z_zzz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm" "Zk"))
  ("BSL_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(stfaddl
  ("STFADDL_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
  ("STFADDL_32" "SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
  ("STFADDL_64" "DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
)

(usra
  ("usra_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2"))
  ("USRA_asisdshf_R" "DUInteger, DUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("USRA_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__4"))
)

(csneg
  ("CSNEG_32_condsel" "WZR, WZR, WZR, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("CSNEG_64_condsel" "XZR, XZR, XZR, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
)

(ldbfminnml
  ("LDBFMINNML_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(ldsetal
  ("LDSETAL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDSETAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(stlp
  ("STLP_64_ldiappstilp" "XZR, XZR, [SP 0]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(bsl1n
  ("bsl1n_z_zzz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm" "Zk"))
)

(cpyfpwtrn
  ("CPYFPWTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(rcwsclrl
  ("RCWSCLRL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(cpyfpwtwn
  ("CPYFPWTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(sm3partw1
  ("SM3PARTW1_VVV4_cryptosha512_3" "VUInteger.4S, VUInteger.4S, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6" "Vm__7"))
)

(stlr
  ("STLR_SL32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("STLR_SL64_ldstord" "XZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
  ("STLR_32S_ldapstl_writeback" "WZR, [SP -4], !" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("STLR_64S_ldapstl_writeback" "XZR, [SP -8], !" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
)

(cpyetwn
  ("CPYETWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(orn
  ("orn_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
  ("ORN_32_log_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("ORN_64_log_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
  ("ORN_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(wfet
  ("WFET_only_systeminstrswithreg" "XZR" (("Rd" (reg-range 0 31))) ("XtOrXZR__5"))
)

(cblo
  ("CBLO_32_imm" "WZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "imm_cbr" "imm9_offset"))
  ("CBLO_64_imm" "XZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "imm_cbr" "imm9_offset"))
)

(fmlsl
  ("fmlsl_za_zzi_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
  ("fmlsl_za_zzi_2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm__2"))
  ("fmlsl_za_zzi_4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm__2"))
  ("fmlsl_za_zzv_2x1" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn2" "Zm__2"))
  ("fmlsl_za_zzv_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
  ("fmlsl_za_zzv_4x1" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn4" "Zm__2"))
  ("fmlsl_za_zzw_2x2" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("fmlsl_za_zzw_4x4" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("FMLSL_asimdsame_F" "VUInteger.2S, VUInteger.2H, VUInteger.2H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMLSL_asimdelem_LH" "VUInteger.2S, VUInteger.2H, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(ldursw
  ("LDURSW_64_ldst_unscaled" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
)

(cpypwtwn
  ("CPYPWTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(ldff1w
  ("ldff1w_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1w_z_p_bz_s_x32_scaled" "{Z UInteger .S}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1w_z_p_ai_s" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ldff1w_z_p_br_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldff1w_z_p_br_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldff1w_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1w_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1w_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ldff1w_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1w_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
)

(sm3tt1b
  ("SM3TT1B_VVV4_crypto3_imm2" "VUInteger.4S, VUInteger.4S, VUInteger.S[UInteger]" (("Rm" (reg-range 0 31)) ("imm2" (imm-range 0 3 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6" "Vm__7"))
)

(cpyfprn
  ("CPYFPRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(cbbeq
  ("CBBEQ_8_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
)

(uqxtn
  ("UQXTN_asisdmisc_N" "BUInteger, HUInteger" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vb_option__3" "Va_option__3"))
  ("UQXTN_asimdmisc_N" "VUInteger.8B, VUInteger.8H" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(swpl
  ("SWPL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
  ("SWPL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(mls
  ("mls_z_p_zzz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Pg" "Zn__2" "Zm"))
  ("mls_z_zzzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
  ("mls_z_zzzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__41"))
  ("mls_z_zzzi_d" "ZUInteger.D, ZUInteger.D, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__42"))
  ("MLS_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("MLS_asimdelem_R" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
)

(cpyfewtwn
  ("CPYFEWTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(rcwsswpp
  ("RCWSSWPP_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(fmaxnm
  ("fmaxnm_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("fmaxnm_z_p_zs_" "ZUInteger.H, PUInteger/M, ZUInteger.H, 0.0" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
  ("fmaxnm_mz_zzv_2x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
  ("fmaxnm_mz_zzv_4x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
  ("fmaxnm_mz_zzw_2x2" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
  ("fmaxnm_mz_zzw_4x4" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
  ("FMAXNM_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMAXNM_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMAXNM_S_floatdp2" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__3" "Sm"))
  ("FMAXNM_D_floatdp2" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__2" "Dm"))
  ("FMAXNM_H_floatdp2" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
)

(uqrshrnb
  ("uqrshrnb_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(sqdmlalb
  ("sqdmlalb_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("sqdmlalb_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
  ("sqdmlalb_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
)

(ldapursh
  ("LDAPURSH_64_ldapstl_unscaled" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
  ("LDAPURSH_32_ldapstl_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
)

(crc32x
  ("CRC32X_64C_dp_2src" "WZR, WZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR__2" "WnOrWZR__4" "XmOrXZR__8"))
)

(uqincw
  ("uqincw_z_zs_" "ZUInteger.S" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
  ("uqincw_r_rs_uw" "WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Wdn"))
  ("uqincw_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(ldnt1sw
  ("ldnt1sw_z_p_ar_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
)

(pacga
  ("PACGA_64P_dp_2src" "XZR, XZR, SP" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmSP_option__2"))
)

(cpyfet
  ("CPYFET_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(caslh
  ("CASLH_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
)

(f1cvtlt
  ("f1cvtlt_z_z8_b2h" "ZUInteger.H, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(st2g
  ("ST2G_64Spost_ldsttags" "SP, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option"))
  ("ST2G_64Soffset_ldsttags" "SP, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option" "imm9_option__2"))
  ("ST2G_64Spre_ldsttags" "SP, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option"))
)

(st2
  ("ST2_asisdlse_R2" "{V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
  ("ST2_asisdlsep_R2_r" "{V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
  ("ST2_asisdlsep_I2_i" "{V UInteger . 8B V UInteger . 8B}, [SP], 16" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "imm_option__6"))
  ("ST2_asisdlso_B2_2b" "{V UInteger . B V UInteger . B}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
  ("ST2_asisdlso_H2_2h" "{V UInteger . H V UInteger . H}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
  ("ST2_asisdlso_S2_2s" "{V UInteger . S V UInteger . S}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
  ("ST2_asisdlso_D2_2d" "{V UInteger . D V UInteger . D}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
  ("ST2_asisdlsop_BX2_r2b" "{V UInteger . B V UInteger . B}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
  ("ST2_asisdlsop_HX2_r2h" "{V UInteger . H V UInteger . H}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
  ("ST2_asisdlsop_SX2_r2s" "{V UInteger . S V UInteger . S}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
  ("ST2_asisdlsop_DX2_r2d" "{V UInteger . D V UInteger . D}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
  ("ST2_asisdlsop_B2_i2b" "{V UInteger . B V UInteger . B}, [UInteger], [SP], 2" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
  ("ST2_asisdlsop_H2_i2h" "{V UInteger . H V UInteger . H}, [UInteger], [SP], 4" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
  ("ST2_asisdlsop_S2_i2s" "{V UInteger . S V UInteger . S}, [UInteger], [SP], 8" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
  ("ST2_asisdlsop_D2_i2d" "{V UInteger . D V UInteger . D}, [UInteger], [SP], 16" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
)

(frint64z
  ("frint64z_z_p_z_z" "ZUInteger.S, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("frint64z_z_p_z_m" "ZUInteger.S, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("FRINT64Z_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FRINT64Z_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
  ("FRINT64Z_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
)

(tenter
  ("TENTER_te_exception" "UInteger" (("imm7" (imm-range 0 127 1))) ("imm_tindex"))
)

(addv
  ("ADDV_asimdall_only" "BUInteger, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__2" "Vn"))
)

(sqcvtun
  ("sqcvtun_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("sqcvtun_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
)

(bf2cvtl
  ("bf2cvtl_mz2_z8_" "{Z UInteger .H- Z UInteger .H}, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
  ("BF2CVTL_asimdmisc_V" "VUInteger.8H, VUInteger.8B" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(ldclrpal
  ("LDCLRPAL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(ldbfmaxal
  ("LDBFMAXAL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(ldeoralb
  ("LDEORALB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(addqv
  ("addqv_z_p_z_" "VUInteger.16B, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
)

(sha1su0
  ("SHA1SU0_VVV_cryptosha3" "VUInteger.4S, VUInteger.4S, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6" "Vm__7"))
)

(fmlalb
  ("fmlalb_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
  ("fmlalb_z_z8z8z8i_" "ZUInteger.H, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__56"))
  ("fmlalb_z_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("fmlalb_z_z8z8z8_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("FMLALB_asimdsame2_J" "VUInteger.8H, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMLALB_asimdelem_H" "VUInteger.8H, VUInteger.16B, VUInteger.B[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__6"))
)

(tbnz
  ("TBNZ_only_testbranch" "WZR, UInteger, SInteger" (("imm14" (imm-range 0 16383 1)) ("Rt" (reg-range 0 31))) ("imm_0_63" "imm14_offset"))
)

(ld3r
  ("LD3R_asisdlso_R3" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
  ("LD3R_asisdlsop_RX3_r" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
  ("LD3R_asisdlsop_R3_i" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], 3" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "imm_option__9"))
)

(brkas
  ("brkas_p_p_p_z" "PUInteger.B, PUInteger/Z, PUInteger.B" (("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__3"))
)

(ldseta
  ("LDSETA_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDSETA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(cpymrtwn
  ("CPYMRTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(cpye
  ("CPYE_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(xpaclri
  ("XPACLRI_HI_hints" "" () ())
)

(setffr
  ("setffr_f_" "" () ())
)

(cast
  ("CAST_C64_comswap_unpriv" "XZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
)

(autibsp
  ("AUTIBSP_HI_hints" "" () ())
)

(st4w
  ("st4w_z_p_br_contiguous" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3" "Xm__4"))
  ("st4w_z_p_bi_contiguous" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3"))
)

(rcwscaspal
  ("RCWSCASPAL_C64_rcwcomswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
)

(ldclrlb
  ("LDCLRLB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(ld2w
  ("ld2w_z_p_br_contiguous" "{Z UInteger .S Z UInteger .S}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3" "Xm__4"))
  ("ld2w_z_p_bi_contiguous" "{Z UInteger .S Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3"))
)

(and
  ("and_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("and_z_zz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("and_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm13" (imm-range 0 8191 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2"))
  ("and_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
  ("AND_32_log_imm" "WSP, WZR, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdWSP_option" "WnOrWZR" "imm__bitmask_w"))
  ("AND_64_log_imm" "SP, XZR, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option" "XnOrXZR__11" "imm__bitmask_x"))
  ("AND_32_log_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("AND_64_log_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
  ("AND_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(subhn
  ("SUBHN_asimddiff_N" "VUInteger.8B, VUInteger.8H, VUInteger.8H" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(uaddlv
  ("UADDLV_asimdall_only" "HUInteger, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option" "Vn"))
)

(ldrab
  ("LDRAB_64_ldst_pac" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "Simm9_option"))
  ("LDRAB_64W_ldst_pac" "XZR, [SP], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "Simm9_option"))
)

(uminqv
  ("uminqv_z_p_z_" "VUInteger.16B, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
)

(frsqrte
  ("frsqrte_z_z_" "ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
  ("FRSQRTE_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
  ("FRSQRTE_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("FRSQRTE_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FRSQRTE_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(stl1
  ("STL1_asisdlso_D1" "{V UInteger . D}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
)

(revb
  ("revb_z_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("revb_z_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
)

(caslt
  ("CASLT_C64_comswap_unpriv" "XZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
)

(swplb
  ("SWPLB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
)

(fmops
  ("fmops_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
  ("fmops_za32_pp_zz_16" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
  ("fmops_za_pp_zz_16" "ZAUInteger.H, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__3" "Pn" "Pm" "Zn__2" "Zm"))
  ("fmops_za_pp_zz_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn__2" "Zm"))
)

(lslr
  ("lslr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
)

(ldrsw
  ("LDRSW_64_loadlit" "XZR, SInteger" (("imm19" (imm-range 0 524287 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR__8" "imm19_offset__2"))
  ("LDRSW_64_ldst_immpost" "XZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
  ("LDRSW_64_ldst_immpre" "XZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
  ("LDRSW_64_ldst_regoff" "XZR, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "WorX_choice"))
  ("LDRSW_64_ldst_pos" "XZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm12_option__6"))
)

(rcwcas
  ("RCWCAS_C64_rcwcomswap" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
)

(sqrshr
  ("sqrshr_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}, UInteger" (("imm4" (imm-range 0 15 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("sqrshr_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}, UInteger" (("imm5" (imm-range 0 31 1)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
)

(cpymtwn
  ("CPYMTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(fmaxv
  ("fmaxv_v_p_z_" "HUInteger, PUInteger, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V__5" "Pg" "Zn"))
  ("FMAXV_asimdall_only_H" "HUInteger, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_hv" "Vn"))
  ("FMAXV_asimdall_only_SD" "SUInteger, VUInteger.4S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vn"))
)

(ldfaddal
  ("LDFADDAL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFADDAL_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFADDAL_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(ldsetab
  ("LDSETAB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(rcwsswpl
  ("RCWSSWPL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(ldaddlb
  ("LDADDLB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(ldbfaddal
  ("LDBFADDAL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(utmopa
  ("utmopa_za_zzzi_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
  ("utmopa_za32_zzzi_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
)

(sqcvtn
  ("sqcvtn_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("sqcvtn_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
)

(sabdlt
  ("sabdlt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(fsqrt
  ("fsqrt_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fsqrt_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("FSQRT_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FSQRT_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FSQRT_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
  ("FSQRT_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
  ("FSQRT_H_floatdp1" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
)

(eorqv
  ("eorqv_z_p_z_" "VUInteger.16B, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
)

(uqcvtn
  ("uqcvtn_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("uqcvtn_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
)

(prfb
  ("prfb_i_p_bz_s_x32_scaled" "PLDL1KEEP, PUInteger, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
  ("prfb_i_p_bi_s" "PLDL1KEEP, PUInteger, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3"))
  ("prfb_i_p_br_s" "PLDL1KEEP, PUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Xm__4"))
  ("prfb_i_p_ai_s" "PLDL1KEEP, PUInteger, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("Pg" "Zn__3"))
  ("prfb_i_p_bz_d_x32_scaled" "PLDL1KEEP, PUInteger, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
  ("prfb_i_p_ai_d" "PLDL1KEEP, PUInteger, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("Pg" "Zn__3"))
  ("prfb_i_p_bz_d_64_scaled" "PLDL1KEEP, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
)

(ldg
  ("LDG_64Loffset_ldsttags" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__4" "XnSP_option" "imm9_option__2"))
)

(incd
  ("incd_z_zs_" "ZUInteger.D" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
  ("incd_r_rs_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(cpyewtrn
  ("CPYEWTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(autiaz
  ("AUTIAZ_HI_hints" "" () ())
)

(setm
  ("SETM_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__3" "XnOrXZR__6" "XsOrXZR__7"))
)

(shrnb
  ("shrnb_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(cbeq
  ("CBEQ_32_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
  ("CBEQ_64_regs" "XZR, XZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "XmOrXZR__4" "imm9_offset"))
  ("CBEQ_32_imm" "WZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "imm_cbr" "imm9_offset"))
  ("CBEQ_64_imm" "XZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "imm_cbr" "imm9_offset"))
)

(smin
  ("smin_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("smin_z_zi_" "ZUInteger.B, ZUInteger.B, SInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__79"))
  ("smin_mz_zzv_2x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
  ("smin_mz_zzv_4x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
  ("smin_mz_zzw_2x2" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
  ("smin_mz_zzw_4x4" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
  ("SMIN_32_minmax_imm" "WZR, WZR, SInteger" (("imm8" (imm-range 0 255 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
  ("SMIN_64_minmax_imm" "XZR, XZR, SInteger" (("imm8" (imm-range 0 255 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
  ("SMIN_32_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("SMIN_64_dp_2src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
  ("SMIN_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(uaddv
  ("uaddv_r_p_z_" "DUInteger, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Dd__2" "Pg" "Zn"))
)

(rev64
  ("REV64_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(fcvtnb
  ("fcvtnb_z8_mz2_s2b" "ZUInteger.B, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
)

(cpymrt
  ("CPYMRT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(st4
  ("ST4_asisdlse_R4" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
  ("ST4_asisdlsep_R4_r" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
  ("ST4_asisdlsep_I4_i" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], 32" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "imm_option"))
  ("ST4_asisdlso_B4_4b" "{V UInteger . B V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
  ("ST4_asisdlso_H4_4h" "{V UInteger . H V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
  ("ST4_asisdlso_S4_4s" "{V UInteger . S V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
  ("ST4_asisdlso_D4_4d" "{V UInteger . D V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
  ("ST4_asisdlsop_BX4_r4b" "{V UInteger . B V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
  ("ST4_asisdlsop_HX4_r4h" "{V UInteger . H V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
  ("ST4_asisdlsop_SX4_r4s" "{V UInteger . S V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
  ("ST4_asisdlsop_DX4_r4d" "{V UInteger . D V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
  ("ST4_asisdlsop_B4_i4b" "{V UInteger . B V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP], 4" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
  ("ST4_asisdlsop_H4_i4h" "{V UInteger . H V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP], 8" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
  ("ST4_asisdlsop_S4_i4s" "{V UInteger . S V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP], 16" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
  ("ST4_asisdlsop_D4_i4d" "{V UInteger . D V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP], 32" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
)

(stfmaxnm
  ("STFMAXNM_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
  ("STFMAXNM_32" "SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
  ("STFMAXNM_64" "DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
)

(nors
  ("nors_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
)

(ld3h
  ("ld3h_z_p_br_contiguous" "{Z UInteger .H Z UInteger .H Z UInteger .H}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3" "Xm__4"))
  ("ld3h_z_p_bi_contiguous" "{Z UInteger .H Z UInteger .H Z UInteger .H}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3"))
)

(ccmn
  ("CCMN_32_condcmp_reg" "WZR, WZR, UInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("WnOrWZR__3" "WmOrWZR__2"))
  ("CCMN_64_condcmp_reg" "XZR, XZR, UInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnOrXZR__12" "XmOrXZR__4"))
  ("CCMN_32_condcmp_imm" "WZR, UInteger, UInteger, EQ" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31))) ("WnOrWZR" "imm__19"))
  ("CCMN_64_condcmp_imm" "XZR, UInteger, UInteger, EQ" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31))) ("XnOrXZR__11" "imm__19"))
)

(ldsetah
  ("LDSETAH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(dmb
  ("DMB_BO_barriers" "SY" () ())
)

(setetn
  ("SETETN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__3" "XnOrXZR__7" "XsOrXZR__7"))
)

(cbge
  ("CBGE_32_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
  ("CBGE_64_regs" "XZR, XZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "XmOrXZR__4" "imm9_offset"))
)

(bfmops
  ("bfmops_za32_pp_zz_" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
  ("bfmops_za_pp_zz_16" "ZAUInteger.H, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__3" "Pn" "Pm" "Zn__2" "Zm"))
)

(cmtst
  ("CMTST_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("CMTST_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(fmlall
  ("fmlall_za32_z8z8i_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
  ("fmlall_za32_z8z8i_2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm__2"))
  ("fmlall_za32_z8z8i_4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm__2"))
  ("fmlall_za32_z8z8v_2x1" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn2" "Zm__2"))
  ("fmlall_za32_z8z8v_4x1" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn4" "Zm__2"))
  ("fmlall_za32_z8z8v_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
  ("fmlall_za32_z8z8w_2x2" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("fmlall_za32_z8z8w_4x4" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
)

(ccmp
  ("CCMP_32_condcmp_reg" "WZR, WZR, UInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("WnOrWZR__3" "WmOrWZR__2"))
  ("CCMP_64_condcmp_reg" "XZR, XZR, UInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnOrXZR__12" "XmOrXZR__4"))
  ("CCMP_32_condcmp_imm" "WZR, UInteger, UInteger, EQ" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31))) ("WnOrWZR" "imm__19"))
  ("CCMP_64_condcmp_imm" "XZR, UInteger, UInteger, EQ" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31))) ("XnOrXZR__11" "imm__19"))
)

(cpymrn
  ("CPYMRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(ldapursb
  ("LDAPURSB_64_ldapstl_unscaled" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
  ("LDAPURSB_32_ldapstl_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
)

(fmax
  ("fmax_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("fmax_z_p_zs_" "ZUInteger.H, PUInteger/M, ZUInteger.H, 0.0" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
  ("fmax_mz_zzv_2x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
  ("fmax_mz_zzv_4x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
  ("fmax_mz_zzw_2x2" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
  ("fmax_mz_zzw_4x4" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
  ("FMAX_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMAX_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMAX_S_floatdp2" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__3" "Sm"))
  ("FMAX_D_floatdp2" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__2" "Dm"))
  ("FMAX_H_floatdp2" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
)

(bgrp
  ("bgrp_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(lslv
  ("LSLV_32_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__4"))
  ("LSLV_64_dp_2src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__7"))
)

(saddwb
  ("saddwb_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(rcwcasal
  ("RCWCASAL_C64_rcwcomswap" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
)

(prfd
  ("prfd_i_p_bz_s_x32_scaled" "PLDL1KEEP, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
  ("prfd_i_p_bi_s" "PLDL1KEEP, PUInteger, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3"))
  ("prfd_i_p_br_s" "PLDL1KEEP, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Xm__4"))
  ("prfd_i_p_ai_s" "PLDL1KEEP, PUInteger, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("Pg" "Zn__3"))
  ("prfd_i_p_bz_d_x32_scaled" "PLDL1KEEP, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
  ("prfd_i_p_ai_d" "PLDL1KEEP, PUInteger, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("Pg" "Zn__3"))
  ("prfd_i_p_bz_d_64_scaled" "PLDL1KEEP, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
)

(smax
  ("smax_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("smax_z_zi_" "ZUInteger.B, ZUInteger.B, SInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__79"))
  ("smax_mz_zzv_2x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
  ("smax_mz_zzv_4x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
  ("smax_mz_zzw_2x2" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
  ("smax_mz_zzw_4x4" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
  ("SMAX_32_minmax_imm" "WZR, WZR, SInteger" (("imm8" (imm-range 0 255 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
  ("SMAX_64_minmax_imm" "XZR, XZR, SInteger" (("imm8" (imm-range 0 255 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
  ("SMAX_32_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("SMAX_64_dp_2src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
  ("SMAX_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(stzgm
  ("STZGM_64bulk_ldsttags" "XZR, [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__3" "XnSP_option"))
)

(sqdecw
  ("sqdecw_z_zs_" "ZUInteger.S" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
  ("sqdecw_r_rs_sx" "XUInteger, WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn" "Wdn"))
  ("sqdecw_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(swptl
  ("SWPTL_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
  ("SWPTL_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(incb
  ("incb_r_rs_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(fccmp
  ("FCCMP_S_floatccmp" "SUInteger, SUInteger, UInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Sn__3" "Sm"))
  ("FCCMP_D_floatccmp" "DUInteger, DUInteger, UInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Dn__2" "Dm"))
  ("FCCMP_H_floatccmp" "HUInteger, HUInteger, UInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Hn" "Hm"))
)

(uabd
  ("uabd_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("UABD_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(swplh
  ("SWPLH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
)

(zipq1
  ("zipq1_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(usmop4a
  ("usmop4a_za_zz_b1x1" "ZAUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
  ("usmop4a_za_zz_b1x2" "ZAUInteger.S, ZUInteger.B, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("usmop4a_za_zz_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("usmop4a_za_zz_b2x2" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("usmop4a_za_zz_h1x1" "ZAUInteger.D, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm_mortlach"))
  ("usmop4a_za_zz_h1x2" "ZAUInteger.D, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("usmop4a_za_zz_h2x1" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("usmop4a_za_zz_h2x2" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
)

(cmpgt
  ("cmpgt_p_p_zz_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
  ("cmpgt_p_p_zw_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
  ("cmpgt_p_p_zi_" "PUInteger.B, PUInteger/Z, ZUInteger.B, SInteger" (("size" (element-size B H S D)) ("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn" "imm__43"))
)

(eretab
  ("ERETAB_64E_branch_reg" "" () ())
)

(brab
  ("BRAB_64P_branch_reg" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rm" (reg-range 0 31))) ("XnOrXZR" "XmSP_option"))
)

(ummla
  ("ummla_z_zzz_" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("UMMLA_asimdsame2_G" "VUInteger.4S, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "Vm"))
)

(revd
  ("revd_z_p_z_m" "ZUInteger.Q, PUInteger/M, ZUInteger.Q" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("revd_z_p_z_z" "ZUInteger.Q, PUInteger/Z, ZUInteger.Q" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
)

(smlsl
  ("smlsl_za_zzi_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
  ("smlsl_za_zzi_2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm__2"))
  ("smlsl_za_zzi_4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm__2"))
  ("smlsl_za_zzv_2x1" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn2" "Zm__2"))
  ("smlsl_za_zzv_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
  ("smlsl_za_zzv_4x1" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn4" "Zm__2"))
  ("smlsl_za_zzw_2x2" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("smlsl_za_zzw_4x4" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("SMLSL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("SMLSL_asimdelem_L" "VUInteger.4S, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
)

(ld2q
  ("ld2q_z_p_br_contiguous" "{Z UInteger .Q Z UInteger .Q}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3" "Xm__4"))
  ("ld2q_z_p_bi_contiguous" "{Z UInteger .Q Z UInteger .Q}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3"))
)

(ldaxrb
  ("LDAXRB_LR32_ldstexclr" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
)

(fcsel
  ("FCSEL_S_floatsel" "SUInteger, SUInteger, SUInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__3" "Sm"))
  ("FCSEL_D_floatsel" "DUInteger, DUInteger, DUInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__2" "Dm"))
  ("FCSEL_H_floatsel" "HUInteger, HUInteger, HUInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
)

(clrbhb
  ("CLRBHB_HI_hints" "" () ())
)

(cdot
  ("cdot_z_zzz_" "ZUInteger.S, ZUInteger.B, ZUInteger.B, 0" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("cdot_z_zzzi_s" "ZUInteger.S, ZUInteger.B, ZUInteger.B[UInteger, 0" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__40"))
  ("cdot_z_zzzi_d" "ZUInteger.D, ZUInteger.H, ZUInteger.H[UInteger, 0" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__39"))
)

(sha1c
  ("SHA1C_QSV_cryptosha3" "QUInteger, SUInteger, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Qd" "Sn__2" "Vm__7"))
)

(ldeorlb
  ("LDEORLB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(sbclb
  ("sbclb_z_zzz_" "ZUInteger.S, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
)

(sete
  ("SETE_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__3" "XnOrXZR__7" "XsOrXZR__7"))
)

(uaddlt
  ("uaddlt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(st2q
  ("st2q_z_p_bi_contiguous" "{Z UInteger .Q Z UInteger .Q}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3"))
  ("st2q_z_p_br_contiguous" "{Z UInteger .Q Z UInteger .Q}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3" "Xm__4"))
)

(ldeorah
  ("LDEORAH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(usubw
  ("USUBW_asimddiff_W" "VUInteger.8H, VUInteger.8H, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(cntw
  ("cntw_r_s_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rd" (reg-range 0 31))) ("Xd__2"))
)

(rcwcaspa
  ("RCWCASPA_C64_rcwcomswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
)

(sqrshl
  ("sqrshl_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("SQRSHL_asisdsame_only" "BUInteger, BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7" "V_option__7"))
  ("SQRSHL_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(rcwclra
  ("RCWCLRA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(inch
  ("inch_z_zs_" "ZUInteger.H" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
  ("inch_r_rs_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(ldsmaxlh
  ("LDSMAXLH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(cpymwt
  ("CPYMWT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(sqxtunb
  ("sqxtunb_z_zz_" "ZUInteger.B, ZUInteger.H" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(not
  ("not_z_p_z_m" "ZUInteger.B, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("not_z_p_z_z" "ZUInteger.B, PUInteger/Z, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("NOT_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(sqsub
  ("sqsub_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("sqsub_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__27"))
  ("sqsub_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("SQSUB_asisdsame_only" "BUInteger, BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7" "V_option__7"))
  ("SQSUB_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(retaasppcr
  ("RETAASPPCR_64M_branch_reg" "XZR" (("Rm" (reg-range 0 31))) ("XmOrXZR"))
)

(crc32h
  ("CRC32H_32C_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR__2" "WnOrWZR__4" "WmOrWZR__5"))
)

(dsb
  ("DSB_BO_barriers" "SY" () ())
  ("DSB_BOn_barriers" "SYnXS" (("imm2" (imm-range 0 3 1))) ("imm2_option"))
)

(rcwsclrpa
  ("RCWSCLRPA_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(mul
  ("mul_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("mul_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("mul_z_zi_" "ZUInteger.B, ZUInteger.B, SInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__79"))
  ("mul_z_zzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__78"))
  ("mul_z_zzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__41"))
  ("mul_z_zzi_d" "ZUInteger.D, ZUInteger.D, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__2" "imm__42"))
  ("MUL_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("MUL_asimdelem_R" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
)

(retabsppcr
  ("RETABSPPCR_64M_branch_reg" "XZR" (("Rm" (reg-range 0 31))) ("XmOrXZR"))
)

(setptn
  ("SETPTN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XnOrXZR__5" "XsOrXZR__7"))
)

(pacibz
  ("PACIBZ_HI_hints" "" () ())
)

(rcwscasp
  ("RCWSCASP_C64_rcwcomswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
)

(sqrshrun
  ("sqrshrun_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}, UInteger" (("imm4" (imm-range 0 15 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("sqrshrun_z_mz2_b" "ZUInteger.B, {Z UInteger .H- Z UInteger .H}, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("sqrshrun_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}, UInteger" (("imm5" (imm-range 0 31 1)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
  ("SQRSHRUN_asisdshf_N" "BUInteger, HUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vb_option" "Va_option" "immh_shift__2"))
  ("SQRSHRUN_asimdshf_N" "VUInteger.8B, VUInteger.8H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__6"))
)

(bsl2n
  ("bsl2n_z_zzz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm" "Zk"))
)

(asr
  ("asr_z_p_zi_" "ZUInteger.B, PUInteger/M, ZUInteger.B, UInteger" (("Pg" (reg-range 0 7)) ("imm3" (imm-range 0 7 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
  ("asr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("asr_z_p_zw_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("asr_z_zw_" "ZUInteger.B, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("asr_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(rcwsetpa
  ("RCWSETPA_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(stfmaxl
  ("STFMAXL_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
  ("STFMAXL_32" "SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
  ("STFMAXL_64" "DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
)

(sshl
  ("SSHL_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("SSHL_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(fneg
  ("fneg_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fneg_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("FNEG_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FNEG_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FNEG_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
  ("FNEG_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
  ("FNEG_H_floatdp1" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
)

(umopa
  ("umopa_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
  ("umopa_za32_pp_zz_16" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
  ("umopa_za_pp_zz_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn__2" "Zm"))
)

(umsubl
  ("UMSUBL_64WA_dp_3src" "XZR, WZR, WZR, XZR" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "WnOrWZR__5" "WmOrWZR__6" "XaOrXZR__2"))
)

(setgmn
  ("SETGMN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__9" "XsOrXZR__8"))
)

(pnext
  ("pnext_p_p_p_" "PUInteger.B, PUInteger, PUInteger.B" (("size" (element-size B H S D))) ("Pdn__2" "Pv" "Pdn__2"))
)

(sqrshru
  ("sqrshru_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}, UInteger" (("imm4" (imm-range 0 15 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("sqrshru_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}, UInteger" (("imm5" (imm-range 0 31 1)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
)

(sqcadd
  ("sqcadd_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B, 90" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm"))
)

(cbbhs
  ("CBBHS_8_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
)

(sqdmlalt
  ("sqdmlalt_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("sqdmlalt_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
  ("sqdmlalt_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
)

(cpyfmtn
  ("CPYFMTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(bfmlalt
  ("bfmlalt_z_zzzi_" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
  ("bfmlalt_z_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
)

(sqshlr
  ("sqshlr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
)

(cbhge
  ("CBHGE_16_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
)

(ldtrb
  ("LDTRB_32_ldst_unpriv" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
)

(scvtf
  ("scvtf_z_p_z_w2sz" "ZUInteger.S, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("scvtf_z_p_z_w2dz" "ZUInteger.D, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("scvtf_z_p_z_x2sz" "ZUInteger.S, PUInteger/Z, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("scvtf_z_p_z_x2dz" "ZUInteger.D, PUInteger/Z, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("scvtf_z_p_z_h2fp16z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("scvtf_z_p_z_w2fp16z" "ZUInteger.H, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("scvtf_z_p_z_x2fp16z" "ZUInteger.H, PUInteger/Z, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("scvtf_z_p_z_w2s" "ZUInteger.S, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("scvtf_z_p_z_w2d" "ZUInteger.D, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("scvtf_z_p_z_x2s" "ZUInteger.S, PUInteger/M, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("scvtf_z_p_z_x2d" "ZUInteger.D, PUInteger/M, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("scvtf_z_p_z_h2fp16" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("scvtf_z_p_z_w2fp16" "ZUInteger.H, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("scvtf_z_p_z_x2fp16" "ZUInteger.H, PUInteger/M, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("scvtf_z_z_" "ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
  ("scvtf_mz_z_2" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__4" "Zn2__3"))
  ("scvtf_mz_z_4" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
  ("SCVTF_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
  ("SCVTF_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("SCVTF_asisdshf_C" "HUInteger, HUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__6" "V_option__6" "immh_shift__3"))
  ("SCVTF_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("SCVTF_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("SCVTF_asimdshf_C" "VUInteger.4H, VUInteger.4H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__9"))
  ("SCVTF_S32_float2fix" "SUInteger, WZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "WnOrWZR"))
  ("SCVTF_D32_float2fix" "DUInteger, WZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "WnOrWZR"))
  ("SCVTF_H32_float2fix" "HUInteger, WZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "WnOrWZR"))
  ("SCVTF_S64_float2fix" "SUInteger, XZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "XnOrXZR__11"))
  ("SCVTF_D64_float2fix" "DUInteger, XZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "XnOrXZR__11"))
  ("SCVTF_H64_float2fix" "HUInteger, XZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "XnOrXZR__11"))
  ("SCVTF_S32_float2int" "SUInteger, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "WnOrWZR"))
  ("SCVTF_D32_float2int" "DUInteger, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "WnOrWZR"))
  ("SCVTF_H32_float2int" "HUInteger, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "WnOrWZR"))
  ("SCVTF_S64_float2int" "SUInteger, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "XnOrXZR__11"))
  ("SCVTF_D64_float2int" "DUInteger, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "XnOrXZR__11"))
  ("SCVTF_H64_float2int" "HUInteger, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "XnOrXZR__11"))
  ("SCVTF_sisd_32D" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
  ("SCVTF_sisd_32H" "HUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Sn"))
  ("SCVTF_sisd_64H" "HUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Dn"))
  ("SCVTF_sisd_64S" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
)

(msrr
  ("MSRR_SR_systemmovepr" "ACTLR_EL3, XZR, XUInteger" (("Rt" (reg-range 0 31))) ("XtOrXZR__6" "XtPlus1"))
)

(stshh
  ("STSHH_HI_hints" "KEEP" () ())
)

(ldaxrh
  ("LDAXRH_LR32_ldstexclr" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
)

(fmlalt
  ("fmlalt_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
  ("fmlalt_z_z8z8z8i_" "ZUInteger.H, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__56"))
  ("fmlalt_z_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("fmlalt_z_z8z8z8_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("FMLALT_asimdsame2_J" "VUInteger.8H, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMLALT_asimdelem_H" "VUInteger.8H, VUInteger.16B, VUInteger.B[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__6"))
)

(ld1rsb
  ("ld1rsb_z_p_bi_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1rsb_z_p_bi_s32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1rsb_z_p_bi_s16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
)

(ld1row
  ("ld1row_z_p_br_contiguous" "{Z UInteger .S}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1row_z_p_bi_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
)

(sshllt
  ("sshllt_z_zi_" "ZUInteger.H, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(sadalp
  ("sadalp_z_p_z_" "ZUInteger.H, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda__2" "Pg" "Zn__2"))
  ("SADALP_asimdmisc_P" "VUInteger.4H, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(st2w
  ("st2w_z_p_br_contiguous" "{Z UInteger .S Z UInteger .S}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3" "Xm__4"))
  ("st2w_z_p_bi_contiguous" "{Z UInteger .S Z UInteger .S}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3"))
)

(ldlar
  ("LDLAR_LR32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("LDLAR_LR64_ldstord" "XZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
)

(ldeorab
  ("LDEORAB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(bfmlal
  ("bfmlal_za_zzi_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
  ("bfmlal_za_zzi_2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm__2"))
  ("bfmlal_za_zzi_4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm__2"))
  ("bfmlal_za_zzv_2x1" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn2" "Zm__2"))
  ("bfmlal_za_zzv_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
  ("bfmlal_za_zzv_4x1" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn4" "Zm__2"))
  ("bfmlal_za_zzw_2x2" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("bfmlal_za_zzw_4x4" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("BFMLAL_asimdsame2_F_" "VUInteger.4S, VUInteger.8H, VUInteger.8H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("BFMLAL_asimdelem_F" "VUInteger.4S, VUInteger.8H, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__2"))
)

(ldsmina
  ("LDSMINA_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDSMINA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(ldtadda
  ("LDTADDA_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDTADDA_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(wfe
  ("WFE_HI_hints" "" () ())
)

(adclb
  ("adclb_z_zzz_" "ZUInteger.S, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
)

(cpymwtn
  ("CPYMWTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(ldxr
  ("LDXR_LR32_ldstexclr" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("LDXR_LR64_ldstexclr" "XZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
)

(cmpeq
  ("cmpeq_p_p_zw_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
  ("cmpeq_p_p_zz_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
  ("cmpeq_p_p_zi_" "PUInteger.B, PUInteger/Z, ZUInteger.B, SInteger" (("size" (element-size B H S D)) ("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn" "imm__43"))
)

(faddv
  ("faddv_v_p_z_" "HUInteger, PUInteger, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V__5" "Pg" "Zn"))
)

(cpyertwn
  ("CPYERTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(uaddlp
  ("UADDLP_asimdmisc_P" "VUInteger.4H, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(saba
  ("saba_z_zzz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("SABA_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(dgh
  ("DGH_HI_hints" "" () ())
)

(ldaddlh
  ("LDADDLH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(fmaxp
  ("fmaxp_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("FMAXP_asisdpair_only_H" "HUInteger, VUInteger.2H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vn"))
  ("FMAXP_asisdpair_only_SD" "SUInteger, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__4" "Vn"))
  ("FMAXP_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMAXP_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(ldfmin
  ("LDFMIN_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMIN_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMIN_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(sabalt
  ("sabalt_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
)

(ldtrh
  ("LDTRH_32_ldst_unpriv" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
)

(bdep
  ("bdep_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(ldbfadd
  ("LDBFADD_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(cmhi
  ("CMHI_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("CMHI_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(uunpklo
  ("uunpklo_z_z_" "ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(ldtrsh
  ("LDTRSH_64_ldst_unpriv" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
  ("LDTRSH_32_ldst_unpriv" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
)

(sqshrun
  ("sqshrun_z_mz2_" "ZUInteger.B, {Z UInteger . H - Z UInteger . H}, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("SQSHRUN_asisdshf_N" "BUInteger, HUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vb_option" "Va_option" "immh_shift__2"))
  ("SQSHRUN_asimdshf_N" "VUInteger.8B, VUInteger.8H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__6"))
)

(pext
  ("pext_pn_rr_" "PUInteger.B, PNUInteger[UInteger]" (("size" (element-size B H S D)) ("imm2" (imm-range 0 3 1)) ("PNn" (reg-range 0 7)) ("Pd" (reg-range 0 15))) ("Pd" "PNn__2" "imm__81"))
  ("pext_pp_rr_" "{P UInteger . B P UInteger . B}, PNUInteger[UInteger]" (("size" (element-size B H S D)) ("PNn" (reg-range 0 7)) ("Pd" (reg-range 0 15))) ("Pd1" "Pd2" "PNn__2" "imm__82"))
)

(wfi
  ("WFI_HI_hints" "" () ())
)

(ldclrb
  ("LDCLRB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(cpymwtrn
  ("CPYMWTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(srshlr
  ("srshlr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
)

(pacib1716
  ("PACIB1716_HI_hints" "" () ())
)

(dupq
  ("dupq_z_zi_" "ZUInteger.D, ZUInteger.D[UInteger]" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn" "imm__48"))
)

(rorv
  ("RORV_32_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__4"))
  ("RORV_64_dp_2src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__7"))
)

(prfh
  ("prfh_i_p_bz_s_x32_scaled" "PLDL1KEEP, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
  ("prfh_i_p_bi_s" "PLDL1KEEP, PUInteger, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3"))
  ("prfh_i_p_br_s" "PLDL1KEEP, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Xm__4"))
  ("prfh_i_p_ai_s" "PLDL1KEEP, PUInteger, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("Pg" "Zn__3"))
  ("prfh_i_p_bz_d_x32_scaled" "PLDL1KEEP, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
  ("prfh_i_p_ai_d" "PLDL1KEEP, PUInteger, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("Pg" "Zn__3"))
  ("prfh_i_p_bz_d_64_scaled" "PLDL1KEEP, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
)

(cpypwtrn
  ("CPYPWTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(clasta
  ("clasta_z_p_zz_" "ZUInteger.B, PUInteger, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("clasta_v_p_z_" "BUInteger, PUInteger, BUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31))) ("V__2" "Pg" "V__2" "Zm__5"))
  ("clasta_r_p_z_" "WZR, PUInteger, WZR, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Rdn" (reg-range 0 31))) ("Pg" "Zm__5"))
)

(lduminlb
  ("LDUMINLB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(uzpq2
  ("uzpq2_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(sshr
  ("SSHR_asisdshf_R" "DUInteger, DUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("SSHR_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__4"))
)

(urshl
  ("urshl_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("urshl_mz_zzv_2x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
  ("urshl_mz_zzv_4x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
  ("urshl_mz_zzw_2x2" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
  ("urshl_mz_zzw_4x4" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
  ("URSHL_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("URSHL_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(ldxp
  ("LDXP_LP32_ldstexclp" "WZR, WZR, [SP 0]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option"))
  ("LDXP_LP64_ldstexclp" "XZR, XZR, [SP 0]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(cmplo
  ("cmplo_p_p_zw_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
  ("cmplo_p_p_zi_" "PUInteger.B, PUInteger/Z, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm7" (imm-range 0 127 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn" "imm__44"))
)

(ldfmaxnml
  ("LDFMAXNML_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMAXNML_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMAXNML_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(swptal
  ("SWPTAL_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
  ("SWPTAL_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(ldaprh
  ("LDAPRH_32L_memop" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__2" "XnSP_option"))
)

(autib
  ("AUTIB_64P_dp_1src" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__7"))
)

(retaasppc
  ("RETAASPPC_only_miscbranch" "SInteger" (("imm16" (imm-range 0 65535 1))) ("imm16_offset"))
)

(ldtset
  ("LDTSET_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDTSET_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(ldff1sh
  ("ldff1sh_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1sh_z_p_bz_s_x32_scaled" "{Z UInteger .S}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1sh_z_p_ai_s" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ldff1sh_z_p_br_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldff1sh_z_p_br_s32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldff1sh_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1sh_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1sh_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ldff1sh_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1sh_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
)

(ld1rsh
  ("ld1rsh_z_p_bi_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1rsh_z_p_bi_s32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
)

(cpyfertn
  ("CPYFERTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(ustmopa
  ("ustmopa_za_zzzi_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
)

(autiza
  ("AUTIZA_64Z_dp_1src" "XZR" (("Rd" (reg-range 0 31))) ("XdOrXZR__6"))
)

(sabal
  ("sabal_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("SABAL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(usdot
  ("usdot_z_zzz_s" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("usdot_z_zzzi_s" "ZUInteger.S, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__40"))
  ("usdot_za_zzi_s2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("usdot_za_zzi_s4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
  ("usdot_za_zzv_s2x1" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
  ("usdot_za_zzv_s4x1" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
  ("usdot_za_zzw_s2x2" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("usdot_za_zzw_s4x4" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("USDOT_asimdsame2_D" "VUInteger.2S, VUInteger.8B, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "Vm"))
  ("USDOT_asimdelem_D" "VUInteger.2S, VUInteger.8B, VUInteger.4B[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "H_L"))
)

(sbclt
  ("sbclt_z_zzz_" "ZUInteger.S, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
)

(ldumaxah
  ("LDUMAXAH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(ldeorb
  ("LDEORB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(uaddlb
  ("uaddlb_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(histseg
  ("histseg_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(urshlr
  ("urshlr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
)

(cpyfert
  ("CPYFERT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(cmpls
  ("cmpls_p_p_zw_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
  ("cmpls_p_p_zi_" "PUInteger.B, PUInteger/Z, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm7" (imm-range 0 127 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn" "imm__44"))
)

(shuh
  ("SHUH_HI_hints" "" () ())
)

(stg
  ("STG_64Spost_ldsttags" "SP, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option"))
  ("STG_64Soffset_ldsttags" "SP, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option" "imm9_option__2"))
  ("STG_64Spre_ldsttags" "SP, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option"))
)

(uqshrnb
  ("uqshrnb_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(sqshl
  ("sqshl_z_p_zi_" "ZUInteger.B, PUInteger/M, ZUInteger.B, UInteger" (("Pg" (reg-range 0 7)) ("imm3" (imm-range 0 7 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
  ("sqshl_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("SQSHL_asisdsame_only" "BUInteger, BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7" "V_option__7"))
  ("SQSHL_asisdshf_R" "BUInteger, BUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__5" "V_option__5" "immh_shift"))
  ("SQSHL_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("SQSHL_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__5"))
)

(saddw
  ("SADDW_asimddiff_W" "VUInteger.8H, VUInteger.8H, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(sqdmlalbt
  ("sqdmlalbt_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
)

(sshll
  ("SSHLL_asimdshf_L" "VUInteger.8H, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__8"))
)

(saddwt
  ("saddwt_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(prfum
  ("PRFUM_P_ldst_unscaled" "PLDL1KEEP, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option" "imm9_option"))
)

(smullt
  ("smullt_z_zzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__78"))
  ("smullt_z_zzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__2" "imm__88"))
  ("smullt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(udiv
  ("udiv_z_p_zz_" "ZUInteger.S, PUInteger/M, ZUInteger.S, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("UDIV_32_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("UDIV_64_dp_2src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
)

(rcwscasal
  ("RCWSCASAL_C64_rcwcomswap" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
)

(sm3tt2b
  ("SM3TT2B_VVV_crypto3_imm2" "VUInteger.4S, VUInteger.4S, VUInteger.S[UInteger]" (("Rm" (reg-range 0 31)) ("imm2" (imm-range 0 3 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6" "Vm__7"))
)

(faddp
  ("faddp_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("FADDP_asisdpair_only_H" "HUInteger, VUInteger.2H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vn"))
  ("FADDP_asisdpair_only_SD" "SUInteger, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__4" "Vn"))
  ("FADDP_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FADDP_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(brkpas
  ("brkpas_p_p_pp_" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
)

(lduminalh
  ("LDUMINALH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(fcvtnt
  ("fcvtnt_z_p_z_s2hz" "ZUInteger.H, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtnt_z_p_z_d2sz" "ZUInteger.S, PUInteger/Z, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtnt_z_p_z_s2h" "ZUInteger.H, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtnt_z_p_z_d2s" "ZUInteger.S, PUInteger/M, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtnt_z8_mz2_s2b" "ZUInteger.B, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
)

(pacia
  ("PACIA_64P_dp_1src" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__7"))
)

(bfmopa
  ("bfmopa_za32_pp_zz_" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
  ("bfmopa_za_pp_zz_16" "ZAUInteger.H, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__3" "Pn" "Pm" "Zn__2" "Zm"))
)

(paciasp
  ("PACIASP_HI_hints" "" () ())
)

(ld4r
  ("LD4R_asisdlso_R4" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
  ("LD4R_asisdlsop_RX4_r" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
  ("LD4R_asisdlsop_R4_i" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], 4" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "imm_option__11"))
)

(fcmge
  ("fcmge_p_p_zz_" "PUInteger.H, PUInteger/Z, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
  ("fcmge_p_p_z0_" "PUInteger.H, PUInteger/Z, ZUInteger.H, 0.0" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn"))
  ("FCMGE_asisdsamefp16_only" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
  ("FCMGE_asisdmiscfp16_FZ" "HUInteger, HUInteger, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
  ("FCMGE_asisdmisc_FZ" "SUInteger, SUInteger, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("FCMGE_asisdsame_only" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9" "V_option__9"))
  ("FCMGE_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FCMGE_asimdmiscfp16_FZ" "VUInteger.4H, VUInteger.4H, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCMGE_asimdmisc_FZ" "VUInteger.2S, VUInteger.2S, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCMGE_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(setgmt
  ("SETGMT_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__9" "XsOrXZR__8"))
)

(rcwscaspa
  ("RCWSCASPA_C64_rcwcomswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
)

(swpal
  ("SWPAL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
  ("SWPAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(ldsmaxalh
  ("LDSMAXALH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(cbbge
  ("CBBGE_8_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
)

(rcwsetal
  ("RCWSETAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(incp
  ("incp_z_p_z_" "ZUInteger.H, PUInteger.H" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pm__3"))
  ("incp_r_p_r_" "XUInteger, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Rdn" (reg-range 0 31))) ("Xdn" "Pm__3"))
)

(setgomtn
  ("SETGOMTN_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__9"))
)

(addp
  ("addp_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("ADDP_asisdpair_only" "DUInteger, VUInteger.2D" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vn"))
  ("ADDP_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(sumop4s
  ("sumop4s_za_zz_b1x1" "ZAUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
  ("sumop4s_za_zz_b1x2" "ZAUInteger.S, ZUInteger.B, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("sumop4s_za_zz_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("sumop4s_za_zz_b2x2" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("sumop4s_za_zz_h1x1" "ZAUInteger.D, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm_mortlach"))
  ("sumop4s_za_zz_h1x2" "ZAUInteger.D, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("sumop4s_za_zz_h2x1" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("sumop4s_za_zz_h2x2" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
)

(orv
  ("orv_r_p_z_" "BUInteger, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V" "Pg" "Zn"))
)

(st1d
  ("st1d_z_p_br_u128" "{Z UInteger .Q}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("st1d_z_p_br_" "{Z UInteger .D}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("st1d_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("st1d_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("st1d_z_p_bz_d_64_unscaled" "{Z UInteger . D}, PUInteger, [SP Z UInteger . D]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("st1d_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("st1d_z_p_ai_d" "{Z UInteger .D}, PUInteger, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("st1d_z_p_bi_u128" "{Z UInteger .Q}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("st1d_z_p_bi_" "{Z UInteger .D}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("st1d_mz_p_br_2" "{Z UInteger .D- Z UInteger .D}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
  ("st1d_mz_p_br_4" "{Z UInteger .D- Z UInteger .D}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
  ("st1d_mz_p_bi_2" "{Z UInteger .D- Z UInteger .D}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
  ("st1d_mz_p_bi_4" "{Z UInteger .D- Z UInteger .D}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
  ("st1d_mzx_p_br_2x8" "{Z UInteger .D Z UInteger .D}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
  ("st1d_mzx_p_br_4x4" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
  ("st1d_mzx_p_bi_2x8" "{Z UInteger .D Z UInteger .D}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
  ("st1d_mzx_p_bi_4x4" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
  ("st1d_za_p_rrr_" "{ZA UInteger H .D [W UInteger UInteger]}, PUInteger, [SP]" (("Rm" (reg-range 0 31)) ("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("ZAt" "HV" "Ws__3" "offs__3" "Pg" "XnSP__3"))
)

(ldsminalb
  ("LDSMINALB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(ldclrl
  ("LDCLRL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDCLRL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(ldnf1sw
  ("ldnf1sw_z_p_bi_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
)

(extq
  ("extq_z_zi_des" "ZUInteger.B, ZUInteger.B, ZUInteger.B, UInteger" (("imm4" (imm-range 0 15 1)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm" "imm__50"))
)

(xaflag
  ("XAFLAG_M_pstate" "" () ())
)

(ld4h
  ("ld4h_z_p_br_contiguous" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3" "Xm__4"))
  ("ld4h_z_p_bi_contiguous" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3"))
)

(bics
  ("bics_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
  ("BICS_32_log_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("BICS_64_log_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
)

(facge
  ("facge_p_p_zz_" "PUInteger.H, PUInteger/Z, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
  ("FACGE_asisdsamefp16_only" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
  ("FACGE_asisdsame_only" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9" "V_option__9"))
  ("FACGE_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FACGE_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(lasta
  ("lasta_v_p_z_" "BUInteger, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V__7" "Pg" "Zn"))
  ("lasta_r_p_z_" "WZR, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Pg" "Zn"))
)

(sqdmullt
  ("sqdmullt_z_zzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__78"))
  ("sqdmullt_z_zzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__2" "imm__88"))
  ("sqdmullt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(swpb
  ("SWPB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
)

(lduminlh
  ("LDUMINLH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(uabdl
  ("UABDL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(autiasppc
  ("AUTIASPPC_only_dp_1src_imm" "SInteger" (("imm16" (imm-range 0 65535 1))) ("imm16_offset"))
)

(ldclrpl
  ("LDCLRPL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(insr
  ("insr_z_r_" "ZUInteger.B, WZR" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
  ("insr_z_v_" "ZUInteger.B, BUInteger" (("size" (element-size B H S D)) ("Vm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "V__6"))
)

(ldsminalh
  ("LDSMINALH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(fdivr
  ("fdivr_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
)

(uabdlb
  ("uabdlb_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(expand
  ("expand_z_p_z_" "ZUInteger.B, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
)

(ldfmax
  ("LDFMAX_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMAX_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMAX_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(saddlb
  ("saddlb_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(st3q
  ("st3q_z_p_bi_contiguous" "{Z UInteger .Q Z UInteger .Q Z UInteger .Q}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3"))
  ("st3q_z_p_br_contiguous" "{Z UInteger .Q Z UInteger .Q Z UInteger .Q}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3" "Xm__4"))
)

(ldsmaxalb
  ("LDSMAXALB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(pacnbibsppc
  ("PACNBIBSPPC_64LR_dp_1src" "" () ())
)

(psel
  ("psel_p_ppi_" "PUInteger, PUInteger, PUInteger.D, [W UInteger UInteger]" (("Pn" (reg-range 0 15)) ("Pm" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pn__2" "Pm__2" "Wv__2" "imm__87"))
)

(swppa
  ("SWPPA_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(nor
  ("nor_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
)

(umaxv
  ("umaxv_r_p_z_" "BUInteger, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V" "Pg" "Zn"))
  ("UMAXV_asimdall_only" "BUInteger, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__2" "Vn"))
)

(ldumaxab
  ("LDUMAXAB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(fmla
  ("fmla_z_zzzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
  ("fmla_z_zzzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__55"))
  ("fmla_z_zzzi_d" "ZUInteger.D, ZUInteger.D, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__54"))
  ("fmla_z_p_zzz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Pg" "Zn__2" "Zm"))
  ("fmla_za_zzi_h2xi" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("fmla_za_zzi_s2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .S- Z UInteger .S}, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("fmla_za_zzi_d2xi" "ZA.D[WUInteger, UInteger, VGx2, {Z UInteger .D- Z UInteger .D}, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("fmla_za_zzi_h4xi" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
  ("fmla_za_zzi_s4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .S- Z UInteger .S}, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
  ("fmla_za_zzi_d4xi" "ZA.D[WUInteger, UInteger, VGx4, {Z UInteger .D- Z UInteger .D}, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
  ("fmla_za_zzv_2x1" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}, ZUInteger.S" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
  ("fmla_za_zzv_2x1_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
  ("fmla_za_zzv_4x1" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}, ZUInteger.S" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
  ("fmla_za_zzv_4x1_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
  ("fmla_za_zzw_2x2_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("fmla_za_zzw_2x2" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}, {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("fmla_za_zzw_4x4_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("fmla_za_zzw_4x4" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}, {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("FMLA_asisdelem_RH_H" "HUInteger, HUInteger, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Vm__2"))
  ("FMLA_asisdelem_R_SD" "SUInteger, SUInteger, VUInteger.S[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("FMLA_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMLA_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMLA_asimdelem_RH_H" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__2"))
  ("FMLA_asimdelem_R_SD" "VUInteger.2S, VUInteger.2S, VUInteger.S[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2"))
)

(ldpsw
  ("LDPSW_64_ldstpair_post" "XZR, XZR, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__12"))
  ("LDPSW_64_ldstpair_off" "XZR, XZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm7_option"))
  ("LDPSW_64_ldstpair_pre" "XZR, XZR, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__12"))
)

(ldfaddl
  ("LDFADDL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFADDL_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFADDL_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(trn2
  ("trn2_z_zz_q" "ZUInteger.Q, ZUInteger.Q, ZUInteger.Q" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("trn2_p_pp_" "PUInteger.B, PUInteger.B, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pn__2" "Pm__2"))
  ("trn2_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("TRN2_asimdperm_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(orr
  ("orr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("orr_z_zz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("orr_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm13" (imm-range 0 8191 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2"))
  ("orr_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
  ("ORR_32_log_imm" "WSP, WZR, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdWSP_option" "WnOrWZR" "imm__bitmask_w"))
  ("ORR_64_log_imm" "SP, XZR, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option" "XnOrXZR__11" "imm__bitmask_x"))
  ("ORR_32_log_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("ORR_64_log_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
  ("ORR_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("ORR_asimdimm_L_sl" "VUInteger.2S, UInteger" (("Rd" (reg-range 0 31))) ("Vd__2"))
  ("ORR_asimdimm_L_hl" "VUInteger.4H, UInteger" (("Rd" (reg-range 0 31))) ("Vd__2"))
)

(st1h
  ("st1h_z_p_br_" "{Z UInteger . H}, PUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("st1h_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("st1h_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("st1h_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("st1h_z_p_bz_s_x32_scaled" "{Z UInteger .S}, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("st1h_z_p_bz_d_64_unscaled" "{Z UInteger . D}, PUInteger, [SP Z UInteger . D]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("st1h_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("st1h_z_p_ai_d" "{Z UInteger .D}, PUInteger, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("st1h_z_p_ai_s" "{Z UInteger .S}, PUInteger, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("st1h_z_p_bi_" "{Z UInteger . H}, PUInteger, [SP]" (("size" (element-size B H S D)) ("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("st1h_mz_p_br_2" "{Z UInteger .H- Z UInteger .H}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
  ("st1h_mz_p_br_4" "{Z UInteger .H- Z UInteger .H}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
  ("st1h_mz_p_bi_2" "{Z UInteger .H- Z UInteger .H}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
  ("st1h_mz_p_bi_4" "{Z UInteger .H- Z UInteger .H}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
  ("st1h_mzx_p_br_2x8" "{Z UInteger .H Z UInteger .H}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
  ("st1h_mzx_p_br_4x4" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
  ("st1h_mzx_p_bi_2x8" "{Z UInteger .H Z UInteger .H}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
  ("st1h_mzx_p_bi_4x4" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
  ("st1h_za_p_rrr_" "{ZA UInteger H .H [W UInteger UInteger]}, PUInteger, [SP]" (("Rm" (reg-range 0 31)) ("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("ZAt__2" "HV" "Ws__3" "offs__4" "Pg" "XnSP__3"))
)

(ldclrh
  ("LDCLRH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(rcwswpa
  ("RCWSWPA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(ldff1sb
  ("ldff1sb_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1sb_z_p_ai_s" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ldff1sb_z_p_br_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldff1sb_z_p_br_s32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldff1sb_z_p_br_s16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldff1sb_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ldff1sb_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ldff1sb_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
)

(histcnt
  ("histcnt_z_p_zz_" "ZUInteger.S, PUInteger/Z, ZUInteger.S, ZUInteger.S" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn__2" "Zm"))
)

(rcwscasl
  ("RCWSCASL_C64_rcwcomswap" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
)

(urshr
  ("urshr_z_p_zi_" "ZUInteger.B, PUInteger/M, ZUInteger.B, UInteger" (("Pg" (reg-range 0 7)) ("imm3" (imm-range 0 7 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
  ("URSHR_asisdshf_R" "DUInteger, DUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("URSHR_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__4"))
)

(frsqrts
  ("frsqrts_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("FRSQRTS_asisdsamefp16_only" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
  ("FRSQRTS_asisdsame_only" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9" "V_option__9"))
  ("FRSQRTS_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FRSQRTS_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(swpah
  ("SWPAH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
)

(cpyfern
  ("CPYFERN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(ldnp
  ("LDNP_32_ldstnapair_offs" "WZR, WZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option" "imm7_option"))
  ("LDNP_S_ldstnapair_offs" "SUInteger, SUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St1" "St2" "XnSP_option" "imm7_option"))
  ("LDNP_D_ldstnapair_offs" "DUInteger, DUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt1" "Dt2" "XnSP_option" "imm7_option__2"))
  ("LDNP_64_ldstnapair_offs" "XZR, XZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm7_option__2"))
  ("LDNP_Q_ldstnapair_offs" "QUInteger, QUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm7_option__3"))
)

(autiasppcr
  ("AUTIASPPCR_64LRR_dp_1src" "XZR" (("Rn" (reg-range 0 31))) ("XnOrXZR__11"))
)

(ldsmaxlb
  ("LDSMAXLB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(ubfm
  ("UBFM_32M_bitfield" "WZR, WZR, UInteger, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR" "immr" "imms"))
  ("UBFM_64M_bitfield" "XZR, XZR, UInteger, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11" "immr__2" "imms__2"))
)

(ldaprb
  ("LDAPRB_32L_memop" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__2" "XnSP_option"))
)

(subpt
  ("subpt_z_p_zz_" "ZUInteger.D, PUInteger/M, ZUInteger.D, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("subpt_z_zz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("SUBPT_64_addsub_pt" "SP, SP, XZR" (("Rm" (reg-range 0 31)) ("imm3" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option__3" "XnSP_option__5" "XmOrXZR__4" "imm3_option"))
)

(nop
  ("NOP_HI_hints" "" () ())
)

(maddpt
  ("MADDPT_64A_dp_3src" "XZR, XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__13" "XmOrXZR__9" "XaOrXZR"))
)

(esb
  ("ESB_HI_hints" "" () ())
)

(smc
  ("SMC_EX_exception" "UInteger" (("imm16" (imm-range 0 65535 1))) ("imm"))
)

(caspl
  ("CASPL_CP32_comswappr" "WUInteger, WUInteger, WUInteger, WUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ws" "WsPlus1" "Wt" "WtPlus1" "XnSP_option"))
  ("CASPL_CP64_comswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
)

(rcwclral
  ("RCWCLRAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(andv
  ("andv_r_p_z_" "BUInteger, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V" "Pg" "Zn"))
)

(umlsl
  ("umlsl_za_zzi_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
  ("umlsl_za_zzi_2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm__2"))
  ("umlsl_za_zzi_4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm__2"))
  ("umlsl_za_zzv_2x1" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn2" "Zm__2"))
  ("umlsl_za_zzv_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
  ("umlsl_za_zzv_4x1" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn4" "Zm__2"))
  ("umlsl_za_zzw_2x2" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("umlsl_za_zzw_4x4" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("UMLSL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("UMLSL_asimdelem_L" "VUInteger.4S, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
)

(fmul
  ("fmul_z_zzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__36"))
  ("fmul_z_zzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__55"))
  ("fmul_z_zzi_d" "ZUInteger.D, ZUInteger.D, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__2" "imm__54"))
  ("fmul_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("fmul_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("fmul_z_p_zs_" "ZUInteger.H, PUInteger/M, ZUInteger.H, 0.5" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
  ("fmul_mz_zzw_2x2" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("fmul_mz_zzw_4x4" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("fmul_mz_zzv_2x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__2" "Zn2__2" "Zm__2"))
  ("fmul_mz_zzv_4x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__3" "Zn4__2" "Zm__2"))
  ("FMUL_asisdelem_RH_H" "HUInteger, HUInteger, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Vm__2"))
  ("FMUL_asisdelem_R_SD" "SUInteger, SUInteger, VUInteger.S[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("FMUL_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMUL_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMUL_asimdelem_RH_H" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__2"))
  ("FMUL_asimdelem_R_SD" "VUInteger.2S, VUInteger.2S, VUInteger.S[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2"))
  ("FMUL_S_floatdp2" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__3" "Sm"))
  ("FMUL_D_floatdp2" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__2" "Dm"))
  ("FMUL_H_floatdp2" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
)

(ldaddh
  ("LDADDH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(cpyprtwn
  ("CPYPRTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(fcmuo
  ("fcmuo_p_p_zz_" "PUInteger.H, PUInteger/Z, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
)

(eor
  ("eor_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("eor_z_zz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("eor_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm13" (imm-range 0 8191 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2"))
  ("eor_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
  ("EOR_32_log_imm" "WSP, WZR, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdWSP_option" "WnOrWZR" "imm__bitmask_w"))
  ("EOR_64_log_imm" "SP, XZR, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option" "XnOrXZR__11" "imm__bitmask_x"))
  ("EOR_32_log_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("EOR_64_log_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
  ("EOR_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(whilelo
  ("whilelo_pn_rr_" "PNUInteger.B, XUInteger, XUInteger, VLx2" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("PNd" (reg-range 0 7))) ("PNd" "Xn__4" "Xm__6"))
  ("whilelo_pp_rr_" "{P UInteger . B P UInteger . B}, XUInteger, XUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 7))) ("Pd1__2" "Pd2__2" "Xn__4" "Xm__6"))
  ("whilelo_p_p_rr_" "PUInteger.B, WZR, WZR" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd"))
)

(ssublb
  ("ssublb_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(rdffrs
  ("rdffrs_p_p_f_" "PUInteger.B, PUInteger/Z" (("Pg" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2"))
)

(ftmopa
  ("ftmopa_za_zzzi_s2x1" "ZAUInteger.S, {Z UInteger .S- Z UInteger .S}, ZUInteger.S, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
  ("ftmopa_za32_z8z8zi_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
  ("ftmopa_za32_zzzi_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
  ("ftmopa_za16_z8z8zi_b2x1" "ZAUInteger.H, {Z UInteger .B- Z UInteger .B}, ZUInteger.B, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda__3" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
  ("ftmopa_za_zzzi_h2x1" "ZAUInteger.H, {Z UInteger .H- Z UInteger .H}, ZUInteger.H, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda__3" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
)

(ldaddah
  ("LDADDAH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(bfmlslb
  ("bfmlslb_z_zzzi_" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
  ("bfmlslb_z_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
)

(sdiv
  ("sdiv_z_p_zz_" "ZUInteger.S, PUInteger/M, ZUInteger.S, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("SDIV_32_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("SDIV_64_dp_2src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
)

(bfsub
  ("bfsub_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("bfsub_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("bfsub_za_zw_2x2_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1" "Zm2"))
  ("bfsub_za_zw_4x4_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1__2" "Zm4"))
)

(wfit
  ("WFIT_only_systeminstrswithreg" "XZR" (("Rd" (reg-range 0 31))) ("XtOrXZR__5"))
)

(xpaci
  ("XPACI_64Z_dp_1src" "XZR" (("Rd" (reg-range 0 31))) ("XdOrXZR__6"))
)

(uqrshrnt
  ("uqrshrnt_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(lsl
  ("lsl_z_p_zi_" "ZUInteger.B, PUInteger/M, ZUInteger.B, UInteger" (("Pg" (reg-range 0 7)) ("imm3" (imm-range 0 7 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
  ("lsl_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("lsl_z_p_zw_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("lsl_z_zw_" "ZUInteger.B, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("lsl_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(sha512h2
  ("SHA512H2_QQV_cryptosha512_3" "QUInteger, QUInteger, VUInteger.2D" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Qd__2" "Qn" "Vm__7"))
)

(ret
  ("RET_64R_branch_reg" "" (("Rn" (reg-range 0 31))) ())
)

(smov
  ("SMOV_asimdins_W_w" "WZR, VUInteger.B[UInteger]" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Vn" "imm5_index__2"))
  ("SMOV_asimdins_X_x" "XZR, VUInteger.B[UInteger]" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Vn" "imm5_index__3"))
)

(sqdmlslb
  ("sqdmlslb_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("sqdmlslb_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
  ("sqdmlslb_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
)

(xtn
  ("XTN_asimdmisc_N" "VUInteger.8B, VUInteger.8H" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(rcwsclrpl
  ("RCWSCLRPL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(uqdech
  ("uqdech_z_zs_" "ZUInteger.H" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
  ("uqdech_r_rs_uw" "WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Wdn"))
  ("uqdech_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(ldnt1h
  ("ldnt1h_z_p_ar_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ldnt1h_z_p_br_contiguous" "{Z UInteger .H}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ldnt1h_z_p_bi_contiguous" "{Z UInteger .H}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldnt1h_z_p_ar_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ldnt1h_mz_p_br_2" "{Z UInteger .H- Z UInteger .H}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
  ("ldnt1h_mz_p_br_4" "{Z UInteger .H- Z UInteger .H}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
  ("ldnt1h_mz_p_bi_2" "{Z UInteger .H- Z UInteger .H}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
  ("ldnt1h_mz_p_bi_4" "{Z UInteger .H- Z UInteger .H}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
  ("ldnt1h_mzx_p_br_2x8" "{Z UInteger .H Z UInteger .H}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
  ("ldnt1h_mzx_p_br_4x4" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
  ("ldnt1h_mzx_p_bi_2x8" "{Z UInteger .H Z UInteger .H}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
  ("ldnt1h_mzx_p_bi_4x4" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
)

(whilehi
  ("whilehi_pn_rr_" "PNUInteger.B, XUInteger, XUInteger, VLx2" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("PNd" (reg-range 0 7))) ("PNd" "Xn__4" "Xm__6"))
  ("whilehi_pp_rr_" "{P UInteger . B P UInteger . B}, XUInteger, XUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 7))) ("Pd1__2" "Pd2__2" "Xn__4" "Xm__6"))
  ("whilehi_p_p_rr_" "PUInteger.B, WZR, WZR" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd"))
)

(fcmpe
  ("FCMPE_S_floatcmp" "SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Sn__3" "Sm"))
  ("FCMPE_SZ_floatcmp" "SUInteger, 0.0" (("Rn" (reg-range 0 31))) ("Sn"))
  ("FCMPE_D_floatcmp" "DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Dn__2" "Dm"))
  ("FCMPE_DZ_floatcmp" "DUInteger, 0.0" (("Rn" (reg-range 0 31))) ("Dn"))
  ("FCMPE_H_floatcmp" "HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Hn" "Hm"))
  ("FCMPE_HZ_floatcmp" "HUInteger, 0.0" (("Rn" (reg-range 0 31))) ("Hn__2"))
)

(rdffr
  ("rdffr_p_p_f_" "PUInteger.B, PUInteger/Z" (("Pg" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2"))
  ("rdffr_p_f_" "PUInteger.B" (("Pd" (reg-range 0 15))) ("Pd"))
)

(sturh
  ("STURH_32_ldst_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
)

(ldnf1sb
  ("ldnf1sb_z_p_bi_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldnf1sb_z_p_bi_s32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldnf1sb_z_p_bi_s16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
)

(brkn
  ("brkn_p_p_pp_" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pdm" (reg-range 0 15))) ("Pdm" "Pg__2" "Pn__2" "Pdm"))
)

(subg
  ("SUBG_64_addsub_immtags" "SP, SP, UInteger, UInteger" (("imm6" (imm-range 0 63 1)) ("imm4" (imm-range 0 15 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option" "XnSP_option__3"))
)

(ushllt
  ("ushllt_z_zi_" "ZUInteger.H, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(stnp
  ("STNP_32_ldstnapair_offs" "WZR, WZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option" "imm7_option"))
  ("STNP_S_ldstnapair_offs" "SUInteger, SUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St1" "St2" "XnSP_option" "imm7_option"))
  ("STNP_D_ldstnapair_offs" "DUInteger, DUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt1" "Dt2" "XnSP_option" "imm7_option__2"))
  ("STNP_64_ldstnapair_offs" "XZR, XZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm7_option__2"))
  ("STNP_Q_ldstnapair_offs" "QUInteger, QUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm7_option__3"))
)

(smlslt
  ("smlslt_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("smlslt_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
  ("smlslt_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
)

(cbheq
  ("CBHEQ_16_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
)

(ursra
  ("ursra_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2"))
  ("URSRA_asisdshf_R" "DUInteger, DUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("URSRA_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__4"))
)

(fclamp
  ("fclamp_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("fclamp_mz_zz_2" "{Z UInteger . H - Z UInteger . H}, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn__2" "Zm"))
  ("fclamp_mz_zz_4" "{Z UInteger . H - Z UInteger . H}, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn__2" "Zm"))
)

(seten
  ("SETEN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__3" "XnOrXZR__7" "XsOrXZR__7"))
)

(umov
  ("UMOV_asimdins_W_w" "WZR, VUInteger.B[UInteger]" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Vn" "imm5_index__3"))
  ("UMOV_asimdins_X_x" "XZR, VUInteger.D[UInteger" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Vn"))
)

(pacibsppc
  ("PACIBSPPC_64LR_dp_1src" "" () ())
)

(stlxrb
  ("STLXRB_SR32_ldstexclr" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "WtOrWZR__4" "XnSP_option"))
)

(frinta
  ("frinta_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("frinta_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("frinta_mz_z_2" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__4" "Zn2__3"))
  ("frinta_mz_z_4" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
  ("FRINTA_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FRINTA_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FRINTA_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
  ("FRINTA_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
  ("FRINTA_H_floatdp1" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
)

(sbfm
  ("SBFM_32M_bitfield" "WZR, WZR, UInteger, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR" "immr" "imms"))
  ("SBFM_64M_bitfield" "XZR, XZR, UInteger, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11" "immr__2" "imms__2"))
)

(fcmp
  ("FCMP_S_floatcmp" "SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Sn__3" "Sm"))
  ("FCMP_SZ_floatcmp" "SUInteger, 0.0" (("Rn" (reg-range 0 31))) ("Sn"))
  ("FCMP_D_floatcmp" "DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Dn__2" "Dm"))
  ("FCMP_DZ_floatcmp" "DUInteger, 0.0" (("Rn" (reg-range 0 31))) ("Dn"))
  ("FCMP_H_floatcmp" "HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Hn" "Hm"))
  ("FCMP_HZ_floatcmp" "HUInteger, 0.0" (("Rn" (reg-range 0 31))) ("Hn__2"))
)

(rcwsswp
  ("RCWSSWP_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(umin
  ("umin_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("umin_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__37"))
  ("umin_mz_zzv_2x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
  ("umin_mz_zzv_4x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
  ("umin_mz_zzw_2x2" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
  ("umin_mz_zzw_4x4" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
  ("UMIN_32U_minmax_imm" "WZR, WZR, UInteger" (("imm8" (imm-range 0 255 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
  ("UMIN_64U_minmax_imm" "XZR, XZR, UInteger" (("imm8" (imm-range 0 255 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
  ("UMIN_32_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("UMIN_64_dp_2src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
  ("UMIN_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(clz
  ("clz_z_p_z_m" "ZUInteger.B, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("clz_z_p_z_z" "ZUInteger.B, PUInteger/Z, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("CLZ_32_dp_1src" "WZR, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
  ("CLZ_64_dp_1src" "XZR, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
  ("CLZ_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(ldtrsb
  ("LDTRSB_64_ldst_unpriv" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
  ("LDTRSB_32_ldst_unpriv" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
)

(cadd
  ("cadd_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B, 90" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm"))
)

(uqcvt
  ("uqcvt_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("uqcvt_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
)

(rsubhn
  ("RSUBHN_asimddiff_N" "VUInteger.8B, VUInteger.8H, VUInteger.8H" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(uunpkhi
  ("uunpkhi_z_z_" "ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(ldbfmaxl
  ("LDBFMAXL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(fcvtxnt
  ("fcvtxnt_z_p_z_d2sz" "ZUInteger.S, PUInteger/Z, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvtxnt_z_p_z_d2s" "ZUInteger.S, PUInteger/M, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
)

(setpt
  ("SETPT_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XnOrXZR__5" "XsOrXZR__7"))
)

(bf1cvtl
  ("bf1cvtl_mz2_z8_" "{Z UInteger .H- Z UInteger .H}, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
  ("BF1CVTL_asimdmisc_V" "VUInteger.8H, VUInteger.8B" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(ldsminl
  ("LDSMINL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDSMINL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(sturb
  ("STURB_32_ldst_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
)

(fadda
  ("fadda_v_p_z_" "HUInteger, PUInteger, HUInteger, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31))) ("V__4" "Pg" "V__4" "Zm__5"))
)

(ptrue
  ("ptrue_p_s_" "PUInteger.B" (("size" (element-size B H S D)) ("Pd" (reg-range 0 15))) ("Pd"))
  ("ptrue_pn_i_" "PNUInteger.B" (("size" (element-size B H S D)) ("PNd" (reg-range 0 7))) ("PNd"))
)

(whilege
  ("whilege_pn_rr_" "PNUInteger.B, XUInteger, XUInteger, VLx2" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("PNd" (reg-range 0 7))) ("PNd" "Xn__4" "Xm__6"))
  ("whilege_pp_rr_" "{P UInteger . B P UInteger . B}, XUInteger, XUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 7))) ("Pd1__2" "Pd2__2" "Xn__4" "Xm__6"))
  ("whilege_p_p_rr_" "PUInteger.B, WZR, WZR" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd"))
)

(bl
  ("BL_only_branch_imm" "SInteger" (("imm26" (imm-range 0 67108863 1))) ("imm26_offset"))
)

(cpyfmrtrn
  ("CPYFMRTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(uqshrnt
  ("uqshrnt_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(umaxqv
  ("umaxqv_z_p_z_" "VUInteger.16B, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
)

(uqshl
  ("uqshl_z_p_zi_" "ZUInteger.B, PUInteger/M, ZUInteger.B, UInteger" (("Pg" (reg-range 0 7)) ("imm3" (imm-range 0 7 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
  ("uqshl_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("UQSHL_asisdsame_only" "BUInteger, BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7" "V_option__7"))
  ("UQSHL_asisdshf_R" "BUInteger, BUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__5" "V_option__5" "immh_shift"))
  ("UQSHL_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("UQSHL_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__5"))
)

(ldnt1b
  ("ldnt1b_z_p_ar_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ldnt1b_z_p_br_contiguous" "{Z UInteger .B}, PUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ldnt1b_z_p_bi_contiguous" "{Z UInteger .B}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldnt1b_z_p_ar_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ldnt1b_mz_p_br_2" "{Z UInteger .B- Z UInteger .B}, PNUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
  ("ldnt1b_mz_p_br_4" "{Z UInteger .B- Z UInteger .B}, PNUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
  ("ldnt1b_mz_p_bi_2" "{Z UInteger .B- Z UInteger .B}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
  ("ldnt1b_mz_p_bi_4" "{Z UInteger .B- Z UInteger .B}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
  ("ldnt1b_mzx_p_br_2x8" "{Z UInteger .B Z UInteger .B}, PNUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
  ("ldnt1b_mzx_p_br_4x4" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PNUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
  ("ldnt1b_mzx_p_bi_2x8" "{Z UInteger .B Z UInteger .B}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
  ("ldnt1b_mzx_p_bi_4x4" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
)

(madd
  ("MADD_32A_dp_3src" "WZR, WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__5" "WmOrWZR__6" "WaOrWZR"))
  ("MADD_64A_dp_3src" "XZR, XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__13" "XmOrXZR__9" "XaOrXZR"))
)

(ldclralb
  ("LDCLRALB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(usublt
  ("usublt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(ldnf1sh
  ("ldnf1sh_z_p_bi_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldnf1sh_z_p_bi_s32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
)

(cpy
  ("cpy_z_o_i_" "ZUInteger.B, PUInteger/Z, SInteger" (("size" (element-size B H S D)) ("Pg" (reg-range 0 15)) ("imm8" (imm-range 0 255 1)) ("Zd" (reg-range 0 31))) ("Zd" "Pg__2" "imm__46"))
  ("cpy_z_p_i_" "ZUInteger.B, PUInteger/M, SInteger" (("size" (element-size B H S D)) ("Pg" (reg-range 0 15)) ("imm8" (imm-range 0 255 1)) ("Zd" (reg-range 0 31))) ("Zd" "Pg__2" "imm__46"))
  ("cpy_z_p_v_" "ZUInteger.B, PUInteger/M, BUInteger" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Vn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "V__3"))
  ("cpy_z_p_r_" "ZUInteger.B, PUInteger/M, WSP" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg"))
)

(ldfminl
  ("LDFMINL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMINL_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMINL_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(madpt
  ("madpt_z_zzz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Za" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zm" "Za"))
)

(dupm
  ("dupm_z_i_" "ZUInteger.B, UInteger" (("imm13" (imm-range 0 8191 1)) ("Zd" (reg-range 0 31))) ("Zd"))
)

(pacdzb
  ("PACDZB_64Z_dp_1src" "XZR" (("Rd" (reg-range 0 31))) ("XdOrXZR__6"))
)

(ldaddal
  ("LDADDAL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDADDAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(ldsmax
  ("LDSMAX_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDSMAX_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(rcwclrpa
  ("RCWCLRPA_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(stz2g
  ("STZ2G_64Spost_ldsttags" "SP, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option"))
  ("STZ2G_64Soffset_ldsttags" "SP, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option" "imm9_option__2"))
  ("STZ2G_64Spre_ldsttags" "SP, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option"))
)

(ldadd
  ("LDADD_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDADD_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(smaxp
  ("smaxp_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("SMAXP_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(cpyfpwtn
  ("CPYFPWTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(ldbfminnm
  ("LDBFMINNM_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(ldsmaxal
  ("LDSMAXAL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDSMAXAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(nand
  ("nand_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
)

(sqrdmlah
  ("sqrdmlah_z_zzz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("sqrdmlah_z_zzzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
  ("sqrdmlah_z_zzzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__41"))
  ("sqrdmlah_z_zzzi_d" "ZUInteger.D, ZUInteger.D, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__42"))
  ("SQRDMLAH_asisdsame2_only" "HUInteger, HUInteger, HUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__8" "V_option__8" "V_option__8"))
  ("SQRDMLAH_asisdelem_R" "HUInteger, HUInteger, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__8" "V_option__8" "Vm__5"))
  ("SQRDMLAH_asimdsame2_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("SQRDMLAH_asimdelem_R" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
)

(movprfx
  ("movprfx_z_p_z_" "ZUInteger.B, PUInteger/Z, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "ZM" "Zn"))
  ("movprfx_z_z_" "ZUInteger, ZUInteger" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(fvdot
  ("fvdot_za_zzi_2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("fvdot_za_z8z8i_2xi" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
)

(bf2cvt
  ("bf2cvt_z_z8_b2bf" "ZUInteger.H, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
  ("bf2cvt_mz2_z8_" "{Z UInteger .H- Z UInteger .H}, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
)

(uminv
  ("uminv_r_p_z_" "BUInteger, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V" "Pg" "Zn"))
  ("UMINV_asimdall_only" "BUInteger, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__2" "Vn"))
)

(ldfmaxa
  ("LDFMAXA_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMAXA_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMAXA_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(rcwssetpa
  ("RCWSSETPA_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(decw
  ("decw_z_zs_" "ZUInteger.S" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
  ("decw_r_rs_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(ldnt1d
  ("ldnt1d_z_p_br_contiguous" "{Z UInteger .D}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ldnt1d_z_p_bi_contiguous" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldnt1d_z_p_ar_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ldnt1d_mz_p_br_2" "{Z UInteger .D- Z UInteger .D}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
  ("ldnt1d_mz_p_br_4" "{Z UInteger .D- Z UInteger .D}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
  ("ldnt1d_mz_p_bi_2" "{Z UInteger .D- Z UInteger .D}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
  ("ldnt1d_mz_p_bi_4" "{Z UInteger .D- Z UInteger .D}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
  ("ldnt1d_mzx_p_br_2x8" "{Z UInteger .D Z UInteger .D}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
  ("ldnt1d_mzx_p_br_4x4" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
  ("ldnt1d_mzx_p_bi_2x8" "{Z UInteger .D Z UInteger .D}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
  ("ldnt1d_mzx_p_bi_4x4" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
)

(sha512h
  ("SHA512H_QQV_cryptosha512_3" "QUInteger, QUInteger, VUInteger.2D" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Qd__2" "Qn" "Vm__7"))
)

(ldclrp
  ("LDCLRP_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(sqshrn
  ("sqshrn_z_mz2_" "ZUInteger.B, {Z UInteger . H - Z UInteger . H}, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("SQSHRN_asisdshf_N" "BUInteger, HUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vb_option" "Va_option" "immh_shift__2"))
  ("SQSHRN_asimdshf_N" "VUInteger.8B, VUInteger.8H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__6"))
)

(smop4s
  ("smop4s_za_zz_b1x1" "ZAUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
  ("smop4s_za_zz_b1x2" "ZAUInteger.S, ZUInteger.B, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("smop4s_za_zz_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("smop4s_za_zz_b2x2" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("smop4s_za32_zz_h1x1" "ZAUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
  ("smop4s_za32_zz_h1x2" "ZAUInteger.S, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("smop4s_za32_zz_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("smop4s_za32_zz_h2x2" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("smop4s_za_zz_h1x1" "ZAUInteger.D, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm_mortlach"))
  ("smop4s_za_zz_h1x2" "ZAUInteger.D, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("smop4s_za_zz_h2x1" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("smop4s_za_zz_h2x2" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
)

(frinti
  ("frinti_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("frinti_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("FRINTI_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FRINTI_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FRINTI_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
  ("FRINTI_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
  ("FRINTI_H_floatdp1" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
)

(ldxrb
  ("LDXRB_LR32_ldstexclr" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
)

(ld4w
  ("ld4w_z_p_br_contiguous" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3" "Xm__4"))
  ("ld4w_z_p_bi_contiguous" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3"))
)

(cpyfptrn
  ("CPYFPTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(ld64b
  ("LD64B_64L_memop" "XZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__9" "XnSP_option"))
)

(mlapt
  ("mlapt_z_zzz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
)

(ldfminnmal
  ("LDFMINNMAL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMINNMAL_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMINNMAL_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(setgptn
  ("SETGPTN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__4" "XnOrXZR__8" "XsOrXZR__8"))
)

(subhnb
  ("subhnb_z_zz_" "ZUInteger.B, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(chkfeat
  ("CHKFEAT_HF_hints" "X16" () ())
)

(sqrshrunt
  ("sqrshrunt_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(usmopa
  ("usmopa_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
  ("usmopa_za_pp_zz_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn__2" "Zm"))
)

(rshrnb
  ("rshrnb_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(addhnt
  ("addhnt_z_zz_" "ZUInteger.B, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(andqv
  ("andqv_z_p_z_" "VUInteger.16B, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
)

(fcvtms
  ("FCVTMS_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
  ("FCVTMS_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("FCVTMS_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCVTMS_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCVTMS_32S_float2int" "WZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
  ("FCVTMS_32D_float2int" "WZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
  ("FCVTMS_32H_float2int" "WZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
  ("FCVTMS_64S_float2int" "XZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
  ("FCVTMS_64D_float2int" "XZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
  ("FCVTMS_64H_float2int" "XZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
  ("FCVTMS_sisd_32D" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
  ("FCVTMS_sisd_32H" "SUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Hn__2"))
  ("FCVTMS_sisd_64H" "DUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Hn__2"))
  ("FCVTMS_sisd_64S" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
)

(ldfminnm
  ("LDFMINNM_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMINNM_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMINNM_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(rcwcaspal
  ("RCWCASPAL_C64_rcwcomswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
)

(usmop4s
  ("usmop4s_za_zz_b1x1" "ZAUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
  ("usmop4s_za_zz_b1x2" "ZAUInteger.S, ZUInteger.B, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("usmop4s_za_zz_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("usmop4s_za_zz_b2x2" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("usmop4s_za_zz_h1x1" "ZAUInteger.D, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm_mortlach"))
  ("usmop4s_za_zz_h1x2" "ZAUInteger.D, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("usmop4s_za_zz_h2x1" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("usmop4s_za_zz_h2x2" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
)

(usmlall
  ("usmlall_za_zzi_s" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
  ("usmlall_za_zzi_s2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm__2"))
  ("usmlall_za_zzi_s4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm__2"))
  ("usmlall_za_zzv_s2x1" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger . B- Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn2" "Zm__2"))
  ("usmlall_za_zzv_s" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
  ("usmlall_za_zzv_s4x1" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger . B- Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn4" "Zm__2"))
  ("usmlall_za_zzw_s2x2" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger . B- Z UInteger . B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("usmlall_za_zzw_s4x4" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger . B- Z UInteger . B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
)

(cpyptwn
  ("CPYPTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(caspt
  ("CASPT_CP64_comswappr_unpriv" "XUInteger, XUInteger, XUInteger, XUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
)

(fmaxnmqv
  ("fmaxnmqv_z_p_z_" "VUInteger.8H, PUInteger, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
)

(ld1rd
  ("ld1rd_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
)

(addsubp
  ("addsubp_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(brkbs
  ("brkbs_p_p_p_z" "PUInteger.B, PUInteger/Z, PUInteger.B" (("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__3"))
)

(sha256su0
  ("SHA256SU0_VV_cryptosha2" "VUInteger.4S, VUInteger.4S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6"))
)

(lduminal
  ("LDUMINAL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDUMINAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(abs
  ("abs_z_p_z_m" "ZUInteger.B, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("abs_z_p_z_z" "ZUInteger.B, PUInteger/Z, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("ABS_32_dp_1src" "WZR, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
  ("ABS_64_dp_1src" "XZR, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
  ("ABS_asisdmisc_R" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("ABS_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(bmops
  ("bmops_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
)

(fmlsl2
  ("FMLSL2_asimdsame_F" "VUInteger.2S, VUInteger.2H, VUInteger.2H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMLSL2_asimdelem_LH" "VUInteger.2S, VUInteger.2H, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(rcwssetal
  ("RCWSSETAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(f2cvt
  ("f2cvt_z_z8_b2h" "ZUInteger.H, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
  ("f2cvt_mz2_z8_" "{Z UInteger .H- Z UInteger .H}, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
)

(sb
  ("SB_only_barriers" "" () ())
)

(ldtclra
  ("LDTCLRA_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDTCLRA_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(bfmlalb
  ("bfmlalb_z_zzzi_" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
  ("bfmlalb_z_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
)

(fcvt
  ("fcvt_z_p_z_s2hz" "ZUInteger.H, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvt_z_p_z_h2sz" "ZUInteger.S, PUInteger/Z, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvt_z_p_z_d2hz" "ZUInteger.H, PUInteger/Z, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvt_z_p_z_h2dz" "ZUInteger.D, PUInteger/Z, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvt_z_p_z_d2sz" "ZUInteger.S, PUInteger/Z, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvt_z_p_z_s2dz" "ZUInteger.D, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvt_z_p_z_s2h" "ZUInteger.H, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvt_z_p_z_h2s" "ZUInteger.S, PUInteger/M, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvt_z_p_z_d2h" "ZUInteger.H, PUInteger/M, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvt_z_p_z_h2d" "ZUInteger.D, PUInteger/M, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvt_z_p_z_d2s" "ZUInteger.S, PUInteger/M, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvt_z_p_z_s2d" "ZUInteger.D, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("fcvt_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("fcvt_z8_mz2_" "ZUInteger.B, {Z UInteger .H- Z UInteger .H}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("fcvt_mz2_z_" "{Z UInteger .S- Z UInteger .S}, ZUInteger.H" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
  ("fcvt_z8_mz4_" "ZUInteger.B, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
  ("FCVT_DS_floatdp1" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
  ("FCVT_HS_floatdp1" "HUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Sn"))
  ("FCVT_SD_floatdp1" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
  ("FCVT_HD_floatdp1" "HUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Dn"))
  ("FCVT_SH_floatdp1" "SUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Hn__2"))
  ("FCVT_DH_floatdp1" "DUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Hn__2"))
)

(smaxv
  ("smaxv_r_p_z_" "BUInteger, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V" "Pg" "Zn"))
  ("SMAXV_asimdall_only" "BUInteger, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__2" "Vn"))
)

(shrn
  ("SHRN_asimdshf_N" "VUInteger.8B, VUInteger.8H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__6"))
)

(cpyfe
  ("CPYFE_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(fmlalltb
  ("fmlalltb_z32_z8z8z8_" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("fmlalltb_z32_z8z8z8i_" "ZUInteger.S, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__56"))
  ("FMLALLTB_asimdsame2_G" "VUInteger.4S, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMLALLTB_asimdelem_J" "VUInteger.4S, VUInteger.16B, VUInteger.B[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__6"))
)

(uqshrn
  ("uqshrn_z_mz2_" "ZUInteger.B, {Z UInteger . H - Z UInteger . H}, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("UQSHRN_asisdshf_N" "BUInteger, HUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vb_option" "Va_option" "immh_shift__2"))
  ("UQSHRN_asimdshf_N" "VUInteger.8B, VUInteger.8H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__6"))
)

(br
  ("BR_64_branch_reg" "XZR" (("Rn" (reg-range 0 31))) ("XnOrXZR"))
)

(stgp
  ("STGP_64_ldstpair_post" "XZR, XZR, [SP], SInteger" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__13"))
  ("STGP_64_ldstpair_off" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
  ("STGP_64_ldstpair_pre" "XZR, XZR, [SP SInteger], !" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__13"))
)

(cpyfptn
  ("CPYFPTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(fcvtmu
  ("FCVTMU_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
  ("FCVTMU_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("FCVTMU_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCVTMU_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCVTMU_32S_float2int" "WZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
  ("FCVTMU_32D_float2int" "WZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
  ("FCVTMU_32H_float2int" "WZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
  ("FCVTMU_64S_float2int" "XZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
  ("FCVTMU_64D_float2int" "XZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
  ("FCVTMU_64H_float2int" "XZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
  ("FCVTMU_sisd_32D" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
  ("FCVTMU_sisd_32H" "SUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Hn__2"))
  ("FCVTMU_sisd_64H" "DUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Hn__2"))
  ("FCVTMU_sisd_64S" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
)

(autib1716
  ("AUTIB1716_HI_hints" "" () ())
)

(bfmmla
  ("bfmmla_z_zzz_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("bfmmla_z_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("BFMMLA_asimdsame2_E" "VUInteger.4S, VUInteger.8H, VUInteger.8H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "Vm"))
)

(ldumaxal
  ("LDUMAXAL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDUMAXAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(ld1rb
  ("ld1rb_z_p_bi_u8" "{Z UInteger .B}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1rb_z_p_bi_u16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1rb_z_p_bi_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1rb_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
)

(crc32cw
  ("CRC32CW_32C_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR__2" "WnOrWZR__4" "WmOrWZR__5"))
)

(sutmopa
  ("sutmopa_za_zzzi_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
)

(axflag
  ("AXFLAG_M_pstate" "" () ())
)

(ldsmin
  ("LDSMIN_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDSMIN_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(fminnm
  ("fminnm_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("fminnm_z_p_zs_" "ZUInteger.H, PUInteger/M, ZUInteger.H, 0.0" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
  ("fminnm_mz_zzv_2x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
  ("fminnm_mz_zzv_4x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
  ("fminnm_mz_zzw_2x2" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
  ("fminnm_mz_zzw_4x4" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
  ("FMINNM_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMINNM_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMINNM_S_floatdp2" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__3" "Sm"))
  ("FMINNM_D_floatdp2" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__2" "Dm"))
  ("FMINNM_H_floatdp2" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
)

(setpn
  ("SETPN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XnOrXZR__5" "XsOrXZR__7"))
)

(sqrshrnb
  ("sqrshrnb_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(ld1rh
  ("ld1rh_z_p_bi_u16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1rh_z_p_bi_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1rh_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
)

(fmls
  ("fmls_z_zzzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
  ("fmls_z_zzzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__55"))
  ("fmls_z_zzzi_d" "ZUInteger.D, ZUInteger.D, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__54"))
  ("fmls_z_p_zzz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Pg" "Zn__2" "Zm"))
  ("fmls_za_zzi_h2xi" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("fmls_za_zzi_s2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .S- Z UInteger .S}, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("fmls_za_zzi_d2xi" "ZA.D[WUInteger, UInteger, VGx2, {Z UInteger .D- Z UInteger .D}, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("fmls_za_zzi_h4xi" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
  ("fmls_za_zzi_s4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .S- Z UInteger .S}, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
  ("fmls_za_zzi_d4xi" "ZA.D[WUInteger, UInteger, VGx4, {Z UInteger .D- Z UInteger .D}, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
  ("fmls_za_zzv_2x1" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}, ZUInteger.S" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
  ("fmls_za_zzv_2x1_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
  ("fmls_za_zzv_4x1" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}, ZUInteger.S" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
  ("fmls_za_zzv_4x1_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
  ("fmls_za_zzw_2x2_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("fmls_za_zzw_2x2" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}, {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("fmls_za_zzw_4x4_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("fmls_za_zzw_4x4" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}, {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("FMLS_asisdelem_RH_H" "HUInteger, HUInteger, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Vm__2"))
  ("FMLS_asisdelem_R_SD" "SUInteger, SUInteger, VUInteger.S[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("FMLS_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMLS_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMLS_asimdelem_RH_H" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__2"))
  ("FMLS_asimdelem_R_SD" "VUInteger.2S, VUInteger.2S, VUInteger.S[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2"))
)

(cpyfewtn
  ("CPYFEWTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(brkpbs
  ("brkpbs_p_p_pp_" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
)

(stlrb
  ("STLRB_SL32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
)

(sqdmlal
  ("SQDMLAL_asisddiff_only" "SUInteger, HUInteger, HUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Va_option__2" "Vb_option__2" "Vb_option__2"))
  ("SQDMLAL_asisdelem_L" "SUInteger, HUInteger, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Va_option__2" "Vb_option__2" "Vm__5"))
  ("SQDMLAL_asimddiff_L" "VUInteger.4S, VUInteger.4H, VUInteger.4H" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("SQDMLAL_asimdelem_L" "VUInteger.4S, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
)

(uqdecd
  ("uqdecd_z_zs_" "ZUInteger.D" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
  ("uqdecd_r_rs_uw" "WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Wdn"))
  ("uqdecd_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(lduminalb
  ("LDUMINALB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(firstp
  ("firstp_r_p_p_" "XUInteger, PUInteger, PUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Rd" (reg-range 0 31))) ("Xd__2" "Pg__2" "Pn__3"))
)

(stfmin
  ("STFMIN_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
  ("STFMIN_32" "SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
  ("STFMIN_64" "DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
)

(stbfmax
  ("STBFMAX_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
)

(bfdot
  ("bfdot_z_zzzi_" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__35"))
  ("bfdot_z_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("bfdot_za_zzi_2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("bfdot_za_zzi_4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
  ("bfdot_za_zzv_2x1" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
  ("bfdot_za_zzv_4x1" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
  ("bfdot_za_zzw_2x2" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("bfdot_za_zzw_4x4" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("BFDOT_asimdsame2_D" "VUInteger.2S, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("BFDOT_asimdelem_E" "VUInteger.2S, VUInteger.4H, VUInteger.2H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "H_L__2"))
)

(sm4e
  ("sm4e_z_zz_" "ZUInteger.S, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm"))
  ("SM4E_VV4_cryptosha512_2" "VUInteger.4S, VUInteger.4S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6"))
)

(sxtb
  ("sxtb_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("sxtb_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
)

(umlslb
  ("umlslb_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("umlslb_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
  ("umlslb_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
)

(swpab
  ("SWPAB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
)

(mrs
  ("MRS_RS_systemmove" "XZR, ACTLR_EL3" (("Rt" (reg-range 0 31))) ("XtOrXZR__4"))
)

(stfminnm
  ("STFMINNM_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
  ("STFMINNM_32" "SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
  ("STFMINNM_64" "DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
)

(zero
  ("zero_za_i_" "{}" (("imm8" (imm-range 0 255 1))) ())
  ("zero_za1_ri_2" "ZA.D[WUInteger, UInteger, VGx2" (("off3" (imm-range 0 7 1))) ("Wv" "offs"))
  ("zero_za1_ri_4" "ZA.D[WUInteger, UInteger, VGx4" (("off3" (imm-range 0 7 1))) ("Wv" "offs"))
  ("zero_za2_ri_1" "ZA.D[WUInteger, UInteger:UInteger" (("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2"))
  ("zero_za2_ri_2" "ZA.D[WUInteger, UInteger:UInteger, VGx2]" (("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2"))
  ("zero_za2_ri_4" "ZA.D[WUInteger, UInteger:UInteger, VGx4]" (("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2"))
  ("zero_za4_ri_1" "ZA.D[WUInteger, UInteger:UInteger" (("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4"))
  ("zero_za4_ri_2" "ZA.D[WUInteger, UInteger:UInteger, VGx2]" () ("Wv" "offs1__4" "offs4__2"))
  ("zero_za4_ri_4" "ZA.D[WUInteger, UInteger:UInteger, VGx4]" () ("Wv" "offs1__4" "offs4__2"))
  ("zero_zt_i_" "{ZT0}" () ())
)

(fnmsb
  ("fnmsb_z_p_zzz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Za" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zm" "Za"))
)

(ldaddl
  ("LDADDL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDADDL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(bf1cvt
  ("bf1cvt_z_z8_b2bf" "ZUInteger.H, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
  ("bf1cvt_mz2_z8_" "{Z UInteger .H- Z UInteger .H}, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
)

(paciaz
  ("PACIAZ_HI_hints" "" () ())
)

(setgoe
  ("SETGOE_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__10"))
)

(eon
  ("EON_32_log_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("EON_64_log_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
)

(uqdecb
  ("uqdecb_r_rs_uw" "WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Wdn"))
  ("uqdecb_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
)

(ldfmaxal
  ("LDFMAXAL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMAXAL_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMAXAL_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(lduminah
  ("LDUMINAH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(rdsvl
  ("rdsvl_r_i_" "XUInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("Rd" (reg-range 0 31))) ("Xd__2" "imm__28"))
)

(eor3
  ("eor3_z_zzz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm" "Zk"))
  ("EOR3_VVV16_crypto4" "VUInteger.16B, VUInteger.16B, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm" "Va"))
)

(whilels
  ("whilels_pn_rr_" "PNUInteger.B, XUInteger, XUInteger, VLx2" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("PNd" (reg-range 0 7))) ("PNd" "Xn__4" "Xm__6"))
  ("whilels_pp_rr_" "{P UInteger . B P UInteger . B}, XUInteger, XUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 7))) ("Pd1__2" "Pd2__2" "Xn__4" "Xm__6"))
  ("whilels_p_p_rr_" "PUInteger.B, WZR, WZR" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd"))
)

(casa
  ("CASA_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
  ("CASA_C64_comswap" "XZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
)

(sqshrunb
  ("sqshrunb_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(ldsetpl
  ("LDSETPL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(ucvtflt
  ("ucvtflt_z_z_" "ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(cpyetn
  ("CPYETN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(stlxrh
  ("STLXRH_SR32_ldstexclr" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "WtOrWZR__4" "XnSP_option"))
)

(ldrh
  ("LDRH_32_ldst_immpost" "WZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("LDRH_32_ldst_immpre" "WZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("LDRH_32_ldst_regoff" "WZR, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "WorX_choice"))
  ("LDRH_32_ldst_pos" "WZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm12_option__4"))
)

(swpt
  ("SWPT_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
  ("SWPT_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(eorv
  ("eorv_r_p_z_" "BUInteger, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V" "Pg" "Zn"))
)

(uaddl
  ("UADDL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(rcwseta
  ("RCWSETA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(aesimc
  ("aesimc_z_z_" "ZUInteger.B, ZUInteger.B" (("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2"))
  ("AESIMC_B_cryptoaes" "VUInteger.16B, VUInteger.16B" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(lduminb
  ("LDUMINB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(ld1w
  ("ld1w_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1w_z_p_bz_s_x32_scaled" "{Z UInteger .S}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1w_z_p_ai_s" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ld1w_z_p_bi_u128" "{Z UInteger .Q}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1w_z_p_br_u32" "{Z UInteger .S}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1w_z_p_br_u64" "{Z UInteger .D}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1w_z_p_br_u128" "{Z UInteger .Q}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1w_z_p_bi_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1w_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ld1w_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1w_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1w_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ld1w_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1w_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
  ("ld1w_mz_p_br_2" "{Z UInteger .S- Z UInteger .S}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
  ("ld1w_mz_p_br_4" "{Z UInteger .S- Z UInteger .S}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
  ("ld1w_mz_p_bi_2" "{Z UInteger .S- Z UInteger .S}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
  ("ld1w_mz_p_bi_4" "{Z UInteger .S- Z UInteger .S}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
  ("ld1w_mzx_p_br_2x8" "{Z UInteger .S Z UInteger .S}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
  ("ld1w_mzx_p_br_4x4" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
  ("ld1w_mzx_p_bi_2x8" "{Z UInteger .S Z UInteger .S}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
  ("ld1w_mzx_p_bi_4x4" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
  ("ld1w_za_p_rrr_" "{ZA UInteger H .S [W UInteger UInteger]}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("ZAt__4" "HV" "Ws__3" "offs__6" "Pg" "XnSP__3"))
)

(csinc
  ("CSINC_32_condsel" "WZR, WZR, WZR, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("CSINC_64_condsel" "XZR, XZR, XZR, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
)

(addpt
  ("addpt_z_p_zz_" "ZUInteger.D, PUInteger/M, ZUInteger.D, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("addpt_z_zz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("ADDPT_64_addsub_pt" "SP, SP, XZR" (("Rm" (reg-range 0 31)) ("imm3" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option__3" "XnSP_option__5" "XmOrXZR__4" "imm3_option"))
)

(ssublt
  ("ssublt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(st4d
  ("st4d_z_p_br_contiguous" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3" "Xm__4"))
  ("st4d_z_p_bi_contiguous" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3"))
)

(umop4a
  ("umop4a_za_zz_b1x1" "ZAUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
  ("umop4a_za_zz_b1x2" "ZAUInteger.S, ZUInteger.B, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("umop4a_za_zz_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("umop4a_za_zz_b2x2" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("umop4a_za32_zz_h1x1" "ZAUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
  ("umop4a_za32_zz_h1x2" "ZAUInteger.S, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("umop4a_za32_zz_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("umop4a_za32_zz_h2x2" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("umop4a_za_zz_h1x1" "ZAUInteger.D, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm_mortlach"))
  ("umop4a_za_zz_h1x2" "ZAUInteger.D, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("umop4a_za_zz_h2x1" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("umop4a_za_zz_h2x2" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
)

(cpyern
  ("CPYERN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(stllrb
  ("STLLRB_SL32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
)

(ldnf1w
  ("ldnf1w_z_p_bi_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
  ("ldnf1w_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
)

(drps
  ("DRPS_64E_branch_reg" "" () ())
)

(rcwsclrp
  ("RCWSCLRP_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(gcsstr
  ("GCSSTR_64_ldst_gcs" "XZR, [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
)

(cpyfmn
  ("CPYFMN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(sqshrunt
  ("sqshrunt_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(rcwcasa
  ("RCWCASA_C64_rcwcomswap" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
)

(autdb
  ("AUTDB_64P_dp_1src" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__7"))
)

(sqadd
  ("sqadd_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("sqadd_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__27"))
  ("sqadd_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("SQADD_asisdsame_only" "BUInteger, BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7" "V_option__7"))
  ("SQADD_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(cpyfmwn
  ("CPYFMWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(sqrdmulh
  ("sqrdmulh_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("sqrdmulh_z_zzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__78"))
  ("sqrdmulh_z_zzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__41"))
  ("sqrdmulh_z_zzi_d" "ZUInteger.D, ZUInteger.D, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__2" "imm__42"))
  ("SQRDMULH_asisdsame_only" "HUInteger, HUInteger, HUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__8" "V_option__8" "V_option__8"))
  ("SQRDMULH_asisdelem_R" "HUInteger, HUInteger, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__8" "V_option__8" "Vm__5"))
  ("SQRDMULH_asimdsame_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("SQRDMULH_asimdelem_R" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
)

(cpyfmrtwn
  ("CPYFMRTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(smlslb
  ("smlslb_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("smlslb_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
  ("smlslb_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
)

(fnmls
  ("fnmls_z_p_zzz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Pg" "Zn__2" "Zm"))
)

(usmops
  ("usmops_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
  ("usmops_za_pp_zz_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn__2" "Zm"))
)

(subs
  ("SUBS_32S_addsub_imm" "WZR, WSP, UInteger" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnWSP_option" "imm__17"))
  ("SUBS_64S_addsub_imm" "XZR, SP, UInteger" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__3" "imm__17"))
  ("SUBS_32_addsub_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("SUBS_64_addsub_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
  ("SUBS_32S_addsub_ext" "WZR, WSP, WZR, UXTB, UInteger" (("Rm" (reg-range 0 31)) ("imm3" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnWSP_option__2" "WmOrWZR__2"))
  ("SUBS_64S_addsub_ext" "XZR, SP, WZR, UXTB, UInteger" (("Rm" (reg-range 0 31)) ("imm3" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__6"))
)

(retabsppc
  ("RETABSPPC_only_miscbranch" "SInteger" (("imm16" (imm-range 0 65535 1))) ("imm16_offset"))
)

(bfclamp
  ("bfclamp_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("bfclamp_mz_zz_2" "{Z UInteger .H- Z UInteger .H}, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn__2" "Zm"))
  ("bfclamp_mz_zz_4" "{Z UInteger .H- Z UInteger .H}, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn__2" "Zm"))
)

(ld1rob
  ("ld1rob_z_p_br_contiguous" "{Z UInteger .B}, PUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1rob_z_p_bi_u8" "{Z UInteger .B}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
)

(ld1rqw
  ("ld1rqw_z_p_br_contiguous" "{Z UInteger .S}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1rqw_z_p_bi_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
)

(ldbfmaxnma
  ("LDBFMAXNMA_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(pacdb
  ("PACDB_64P_dp_1src" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__7"))
)

(cpyfmwtn
  ("CPYFMWTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(setgom
  ("SETGOM_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__9"))
)

(ldfminal
  ("LDFMINAL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMINAL_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
  ("LDFMINAL_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(stxrh
  ("STXRH_SR32_ldstexclr" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "WtOrWZR__4" "XnSP_option"))
)

(ushl
  ("USHL_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("USHL_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(ldseth
  ("LDSETH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(cpyptrn
  ("CPYPTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(aesemc
  ("aesemc_mz_zzi_2x1" "{Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}, ZUInteger.Q[UInteger" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm"))
  ("aesemc_mz_zzi_4x1" "{Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}, ZUInteger.Q[UInteger" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm"))
)

(aese
  ("aese_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm"))
  ("aese_mz_zzi_2x1" "{Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}, ZUInteger.Q[UInteger" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm"))
  ("aese_mz_zzi_4x1" "{Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}, ZUInteger.Q[UInteger" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm"))
  ("AESE_B_cryptoaes" "VUInteger.16B, VUInteger.16B" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6"))
)

(ldsmaxb
  ("LDSMAXB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(cpyfprtwn
  ("CPYFPRTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(bfmls
  ("bfmls_z_zzzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
  ("bfmls_z_p_zzz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Pg" "Zn__2" "Zm"))
  ("bfmls_za_zzi_h2xi" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("bfmls_za_zzi_h4xi" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
  ("bfmls_za_zzv_2x1_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
  ("bfmls_za_zzv_4x1_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
  ("bfmls_za_zzw_2x2_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("bfmls_za_zzw_4x4_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
)

(uqdecp
  ("uqdecp_z_p_z_" "ZUInteger.H, PUInteger.H" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pm__3"))
  ("uqdecp_r_p_r_uw" "WUInteger, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Rdn" (reg-range 0 31))) ("Wdn" "Pm__3"))
  ("uqdecp_r_p_r_x" "XUInteger, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Rdn" (reg-range 0 31))) ("Xdn" "Pm__3"))
)

(frintm
  ("frintm_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("frintm_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("frintm_mz_z_2" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__4" "Zn2__3"))
  ("frintm_mz_z_4" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
  ("FRINTM_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FRINTM_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FRINTM_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
  ("FRINTM_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
  ("FRINTM_H_floatdp1" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
)

(ldtsetl
  ("LDTSETL_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDTSETL_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(ldbfmaxnmal
  ("LDBFMAXNMAL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(fcpy
  ("fcpy_z_p_i_" "ZUInteger.H, PUInteger/M, Real" (("size" (element-size B H S D)) ("Pg" (reg-range 0 15)) ("imm8" (imm-range 0 255 1)) ("Zd" (reg-range 0 31))) ("Zd" "Pg__2"))
)

(cbnz
  ("CBNZ_32_compbranch" "WZR, SInteger" (("imm19" (imm-range 0 524287 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "imm19_offset"))
  ("CBNZ_64_compbranch" "XZR, SInteger" (("imm19" (imm-range 0 524287 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "imm19_offset"))
)

(rsubhnt
  ("rsubhnt_z_zz_" "ZUInteger.B, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(stlrh
  ("STLRH_SL32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
)

(stfadd
  ("STFADD_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
  ("STFADD_32" "SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
  ("STFADD_64" "DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
)

(smaddl
  ("SMADDL_64WA_dp_3src" "XZR, WZR, WZR, XZR" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "WnOrWZR__5" "WmOrWZR__6" "XaOrXZR"))
)

(sqxtunt
  ("sqxtunt_z_zz_" "ZUInteger.B, ZUInteger.H" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(stbfmaxl
  ("STBFMAXL_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
)

(ursqrte
  ("ursqrte_z_p_z_m" "ZUInteger.S, PUInteger/M, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("ursqrte_z_p_z_z" "ZUInteger.S, PUInteger/Z, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("URSQRTE_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(ld1q
  ("ld1q_z_p_ar_d_64_unscaled" "{Z UInteger .Q}, PUInteger/Z, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
  ("ld1q_za_p_rrr_" "{ZA UInteger H .Q [W UInteger 0]}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("ZAt__3" "HV" "Ws__3" "offs__5" "Pg" "XnSP__3"))
)

(ld4
  ("LD4_asisdlse_R4" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
  ("LD4_asisdlsep_R4_r" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
  ("LD4_asisdlsep_I4_i" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], 32" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "imm_option"))
  ("LD4_asisdlso_B4_4b" "{V UInteger . B V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
  ("LD4_asisdlso_H4_4h" "{V UInteger . H V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
  ("LD4_asisdlso_S4_4s" "{V UInteger . S V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
  ("LD4_asisdlso_D4_4d" "{V UInteger . D V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
  ("LD4_asisdlsop_BX4_r4b" "{V UInteger . B V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
  ("LD4_asisdlsop_HX4_r4h" "{V UInteger . H V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
  ("LD4_asisdlsop_SX4_r4s" "{V UInteger . S V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
  ("LD4_asisdlsop_DX4_r4d" "{V UInteger . D V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
  ("LD4_asisdlsop_B4_i4b" "{V UInteger . B V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP], 4" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
  ("LD4_asisdlsop_H4_i4h" "{V UInteger . H V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP], 8" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
  ("LD4_asisdlsop_S4_i4s" "{V UInteger . S V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP], 16" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
  ("LD4_asisdlsop_D4_i4d" "{V UInteger . D V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP], 32" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
)

(ldbfminl
  ("LDBFMINL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(ld1rod
  ("ld1rod_z_p_br_contiguous" "{Z UInteger .D}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
  ("ld1rod_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
)

(ldeor
  ("LDEOR_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDEOR_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(st4h
  ("st4h_z_p_br_contiguous" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3" "Xm__4"))
  ("st4h_z_p_bi_contiguous" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3"))
)

(cmpge
  ("cmpge_p_p_zz_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
  ("cmpge_p_p_zw_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
  ("cmpge_p_p_zi_" "PUInteger.B, PUInteger/Z, ZUInteger.B, SInteger" (("size" (element-size B H S D)) ("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn" "imm__43"))
)

(rcwswppa
  ("RCWSWPPA_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(saddlbt
  ("saddlbt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(pacizb
  ("PACIZB_64Z_dp_1src" "XZR" (("Rd" (reg-range 0 31))) ("XdOrXZR__6"))
)

(pmlal
  ("pmlal_mz_zzzw_1x2" "{Z UInteger .Q- Z UInteger .Q}, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 15))) ("Zda1" "Zda2" "Zn__2" "Zm"))
)

(swpp
  ("SWPP_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(bfmlslt
  ("bfmlslt_z_zzzi_" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
  ("bfmlslt_z_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
)

(brkpb
  ("brkpb_p_p_pp_" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
)

(cpyprtrn
  ("CPYPRTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(bic
  ("bic_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("bic_z_zz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("bic_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
  ("BIC_32_log_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("BIC_64_log_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
  ("BIC_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("BIC_asimdimm_L_sl" "VUInteger.2S, UInteger" (("Rd" (reg-range 0 31))) ("Vd__2"))
  ("BIC_asimdimm_L_hl" "VUInteger.4H, UInteger" (("Rd" (reg-range 0 31))) ("Vd__2"))
)

(cpyfm
  ("CPYFM_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(ldtaddal
  ("LDTADDAL_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDTADDAL_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(svc
  ("SVC_EX_exception" "UInteger" (("imm16" (imm-range 0 65535 1))) ("imm"))
)

(sqxtun
  ("SQXTUN_asisdmisc_N" "BUInteger, HUInteger" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vb_option__3" "Va_option__3"))
  ("SQXTUN_asimdmisc_N" "VUInteger.8B, VUInteger.8H" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(ldbfaddl
  ("LDBFADDL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
)

(cpyfmt
  ("CPYFMT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(ldsetl
  ("LDSETL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDSETL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(sha512su1
  ("SHA512SU1_VVV2_cryptosha512_3" "VUInteger.2D, VUInteger.2D, VUInteger.2D" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6" "Vm__7"))
)

(casplt
  ("CASPLT_CP64_comswappr_unpriv" "XUInteger, XUInteger, XUInteger, XUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
)

(cpyfmwt
  ("CPYFMWT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(uzp
  ("uzp_mz_zz_2" "{Z UInteger . B - Z UInteger . B}, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn__2" "Zm"))
  ("uzp_mz_zz_2q" "{Z UInteger .Q- Z UInteger .Q}, ZUInteger.Q, ZUInteger.Q" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn__2" "Zm"))
  ("uzp_mz_z_4" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
  ("uzp_mz_z_4q" "{Z UInteger .Q- Z UInteger .Q}, {Z UInteger .Q- Z UInteger .Q}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
)

(bfmla
  ("bfmla_z_zzzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
  ("bfmla_z_p_zzz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Pg" "Zn__2" "Zm"))
  ("bfmla_za_zzi_h2xi" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("bfmla_za_zzi_h4xi" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
  ("bfmla_za_zzv_2x1_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
  ("bfmla_za_zzv_4x1_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
  ("bfmla_za_zzw_2x2_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("bfmla_za_zzw_4x4_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
)

(ld2
  ("LD2_asisdlse_R2" "{V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
  ("LD2_asisdlsep_R2_r" "{V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
  ("LD2_asisdlsep_I2_i" "{V UInteger . 8B V UInteger . 8B}, [SP], 16" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "imm_option__6"))
  ("LD2_asisdlso_B2_2b" "{V UInteger . B V UInteger . B}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
  ("LD2_asisdlso_H2_2h" "{V UInteger . H V UInteger . H}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
  ("LD2_asisdlso_S2_2s" "{V UInteger . S V UInteger . S}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
  ("LD2_asisdlso_D2_2d" "{V UInteger . D V UInteger . D}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
  ("LD2_asisdlsop_BX2_r2b" "{V UInteger . B V UInteger . B}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
  ("LD2_asisdlsop_HX2_r2h" "{V UInteger . H V UInteger . H}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
  ("LD2_asisdlsop_SX2_r2s" "{V UInteger . S V UInteger . S}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
  ("LD2_asisdlsop_DX2_r2d" "{V UInteger . D V UInteger . D}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
  ("LD2_asisdlsop_B2_i2b" "{V UInteger . B V UInteger . B}, [UInteger], [SP], 2" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
  ("LD2_asisdlsop_H2_i2h" "{V UInteger . H V UInteger . H}, [UInteger], [SP], 4" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
  ("LD2_asisdlsop_S2_i2s" "{V UInteger . S V UInteger . S}, [UInteger], [SP], 8" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
  ("LD2_asisdlsop_D2_i2d" "{V UInteger . D V UInteger . D}, [UInteger], [SP], 16" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
)

(ldsetalh
  ("LDSETALH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(ctz
  ("CTZ_32_dp_1src" "WZR, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
  ("CTZ_64_dp_1src" "XZR, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
)

(cpypwtn
  ("CPYPWTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(sys
  ("SYS_CR_systeminstrs" "UInteger, CUInteger, CUInteger, UInteger" (("Rt" (reg-range 0 31))) ())
)

(ushr
  ("USHR_asisdshf_R" "DUInteger, DUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("USHR_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__4"))
)

(lduminh
  ("LDUMINH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(cpyfetn
  ("CPYFETN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
)

(fexpa
  ("fexpa_z_z_" "ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(dcps2
  ("DCPS2_DC_exception" "" (("imm16" (imm-range 0 65535 1))) ())
)

(stllrh
  ("STLLRH_SL32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
)

(fcmlt
  ("fcmlt_p_p_z0_" "PUInteger.H, PUInteger/Z, ZUInteger.H, 0.0" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn"))
  ("FCMLT_asisdmiscfp16_FZ" "HUInteger, HUInteger, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
  ("FCMLT_asisdmisc_FZ" "SUInteger, SUInteger, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("FCMLT_asimdmiscfp16_FZ" "VUInteger.4H, VUInteger.4H, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("FCMLT_asimdmisc_FZ" "VUInteger.2S, VUInteger.2S, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(stfmax
  ("STFMAX_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
  ("STFMAX_32" "SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
  ("STFMAX_64" "DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
)

(cpypwn
  ("CPYPWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(eorbt
  ("eorbt_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(bti
  ("BTI_HB_hints" "" () ())
)

(rcwsetpal
  ("RCWSETPAL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(pmov
  ("pmov_p_zi_b" "PUInteger.B, ZUInteger" (("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Zn"))
  ("pmov_p_zi_h" "PUInteger.H, ZUInteger" (("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Zn"))
  ("pmov_p_zi_s" "PUInteger.S, ZUInteger" (("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Zn"))
  ("pmov_p_zi_d" "PUInteger.D, ZUInteger" (("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Zn"))
  ("pmov_z_pi_b" "ZUInteger, PUInteger.B" (("Pn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Pn__3"))
  ("pmov_z_pi_h" "ZUInteger, PUInteger.H" (("Pn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Pn__3"))
  ("pmov_z_pi_s" "ZUInteger, PUInteger.S" (("Pn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Pn__3"))
  ("pmov_z_pi_d" "ZUInteger, PUInteger.D" (("Pn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Pn__3"))
)

(rshrnt
  ("rshrnt_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(stilp
  ("STILP_32SE_ldiappstilp" "WZR, WZR, [SP -8], !" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option"))
  ("STILP_32S_ldiappstilp" "WZR, WZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option"))
  ("STILP_64SS_ldiappstilp" "XZR, XZR, [SP -16], !" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
  ("STILP_64S_ldiappstilp" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(wrffr
  ("wrffr_f_p_" "PUInteger.B" (("Pn" (reg-range 0 15))) ("Pn__3"))
)

(rcwsswppa
  ("RCWSSWPPA_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(casalb
  ("CASALB_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
)

(ldsmaxh
  ("LDSMAXH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(lsr
  ("lsr_z_p_zi_" "ZUInteger.B, PUInteger/M, ZUInteger.B, UInteger" (("Pg" (reg-range 0 7)) ("imm3" (imm-range 0 7 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
  ("lsr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("lsr_z_p_zw_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("lsr_z_zw_" "ZUInteger.B, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("lsr_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(ld3d
  ("ld3d_z_p_br_contiguous" "{Z UInteger .D Z UInteger .D Z UInteger .D}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3" "Xm__4"))
  ("ld3d_z_p_bi_contiguous" "{Z UInteger .D Z UInteger .D Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3"))
)

(lduminl
  ("LDUMINL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDUMINL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(uqrshlr
  ("uqrshlr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
)

(ldsetp
  ("LDSETP_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(umullt
  ("umullt_z_zzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__78"))
  ("umullt_z_zzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__2" "imm__88"))
  ("umullt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(ldumaxa
  ("LDUMAXA_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDUMAXA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(cmge
  ("CMGE_asisdmisc_Z" "DUInteger, DUInteger, 0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("CMGE_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("CMGE_asimdmisc_Z" "VUInteger.8B, VUInteger.8B, 0" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
  ("CMGE_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(ldtsetal
  ("LDTSETAL_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDTSETAL_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(brkb
  ("brkb_p_p_p_" "PUInteger.B, PUInteger/Z, PUInteger.B" (("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "ZM" "Pn__3"))
)

(fsubr
  ("fsubr_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("fsubr_z_p_zs_" "ZUInteger.H, PUInteger/M, ZUInteger.H, 0.5" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
)

(stxp
  ("STXP_SP32_ldstexclp" "WZR, WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "Wt1OrWZR" "Wt2OrWZR" "XnSP_option"))
  ("STXP_SP64_ldstexclp" "WZR, XZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(stlxp
  ("STLXP_SP32_ldstexclp" "WZR, WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "Wt1OrWZR" "Wt2OrWZR" "XnSP_option"))
  ("STLXP_SP64_ldstexclp" "WZR, XZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
)

(bf2cvtlt
  ("bf2cvtlt_z_z8_b2bf" "ZUInteger.H, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(pacm
  ("PACM_HI_hints" "" () ())
)

(ldsmaxah
  ("LDSMAXAH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(ptest
  ("ptest__p_p_" "PUInteger, PUInteger.B" (("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15))) ("Pg__2" "Pn__3"))
)

(svdot
  ("svdot_za32_zzi_2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
  ("svdot_za_zzi_s4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
  ("svdot_za_zzi_d4xi" "ZA.D[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
)

(rcwsclral
  ("RCWSCLRAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(sxth
  ("sxth_z_p_z_m" "ZUInteger.S, PUInteger/M, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("sxth_z_p_z_z" "ZUInteger.S, PUInteger/Z, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
)

(ld3b
  ("ld3b_z_p_br_contiguous" "{Z UInteger .B Z UInteger .B Z UInteger .B}, PUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3" "Xm__4"))
  ("ld3b_z_p_bi_contiguous" "{Z UInteger .B Z UInteger .B Z UInteger .B}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3"))
)

(fmulx
  ("fmulx_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("FMULX_asisdsamefp16_only" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
  ("FMULX_asisdsame_only" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9" "V_option__9"))
  ("FMULX_asisdelem_RH_H" "HUInteger, HUInteger, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Vm__2"))
  ("FMULX_asisdelem_R_SD" "SUInteger, SUInteger, VUInteger.S[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
  ("FMULX_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMULX_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMULX_asimdelem_RH_H" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__2"))
  ("FMULX_asimdelem_R_SD" "VUInteger.2S, VUInteger.2S, VUInteger.S[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2"))
)

(ldapur
  ("LDAPUR_32_ldapstl_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
  ("LDAPUR_64_ldapstl_unscaled" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
  ("LDAPUR_B_ldapstl_simd" "BUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option" "imm9_option"))
  ("LDAPUR_Q_ldapstl_simd" "QUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option" "imm9_option"))
  ("LDAPUR_H_ldapstl_simd" "HUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option" "imm9_option"))
  ("LDAPUR_S_ldapstl_simd" "SUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option" "imm9_option"))
  ("LDAPUR_D_ldapstl_simd" "DUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option" "imm9_option"))
)

(fmov
  ("FMOV_asimdimm_S_s" "VUInteger.2S, SInteger" (("Rd" (reg-range 0 31))) ("Vd"))
  ("FMOV_asimdimm_H_h" "VUInteger.4H, SInteger" (("Rd" (reg-range 0 31))) ("Vd"))
  ("FMOV_asimdimm_D2_d" "VUInteger.2D, SInteger" (("Rd" (reg-range 0 31))) ("Vd"))
  ("FMOV_32S_float2int" "WZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
  ("FMOV_S32_float2int" "SUInteger, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "WnOrWZR"))
  ("FMOV_32H_float2int" "WZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
  ("FMOV_H32_float2int" "HUInteger, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "WnOrWZR"))
  ("FMOV_64D_float2int" "XZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
  ("FMOV_D64_float2int" "DUInteger, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "XnOrXZR__11"))
  ("FMOV_64VX_float2int" "XZR, VUInteger.D[1]" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Vn"))
  ("FMOV_V64I_float2int" "VUInteger.D[1], XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "XnOrXZR__11"))
  ("FMOV_64H_float2int" "XZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
  ("FMOV_H64_float2int" "HUInteger, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "XnOrXZR__11"))
  ("FMOV_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
  ("FMOV_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
  ("FMOV_H_floatdp1" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
  ("FMOV_S_floatimm" "SUInteger, SInteger" (("imm8" (imm-range 0 255 1)) ("Rd" (reg-range 0 31))) ("Sd" "imm__20"))
  ("FMOV_D_floatimm" "DUInteger, SInteger" (("imm8" (imm-range 0 255 1)) ("Rd" (reg-range 0 31))) ("Dd" "imm__20"))
  ("FMOV_H_floatimm" "HUInteger, SInteger" (("imm8" (imm-range 0 255 1)) ("Rd" (reg-range 0 31))) ("Hd" "imm__20"))
)

(addva
  ("addva_za_pp_z_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.S" (("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn"))
  ("addva_za_pp_z_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.D" (("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn"))
)

(umops
  ("umops_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
  ("umops_za32_pp_zz_16" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
  ("umops_za_pp_zz_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn__2" "Zm"))
)

(usubwt
  ("usubwt_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
)

(addpl
  ("addpl_r_ri_" "SP, SP, SInteger" (("Rn" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rd" (reg-range 0 31))) ("XdSP__2" "XnSP__2" "imm__28"))
)

(retaa
  ("RETAA_64E_branch_reg" "" () ())
)

(ldrb
  ("LDRB_32_ldst_immpost" "WZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("LDRB_32_ldst_immpre" "WZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
  ("LDRB_32B_ldst_regoff" "WZR, [SP WZR UXTW]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "WorX_choice" "S_option"))
  ("LDRB_32BL_ldst_regoff" "WZR, [SP XZR]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "XmOrXZR__2"))
  ("LDRB_32_ldst_pos" "WZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm12_option"))
)

(uminp
  ("uminp_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("UMINP_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(sqrshrnt
  ("sqrshrnt_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(ushllb
  ("ushllb_z_zi_" "ZUInteger.H, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(bfcvtn
  ("bfcvtn_z8_mz2_bf2b" "ZUInteger.B, {Z UInteger .H- Z UInteger .H}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("bfcvtn_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
  ("BFCVTN_asimdmisc_4S" "VUInteger.4H, VUInteger.4S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(raddhn
  ("RADDHN_asimddiff_N" "VUInteger.8B, VUInteger.8H, VUInteger.8H" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(st64bv0
  ("ST64BV0_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__3" "XtOrXZR__9" "XnSP_option"))
)

(movn
  ("MOVN_32_movewide" "WZR, UInteger" (("imm16" (imm-range 0 65535 1)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "imm__18"))
  ("MOVN_64_movewide" "XZR, UInteger" (("imm16" (imm-range 0 65535 1)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "imm__18"))
)

(fminnmqv
  ("fminnmqv_z_p_z_" "VUInteger.8H, PUInteger, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
)

(ldumaxlh
  ("LDUMAXLH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(pfalse
  ("pfalse_p_" "PUInteger.B" (("Pd" (reg-range 0 15))) ("Pd"))
)

(ldaddb
  ("LDADDB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(add
  ("add_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("add_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("add_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__27"))
  ("add_za_zzv_2x1" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}, ZUInteger.S" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
  ("add_za_zzv_4x1" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}, ZUInteger.S" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
  ("add_za_zzw_2x2" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}, {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("add_za_zw_2x2" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1" "Zm2"))
  ("add_za_zzw_4x4" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}, {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
  ("add_za_zw_4x4" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1__2" "Zm4"))
  ("add_mz_zzv_2x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
  ("add_mz_zzv_4x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
  ("ADD_32_addsub_imm" "WSP, WSP, UInteger" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdWSP_option" "WnWSP_option" "imm__17"))
  ("ADD_64_addsub_imm" "SP, SP, UInteger" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option" "XnSP_option__3" "imm__17"))
  ("ADD_32_addsub_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
  ("ADD_64_addsub_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
  ("ADD_32_addsub_ext" "WSP, WSP, WZR" (("Rm" (reg-range 0 31)) ("imm3" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdWSP_option" "WnWSP_option__2" "WmOrWZR__2"))
  ("ADD_64_addsub_ext" "SP, SP, WZR, UXTB, UInteger" (("Rm" (reg-range 0 31)) ("imm3" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option" "XnSP_option__6"))
  ("ADD_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("ADD_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(fmlalltt
  ("fmlalltt_z32_z8z8z8_" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
  ("fmlalltt_z32_z8z8z8i_" "ZUInteger.S, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__56"))
  ("FMLALLTT_asimdsame2_G" "VUInteger.4S, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FMLALLTT_asimdelem_J" "VUInteger.4S, VUInteger.16B, VUInteger.B[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__6"))
)

(cpyp
  ("CPYP_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(setet
  ("SETET_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__3" "XnOrXZR__7" "XsOrXZR__7"))
)

(zip1
  ("zip1_z_zz_q" "ZUInteger.Q, ZUInteger.Q, ZUInteger.Q" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("zip1_p_pp_" "PUInteger.B, PUInteger.B, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pn__2" "Pm__2"))
  ("zip1_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("ZIP1_asimdperm_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(blraa
  ("BLRAA_64P_branch_reg" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rm" (reg-range 0 31))) ("XnOrXZR" "XmSP_option"))
)

(st4b
  ("st4b_z_p_br_contiguous" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3" "Xm__4"))
  ("st4b_z_p_bi_contiguous" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3"))
)

(revh
  ("revh_z_z_m" "ZUInteger.S, PUInteger/M, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
  ("revh_z_z_z" "ZUInteger.S, PUInteger/Z, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
)

(bfscale
  ("bfscale_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("bfscale_mz_zzv_2x1" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
  ("bfscale_mz_zzv_4x1" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
  ("bfscale_mz_zzw_2x2" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, {Z UInteger . H- Z UInteger . H}" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
  ("bfscale_mz_zzw_4x4" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, {Z UInteger . H- Z UInteger . H}" (("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
)

(ldsmaxab
  ("LDSMAXAB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(sunpkhi
  ("sunpkhi_z_z_" "ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(smlsll
  ("smlsll_za_zzi_s" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
  ("smlsll_za_zzi_d" "ZA.D[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
  ("smlsll_za_zzi_s2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm__2"))
  ("smlsll_za_zzi_d2xi" "ZA.D[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm__2"))
  ("smlsll_za_zzi_s4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm__2"))
  ("smlsll_za_zzi_d4xi" "ZA.D[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm__2"))
  ("smlsll_za_zzv_2x1" "ZA.S, [W UInteger UInteger : UInteger VGx2], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn2" "Zm__2"))
  ("smlsll_za_zzv_1" "ZA.S, [W UInteger UInteger : UInteger], ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
  ("smlsll_za_zzv_4x1" "ZA.S, [W UInteger UInteger : UInteger VGx4], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn4" "Zm__2"))
  ("smlsll_za_zzw_2x2" "ZA.S, [W UInteger UInteger : UInteger VGx2], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
  ("smlsll_za_zzw_4x4" "ZA.S, [W UInteger UInteger : UInteger VGx4], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
)

(stltxr
  ("STLTXR_SR32_ldstexclr_unpriv" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "WtOrWZR__4" "XnSP_option"))
  ("STLTXR_SR64_ldstexclr_unpriv" "WZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "XtOrXZR__11" "XnSP_option"))
)

(sqrshrunb
  ("sqrshrunb_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
)

(bmopa
  ("bmopa_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
)

(ldsmaxl
  ("LDSMAXL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
  ("LDSMAXL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
)

(famax
  ("famax_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("famax_mz_zzw_2x2" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
  ("famax_mz_zzw_4x4" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
  ("FAMAX_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FAMAX_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(cmhs
  ("CMHS_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("CMHS_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(stxr
  ("STXR_SR32_ldstexclr" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "WtOrWZR__4" "XnSP_option"))
  ("STXR_SR64_ldstexclr" "WZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "XtOrXZR__11" "XnSP_option"))
)

(setgoetn
  ("SETGOETN_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__10"))
)

(swp
  ("SWP_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
  ("SWP_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
)

(stlxr
  ("STLXR_SR32_ldstexclr" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "WtOrWZR__4" "XnSP_option"))
  ("STLXR_SR64_ldstexclr" "WZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "XtOrXZR__11" "XnSP_option"))
)

(uclamp
  ("uclamp_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("uclamp_mz_zz_2" "{Z UInteger . B - Z UInteger . B}, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn__2" "Zm"))
  ("uclamp_mz_zz_4" "{Z UInteger . B - Z UInteger . B}, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn__2" "Zm"))
)

(smopa
  ("smopa_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
  ("smopa_za32_pp_zz_16" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
  ("smopa_za_pp_zz_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn__2" "Zm"))
)

(autdzb
  ("AUTDZB_64Z_dp_1src" "XZR" (("Rd" (reg-range 0 31))) ("XdOrXZR__6"))
)

(sha256h2
  ("SHA256H2_QQV_cryptosha3" "QUInteger, QUInteger, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Qd" "Qn" "Vm__7"))
)

(uzp1
  ("uzp1_z_zz_q" "ZUInteger.Q, ZUInteger.Q, ZUInteger.Q" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("uzp1_p_pp_" "PUInteger.B, PUInteger.B, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pn__2" "Pm__2"))
  ("uzp1_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
  ("UZP1_asimdperm_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(cpypwt
  ("CPYPWT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
)

(fabd
  ("fabd_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
  ("FABD_asisdsamefp16_only" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
  ("FABD_asisdsame_only" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9" "V_option__9"))
  ("FABD_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
  ("FABD_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
)

(cmlt
  ("CMLT_asisdmisc_Z" "DUInteger, DUInteger, 0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
  ("CMLT_asimdmisc_Z" "VUInteger.8B, VUInteger.8B, 0" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(cpyfmtwn
  ("CPYFMTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
)

(ldsetalb
  ("LDSETALB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
)

(smop4a
  ("smop4a_za_zz_b1x1" "ZAUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
  ("smop4a_za_zz_b1x2" "ZAUInteger.S, ZUInteger.B, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("smop4a_za_zz_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("smop4a_za_zz_b2x2" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("smop4a_za32_zz_h1x1" "ZAUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
  ("smop4a_za32_zz_h1x2" "ZAUInteger.S, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("smop4a_za32_zz_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("smop4a_za32_zz_h2x2" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("smop4a_za_zz_h1x1" "ZAUInteger.D, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm_mortlach"))
  ("smop4a_za_zz_h1x2" "ZAUInteger.D, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
  ("smop4a_za_zz_h2x1" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
  ("smop4a_za_zz_h2x2" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
)

(uunpk
  ("uunpk_mz_z_2" "{Z UInteger . H - Z UInteger . H}, ZUInteger.B" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
  ("uunpk_mz_z_4" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__4" "Zn2__3"))
)

(aesmc
  ("aesmc_z_z_" "ZUInteger.B, ZUInteger.B" (("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2"))
  ("AESMC_B_cryptoaes" "VUInteger.16B, VUInteger.16B" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
)

(casalh
  ("CASALH_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
)

