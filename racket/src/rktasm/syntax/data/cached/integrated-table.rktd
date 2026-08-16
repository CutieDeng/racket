;; 整合表: mnemonic -> layer1 -> layer2 -> encodings
;; 生成命令: racket syntax/gen-cached.rkt

(stp
  (c2m1
    ((gpr-64 gpr-64 memory immediate)
      ("STP_64_ldstpair_post" "XZR, XZR, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__15"))
    )
    ((gpr-64 gpr-64 memory pre-index)
      ("STP_64_ldstpair_pre" "XZR, XZR, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__15"))
    )
    ((gpr-32 gpr-32 memory pre-index)
      ("STP_32_ldstpair_pre" "WZR, WZR, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option" "imm__12"))
    )
    ((gpr-32 gpr-32 memory immediate)
      ("STP_32_ldstpair_post" "WZR, WZR, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option" "imm__12"))
    )
    ((simd-scalar simd-scalar memory immediate)
      ("STP_S_ldstpair_post" "SUInteger, SUInteger, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St1" "St2" "XnSP_option" "imm__12"))
      ("STP_D_ldstpair_post" "DUInteger, DUInteger, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt1" "Dt2" "XnSP_option" "imm__15"))
      ("STP_Q_ldstpair_post" "QUInteger, QUInteger, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm__16"))
    )
    ((simd-scalar simd-scalar memory pre-index)
      ("STP_S_ldstpair_pre" "SUInteger, SUInteger, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St1" "St2" "XnSP_option" "imm__12"))
      ("STP_D_ldstpair_pre" "DUInteger, DUInteger, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt1" "Dt2" "XnSP_option" "imm__15"))
      ("STP_Q_ldstpair_pre" "QUInteger, QUInteger, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm__16"))
    )
  )
  (c2m
    ((simd-scalar simd-scalar memory)
      ("STP_S_ldstpair_off" "SUInteger, SUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St1" "St2" "XnSP_option" "imm7_option"))
      ("STP_D_ldstpair_off" "DUInteger, DUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt1" "Dt2" "XnSP_option" "imm7_option__2"))
      ("STP_Q_ldstpair_off" "QUInteger, QUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm7_option__3"))
    )
    ((gpr-64 gpr-64 memory)
      ("STP_64_ldstpair_off" "XZR, XZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm7_option__2"))
    )
    ((gpr-32 gpr-32 memory)
      ("STP_32_ldstpair_off" "WZR, WZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option" "imm7_option"))
    )
  )
)

(sunpklo
  (c2
    ((sve-z sve-z)
      ("sunpklo_z_z_" "ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(ldp
  (c2m1
    ((gpr-64 gpr-64 memory immediate)
      ("LDP_64_ldstpair_post" "XZR, XZR, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__15"))
    )
    ((gpr-64 gpr-64 memory pre-index)
      ("LDP_64_ldstpair_pre" "XZR, XZR, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__15"))
    )
    ((gpr-32 gpr-32 memory pre-index)
      ("LDP_32_ldstpair_pre" "WZR, WZR, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option" "imm__12"))
    )
    ((gpr-32 gpr-32 memory immediate)
      ("LDP_32_ldstpair_post" "WZR, WZR, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option" "imm__12"))
    )
    ((simd-scalar simd-scalar memory immediate)
      ("LDP_S_ldstpair_post" "SUInteger, SUInteger, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St1" "St2" "XnSP_option" "imm__12"))
      ("LDP_D_ldstpair_post" "DUInteger, DUInteger, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt1" "Dt2" "XnSP_option" "imm__15"))
      ("LDP_Q_ldstpair_post" "QUInteger, QUInteger, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm__16"))
    )
    ((simd-scalar simd-scalar memory pre-index)
      ("LDP_S_ldstpair_pre" "SUInteger, SUInteger, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St1" "St2" "XnSP_option" "imm__12"))
      ("LDP_D_ldstpair_pre" "DUInteger, DUInteger, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt1" "Dt2" "XnSP_option" "imm__15"))
      ("LDP_Q_ldstpair_pre" "QUInteger, QUInteger, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm__16"))
    )
  )
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDP_S_ldstpair_off" "SUInteger, SUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St1" "St2" "XnSP_option" "imm7_option"))
      ("LDP_D_ldstpair_off" "DUInteger, DUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt1" "Dt2" "XnSP_option" "imm7_option__2"))
      ("LDP_Q_ldstpair_off" "QUInteger, QUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm7_option__3"))
    )
    ((gpr-64 gpr-64 memory)
      ("LDP_64_ldstpair_off" "XZR, XZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm7_option__2"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDP_32_ldstpair_off" "WZR, WZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option" "imm7_option"))
    )
  )
)

(blraaz
  (c1
    ((gpr-64)
      ("BLRAAZ_64_branch_reg" "XZR" (("Rn" (reg-range 0 31))) ("XnOrXZR"))
    )
  )
)

(sqcvtu
  (c2
    ((sve-z reg-list)
      ("sqcvtu_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
      ("sqcvtu_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
    )
  )
)

(sabdl
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SABDL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(cpyfmrt
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFMRT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(cpymt
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYMT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(cpyfpwn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFPWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(zipq2
  (c3
    ((sve-z sve-z sve-z)
      ("zipq2_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(ld1sw
  (c2
    ((reg-list sve-p)
      ("ld1sw_z_p_br_s64" "{Z UInteger .D}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
      ("ld1sw_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ld1sw_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ld1sw_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld1sw_z_p_bi_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ld1sw_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ld1sw_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
    )
  )
)

(cbz
  (c2
    ((gpr-64 immediate)
      ("CBZ_64_compbranch" "XZR, SInteger" (("imm19" (imm-range 0 524287 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "imm19_offset"))
    )
    ((gpr-32 immediate)
      ("CBZ_32_compbranch" "WZR, SInteger" (("imm19" (imm-range 0 524287 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "imm19_offset"))
    )
  )
)

(casalt
  (c2m
    ((gpr-64 gpr-64 memory)
      ("CASALT_C64_comswap_unpriv" "XZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
    )
  )
)

(usubwb
  (c3
    ((sve-z sve-z sve-z)
      ("usubwb_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(sttxr
  (c2m
    ((gpr-32 gpr-32 memory)
      ("STTXR_SR32_ldstexclr_unpriv" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "WtOrWZR__4" "XnSP_option"))
    )
    ((gpr-32 gpr-64 memory)
      ("STTXR_SR64_ldstexclr_unpriv" "WZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "XtOrXZR__11" "XnSP_option"))
    )
  )
)

(setgoptn
  (c0m1
    ((memory gpr-64)
      ("SETGOPTN_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__4" "XnOrXZR__8"))
    )
  )
)

(rcwsswppl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSSWPPL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(sha1p
  (c3
    ((simd-scalar simd-scalar simd-vector)
      ("SHA1P_QSV_cryptosha3" "QUInteger, SUInteger, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Qd" "Sn__2" "Vm__7"))
    )
  )
)

(addhn
  (c3
    ((simd-vector simd-vector simd-vector)
      ("ADDHN_asimddiff_N" "VUInteger.8B, VUInteger.8H, VUInteger.8H" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(ldtrsw
  (c1m
    ((gpr-64 memory)
      ("LDTRSW_64_ldst_unpriv" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
    )
  )
)

(fminv
  (c2
    ((simd-scalar simd-vector)
      ("FMINV_asimdall_only_H" "HUInteger, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_hv" "Vn"))
      ("FMINV_asimdall_only_SD" "SUInteger, VUInteger.4S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vn"))
    )
  )
  (c3
    ((simd-scalar sve-p sve-z)
      ("fminv_v_p_z_" "HUInteger, PUInteger, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V__5" "Pg" "Zn"))
    )
  )
)

(uxth
  (c3
    ((sve-z sve-p sve-z)
      ("uxth_z_p_z_m" "ZUInteger.S, PUInteger/M, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("uxth_z_p_z_z" "ZUInteger.S, PUInteger/Z, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(ldnf1b
  (c2m
    ((reg-list sve-p memory)
      ("ldnf1b_z_p_bi_u8" "{Z UInteger .B}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldnf1b_z_p_bi_u16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldnf1b_z_p_bi_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldnf1b_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
  )
)

(autibsppcr
  (c1
    ((gpr-64)
      ("AUTIBSPPCR_64LRR_dp_1src" "XZR" (("Rn" (reg-range 0 31))) ("XnOrXZR__11"))
    )
  )
)

(str
  (c1m1
    ((gpr-32 memory pre-index)
      ("STR_32_ldst_immpre" "WZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
    ((simd-scalar memory pre-index)
      ("STR_B_ldst_immpre" "BUInteger, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option"))
      ("STR_Q_ldst_immpre" "QUInteger, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option"))
      ("STR_H_ldst_immpre" "HUInteger, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option"))
      ("STR_S_ldst_immpre" "SUInteger, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option"))
      ("STR_D_ldst_immpre" "DUInteger, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option"))
    )
    ((gpr-64 memory pre-index)
      ("STR_64_ldst_immpre" "XZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
    )
    ((gpr-64 memory immediate)
      ("STR_64_ldst_immpost" "XZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
    )
    ((gpr-32 memory immediate)
      ("STR_32_ldst_immpost" "WZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
    ((simd-scalar memory immediate)
      ("STR_B_ldst_immpost" "BUInteger, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option"))
      ("STR_Q_ldst_immpost" "QUInteger, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option"))
      ("STR_H_ldst_immpost" "HUInteger, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option"))
      ("STR_S_ldst_immpost" "SUInteger, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option"))
      ("STR_D_ldst_immpost" "DUInteger, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option"))
    )
  )
  (c1
    ((sme-za)
      ("str_za_ri_" "ZA[WUInteger, UInteger, [SP]" (("Rn" (reg-range 0 31)) ("off4" (imm-range 0 15 1))) ("Wv__2" "offs__7" "XnSP__3"))
    )
  )
  (c1m
    ((gpr-32 memory)
      ("STR_32_ldst_regoff" "WZR, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "WorX_choice"))
      ("STR_32_ldst_pos" "WZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm12_option__6"))
    )
    ((sve-p memory)
      ("str_p_bi_" "PUInteger, [SP]" (("imm9h" (imm-range 0 63 1)) ("imm9l" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Pt" (reg-range 0 15))) ("Pt__2" "XnSP__3"))
    )
    ((simd-scalar memory)
      ("STR_B_ldst_regoff" "BUInteger, [SP WZR UXTW]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option" "WorX_choice" "S_option"))
      ("STR_BL_ldst_regoff" "BUInteger, [SP XZR]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option" "XmOrXZR__2"))
      ("STR_Q_ldst_regoff" "QUInteger, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option" "WorX_choice"))
      ("STR_H_ldst_regoff" "HUInteger, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option" "WorX_choice"))
      ("STR_S_ldst_regoff" "SUInteger, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option" "WorX_choice"))
      ("STR_D_ldst_regoff" "DUInteger, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option" "WorX_choice"))
      ("STR_B_ldst_pos" "BUInteger, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option" "imm12_option"))
      ("STR_Q_ldst_pos" "QUInteger, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option" "imm12_option__3"))
      ("STR_H_ldst_pos" "HUInteger, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option" "imm12_option__4"))
      ("STR_S_ldst_pos" "SUInteger, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option" "imm12_option__6"))
      ("STR_D_ldst_pos" "DUInteger, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option" "imm12_option__8"))
    )
    ((sme-zt memory)
      ("str_zt_br_" "ZT0, [SP]" (("Rn" (reg-range 0 31))) ("XnSP__3"))
    )
    ((sve-z memory)
      ("str_z_bi_" "ZUInteger, [SP]" (("imm9h" (imm-range 0 63 1)) ("imm9l" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "XnSP__3"))
    )
    ((gpr-64 memory)
      ("STR_64_ldst_regoff" "XZR, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "WorX_choice"))
      ("STR_64_ldst_pos" "XZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm12_option__8"))
    )
  )
)

(blr
  (c1
    ((gpr-64)
      ("BLR_64_branch_reg" "XZR" (("Rn" (reg-range 0 31))) ("XnOrXZR"))
    )
  )
)

(ctermeq
  (c2
    ((gpr-32 gpr-32)
      ("ctermeq_rr_" "WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ())
    )
  )
)

(ldumaxl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDUMAXL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDUMAXL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ldbfmin
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDBFMIN_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(usmmla
  (c3
    ((simd-vector simd-vector simd-vector)
      ("USMMLA_asimdsame2_G" "VUInteger.4S, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "Vm"))
    )
    ((sve-z sve-z sve-z)
      ("usmmla_z_zzz_" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(orrs
  (c4
    ((sve-p sve-p sve-p sve-p)
      ("orrs_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
    )
  )
)

(ld1rsw
  (c2m
    ((reg-list sve-p memory)
      ("ld1rsw_z_p_bi_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
  )
)

(bfm
  (c4
    ((gpr-64 gpr-64 immediate immediate)
      ("BFM_64M_bitfield" "XZR, XZR, UInteger, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11" "immr__2" "imms__2"))
    )
    ((gpr-32 gpr-32 immediate immediate)
      ("BFM_32M_bitfield" "WZR, WZR, UInteger, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR" "immr" "imms"))
    )
  )
)

(f1cvtl
  (c2
    ((simd-vector simd-vector)
      ("F1CVTL_asimdmisc_V" "VUInteger.8H, VUInteger.8B" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((reg-list sve-z)
      ("f1cvtl_mz2_z8_" "{Z UInteger .H- Z UInteger .H}, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
    )
  )
)

(cpyfmrtn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFMRTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(cblt
  (c3
    ((gpr-64 immediate immediate)
      ("CBLT_64_imm" "XZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "imm_cbr" "imm9_offset"))
    )
    ((gpr-32 immediate immediate)
      ("CBLT_32_imm" "WZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "imm_cbr" "imm9_offset"))
    )
  )
)

(shadd
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("shadd_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SHADD_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(crc32w
  (c3
    ((gpr-32 gpr-32 gpr-32)
      ("CRC32W_32C_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR__2" "WnOrWZR__4" "WmOrWZR__5"))
    )
  )
)

(bfmop4s
  (c3
    ((sme-za reg-list sve-z)
      ("bfmop4s_za32_zz_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
      ("bfmop4s_za_zz_h2x1" "ZAUInteger.H, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
    )
    ((sme-za reg-list reg-list)
      ("bfmop4s_za32_zz_h2x2" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("bfmop4s_za_zz_h2x2" "ZAUInteger.H, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
    ((sme-za sve-z sve-z)
      ("bfmop4s_za32_zz_h1x1" "ZAUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
      ("bfmop4s_za_zz_h1x1" "ZAUInteger.H, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn_mortlach" "Zm_mortlach"))
    )
    ((sme-za sve-z reg-list)
      ("bfmop4s_za32_zz_h1x2" "ZAUInteger.S, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("bfmop4s_za_zz_h1x2" "ZAUInteger.H, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
  )
)

(stur
  (c1m
    ((gpr-32 memory)
      ("STUR_32_ldst_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
    ((simd-scalar memory)
      ("STUR_B_ldst_unscaled" "BUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option" "imm9_option"))
      ("STUR_Q_ldst_unscaled" "QUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option" "imm9_option"))
      ("STUR_H_ldst_unscaled" "HUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option" "imm9_option"))
      ("STUR_S_ldst_unscaled" "SUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option" "imm9_option"))
      ("STUR_D_ldst_unscaled" "DUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option" "imm9_option"))
    )
    ((gpr-64 memory)
      ("STUR_64_ldst_unscaled" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
    )
  )
)

(uqrshr
  (c3
    ((sve-z reg-list immediate)
      ("uqrshr_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}, UInteger" (("imm4" (imm-range 0 15 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
      ("uqrshr_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}, UInteger" (("imm5" (imm-range 0 31 1)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
    )
  )
)

(sqxtn
  (c2
    ((simd-vector simd-vector)
      ("SQXTN_asimdmisc_N" "VUInteger.8B, VUInteger.8H" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("SQXTN_asisdmisc_N" "BUInteger, HUInteger" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vb_option__3" "Va_option__3"))
    )
  )
)

(adr
  (c2
    ((gpr-64 immediate)
      ("ADR_only_pcreladdr" "XZR, SInteger" (("immlo" (imm-range 0 3 1)) ("immhi" (imm-range 0 524287 1)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "immhiimmlo_offset"))
    )
  )
  (c1m
    ((sve-z memory)
      ("adr_z_az_d_s32_scaled" "ZUInteger.D, [Z UInteger .D Z UInteger .D SXTW]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__3" "Zm__3"))
      ("adr_z_az_d_u32_scaled" "ZUInteger.D, [Z UInteger .D Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__3" "Zm__3"))
      ("adr_z_az_sd_same_scaled" "ZUInteger.S, [Z UInteger . S Z UInteger . S]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__3" "Zm__3"))
    )
  )
)

(cpyert
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYERT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(cntp
  (c3
    ((gpr-64 sve-pn vector-length)
      ("cntp_r_pn_" "XUInteger, PNUInteger.B, VLx2" (("size" (element-size B H S D)) ("PNn" (reg-range 0 15)) ("Rd" (reg-range 0 31))) ("Xd__2" "PNn"))
    )
    ((gpr-64 sve-p sve-p)
      ("cntp_r_p_p_" "XUInteger, PUInteger, PUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Rd" (reg-range 0 31))) ("Xd__2" "Pg__2" "Pn__3"))
    )
  )
)

(decb
  (c1
    ((gpr-64)
      ("decb_r_rs_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
  )
)

(cpymtrn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYMTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(gcsb
  (c1
    ((barrier-option)
      ("GCSB_HD_hints" "DSYNC" () ())
    )
  )
)

(setgmtn
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETGMTN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__9" "XsOrXZR__8"))
    )
  )
)

(rcwsseta
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSSETA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(sel
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("sel_z_p_zz_" "ZUInteger.B, PUInteger, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pv" "Zn__2" "Zm"))
    )
    ((sve-p sve-p sve-p sve-p)
      ("sel_p_p_pp_" "PUInteger.B, PUInteger, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
    )
    ((reg-list sve-pn reg-list reg-list)
      ("sel_mz_p_zz_2" "{Z UInteger . B - Z UInteger . B}, PNUInteger, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "PNv" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("sel_mz_p_zz_4" "{Z UInteger . B - Z UInteger . B}, PNUInteger, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "PNv" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
)

(nbsl
  (c4
    ((sve-z sve-z sve-z sve-z)
      ("nbsl_z_zzz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm" "Zk"))
    )
  )
)

(compact
  (c3
    ((sve-z sve-p sve-z)
      ("compact_z_p_z_s" "ZUInteger.B, PUInteger, ZUInteger.B" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("compact_z_p_z_" "ZUInteger.S, PUInteger, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(smlal
  (c1
    ((sme-za)
      ("smlal_za_zzi_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
      ("smlal_za_zzi_2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm__2"))
      ("smlal_za_zzi_4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm__2"))
      ("smlal_za_zzv_2x1" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn2" "Zm__2"))
      ("smlal_za_zzv_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
      ("smlal_za_zzv_4x1" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn4" "Zm__2"))
      ("smlal_za_zzw_2x2" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("smlal_za_zzw_4x4" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SMLAL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("SMLAL_asimdelem_L" "VUInteger.4S, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
    )
  )
)

(strb
  (c1m1
    ((gpr-32 memory pre-index)
      ("STRB_32_ldst_immpre" "WZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
    ((gpr-32 memory immediate)
      ("STRB_32_ldst_immpost" "WZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
  )
  (c1m
    ((gpr-32 memory)
      ("STRB_32B_ldst_regoff" "WZR, [SP WZR UXTW]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "WorX_choice" "S_option"))
      ("STRB_32BL_ldst_regoff" "WZR, [SP XZR]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "XmOrXZR__2"))
      ("STRB_32_ldst_pos" "WZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm12_option"))
    )
  )
)

(sm3partw2
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SM3PARTW2_VVV4_cryptosha512_3" "VUInteger.4S, VUInteger.4S, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6" "Vm__7"))
    )
  )
)

(sysp
  (c4
    ((immediate system-reg system-reg immediate)
      ("SYSP_CR_syspairinstrs" "UInteger, CUInteger, CUInteger, UInteger" (("Rt" (reg-range 0 31))) ("SYSP_optional_xt1_xt2"))
    )
  )
)

(ldfmaxnmal
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDFMAXNMAL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMAXNMAL_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMAXNMAL_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(autibsppc
  (c1
    ((immediate)
      ("AUTIBSPPC_only_dp_1src_imm" "SInteger" (("imm16" (imm-range 0 65535 1))) ("imm16_offset"))
    )
  )
)

(fscale
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fscale_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FSCALE_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FSCALE_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((reg-list reg-list sve-z)
      ("fscale_mz_zzv_2x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
      ("fscale_mz_zzv_4x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
    )
    ((reg-list reg-list reg-list)
      ("fscale_mz_zzw_2x2" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
      ("fscale_mz_zzw_4x4" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
    )
  )
)

(stlurb
  (c1m
    ((gpr-32 memory)
      ("STLURB_32_ldapstl_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
  )
)

(sbcs
  (c3
    ((gpr-32 gpr-32 gpr-32)
      ("SBCS_32_addsub_carry" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64)
      ("SBCS_64_addsub_carry" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
  )
)

(st1
  (c1m1
    ((reg-list memory immediate)
      ("ST1_asisdlsep_I4_i4" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], 32" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "imm_option"))
      ("ST1_asisdlsep_I3_i3" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], 24" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "imm_option__3"))
      ("ST1_asisdlsep_I1_i1" "{V UInteger . 8B}, [SP], 8" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "imm_option__5"))
      ("ST1_asisdlsep_I2_i2" "{V UInteger . 8B V UInteger . 8B}, [SP], 16" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "imm_option__6"))
    )
    ((reg-list memory gpr-64)
      ("ST1_asisdlsep_R4_r4" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
      ("ST1_asisdlsep_R3_r3" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
      ("ST1_asisdlsep_R1_r1" "{V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "Xm__2"))
      ("ST1_asisdlsep_R2_r2" "{V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
    )
    ((reg-list memory memory)
      ("ST1_asisdlso_B1_1b" "{V UInteger . B}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
      ("ST1_asisdlso_H1_1h" "{V UInteger . H}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
      ("ST1_asisdlso_S1_1s" "{V UInteger . S}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
      ("ST1_asisdlso_D1_1d" "{V UInteger . D}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
    )
  )
  (c1m2
    ((reg-list memory memory immediate)
      ("ST1_asisdlsop_B1_i1b" "{V UInteger . B}, [UInteger], [SP], 1" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
      ("ST1_asisdlsop_H1_i1h" "{V UInteger . H}, [UInteger], [SP], 2" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
      ("ST1_asisdlsop_S1_i1s" "{V UInteger . S}, [UInteger], [SP], 4" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
      ("ST1_asisdlsop_D1_i1d" "{V UInteger . D}, [UInteger], [SP], 8" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
    )
    ((reg-list memory memory gpr-64)
      ("ST1_asisdlsop_BX1_r1b" "{V UInteger . B}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "Xm__2"))
      ("ST1_asisdlsop_HX1_r1h" "{V UInteger . H}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "Xm__2"))
      ("ST1_asisdlsop_SX1_r1s" "{V UInteger . S}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "Xm__2"))
      ("ST1_asisdlsop_DX1_r1d" "{V UInteger . D}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "Xm__2"))
    )
  )
  (c1m
    ((reg-list memory)
      ("ST1_asisdlse_R4_4v" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
      ("ST1_asisdlse_R3_3v" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
      ("ST1_asisdlse_R1_1v" "{V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
      ("ST1_asisdlse_R2_2v" "{V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
    )
  )
)

(rprfm
  (c2m
    ((prefetch-op gpr-64 memory)
      ("RPRFM_R_ldst_regoff" "PLDKEEP, XZR, [SP]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XmOrXZR__3" "XnSP_option"))
    )
  )
)

(fcvtn
  (c2
    ((simd-vector simd-vector)
      ("FCVTN_asimdmisc_N" "VUInteger.4H, VUInteger.4S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((sve-z reg-list)
      ("fcvtn_z8_mz2_h2b" "ZUInteger.B, {Z UInteger .H- Z UInteger .H}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
      ("fcvtn_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
      ("fcvtn_z8_mz4_" "ZUInteger.B, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FCVTN_asimdsame2_H" "VUInteger.8B, VUInteger.4S, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FCVTN_asimdsame2_D" "VUInteger.8B, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(rcwscaspl
  (c4m
    ((gpr-64 gpr-64 gpr-64 gpr-64 memory)
      ("RCWSCASPL_C64_rcwcomswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
    )
  )
)

(mad
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("mad_z_p_zzz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Za" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zm" "Za"))
    )
  )
)

(umullb
  (c3
    ((sve-z sve-z sve-z)
      ("umullb_z_zzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__78"))
      ("umullb_z_zzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__2" "imm__88"))
      ("umullb_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(rcwswppal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSWPPAL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(stbfminl
  (c1m
    ((simd-scalar memory)
      ("STBFMINL_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(setget
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETGET_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__10" "XsOrXZR__7"))
    )
  )
)

(sm3tt1a
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SM3TT1A_VVV4_crypto3_imm2" "VUInteger.4S, VUInteger.4S, VUInteger.S[UInteger]" (("Rm" (reg-range 0 31)) ("imm2" (imm-range 0 3 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6" "Vm__7"))
    )
  )
)

(cbhgt
  (c3
    ((gpr-32 gpr-32 immediate)
      ("CBHGT_16_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
    )
  )
)

(sqdecp
  (c2
    ((gpr-64 sve-p)
      ("sqdecp_r_p_r_x" "XUInteger, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Rdn" (reg-range 0 31))) ("Xdn" "Pm__3"))
    )
    ((sve-z sve-p)
      ("sqdecp_z_p_z_" "ZUInteger.H, PUInteger.H" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pm__3"))
    )
  )
  (c3
    ((gpr-64 sve-p gpr-32)
      ("sqdecp_r_p_r_sx" "XUInteger, PUInteger.B, WUInteger" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Rdn" (reg-range 0 31))) ("Xdn" "Pm__3" "Wdn"))
    )
  )
)

(umlalt
  (c3
    ((sve-z sve-z sve-z)
      ("umlalt_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("umlalt_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
      ("umlalt_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
    )
  )
)

(cpyfewtrn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFEWTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(nmatch
  (c4
    ((sve-p sve-p sve-z sve-z)
      ("nmatch_p_p_zz_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
    )
  )
)

(sxtw
  (c3
    ((sve-z sve-p sve-z)
      ("sxtw_z_p_z_m" "ZUInteger.D, PUInteger/M, ZUInteger.D" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("sxtw_z_p_z_z" "ZUInteger.D, PUInteger/Z, ZUInteger.D" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(fcvtl
  (c2
    ((simd-vector simd-vector)
      ("FCVTL_asimdmisc_L" "VUInteger.4S, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((reg-list sve-z)
      ("fcvtl_mz2_z_" "{Z UInteger .S- Z UInteger .S}, ZUInteger.H" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
    )
  )
)

(ldclr
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDCLR_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDCLR_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(addsvl
  (c3
    ((gpr-64 gpr-64 immediate)
      ("addsvl_r_ri_" "SP, SP, SInteger" (("Rn" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rd" (reg-range 0 31))) ("XdSP__2" "XnSP__2" "imm__28"))
    )
  )
)

(ld3q
  (c2
    ((reg-list sve-p)
      ("ld3q_z_p_br_contiguous" "{Z UInteger .Q Z UInteger .Q Z UInteger .Q}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld3q_z_p_bi_contiguous" "{Z UInteger .Q Z UInteger .Q Z UInteger .Q}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3"))
    )
  )
)

(ldsetb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSETB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(st2h
  (c2
    ((reg-list sve-p)
      ("st2h_z_p_br_contiguous" "{Z UInteger .H Z UInteger .H}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("st2h_z_p_bi_contiguous" "{Z UInteger .H Z UInteger .H}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3"))
    )
  )
)

(udf
  (c1
    ((immediate)
      ("UDF_only_perm_undef" "UInteger" (("imm16" (imm-range 0 65535 1))) ("imm__21"))
    )
  )
)

(rcwssetpal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSSETPAL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(orns
  (c4
    ((sve-p sve-p sve-p sve-p)
      ("orns_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
    )
  )
)

(ld1roh
  (c2
    ((reg-list sve-p)
      ("ld1roh_z_p_br_contiguous" "{Z UInteger .H}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld1roh_z_p_bi_u16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
  )
)

(st3
  (c1m1
    ((reg-list memory immediate)
      ("ST3_asisdlsep_I3_i" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], 24" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "imm_option__3"))
    )
    ((reg-list memory gpr-64)
      ("ST3_asisdlsep_R3_r" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
    )
    ((reg-list memory memory)
      ("ST3_asisdlso_B3_3b" "{V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
      ("ST3_asisdlso_H3_3h" "{V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
      ("ST3_asisdlso_S3_3s" "{V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
      ("ST3_asisdlso_D3_3d" "{V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
    )
  )
  (c1m2
    ((reg-list memory memory immediate)
      ("ST3_asisdlsop_B3_i3b" "{V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP], 3" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
      ("ST3_asisdlsop_H3_i3h" "{V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP], 6" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
      ("ST3_asisdlsop_S3_i3s" "{V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP], 12" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
      ("ST3_asisdlsop_D3_i3d" "{V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP], 24" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
    )
    ((reg-list memory memory gpr-64)
      ("ST3_asisdlsop_BX3_r3b" "{V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
      ("ST3_asisdlsop_HX3_r3h" "{V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
      ("ST3_asisdlsop_SX3_r3s" "{V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
      ("ST3_asisdlsop_DX3_r3d" "{V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
    )
  )
  (c1m
    ((reg-list memory)
      ("ST3_asisdlse_R3" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
    )
  )
)

(stxrb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("STXRB_SR32_ldstexclr" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "WtOrWZR__4" "XnSP_option"))
    )
  )
)

(rcwsswpal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSSWPAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(srhadd
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("srhadd_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SRHADD_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(fcmeq
  (c4
    ((sve-p sve-p sve-z float-const)
      ("fcmeq_p_p_z0_" "PUInteger.H, PUInteger/Z, ZUInteger.H, 0.0" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn"))
    )
    ((sve-p sve-p sve-z sve-z)
      ("fcmeq_p_p_zz_" "PUInteger.H, PUInteger/Z, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
    )
  )
  (c3
    ((simd-scalar simd-scalar float-const)
      ("FCMEQ_asisdmiscfp16_FZ" "HUInteger, HUInteger, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
      ("FCMEQ_asisdmisc_FZ" "SUInteger, SUInteger, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
    )
    ((simd-vector simd-vector simd-vector)
      ("FCMEQ_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FCMEQ_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("FCMEQ_asisdsamefp16_only" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
      ("FCMEQ_asisdsame_only" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9" "V_option__9"))
    )
    ((simd-vector simd-vector float-const)
      ("FCMEQ_asimdmiscfp16_FZ" "VUInteger.4H, VUInteger.4H, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FCMEQ_asimdmisc_FZ" "VUInteger.2S, VUInteger.2S, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
  )
)

(fcvtzun
  (c2
    ((sve-z reg-list)
      ("fcvtzun_z_mz2_" "ZUInteger.B, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
    )
  )
)

(bif
  (c3
    ((simd-vector simd-vector simd-vector)
      ("BIF_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(cpymn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYMN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(frecps
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FRECPS_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FRECPS_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("FRECPS_asisdsamefp16_only" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
      ("FRECPS_asisdsame_only" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9" "V_option__9"))
    )
    ((sve-z sve-z sve-z)
      ("frecps_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(cmla
  (c4
    ((sve-z sve-z sve-z immediate)
      ("cmla_z_zzz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B, 0" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
  (c3
    ((sve-z sve-z sve-z)
      ("cmla_z_zzzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger, 0" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__41"))
      ("cmla_z_zzzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger, 0" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__42"))
    )
  )
)

(tchangeb
  (c2
    ((immediate gpr-64)
      ("TCHANGEB_tc_reg" "UInteger, XUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Xd_tchange" "Xn_tchange"))
    )
    ((immediate immediate)
      ("TCHANGEB_tc_imm" "UInteger, UInteger" (("imm7" (imm-range 0 127 1)) ("Rd" (reg-range 0 31))) ("Xd_tchange" "imm_tindex"))
    )
  )
)

(cpyfpwt
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFPWT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(rcwswpp
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSWPP_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(uvdot
  (c1
    ((sme-za)
      ("uvdot_za32_zzi_2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
      ("uvdot_za_zzi_s4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
      ("uvdot_za_zzi_d4xi" "ZA.D[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
    )
  )
)

(psb
  (c1
    ((barrier-option)
      ("PSB_HC_hints" "CSYNC" () ())
    )
  )
)

(cmle
  (c3
    ((simd-scalar simd-scalar immediate)
      ("CMLE_asisdmisc_Z" "DUInteger, DUInteger, 0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
    ((simd-vector simd-vector immediate)
      ("CMLE_asimdmisc_Z" "VUInteger.8B, VUInteger.8B, 0" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
  )
)

(cpyfmwtwn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFMWTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(fcvtpu
  (c2
    ((simd-vector simd-vector)
      ("FCVTPU_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FCVTPU_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("FCVTPU_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
      ("FCVTPU_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
      ("FCVTPU_sisd_32D" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
      ("FCVTPU_sisd_32H" "SUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Hn__2"))
      ("FCVTPU_sisd_64H" "DUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Hn__2"))
      ("FCVTPU_sisd_64S" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
    )
    ((gpr-32 simd-scalar)
      ("FCVTPU_32S_float2int" "WZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
      ("FCVTPU_32D_float2int" "WZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
      ("FCVTPU_32H_float2int" "WZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
    )
    ((gpr-64 simd-scalar)
      ("FCVTPU_64S_float2int" "XZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
      ("FCVTPU_64D_float2int" "XZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
      ("FCVTPU_64H_float2int" "XZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
    )
  )
)

(lastp
  (c3
    ((gpr-64 sve-p sve-p)
      ("lastp_r_p_p_" "XUInteger, PUInteger, PUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Rd" (reg-range 0 31))) ("Xd__2" "Pg__2" "Pn__3"))
    )
  )
)

(ldsetlb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSETLB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(fnmad
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fnmad_z_p_zzz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Za" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zm" "Za"))
    )
  )
)

(smull
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SMULL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("SMULL_asimdelem_L" "VUInteger.4S, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
    )
  )
)

(udivr
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("udivr_z_p_zz_" "ZUInteger.S, PUInteger/M, ZUInteger.S, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
)

(eortb
  (c3
    ((sve-z sve-z sve-z)
      ("eortb_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(fsub
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fsub_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
    ((sve-z sve-p sve-z float-const)
      ("fsub_z_p_zs_" "ZUInteger.H, PUInteger/M, ZUInteger.H, 0.5" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
    )
  )
  (c1
    ((sme-za)
      ("fsub_za_zw_2x2_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1" "Zm2"))
      ("fsub_za_zw_4x4_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1__2" "Zm4"))
    )
  )
  (c1m1
    ((sme-za memory reg-list)
      ("fsub_za_zw_2x2" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1" "Zm2"))
      ("fsub_za_zw_4x4" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1__2" "Zm4"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FSUB_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FSUB_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("FSUB_S_floatdp2" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__3" "Sm"))
      ("FSUB_D_floatdp2" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__2" "Dm"))
      ("FSUB_H_floatdp2" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
    )
    ((sve-z sve-z sve-z)
      ("fsub_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(rcwswpal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSWPAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(ldfmaxnm
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDFMAXNM_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMAXNM_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMAXNM_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(cpyfpt
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFPT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(fcvtps
  (c2
    ((simd-vector simd-vector)
      ("FCVTPS_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FCVTPS_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("FCVTPS_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
      ("FCVTPS_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
      ("FCVTPS_sisd_32D" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
      ("FCVTPS_sisd_32H" "SUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Hn__2"))
      ("FCVTPS_sisd_64H" "DUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Hn__2"))
      ("FCVTPS_sisd_64S" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
    )
    ((gpr-32 simd-scalar)
      ("FCVTPS_32S_float2int" "WZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
      ("FCVTPS_32D_float2int" "WZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
      ("FCVTPS_32H_float2int" "WZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
    )
    ((gpr-64 simd-scalar)
      ("FCVTPS_64S_float2int" "XZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
      ("FCVTPS_64D_float2int" "XZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
      ("FCVTPS_64H_float2int" "XZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
    )
  )
)

(ldfminnml
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDFMINNML_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMINNML_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMINNML_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(uqsub
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("uqsub_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((sve-z sve-z immediate)
      ("uqsub_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__27"))
    )
    ((simd-vector simd-vector simd-vector)
      ("UQSUB_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("UQSUB_asisdsame_only" "BUInteger, BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7" "V_option__7"))
    )
    ((sve-z sve-z sve-z)
      ("uqsub_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(uaddw
  (c3
    ((simd-vector simd-vector simd-vector)
      ("UADDW_asimddiff_W" "VUInteger.8H, VUInteger.8H, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(texit
  (c0
    (()
      ("TEXIT_te_branch_reg" "" () ())
    )
  )
)

(fcvtzu
  (c2
    ((simd-vector simd-vector)
      ("FCVTZU_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FCVTZU_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((reg-list reg-list)
      ("fcvtzu_mz_z_2" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__4" "Zn2__3"))
      ("fcvtzu_mz_z_4" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
    )
    ((simd-scalar simd-scalar)
      ("FCVTZU_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
      ("FCVTZU_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
      ("FCVTZU_sisd_32D" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
      ("FCVTZU_sisd_32H" "SUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Hn__2"))
      ("FCVTZU_sisd_64H" "DUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Hn__2"))
      ("FCVTZU_sisd_64S" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
    )
    ((gpr-32 simd-scalar)
      ("FCVTZU_32S_float2int" "WZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
      ("FCVTZU_32D_float2int" "WZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
      ("FCVTZU_32H_float2int" "WZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
    )
    ((gpr-64 simd-scalar)
      ("FCVTZU_64S_float2int" "XZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
      ("FCVTZU_64D_float2int" "XZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
      ("FCVTZU_64H_float2int" "XZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
    )
  )
  (c3
    ((simd-scalar simd-scalar immediate)
      ("FCVTZU_asisdshf_C" "HUInteger, HUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__6" "V_option__6" "immh_shift__3"))
    )
    ((gpr-32 simd-scalar immediate)
      ("FCVTZU_32S_float2fix" "WZR, SUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
      ("FCVTZU_32D_float2fix" "WZR, DUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
      ("FCVTZU_32H_float2fix" "WZR, HUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
    )
    ((gpr-64 simd-scalar immediate)
      ("FCVTZU_64S_float2fix" "XZR, SUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
      ("FCVTZU_64D_float2fix" "XZR, DUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
      ("FCVTZU_64H_float2fix" "XZR, HUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
    )
    ((simd-vector simd-vector immediate)
      ("FCVTZU_asimdshf_C" "VUInteger.4H, VUInteger.4H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__9"))
    )
    ((sve-z sve-p sve-z)
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
    )
  )
)

(uabal
  (c3
    ((simd-vector simd-vector simd-vector)
      ("UABAL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((sve-z sve-z sve-z)
      ("uabal_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(cpyewn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYEWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(rshrn
  (c3
    ((simd-vector simd-vector immediate)
      ("RSHRN_asimdshf_N" "VUInteger.8B, VUInteger.8H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__6"))
    )
  )
)

(ldnf1h
  (c2m
    ((reg-list sve-p memory)
      ("ldnf1h_z_p_bi_u16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldnf1h_z_p_bi_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldnf1h_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
  )
)

(casal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("CASAL_C64_comswap" "XZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("CASAL_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
    )
  )
)

(cpyertn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYERTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(movt
  (c2
    ((gpr-64 sme-zt)
      ("movt_r_zt_" "XUInteger, ZT0[UInteger" (("off3" (imm-range 0 7 1)) ("Rt" (reg-range 0 31))) ("Xt__3" "offs__8"))
    )
    ((sme-zt sve-z)
      ("movt_zt_z_" "ZT0, ZUInteger" (("off2" (imm-range 0 3 1)) ("Zt" (reg-range 0 31))) ("Zt"))
    )
  )
  (c1
    ((sme-zt)
      ("movt_zt_r_" "ZT0[UInteger, XUInteger" (("off3" (imm-range 0 7 1)) ("Rt" (reg-range 0 31))) ("offs__8" "Xt__3"))
    )
  )
)

(uxtb
  (c3
    ((sve-z sve-p sve-z)
      ("uxtb_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("uxtb_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(fmsb
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fmsb_z_p_zzz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Za" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zm" "Za"))
    )
  )
)

(sha1h
  (c2
    ((simd-scalar simd-scalar)
      ("SHA1H_SS_cryptosha2" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
    )
  )
)

(ldraa
  (c1m1
    ((gpr-64 memory pre-index)
      ("LDRAA_64W_ldst_pac" "XZR, [SP], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "Simm9_option"))
    )
  )
  (c1m
    ((gpr-64 memory)
      ("LDRAA_64_ldst_pac" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "Simm9_option"))
    )
  )
)

(st3b
  (c2m
    ((reg-list sve-p memory)
      ("st3b_z_p_br_contiguous" "{Z UInteger .B Z UInteger .B Z UInteger .B}, PUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3" "Xm__4"))
      ("st3b_z_p_bi_contiguous" "{Z UInteger .B Z UInteger .B Z UInteger .B}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3"))
    )
  )
)

(uhadd
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("uhadd_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("UHADD_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(ldlarb
  (c1m
    ((gpr-32 memory)
      ("LDLARB_LR32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
  )
)

(uqshlr
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("uqshlr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
)

(fnmla
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fnmla_z_p_zzz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Pg" "Zn__2" "Zm"))
    )
  )
)

(st1w
  (c2
    ((reg-list sve-pn)
      ("st1w_mz_p_br_2" "{Z UInteger .S- Z UInteger .S}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
      ("st1w_mz_p_br_4" "{Z UInteger .S- Z UInteger .S}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
      ("st1w_mzx_p_br_2x8" "{Z UInteger .S Z UInteger .S}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
      ("st1w_mzx_p_br_4x4" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
    )
    ((reg-list sve-p)
      ("st1w_z_p_br_u128" "{Z UInteger .Q}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
      ("st1w_z_p_br_" "{Z UInteger . S}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
      ("st1w_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("st1w_z_p_bz_s_x32_scaled" "{Z UInteger .S}, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("st1w_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("st1w_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("st1w_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("st1w_z_p_bz_d_64_unscaled" "{Z UInteger . D}, PUInteger, [SP Z UInteger . D]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("st1w_z_p_ai_d" "{Z UInteger .D}, PUInteger, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("st1w_z_p_ai_s" "{Z UInteger .S}, PUInteger, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("st1w_z_p_bi_u128" "{Z UInteger .Q}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("st1w_z_p_bi_" "{Z UInteger . S}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("st1w_za_p_rrr_" "{ZA UInteger H .S [W UInteger UInteger]}, PUInteger, [SP]" (("Rm" (reg-range 0 31)) ("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("ZAt__4" "HV" "Ws__3" "offs__6" "Pg" "XnSP__3"))
    )
    ((reg-list sve-pn memory)
      ("st1w_mz_p_bi_2" "{Z UInteger .S- Z UInteger .S}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
      ("st1w_mz_p_bi_4" "{Z UInteger .S- Z UInteger .S}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
      ("st1w_mzx_p_bi_2x8" "{Z UInteger .S Z UInteger .S}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
      ("st1w_mzx_p_bi_4x4" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
    )
  )
)

(aesdimc
  (c3
    ((reg-list reg-list sve-z)
      ("aesdimc_mz_zzi_2x1" "{Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}, ZUInteger.Q[UInteger" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm"))
      ("aesdimc_mz_zzi_4x1" "{Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}, ZUInteger.Q[UInteger" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm"))
    )
  )
)

(uqrshl
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("uqrshl_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("UQRSHL_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("UQRSHL_asisdsame_only" "BUInteger, BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7" "V_option__7"))
    )
  )
)

(ldumaxh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDUMAXH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(fminp
  (c2
    ((simd-scalar simd-vector)
      ("FMINP_asisdpair_only_H" "HUInteger, VUInteger.2H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vn"))
      ("FMINP_asisdpair_only_SD" "SUInteger, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__4" "Vn"))
    )
  )
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fminp_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMINP_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMINP_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(cpyprtn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYPRTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(ftmad
  (c4
    ((sve-z sve-z sve-z immediate)
      ("ftmad_z_zzi_" "ZUInteger.H, ZUInteger.H, ZUInteger.H, UInteger" (("size" (element-size B H S D)) ("imm3" (imm-range 0 7 1)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm" "imm__57"))
    )
  )
)

(fcmne
  (c4
    ((sve-p sve-p sve-z float-const)
      ("fcmne_p_p_z0_" "PUInteger.H, PUInteger/Z, ZUInteger.H, 0.0" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn"))
    )
    ((sve-p sve-p sve-z sve-z)
      ("fcmne_p_p_zz_" "PUInteger.H, PUInteger/Z, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
    )
  )
)

(ldlarh
  (c1m
    ((gpr-32 memory)
      ("LDLARH_LR32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
  )
)

(f1cvt
  (c2
    ((reg-list sve-z)
      ("f1cvt_mz2_z8_" "{Z UInteger .H- Z UInteger .H}, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
    )
    ((sve-z sve-z)
      ("f1cvt_z_z8_b2h" "ZUInteger.H, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(scvtflt
  (c2
    ((sve-z sve-z)
      ("scvtflt_z_z_" "ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(smulh
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("smulh_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((gpr-64 gpr-64 gpr-64)
      ("SMULH_64_dp_3src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__13" "XmOrXZR__9"))
    )
    ((sve-z sve-z sve-z)
      ("smulh_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(smmla
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SMMLA_asimdsame2_G" "VUInteger.4S, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "Vm"))
    )
    ((sve-z sve-z sve-z)
      ("smmla_z_zzz_" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(urecpe
  (c2
    ((simd-vector simd-vector)
      ("URECPE_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("urecpe_z_p_z_m" "ZUInteger.S, PUInteger/M, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("urecpe_z_p_z_z" "ZUInteger.S, PUInteger/Z, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(st3d
  (c2
    ((reg-list sve-p)
      ("st3d_z_p_br_contiguous" "{Z UInteger .D Z UInteger .D Z UInteger .D}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("st3d_z_p_bi_contiguous" "{Z UInteger .D Z UInteger .D Z UInteger .D}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3"))
    )
  )
)

(csdb
  (c0
    (()
      ("CSDB_HI_hints" "" () ())
    )
  )
)

(swppl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("SWPPL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(f2cvtlt
  (c2
    ((sve-z sve-z)
      ("f2cvtlt_z_z8_b2h" "ZUInteger.H, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(bfadd
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("bfadd_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c1
    ((sme-za)
      ("bfadd_za_zw_2x2_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1" "Zm2"))
      ("bfadd_za_zw_4x4_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1__2" "Zm4"))
    )
  )
  (c3
    ((sve-z sve-z sve-z)
      ("bfadd_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(fvdotb
  (c3
    ((sme-za reg-list sve-z)
      ("fvdotb_za32_z8z8i_2xi" "ZA.S[WUInteger, UInteger, VGx4], {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
    )
  )
)

(ldset
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDSET_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDSET_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(rcwsclra
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSCLRA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(setgen
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETGEN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__10" "XsOrXZR__7"))
    )
  )
)

(ftssel
  (c3
    ((sve-z sve-z sve-z)
      ("ftssel_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(ldfadd
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDFADD_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFADD_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFADD_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(fcmgt
  (c4
    ((sve-p sve-p sve-z float-const)
      ("fcmgt_p_p_z0_" "PUInteger.H, PUInteger/Z, ZUInteger.H, 0.0" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn"))
    )
    ((sve-p sve-p sve-z sve-z)
      ("fcmgt_p_p_zz_" "PUInteger.H, PUInteger/Z, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
    )
  )
  (c3
    ((simd-scalar simd-scalar float-const)
      ("FCMGT_asisdmiscfp16_FZ" "HUInteger, HUInteger, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
      ("FCMGT_asisdmisc_FZ" "SUInteger, SUInteger, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
    )
    ((simd-vector simd-vector simd-vector)
      ("FCMGT_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FCMGT_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("FCMGT_asisdsamefp16_only" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
      ("FCMGT_asisdsame_only" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9" "V_option__9"))
    )
    ((simd-vector simd-vector float-const)
      ("FCMGT_asimdmiscfp16_FZ" "VUInteger.4H, VUInteger.4H, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FCMGT_asimdmisc_FZ" "VUInteger.2S, VUInteger.2S, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
  )
)

(stfmaxnml
  (c1m
    ((simd-scalar memory)
      ("STFMAXNML_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
      ("STFMAXNML_32" "SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
      ("STFMAXNML_64" "DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(csinv
  (c4
    ((gpr-32 gpr-32 gpr-32 cond-code)
      ("CSINV_32_condsel" "WZR, WZR, WZR, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64 cond-code)
      ("CSINV_64_condsel" "XZR, XZR, XZR, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
  )
)

(shsubr
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("shsubr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
)

(addspl
  (c3
    ((gpr-64 gpr-64 immediate)
      ("addspl_r_ri_" "SP, SP, SInteger" (("Rn" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rd" (reg-range 0 31))) ("XdSP__2" "XnSP__2" "imm__28"))
    )
  )
)

(autdza
  (c1
    ((gpr-64)
      ("AUTDZA_64Z_dp_1src" "XZR" (("Rd" (reg-range 0 31))) ("XdOrXZR__6"))
    )
  )
)

(uaba
  (c3
    ((simd-vector simd-vector simd-vector)
      ("UABA_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((sve-z sve-z sve-z)
      ("uaba_z_zzz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(stlurh
  (c1m
    ((gpr-32 memory)
      ("STLURH_32_ldapstl_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
  )
)

(cmpne
  (c4
    ((sve-p sve-p sve-z immediate)
      ("cmpne_p_p_zi_" "PUInteger.B, PUInteger/Z, ZUInteger.B, SInteger" (("size" (element-size B H S D)) ("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn" "imm__43"))
    )
    ((sve-p sve-p sve-z sve-z)
      ("cmpne_p_p_zw_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
      ("cmpne_p_p_zz_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
    )
  )
)

(fmlal
  (c1
    ((sme-za)
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
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMLAL_asimdsame_F" "VUInteger.2S, VUInteger.2H, VUInteger.2H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMLAL_asimdelem_LH" "VUInteger.2S, VUInteger.2H, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(cbbgt
  (c3
    ((gpr-32 gpr-32 immediate)
      ("CBBGT_8_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
    )
  )
)

(cas
  (c2m
    ((gpr-64 gpr-64 memory)
      ("CAS_C64_comswap" "XZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("CAS_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
    )
  )
)

(casah
  (c2m
    ((gpr-32 gpr-32 memory)
      ("CASAH_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
    )
  )
)

(irg
  (c2
    ((gpr-64 gpr-64)
      ("IRG_64I_dp_2src" "SP, SP" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option" "XnSP_option__6"))
    )
  )
)

(eretaa
  (c0
    (()
      ("ERETAA_64E_branch_reg" "" () ())
    )
  )
)

(msubpt
  (c4
    ((gpr-64 gpr-64 gpr-64 gpr-64)
      ("MSUBPT_64A_dp_3src" "XZR, XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__13" "XmOrXZR__9" "XaOrXZR__2"))
    )
  )
)

(ldumaxlb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDUMAXLB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ldnf1d
  (c2m
    ((reg-list sve-p memory)
      ("ldnf1d_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
  )
)

(ld2r
  (c1m1
    ((reg-list memory immediate)
      ("LD2R_asisdlsop_R2_i" "{V UInteger . 8B V UInteger . 8B}, [SP], 2" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "imm_option__10"))
    )
    ((reg-list memory gpr-64)
      ("LD2R_asisdlsop_RX2_r" "{V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
    )
  )
  (c1m
    ((reg-list memory)
      ("LD2R_asisdlso_R2" "{V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
    )
  )
)

(ldsetlh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSETLH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(sqdmlslbt
  (c3
    ((sve-z sve-z sve-z)
      ("sqdmlslbt_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(braa
  (c2
    ((gpr-64 gpr-64)
      ("BRAA_64P_branch_reg" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rm" (reg-range 0 31))) ("XnOrXZR" "XmSP_option"))
    )
  )
)

(rcwclrpal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWCLRPAL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(suqadd
  (c2
    ((simd-vector simd-vector)
      ("SUQADD_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("SUQADD_asisdmisc_R" "BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7"))
    )
  )
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("suqadd_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
)

(ldclralh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDCLRALH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(rev
  (c2
    ((gpr-64 gpr-64)
      ("REV_64_dp_1src" "XZR, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
    )
    ((gpr-32 gpr-32)
      ("REV_32_dp_1src" "WZR, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
    )
    ((sve-p sve-p)
      ("rev_p_p_" "PUInteger.B, PUInteger.B" (("size" (element-size B H S D)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pn__3"))
    )
    ((sve-z sve-z)
      ("rev_z_z_" "ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(sqdmull
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SQDMULL_asimddiff_L" "VUInteger.4S, VUInteger.4H, VUInteger.4H" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("SQDMULL_asimdelem_L" "VUInteger.4S, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
    )
    ((simd-scalar simd-scalar simd-vector)
      ("SQDMULL_asisdelem_L" "SUInteger, HUInteger, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Va_option__2" "Vb_option__2" "Vm__5"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("SQDMULL_asisddiff_only" "SUInteger, HUInteger, HUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Va_option__2" "Vb_option__2" "Vb_option__2"))
    )
  )
)

(st1q
  (c2m
    ((reg-list sve-p memory)
      ("st1q_z_p_ar_d_64_unscaled" "{Z UInteger .Q}, PUInteger, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("st1q_za_p_rrr_" "{ZA UInteger H .Q [W UInteger 0]}, PUInteger, [SP]" (("Rm" (reg-range 0 31)) ("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("ZAt__3" "HV" "Ws__3" "offs__5" "Pg" "XnSP__3"))
    )
  )
)

(addg
  (c4
    ((gpr-64 gpr-64 immediate immediate)
      ("ADDG_64_addsub_immtags" "SP, SP, UInteger, UInteger" (("imm6" (imm-range 0 63 1)) ("imm4" (imm-range 0 15 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option" "XnSP_option__3"))
    )
  )
)

(cmeq
  (c3
    ((simd-scalar simd-scalar immediate)
      ("CMEQ_asisdmisc_Z" "DUInteger, DUInteger, 0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
    ((simd-vector simd-vector immediate)
      ("CMEQ_asimdmisc_Z" "VUInteger.8B, VUInteger.8B, 0" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-vector simd-vector simd-vector)
      ("CMEQ_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("CMEQ_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
  )
)

(setp
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETP_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XnOrXZR__5" "XsOrXZR__7"))
    )
  )
)

(usqadd
  (c2
    ((simd-vector simd-vector)
      ("USQADD_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("USQADD_asisdmisc_R" "BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7"))
    )
  )
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("usqadd_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
)

(cnt
  (c2
    ((simd-vector simd-vector)
      ("CNT_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((gpr-64 gpr-64)
      ("CNT_64_dp_1src" "XZR, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
    )
    ((gpr-32 gpr-32)
      ("CNT_32_dp_1src" "WZR, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("cnt_z_p_z_m" "ZUInteger.B, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("cnt_z_p_z_z" "ZUInteger.B, PUInteger/Z, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(sqincp
  (c2
    ((gpr-64 sve-p)
      ("sqincp_r_p_r_x" "XUInteger, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Rdn" (reg-range 0 31))) ("Xdn" "Pm__3"))
    )
    ((sve-z sve-p)
      ("sqincp_z_p_z_" "ZUInteger.H, PUInteger.H" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pm__3"))
    )
  )
  (c3
    ((gpr-64 sve-p gpr-32)
      ("sqincp_r_p_r_sx" "XUInteger, PUInteger.B, WUInteger" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Rdn" (reg-range 0 31))) ("Xdn" "Pm__3" "Wdn"))
    )
  )
)

(umull
  (c3
    ((simd-vector simd-vector simd-vector)
      ("UMULL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("UMULL_asimdelem_L" "VUInteger.4S, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
    )
  )
)

(ldapurb
  (c1m
    ((gpr-32 memory)
      ("LDAPURB_32_ldapstl_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
  )
)

(ssubwb
  (c3
    ((sve-z sve-z sve-z)
      ("ssubwb_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(cpyewtn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYEWTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(rsubhnb
  (c3
    ((sve-z sve-z sve-z)
      ("rsubhnb_z_zz_" "ZUInteger.B, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(ldar
  (c1m
    ((gpr-32 memory)
      ("LDAR_LR32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
    ((gpr-64 memory)
      ("LDAR_LR64_ldstord" "XZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
    )
  )
)

(sabd
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("sabd_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SABD_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(umlalb
  (c3
    ((sve-z sve-z sve-z)
      ("umlalb_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("umlalb_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
      ("umlalb_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
    )
  )
)

(rcwsswpa
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSSWPA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(ldfadda
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDFADDA_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFADDA_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFADDA_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(cntb
  (c1
    ((gpr-64)
      ("cntb_r_s_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rd" (reg-range 0 31))) ("Xd__2"))
    )
  )
)

(fdiv
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fdiv_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FDIV_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FDIV_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("FDIV_S_floatdp2" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__3" "Sm"))
      ("FDIV_D_floatdp2" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__2" "Dm"))
      ("FDIV_H_floatdp2" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
    )
  )
)

(sqdecb
  (c2
    ((gpr-64 gpr-32)
      ("sqdecb_r_rs_sx" "XUInteger, WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn" "Wdn"))
    )
  )
  (c1
    ((gpr-64)
      ("sqdecb_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
  )
)

(cmphs
  (c4
    ((sve-p sve-p sve-z immediate)
      ("cmphs_p_p_zi_" "PUInteger.B, PUInteger/Z, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm7" (imm-range 0 127 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn" "imm__44"))
    )
    ((sve-p sve-p sve-z sve-z)
      ("cmphs_p_p_zz_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
      ("cmphs_p_p_zw_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
    )
  )
)

(autizb
  (c1
    ((gpr-64)
      ("AUTIZB_64Z_dp_1src" "XZR" (("Rd" (reg-range 0 31))) ("XdOrXZR__6"))
    )
  )
)

(fminqv
  (c3
    ((simd-vector sve-p sve-z)
      ("fminqv_z_p_z_" "VUInteger.8H, PUInteger, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
    )
  )
)

(bit
  (c3
    ((simd-vector simd-vector simd-vector)
      ("BIT_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(sqdmlslt
  (c3
    ((sve-z sve-z sve-z)
      ("sqdmlslt_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("sqdmlslt_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
      ("sqdmlslt_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
    )
  )
)

(cbhi
  (c3
    ((gpr-64 gpr-64 immediate)
      ("CBHI_64_regs" "XZR, XZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "XmOrXZR__4" "imm9_offset"))
    )
    ((gpr-64 immediate immediate)
      ("CBHI_64_imm" "XZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "imm_cbr" "imm9_offset"))
    )
    ((gpr-32 gpr-32 immediate)
      ("CBHI_32_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
    )
    ((gpr-32 immediate immediate)
      ("CBHI_32_imm" "WZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "imm_cbr" "imm9_offset"))
    )
  )
)

(sbc
  (c3
    ((gpr-32 gpr-32 gpr-32)
      ("SBC_32_addsub_carry" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64)
      ("SBC_64_addsub_carry" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
  )
)

(cpyfetrn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFETRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(cpyetrn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYETRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(cpyfmwtrn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFMWTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(fcvtzs
  (c2
    ((simd-vector simd-vector)
      ("FCVTZS_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FCVTZS_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((reg-list reg-list)
      ("fcvtzs_mz_z_2" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__4" "Zn2__3"))
      ("fcvtzs_mz_z_4" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
    )
    ((simd-scalar simd-scalar)
      ("FCVTZS_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
      ("FCVTZS_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
      ("FCVTZS_sisd_32D" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
      ("FCVTZS_sisd_32H" "SUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Hn__2"))
      ("FCVTZS_sisd_64H" "DUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Hn__2"))
      ("FCVTZS_sisd_64S" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
    )
    ((gpr-32 simd-scalar)
      ("FCVTZS_32S_float2int" "WZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
      ("FCVTZS_32D_float2int" "WZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
      ("FCVTZS_32H_float2int" "WZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
    )
    ((gpr-64 simd-scalar)
      ("FCVTZS_64S_float2int" "XZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
      ("FCVTZS_64D_float2int" "XZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
      ("FCVTZS_64H_float2int" "XZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
    )
  )
  (c3
    ((simd-scalar simd-scalar immediate)
      ("FCVTZS_asisdshf_C" "HUInteger, HUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__6" "V_option__6" "immh_shift__3"))
    )
    ((gpr-32 simd-scalar immediate)
      ("FCVTZS_32S_float2fix" "WZR, SUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
      ("FCVTZS_32D_float2fix" "WZR, DUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
      ("FCVTZS_32H_float2fix" "WZR, HUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
    )
    ((gpr-64 simd-scalar immediate)
      ("FCVTZS_64S_float2fix" "XZR, SUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
      ("FCVTZS_64D_float2fix" "XZR, DUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
      ("FCVTZS_64H_float2fix" "XZR, HUInteger, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
    )
    ((simd-vector simd-vector immediate)
      ("FCVTZS_asimdshf_C" "VUInteger.4H, VUInteger.4H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__9"))
    )
    ((sve-z sve-p sve-z)
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
    )
  )
)

(uqincd
  (c1
    ((gpr-64)
      ("uqincd_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
    ((sve-z)
      ("uqincd_z_zs_" "ZUInteger.D" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
    )
    ((gpr-32)
      ("uqincd_r_rs_uw" "WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Wdn"))
    )
  )
)

(addhnb
  (c3
    ((sve-z sve-z sve-z)
      ("addhnb_z_zz_" "ZUInteger.B, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(ld1rqb
  (c2m
    ((reg-list sve-p memory)
      ("ld1rqb_z_p_br_contiguous" "{Z UInteger .B}, PUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
      ("ld1rqb_z_p_bi_u8" "{Z UInteger .B}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
  )
)

(ldbfminnma
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDBFMINNMA_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(smlalb
  (c3
    ((sve-z sve-z sve-z)
      ("smlalb_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("smlalb_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
      ("smlalb_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
    )
  )
)

(tchangef
  (c2
    ((immediate gpr-64)
      ("TCHANGEF_tc_reg" "UInteger, XUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Xd_tchange" "Xn_tchange"))
    )
    ((immediate immediate)
      ("TCHANGEF_tc_imm" "UInteger, UInteger" (("imm7" (imm-range 0 127 1)) ("Rd" (reg-range 0 31))) ("Xd_tchange" "imm_tindex"))
    )
  )
)

(ldarb
  (c1m
    ((gpr-32 memory)
      ("LDARB_LR32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
  )
)

(rcwswpl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSWPL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(decp
  (c2
    ((gpr-64 sve-p)
      ("decp_r_p_r_" "XUInteger, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Rdn" (reg-range 0 31))) ("Xdn" "Pm__3"))
    )
    ((sve-z sve-p)
      ("decp_z_p_z_" "ZUInteger.H, PUInteger.H" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pm__3"))
    )
  )
)

(stbfminnml
  (c1m
    ((simd-scalar memory)
      ("STBFMINNML_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(ldap
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDAP_64_ldiappstilp" "XZR, XZR, [SP 0]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(ldsminlh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSMINLH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ldsminal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDSMINAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDSMINAL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(bfmop4a
  (c3
    ((sme-za reg-list sve-z)
      ("bfmop4a_za32_zz_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
      ("bfmop4a_za_zz_h2x1" "ZAUInteger.H, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
    )
    ((sme-za reg-list reg-list)
      ("bfmop4a_za32_zz_h2x2" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("bfmop4a_za_zz_h2x2" "ZAUInteger.H, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
    ((sme-za sve-z sve-z)
      ("bfmop4a_za32_zz_h1x1" "ZAUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
      ("bfmop4a_za_zz_h1x1" "ZAUInteger.H, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn_mortlach" "Zm_mortlach"))
    )
    ((sme-za sve-z reg-list)
      ("bfmop4a_za32_zz_h1x2" "ZAUInteger.S, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("bfmop4a_za_zz_h1x2" "ZAUInteger.H, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
  )
)

(setgopt
  (c0m1
    ((memory gpr-64)
      ("SETGOPT_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__4" "XnOrXZR__8"))
    )
  )
)

(cpypt
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYPT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(whilele
  (c4
    ((sve-pn gpr-64 gpr-64 vector-length)
      ("whilele_pn_rr_" "PNUInteger.B, XUInteger, XUInteger, VLx2" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("PNd" (reg-range 0 7))) ("PNd" "Xn__4" "Xm__6"))
    )
  )
  (c3
    ((reg-list gpr-64 gpr-64)
      ("whilele_pp_rr_" "{P UInteger . B P UInteger . B}, XUInteger, XUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 7))) ("Pd1__2" "Pd2__2" "Xn__4" "Xm__6"))
    )
    ((sve-p gpr-32 gpr-32)
      ("whilele_p_p_rr_" "PUInteger.B, WZR, WZR" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd"))
    )
  )
)

(brk
  (c1
    ((immediate)
      ("BRK_EX_exception" "UInteger" (("imm16" (imm-range 0 65535 1))) ("imm"))
    )
  )
)

(ldnt1sb
  (c2m
    ((reg-list sve-p memory)
      ("ldnt1sb_z_p_ar_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("ldnt1sb_z_p_ar_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
    )
  )
)

(stnt1b
  (c2m
    ((reg-list sve-p memory)
      ("stnt1b_z_p_ar_d_64_unscaled" "{Z UInteger .D}, PUInteger, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("stnt1b_z_p_ar_s_x32_unscaled" "{Z UInteger .S}, PUInteger, [Z UInteger .S]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("stnt1b_z_p_br_contiguous" "{Z UInteger .B}, PUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
      ("stnt1b_z_p_bi_contiguous" "{Z UInteger .B}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
    ((reg-list sve-pn memory)
      ("stnt1b_mz_p_br_2" "{Z UInteger .B- Z UInteger .B}, PNUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
      ("stnt1b_mz_p_br_4" "{Z UInteger .B- Z UInteger .B}, PNUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
      ("stnt1b_mz_p_bi_2" "{Z UInteger .B- Z UInteger .B}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
      ("stnt1b_mz_p_bi_4" "{Z UInteger .B- Z UInteger .B}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
      ("stnt1b_mzx_p_br_2x8" "{Z UInteger .B Z UInteger .B}, PNUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
      ("stnt1b_mzx_p_br_4x4" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PNUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
      ("stnt1b_mzx_p_bi_2x8" "{Z UInteger .B Z UInteger .B}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
      ("stnt1b_mzx_p_bi_4x4" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
    )
  )
)

(rcwscas
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSCAS_C64_rcwcomswap" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
    )
  )
)

(stnt1d
  (c2
    ((reg-list sve-pn)
      ("stnt1d_mz_p_br_2" "{Z UInteger .D- Z UInteger .D}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
      ("stnt1d_mz_p_br_4" "{Z UInteger .D- Z UInteger .D}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
      ("stnt1d_mzx_p_br_2x8" "{Z UInteger .D Z UInteger .D}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
      ("stnt1d_mzx_p_br_4x4" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
    )
    ((reg-list sve-p)
      ("stnt1d_z_p_br_contiguous" "{Z UInteger .D}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("stnt1d_z_p_ar_d_64_unscaled" "{Z UInteger .D}, PUInteger, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("stnt1d_z_p_bi_contiguous" "{Z UInteger .D}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
    ((reg-list sve-pn memory)
      ("stnt1d_mz_p_bi_2" "{Z UInteger .D- Z UInteger .D}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
      ("stnt1d_mz_p_bi_4" "{Z UInteger .D- Z UInteger .D}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
      ("stnt1d_mzx_p_bi_2x8" "{Z UInteger .D Z UInteger .D}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
      ("stnt1d_mzx_p_bi_4x4" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
    )
  )
)

(umlslt
  (c3
    ((sve-z sve-z sve-z)
      ("umlslt_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("umlslt_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
      ("umlslt_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
    )
  )
)

(ldapursw
  (c1m
    ((gpr-64 memory)
      ("LDAPURSW_64_ldapstl_unscaled" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
    )
  )
)

(fmaxnmv
  (c2
    ((simd-scalar simd-vector)
      ("FMAXNMV_asimdall_only_H" "HUInteger, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_hv" "Vn"))
      ("FMAXNMV_asimdall_only_SD" "SUInteger, VUInteger.4S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vn"))
    )
  )
  (c3
    ((simd-scalar sve-p sve-z)
      ("fmaxnmv_v_p_z_" "HUInteger, PUInteger, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V__5" "Pg" "Zn"))
    )
  )
)

(index
  (c3
    ((sve-z immediate gpr-32)
      ("index_z_ir_" "ZUInteger.B, SInteger, WZR" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("imm5" (imm-range 0 31 1)) ("Zd" (reg-range 0 31))) ("Zd" "imm__43"))
    )
    ((sve-z gpr-32 gpr-32)
      ("index_z_rr_" "ZUInteger.B, WZR, WZR" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd"))
    )
    ((sve-z gpr-32 immediate)
      ("index_z_ri_" "ZUInteger.B, WZR, SInteger" (("size" (element-size B H S D)) ("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "imm__43"))
    )
    ((sve-z immediate immediate)
      ("index_z_ii_" "ZUInteger.B, SInteger, SInteger" (("size" (element-size B H S D)) ("imm5b" (imm-range 0 31 1)) ("imm5" (imm-range 0 31 1)) ("Zd" (reg-range 0 31))) ("Zd" "imm1" "imm2"))
    )
  )
)

(sqneg
  (c2
    ((simd-vector simd-vector)
      ("SQNEG_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("SQNEG_asisdmisc_R" "BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("sqneg_z_p_z_m" "ZUInteger.B, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("sqneg_z_p_z_z" "ZUInteger.B, PUInteger/Z, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(ldtp
  (c2m1
    ((gpr-64 gpr-64 memory immediate)
      ("LDTP_64_ldstpair_post" "XZR, XZR, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__15"))
    )
    ((gpr-64 gpr-64 memory pre-index)
      ("LDTP_64_ldstpair_pre" "XZR, XZR, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__15"))
    )
    ((simd-scalar simd-scalar memory immediate)
      ("LDTP_Q_ldstpair_post" "QUInteger, QUInteger, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm__16"))
    )
    ((simd-scalar simd-scalar memory pre-index)
      ("LDTP_Q_ldstpair_pre" "QUInteger, QUInteger, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm__16"))
    )
  )
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDTP_Q_ldstpair_off" "QUInteger, QUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm7_option__3"))
    )
    ((gpr-64 gpr-64 memory)
      ("LDTP_64_ldstpair_off" "XZR, XZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm7_option__2"))
    )
  )
)

(caspa
  (c4m
    ((gpr-64 gpr-64 gpr-64 gpr-64 memory)
      ("CASPA_CP64_comswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
    )
    ((gpr-32 gpr-32 gpr-32 gpr-32 memory)
      ("CASPA_CP32_comswappr" "WUInteger, WUInteger, WUInteger, WUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ws" "WsPlus1" "Wt" "WtPlus1" "XnSP_option"))
    )
  )
)

(ld1rqd
  (c2
    ((reg-list sve-p)
      ("ld1rqd_z_p_br_contiguous" "{Z UInteger .D}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld1rqd_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
  )
)

(sqdmulh
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SQDMULH_asimdsame_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("SQDMULH_asimdelem_R" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
    )
    ((simd-scalar simd-scalar simd-vector)
      ("SQDMULH_asisdelem_R" "HUInteger, HUInteger, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__8" "V_option__8" "Vm__5"))
    )
    ((reg-list reg-list sve-z)
      ("sqdmulh_mz_zzv_2x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
      ("sqdmulh_mz_zzv_4x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("SQDMULH_asisdsame_only" "HUInteger, HUInteger, HUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__8" "V_option__8" "V_option__8"))
    )
    ((reg-list reg-list reg-list)
      ("sqdmulh_mz_zzw_2x2" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
      ("sqdmulh_mz_zzw_4x4" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
    )
    ((sve-z sve-z sve-z)
      ("sqdmulh_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
      ("sqdmulh_z_zzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__78"))
      ("sqdmulh_z_zzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__41"))
      ("sqdmulh_z_zzi_d" "ZUInteger.D, ZUInteger.D, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__2" "imm__42"))
    )
  )
)

(autia
  (c2
    ((gpr-64 gpr-64)
      ("AUTIA_64P_dp_1src" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__7"))
    )
  )
)

(umax
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("umax_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((gpr-64 gpr-64 immediate)
      ("UMAX_64U_minmax_imm" "XZR, XZR, UInteger" (("imm8" (imm-range 0 255 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
    )
    ((sve-z sve-z immediate)
      ("umax_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__37"))
    )
    ((gpr-32 gpr-32 immediate)
      ("UMAX_32U_minmax_imm" "WZR, WZR, UInteger" (("imm8" (imm-range 0 255 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
    )
    ((simd-vector simd-vector simd-vector)
      ("UMAX_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((gpr-32 gpr-32 gpr-32)
      ("UMAX_32_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((reg-list reg-list sve-z)
      ("umax_mz_zzv_2x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
      ("umax_mz_zzv_4x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
    )
    ((gpr-64 gpr-64 gpr-64)
      ("UMAX_64_dp_2src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
    ((reg-list reg-list reg-list)
      ("umax_mz_zzw_2x2" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
      ("umax_mz_zzw_4x4" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
    )
  )
)

(ldarh
  (c1m
    ((gpr-32 memory)
      ("LDARH_LR32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
  )
)

(ldclra
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDCLRA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDCLRA_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(setgopn
  (c0m1
    ((memory gpr-64)
      ("SETGOPN_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__4" "XnOrXZR__8"))
    )
  )
)

(prfm
  (c2
    ((prefetch-op immediate)
      ("PRFM_P_loadlit" "PLDL1KEEP, SInteger" (("imm19" (imm-range 0 524287 1)) ("Rt" (reg-range 0 31))) ("imm19_offset__2"))
    )
  )
  (c1m
    ((prefetch-op memory)
      ("PRFM_P_ldst_regoff" "PLDL1KEEP, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option" "WorX_choice"))
      ("PRFM_P_ldst_pos" "PLDL1KEEP, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option" "imm12_option__8"))
    )
  )
)

(whilewr
  (c3
    ((sve-p gpr-64 gpr-64)
      ("whilewr_p_rr_" "PUInteger.B, XUInteger, XUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Xn__4" "Xm__6"))
    )
  )
)

(ldaddab
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDADDAB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ldtr
  (c1m
    ((gpr-32 memory)
      ("LDTR_32_ldst_unpriv" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
    ((gpr-64 memory)
      ("LDTR_64_ldst_unpriv" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
    )
  )
)

(sev
  (c0
    (()
      ("SEV_HI_hints" "" () ())
    )
  )
)

(umop4s
  (c3
    ((sme-za reg-list sve-z)
      ("umop4s_za_zz_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
      ("umop4s_za32_zz_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
      ("umop4s_za_zz_h2x1" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
    )
    ((sme-za reg-list reg-list)
      ("umop4s_za_zz_b2x2" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("umop4s_za32_zz_h2x2" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("umop4s_za_zz_h2x2" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
    ((sme-za sve-z sve-z)
      ("umop4s_za_zz_b1x1" "ZAUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
      ("umop4s_za32_zz_h1x1" "ZAUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
      ("umop4s_za_zz_h1x1" "ZAUInteger.D, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm_mortlach"))
    )
    ((sme-za sve-z reg-list)
      ("umop4s_za_zz_b1x2" "ZAUInteger.S, ZUInteger.B, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("umop4s_za32_zz_h1x2" "ZAUInteger.S, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("umop4s_za_zz_h1x2" "ZAUInteger.D, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
  )
)

(uqinch
  (c1
    ((gpr-64)
      ("uqinch_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
    ((sve-z)
      ("uqinch_z_zs_" "ZUInteger.H" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
    )
    ((gpr-32)
      ("uqinch_r_rs_uw" "WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Wdn"))
    )
  )
)

(ssubl
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SSUBL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(asrd
  (c4
    ((sve-z sve-p sve-z immediate)
      ("asrd_z_p_zi_" "ZUInteger.B, PUInteger/M, ZUInteger.B, UInteger" (("Pg" (reg-range 0 7)) ("imm3" (imm-range 0 7 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
    )
  )
)

(frecpe
  (c2
    ((simd-vector simd-vector)
      ("FRECPE_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FRECPE_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((sve-z sve-z)
      ("frecpe_z_z_" "ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
    ((simd-scalar simd-scalar)
      ("FRECPE_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
      ("FRECPE_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
    )
  )
)

(sqxtnb
  (c2
    ((sve-z sve-z)
      ("sqxtnb_z_zz_" "ZUInteger.B, ZUInteger.H" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(sqshlu
  (c4
    ((sve-z sve-p sve-z immediate)
      ("sqshlu_z_p_zi_" "ZUInteger.B, PUInteger/M, ZUInteger.B, UInteger" (("Pg" (reg-range 0 7)) ("imm3" (imm-range 0 7 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
    )
  )
  (c3
    ((simd-scalar simd-scalar immediate)
      ("SQSHLU_asisdshf_R" "BUInteger, BUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__5" "V_option__5" "immh_shift"))
    )
    ((simd-vector simd-vector immediate)
      ("SQSHLU_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__5"))
    )
  )
)

(sminp
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("sminp_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SMINP_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(cpyewt
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYEWT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(ldsminah
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSMINAH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(setgoet
  (c0m1
    ((memory gpr-64)
      ("SETGOET_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__10"))
    )
  )
)

(clastb
  (c4
    ((gpr-32 sve-p gpr-32 sve-z)
      ("clastb_r_p_z_" "WZR, PUInteger, WZR, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Rdn" (reg-range 0 31))) ("Pg" "Zm__5"))
    )
    ((sve-z sve-p sve-z sve-z)
      ("clastb_z_p_zz_" "ZUInteger.B, PUInteger, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
    ((simd-scalar sve-p simd-scalar sve-z)
      ("clastb_v_p_z_" "BUInteger, PUInteger, BUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31))) ("V__2" "Pg" "V__2" "Zm__5"))
    )
  )
)

(st3h
  (c2
    ((reg-list sve-p)
      ("st3h_z_p_br_contiguous" "{Z UInteger .H Z UInteger .H Z UInteger .H}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("st3h_z_p_bi_contiguous" "{Z UInteger .H Z UInteger .H Z UInteger .H}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3"))
    )
  )
)

(casab
  (c2m
    ((gpr-32 gpr-32 memory)
      ("CASAB_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
    )
  )
)

(ldbfminnmal
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDBFMINNMAL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(uzpq1
  (c3
    ((sve-z sve-z sve-z)
      ("uzpq1_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(ldsminh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSMINH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(cpyertrn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYERTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(sm3ss1
  (c4
    ((simd-vector simd-vector simd-vector simd-vector)
      ("SM3SS1_VVV4_crypto4" "VUInteger.4S, VUInteger.4S, VUInteger.4S, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm" "Va"))
    )
  )
)

(setgp
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETGP_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__4" "XnOrXZR__8" "XsOrXZR__8"))
    )
  )
)

(umlall
  (c1
    ((sme-za)
      ("umlall_za_zzi_s" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
      ("umlall_za_zzi_d" "ZA.D[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
      ("umlall_za_zzi_s2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm__2"))
      ("umlall_za_zzi_d2xi" "ZA.D[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm__2"))
      ("umlall_za_zzi_s4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm__2"))
      ("umlall_za_zzi_d4xi" "ZA.D[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm__2"))
    )
  )
  (c1m2
    ((sme-za memory reg-list sve-z)
      ("umlall_za_zzv_2x1" "ZA.S, [W UInteger UInteger : UInteger VGx2], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn2" "Zm__2"))
      ("umlall_za_zzv_4x1" "ZA.S, [W UInteger UInteger : UInteger VGx4], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn4" "Zm__2"))
    )
    ((sme-za memory reg-list reg-list)
      ("umlall_za_zzw_2x2" "ZA.S, [W UInteger UInteger : UInteger VGx2], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("umlall_za_zzw_4x4" "ZA.S, [W UInteger UInteger : UInteger VGx4], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
    ((sme-za memory sve-z sve-z)
      ("umlall_za_zzv_1" "ZA.S, [W UInteger UInteger : UInteger], ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
    )
  )
)

(sttr
  (c1m
    ((gpr-32 memory)
      ("STTR_32_ldst_unpriv" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
    ((gpr-64 memory)
      ("STTR_64_ldst_unpriv" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
    )
  )
)

(sm3tt2a
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SM3TT2A_VVV4_crypto3_imm2" "VUInteger.4S, VUInteger.4S, VUInteger.S[UInteger]" (("Rm" (reg-range 0 31)) ("imm2" (imm-range 0 3 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6" "Vm__7"))
    )
  )
)

(ldtclr
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDTCLR_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDTCLR_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ldgm
  (c1m
    ((gpr-64 memory)
      ("LDGM_64bulk_ldsttags" "XZR, [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__4" "XnSP_option"))
    )
  )
)

(trn1
  (c3
    ((sve-p sve-p sve-p)
      ("trn1_p_pp_" "PUInteger.B, PUInteger.B, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pn__2" "Pm__2"))
    )
    ((simd-vector simd-vector simd-vector)
      ("TRN1_asimdperm_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((sve-z sve-z sve-z)
      ("trn1_z_zz_q" "ZUInteger.Q, ZUInteger.Q, ZUInteger.Q" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
      ("trn1_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(fcvtns
  (c2
    ((simd-vector simd-vector)
      ("FCVTNS_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FCVTNS_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("FCVTNS_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
      ("FCVTNS_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
      ("FCVTNS_sisd_32D" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
      ("FCVTNS_sisd_32H" "SUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Hn__2"))
      ("FCVTNS_sisd_64H" "DUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Hn__2"))
      ("FCVTNS_sisd_64S" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
    )
    ((gpr-32 simd-scalar)
      ("FCVTNS_32S_float2int" "WZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
      ("FCVTNS_32D_float2int" "WZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
      ("FCVTNS_32H_float2int" "WZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
    )
    ((gpr-64 simd-scalar)
      ("FCVTNS_64S_float2int" "XZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
      ("FCVTNS_64D_float2int" "XZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
      ("FCVTNS_64H_float2int" "XZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
    )
  )
)

(pmullb
  (c3
    ((sve-z sve-z sve-z)
      ("pmullb_z_zz_q" "ZUInteger.Q, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
      ("pmullb_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(ld4q
  (c2
    ((reg-list sve-p)
      ("ld4q_z_p_br_contiguous" "{Z UInteger .Q Z UInteger .Q Z UInteger .Q Z UInteger .Q}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld4q_z_p_bi_contiguous" "{Z UInteger .Q Z UInteger .Q Z UInteger .Q Z UInteger .Q}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3"))
    )
  )
)

(cmplt
  (c4
    ((sve-p sve-p sve-z immediate)
      ("cmplt_p_p_zi_" "PUInteger.B, PUInteger/Z, ZUInteger.B, SInteger" (("size" (element-size B H S D)) ("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn" "imm__43"))
    )
    ((sve-p sve-p sve-z sve-z)
      ("cmplt_p_p_zw_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
    )
  )
)

(whilerw
  (c3
    ((sve-p gpr-64 gpr-64)
      ("whilerw_p_rr_" "PUInteger.B, XUInteger, XUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Xn__4" "Xm__6"))
    )
  )
)

(ftsmul
  (c3
    ((sve-z sve-z sve-z)
      ("ftsmul_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(cbhs
  (c3
    ((gpr-64 gpr-64 immediate)
      ("CBHS_64_regs" "XZR, XZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "XmOrXZR__4" "imm9_offset"))
    )
    ((gpr-32 gpr-32 immediate)
      ("CBHS_32_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
    )
  )
)

(fjcvtzs
  (c2
    ((gpr-32 simd-scalar)
      ("FJCVTZS_32D_float2int" "WZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
    )
  )
)

(punpklo
  (c2
    ((sve-p sve-p)
      ("punpklo_p_p_" "PUInteger.H, PUInteger.B" (("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pn__3"))
    )
  )
)

(cmphi
  (c4
    ((sve-p sve-p sve-z immediate)
      ("cmphi_p_p_zi_" "PUInteger.B, PUInteger/Z, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm7" (imm-range 0 127 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn" "imm__44"))
    )
    ((sve-p sve-p sve-z sve-z)
      ("cmphi_p_p_zz_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
      ("cmphi_p_p_zw_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
    )
  )
)

(cnth
  (c1
    ((gpr-64)
      ("cnth_r_s_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rd" (reg-range 0 31))) ("Xd__2"))
    )
  )
)

(dech
  (c1
    ((gpr-64)
      ("dech_r_rs_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
    ((sve-z)
      ("dech_z_zs_" "ZUInteger.H" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
    )
  )
)

(sqdech
  (c2
    ((gpr-64 gpr-32)
      ("sqdech_r_rs_sx" "XUInteger, WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn" "Wdn"))
    )
  )
  (c1
    ((gpr-64)
      ("sqdech_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
    ((sve-z)
      ("sqdech_z_zs_" "ZUInteger.H" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
    )
  )
)

(sqinch
  (c2
    ((gpr-64 gpr-32)
      ("sqinch_r_rs_sx" "XUInteger, WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn" "Wdn"))
    )
  )
  (c1
    ((gpr-64)
      ("sqinch_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
    ((sve-z)
      ("sqinch_z_zs_" "ZUInteger.H" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
    )
  )
)

(setgoen
  (c0m1
    ((memory gpr-64)
      ("SETGOEN_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__10"))
    )
  )
)

(brabz
  (c1
    ((gpr-64)
      ("BRABZ_64_branch_reg" "XZR" (("Rn" (reg-range 0 31))) ("XnOrXZR"))
    )
  )
)

(fnmsub
  (c4
    ((simd-scalar simd-scalar simd-scalar simd-scalar)
      ("FNMSUB_S_floatdp3" "SUInteger, SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__6" "Sm__2" "Sa__2"))
      ("FNMSUB_D_floatdp3" "DUInteger, DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__5" "Dm__2" "Da__2"))
      ("FNMSUB_H_floatdp3" "HUInteger, HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__5" "Hm__2" "Ha__2"))
    )
  )
)

(whilehs
  (c4
    ((sve-pn gpr-64 gpr-64 vector-length)
      ("whilehs_pn_rr_" "PNUInteger.B, XUInteger, XUInteger, VLx2" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("PNd" (reg-range 0 7))) ("PNd" "Xn__4" "Xm__6"))
    )
  )
  (c3
    ((reg-list gpr-64 gpr-64)
      ("whilehs_pp_rr_" "{P UInteger . B P UInteger . B}, XUInteger, XUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 7))) ("Pd1__2" "Pd2__2" "Xn__4" "Xm__6"))
    )
    ((sve-p gpr-32 gpr-32)
      ("whilehs_p_p_rr_" "PUInteger.B, WZR, WZR" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd"))
    )
  )
)

(fcvtnu
  (c2
    ((simd-vector simd-vector)
      ("FCVTNU_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FCVTNU_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("FCVTNU_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
      ("FCVTNU_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
      ("FCVTNU_sisd_32D" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
      ("FCVTNU_sisd_32H" "SUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Hn__2"))
      ("FCVTNU_sisd_64H" "DUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Hn__2"))
      ("FCVTNU_sisd_64S" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
    )
    ((gpr-32 simd-scalar)
      ("FCVTNU_32S_float2int" "WZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
      ("FCVTNU_32D_float2int" "WZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
      ("FCVTNU_32H_float2int" "WZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
    )
    ((gpr-64 simd-scalar)
      ("FCVTNU_64S_float2int" "XZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
      ("FCVTNU_64D_float2int" "XZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
      ("FCVTNU_64H_float2int" "XZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
    )
  )
)

(sqrshrn
  (c3
    ((simd-scalar simd-scalar immediate)
      ("SQRSHRN_asisdshf_N" "BUInteger, HUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vb_option" "Va_option" "immh_shift__2"))
    )
    ((simd-vector simd-vector immediate)
      ("SQRSHRN_asimdshf_N" "VUInteger.8B, VUInteger.8H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__6"))
    )
    ((sve-z reg-list immediate)
      ("sqrshrn_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}, UInteger" (("imm4" (imm-range 0 15 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
      ("sqrshrn_z_mz2_b" "ZUInteger.B, {Z UInteger .H- Z UInteger .H}, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
      ("sqrshrn_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}, UInteger" (("imm5" (imm-range 0 31 1)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
    )
  )
)

(mvni
  (c2
    ((simd-vector immediate)
      ("MVNI_asimdimm_L_sl" "VUInteger.2S, UInteger" (("Rd" (reg-range 0 31))) ("Vd"))
      ("MVNI_asimdimm_L_hl" "VUInteger.4H, UInteger" (("Rd" (reg-range 0 31))) ("Vd"))
    )
  )
  (c4
    ((simd-vector immediate keyword immediate)
      ("MVNI_asimdimm_M_sm" "VUInteger.2S, UInteger, MSL, 8" (("Rd" (reg-range 0 31))) ("Vd"))
    )
  )
)

(usublb
  (c3
    ((sve-z sve-z sve-z)
      ("usublb_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(cbgt
  (c3
    ((gpr-64 gpr-64 immediate)
      ("CBGT_64_regs" "XZR, XZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "XmOrXZR__4" "imm9_offset"))
    )
    ((gpr-64 immediate immediate)
      ("CBGT_64_imm" "XZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "imm_cbr" "imm9_offset"))
    )
    ((gpr-32 gpr-32 immediate)
      ("CBGT_32_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
    )
    ((gpr-32 immediate immediate)
      ("CBGT_32_imm" "WZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "imm_cbr" "imm9_offset"))
    )
  )
)

(ldbfminal
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDBFMINAL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(uhsub
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("uhsub_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("UHSUB_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(bcax
  (c4
    ((simd-vector simd-vector simd-vector simd-vector)
      ("BCAX_VVV16_crypto4" "VUInteger.16B, VUInteger.16B, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm" "Va"))
    )
    ((sve-z sve-z sve-z sve-z)
      ("bcax_z_zzz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm" "Zk"))
    )
  )
)

(ldsminlb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSMINLB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(smops
  (c5
    ((sme-za sve-p sve-p sve-z sve-z)
      ("smops_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
      ("smops_za32_pp_zz_16" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
      ("smops_za_pp_zz_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn__2" "Zm"))
    )
  )
)

(fcvtxn
  (c2
    ((simd-vector simd-vector)
      ("FCVTXN_asimdmisc_N" "VUInteger.2S, VUInteger.2D" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("FCVTXN_asisdmisc_N" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
  )
)

(swpalb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("SWPALB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(stnt1h
  (c2
    ((reg-list sve-pn)
      ("stnt1h_mz_p_br_2" "{Z UInteger .H- Z UInteger .H}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
      ("stnt1h_mz_p_br_4" "{Z UInteger .H- Z UInteger .H}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
      ("stnt1h_mzx_p_br_2x8" "{Z UInteger .H Z UInteger .H}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
      ("stnt1h_mzx_p_br_4x4" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
    )
    ((reg-list sve-p)
      ("stnt1h_z_p_br_contiguous" "{Z UInteger .H}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("stnt1h_z_p_ar_d_64_unscaled" "{Z UInteger .D}, PUInteger, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("stnt1h_z_p_ar_s_x32_unscaled" "{Z UInteger .S}, PUInteger, [Z UInteger .S]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("stnt1h_z_p_bi_contiguous" "{Z UInteger .H}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
    ((reg-list sve-pn memory)
      ("stnt1h_mz_p_bi_2" "{Z UInteger .H- Z UInteger .H}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
      ("stnt1h_mz_p_bi_4" "{Z UInteger .H- Z UInteger .H}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
      ("stnt1h_mzx_p_bi_2x8" "{Z UInteger .H Z UInteger .H}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
      ("stnt1h_mzx_p_bi_4x4" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
    )
  )
)

(incw
  (c1
    ((gpr-64)
      ("incw_r_rs_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
    ((sve-z)
      ("incw_z_zs_" "ZUInteger.S" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
    )
  )
)

(saddv
  (c3
    ((simd-scalar sve-p sve-z)
      ("saddv_r_p_z_" "DUInteger, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Dd__2" "Pg" "Zn"))
    )
  )
)

(cntd
  (c1
    ((gpr-64)
      ("cntd_r_s_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rd" (reg-range 0 31))) ("Xd__2"))
    )
  )
)

(clrex
  (c0
    (()
      ("CLREX_BN_barriers" "" () ())
    )
  )
)

(sqdecd
  (c2
    ((gpr-64 gpr-32)
      ("sqdecd_r_rs_sx" "XUInteger, WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn" "Wdn"))
    )
  )
  (c1
    ((gpr-64)
      ("sqdecd_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
    ((sve-z)
      ("sqdecd_z_zs_" "ZUInteger.D" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
    )
  )
)

(swpta
  (c2m
    ((gpr-64 gpr-64 memory)
      ("SWPTA_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("SWPTA_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(fmlal2
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMLAL2_asimdsame_F" "VUInteger.2S, VUInteger.2H, VUInteger.2H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMLAL2_asimdelem_LH" "VUInteger.2S, VUInteger.2H, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(subps
  (c3
    ((gpr-64 gpr-64 gpr-64)
      ("SUBPS_64S_dp_2src" "XZR, SP, SP" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__6" "XmSP_option__2"))
    )
  )
)

(ldnt1w
  (c2
    ((reg-list sve-pn)
      ("ldnt1w_mz_p_br_2" "{Z UInteger .S- Z UInteger .S}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
      ("ldnt1w_mz_p_br_4" "{Z UInteger .S- Z UInteger .S}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
      ("ldnt1w_mzx_p_br_2x8" "{Z UInteger .S Z UInteger .S}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
      ("ldnt1w_mzx_p_br_4x4" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
    )
    ((reg-list sve-p)
      ("ldnt1w_z_p_br_contiguous" "{Z UInteger .S}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ldnt1w_z_p_ar_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("ldnt1w_z_p_bi_contiguous" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldnt1w_z_p_ar_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
    )
    ((reg-list sve-pn memory)
      ("ldnt1w_mz_p_bi_2" "{Z UInteger .S- Z UInteger .S}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
      ("ldnt1w_mz_p_bi_4" "{Z UInteger .S- Z UInteger .S}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
      ("ldnt1w_mzx_p_bi_2x8" "{Z UInteger .S Z UInteger .S}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
      ("ldnt1w_mzx_p_bi_4x4" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
    )
  )
)

(lduminab
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDUMINAB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(uaddwb
  (c3
    ((sve-z sve-z sve-z)
      ("uaddwb_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(ldxrh
  (c1m
    ((gpr-32 memory)
      ("LDXRH_LR32_ldstexclr" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
  )
)

(fcvtzsn
  (c2
    ((sve-z reg-list)
      ("fcvtzsn_z_mz2_" "ZUInteger.B, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
    )
  )
)

(uadalp
  (c2
    ((simd-vector simd-vector)
      ("UADALP_asimdmisc_P" "VUInteger.4H, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("uadalp_z_p_z_" "ZUInteger.H, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda__2" "Pg" "Zn__2"))
    )
  )
)

(uqincp
  (c2
    ((gpr-64 sve-p)
      ("uqincp_r_p_r_x" "XUInteger, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Rdn" (reg-range 0 31))) ("Xdn" "Pm__3"))
    )
    ((sve-z sve-p)
      ("uqincp_z_p_z_" "ZUInteger.H, PUInteger.H" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pm__3"))
    )
    ((gpr-32 sve-p)
      ("uqincp_r_p_r_uw" "WUInteger, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Rdn" (reg-range 0 31))) ("Wdn" "Pm__3"))
    )
  )
)

(blrabz
  (c1
    ((gpr-64)
      ("BLRABZ_64_branch_reg" "XZR" (("Rn" (reg-range 0 31))) ("XnOrXZR"))
    )
  )
)

(decd
  (c1
    ((gpr-64)
      ("decd_r_rs_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
    ((sve-z)
      ("decd_z_zs_" "ZUInteger.D" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
    )
  )
)

(ldapurh
  (c1m
    ((gpr-32 memory)
      ("LDAPURH_32_ldapstl_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
  )
)

(lastb
  (c3
    ((gpr-32 sve-p sve-z)
      ("lastb_r_p_z_" "WZR, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Pg" "Zn"))
    )
    ((simd-scalar sve-p sve-z)
      ("lastb_v_p_z_" "BUInteger, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V__7" "Pg" "Zn"))
    )
  )
)

(extr
  (c4
    ((gpr-64 gpr-64 gpr-64 immediate)
      ("EXTR_64_extract" "XZR, XZR, XZR, UInteger" (("Rm" (reg-range 0 31)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
    ((gpr-32 gpr-32 gpr-32 immediate)
      ("EXTR_32_extract" "WZR, WZR, WZR, UInteger" (("Rm" (reg-range 0 31)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
  )
)

(prfw
  (c2
    ((prefetch-op sve-p)
      ("prfw_i_p_bz_s_x32_scaled" "PLDL1KEEP, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
      ("prfw_i_p_br_s" "PLDL1KEEP, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Xm__4"))
      ("prfw_i_p_bz_d_x32_scaled" "PLDL1KEEP, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
      ("prfw_i_p_bz_d_64_scaled" "PLDL1KEEP, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
    )
  )
  (c2m
    ((prefetch-op sve-p memory)
      ("prfw_i_p_bi_s" "PLDL1KEEP, PUInteger, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3"))
      ("prfw_i_p_ai_s" "PLDL1KEEP, PUInteger, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("Pg" "Zn__3"))
      ("prfw_i_p_ai_d" "PLDL1KEEP, PUInteger, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("Pg" "Zn__3"))
    )
  )
)

(autiasp
  (c0
    (()
      ("AUTIASP_HI_hints" "" () ())
    )
  )
)

(b
  (c1
    ((immediate)
      ("B_only_condbranch" "SInteger" (("imm19" (imm-range 0 524287 1))) ("imm19_offset"))
      ("B_only_branch_imm" "SInteger" (("imm26" (imm-range 0 67108863 1))) ("imm26_offset"))
    )
  )
)

(sqincb
  (c2
    ((gpr-64 gpr-32)
      ("sqincb_r_rs_sx" "XUInteger, WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn" "Wdn"))
    )
  )
  (c1
    ((gpr-64)
      ("sqincb_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
  )
)

(movz
  (c2
    ((gpr-64 immediate)
      ("MOVZ_64_movewide" "XZR, UInteger" (("imm16" (imm-range 0 65535 1)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "imm__18"))
    )
    ((gpr-32 immediate)
      ("MOVZ_32_movewide" "WZR, UInteger" (("imm16" (imm-range 0 65535 1)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "imm__18"))
    )
  )
  (c4
    ((gpr-64 immediate unknown immediate)
      ("MOVZ_64_movewide_shift" "XZR, UInteger, lsl, UInteger" (("imm16" (imm-range 0 65535 1)) ("hw" (imm-range 0 3 1)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "imm" "lsl" "shift"))
    )
    ((gpr-32 immediate unknown immediate)
      ("MOVZ_32_movewide_shift" "WZR, UInteger, lsl, UInteger" (("imm16" (imm-range 0 65535 1)) ("hw" (imm-range 0 1 1)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "imm" "lsl" "shift"))
    )
  )
)

(uabalt
  (c3
    ((sve-z sve-z sve-z)
      ("uabalt_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(ssra
  (c3
    ((simd-scalar simd-scalar immediate)
      ("SSRA_asisdshf_R" "DUInteger, DUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
    ((simd-vector simd-vector immediate)
      ("SSRA_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__4"))
    )
    ((sve-z sve-z immediate)
      ("ssra_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2"))
    )
  )
)

(sminv
  (c2
    ((simd-scalar simd-vector)
      ("SMINV_asimdall_only" "BUInteger, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__2" "Vn"))
    )
  )
  (c3
    ((simd-scalar sve-p sve-z)
      ("sminv_r_p_z_" "BUInteger, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V" "Pg" "Zn"))
    )
  )
)

(cpypn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYPN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(rcwssetpl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSSETPL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(bfmax
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("bfmax_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((reg-list reg-list sve-z)
      ("bfmax_mz_zzv_2x1" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
      ("bfmax_mz_zzv_4x1" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
    )
    ((reg-list reg-list reg-list)
      ("bfmax_mz_zzw_2x2" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, {Z UInteger . H- Z UInteger . H}" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
      ("bfmax_mz_zzw_4x4" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, {Z UInteger . H- Z UInteger . H}" (("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
    )
  )
)

(umlsll
  (c1
    ((sme-za)
      ("umlsll_za_zzi_s" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
      ("umlsll_za_zzi_d" "ZA.D[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
      ("umlsll_za_zzi_s2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm__2"))
      ("umlsll_za_zzi_d2xi" "ZA.D[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm__2"))
      ("umlsll_za_zzi_s4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm__2"))
      ("umlsll_za_zzi_d4xi" "ZA.D[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm__2"))
    )
  )
  (c1m2
    ((sme-za memory reg-list sve-z)
      ("umlsll_za_zzv_2x1" "ZA.S, [W UInteger UInteger : UInteger VGx2], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn2" "Zm__2"))
      ("umlsll_za_zzv_4x1" "ZA.S, [W UInteger UInteger : UInteger VGx4], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn4" "Zm__2"))
    )
    ((sme-za memory reg-list reg-list)
      ("umlsll_za_zzw_2x2" "ZA.S, [W UInteger UInteger : UInteger VGx2], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("umlsll_za_zzw_4x4" "ZA.S, [W UInteger UInteger : UInteger VGx4], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
    ((sme-za memory sve-z sve-z)
      ("umlsll_za_zzv_1" "ZA.S, [W UInteger UInteger : UInteger], ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
    )
  )
)

(adds
  (c5
    ((gpr-64 gpr-64 gpr-32 keyword immediate)
      ("ADDS_64S_addsub_ext" "XZR, SP, WZR, UXTB, UInteger" (("Rm" (reg-range 0 31)) ("imm3" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__6"))
    )
    ((gpr-32 gpr-32 gpr-32 keyword immediate)
      ("ADDS_32_addsub_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
      ("ADDS_32S_addsub_ext" "WZR, WSP, WZR, UXTB, UInteger" (("Rm" (reg-range 0 31)) ("imm3" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnWSP_option__2" "WmOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64 keyword immediate)
      ("ADDS_64_addsub_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
  )
  (c3
    ((gpr-64 gpr-64 immediate)
      ("ADDS_64S_addsub_imm" "XZR, SP, UInteger" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__3" "imm__17"))
    )
    ((gpr-32 gpr-32 immediate)
      ("ADDS_32S_addsub_imm" "WZR, WSP, UInteger" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnWSP_option" "imm__17"))
    )
  )
)

(st64b
  (c1m
    ((gpr-64 memory)
      ("ST64B_64L_memop" "XZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__9" "XnSP_option"))
    )
  )
)

(ldsminab
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSMINAB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ldeora
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDEORA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDEORA_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(uhsubr
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("uhsubr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
)

(zip
  (c2
    ((reg-list reg-list)
      ("zip_mz_z_4" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
      ("zip_mz_z_4q" "{Z UInteger .Q- Z UInteger .Q}, {Z UInteger .Q- Z UInteger .Q}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
    )
  )
  (c3
    ((reg-list sve-z sve-z)
      ("zip_mz_zz_2" "{Z UInteger . B - Z UInteger . B}, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn__2" "Zm"))
      ("zip_mz_zz_2q" "{Z UInteger .Q- Z UInteger .Q}, ZUInteger.Q, ZUInteger.Q" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn__2" "Zm"))
    )
  )
)

(usubl
  (c3
    ((simd-vector simd-vector simd-vector)
      ("USUBL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(ldfmaxnma
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDFMAXNMA_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMAXNMA_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMAXNMA_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(cpymwtwn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYMWTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(sqincd
  (c2
    ((gpr-64 gpr-32)
      ("sqincd_r_rs_sx" "XUInteger, WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn" "Wdn"))
    )
  )
  (c1
    ((gpr-64)
      ("sqincd_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
    ((sve-z)
      ("sqincd_z_zs_" "ZUInteger.D" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
    )
  )
)

(pacib
  (c2
    ((gpr-64 gpr-64)
      ("PACIB_64P_dp_1src" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__7"))
    )
  )
)

(ldbfmaxnm
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDBFMAXNM_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(fmaxnmp
  (c2
    ((simd-scalar simd-vector)
      ("FMAXNMP_asisdpair_only_H" "HUInteger, VUInteger.2H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vn"))
      ("FMAXNMP_asisdpair_only_SD" "SUInteger, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__4" "Vn"))
    )
  )
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fmaxnmp_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMAXNMP_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMAXNMP_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(rcwclrl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWCLRL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(ldsminb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSMINB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(sttp
  (c2m1
    ((gpr-64 gpr-64 memory immediate)
      ("STTP_64_ldstpair_post" "XZR, XZR, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__15"))
    )
    ((gpr-64 gpr-64 memory pre-index)
      ("STTP_64_ldstpair_pre" "XZR, XZR, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__15"))
    )
    ((simd-scalar simd-scalar memory immediate)
      ("STTP_Q_ldstpair_post" "QUInteger, QUInteger, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm__16"))
    )
    ((simd-scalar simd-scalar memory pre-index)
      ("STTP_Q_ldstpair_pre" "QUInteger, QUInteger, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm__16"))
    )
  )
  (c2m
    ((simd-scalar simd-scalar memory)
      ("STTP_Q_ldstpair_off" "QUInteger, QUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm7_option__3"))
    )
    ((gpr-64 gpr-64 memory)
      ("STTP_64_ldstpair_off" "XZR, XZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm7_option__2"))
    )
  )
)

(ctermne
  (c2
    ((gpr-32 gpr-32)
      ("ctermne_rr_" "WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ())
    )
  )
)

(ldnt1sh
  (c2m
    ((reg-list sve-p memory)
      ("ldnt1sh_z_p_ar_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("ldnt1sh_z_p_ar_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
    )
  )
)

(ld3w
  (c2
    ((reg-list sve-p)
      ("ld3w_z_p_br_contiguous" "{Z UInteger .S Z UInteger .S Z UInteger .S}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld3w_z_p_bi_contiguous" "{Z UInteger .S Z UInteger .S Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3"))
    )
  )
)

(sevl
  (c0
    (()
      ("SEVL_HI_hints" "" () ())
    )
  )
)

(sha1su1
  (c2
    ((simd-vector simd-vector)
      ("SHA1SU1_VV_cryptosha2" "VUInteger.4S, VUInteger.4S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6"))
    )
  )
)

(swpa
  (c2m
    ((gpr-64 gpr-64 memory)
      ("SWPA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("SWPA_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(fmlallbb
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMLALLBB_asimdsame2_G" "VUInteger.4S, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMLALLBB_asimdelem_J" "VUInteger.4S, VUInteger.16B, VUInteger.B[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__6"))
    )
    ((sve-z sve-z sve-z)
      ("fmlallbb_z32_z8z8z8_" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("fmlallbb_z32_z8z8z8i_" "ZUInteger.S, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__56"))
    )
  )
)

(fmlslt
  (c3
    ((sve-z sve-z sve-z)
      ("fmlslt_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
      ("fmlslt_z_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(ldbfadda
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDBFADDA_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(facgt
  (c4
    ((sve-p sve-p sve-z sve-z)
      ("facgt_p_p_zz_" "PUInteger.H, PUInteger/Z, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FACGT_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FACGT_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("FACGT_asisdsamefp16_only" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
      ("FACGT_asisdsame_only" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9" "V_option__9"))
    )
  )
)

(sqrdmlsh
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SQRDMLSH_asimdsame2_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("SQRDMLSH_asimdelem_R" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
    )
    ((simd-scalar simd-scalar simd-vector)
      ("SQRDMLSH_asisdelem_R" "HUInteger, HUInteger, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__8" "V_option__8" "Vm__5"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("SQRDMLSH_asisdsame2_only" "HUInteger, HUInteger, HUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__8" "V_option__8" "V_option__8"))
    )
    ((sve-z sve-z sve-z)
      ("sqrdmlsh_z_zzz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("sqrdmlsh_z_zzzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
      ("sqrdmlsh_z_zzzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__41"))
      ("sqrdmlsh_z_zzzi_d" "ZUInteger.D, ZUInteger.D, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__42"))
    )
  )
)

(fmlallbt
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMLALLBT_asimdsame2_G" "VUInteger.4S, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMLALLBT_asimdelem_J" "VUInteger.4S, VUInteger.16B, VUInteger.B[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__6"))
    )
    ((sve-z sve-z sve-z)
      ("fmlallbt_z32_z8z8z8_" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("fmlallbt_z32_z8z8z8i_" "ZUInteger.S, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__56"))
    )
  )
)

(gcssttr
  (c1m
    ((gpr-64 memory)
      ("GCSSTTR_64_ldst_gcs" "XZR, [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
    )
  )
)

(ld1b
  (c2
    ((reg-list sve-p)
      ("ld1b_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
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
      ("ld1b_za_p_rrr_" "{ZA0 H .B [W UInteger UInteger]}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("off4" (imm-range 0 15 1))) ("HV" "Ws__3" "offs__2" "Pg" "XnSP__3"))
    )
    ((reg-list sve-pn memory)
      ("ld1b_mz_p_br_2" "{Z UInteger .B- Z UInteger .B}, PNUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
      ("ld1b_mz_p_br_4" "{Z UInteger .B- Z UInteger .B}, PNUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
      ("ld1b_mz_p_bi_2" "{Z UInteger .B- Z UInteger .B}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
      ("ld1b_mz_p_bi_4" "{Z UInteger .B- Z UInteger .B}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
      ("ld1b_mzx_p_br_2x8" "{Z UInteger .B Z UInteger .B}, PNUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
      ("ld1b_mzx_p_br_4x4" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PNUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
      ("ld1b_mzx_p_bi_2x8" "{Z UInteger .B Z UInteger .B}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
      ("ld1b_mzx_p_bi_4x4" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
    )
  )
)

(sudot
  (c1
    ((sme-za)
      ("sudot_za_zzi_s2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
      ("sudot_za_zzi_s4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
      ("sudot_za_zzv_s2x1" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
      ("sudot_za_zzv_s4x1" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SUDOT_asimdelem_D" "VUInteger.2S, VUInteger.8B, VUInteger.4B[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "H_L"))
    )
    ((sve-z sve-z sve-z)
      ("sudot_z_zzzi_s" "ZUInteger.S, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__40"))
    )
  )
)

(ldur
  (c1m
    ((gpr-32 memory)
      ("LDUR_32_ldst_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
    ((simd-scalar memory)
      ("LDUR_B_ldst_unscaled" "BUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option" "imm9_option"))
      ("LDUR_Q_ldst_unscaled" "QUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option" "imm9_option"))
      ("LDUR_H_ldst_unscaled" "HUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option" "imm9_option"))
      ("LDUR_S_ldst_unscaled" "SUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option" "imm9_option"))
      ("LDUR_D_ldst_unscaled" "DUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option" "imm9_option"))
    )
    ((gpr-64 memory)
      ("LDUR_64_ldst_unscaled" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
    )
  )
)

(sm4ekey
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SM4EKEY_VVV4_cryptosha512_3" "VUInteger.4S, VUInteger.4S, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((sve-z sve-z sve-z)
      ("sm4ekey_z_zz_" "ZUInteger.S, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(cpymwn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYMWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(uabdlt
  (c3
    ((sve-z sve-z sve-z)
      ("uabdlt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(ldaxr
  (c1m
    ((gpr-32 memory)
      ("LDAXR_LR32_ldstexclr" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
    ((gpr-64 memory)
      ("LDAXR_LR64_ldstexclr" "XZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
    )
  )
)

(rcwsetl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSETL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(cbbne
  (c3
    ((gpr-32 gpr-32 immediate)
      ("CBBNE_8_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
    )
  )
)

(stfminnml
  (c1m
    ((simd-scalar memory)
      ("STFMINNML_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
      ("STFMINNML_32" "SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
      ("STFMINNML_64" "DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(umlal
  (c1
    ((sme-za)
      ("umlal_za_zzi_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
      ("umlal_za_zzi_2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm__2"))
      ("umlal_za_zzi_4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm__2"))
      ("umlal_za_zzv_2x1" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn2" "Zm__2"))
      ("umlal_za_zzv_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
      ("umlal_za_zzv_4x1" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn4" "Zm__2"))
      ("umlal_za_zzw_2x2" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("umlal_za_zzw_4x4" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("UMLAL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("UMLAL_asimdelem_L" "VUInteger.4S, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
    )
  )
)

(srshl
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("srshl_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SRSHL_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((reg-list reg-list sve-z)
      ("srshl_mz_zzv_2x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
      ("srshl_mz_zzv_4x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("SRSHL_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
    ((reg-list reg-list reg-list)
      ("srshl_mz_zzw_2x2" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
      ("srshl_mz_zzw_4x4" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
    )
  )
)

(saddlt
  (c3
    ((sve-z sve-z sve-z)
      ("saddlt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(fdup
  (c2
    ((sve-z float-const)
      ("fdup_z_i_" "ZUInteger.H, Real" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zd" (reg-range 0 31))) ("Zd"))
    )
  )
)

(cpyprt
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYPRT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(sumlall
  (c1
    ((sme-za)
      ("sumlall_za_zzi_s" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
      ("sumlall_za_zzi_s2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm__2"))
      ("sumlall_za_zzi_s4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm__2"))
      ("sumlall_za_zzv_s2x1" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger . B- Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn2" "Zm__2"))
      ("sumlall_za_zzv_s4x1" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger . B- Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn4" "Zm__2"))
    )
  )
)

(ushll
  (c3
    ((simd-vector simd-vector immediate)
      ("USHLL_asimdshf_L" "VUInteger.8H, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__new"))
    )
  )
)

(sli
  (c3
    ((simd-scalar simd-scalar immediate)
      ("SLI_asisdshf_R" "DUInteger, DUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
    ((simd-vector simd-vector immediate)
      ("SLI_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__5"))
    )
    ((sve-z sve-z immediate)
      ("sli_z_zzi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(cpyfertwn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFERTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(bfcvt
  (c2
    ((simd-scalar simd-scalar)
      ("BFCVT_BS_floatdp1" "HUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Sn"))
    )
    ((sve-z reg-list)
      ("bfcvt_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
      ("bfcvt_z8_mz2_" "ZUInteger.B, {Z UInteger .H- Z UInteger .H}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("bfcvt_z_p_z_s2bfz" "ZUInteger.H, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("bfcvt_z_p_z_s2bf" "ZUInteger.H, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(ld1d
  (c2
    ((reg-list sve-pn)
      ("ld1d_mz_p_br_2" "{Z UInteger .D- Z UInteger .D}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
      ("ld1d_mz_p_br_4" "{Z UInteger .D- Z UInteger .D}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
      ("ld1d_mzx_p_br_2x8" "{Z UInteger .D Z UInteger .D}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
      ("ld1d_mzx_p_br_4x4" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
    )
    ((reg-list sve-p)
      ("ld1d_z_p_br_u64" "{Z UInteger .D}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
      ("ld1d_z_p_br_u128" "{Z UInteger .Q}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
      ("ld1d_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ld1d_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ld1d_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld1d_z_p_bi_u128" "{Z UInteger .Q}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ld1d_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ld1d_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ld1d_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("ld1d_za_p_rrr_" "{ZA UInteger H .D [W UInteger UInteger]}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("ZAt" "HV" "Ws__3" "offs__3" "Pg" "XnSP__3"))
    )
    ((reg-list sve-pn memory)
      ("ld1d_mz_p_bi_2" "{Z UInteger .D- Z UInteger .D}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
      ("ld1d_mz_p_bi_4" "{Z UInteger .D- Z UInteger .D}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
      ("ld1d_mzx_p_bi_2x8" "{Z UInteger .D Z UInteger .D}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
      ("ld1d_mzx_p_bi_4x4" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
    )
  )
)

(pacibsp
  (c0
    (()
      ("PACIBSP_HI_hints" "" () ())
    )
  )
)

(cpyptn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYPTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(stllr
  (c1m
    ((gpr-32 memory)
      ("STLLR_SL32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
    ((gpr-64 memory)
      ("STLLR_SL64_ldstord" "XZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
    )
  )
)

(mla
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("mla_z_p_zzz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Pg" "Zn__2" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("MLA_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("MLA_asimdelem_R" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
    )
    ((sve-z sve-z sve-z)
      ("mla_z_zzzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
      ("mla_z_zzzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__41"))
      ("mla_z_zzzi_d" "ZUInteger.D, ZUInteger.D, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__42"))
    )
  )
)

(braaz
  (c1
    ((gpr-64)
      ("BRAAZ_64_branch_reg" "XZR" (("Rn" (reg-range 0 31))) ("XnOrXZR"))
    )
  )
)

(cpymtn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYMTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(rcwclr
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWCLR_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(cmple
  (c4
    ((sve-p sve-p sve-z immediate)
      ("cmple_p_p_zi_" "PUInteger.B, PUInteger/Z, ZUInteger.B, SInteger" (("size" (element-size B H S D)) ("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn" "imm__43"))
    )
    ((sve-p sve-p sve-z sve-z)
      ("cmple_p_p_zw_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
    )
  )
)

(cpyet
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYET_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(uqxtnb
  (c2
    ((sve-z sve-z)
      ("uqxtnb_z_zz_" "ZUInteger.B, ZUInteger.H" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(ldff1b
  (c2
    ((reg-list sve-p)
      ("ldff1b_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ldff1b_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1b_z_p_ai_s" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("ldff1b_z_p_br_u8" "{Z UInteger .B}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldff1b_z_p_br_u16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldff1b_z_p_br_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldff1b_z_p_br_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldff1b_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1b_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
    )
  )
)

(udot
  (c1
    ((sme-za)
      ("udot_za32_zzi_2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
      ("udot_za_zzi_s2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
      ("udot_za_zzi_d2xi" "ZA.D[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
      ("udot_za32_zzi_4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
      ("udot_za_zzi_s4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
      ("udot_za_zzi_d4xi" "ZA.D[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
      ("udot_za32_zzv_2x1" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
      ("udot_za32_zzv_4x1" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
      ("udot_za32_zzw_2x2" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("udot_za32_zzw_4x4" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("UDOT_asimdsame2_D" "VUInteger.2S, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "Vm"))
      ("UDOT_asimdelem_D" "VUInteger.2S, VUInteger.8B, VUInteger.4B[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2"))
    )
    ((sve-z sve-z sve-z)
      ("udot_z_zzz_" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("udot_z16_zzz_h" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("udot_z32_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("udot_z32_zzzi_" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__35"))
      ("udot_z_zzzi_s" "ZUInteger.S, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__40"))
      ("udot_z_zzzi_d" "ZUInteger.D, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__39"))
      ("udot_z16_zzzi_h" "ZUInteger.H, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__53"))
    )
  )
  (c1m2
    ((sme-za memory reg-list sve-z)
      ("udot_za_zzv_2x1" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
      ("udot_za_zzv_4x1" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
    )
    ((sme-za memory reg-list reg-list)
      ("udot_za_zzw_2x2" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("udot_za_zzw_4x4" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
)

(umulh
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("umulh_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((gpr-64 gpr-64 gpr-64)
      ("UMULH_64_dp_3src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__13" "XmOrXZR__9"))
    )
    ((sve-z sve-z sve-z)
      ("umulh_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(smlall
  (c1
    ((sme-za)
      ("smlall_za_zzi_s" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
      ("smlall_za_zzi_d" "ZA.D[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
      ("smlall_za_zzi_s2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm__2"))
      ("smlall_za_zzi_d2xi" "ZA.D[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm__2"))
      ("smlall_za_zzi_s4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm__2"))
      ("smlall_za_zzi_d4xi" "ZA.D[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm__2"))
    )
  )
  (c1m2
    ((sme-za memory reg-list sve-z)
      ("smlall_za_zzv_2x1" "ZA.S, [W UInteger UInteger : UInteger VGx2], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn2" "Zm__2"))
      ("smlall_za_zzv_4x1" "ZA.S, [W UInteger UInteger : UInteger VGx4], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn4" "Zm__2"))
    )
    ((sme-za memory reg-list reg-list)
      ("smlall_za_zzw_2x2" "ZA.S, [W UInteger UInteger : UInteger VGx2], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("smlall_za_zzw_4x4" "ZA.S, [W UInteger UInteger : UInteger VGx4], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
    ((sme-za memory sve-z sve-z)
      ("smlall_za_zzv_1" "ZA.S, [W UInteger UInteger : UInteger], ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
    )
  )
)

(sqshrnt
  (c3
    ((sve-z sve-z immediate)
      ("sqshrnt_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(autibz
  (c0
    (()
      ("AUTIBZ_HI_hints" "" () ())
    )
  )
)

(ldurh
  (c1m
    ((gpr-32 memory)
      ("LDURH_32_ldst_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
  )
)

(fcmla
  (c5
    ((sve-z sve-p sve-z sve-z immediate)
      ("fcmla_z_p_zzz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H, 0" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Pg" "Zn__2" "Zm"))
    )
  )
  (c4
    ((simd-vector simd-vector simd-vector immediate)
      ("FCMLA_asimdsame2_C" "VUInteger.4H, VUInteger.4H, VUInteger.4H, 0" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FCMLA_advsimd_elt" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger], 0" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2"))
    )
  )
  (c3
    ((sve-z sve-z sve-z)
      ("fcmla_z_zzzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger, 0" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__51"))
      ("fcmla_z_zzzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger, 0" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__52"))
    )
  )
)

(ssubltb
  (c3
    ((sve-z sve-z sve-z)
      ("ssubltb_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(mrrs
  (c3
    ((gpr-64 gpr-64 system-reg)
      ("MRRS_RS_systemmovepr" "XZR, XUInteger, ACTLR_EL3" (("Rt" (reg-range 0 31))) ("XtOrXZR__7" "XtPlus1__2"))
    )
  )
)

(ldumaxalh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDUMAXALH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ands
  (c5
    ((gpr-32 gpr-32 gpr-32 keyword immediate)
      ("ANDS_32_log_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64 keyword immediate)
      ("ANDS_64_log_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
  )
  (c4
    ((sve-p sve-p sve-p sve-p)
      ("ands_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
    )
  )
  (c3
    ((gpr-64 gpr-64 immediate)
      ("ANDS_64S_log_imm" "XZR, XZR, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11" "imm__bitmask_x"))
    )
    ((gpr-32 gpr-32 immediate)
      ("ANDS_32S_log_imm" "WZR, WZR, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR" "imm__bitmask_w"))
    )
  )
)

(saddl
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SADDL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(fminnmv
  (c2
    ((simd-scalar simd-vector)
      ("FMINNMV_asimdall_only_H" "HUInteger, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_hv" "Vn"))
      ("FMINNMV_asimdall_only_SD" "SUInteger, VUInteger.4S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vn"))
    )
  )
  (c3
    ((simd-scalar sve-p sve-z)
      ("fminnmv_v_p_z_" "HUInteger, PUInteger, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V__5" "Pg" "Zn"))
    )
  )
)

(urhadd
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("urhadd_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("URHADD_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(frint32x
  (c2
    ((simd-vector simd-vector)
      ("FRINT32X_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("FRINT32X_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
      ("FRINT32X_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("frint32x_z_p_z_z" "ZUInteger.S, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("frint32x_z_p_z_m" "ZUInteger.S, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(saddlp
  (c2
    ((simd-vector simd-vector)
      ("SADDLP_asimdmisc_P" "VUInteger.4H, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
  )
)

(adclt
  (c3
    ((sve-z sve-z sve-z)
      ("adclt_z_zzz_" "ZUInteger.S, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(uqsubr
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("uqsubr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
)

(ldfminnma
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDFMINNMA_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMINNMA_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMINNMA_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(ldtadd
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDTADD_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDTADD_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ldtxr
  (c1m
    ((gpr-32 memory)
      ("LDTXR_LR32_ldstexclr_unpriv" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
    ((gpr-64 memory)
      ("LDTXR_LR64_ldstexclr_unpriv" "XZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
    )
  )
)

(caspalt
  (c4m
    ((gpr-64 gpr-64 gpr-64 gpr-64 memory)
      ("CASPALT_CP64_comswappr_unpriv" "XUInteger, XUInteger, XUInteger, XUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
    )
  )
)

(raddhnb
  (c3
    ((sve-z sve-z sve-z)
      ("raddhnb_z_zz_" "ZUInteger.B, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(uabalb
  (c3
    ((sve-z sve-z sve-z)
      ("uabalb_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(eret
  (c0
    (()
      ("ERET_64E_branch_reg" "" () ())
    )
  )
)

(lsrv
  (c3
    ((gpr-32 gpr-32 gpr-32)
      ("LSRV_32_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__4"))
    )
    ((gpr-64 gpr-64 gpr-64)
      ("LSRV_64_dp_2src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__7"))
    )
  )
)

(sumops
  (c5
    ((sme-za sve-p sve-p sve-z sve-z)
      ("sumops_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
      ("sumops_za_pp_zz_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn__2" "Zm"))
    )
  )
)

(uqadd
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("uqadd_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((sve-z sve-z immediate)
      ("uqadd_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__27"))
    )
    ((simd-vector simd-vector simd-vector)
      ("UQADD_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("UQADD_asisdsame_only" "BUInteger, BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7" "V_option__7"))
    )
    ((sve-z sve-z sve-z)
      ("uqadd_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(fcadd
  (c5
    ((sve-z sve-p sve-z sve-z immediate)
      ("fcadd_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H, 90" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c4
    ((simd-vector simd-vector simd-vector immediate)
      ("FCADD_asimdsame2_C" "VUInteger.4H, VUInteger.4H, VUInteger.4H, 90" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(sub
  (c5
    ((gpr-64 gpr-64 gpr-32 keyword immediate)
      ("SUB_64_addsub_ext" "SP, SP, WZR, UXTB, UInteger" (("Rm" (reg-range 0 31)) ("imm3" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option" "XnSP_option__6"))
    )
    ((gpr-32 gpr-32 gpr-32 keyword immediate)
      ("SUB_32_addsub_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64 keyword immediate)
      ("SUB_64_addsub_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
  )
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("sub_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c1m1
    ((sme-za memory reg-list)
      ("sub_za_zw_2x2" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1" "Zm2"))
      ("sub_za_zw_4x4" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1__2" "Zm4"))
    )
  )
  (c3
    ((gpr-64 gpr-64 immediate)
      ("SUB_64_addsub_imm" "SP, SP, UInteger" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option" "XnSP_option__3" "imm__17"))
    )
    ((sve-z sve-z immediate)
      ("sub_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__27"))
    )
    ((gpr-32 gpr-32 immediate)
      ("SUB_32_addsub_imm" "WSP, WSP, UInteger" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdWSP_option" "WnWSP_option" "imm__17"))
    )
    ((simd-vector simd-vector simd-vector)
      ("SUB_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((gpr-32 gpr-32 gpr-32)
      ("SUB_32_addsub_ext" "WSP, WSP, WZR" (("Rm" (reg-range 0 31)) ("imm3" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdWSP_option" "WnWSP_option__2" "WmOrWZR__2"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("SUB_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
    ((sve-z sve-z sve-z)
      ("sub_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
  (c1m2
    ((sme-za memory reg-list sve-z)
      ("sub_za_zzv_2x1" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}, ZUInteger.S" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
      ("sub_za_zzv_4x1" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}, ZUInteger.S" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
    )
    ((sme-za memory reg-list reg-list)
      ("sub_za_zzw_2x2" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}, {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("sub_za_zzw_4x4" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}, {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
)

(nands
  (c4
    ((sve-p sve-p sve-p sve-p)
      ("nands_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
    )
  )
)

(uqincb
  (c1
    ((gpr-64)
      ("uqincb_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
    ((gpr-32)
      ("uqincb_r_rs_uw" "WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Wdn"))
    )
  )
)

(ldaxp
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDAXP_LP64_ldstexclp" "XZR, XZR, [SP 0]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDAXP_LP32_ldstexclp" "WZR, WZR, [SP 0]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option"))
    )
  )
)

(bfmul
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("bfmul_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((reg-list reg-list sve-z)
      ("bfmul_mz_zzv_2x1" "{Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__2" "Zn2__2" "Zm__2"))
      ("bfmul_mz_zzv_4x1" "{Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__3" "Zn4__2" "Zm__2"))
    )
    ((reg-list reg-list reg-list)
      ("bfmul_mz_zzw_2x2" "{Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("bfmul_mz_zzw_4x4" "{Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
    ((sve-z sve-z sve-z)
      ("bfmul_z_zzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__36"))
      ("bfmul_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(bfmlsl
  (c1
    ((sme-za)
      ("bfmlsl_za_zzi_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
      ("bfmlsl_za_zzi_2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm__2"))
      ("bfmlsl_za_zzi_4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm__2"))
      ("bfmlsl_za_zzv_2x1" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn2" "Zm__2"))
      ("bfmlsl_za_zzv_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
      ("bfmlsl_za_zzv_4x1" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn4" "Zm__2"))
      ("bfmlsl_za_zzw_2x2" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("bfmlsl_za_zzw_4x4" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
)

(ldclral
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDCLRAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDCLRAL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(msub
  (c4
    ((gpr-32 gpr-32 gpr-32 gpr-32)
      ("MSUB_32A_dp_3src" "WZR, WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__5" "WmOrWZR__6" "WaOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64 gpr-64)
      ("MSUB_64A_dp_3src" "XZR, XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__13" "XmOrXZR__9" "XaOrXZR__2"))
    )
  )
)

(cpyprn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYPRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(cpymrtn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYMRTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(rcwswppl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSWPPL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(ldumin
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDUMIN_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDUMIN_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(uaddwt
  (c3
    ((sve-z sve-z sve-z)
      ("uaddwt_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(cbbhi
  (c3
    ((gpr-32 gpr-32 immediate)
      ("CBBHI_8_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
    )
  )
)

(stbfmaxnml
  (c1m
    ((simd-scalar memory)
      ("STBFMAXNML_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(pmullt
  (c3
    ((sve-z sve-z sve-z)
      ("pmullt_z_zz_q" "ZUInteger.Q, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
      ("pmullt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(frint32z
  (c2
    ((simd-vector simd-vector)
      ("FRINT32Z_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("FRINT32Z_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
      ("FRINT32Z_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("frint32z_z_p_z_z" "ZUInteger.S, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("frint32z_z_p_z_m" "ZUInteger.S, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(sqincw
  (c2
    ((gpr-64 gpr-32)
      ("sqincw_r_rs_sx" "XUInteger, WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn" "Wdn"))
    )
  )
  (c1
    ((gpr-64)
      ("sqincw_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
    ((sve-z)
      ("sqincw_z_zs_" "ZUInteger.S" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
    )
  )
)

(hvc
  (c1
    ((immediate)
      ("HVC_EX_exception" "UInteger" (("imm16" (imm-range 0 65535 1))) ("imm"))
    )
  )
)

(swppal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("SWPPAL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(ldclrpa
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDCLRPA_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(cnot
  (c3
    ((sve-z sve-p sve-z)
      ("cnot_z_p_z_m" "ZUInteger.B, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("cnot_z_p_z_z" "ZUInteger.B, PUInteger/Z, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(ld1h
  (c2
    ((reg-list sve-pn)
      ("ld1h_mz_p_br_2" "{Z UInteger .H- Z UInteger .H}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
      ("ld1h_mz_p_br_4" "{Z UInteger .H- Z UInteger .H}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
      ("ld1h_mzx_p_br_2x8" "{Z UInteger .H Z UInteger .H}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
      ("ld1h_mzx_p_br_4x4" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
    )
    ((reg-list sve-p)
      ("ld1h_z_p_bz_s_x32_scaled" "{Z UInteger .S}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ld1h_z_p_br_u16" "{Z UInteger .H}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
      ("ld1h_z_p_br_u32" "{Z UInteger .S}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
      ("ld1h_z_p_br_u64" "{Z UInteger .D}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
      ("ld1h_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ld1h_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ld1h_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld1h_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ld1h_z_p_ai_s" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("ld1h_z_p_bi_u16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ld1h_z_p_bi_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ld1h_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ld1h_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ld1h_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("ld1h_za_p_rrr_" "{ZA UInteger H .H [W UInteger UInteger]}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("ZAt__2" "HV" "Ws__3" "offs__4" "Pg" "XnSP__3"))
    )
    ((reg-list sve-pn memory)
      ("ld1h_mz_p_bi_2" "{Z UInteger .H- Z UInteger .H}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
      ("ld1h_mz_p_bi_4" "{Z UInteger .H- Z UInteger .H}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
      ("ld1h_mzx_p_bi_2x8" "{Z UInteger .H Z UInteger .H}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
      ("ld1h_mzx_p_bi_4x4" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
    )
  )
)

(ld1rqh
  (c2
    ((reg-list sve-p)
      ("ld1rqh_z_p_br_contiguous" "{Z UInteger .H}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld1rqh_z_p_bi_u16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
  )
)

(ldsetpa
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDSETPA_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(pacia1716
  (c0
    (()
      ("PACIA1716_HI_hints" "" () ())
    )
  )
)

(rax1
  (c3
    ((simd-vector simd-vector simd-vector)
      ("RAX1_VVV2_cryptosha512_3" "VUInteger.2D, VUInteger.2D, VUInteger.2D" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((sve-z sve-z sve-z)
      ("rax1_z_zz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(fmaxqv
  (c3
    ((simd-vector sve-p sve-z)
      ("fmaxqv_z_p_z_" "VUInteger.8H, PUInteger, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
    )
  )
)

(smullb
  (c3
    ((sve-z sve-z sve-z)
      ("smullb_z_zzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__78"))
      ("smullb_z_zzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__2" "imm__88"))
      ("smullb_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(yield
  (c0
    (()
      ("YIELD_HI_hints" "" () ())
    )
  )
)

(rcwcasp
  (c4m
    ((gpr-64 gpr-64 gpr-64 gpr-64 memory)
      ("RCWCASP_C64_rcwcomswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
    )
  )
)

(crc32b
  (c3
    ((gpr-32 gpr-32 gpr-32)
      ("CRC32B_32C_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR__2" "WnOrWZR__4" "WmOrWZR__5"))
    )
  )
)

(rcwcasl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWCASL_C64_rcwcomswap" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
    )
  )
)

(stgm
  (c1m
    ((gpr-64 memory)
      ("STGM_64bulk_ldsttags" "XZR, [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__3" "XnSP_option"))
    )
  )
)

(cbhne
  (c3
    ((gpr-32 gpr-32 immediate)
      ("CBHNE_16_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
    )
  )
)

(umaxp
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("umaxp_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("UMAXP_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(ucvtf
  (c2
    ((simd-vector simd-vector)
      ("UCVTF_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("UCVTF_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar gpr-64)
      ("UCVTF_S64_float2int" "SUInteger, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "XnOrXZR__11"))
      ("UCVTF_D64_float2int" "DUInteger, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "XnOrXZR__11"))
      ("UCVTF_H64_float2int" "HUInteger, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "XnOrXZR__11"))
    )
    ((reg-list reg-list)
      ("ucvtf_mz_z_2" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__4" "Zn2__3"))
      ("ucvtf_mz_z_4" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
    )
    ((sve-z sve-z)
      ("ucvtf_z_z_" "ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
    ((simd-scalar simd-scalar)
      ("UCVTF_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
      ("UCVTF_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
      ("UCVTF_sisd_32D" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
      ("UCVTF_sisd_32H" "HUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Sn"))
      ("UCVTF_sisd_64H" "HUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Dn"))
      ("UCVTF_sisd_64S" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
    )
    ((simd-scalar gpr-32)
      ("UCVTF_S32_float2int" "SUInteger, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "WnOrWZR"))
      ("UCVTF_D32_float2int" "DUInteger, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "WnOrWZR"))
      ("UCVTF_H32_float2int" "HUInteger, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "WnOrWZR"))
    )
  )
  (c3
    ((simd-scalar simd-scalar immediate)
      ("UCVTF_asisdshf_C" "HUInteger, HUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__6" "V_option__6" "immh_shift__3"))
    )
    ((simd-vector simd-vector immediate)
      ("UCVTF_asimdshf_C" "VUInteger.4H, VUInteger.4H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__9"))
    )
    ((sve-z sve-p sve-z)
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
    )
    ((simd-scalar gpr-64 immediate)
      ("UCVTF_S64_float2fix" "SUInteger, XZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "XnOrXZR__11"))
      ("UCVTF_D64_float2fix" "DUInteger, XZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "XnOrXZR__11"))
      ("UCVTF_H64_float2fix" "HUInteger, XZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "XnOrXZR__11"))
    )
    ((simd-scalar gpr-32 immediate)
      ("UCVTF_S32_float2fix" "SUInteger, WZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "WnOrWZR"))
      ("UCVTF_D32_float2fix" "DUInteger, WZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "WnOrWZR"))
      ("UCVTF_H32_float2fix" "HUInteger, WZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "WnOrWZR"))
    )
  )
)

(xar
  (c4
    ((sve-z sve-z sve-z immediate)
      ("xar_z_zzi_" "ZUInteger.B, ZUInteger.B, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm"))
    )
    ((simd-vector simd-vector simd-vector immediate)
      ("XAR_VVV2_crypto3_imm6" "VUInteger.2D, VUInteger.2D, VUInteger.2D, UInteger" (("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm" "imm6"))
    )
  )
)

(bc
  (c1
    ((immediate)
      ("BC_only_condbranch" "SInteger" (("imm19" (imm-range 0 524287 1))) ("imm19_offset"))
    )
  )
)

(pacdza
  (c1
    ((gpr-64)
      ("PACDZA_64Z_dp_1src" "XZR" (("Rd" (reg-range 0 31))) ("XdOrXZR__6"))
    )
  )
)

(sqrdcmlah
  (c4
    ((sve-z sve-z sve-z immediate)
      ("sqrdcmlah_z_zzz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B, 0" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
  (c3
    ((sve-z sve-z sve-z)
      ("sqrdcmlah_z_zzzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger, 0" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__41"))
      ("sqrdcmlah_z_zzzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger, 0" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__42"))
    )
  )
)

(st3w
  (c2
    ((reg-list sve-p)
      ("st3w_z_p_br_contiguous" "{Z UInteger .S Z UInteger .S Z UInteger .S}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("st3w_z_p_bi_contiguous" "{Z UInteger .S Z UInteger .S Z UInteger .S}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3"))
    )
  )
)

(setmt
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETMT_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__3" "XnOrXZR__6" "XsOrXZR__7"))
    )
  )
)

(smsubl
  (c4
    ((gpr-64 gpr-32 gpr-32 gpr-64)
      ("SMSUBL_64WA_dp_3src" "XZR, WZR, WZR, XZR" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "WnOrWZR__5" "WmOrWZR__6" "XaOrXZR__2"))
    )
  )
)

(ldff1sw
  (c2
    ((reg-list sve-p)
      ("ldff1sw_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1sw_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1sw_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ldff1sw_z_p_br_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldff1sw_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1sw_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
    )
  )
)

(luti6
  (c3m
    ((reg-list reg-list reg-list memory)
      ("luti6_mz4_zmz2_1" "{Z UInteger .H - Z UInteger .H}, {Z UInteger .H Z UInteger .H}, {Z UInteger - Z UInteger}, [UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__7" "Zn2__5" "Zm1__5" "Zm2__3"))
      ("luti6_mz4_zmz2_4" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, {Z UInteger .H Z UInteger .H}, {Z UInteger - Z UInteger}, [UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 3))) ("Zd1__4" "Zd2__3" "Zd3" "Zd4__2" "Zn1__7" "Zn2__5" "Zm1__5" "Zm2__3"))
    )
  )
  (c3
    ((reg-list sme-zt reg-list)
      ("luti6_mz4_ztmz3_1" "{Z UInteger .B - Z UInteger .B}, ZT0, {Z UInteger - Z UInteger}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__9" "Zn3"))
      ("luti6_mz4_ztmz3_4" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, ZT0, {Z UInteger - Z UInteger}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 3))) ("Zd1__4" "Zd2__3" "Zd3" "Zd4__2" "Zn1__9" "Zn3"))
    )
    ((sve-z reg-list sve-z)
      ("luti6_z_zzz_8" "ZUInteger.B, {Z UInteger .B Z UInteger .B}, ZUInteger" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__7" "Zn2__5" "Zm__5"))
      ("luti6_z_zzz_16" "ZUInteger.H, {Z UInteger .H Z UInteger .H}, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__7" "Zn2__5" "Zm__5"))
    )
    ((sve-z sme-zt sve-z)
      ("luti6_z_ztz_" "ZUInteger.B, ZT0, ZUInteger" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(revw
  (c3
    ((sve-z sve-p sve-z)
      ("revw_z_z_m" "ZUInteger.D, PUInteger/M, ZUInteger.D" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("revw_z_z_z" "ZUInteger.D, PUInteger/Z, ZUInteger.D" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(stfminl
  (c1m
    ((simd-scalar memory)
      ("STFMINL_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
      ("STFMINL_32" "SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
      ("STFMINL_64" "DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(stbfaddl
  (c1m
    ((simd-scalar memory)
      ("STBFADDL_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(smlalt
  (c3
    ((sve-z sve-z sve-z)
      ("smlalt_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("smlalt_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
      ("smlalt_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
    )
  )
)

(cfinv
  (c0
    (()
      ("CFINV_M_pstate" "" () ())
    )
  )
)

(sumop4a
  (c3
    ((sme-za reg-list sve-z)
      ("sumop4a_za_zz_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
      ("sumop4a_za_zz_h2x1" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
    )
    ((sme-za reg-list reg-list)
      ("sumop4a_za_zz_b2x2" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("sumop4a_za_zz_h2x2" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
    ((sme-za sve-z sve-z)
      ("sumop4a_za_zz_b1x1" "ZAUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
      ("sumop4a_za_zz_h1x1" "ZAUInteger.D, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm_mortlach"))
    )
    ((sme-za sve-z reg-list)
      ("sumop4a_za_zz_b1x2" "ZAUInteger.S, ZUInteger.B, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("sumop4a_za_zz_h1x2" "ZAUInteger.D, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
  )
)

(rdvl
  (c2
    ((gpr-64 immediate)
      ("rdvl_r_i_" "XUInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("Rd" (reg-range 0 31))) ("Xd__2" "imm__28"))
    )
  )
)

(rcwsetpl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSETPL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(ldclrah
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDCLRAH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(brkns
  (c4
    ((sve-p sve-p sve-p sve-p)
      ("brkns_p_p_pp_" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pdm" (reg-range 0 15))) ("Pdm" "Pg__2" "Pn__2" "Pdm"))
    )
  )
)

(st1b
  (c2m
    ((reg-list sve-p memory)
      ("st1b_z_p_br_" "{Z UInteger . B}, PUInteger, [SP X UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
      ("st1b_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("st1b_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("st1b_z_p_bz_d_64_unscaled" "{Z UInteger . D}, PUInteger, [SP Z UInteger . D]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("st1b_z_p_ai_d" "{Z UInteger .D}, PUInteger, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("st1b_z_p_ai_s" "{Z UInteger .S}, PUInteger, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("st1b_z_p_bi_" "{Z UInteger . B}, PUInteger, [SP]" (("size" (element-size B H S D)) ("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("st1b_za_p_rrr_" "{ZA0 H .B [W UInteger UInteger]}, PUInteger, [SP]" (("Rm" (reg-range 0 31)) ("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("off4" (imm-range 0 15 1))) ("HV" "Ws__3" "offs__2" "Pg" "XnSP__3"))
    )
    ((reg-list sve-pn memory)
      ("st1b_mz_p_br_2" "{Z UInteger .B- Z UInteger .B}, PNUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
      ("st1b_mz_p_br_4" "{Z UInteger .B- Z UInteger .B}, PNUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
      ("st1b_mz_p_bi_2" "{Z UInteger .B- Z UInteger .B}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
      ("st1b_mz_p_bi_4" "{Z UInteger .B- Z UInteger .B}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
      ("st1b_mzx_p_br_2x8" "{Z UInteger .B Z UInteger .B}, PNUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
      ("st1b_mzx_p_br_4x4" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PNUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
      ("st1b_mzx_p_bi_2x8" "{Z UInteger .B Z UInteger .B}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
      ("st1b_mzx_p_bi_4x4" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
    )
  )
)

(ldtaddl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDTADDL_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDTADDL_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(pacnbiasppc
  (c0
    (()
      ("PACNBIASPPC_64LR_dp_1src" "" () ())
    )
  )
)

(hint
  (c1
    ((immediate)
      ("HINT_HM_hints" "UInteger" () ())
    )
  )
)

(cpyen
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYEN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(subp
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("subp_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((gpr-64 gpr-64 gpr-64)
      ("SUBP_64S_dp_2src" "XZR, SP, SP" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__6" "XmSP_option__2"))
    )
  )
)

(bf1cvtlt
  (c2
    ((sve-z sve-z)
      ("bf1cvtlt_z_z8_b2bf" "ZUInteger.H, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(cmgt
  (c3
    ((simd-scalar simd-scalar immediate)
      ("CMGT_asisdmisc_Z" "DUInteger, DUInteger, 0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
    ((simd-vector simd-vector immediate)
      ("CMGT_asimdmisc_Z" "VUInteger.8B, VUInteger.8B, 0" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-vector simd-vector simd-vector)
      ("CMGT_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("CMGT_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
  )
)

(ldaddalh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDADDALH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(fmad
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fmad_z_p_zzz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Za" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zm" "Za"))
    )
  )
)

(setf8
  (c1
    ((gpr-32)
      ("SETF8_only_setf" "WZR" (("Rn" (reg-range 0 31))) ("WnOrWZR"))
    )
  )
)

(ldeorl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDEORL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDEORL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(bfmin
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("bfmin_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((reg-list reg-list sve-z)
      ("bfmin_mz_zzv_2x1" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
      ("bfmin_mz_zzv_4x1" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
    )
    ((reg-list reg-list reg-list)
      ("bfmin_mz_zzw_2x2" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, {Z UInteger . H- Z UInteger . H}" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
      ("bfmin_mz_zzw_4x4" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, {Z UInteger . H- Z UInteger . H}" (("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
    )
  )
)

(cpyfmtrn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFMTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(lsrr
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("lsrr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
)

(ldumaxalb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDUMAXALB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(pacib171615
  (c0
    (()
      ("PACIB171615_64LR_dp_1src" "" () ())
    )
  )
)

(sha256su1
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SHA256SU1_VVV_cryptosha3" "VUInteger.4S, VUInteger.4S, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6" "Vm__7"))
    )
  )
)

(fabs
  (c2
    ((simd-vector simd-vector)
      ("FABS_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FABS_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("FABS_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
      ("FABS_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
      ("FABS_H_floatdp1" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("fabs_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("fabs_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(ldumax
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDUMAX_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDUMAX_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(addvl
  (c3
    ((gpr-64 gpr-64 immediate)
      ("addvl_r_ri_" "SP, SP, SInteger" (("Rn" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rd" (reg-range 0 31))) ("XdSP__2" "XnSP__2" "imm__28"))
    )
  )
)

(tbx
  (c3
    ((simd-vector reg-list simd-vector)
      ("TBX_asimdtbl_L1_1" "VUInteger.8B, {V UInteger . 16B}, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__3" "Vm__3"))
      ("TBX_asimdtbl_L2_2" "VUInteger.8B, {V UInteger . 16B V UInteger . 16B}, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__4" "VnPlus1" "Vm__3"))
      ("TBX_asimdtbl_L3_3" "VUInteger.8B, {V UInteger . 16B V UInteger . 16B V UInteger . 16B}, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__4" "VnPlus1" "VnPlus2" "Vm__3"))
      ("TBX_asimdtbl_L4_4" "VUInteger.8B, {V UInteger . 16B V UInteger . 16B V UInteger . 16B V UInteger . 16B}, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__4" "VnPlus1" "VnPlus2" "VnPlus3" "Vm__3"))
    )
    ((sve-z sve-z sve-z)
      ("tbx_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(sqcvt
  (c2
    ((sve-z reg-list)
      ("sqcvt_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
      ("sqcvt_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
    )
  )
)

(luti2
  (c3
    ((sve-z reg-list sve-z)
      ("luti2_z_zz_8" "ZUInteger.B, {Z UInteger .B}, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__4" "Zm__5"))
      ("luti2_z_zz_16" "ZUInteger.H, {Z UInteger .H}, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__4" "Zm__5"))
    )
    ((simd-vector reg-list simd-element)
      ("LUTI2_asimdtbl_L5" "VUInteger.16B, {V UInteger . 16B}, VUInteger[UInteger]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__3" "Vm__4"))
      ("LUTI2_asimdtbl_L6" "VUInteger.8H, {V UInteger . 8H}, VUInteger[UInteger]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__3" "Vm__4"))
    )
    ((sve-z sme-zt sve-z)
      ("luti2_z_ztz_" "ZUInteger.B, ZT0, ZUInteger[UInteger]" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
    ((reg-list sme-zt sve-z)
      ("luti2_mz2_ztz_1" "{Z UInteger . B - Z UInteger . B}, ZT0, ZUInteger[UInteger]" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
      ("luti2_mz4_ztz_1" "{Z UInteger . B - Z UInteger . B}, ZT0, ZUInteger[UInteger]" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn"))
      ("luti2_mz2_ztz_8" "{Z UInteger . B Z UInteger . B}, ZT0, ZUInteger[UInteger]" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 7))) ("Zd1__3" "Zd2__2" "Zn"))
      ("luti2_mz4_ztz_4" "{Z UInteger . B Z UInteger . B Z UInteger . B Z UInteger . B}, ZT0, ZUInteger[UInteger]" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 3))) ("Zd1__4" "Zd2__3" "Zd3" "Zd4__2" "Zn"))
    )
  )
)

(sshllb
  (c3
    ((sve-z sve-z immediate)
      ("sshllb_z_zi_" "ZUInteger.H, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(ssubw
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SSUBW_asimddiff_W" "VUInteger.8H, VUInteger.8H, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(fcmle
  (c4
    ((sve-p sve-p sve-z float-const)
      ("fcmle_p_p_z0_" "PUInteger.H, PUInteger/Z, ZUInteger.H, 0.0" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn"))
    )
  )
  (c3
    ((simd-scalar simd-scalar float-const)
      ("FCMLE_asisdmiscfp16_FZ" "HUInteger, HUInteger, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
      ("FCMLE_asisdmisc_FZ" "SUInteger, SUInteger, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
    )
    ((simd-vector simd-vector float-const)
      ("FCMLE_asimdmiscfp16_FZ" "VUInteger.4H, VUInteger.4H, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FCMLE_asimdmisc_FZ" "VUInteger.2S, VUInteger.2S, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
  )
)

(whilelt
  (c4
    ((sve-pn gpr-64 gpr-64 vector-length)
      ("whilelt_pn_rr_" "PNUInteger.B, XUInteger, XUInteger, VLx2" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("PNd" (reg-range 0 7))) ("PNd" "Xn__4" "Xm__6"))
    )
  )
  (c3
    ((reg-list gpr-64 gpr-64)
      ("whilelt_pp_rr_" "{P UInteger . B P UInteger . B}, XUInteger, XUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 7))) ("Pd1__2" "Pd2__2" "Xn__4" "Xm__6"))
    )
    ((sve-p gpr-32 gpr-32)
      ("whilelt_p_p_rr_" "PUInteger.B, WZR, WZR" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd"))
    )
  )
)

(tbz
  (c3
    ((gpr-32 immediate immediate)
      ("TBZ_only_testbranch" "WZR, UInteger, SInteger" (("imm14" (imm-range 0 16383 1)) ("Rt" (reg-range 0 31))) ("imm_0_63" "imm14_offset"))
    )
  )
)

(rcwclrp
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWCLRP_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(casb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("CASB_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
    )
  )
)

(ssubwt
  (c3
    ((sve-z sve-z sve-z)
      ("ssubwt_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(rev16
  (c2
    ((simd-vector simd-vector)
      ("REV16_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((gpr-64 gpr-64)
      ("REV16_64_dp_1src" "XZR, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
    )
    ((gpr-32 gpr-32)
      ("REV16_32_dp_1src" "WZR, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
    )
  )
)

(fnmul
  (c3
    ((simd-scalar simd-scalar simd-scalar)
      ("FNMUL_S_floatdp2" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__3" "Sm"))
      ("FNMUL_D_floatdp2" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__2" "Dm"))
      ("FNMUL_H_floatdp2" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
    )
  )
)

(ld1rw
  (c2m
    ((reg-list sve-p memory)
      ("ld1rw_z_p_bi_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ld1rw_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
  )
)

(sabalb
  (c3
    ((sve-z sve-z sve-z)
      ("sabalb_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(usvdot
  (c1
    ((sme-za)
      ("usvdot_za_zzi_s4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
    )
  )
)

(cbhhi
  (c3
    ((gpr-32 gpr-32 immediate)
      ("CBHHI_16_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
    )
  )
)

(ldtnp
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDTNP_Q_ldstnapair_offs" "QUInteger, QUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm7_option__3"))
    )
    ((gpr-64 gpr-64 memory)
      ("LDTNP_64_ldstnapair_offs" "XZR, XZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm7_option__2"))
    )
  )
)

(rcwscasa
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSCASA_C64_rcwcomswap" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
    )
  )
)

(mova
  (c2
    ((reg-list sme-za)
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
  )
  (c1
    ((sme-za)
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
    )
  )
  (c3
    ((sve-z sve-p sme-za)
      ("mova_z_p_rza_b" "ZUInteger.B, PUInteger/M, ZA0H.B[WUInteger, UInteger" (("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("off4" (imm-range 0 15 1)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "HV__4" "Ws__3" "offs__2"))
      ("mova_z_p_rza_h" "ZUInteger.H, PUInteger/M, ZAUIntegerH.H[WUInteger, UInteger" (("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("off3" (imm-range 0 7 1)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "ZAn__2" "HV__4" "Ws__3" "offs__4"))
      ("mova_z_p_rza_w" "ZUInteger.S, PUInteger/M, ZAUIntegerH.S[WUInteger, UInteger" (("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("off2" (imm-range 0 3 1)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "ZAn__3" "HV__4" "Ws__3" "offs__6"))
      ("mova_z_p_rza_d" "ZUInteger.D, PUInteger/M, ZAUIntegerH.D[WUInteger, UInteger" (("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "ZAn" "HV__4" "Ws__3" "offs__3"))
      ("mova_z_p_rza_q" "ZUInteger.Q, PUInteger/M, ZAUIntegerH.Q[WUInteger, 0" (("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "ZAn__4" "HV__4" "Ws__3" "offs__5"))
    )
  )
)

(caspat
  (c4m
    ((gpr-64 gpr-64 gpr-64 gpr-64 memory)
      ("CASPAT_CP64_comswappr_unpriv" "XUInteger, XUInteger, XUInteger, XUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
    )
  )
)

(rcwsset
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSSET_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(cls
  (c2
    ((simd-vector simd-vector)
      ("CLS_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((gpr-64 gpr-64)
      ("CLS_64_dp_1src" "XZR, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
    )
    ((gpr-32 gpr-32)
      ("CLS_32_dp_1src" "WZR, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("cls_z_p_z_m" "ZUInteger.B, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("cls_z_p_z_z" "ZUInteger.B, PUInteger/Z, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(setmn
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETMN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__3" "XnOrXZR__6" "XsOrXZR__7"))
    )
  )
)

(rcwsclr
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSCLR_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(ldeorh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDEORH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(fminnmp
  (c2
    ((simd-scalar simd-vector)
      ("FMINNMP_asisdpair_only_H" "HUInteger, VUInteger.2H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vn"))
      ("FMINNMP_asisdpair_only_SD" "SUInteger, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__4" "Vn"))
    )
  )
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fminnmp_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMINNMP_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMINNMP_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(gmi
  (c3
    ((gpr-64 gpr-64 gpr-64)
      ("GMI_64G_dp_2src" "XZR, SP, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__6" "XmOrXZR__4"))
    )
  )
)

(movaz
  (c2
    ((sve-z sme-za)
      ("movaz_z_rza_b" "ZUInteger.B, ZA0H.B[WUInteger, UInteger" (("Rs" (reg-range 0 3)) ("off4" (imm-range 0 15 1)) ("Zd" (reg-range 0 31))) ("Zd" "HV__4" "Ws__3" "offs__2"))
      ("movaz_z_rza_h" "ZUInteger.H, ZAUIntegerH.H[WUInteger, UInteger" (("Rs" (reg-range 0 3)) ("off3" (imm-range 0 7 1)) ("Zd" (reg-range 0 31))) ("Zd" "ZAn__2" "HV__4" "Ws__3" "offs__4"))
      ("movaz_z_rza_w" "ZUInteger.S, ZAUIntegerH.S[WUInteger, UInteger" (("Rs" (reg-range 0 3)) ("off2" (imm-range 0 3 1)) ("Zd" (reg-range 0 31))) ("Zd" "ZAn__3" "HV__4" "Ws__3" "offs__6"))
      ("movaz_z_rza_d" "ZUInteger.D, ZAUIntegerH.D[WUInteger, UInteger" (("Rs" (reg-range 0 3)) ("Zd" (reg-range 0 31))) ("Zd" "ZAn" "HV__4" "Ws__3" "offs__3"))
      ("movaz_z_rza_q" "ZUInteger.Q, ZAUIntegerH.Q[WUInteger, 0" (("Rs" (reg-range 0 3)) ("Zd" (reg-range 0 31))) ("Zd" "ZAn__4" "HV__4" "Ws__3" "offs__5"))
    )
    ((reg-list sme-za)
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
  )
)

(luti4
  (c3
    ((reg-list sme-zt reg-list)
      ("luti4_mz4_ztmz2_1" "{Z UInteger .B- Z UInteger .B}, ZT0, {Z UInteger - Z UInteger}" (("size" (element-size B H S D)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__4" "Zn2__3"))
      ("luti4_mz4_ztmz2_4" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, ZT0, {Z UInteger - Z UInteger}" (("size" (element-size B H S D)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 3))) ("Zd1__4" "Zd2__3" "Zd3" "Zd4__2" "Zn1__4" "Zn2__3"))
    )
    ((sve-z reg-list sve-z)
      ("luti4_z_zz_8" "ZUInteger.B, {Z UInteger .B}, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__4" "Zm__5"))
      ("luti4_z_zz_2x16" "ZUInteger.H, {Z UInteger .H Z UInteger . H}, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__7" "Zn2__5" "Zm__5"))
      ("luti4_z_zz_1x16" "ZUInteger.H, {Z UInteger .H}, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__4" "Zm__5"))
    )
    ((simd-vector reg-list simd-element)
      ("LUTI4_asimdtbl_L7" "VUInteger.8H, {V UInteger . 8H V UInteger . 8H}, VUInteger[UInteger]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn1" "Vn2" "Vm__4"))
      ("LUTI4_asimdtbl_L5" "VUInteger.16B, {V UInteger . 16B}, VUInteger[UInteger]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__3" "Vm__4"))
    )
    ((sve-z sme-zt sve-z)
      ("luti4_z_ztz_" "ZUInteger.B, ZT0, ZUInteger[UInteger]" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
    ((reg-list sme-zt sve-z)
      ("luti4_mz2_ztz_1" "{Z UInteger . B - Z UInteger . B}, ZT0, ZUInteger[UInteger]" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
      ("luti4_mz4_ztz_1" "{Z UInteger . H - Z UInteger . H}, ZT0, ZUInteger[UInteger]" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn"))
      ("luti4_mz2_ztz_8" "{Z UInteger . B Z UInteger . B}, ZT0, ZUInteger[UInteger]" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 7))) ("Zd1__3" "Zd2__2" "Zn"))
      ("luti4_mz4_ztz_4" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, ZT0, ZUInteger[UInteger]" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 3))) ("Zd1__4" "Zd2__3" "Zd3" "Zd4__2" "Zn"))
    )
  )
)

(sqdmlsl
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SQDMLSL_asimddiff_L" "VUInteger.4S, VUInteger.4H, VUInteger.4H" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("SQDMLSL_asimdelem_L" "VUInteger.4S, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
    )
    ((simd-scalar simd-scalar simd-vector)
      ("SQDMLSL_asisdelem_L" "SUInteger, HUInteger, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Va_option__2" "Vb_option__2" "Vm__5"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("SQDMLSL_asisddiff_only" "SUInteger, HUInteger, HUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Va_option__2" "Vb_option__2" "Vb_option__2"))
    )
  )
)

(setmtn
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETMTN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__3" "XnOrXZR__6" "XsOrXZR__7"))
    )
  )
)

(xpacd
  (c1
    ((gpr-64)
      ("XPACD_64Z_dp_1src" "XZR" (("Rd" (reg-range 0 31))) ("XdOrXZR__6"))
    )
  )
)

(msb
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("msb_z_p_zzz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Za" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zm" "Za"))
    )
  )
)

(swpalh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("SWPALH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(cbhhs
  (c3
    ((gpr-32 gpr-32 immediate)
      ("CBHHS_16_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
    )
  )
)

(crc32cx
  (c3
    ((gpr-32 gpr-32 gpr-64)
      ("CRC32CX_64C_dp_2src" "WZR, WZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR__2" "WnOrWZR__4" "XmOrXZR__8"))
    )
  )
)

(subhnt
  (c3
    ((sve-z sve-z sve-z)
      ("subhnt_z_zz_" "ZUInteger.B, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(fmop4s
  (c3
    ((sme-za reg-list sve-z)
      ("fmop4s_za_zz_s2x1" "ZAUInteger.S, {Z UInteger .S- Z UInteger .S}, ZUInteger.S" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
      ("fmop4s_za32_zz_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
      ("fmop4s_za_zz_h2x1" "ZAUInteger.H, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
      ("fmop4s_za_zz_d2x1" "ZAUInteger.D, {Z UInteger .D- Z UInteger .D}, ZUInteger.D" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
    )
    ((sme-za reg-list reg-list)
      ("fmop4s_za_zz_s2x2" "ZAUInteger.S, {Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("fmop4s_za32_zz_h2x2" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("fmop4s_za_zz_h2x2" "ZAUInteger.H, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("fmop4s_za_zz_d2x2" "ZAUInteger.D, {Z UInteger .D- Z UInteger .D}, {Z UInteger .D- Z UInteger .D}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
    ((sme-za sve-z sve-z)
      ("fmop4s_za_zz_s1x1" "ZAUInteger.S, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
      ("fmop4s_za32_zz_h1x1" "ZAUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
      ("fmop4s_za_zz_h1x1" "ZAUInteger.H, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn_mortlach" "Zm_mortlach"))
      ("fmop4s_za_zz_d1x1" "ZAUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm_mortlach"))
    )
    ((sme-za sve-z reg-list)
      ("fmop4s_za_zz_s1x2" "ZAUInteger.S, ZUInteger.S, {Z UInteger .S- Z UInteger .S}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("fmop4s_za32_zz_h1x2" "ZAUInteger.S, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("fmop4s_za_zz_h1x2" "ZAUInteger.H, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("fmop4s_za_zz_d1x2" "ZAUInteger.D, ZUInteger.D, {Z UInteger .D- Z UInteger .D}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
  )
)

(autda
  (c2
    ((gpr-64 gpr-64)
      ("AUTDA_64P_dp_1src" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__7"))
    )
  )
)

(cpym
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYM_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(blrab
  (c2
    ((gpr-64 gpr-64)
      ("BLRAB_64P_branch_reg" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rm" (reg-range 0 31))) ("XnOrXZR" "XmSP_option"))
    )
  )
)

(aesd
  (c2
    ((simd-vector simd-vector)
      ("AESD_B_cryptoaes" "VUInteger.16B, VUInteger.16B" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6"))
    )
  )
  (c3
    ((reg-list reg-list sve-z)
      ("aesd_mz_zzi_2x1" "{Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}, ZUInteger.Q[UInteger" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm"))
      ("aesd_mz_zzi_4x1" "{Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}, ZUInteger.Q[UInteger" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm"))
    )
    ((sve-z sve-z sve-z)
      ("aesd_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm"))
    )
  )
)

(ldsmaxa
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDSMAXA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDSMAXA_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(cash
  (c2m
    ((gpr-32 gpr-32 memory)
      ("CASH_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
    )
  )
)

(ld2b
  (c2m
    ((reg-list sve-p memory)
      ("ld2b_z_p_br_contiguous" "{Z UInteger .B Z UInteger .B}, PUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3" "Xm__4"))
      ("ld2b_z_p_bi_contiguous" "{Z UInteger .B Z UInteger .B}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3"))
    )
  )
)

(rcwclrpl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWCLRPL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(shll
  (c3
    ((simd-vector simd-vector immediate)
      ("SHLL_asimdmisc_S" "VUInteger.8H, VUInteger.8B, 8" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "shift_option__4"))
    )
  )
)

(fdot
  (c1
    ((sme-za)
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
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FDOT_asimdsame2_DD" "VUInteger.2S, VUInteger.8B, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FDOT_asimdsame2_D" "VUInteger.4H, VUInteger.8B, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FDOT_asimdsame2_FP16FP32" "VUInteger.2S, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FDOT_asimdelem_D" "VUInteger.2S, VUInteger.8B, VUInteger.4B[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "H_L"))
      ("FDOT_asimdelem_G" "VUInteger.4H, VUInteger.8B, VUInteger.2B[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__2" "H_L_M"))
      ("FDOT_asimdelem_FP16FP32" "VUInteger.2S, VUInteger.4H, VUInteger.2H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "H_L__2"))
    )
    ((sve-z sve-z sve-z)
      ("fdot_z_zzzi_" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__35"))
      ("fdot_z_zz8z8i_" "ZUInteger.H, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__53"))
      ("fdot_z32_zz8z8i_" "ZUInteger.S, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__40"))
      ("fdot_z_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("fdot_z_zz8z8_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("fdot_z32_zz8z8_" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(fmopa
  (c5
    ((sme-za sve-p sve-p sve-z sve-z)
      ("fmopa_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
      ("fmopa_za32_pp_zz_16" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
      ("fmopa_za32_pp_z8z8_8" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
      ("fmopa_za16_pp_z8z8_8" "ZAUInteger.H, PUInteger/M, PUInteger/M, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__3" "Pn" "Pm" "Zn__2" "Zm"))
      ("fmopa_za_pp_zz_16" "ZAUInteger.H, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__3" "Pn" "Pm" "Zn__2" "Zm"))
      ("fmopa_za_pp_zz_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn__2" "Zm"))
    )
  )
)

(cpyewtwn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYEWTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(flogb
  (c3
    ((sve-z sve-p sve-z)
      ("flogb_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("flogb_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(autia1716
  (c0
    (()
      ("AUTIA1716_HI_hints" "" () ())
    )
  )
)

(famin
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("famin_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FAMIN_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FAMIN_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((reg-list reg-list reg-list)
      ("famin_mz_zzw_2x2" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
      ("famin_mz_zzw_4x4" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
    )
  )
)

(dcps1
  (c0
    (()
      ("DCPS1_DC_exception" "" (("imm16" (imm-range 0 65535 1))) ())
    )
  )
)

(bfmaxnm
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("bfmaxnm_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((reg-list reg-list sve-z)
      ("bfmaxnm_mz_zzv_2x1" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
      ("bfmaxnm_mz_zzv_4x1" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
    )
    ((reg-list reg-list reg-list)
      ("bfmaxnm_mz_zzw_2x2" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, {Z UInteger . H- Z UInteger . H}" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
      ("bfmaxnm_mz_zzw_4x4" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, {Z UInteger . H- Z UInteger . H}" (("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
    )
  )
)

(cbne
  (c3
    ((gpr-64 gpr-64 immediate)
      ("CBNE_64_regs" "XZR, XZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "XmOrXZR__4" "imm9_offset"))
    )
    ((gpr-64 immediate immediate)
      ("CBNE_64_imm" "XZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "imm_cbr" "imm9_offset"))
    )
    ((gpr-32 gpr-32 immediate)
      ("CBNE_32_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
    )
    ((gpr-32 immediate immediate)
      ("CBNE_32_imm" "WZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "imm_cbr" "imm9_offset"))
    )
  )
)

(rcwsswppal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSSWPPAL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(dup
  (c2
    ((simd-vector simd-vector)
      ("DUP_asimdins_DV_v" "VUInteger.8B, VUInteger.B[UInteger]" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "imm5_index"))
    )
    ((sve-z gpr-32)
      ("dup_z_r_" "ZUInteger.B, WSP" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd"))
    )
    ((simd-scalar simd-vector)
      ("DUP_asisdone_only" "BUInteger, VUInteger.B[UInteger]" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__3" "Vn" "imm5_index__7"))
    )
    ((sve-z sve-z)
      ("dup_z_zi_" "ZUInteger.Q, ZUInteger.Q[UInteger]" (("imm2" (imm-range 0 3 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn" "imm__47"))
    )
    ((simd-vector gpr-32)
      ("DUP_asimdins_DR_r" "VUInteger.8B, WZR" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd"))
    )
    ((sve-z immediate)
      ("dup_z_i_" "ZUInteger.B, SInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zd" (reg-range 0 31))) ("Zd" "imm__46"))
    )
  )
)

(stbfadd
  (c1m
    ((simd-scalar memory)
      ("STBFADD_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(hlt
  (c1
    ((immediate)
      ("HLT_EX_exception" "UInteger" (("imm16" (imm-range 0 65535 1))) ("imm"))
    )
  )
)

(ldumina
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDUMINA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDUMINA_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ldr
  (c2
    ((gpr-64 immediate)
      ("LDR_64_loadlit" "XZR, SInteger" (("imm19" (imm-range 0 524287 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR__8" "imm19_offset__2"))
    )
    ((gpr-32 immediate)
      ("LDR_32_loadlit" "WZR, SInteger" (("imm19" (imm-range 0 524287 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR__2" "imm19_offset__2"))
    )
    ((simd-scalar immediate)
      ("LDR_S_loadlit" "SUInteger, SInteger" (("imm19" (imm-range 0 524287 1)) ("Rt" (reg-range 0 31))) ("imm19_offset__2"))
      ("LDR_D_loadlit" "DUInteger, SInteger" (("imm19" (imm-range 0 524287 1)) ("Rt" (reg-range 0 31))) ("imm19_offset__2"))
      ("LDR_Q_loadlit" "QUInteger, SInteger" (("imm19" (imm-range 0 524287 1)) ("Rt" (reg-range 0 31))) ("Qt__2" "imm19_offset__2"))
    )
  )
  (c1m1
    ((gpr-32 memory pre-index)
      ("LDR_32_ldst_immpre" "WZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
    ((simd-scalar memory pre-index)
      ("LDR_B_ldst_immpre" "BUInteger, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option"))
      ("LDR_Q_ldst_immpre" "QUInteger, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option"))
      ("LDR_H_ldst_immpre" "HUInteger, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option"))
      ("LDR_S_ldst_immpre" "SUInteger, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option"))
      ("LDR_D_ldst_immpre" "DUInteger, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option"))
    )
    ((gpr-64 memory pre-index)
      ("LDR_64_ldst_immpre" "XZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
    )
    ((gpr-64 memory immediate)
      ("LDR_64_ldst_immpost" "XZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
    )
    ((gpr-32 memory immediate)
      ("LDR_32_ldst_immpost" "WZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
    ((simd-scalar memory immediate)
      ("LDR_B_ldst_immpost" "BUInteger, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option"))
      ("LDR_Q_ldst_immpost" "QUInteger, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option"))
      ("LDR_H_ldst_immpost" "HUInteger, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option"))
      ("LDR_S_ldst_immpost" "SUInteger, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option"))
      ("LDR_D_ldst_immpost" "DUInteger, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option"))
    )
  )
  (c1
    ((sme-za)
      ("ldr_za_ri_" "ZA[WUInteger, UInteger, [SP]" (("Rn" (reg-range 0 31)) ("off4" (imm-range 0 15 1))) ("Wv__2" "offs__7" "XnSP__3"))
    )
  )
  (c1m
    ((gpr-32 memory)
      ("LDR_32_ldst_regoff" "WZR, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "WorX_choice"))
      ("LDR_32_ldst_pos" "WZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm12_option__6"))
    )
    ((sve-p memory)
      ("ldr_p_bi_" "PUInteger, [SP]" (("imm9h" (imm-range 0 63 1)) ("imm9l" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Pt" (reg-range 0 15))) ("Pt" "XnSP__3"))
    )
    ((simd-scalar memory)
      ("LDR_B_ldst_regoff" "BUInteger, [SP WZR UXTW]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option" "WorX_choice" "S_option"))
      ("LDR_BL_ldst_regoff" "BUInteger, [SP XZR]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option" "XmOrXZR__2"))
      ("LDR_Q_ldst_regoff" "QUInteger, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option" "WorX_choice"))
      ("LDR_H_ldst_regoff" "HUInteger, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option" "WorX_choice"))
      ("LDR_S_ldst_regoff" "SUInteger, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option" "WorX_choice"))
      ("LDR_D_ldst_regoff" "DUInteger, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option" "WorX_choice"))
      ("LDR_B_ldst_pos" "BUInteger, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option" "imm12_option"))
      ("LDR_Q_ldst_pos" "QUInteger, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option" "imm12_option__3"))
      ("LDR_H_ldst_pos" "HUInteger, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option" "imm12_option__4"))
      ("LDR_S_ldst_pos" "SUInteger, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option" "imm12_option__6"))
      ("LDR_D_ldst_pos" "DUInteger, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option" "imm12_option__8"))
    )
    ((sme-zt memory)
      ("ldr_zt_br_" "ZT0, [SP]" (("Rn" (reg-range 0 31))) ("XnSP__3"))
    )
    ((sve-z memory)
      ("ldr_z_bi_" "ZUInteger, [SP]" (("imm9h" (imm-range 0 63 1)) ("imm9l" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "XnSP__3"))
    )
    ((gpr-64 memory)
      ("LDR_64_ldst_regoff" "XZR, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "WorX_choice"))
      ("LDR_64_ldst_pos" "XZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm12_option__8"))
    )
  )
)

(cpyfp
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFP_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(movi
  (c2
    ((simd-vector immediate)
      ("MOVI_asimdimm_L_sl" "VUInteger.2S, UInteger" (("Rd" (reg-range 0 31))) ("Vd"))
      ("MOVI_asimdimm_L_hl" "VUInteger.4H, UInteger" (("Rd" (reg-range 0 31))) ("Vd"))
      ("MOVI_asimdimm_D2_d" "VUInteger.2D, UInteger" (("Rd" (reg-range 0 31))) ("Vd"))
    )
    ((simd-scalar immediate)
      ("MOVI_asimdimm_D_ds" "DUInteger, UInteger" (("Rd" (reg-range 0 31))) ("Dd"))
    )
  )
  (c4
    ((simd-vector immediate keyword immediate)
      ("MOVI_asimdimm_M_sm" "VUInteger.2S, UInteger, MSL, 8" (("Rd" (reg-range 0 31))) ("Vd"))
      ("MOVI_asimdimm_N_b" "VUInteger.8B, UInteger, LSL, 0" (("Rd" (reg-range 0 31))) ("Vd"))
    )
  )
)

(adcs
  (c3
    ((gpr-32 gpr-32 gpr-32)
      ("ADCS_32_addsub_carry" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64)
      ("ADCS_64_addsub_carry" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
  )
)

(match
  (c4
    ((sve-p sve-p sve-z sve-z)
      ("match_p_p_zz_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
    )
  )
)

(whilegt
  (c4
    ((sve-pn gpr-64 gpr-64 vector-length)
      ("whilegt_pn_rr_" "PNUInteger.B, XUInteger, XUInteger, VLx2" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("PNd" (reg-range 0 7))) ("PNd" "Xn__4" "Xm__6"))
    )
  )
  (c3
    ((reg-list gpr-64 gpr-64)
      ("whilegt_pp_rr_" "{P UInteger . B P UInteger . B}, XUInteger, XUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 7))) ("Pd1__2" "Pd2__2" "Xn__4" "Xm__6"))
    )
    ((sve-p gpr-32 gpr-32)
      ("whilegt_p_p_rr_" "PUInteger.B, WZR, WZR" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd"))
    )
  )
)

(fvdott
  (c3
    ((sme-za reg-list sve-z)
      ("fvdott_za32_z8z8i_2xi" "ZA.S[WUInteger, UInteger, VGx4], {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
    )
  )
)

(cpyfetwn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFETWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(tblq
  (c3
    ((sve-z reg-list sve-z)
      ("tblq_z_zz_" "ZUInteger.B, {Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(ld2d
  (c2
    ((reg-list sve-p)
      ("ld2d_z_p_br_contiguous" "{Z UInteger .D Z UInteger .D}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld2d_z_p_bi_contiguous" "{Z UInteger .D Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3"))
    )
  )
)

(stmopa
  (c4
    ((sme-za reg-list sve-z sve-z)
      ("stmopa_za_zzzi_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
      ("stmopa_za32_zzzi_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
    )
  )
)

(rbit
  (c2
    ((simd-vector simd-vector)
      ("RBIT_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((gpr-64 gpr-64)
      ("RBIT_64_dp_1src" "XZR, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
    )
    ((gpr-32 gpr-32)
      ("RBIT_32_dp_1src" "WZR, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("rbit_z_p_z_m" "ZUInteger.B, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("rbit_z_p_z_z" "ZUInteger.B, PUInteger/Z, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(frintn
  (c2
    ((simd-vector simd-vector)
      ("FRINTN_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FRINTN_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((reg-list reg-list)
      ("frintn_mz_z_2" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__4" "Zn2__3"))
      ("frintn_mz_z_4" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
    )
    ((simd-scalar simd-scalar)
      ("FRINTN_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
      ("FRINTN_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
      ("FRINTN_H_floatdp1" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("frintn_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("frintn_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(ldsetpal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDSETPAL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(ld1sh
  (c2
    ((reg-list sve-p)
      ("ld1sh_z_p_bz_s_x32_scaled" "{Z UInteger .S}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ld1sh_z_p_br_s64" "{Z UInteger .D}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
      ("ld1sh_z_p_br_s32" "{Z UInteger .S}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
      ("ld1sh_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ld1sh_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ld1sh_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld1sh_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ld1sh_z_p_ai_s" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("ld1sh_z_p_bi_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ld1sh_z_p_bi_s32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ld1sh_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ld1sh_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
    )
  )
)

(sqxtnt
  (c2
    ((sve-z sve-z)
      ("sqxtnt_z_zz_" "ZUInteger.B, ZUInteger.H" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(sttnp
  (c2m
    ((simd-scalar simd-scalar memory)
      ("STTNP_Q_ldstnapair_offs" "QUInteger, QUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm7_option__3"))
    )
    ((gpr-64 gpr-64 memory)
      ("STTNP_64_ldstnapair_offs" "XZR, XZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm7_option__2"))
    )
  )
)

(fcvtlt
  (c3
    ((sve-z sve-p sve-z)
      ("fcvtlt_z_p_z_h2sz" "ZUInteger.S, PUInteger/Z, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("fcvtlt_z_p_z_s2dz" "ZUInteger.D, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("fcvtlt_z_p_z_h2s" "ZUInteger.S, PUInteger/M, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("fcvtlt_z_p_z_s2d" "ZUInteger.D, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(fccmpe
  (c4
    ((simd-scalar simd-scalar immediate cond-code)
      ("FCCMPE_S_floatccmp" "SUInteger, SUInteger, UInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Sn__3" "Sm"))
      ("FCCMPE_D_floatccmp" "DUInteger, DUInteger, UInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Dn__2" "Dm"))
      ("FCCMPE_H_floatccmp" "HUInteger, HUInteger, UInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Hn" "Hm"))
    )
  )
)

(caspal
  (c4m
    ((gpr-64 gpr-64 gpr-64 gpr-64 memory)
      ("CASPAL_CP64_comswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
    )
    ((gpr-32 gpr-32 gpr-32 gpr-32 memory)
      ("CASPAL_CP32_comswappr" "WUInteger, WUInteger, WUInteger, WUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ws" "WsPlus1" "Wt" "WtPlus1" "XnSP_option"))
    )
  )
)

(bftmopa
  (c4
    ((sme-za reg-list sve-z sve-z)
      ("bftmopa_za32_zzzi_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
      ("bftmopa_za_zzzi_h2x1" "ZAUInteger.H, {Z UInteger .H- Z UInteger .H}, ZUInteger.H, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda__3" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
    )
  )
)

(cpyfprtrn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFPRTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(raddhnt
  (c3
    ((sve-z sve-z sve-z)
      ("raddhnt_z_zz_" "ZUInteger.B, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(st2b
  (c2m
    ((reg-list sve-p memory)
      ("st2b_z_p_br_contiguous" "{Z UInteger .B Z UInteger .B}, PUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3" "Xm__4"))
      ("st2b_z_p_bi_contiguous" "{Z UInteger .B Z UInteger .B}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3"))
    )
  )
)

(eors
  (c4
    ((sve-p sve-p sve-p sve-p)
      ("eors_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
    )
  )
)

(brkpa
  (c4
    ((sve-p sve-p sve-p sve-p)
      ("brkpa_p_p_pp_" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
    )
  )
)

(bext
  (c3
    ((sve-z sve-z sve-z)
      ("bext_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(stbfminnm
  (c1m
    ((simd-scalar memory)
      ("STBFMINNM_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(fmmla
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMMLA_asimd_FP16FP16" "VUInteger.8H, VUInteger.8H, VUInteger.8H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "Vm"))
      ("FMMLA_asimd_FP8FP16" "VUInteger.8H, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "Vm"))
      ("FMMLA_asimd_FP16FP32" "VUInteger.4S, VUInteger.8H, VUInteger.8H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "Vm"))
      ("FMMLA_asimd_FP8FP32" "VUInteger.4S, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "Vm"))
    )
    ((sve-z sve-z sve-z)
      ("fmmla_z32_zz8z8_" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("fmmla_z16_zz8z8_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("fmmla_z_zzz_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("fmmla_z32_zzz_h" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("fmmla_z_zzz_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("fmmla_z_zzz_d" "ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(subr
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("subr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((sve-z sve-z immediate)
      ("subr_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__27"))
    )
  )
)

(ldapp
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDAPP_64_ldiappstilp" "XZR, XZR, [SP 0]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(strh
  (c1m1
    ((gpr-32 memory pre-index)
      ("STRH_32_ldst_immpre" "WZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
    ((gpr-32 memory immediate)
      ("STRH_32_ldst_immpost" "WZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
  )
  (c1m
    ((gpr-32 memory)
      ("STRH_32_ldst_regoff" "WZR, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "WorX_choice"))
      ("STRH_32_ldst_pos" "WZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm12_option__4"))
    )
  )
)

(ldfmaxl
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDFMAXL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMAXL_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMAXL_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(ldtclral
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDTCLRAL_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDTCLRAL_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(sunpk
  (c2
    ((reg-list reg-list)
      ("sunpk_mz_z_4" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__4" "Zn2__3"))
    )
    ((reg-list sve-z)
      ("sunpk_mz_z_2" "{Z UInteger . H - Z UInteger . H}, ZUInteger.B" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
    )
  )
)

(fmsub
  (c4
    ((simd-scalar simd-scalar simd-scalar simd-scalar)
      ("FMSUB_S_floatdp3" "SUInteger, SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__6" "Sm__2" "Sa__2"))
      ("FMSUB_D_floatdp3" "DUInteger, DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__5" "Dm__2" "Da__2"))
      ("FMSUB_H_floatdp3" "HUInteger, HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__5" "Hm__2" "Ha__2"))
    )
  )
)

(paciza
  (c1
    ((gpr-64)
      ("PACIZA_64Z_dp_1src" "XZR" (("Rd" (reg-range 0 31))) ("XdOrXZR__6"))
    )
  )
)

(fmin
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fmin_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
    ((sve-z sve-p sve-z float-const)
      ("fmin_z_p_zs_" "ZUInteger.H, PUInteger/M, ZUInteger.H, 0.0" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMIN_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMIN_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((reg-list reg-list sve-z)
      ("fmin_mz_zzv_2x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
      ("fmin_mz_zzv_4x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("FMIN_S_floatdp2" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__3" "Sm"))
      ("FMIN_D_floatdp2" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__2" "Dm"))
      ("FMIN_H_floatdp2" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
    )
    ((reg-list reg-list reg-list)
      ("fmin_mz_zzw_2x2" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
      ("fmin_mz_zzw_4x4" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
    )
  )
)

(cpyfprtn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFPRTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(ldaddalb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDADDALB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ldapr
  (c1m1
    ((gpr-64 memory immediate)
      ("LDAPR_64L_ldapstl_writeback" "XZR, [SP], 8" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 memory immediate)
      ("LDAPR_32L_ldapstl_writeback" "WZR, [SP], 4" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__2" "XnSP_option"))
    )
  )
  (c1m
    ((gpr-32 memory)
      ("LDAPR_32L_memop" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__2" "XnSP_option"))
    )
    ((gpr-64 memory)
      ("LDAPR_64L_memop" "XZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__8" "XnSP_option"))
    )
  )
)

(sqrshlr
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("sqrshlr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
)

(st2d
  (c2
    ((reg-list sve-p)
      ("st2d_z_p_br_contiguous" "{Z UInteger .D Z UInteger .D}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("st2d_z_p_bi_contiguous" "{Z UInteger .D Z UInteger .D}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3"))
    )
  )
)

(shsub
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("shsub_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SHSUB_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(ld2h
  (c2
    ((reg-list sve-p)
      ("ld2h_z_p_br_contiguous" "{Z UInteger .H Z UInteger .H}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld2h_z_p_bi_contiguous" "{Z UInteger .H Z UInteger .H}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3"))
    )
  )
)

(frintp
  (c2
    ((simd-vector simd-vector)
      ("FRINTP_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FRINTP_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((reg-list reg-list)
      ("frintp_mz_z_2" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__4" "Zn2__3"))
      ("frintp_mz_z_4" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
    )
    ((simd-scalar simd-scalar)
      ("FRINTP_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
      ("FRINTP_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
      ("FRINTP_H_floatdp1" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("frintp_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("frintp_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(pacia171615
  (c0
    (()
      ("PACIA171615_64LR_dp_1src" "" () ())
    )
  )
)

(setgpt
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETGPT_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__4" "XnOrXZR__8" "XsOrXZR__8"))
    )
  )
)

(ld1r
  (c1m1
    ((reg-list memory immediate)
      ("LD1R_asisdlsop_R1_i" "{V UInteger . 8B}, [SP], 1" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "imm_option__8"))
    )
    ((reg-list memory gpr-64)
      ("LD1R_asisdlsop_RX1_r" "{V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "Xm__2"))
    )
  )
  (c1m
    ((reg-list memory)
      ("LD1R_asisdlso_R1" "{V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
    )
  )
)

(ldbfmaxa
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDBFMAXA_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(ldrsh
  (c1m1
    ((gpr-32 memory pre-index)
      ("LDRSH_32_ldst_immpre" "WZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
    ((gpr-64 memory pre-index)
      ("LDRSH_64_ldst_immpre" "XZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
    )
    ((gpr-64 memory immediate)
      ("LDRSH_64_ldst_immpost" "XZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
    )
    ((gpr-32 memory immediate)
      ("LDRSH_32_ldst_immpost" "WZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
  )
  (c1m
    ((gpr-32 memory)
      ("LDRSH_32_ldst_regoff" "WZR, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "WorX_choice"))
      ("LDRSH_32_ldst_pos" "WZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm12_option__4"))
    )
    ((gpr-64 memory)
      ("LDRSH_64_ldst_regoff" "XZR, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "WorX_choice"))
      ("LDRSH_64_ldst_pos" "XZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm12_option__4"))
    )
  )
)

(sha256h
  (c3
    ((simd-scalar simd-scalar simd-vector)
      ("SHA256H_QQV_cryptosha3" "QUInteger, QUInteger, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Qd" "Qn" "Vm__7"))
    )
  )
)

(f2cvtl
  (c2
    ((simd-vector simd-vector)
      ("F2CVTL_asimdmisc_V" "VUInteger.8H, VUInteger.8B" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((reg-list sve-z)
      ("f2cvtl_mz2_z8_" "{Z UInteger .H- Z UInteger .H}, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
    )
  )
)

(ld3
  (c1m1
    ((reg-list memory immediate)
      ("LD3_asisdlsep_I3_i" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], 24" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "imm_option__3"))
    )
    ((reg-list memory gpr-64)
      ("LD3_asisdlsep_R3_r" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
    )
    ((reg-list memory memory)
      ("LD3_asisdlso_B3_3b" "{V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
      ("LD3_asisdlso_H3_3h" "{V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
      ("LD3_asisdlso_S3_3s" "{V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
      ("LD3_asisdlso_D3_3d" "{V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
    )
  )
  (c1m2
    ((reg-list memory memory immediate)
      ("LD3_asisdlsop_B3_i3b" "{V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP], 3" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
      ("LD3_asisdlsop_H3_i3h" "{V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP], 6" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
      ("LD3_asisdlsop_S3_i3s" "{V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP], 12" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
      ("LD3_asisdlsop_D3_i3d" "{V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP], 24" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
    )
    ((reg-list memory memory gpr-64)
      ("LD3_asisdlsop_BX3_r3b" "{V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
      ("LD3_asisdlsop_HX3_r3h" "{V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
      ("LD3_asisdlsop_SX3_r3s" "{V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
      ("LD3_asisdlsop_DX3_r3d" "{V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
    )
  )
  (c1m
    ((reg-list memory)
      ("LD3_asisdlse_R3" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
    )
  )
)

(sttrh
  (c1m
    ((gpr-32 memory)
      ("STTRH_32_ldst_unpriv" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
  )
)

(tsb
  (c1
    ((barrier-option)
      ("TSB_HC_hints" "CSYNC" () ())
    )
  )
)

(sysl
  (c5
    ((gpr-64 immediate system-reg system-reg immediate)
      ("SYSL_RC_systeminstrs" "XZR, UInteger, CUInteger, CUInteger, UInteger" (("Rt" (reg-range 0 31))) ("XtOrXZR__4"))
    )
  )
)

(stbfmaxnm
  (c1m
    ((simd-scalar memory)
      ("STBFMAXNM_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(cpymrtrn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYMRTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(sttrb
  (c1m
    ((gpr-32 memory)
      ("STTRB_32_ldst_unpriv" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
  )
)

(setge
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETGE_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__10" "XsOrXZR__7"))
    )
  )
)

(ldtclrl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDTCLRL_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDTCLRL_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(stcph
  (c0
    (()
      ("STCPH_HI_hints" "" () ())
    )
  )
)

(ldclrab
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDCLRAB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(dcps3
  (c0
    (()
      ("DCPS3_DC_exception" "" (("imm16" (imm-range 0 65535 1))) ())
    )
  )
)

(rcwcaspl
  (c4m
    ((gpr-64 gpr-64 gpr-64 gpr-64 memory)
      ("RCWCASPL_C64_rcwcomswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
    )
  )
)

(bfcvtnt
  (c3
    ((sve-z sve-p sve-z)
      ("bfcvtnt_z_p_z_s2bfz" "ZUInteger.H, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("bfcvtnt_z_p_z_s2bf" "ZUInteger.H, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(ld1
  (c1m1
    ((reg-list memory immediate)
      ("LD1_asisdlsep_I4_i4" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], 32" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "imm_option"))
      ("LD1_asisdlsep_I3_i3" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], 24" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "imm_option__3"))
      ("LD1_asisdlsep_I1_i1" "{V UInteger . 8B}, [SP], 8" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "imm_option__5"))
      ("LD1_asisdlsep_I2_i2" "{V UInteger . 8B V UInteger . 8B}, [SP], 16" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "imm_option__6"))
    )
    ((reg-list memory gpr-64)
      ("LD1_asisdlsep_R4_r4" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
      ("LD1_asisdlsep_R3_r3" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
      ("LD1_asisdlsep_R1_r1" "{V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "Xm__2"))
      ("LD1_asisdlsep_R2_r2" "{V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
    )
    ((reg-list memory memory)
      ("LD1_asisdlso_B1_1b" "{V UInteger . B}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
      ("LD1_asisdlso_H1_1h" "{V UInteger . H}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
      ("LD1_asisdlso_S1_1s" "{V UInteger . S}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
      ("LD1_asisdlso_D1_1d" "{V UInteger . D}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
    )
  )
  (c1m2
    ((reg-list memory memory immediate)
      ("LD1_asisdlsop_B1_i1b" "{V UInteger . B}, [UInteger], [SP], 1" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
      ("LD1_asisdlsop_H1_i1h" "{V UInteger . H}, [UInteger], [SP], 2" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
      ("LD1_asisdlsop_S1_i1s" "{V UInteger . S}, [UInteger], [SP], 4" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
      ("LD1_asisdlsop_D1_i1d" "{V UInteger . D}, [UInteger], [SP], 8" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
    )
    ((reg-list memory memory gpr-64)
      ("LD1_asisdlsop_BX1_r1b" "{V UInteger . B}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "Xm__2"))
      ("LD1_asisdlsop_HX1_r1h" "{V UInteger . H}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "Xm__2"))
      ("LD1_asisdlsop_SX1_r1s" "{V UInteger . S}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "Xm__2"))
      ("LD1_asisdlsop_DX1_r1d" "{V UInteger . D}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option" "Xm__2"))
    )
  )
  (c1m
    ((reg-list memory)
      ("LD1_asisdlse_R4_4v" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
      ("LD1_asisdlse_R3_3v" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
      ("LD1_asisdlse_R1_1v" "{V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
      ("LD1_asisdlse_R2_2v" "{V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
    )
  )
)

(fnmadd
  (c4
    ((simd-scalar simd-scalar simd-scalar simd-scalar)
      ("FNMADD_S_floatdp3" "SUInteger, SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__6" "Sm__2" "Sa"))
      ("FNMADD_D_floatdp3" "DUInteger, DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__5" "Dm__2" "Da"))
      ("FNMADD_H_floatdp3" "HUInteger, HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__5" "Hm__2" "Ha"))
    )
  )
)

(ldbfmax
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDBFMAX_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(st64bv
  (c2m
    ((gpr-64 gpr-64 memory)
      ("ST64BV_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__3" "XtOrXZR__9" "XnSP_option"))
    )
  )
)

(fadd
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fadd_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
    ((sve-z sve-p sve-z float-const)
      ("fadd_z_p_zs_" "ZUInteger.H, PUInteger/M, ZUInteger.H, 0.5" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
    )
  )
  (c1
    ((sme-za)
      ("fadd_za_zw_2x2_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1" "Zm2"))
      ("fadd_za_zw_4x4_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1__2" "Zm4"))
    )
  )
  (c1m1
    ((sme-za memory reg-list)
      ("fadd_za_zw_2x2" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1" "Zm2"))
      ("fadd_za_zw_4x4" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1__2" "Zm4"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FADD_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FADD_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("FADD_S_floatdp2" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__3" "Sm"))
      ("FADD_D_floatdp2" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__2" "Dm"))
      ("FADD_H_floatdp2" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
    )
    ((sve-z sve-z sve-z)
      ("fadd_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(setgetn
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETGETN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__10" "XsOrXZR__7"))
    )
  )
)

(splice
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("splice_z_p_zz_des" "ZUInteger.B, PUInteger, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pv__2" "Zdn" "Zm"))
    )
  )
  (c3
    ((sve-z sve-p reg-list)
      ("splice_z_p_zz_con" "ZUInteger.B, PUInteger, {Z UInteger . B Z UInteger . B}" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pv__2" "Zn1__5" "Zn2__4"))
    )
  )
)

(ptrues
  (c1
    ((sve-p)
      ("ptrues_p_s_" "PUInteger.B" (("size" (element-size B H S D)) ("Pd" (reg-range 0 15))) ("Pd"))
    )
  )
)

(shrnt
  (c3
    ((sve-z sve-z immediate)
      ("shrnt_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(cpyfmrn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFMRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(sha512su0
  (c2
    ((simd-vector simd-vector)
      ("SHA512SU0_VV2_cryptosha512_2" "VUInteger.2D, VUInteger.2D" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6"))
    )
  )
)

(rcwswp
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSWP_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(asrr
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("asrr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
)

(ldap1
  (c1m1
    ((reg-list memory memory)
      ("LDAP1_asisdlso_D1" "{V UInteger . D}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
    )
  )
)

(caslb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("CASLB_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
    )
  )
)

(sqabs
  (c2
    ((simd-vector simd-vector)
      ("SQABS_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("SQABS_asisdmisc_R" "BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("sqabs_z_p_z_m" "ZUInteger.B, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("sqabs_z_p_z_z" "ZUInteger.B, PUInteger/Z, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(ldumaxb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDUMAXB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(brka
  (c3
    ((sve-p sve-p sve-p)
      ("brka_p_p_p_" "PUInteger.B, PUInteger/Z, PUInteger.B" (("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "ZM" "Pn__3"))
    )
  )
)

(saddlv
  (c2
    ((simd-scalar simd-vector)
      ("SADDLV_asimdall_only" "HUInteger, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option" "Vn"))
    )
  )
)

(sabdlb
  (c3
    ((sve-z sve-z sve-z)
      ("sabdlb_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(shl
  (c3
    ((simd-scalar simd-scalar immediate)
      ("SHL_asisdshf_R" "DUInteger, DUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
    ((simd-vector simd-vector immediate)
      ("SHL_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__5"))
    )
  )
)

(setgomt
  (c0m1
    ((memory gpr-64)
      ("SETGOMT_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__9"))
    )
  )
)

(ldursh
  (c1m
    ((gpr-32 memory)
      ("LDURSH_32_ldst_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
    ((gpr-64 memory)
      ("LDURSH_64_ldst_unscaled" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
    )
  )
)

(asrv
  (c3
    ((gpr-32 gpr-32 gpr-32)
      ("ASRV_32_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__4"))
    )
    ((gpr-64 gpr-64 gpr-64)
      ("ASRV_64_dp_2src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__7"))
    )
  )
)

(bfminnm
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("bfminnm_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((reg-list reg-list sve-z)
      ("bfminnm_mz_zzv_2x1" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
      ("bfminnm_mz_zzv_4x1" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
    )
    ((reg-list reg-list reg-list)
      ("bfminnm_mz_zzw_2x2" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, {Z UInteger . H- Z UInteger . H}" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
      ("bfminnm_mz_zzw_4x4" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, {Z UInteger . H- Z UInteger . H}" (("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
    )
  )
)

(sminqv
  (c3
    ((simd-vector sve-p sve-z)
      ("sminqv_z_p_z_" "VUInteger.16B, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
    )
  )
)

(fcvtas
  (c2
    ((simd-vector simd-vector)
      ("FCVTAS_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FCVTAS_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("FCVTAS_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
      ("FCVTAS_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
      ("FCVTAS_sisd_32D" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
      ("FCVTAS_sisd_32H" "SUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Hn__2"))
      ("FCVTAS_sisd_64H" "DUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Hn__2"))
      ("FCVTAS_sisd_64S" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
    )
    ((gpr-32 simd-scalar)
      ("FCVTAS_32S_float2int" "WZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
      ("FCVTAS_32D_float2int" "WZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
      ("FCVTAS_32H_float2int" "WZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
    )
    ((gpr-64 simd-scalar)
      ("FCVTAS_64S_float2int" "XZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
      ("FCVTAS_64D_float2int" "XZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
      ("FCVTAS_64H_float2int" "XZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
    )
  )
)

(bfvdot
  (c1
    ((sme-za)
      ("bfvdot_za_zzi_2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
    )
  )
)

(suvdot
  (c1
    ((sme-za)
      ("suvdot_za_zzi_s4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
    )
  )
)

(cpyfptwn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFPTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(ext
  (c4
    ((sve-z sve-z sve-z immediate)
      ("ext_z_zi_des" "ZUInteger.B, ZUInteger.B, ZUInteger.B, UInteger" (("imm8h" (imm-range 0 31 1)) ("imm8l" (imm-range 0 7 1)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm" "imm__49"))
    )
    ((simd-vector simd-vector simd-vector immediate)
      ("EXT_asimdext_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B, UInteger" (("Rm" (reg-range 0 31)) ("imm4" (imm-range 0 15 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm" "imm420"))
    )
  )
  (c3
    ((sve-z reg-list immediate)
      ("ext_z_zi_con" "ZUInteger.B, {Z UInteger .B Z UInteger .B}, UInteger" (("imm8h" (imm-range 0 31 1)) ("imm8l" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__5" "Zn2__4" "imm__49"))
    )
  )
)

(setgpn
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETGPN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__4" "XnOrXZR__8" "XsOrXZR__8"))
    )
  )
)

(uqxtnt
  (c2
    ((sve-z sve-z)
      ("uqxtnt_z_zz_" "ZUInteger.B, ZUInteger.H" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(tbl
  (c3
    ((sve-z reg-list sve-z)
      ("tbl_z_zz_2" "ZUInteger.B, {Z UInteger . B Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__8" "Zn2__6" "Zm"))
      ("tbl_z_zz_1" "ZUInteger.B, {Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
    ((simd-vector reg-list simd-vector)
      ("TBL_asimdtbl_L1_1" "VUInteger.8B, {V UInteger . 16B}, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__3" "Vm__3"))
      ("TBL_asimdtbl_L2_2" "VUInteger.8B, {V UInteger . 16B V UInteger . 16B}, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__4" "VnPlus1" "Vm__3"))
      ("TBL_asimdtbl_L3_3" "VUInteger.8B, {V UInteger . 16B V UInteger . 16B V UInteger . 16B}, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__4" "VnPlus1" "VnPlus2" "Vm__3"))
      ("TBL_asimdtbl_L4_4" "VUInteger.8B, {V UInteger . 16B V UInteger . 16B V UInteger . 16B V UInteger . 16B}, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__4" "VnPlus1" "VnPlus2" "VnPlus3" "Vm__3"))
    )
  )
)

(casp
  (c4m
    ((gpr-64 gpr-64 gpr-64 gpr-64 memory)
      ("CASP_CP64_comswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
    )
    ((gpr-32 gpr-32 gpr-32 gpr-32 memory)
      ("CASP_CP32_comswappr" "WUInteger, WUInteger, WUInteger, WUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ws" "WsPlus1" "Wt" "WtPlus1" "XnSP_option"))
    )
  )
)

(msr
  (c2
    ((system-reg immediate)
      ("MSR_SI_pstate" "UAO, UInteger" () ())
    )
    ((system-reg gpr-64)
      ("MSR_SR_systemmove" "ACTLR_EL3, XZR" (("Rt" (reg-range 0 31))) ("XtOrXZR__3"))
    )
  )
)

(rcwssetp
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSSETP_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(rcwsclrpal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSCLRPAL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(smaxqv
  (c3
    ((simd-vector sve-p sve-z)
      ("smaxqv_z_p_z_" "VUInteger.16B, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
    )
  )
)

(punpkhi
  (c2
    ((sve-p sve-p)
      ("punpkhi_p_p_" "PUInteger.H, PUInteger.B" (("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pn__3"))
    )
  )
)

(retab
  (c0
    (()
      ("RETAB_64E_branch_reg" "" () ())
    )
  )
)

(rcwsetp
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSETP_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(ldurb
  (c1m
    ((gpr-32 memory)
      ("LDURB_32_ldst_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
  )
)

(fcvtau
  (c2
    ((simd-vector simd-vector)
      ("FCVTAU_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FCVTAU_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("FCVTAU_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
      ("FCVTAU_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
      ("FCVTAU_sisd_32D" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
      ("FCVTAU_sisd_32H" "SUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Hn__2"))
      ("FCVTAU_sisd_64H" "DUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Hn__2"))
      ("FCVTAU_sisd_64S" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
    )
    ((gpr-32 simd-scalar)
      ("FCVTAU_32S_float2int" "WZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
      ("FCVTAU_32D_float2int" "WZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
      ("FCVTAU_32H_float2int" "WZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
    )
    ((gpr-64 simd-scalar)
      ("FCVTAU_64S_float2int" "XZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
      ("FCVTAU_64D_float2int" "XZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
      ("FCVTAU_64H_float2int" "XZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
    )
  )
)

(cpyfewt
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFEWT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(setgomn
  (c0m1
    ((memory gpr-64)
      ("SETGOMN_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__9"))
    )
  )
)

(stlur
  (c1m
    ((gpr-32 memory)
      ("STLUR_32_ldapstl_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
    ((simd-scalar memory)
      ("STLUR_B_ldapstl_simd" "BUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option" "imm9_option"))
      ("STLUR_Q_ldapstl_simd" "QUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option" "imm9_option"))
      ("STLUR_H_ldapstl_simd" "HUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option" "imm9_option"))
      ("STLUR_S_ldapstl_simd" "SUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option" "imm9_option"))
      ("STLUR_D_ldapstl_simd" "DUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option" "imm9_option"))
    )
    ((gpr-64 memory)
      ("STLUR_64_ldapstl_unscaled" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
    )
  )
)

(paciasppc
  (c0
    (()
      ("PACIASPPC_64LR_dp_1src" "" () ())
    )
  )
)

(uqdecw
  (c1
    ((gpr-64)
      ("uqdecw_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
    ((sve-z)
      ("uqdecw_z_zs_" "ZUInteger.S" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
    )
    ((gpr-32)
      ("uqdecw_r_rs_uw" "WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Wdn"))
    )
  )
)

(crc32ch
  (c3
    ((gpr-32 gpr-32 gpr-32)
      ("CRC32CH_32C_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR__2" "WnOrWZR__4" "WmOrWZR__5"))
    )
  )
)

(rcwset
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSET_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(faddqv
  (c3
    ((simd-vector sve-p sve-z)
      ("faddqv_z_p_z_" "VUInteger.8H, PUInteger, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
    )
  )
)

(rmif
  (c3
    ((gpr-64 immediate immediate)
      ("RMIF_only_rmif" "XZR, UInteger, UInteger" (("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31))) ("XnOrXZR__11" "shift__9"))
    )
  )
)

(adrp
  (c2
    ((gpr-64 immediate)
      ("ADRP_only_pcreladdr" "XZR, SInteger" (("immlo" (imm-range 0 3 1)) ("immhi" (imm-range 0 524287 1)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "immhiimmlo_offset__2"))
    )
  )
)

(sqdmullb
  (c3
    ((sve-z sve-z sve-z)
      ("sqdmullb_z_zzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__78"))
      ("sqdmullb_z_zzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__2" "imm__88"))
      ("sqdmullb_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(cpyfertrn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFERTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(ldff1d
  (c2
    ((reg-list sve-p)
      ("ldff1d_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1d_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1d_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ldff1d_z_p_br_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldff1d_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1d_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
    )
  )
)

(umaddl
  (c4
    ((gpr-64 gpr-32 gpr-32 gpr-64)
      ("UMADDL_64WA_dp_3src" "XZR, WZR, WZR, XZR" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "WnOrWZR__5" "WmOrWZR__6" "XaOrXZR"))
    )
  )
)

(sdivr
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("sdivr_z_p_zz_" "ZUInteger.S, PUInteger/M, ZUInteger.S, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
)

(pfirst
  (c3
    ((sve-p sve-p sve-p)
      ("pfirst_p_p_p_" "PUInteger.B, PUInteger, PUInteger.B" (("Pg" (reg-range 0 15))) ("Pdn" "Pg__2" "Pdn"))
    )
  )
)

(ld1sb
  (c2
    ((reg-list sve-p)
      ("ld1sb_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
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
    )
  )
)

(isb
  (c0
    (()
      ("ISB_BI_barriers" "" () ())
    )
  )
)

(setgm
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETGM_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__9" "XsOrXZR__8"))
    )
  )
)

(uxtw
  (c3
    ((sve-z sve-p sve-z)
      ("uxtw_z_p_z_m" "ZUInteger.D, PUInteger/M, ZUInteger.D" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("uxtw_z_p_z_z" "ZUInteger.D, PUInteger/Z, ZUInteger.D" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(stbfmin
  (c1m
    ((simd-scalar memory)
      ("STBFMIN_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(csel
  (c4
    ((gpr-32 gpr-32 gpr-32 cond-code)
      ("CSEL_32_condsel" "WZR, WZR, WZR, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64 cond-code)
      ("CSEL_64_condsel" "XZR, XZR, XZR, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
  )
)

(frintx
  (c2
    ((simd-vector simd-vector)
      ("FRINTX_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FRINTX_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("FRINTX_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
      ("FRINTX_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
      ("FRINTX_H_floatdp1" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("frintx_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("frintx_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(sclamp
  (c3
    ((reg-list sve-z sve-z)
      ("sclamp_mz_zz_2" "{Z UInteger . B - Z UInteger . B}, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn__2" "Zm"))
      ("sclamp_mz_zz_4" "{Z UInteger . B - Z UInteger . B}, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn__2" "Zm"))
    )
    ((sve-z sve-z sve-z)
      ("sclamp_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(srsra
  (c3
    ((simd-scalar simd-scalar immediate)
      ("SRSRA_asisdshf_R" "DUInteger, DUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
    ((simd-vector simd-vector immediate)
      ("SRSRA_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__4"))
    )
    ((sve-z sve-z immediate)
      ("srsra_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2"))
    )
  )
)

(fmop4a
  (c3
    ((sme-za reg-list sve-z)
      ("fmop4a_za_zz_s2x1" "ZAUInteger.S, {Z UInteger .S- Z UInteger .S}, ZUInteger.S" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
      ("fmop4a_za32_z8z8_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
      ("fmop4a_za32_zz_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
      ("fmop4a_za16_z8z8_b2x1" "ZAUInteger.H, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
      ("fmop4a_za_zz_h2x1" "ZAUInteger.H, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
      ("fmop4a_za_zz_d2x1" "ZAUInteger.D, {Z UInteger .D- Z UInteger .D}, ZUInteger.D" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
    )
    ((sme-za reg-list reg-list)
      ("fmop4a_za_zz_s2x2" "ZAUInteger.S, {Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("fmop4a_za32_z8z8_b2x2" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("fmop4a_za32_zz_h2x2" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("fmop4a_za16_z8z8_b2x2" "ZAUInteger.H, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("fmop4a_za_zz_h2x2" "ZAUInteger.H, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("fmop4a_za_zz_d2x2" "ZAUInteger.D, {Z UInteger .D- Z UInteger .D}, {Z UInteger .D- Z UInteger .D}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
    ((sme-za sve-z sve-z)
      ("fmop4a_za_zz_s1x1" "ZAUInteger.S, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
      ("fmop4a_za32_z8z8_b1x1" "ZAUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
      ("fmop4a_za32_zz_h1x1" "ZAUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
      ("fmop4a_za16_z8z8_b1x1" "ZAUInteger.H, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn_mortlach" "Zm_mortlach"))
      ("fmop4a_za_zz_h1x1" "ZAUInteger.H, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn_mortlach" "Zm_mortlach"))
      ("fmop4a_za_zz_d1x1" "ZAUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm_mortlach"))
    )
    ((sme-za sve-z reg-list)
      ("fmop4a_za_zz_s1x2" "ZAUInteger.S, ZUInteger.S, {Z UInteger .S- Z UInteger .S}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("fmop4a_za32_z8z8_b1x2" "ZAUInteger.S, ZUInteger.B, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("fmop4a_za32_zz_h1x2" "ZAUInteger.S, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("fmop4a_za16_z8z8_b1x2" "ZAUInteger.H, ZUInteger.B, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("fmop4a_za_zz_h1x2" "ZAUInteger.H, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__3" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("fmop4a_za_zz_d1x2" "ZAUInteger.D, ZUInteger.D, {Z UInteger .D- Z UInteger .D}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
  )
)

(crc32cb
  (c3
    ((gpr-32 gpr-32 gpr-32)
      ("CRC32CB_32C_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR__2" "WnOrWZR__4" "WmOrWZR__5"))
    )
  )
)

(ldrsb
  (c1m1
    ((gpr-32 memory pre-index)
      ("LDRSB_32_ldst_immpre" "WZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
    ((gpr-64 memory pre-index)
      ("LDRSB_64_ldst_immpre" "XZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
    )
    ((gpr-64 memory immediate)
      ("LDRSB_64_ldst_immpost" "XZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
    )
    ((gpr-32 memory immediate)
      ("LDRSB_32_ldst_immpost" "WZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
  )
  (c1m
    ((gpr-32 memory)
      ("LDRSB_32B_ldst_regoff" "WZR, [SP WZR UXTW]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "WorX_choice" "S_option"))
      ("LDRSB_32BL_ldst_regoff" "WZR, [SP XZR]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "XmOrXZR__2"))
      ("LDRSB_32_ldst_pos" "WZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm12_option"))
    )
    ((gpr-64 memory)
      ("LDRSB_64B_ldst_regoff" "XZR, [SP WZR UXTW]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "WorX_choice" "S_option"))
      ("LDRSB_64BL_ldst_regoff" "XZR, [SP XZR]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "XmOrXZR__2"))
      ("LDRSB_64_ldst_pos" "XZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm12_option"))
    )
  )
)

(sqsubr
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("sqsubr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
)

(ldtseta
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDTSETA_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDTSETA_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(orqv
  (c3
    ((simd-vector sve-p sve-z)
      ("orqv_z_p_z_" "VUInteger.16B, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
    )
  )
)

(cpyfewn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFEWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(setgop
  (c0m1
    ((memory gpr-64)
      ("SETGOP_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__4" "XnOrXZR__8"))
    )
  )
)

(ldbfmina
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDBFMINA_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(zip2
  (c3
    ((sve-p sve-p sve-p)
      ("zip2_p_pp_" "PUInteger.B, PUInteger.B, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pn__2" "Pm__2"))
    )
    ((simd-vector simd-vector simd-vector)
      ("ZIP2_asimdperm_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((sve-z sve-z sve-z)
      ("zip2_z_zz_q" "ZUInteger.Q, ZUInteger.Q, ZUInteger.Q" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
      ("zip2_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(sumopa
  (c5
    ((sme-za sve-p sve-p sve-z sve-z)
      ("sumopa_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
      ("sumopa_za_pp_zz_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn__2" "Zm"))
    )
  )
)

(adc
  (c3
    ((gpr-32 gpr-32 gpr-32)
      ("ADC_32_addsub_carry" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64)
      ("ADC_64_addsub_carry" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
  )
)

(ldfmina
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDFMINA_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMINA_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMINA_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(neg
  (c2
    ((simd-vector simd-vector)
      ("NEG_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("NEG_asisdmisc_R" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("neg_z_p_z_m" "ZUInteger.B, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("neg_z_p_z_z" "ZUInteger.B, PUInteger/Z, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(ins
  (c2
    ((simd-vector simd-vector)
      ("INS_asimdins_IV_v" "VUInteger.B[UInteger], VUInteger.B[UInteger]" (("imm5" (imm-range 0 31 1)) ("imm4" (imm-range 0 15 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "imm5_index__5" "Vn" "imm5_index__6"))
    )
    ((simd-vector gpr-32)
      ("INS_asimdins_IR_r" "VUInteger.B[UInteger], WZR" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "imm5_index"))
    )
  )
)

(frintz
  (c2
    ((simd-vector simd-vector)
      ("FRINTZ_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FRINTZ_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("FRINTZ_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
      ("FRINTZ_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
      ("FRINTZ_H_floatdp1" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("frintz_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("frintz_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(cpyfpn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFPN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(ldff1h
  (c2
    ((reg-list sve-p)
      ("ldff1h_z_p_bz_s_x32_scaled" "{Z UInteger .S}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1h_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1h_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1h_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ldff1h_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1h_z_p_ai_s" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("ldff1h_z_p_br_u16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldff1h_z_p_br_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldff1h_z_p_br_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldff1h_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1h_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
    )
  )
)

(fmadd
  (c4
    ((simd-scalar simd-scalar simd-scalar simd-scalar)
      ("FMADD_S_floatdp3" "SUInteger, SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__6" "Sm__2" "Sa"))
      ("FMADD_D_floatdp3" "DUInteger, DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__5" "Dm__2" "Da"))
      ("FMADD_H_floatdp3" "HUInteger, HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__5" "Hm__2" "Ha"))
    )
  )
)

(autia171615
  (c0
    (()
      ("AUTIA171615_64LR_dp_1src" "" () ())
    )
  )
)

(fmlslb
  (c3
    ((sve-z sve-z sve-z)
      ("fmlslb_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
      ("fmlslb_z_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(fcvtx
  (c3
    ((sve-z sve-p sve-z)
      ("fcvtx_z_p_z_d2sz" "ZUInteger.S, PUInteger/Z, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("fcvtx_z_p_z_d2s" "ZUInteger.S, PUInteger/M, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(ssublbt
  (c3
    ((sve-z sve-z sve-z)
      ("ssublbt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(srshr
  (c4
    ((sve-z sve-p sve-z immediate)
      ("srshr_z_p_zi_" "ZUInteger.B, PUInteger/M, ZUInteger.B, UInteger" (("Pg" (reg-range 0 7)) ("imm3" (imm-range 0 7 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
    )
  )
  (c3
    ((simd-scalar simd-scalar immediate)
      ("SRSHR_asisdshf_R" "DUInteger, DUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
    ((simd-vector simd-vector immediate)
      ("SRSHR_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__4"))
    )
  )
)

(pmul
  (c3
    ((simd-vector simd-vector simd-vector)
      ("PMUL_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((sve-z sve-z sve-z)
      ("pmul_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(ldbfmaxnml
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDBFMAXNML_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(casl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("CASL_C64_comswap" "XZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("CASL_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
    )
  )
)

(ldursb
  (c1m
    ((gpr-32 memory)
      ("LDURSB_32_ldst_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
    ((gpr-64 memory)
      ("LDURSB_64_ldst_unscaled" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
    )
  )
)

(sri
  (c3
    ((simd-scalar simd-scalar immediate)
      ("SRI_asisdshf_R" "DUInteger, DUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
    ((simd-vector simd-vector immediate)
      ("SRI_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__4"))
    )
    ((sve-z sve-z immediate)
      ("sri_z_zzi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(addha
  (c4
    ((sme-za sve-p sve-p sve-z)
      ("addha_za_pp_z_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.S" (("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn"))
      ("addha_za_pp_z_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.D" (("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn"))
    )
  )
)

(casat
  (c2m
    ((gpr-64 gpr-64 memory)
      ("CASAT_C64_comswap_unpriv" "XZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
    )
  )
)

(uzp2
  (c3
    ((sve-p sve-p sve-p)
      ("uzp2_p_pp_" "PUInteger.B, PUInteger.B, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pn__2" "Pm__2"))
    )
    ((simd-vector simd-vector simd-vector)
      ("UZP2_asimdperm_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((sve-z sve-z sve-z)
      ("uzp2_z_zz_q" "ZUInteger.Q, ZUInteger.Q, ZUInteger.Q" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
      ("uzp2_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(ldadda
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDADDA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDADDA_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(movk
  (c2
    ((gpr-64 immediate)
      ("MOVK_64_movewide" "XZR, UInteger" (("imm16" (imm-range 0 65535 1)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "imm__18"))
    )
    ((gpr-32 immediate)
      ("MOVK_32_movewide" "WZR, UInteger" (("imm16" (imm-range 0 65535 1)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "imm__18"))
    )
  )
  (c4
    ((gpr-64 immediate unknown immediate)
      ("MOVK_64_movewide_shift" "XZR, UInteger, lsl, UInteger" (("imm16" (imm-range 0 65535 1)) ("hw" (imm-range 0 3 1)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "imm" "lsl" "shift"))
    )
    ((gpr-32 immediate unknown immediate)
      ("MOVK_32_movewide_shift" "WZR, UInteger, lsl, UInteger" (("imm16" (imm-range 0 65535 1)) ("hw" (imm-range 0 1 1)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "imm" "lsl" "shift"))
    )
  )
)

(pacda
  (c2
    ((gpr-64 gpr-64)
      ("PACDA_64P_dp_1src" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__7"))
    )
  )
)

(rcwssetl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSSETL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(swph
  (c2m
    ((gpr-32 gpr-32 memory)
      ("SWPH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(sqshrnb
  (c3
    ((sve-z sve-z immediate)
      ("sqshrnb_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(ldiapp
  (c2m1
    ((gpr-64 gpr-64 memory immediate)
      ("LDIAPP_64LS_ldiappstilp" "XZR, XZR, [SP], 16" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory immediate)
      ("LDIAPP_32LE_ldiappstilp" "WZR, WZR, [SP], 8" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option"))
    )
  )
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDIAPP_64L_ldiappstilp" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDIAPP_32L_ldiappstilp" "WZR, WZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option"))
    )
  )
)

(ldclrlh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDCLRLH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(rev32
  (c2
    ((simd-vector simd-vector)
      ("REV32_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((gpr-64 gpr-64)
      ("REV32_64_dp_1src" "XZR, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
    )
  )
)

(st4q
  (c2
    ((reg-list sve-p)
      ("st4q_z_p_br_contiguous" "{Z UInteger .Q Z UInteger .Q Z UInteger .Q Z UInteger .Q}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("st4q_z_p_bi_contiguous" "{Z UInteger .Q Z UInteger .Q Z UInteger .Q Z UInteger .Q}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3"))
    )
  )
)

(ldeoralh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDEORALH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(stnt1w
  (c2
    ((reg-list sve-pn)
      ("stnt1w_mz_p_br_2" "{Z UInteger .S- Z UInteger .S}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
      ("stnt1w_mz_p_br_4" "{Z UInteger .S- Z UInteger .S}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
      ("stnt1w_mzx_p_br_2x8" "{Z UInteger .S Z UInteger .S}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
      ("stnt1w_mzx_p_br_4x4" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
    )
    ((reg-list sve-p)
      ("stnt1w_z_p_br_contiguous" "{Z UInteger .S}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("stnt1w_z_p_ar_d_64_unscaled" "{Z UInteger .D}, PUInteger, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("stnt1w_z_p_ar_s_x32_unscaled" "{Z UInteger .S}, PUInteger, [Z UInteger .S]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("stnt1w_z_p_bi_contiguous" "{Z UInteger .S}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
    ((reg-list sve-pn memory)
      ("stnt1w_mz_p_bi_2" "{Z UInteger .S- Z UInteger .S}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
      ("stnt1w_mz_p_bi_4" "{Z UInteger .S- Z UInteger .S}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
      ("stnt1w_mzx_p_bi_2x8" "{Z UInteger .S Z UInteger .S}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
      ("stnt1w_mzx_p_bi_4x4" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
    )
  )
)

(ld4d
  (c2
    ((reg-list sve-p)
      ("ld4d_z_p_br_contiguous" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld4d_z_p_bi_contiguous" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3"))
    )
  )
)

(frint64x
  (c2
    ((simd-vector simd-vector)
      ("FRINT64X_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("FRINT64X_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
      ("FRINT64X_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("frint64x_z_p_z_z" "ZUInteger.S, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("frint64x_z_p_z_m" "ZUInteger.S, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(pmull
  (c3
    ((simd-vector simd-vector simd-vector)
      ("PMULL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((reg-list sve-z sve-z)
      ("pmull_mz_zzw_1x2" "{Z UInteger .Q- Z UInteger .Q}, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn__2" "Zm"))
    )
  )
)

(addqp
  (c3
    ((sve-z sve-z sve-z)
      ("addqp_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(ldeoral
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDEORAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDEORAL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(tbxq
  (c3
    ((sve-z sve-z sve-z)
      ("tbxq_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(sdot
  (c1
    ((sme-za)
      ("sdot_za32_zzi_2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
      ("sdot_za_zzi_s2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
      ("sdot_za_zzi_d2xi" "ZA.D[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
      ("sdot_za32_zzi_4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
      ("sdot_za_zzi_s4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
      ("sdot_za_zzi_d4xi" "ZA.D[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
      ("sdot_za32_zzv_2x1" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
      ("sdot_za32_zzv_4x1" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
      ("sdot_za32_zzw_2x2" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("sdot_za32_zzw_4x4" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SDOT_asimdsame2_D" "VUInteger.2S, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "Vm"))
      ("SDOT_asimdelem_D" "VUInteger.2S, VUInteger.8B, VUInteger.4B[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2"))
    )
    ((sve-z sve-z sve-z)
      ("sdot_z_zzz_" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("sdot_z16_zzz_h" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("sdot_z32_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("sdot_z32_zzzi_" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__35"))
      ("sdot_z_zzzi_s" "ZUInteger.S, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__40"))
      ("sdot_z_zzzi_d" "ZUInteger.D, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__39"))
      ("sdot_z16_zzzi_h" "ZUInteger.H, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__53"))
    )
  )
  (c1m2
    ((sme-za memory reg-list sve-z)
      ("sdot_za_zzv_2x1" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
      ("sdot_za_zzv_4x1" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
    )
    ((sme-za memory reg-list reg-list)
      ("sdot_za_zzw_2x2" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("sdot_za_zzw_4x4" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
)

(frecpx
  (c2
    ((simd-scalar simd-scalar)
      ("FRECPX_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
      ("FRECPX_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("frecpx_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("frecpx_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(setf16
  (c1
    ((gpr-32)
      ("SETF16_only_setf" "WZR" (("Rn" (reg-range 0 31))) ("WnOrWZR"))
    )
  )
)

(cpyfen
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFEN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(ldeorlh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDEORLH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(sha1m
  (c3
    ((simd-scalar simd-scalar simd-vector)
      ("SHA1M_QSV_cryptosha3" "QUInteger, SUInteger, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Qd" "Sn__2" "Vm__7"))
    )
  )
)

(uqrshrn
  (c3
    ((simd-scalar simd-scalar immediate)
      ("UQRSHRN_asisdshf_N" "BUInteger, HUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vb_option" "Va_option" "immh_shift__2"))
    )
    ((simd-vector simd-vector immediate)
      ("UQRSHRN_asimdshf_N" "VUInteger.8B, VUInteger.8H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__6"))
    )
    ((sve-z reg-list immediate)
      ("uqrshrn_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}, UInteger" (("imm4" (imm-range 0 15 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
      ("uqrshrn_z_mz2_b" "ZUInteger.B, {Z UInteger .H- Z UInteger .H}, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
      ("uqrshrn_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}, UInteger" (("imm5" (imm-range 0 31 1)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
    )
  )
)

(stzg
  (c1m1
    ((gpr-64 memory pre-index)
      ("STZG_64Spre_ldsttags" "SP, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option"))
    )
    ((gpr-64 memory immediate)
      ("STZG_64Spost_ldsttags" "SP, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option"))
    )
  )
  (c1m
    ((gpr-64 memory)
      ("STZG_64Soffset_ldsttags" "SP, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option" "imm9_option__2"))
    )
  )
)

(ldatxr
  (c1m
    ((gpr-32 memory)
      ("LDATXR_LR32_ldstexclr_unpriv" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
    ((gpr-64 memory)
      ("LDATXR_LR64_ldstexclr_unpriv" "XZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
    )
  )
)

(ld4b
  (c2m
    ((reg-list sve-p memory)
      ("ld4b_z_p_br_contiguous" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3" "Xm__4"))
      ("ld4b_z_p_bi_contiguous" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3"))
    )
  )
)

(cpyfprt
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFPRT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(autib171615
  (c0
    (()
      ("AUTIB171615_64LR_dp_1src" "" () ())
    )
  )
)

(bsl
  (c4
    ((sve-z sve-z sve-z sve-z)
      ("bsl_z_zzz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm" "Zk"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("BSL_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(stfaddl
  (c1m
    ((simd-scalar memory)
      ("STFADDL_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
      ("STFADDL_32" "SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
      ("STFADDL_64" "DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(usra
  (c3
    ((simd-scalar simd-scalar immediate)
      ("USRA_asisdshf_R" "DUInteger, DUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
    ((simd-vector simd-vector immediate)
      ("USRA_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__4"))
    )
    ((sve-z sve-z immediate)
      ("usra_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2"))
    )
  )
)

(csneg
  (c4
    ((gpr-32 gpr-32 gpr-32 cond-code)
      ("CSNEG_32_condsel" "WZR, WZR, WZR, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64 cond-code)
      ("CSNEG_64_condsel" "XZR, XZR, XZR, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
  )
)

(ldbfminnml
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDBFMINNML_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(ldsetal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDSETAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDSETAL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(stlp
  (c2m
    ((gpr-64 gpr-64 memory)
      ("STLP_64_ldiappstilp" "XZR, XZR, [SP 0]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(bsl1n
  (c4
    ((sve-z sve-z sve-z sve-z)
      ("bsl1n_z_zzz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm" "Zk"))
    )
  )
)

(cpyfpwtrn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFPWTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(rcwsclrl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSCLRL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(cpyfpwtwn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFPWTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(sm3partw1
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SM3PARTW1_VVV4_cryptosha512_3" "VUInteger.4S, VUInteger.4S, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6" "Vm__7"))
    )
  )
)

(stlr
  (c1m1
    ((gpr-32 memory pre-index)
      ("STLR_32S_ldapstl_writeback" "WZR, [SP -4], !" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
    ((gpr-64 memory pre-index)
      ("STLR_64S_ldapstl_writeback" "XZR, [SP -8], !" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
    )
  )
  (c1m
    ((gpr-32 memory)
      ("STLR_SL32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
    ((gpr-64 memory)
      ("STLR_SL64_ldstord" "XZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
    )
  )
)

(cpyetwn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYETWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(orn
  (c5
    ((gpr-32 gpr-32 gpr-32 keyword immediate)
      ("ORN_32_log_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64 keyword immediate)
      ("ORN_64_log_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
  )
  (c4
    ((sve-p sve-p sve-p sve-p)
      ("orn_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("ORN_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(wfet
  (c1
    ((gpr-64)
      ("WFET_only_systeminstrswithreg" "XZR" (("Rd" (reg-range 0 31))) ("XtOrXZR__5"))
    )
  )
)

(cblo
  (c3
    ((gpr-64 immediate immediate)
      ("CBLO_64_imm" "XZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "imm_cbr" "imm9_offset"))
    )
    ((gpr-32 immediate immediate)
      ("CBLO_32_imm" "WZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "imm_cbr" "imm9_offset"))
    )
  )
)

(fmlsl
  (c1
    ((sme-za)
      ("fmlsl_za_zzi_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
      ("fmlsl_za_zzi_2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm__2"))
      ("fmlsl_za_zzi_4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm__2"))
      ("fmlsl_za_zzv_2x1" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn2" "Zm__2"))
      ("fmlsl_za_zzv_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
      ("fmlsl_za_zzv_4x1" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn4" "Zm__2"))
      ("fmlsl_za_zzw_2x2" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("fmlsl_za_zzw_4x4" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMLSL_asimdsame_F" "VUInteger.2S, VUInteger.2H, VUInteger.2H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMLSL_asimdelem_LH" "VUInteger.2S, VUInteger.2H, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(ldursw
  (c1m
    ((gpr-64 memory)
      ("LDURSW_64_ldst_unscaled" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
    )
  )
)

(cpypwtwn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYPWTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(ldff1w
  (c2
    ((reg-list sve-p)
      ("ldff1w_z_p_bz_s_x32_scaled" "{Z UInteger .S}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1w_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1w_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1w_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ldff1w_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1w_z_p_ai_s" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("ldff1w_z_p_br_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldff1w_z_p_br_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldff1w_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1w_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
    )
  )
)

(sm3tt1b
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SM3TT1B_VVV4_crypto3_imm2" "VUInteger.4S, VUInteger.4S, VUInteger.S[UInteger]" (("Rm" (reg-range 0 31)) ("imm2" (imm-range 0 3 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6" "Vm__7"))
    )
  )
)

(cpyfprn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFPRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(cbbeq
  (c3
    ((gpr-32 gpr-32 immediate)
      ("CBBEQ_8_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
    )
  )
)

(uqxtn
  (c2
    ((simd-vector simd-vector)
      ("UQXTN_asimdmisc_N" "VUInteger.8B, VUInteger.8H" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("UQXTN_asisdmisc_N" "BUInteger, HUInteger" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vb_option__3" "Va_option__3"))
    )
  )
)

(swpl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("SWPL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("SWPL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(mls
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("mls_z_p_zzz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Pg" "Zn__2" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("MLS_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("MLS_asimdelem_R" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
    )
    ((sve-z sve-z sve-z)
      ("mls_z_zzzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
      ("mls_z_zzzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__41"))
      ("mls_z_zzzi_d" "ZUInteger.D, ZUInteger.D, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__42"))
    )
  )
)

(cpyfewtwn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFEWTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(rcwsswpp
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSSWPP_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(fmaxnm
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fmaxnm_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
    ((sve-z sve-p sve-z float-const)
      ("fmaxnm_z_p_zs_" "ZUInteger.H, PUInteger/M, ZUInteger.H, 0.0" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMAXNM_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMAXNM_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((reg-list reg-list sve-z)
      ("fmaxnm_mz_zzv_2x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
      ("fmaxnm_mz_zzv_4x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("FMAXNM_S_floatdp2" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__3" "Sm"))
      ("FMAXNM_D_floatdp2" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__2" "Dm"))
      ("FMAXNM_H_floatdp2" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
    )
    ((reg-list reg-list reg-list)
      ("fmaxnm_mz_zzw_2x2" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
      ("fmaxnm_mz_zzw_4x4" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
    )
  )
)

(uqrshrnb
  (c3
    ((sve-z sve-z immediate)
      ("uqrshrnb_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(sqdmlalb
  (c3
    ((sve-z sve-z sve-z)
      ("sqdmlalb_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("sqdmlalb_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
      ("sqdmlalb_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
    )
  )
)

(ldapursh
  (c1m
    ((gpr-32 memory)
      ("LDAPURSH_32_ldapstl_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
    ((gpr-64 memory)
      ("LDAPURSH_64_ldapstl_unscaled" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
    )
  )
)

(crc32x
  (c3
    ((gpr-32 gpr-32 gpr-64)
      ("CRC32X_64C_dp_2src" "WZR, WZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR__2" "WnOrWZR__4" "XmOrXZR__8"))
    )
  )
)

(uqincw
  (c1
    ((gpr-64)
      ("uqincw_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
    ((sve-z)
      ("uqincw_z_zs_" "ZUInteger.S" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
    )
    ((gpr-32)
      ("uqincw_r_rs_uw" "WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Wdn"))
    )
  )
)

(ldnt1sw
  (c2m
    ((reg-list sve-p memory)
      ("ldnt1sw_z_p_ar_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
    )
  )
)

(pacga
  (c3
    ((gpr-64 gpr-64 gpr-64)
      ("PACGA_64P_dp_2src" "XZR, XZR, SP" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmSP_option__2"))
    )
  )
)

(cpyfet
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFET_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(caslh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("CASLH_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
    )
  )
)

(f1cvtlt
  (c2
    ((sve-z sve-z)
      ("f1cvtlt_z_z8_b2h" "ZUInteger.H, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(st2g
  (c1m1
    ((gpr-64 memory pre-index)
      ("ST2G_64Spre_ldsttags" "SP, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option"))
    )
    ((gpr-64 memory immediate)
      ("ST2G_64Spost_ldsttags" "SP, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option"))
    )
  )
  (c1m
    ((gpr-64 memory)
      ("ST2G_64Soffset_ldsttags" "SP, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option" "imm9_option__2"))
    )
  )
)

(st2
  (c1m1
    ((reg-list memory immediate)
      ("ST2_asisdlsep_I2_i" "{V UInteger . 8B V UInteger . 8B}, [SP], 16" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "imm_option__6"))
    )
    ((reg-list memory gpr-64)
      ("ST2_asisdlsep_R2_r" "{V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
    )
    ((reg-list memory memory)
      ("ST2_asisdlso_B2_2b" "{V UInteger . B V UInteger . B}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
      ("ST2_asisdlso_H2_2h" "{V UInteger . H V UInteger . H}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
      ("ST2_asisdlso_S2_2s" "{V UInteger . S V UInteger . S}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
      ("ST2_asisdlso_D2_2d" "{V UInteger . D V UInteger . D}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
    )
  )
  (c1m2
    ((reg-list memory memory immediate)
      ("ST2_asisdlsop_B2_i2b" "{V UInteger . B V UInteger . B}, [UInteger], [SP], 2" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
      ("ST2_asisdlsop_H2_i2h" "{V UInteger . H V UInteger . H}, [UInteger], [SP], 4" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
      ("ST2_asisdlsop_S2_i2s" "{V UInteger . S V UInteger . S}, [UInteger], [SP], 8" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
      ("ST2_asisdlsop_D2_i2d" "{V UInteger . D V UInteger . D}, [UInteger], [SP], 16" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
    )
    ((reg-list memory memory gpr-64)
      ("ST2_asisdlsop_BX2_r2b" "{V UInteger . B V UInteger . B}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
      ("ST2_asisdlsop_HX2_r2h" "{V UInteger . H V UInteger . H}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
      ("ST2_asisdlsop_SX2_r2s" "{V UInteger . S V UInteger . S}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
      ("ST2_asisdlsop_DX2_r2d" "{V UInteger . D V UInteger . D}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
    )
  )
  (c1m
    ((reg-list memory)
      ("ST2_asisdlse_R2" "{V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
    )
  )
)

(frint64z
  (c2
    ((simd-vector simd-vector)
      ("FRINT64Z_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("FRINT64Z_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
      ("FRINT64Z_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("frint64z_z_p_z_z" "ZUInteger.S, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("frint64z_z_p_z_m" "ZUInteger.S, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(tenter
  (c1
    ((immediate)
      ("TENTER_te_exception" "UInteger" (("imm7" (imm-range 0 127 1))) ("imm_tindex"))
    )
  )
)

(addv
  (c2
    ((simd-scalar simd-vector)
      ("ADDV_asimdall_only" "BUInteger, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__2" "Vn"))
    )
  )
)

(sqcvtun
  (c2
    ((sve-z reg-list)
      ("sqcvtun_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
      ("sqcvtun_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
    )
  )
)

(bf2cvtl
  (c2
    ((simd-vector simd-vector)
      ("BF2CVTL_asimdmisc_V" "VUInteger.8H, VUInteger.8B" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((reg-list sve-z)
      ("bf2cvtl_mz2_z8_" "{Z UInteger .H- Z UInteger .H}, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
    )
  )
)

(ldclrpal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDCLRPAL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(ldbfmaxal
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDBFMAXAL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(ldeoralb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDEORALB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(addqv
  (c3
    ((simd-vector sve-p sve-z)
      ("addqv_z_p_z_" "VUInteger.16B, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
    )
  )
)

(sha1su0
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SHA1SU0_VVV_cryptosha3" "VUInteger.4S, VUInteger.4S, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6" "Vm__7"))
    )
  )
)

(fmlalb
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMLALB_asimdsame2_J" "VUInteger.8H, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMLALB_asimdelem_H" "VUInteger.8H, VUInteger.16B, VUInteger.B[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__6"))
    )
    ((sve-z sve-z sve-z)
      ("fmlalb_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
      ("fmlalb_z_z8z8z8i_" "ZUInteger.H, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__56"))
      ("fmlalb_z_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("fmlalb_z_z8z8z8_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(tbnz
  (c3
    ((gpr-32 immediate immediate)
      ("TBNZ_only_testbranch" "WZR, UInteger, SInteger" (("imm14" (imm-range 0 16383 1)) ("Rt" (reg-range 0 31))) ("imm_0_63" "imm14_offset"))
    )
  )
)

(ld3r
  (c1m1
    ((reg-list memory immediate)
      ("LD3R_asisdlsop_R3_i" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], 3" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "imm_option__9"))
    )
    ((reg-list memory gpr-64)
      ("LD3R_asisdlsop_RX3_r" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option" "Xm__2"))
    )
  )
  (c1m
    ((reg-list memory)
      ("LD3R_asisdlso_R3" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "XnSP_option"))
    )
  )
)

(brkas
  (c3
    ((sve-p sve-p sve-p)
      ("brkas_p_p_p_z" "PUInteger.B, PUInteger/Z, PUInteger.B" (("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__3"))
    )
  )
)

(ldseta
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDSETA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDSETA_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(cpymrtwn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYMRTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(cpye
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYE_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(xpaclri
  (c0
    (()
      ("XPACLRI_HI_hints" "" () ())
    )
  )
)

(setffr
  (c0
    (()
      ("setffr_f_" "" () ())
    )
  )
)

(cast
  (c2m
    ((gpr-64 gpr-64 memory)
      ("CAST_C64_comswap_unpriv" "XZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
    )
  )
)

(autibsp
  (c0
    (()
      ("AUTIBSP_HI_hints" "" () ())
    )
  )
)

(st4w
  (c2
    ((reg-list sve-p)
      ("st4w_z_p_br_contiguous" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("st4w_z_p_bi_contiguous" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3"))
    )
  )
)

(rcwscaspal
  (c4m
    ((gpr-64 gpr-64 gpr-64 gpr-64 memory)
      ("RCWSCASPAL_C64_rcwcomswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
    )
  )
)

(ldclrlb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDCLRLB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ld2w
  (c2
    ((reg-list sve-p)
      ("ld2w_z_p_br_contiguous" "{Z UInteger .S Z UInteger .S}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld2w_z_p_bi_contiguous" "{Z UInteger .S Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3"))
    )
  )
)

(and
  (c5
    ((gpr-32 gpr-32 gpr-32 keyword immediate)
      ("AND_32_log_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64 keyword immediate)
      ("AND_64_log_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
  )
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("and_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
    ((sve-p sve-p sve-p sve-p)
      ("and_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
    )
  )
  (c3
    ((gpr-64 gpr-64 immediate)
      ("AND_64_log_imm" "SP, XZR, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option" "XnOrXZR__11" "imm__bitmask_x"))
    )
    ((sve-z sve-z immediate)
      ("and_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm13" (imm-range 0 8191 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2"))
    )
    ((gpr-32 gpr-32 immediate)
      ("AND_32_log_imm" "WSP, WZR, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdWSP_option" "WnOrWZR" "imm__bitmask_w"))
    )
    ((simd-vector simd-vector simd-vector)
      ("AND_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((sve-z sve-z sve-z)
      ("and_z_zz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(subhn
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SUBHN_asimddiff_N" "VUInteger.8B, VUInteger.8H, VUInteger.8H" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(uaddlv
  (c2
    ((simd-scalar simd-vector)
      ("UADDLV_asimdall_only" "HUInteger, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option" "Vn"))
    )
  )
)

(ldrab
  (c1m1
    ((gpr-64 memory pre-index)
      ("LDRAB_64W_ldst_pac" "XZR, [SP], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "Simm9_option"))
    )
  )
  (c1m
    ((gpr-64 memory)
      ("LDRAB_64_ldst_pac" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "Simm9_option"))
    )
  )
)

(uminqv
  (c3
    ((simd-vector sve-p sve-z)
      ("uminqv_z_p_z_" "VUInteger.16B, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
    )
  )
)

(frsqrte
  (c2
    ((simd-vector simd-vector)
      ("FRSQRTE_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FRSQRTE_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((sve-z sve-z)
      ("frsqrte_z_z_" "ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
    ((simd-scalar simd-scalar)
      ("FRSQRTE_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
      ("FRSQRTE_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
    )
  )
)

(stl1
  (c1m1
    ((reg-list memory memory)
      ("STL1_asisdlso_D1" "{V UInteger . D}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "XnSP_option"))
    )
  )
)

(revb
  (c3
    ((sve-z sve-p sve-z)
      ("revb_z_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("revb_z_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(caslt
  (c2m
    ((gpr-64 gpr-64 memory)
      ("CASLT_C64_comswap_unpriv" "XZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
    )
  )
)

(swplb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("SWPLB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(fmops
  (c5
    ((sme-za sve-p sve-p sve-z sve-z)
      ("fmops_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
      ("fmops_za32_pp_zz_16" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
      ("fmops_za_pp_zz_16" "ZAUInteger.H, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__3" "Pn" "Pm" "Zn__2" "Zm"))
      ("fmops_za_pp_zz_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn__2" "Zm"))
    )
  )
)

(lslr
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("lslr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
)

(ldrsw
  (c2
    ((gpr-64 immediate)
      ("LDRSW_64_loadlit" "XZR, SInteger" (("imm19" (imm-range 0 524287 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR__8" "imm19_offset__2"))
    )
  )
  (c1m1
    ((gpr-64 memory pre-index)
      ("LDRSW_64_ldst_immpre" "XZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
    )
    ((gpr-64 memory immediate)
      ("LDRSW_64_ldst_immpost" "XZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
    )
  )
  (c1m
    ((gpr-64 memory)
      ("LDRSW_64_ldst_regoff" "XZR, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "WorX_choice"))
      ("LDRSW_64_ldst_pos" "XZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm12_option__6"))
    )
  )
)

(rcwcas
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWCAS_C64_rcwcomswap" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
    )
  )
)

(sqrshr
  (c3
    ((sve-z reg-list immediate)
      ("sqrshr_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}, UInteger" (("imm4" (imm-range 0 15 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
      ("sqrshr_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}, UInteger" (("imm5" (imm-range 0 31 1)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
    )
  )
)

(cpymtwn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYMTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(fmaxv
  (c2
    ((simd-scalar simd-vector)
      ("FMAXV_asimdall_only_H" "HUInteger, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_hv" "Vn"))
      ("FMAXV_asimdall_only_SD" "SUInteger, VUInteger.4S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vn"))
    )
  )
  (c3
    ((simd-scalar sve-p sve-z)
      ("fmaxv_v_p_z_" "HUInteger, PUInteger, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V__5" "Pg" "Zn"))
    )
  )
)

(ldfaddal
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDFADDAL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFADDAL_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFADDAL_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(ldsetab
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSETAB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(rcwsswpl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSSWPL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(ldaddlb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDADDLB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ldbfaddal
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDBFADDAL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(utmopa
  (c4
    ((sme-za reg-list sve-z sve-z)
      ("utmopa_za_zzzi_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
      ("utmopa_za32_zzzi_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
    )
  )
)

(sqcvtn
  (c2
    ((sve-z reg-list)
      ("sqcvtn_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
      ("sqcvtn_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
    )
  )
)

(sabdlt
  (c3
    ((sve-z sve-z sve-z)
      ("sabdlt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(fsqrt
  (c2
    ((simd-vector simd-vector)
      ("FSQRT_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FSQRT_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("FSQRT_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
      ("FSQRT_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
      ("FSQRT_H_floatdp1" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("fsqrt_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("fsqrt_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(eorqv
  (c3
    ((simd-vector sve-p sve-z)
      ("eorqv_z_p_z_" "VUInteger.16B, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
    )
  )
)

(uqcvtn
  (c2
    ((sve-z reg-list)
      ("uqcvtn_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
      ("uqcvtn_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
    )
  )
)

(prfb
  (c2
    ((prefetch-op sve-p)
      ("prfb_i_p_bz_d_64_scaled" "PLDL1KEEP, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
    )
  )
  (c2m
    ((prefetch-op sve-p memory)
      ("prfb_i_p_bz_s_x32_scaled" "PLDL1KEEP, PUInteger, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
      ("prfb_i_p_bi_s" "PLDL1KEEP, PUInteger, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3"))
      ("prfb_i_p_br_s" "PLDL1KEEP, PUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Xm__4"))
      ("prfb_i_p_ai_s" "PLDL1KEEP, PUInteger, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("Pg" "Zn__3"))
      ("prfb_i_p_bz_d_x32_scaled" "PLDL1KEEP, PUInteger, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
      ("prfb_i_p_ai_d" "PLDL1KEEP, PUInteger, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("Pg" "Zn__3"))
    )
  )
)

(ldg
  (c1m
    ((gpr-64 memory)
      ("LDG_64Loffset_ldsttags" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__4" "XnSP_option" "imm9_option__2"))
    )
  )
)

(incd
  (c1
    ((gpr-64)
      ("incd_r_rs_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
    ((sve-z)
      ("incd_z_zs_" "ZUInteger.D" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
    )
  )
)

(cpyewtrn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYEWTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(autiaz
  (c0
    (()
      ("AUTIAZ_HI_hints" "" () ())
    )
  )
)

(setm
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETM_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__3" "XnOrXZR__6" "XsOrXZR__7"))
    )
  )
)

(shrnb
  (c3
    ((sve-z sve-z immediate)
      ("shrnb_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(cbeq
  (c3
    ((gpr-64 gpr-64 immediate)
      ("CBEQ_64_regs" "XZR, XZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "XmOrXZR__4" "imm9_offset"))
    )
    ((gpr-64 immediate immediate)
      ("CBEQ_64_imm" "XZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "imm_cbr" "imm9_offset"))
    )
    ((gpr-32 gpr-32 immediate)
      ("CBEQ_32_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
    )
    ((gpr-32 immediate immediate)
      ("CBEQ_32_imm" "WZR, UInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "imm_cbr" "imm9_offset"))
    )
  )
)

(smin
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("smin_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((gpr-64 gpr-64 immediate)
      ("SMIN_64_minmax_imm" "XZR, XZR, SInteger" (("imm8" (imm-range 0 255 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
    )
    ((sve-z sve-z immediate)
      ("smin_z_zi_" "ZUInteger.B, ZUInteger.B, SInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__79"))
    )
    ((gpr-32 gpr-32 immediate)
      ("SMIN_32_minmax_imm" "WZR, WZR, SInteger" (("imm8" (imm-range 0 255 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
    )
    ((simd-vector simd-vector simd-vector)
      ("SMIN_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((gpr-32 gpr-32 gpr-32)
      ("SMIN_32_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((reg-list reg-list sve-z)
      ("smin_mz_zzv_2x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
      ("smin_mz_zzv_4x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
    )
    ((gpr-64 gpr-64 gpr-64)
      ("SMIN_64_dp_2src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
    ((reg-list reg-list reg-list)
      ("smin_mz_zzw_2x2" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
      ("smin_mz_zzw_4x4" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
    )
  )
)

(uaddv
  (c3
    ((simd-scalar sve-p sve-z)
      ("uaddv_r_p_z_" "DUInteger, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Dd__2" "Pg" "Zn"))
    )
  )
)

(rev64
  (c2
    ((simd-vector simd-vector)
      ("REV64_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
  )
)

(fcvtnb
  (c2
    ((sve-z reg-list)
      ("fcvtnb_z8_mz2_s2b" "ZUInteger.B, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
    )
  )
)

(cpymrt
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYMRT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(st4
  (c1m1
    ((reg-list memory immediate)
      ("ST4_asisdlsep_I4_i" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], 32" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "imm_option"))
    )
    ((reg-list memory gpr-64)
      ("ST4_asisdlsep_R4_r" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
    )
    ((reg-list memory memory)
      ("ST4_asisdlso_B4_4b" "{V UInteger . B V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
      ("ST4_asisdlso_H4_4h" "{V UInteger . H V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
      ("ST4_asisdlso_S4_4s" "{V UInteger . S V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
      ("ST4_asisdlso_D4_4d" "{V UInteger . D V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
    )
  )
  (c1m2
    ((reg-list memory memory immediate)
      ("ST4_asisdlsop_B4_i4b" "{V UInteger . B V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP], 4" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
      ("ST4_asisdlsop_H4_i4h" "{V UInteger . H V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP], 8" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
      ("ST4_asisdlsop_S4_i4s" "{V UInteger . S V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP], 16" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
      ("ST4_asisdlsop_D4_i4d" "{V UInteger . D V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP], 32" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
    )
    ((reg-list memory memory gpr-64)
      ("ST4_asisdlsop_BX4_r4b" "{V UInteger . B V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
      ("ST4_asisdlsop_HX4_r4h" "{V UInteger . H V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
      ("ST4_asisdlsop_SX4_r4s" "{V UInteger . S V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
      ("ST4_asisdlsop_DX4_r4d" "{V UInteger . D V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
    )
  )
  (c1m
    ((reg-list memory)
      ("ST4_asisdlse_R4" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
    )
  )
)

(stfmaxnm
  (c1m
    ((simd-scalar memory)
      ("STFMAXNM_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
      ("STFMAXNM_32" "SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
      ("STFMAXNM_64" "DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(nors
  (c4
    ((sve-p sve-p sve-p sve-p)
      ("nors_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
    )
  )
)

(ld3h
  (c2
    ((reg-list sve-p)
      ("ld3h_z_p_br_contiguous" "{Z UInteger .H Z UInteger .H Z UInteger .H}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld3h_z_p_bi_contiguous" "{Z UInteger .H Z UInteger .H Z UInteger .H}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3"))
    )
  )
)

(ccmn
  (c4
    ((gpr-64 immediate immediate cond-code)
      ("CCMN_64_condcmp_imm" "XZR, UInteger, UInteger, EQ" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31))) ("XnOrXZR__11" "imm__19"))
    )
    ((gpr-32 gpr-32 immediate cond-code)
      ("CCMN_32_condcmp_reg" "WZR, WZR, UInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("WnOrWZR__3" "WmOrWZR__2"))
    )
    ((gpr-32 immediate immediate cond-code)
      ("CCMN_32_condcmp_imm" "WZR, UInteger, UInteger, EQ" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31))) ("WnOrWZR" "imm__19"))
    )
    ((gpr-64 gpr-64 immediate cond-code)
      ("CCMN_64_condcmp_reg" "XZR, XZR, UInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnOrXZR__12" "XmOrXZR__4"))
    )
  )
)

(ldsetah
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSETAH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(dmb
  (c1
    ((barrier-option)
      ("DMB_BO_barriers" "SY" () ())
    )
  )
)

(setetn
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETETN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__3" "XnOrXZR__7" "XsOrXZR__7"))
    )
  )
)

(cbge
  (c3
    ((gpr-64 gpr-64 immediate)
      ("CBGE_64_regs" "XZR, XZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "XmOrXZR__4" "imm9_offset"))
    )
    ((gpr-32 gpr-32 immediate)
      ("CBGE_32_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
    )
  )
)

(bfmops
  (c5
    ((sme-za sve-p sve-p sve-z sve-z)
      ("bfmops_za32_pp_zz_" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
      ("bfmops_za_pp_zz_16" "ZAUInteger.H, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__3" "Pn" "Pm" "Zn__2" "Zm"))
    )
  )
)

(cmtst
  (c3
    ((simd-vector simd-vector simd-vector)
      ("CMTST_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("CMTST_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
  )
)

(fmlall
  (c1
    ((sme-za)
      ("fmlall_za32_z8z8i_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
      ("fmlall_za32_z8z8i_2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm__2"))
      ("fmlall_za32_z8z8i_4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm__2"))
      ("fmlall_za32_z8z8v_2x1" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn2" "Zm__2"))
      ("fmlall_za32_z8z8v_4x1" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn4" "Zm__2"))
      ("fmlall_za32_z8z8v_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
      ("fmlall_za32_z8z8w_2x2" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("fmlall_za32_z8z8w_4x4" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
)

(ccmp
  (c4
    ((gpr-64 immediate immediate cond-code)
      ("CCMP_64_condcmp_imm" "XZR, UInteger, UInteger, EQ" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31))) ("XnOrXZR__11" "imm__19"))
    )
    ((gpr-32 gpr-32 immediate cond-code)
      ("CCMP_32_condcmp_reg" "WZR, WZR, UInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("WnOrWZR__3" "WmOrWZR__2"))
    )
    ((gpr-32 immediate immediate cond-code)
      ("CCMP_32_condcmp_imm" "WZR, UInteger, UInteger, EQ" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31))) ("WnOrWZR" "imm__19"))
    )
    ((gpr-64 gpr-64 immediate cond-code)
      ("CCMP_64_condcmp_reg" "XZR, XZR, UInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnOrXZR__12" "XmOrXZR__4"))
    )
  )
)

(cpymrn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYMRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(ldapursb
  (c1m
    ((gpr-32 memory)
      ("LDAPURSB_32_ldapstl_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
    ((gpr-64 memory)
      ("LDAPURSB_64_ldapstl_unscaled" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
    )
  )
)

(fmax
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fmax_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
    ((sve-z sve-p sve-z float-const)
      ("fmax_z_p_zs_" "ZUInteger.H, PUInteger/M, ZUInteger.H, 0.0" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMAX_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMAX_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((reg-list reg-list sve-z)
      ("fmax_mz_zzv_2x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
      ("fmax_mz_zzv_4x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("FMAX_S_floatdp2" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__3" "Sm"))
      ("FMAX_D_floatdp2" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__2" "Dm"))
      ("FMAX_H_floatdp2" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
    )
    ((reg-list reg-list reg-list)
      ("fmax_mz_zzw_2x2" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
      ("fmax_mz_zzw_4x4" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
    )
  )
)

(bgrp
  (c3
    ((sve-z sve-z sve-z)
      ("bgrp_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(lslv
  (c3
    ((gpr-32 gpr-32 gpr-32)
      ("LSLV_32_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__4"))
    )
    ((gpr-64 gpr-64 gpr-64)
      ("LSLV_64_dp_2src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__7"))
    )
  )
)

(saddwb
  (c3
    ((sve-z sve-z sve-z)
      ("saddwb_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(rcwcasal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWCASAL_C64_rcwcomswap" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
    )
  )
)

(prfd
  (c2
    ((prefetch-op sve-p)
      ("prfd_i_p_bz_s_x32_scaled" "PLDL1KEEP, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
      ("prfd_i_p_br_s" "PLDL1KEEP, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Xm__4"))
      ("prfd_i_p_bz_d_x32_scaled" "PLDL1KEEP, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
      ("prfd_i_p_bz_d_64_scaled" "PLDL1KEEP, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
    )
  )
  (c2m
    ((prefetch-op sve-p memory)
      ("prfd_i_p_bi_s" "PLDL1KEEP, PUInteger, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3"))
      ("prfd_i_p_ai_s" "PLDL1KEEP, PUInteger, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("Pg" "Zn__3"))
      ("prfd_i_p_ai_d" "PLDL1KEEP, PUInteger, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("Pg" "Zn__3"))
    )
  )
)

(smax
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("smax_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((gpr-64 gpr-64 immediate)
      ("SMAX_64_minmax_imm" "XZR, XZR, SInteger" (("imm8" (imm-range 0 255 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
    )
    ((sve-z sve-z immediate)
      ("smax_z_zi_" "ZUInteger.B, ZUInteger.B, SInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__79"))
    )
    ((gpr-32 gpr-32 immediate)
      ("SMAX_32_minmax_imm" "WZR, WZR, SInteger" (("imm8" (imm-range 0 255 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
    )
    ((simd-vector simd-vector simd-vector)
      ("SMAX_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((gpr-32 gpr-32 gpr-32)
      ("SMAX_32_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((reg-list reg-list sve-z)
      ("smax_mz_zzv_2x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
      ("smax_mz_zzv_4x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
    )
    ((gpr-64 gpr-64 gpr-64)
      ("SMAX_64_dp_2src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
    ((reg-list reg-list reg-list)
      ("smax_mz_zzw_2x2" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
      ("smax_mz_zzw_4x4" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
    )
  )
)

(stzgm
  (c1m
    ((gpr-64 memory)
      ("STZGM_64bulk_ldsttags" "XZR, [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__3" "XnSP_option"))
    )
  )
)

(sqdecw
  (c2
    ((gpr-64 gpr-32)
      ("sqdecw_r_rs_sx" "XUInteger, WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn" "Wdn"))
    )
  )
  (c1
    ((gpr-64)
      ("sqdecw_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
    ((sve-z)
      ("sqdecw_z_zs_" "ZUInteger.S" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
    )
  )
)

(swptl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("SWPTL_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("SWPTL_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(incb
  (c1
    ((gpr-64)
      ("incb_r_rs_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
  )
)

(fccmp
  (c4
    ((simd-scalar simd-scalar immediate cond-code)
      ("FCCMP_S_floatccmp" "SUInteger, SUInteger, UInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Sn__3" "Sm"))
      ("FCCMP_D_floatccmp" "DUInteger, DUInteger, UInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Dn__2" "Dm"))
      ("FCCMP_H_floatccmp" "HUInteger, HUInteger, UInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Hn" "Hm"))
    )
  )
)

(uabd
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("uabd_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("UABD_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(swplh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("SWPLH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(zipq1
  (c3
    ((sve-z sve-z sve-z)
      ("zipq1_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(usmop4a
  (c3
    ((sme-za reg-list sve-z)
      ("usmop4a_za_zz_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
      ("usmop4a_za_zz_h2x1" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
    )
    ((sme-za reg-list reg-list)
      ("usmop4a_za_zz_b2x2" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("usmop4a_za_zz_h2x2" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
    ((sme-za sve-z sve-z)
      ("usmop4a_za_zz_b1x1" "ZAUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
      ("usmop4a_za_zz_h1x1" "ZAUInteger.D, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm_mortlach"))
    )
    ((sme-za sve-z reg-list)
      ("usmop4a_za_zz_b1x2" "ZAUInteger.S, ZUInteger.B, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("usmop4a_za_zz_h1x2" "ZAUInteger.D, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
  )
)

(cmpgt
  (c4
    ((sve-p sve-p sve-z immediate)
      ("cmpgt_p_p_zi_" "PUInteger.B, PUInteger/Z, ZUInteger.B, SInteger" (("size" (element-size B H S D)) ("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn" "imm__43"))
    )
    ((sve-p sve-p sve-z sve-z)
      ("cmpgt_p_p_zz_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
      ("cmpgt_p_p_zw_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
    )
  )
)

(eretab
  (c0
    (()
      ("ERETAB_64E_branch_reg" "" () ())
    )
  )
)

(brab
  (c2
    ((gpr-64 gpr-64)
      ("BRAB_64P_branch_reg" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rm" (reg-range 0 31))) ("XnOrXZR" "XmSP_option"))
    )
  )
)

(ummla
  (c3
    ((simd-vector simd-vector simd-vector)
      ("UMMLA_asimdsame2_G" "VUInteger.4S, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "Vm"))
    )
    ((sve-z sve-z sve-z)
      ("ummla_z_zzz_" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(revd
  (c3
    ((sve-z sve-p sve-z)
      ("revd_z_p_z_m" "ZUInteger.Q, PUInteger/M, ZUInteger.Q" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("revd_z_p_z_z" "ZUInteger.Q, PUInteger/Z, ZUInteger.Q" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(smlsl
  (c1
    ((sme-za)
      ("smlsl_za_zzi_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
      ("smlsl_za_zzi_2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm__2"))
      ("smlsl_za_zzi_4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm__2"))
      ("smlsl_za_zzv_2x1" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn2" "Zm__2"))
      ("smlsl_za_zzv_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
      ("smlsl_za_zzv_4x1" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn4" "Zm__2"))
      ("smlsl_za_zzw_2x2" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("smlsl_za_zzw_4x4" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SMLSL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("SMLSL_asimdelem_L" "VUInteger.4S, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
    )
  )
)

(ld2q
  (c2
    ((reg-list sve-p)
      ("ld2q_z_p_br_contiguous" "{Z UInteger .Q Z UInteger .Q}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld2q_z_p_bi_contiguous" "{Z UInteger .Q Z UInteger .Q}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3"))
    )
  )
)

(ldaxrb
  (c1m
    ((gpr-32 memory)
      ("LDAXRB_LR32_ldstexclr" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
  )
)

(fcsel
  (c4
    ((simd-scalar simd-scalar simd-scalar cond-code)
      ("FCSEL_S_floatsel" "SUInteger, SUInteger, SUInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__3" "Sm"))
      ("FCSEL_D_floatsel" "DUInteger, DUInteger, DUInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__2" "Dm"))
      ("FCSEL_H_floatsel" "HUInteger, HUInteger, HUInteger, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
    )
  )
)

(clrbhb
  (c0
    (()
      ("CLRBHB_HI_hints" "" () ())
    )
  )
)

(cdot
  (c4
    ((sve-z sve-z sve-z immediate)
      ("cdot_z_zzz_" "ZUInteger.S, ZUInteger.B, ZUInteger.B, 0" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
  (c3
    ((sve-z sve-z sve-z)
      ("cdot_z_zzzi_s" "ZUInteger.S, ZUInteger.B, ZUInteger.B[UInteger, 0" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__40"))
      ("cdot_z_zzzi_d" "ZUInteger.D, ZUInteger.H, ZUInteger.H[UInteger, 0" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__39"))
    )
  )
)

(sha1c
  (c3
    ((simd-scalar simd-scalar simd-vector)
      ("SHA1C_QSV_cryptosha3" "QUInteger, SUInteger, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Qd" "Sn__2" "Vm__7"))
    )
  )
)

(ldeorlb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDEORLB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(sbclb
  (c3
    ((sve-z sve-z sve-z)
      ("sbclb_z_zzz_" "ZUInteger.S, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(sete
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETE_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__3" "XnOrXZR__7" "XsOrXZR__7"))
    )
  )
)

(uaddlt
  (c3
    ((sve-z sve-z sve-z)
      ("uaddlt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(st2q
  (c2
    ((reg-list sve-p)
      ("st2q_z_p_br_contiguous" "{Z UInteger .Q Z UInteger .Q}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("st2q_z_p_bi_contiguous" "{Z UInteger .Q Z UInteger .Q}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3"))
    )
  )
)

(ldeorah
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDEORAH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(usubw
  (c3
    ((simd-vector simd-vector simd-vector)
      ("USUBW_asimddiff_W" "VUInteger.8H, VUInteger.8H, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(cntw
  (c1
    ((gpr-64)
      ("cntw_r_s_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rd" (reg-range 0 31))) ("Xd__2"))
    )
  )
)

(rcwcaspa
  (c4m
    ((gpr-64 gpr-64 gpr-64 gpr-64 memory)
      ("RCWCASPA_C64_rcwcomswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
    )
  )
)

(sqrshl
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("sqrshl_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SQRSHL_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("SQRSHL_asisdsame_only" "BUInteger, BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7" "V_option__7"))
    )
  )
)

(rcwclra
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWCLRA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(inch
  (c1
    ((gpr-64)
      ("inch_r_rs_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
    ((sve-z)
      ("inch_z_zs_" "ZUInteger.H" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
    )
  )
)

(ldsmaxlh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSMAXLH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(cpymwt
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYMWT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(sqxtunb
  (c2
    ((sve-z sve-z)
      ("sqxtunb_z_zz_" "ZUInteger.B, ZUInteger.H" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(not
  (c2
    ((simd-vector simd-vector)
      ("NOT_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("not_z_p_z_m" "ZUInteger.B, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("not_z_p_z_z" "ZUInteger.B, PUInteger/Z, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(sqsub
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("sqsub_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((sve-z sve-z immediate)
      ("sqsub_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__27"))
    )
    ((simd-vector simd-vector simd-vector)
      ("SQSUB_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("SQSUB_asisdsame_only" "BUInteger, BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7" "V_option__7"))
    )
    ((sve-z sve-z sve-z)
      ("sqsub_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(retaasppcr
  (c1
    ((gpr-64)
      ("RETAASPPCR_64M_branch_reg" "XZR" (("Rm" (reg-range 0 31))) ("XmOrXZR"))
    )
  )
)

(crc32h
  (c3
    ((gpr-32 gpr-32 gpr-32)
      ("CRC32H_32C_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR__2" "WnOrWZR__4" "WmOrWZR__5"))
    )
  )
)

(dsb
  (c1
    ((barrier-option)
      ("DSB_BO_barriers" "SY" () ())
      ("DSB_BOn_barriers" "SYnXS" (("imm2" (imm-range 0 3 1))) ("imm2_option"))
    )
  )
)

(rcwsclrpa
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSCLRPA_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(mul
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("mul_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((sve-z sve-z immediate)
      ("mul_z_zi_" "ZUInteger.B, ZUInteger.B, SInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__79"))
    )
    ((simd-vector simd-vector simd-vector)
      ("MUL_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("MUL_asimdelem_R" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
    )
    ((sve-z sve-z sve-z)
      ("mul_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
      ("mul_z_zzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__78"))
      ("mul_z_zzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__41"))
      ("mul_z_zzi_d" "ZUInteger.D, ZUInteger.D, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__2" "imm__42"))
    )
  )
)

(retabsppcr
  (c1
    ((gpr-64)
      ("RETABSPPCR_64M_branch_reg" "XZR" (("Rm" (reg-range 0 31))) ("XmOrXZR"))
    )
  )
)

(setptn
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETPTN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XnOrXZR__5" "XsOrXZR__7"))
    )
  )
)

(pacibz
  (c0
    (()
      ("PACIBZ_HI_hints" "" () ())
    )
  )
)

(rcwscasp
  (c4m
    ((gpr-64 gpr-64 gpr-64 gpr-64 memory)
      ("RCWSCASP_C64_rcwcomswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
    )
  )
)

(sqrshrun
  (c3
    ((simd-scalar simd-scalar immediate)
      ("SQRSHRUN_asisdshf_N" "BUInteger, HUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vb_option" "Va_option" "immh_shift__2"))
    )
    ((simd-vector simd-vector immediate)
      ("SQRSHRUN_asimdshf_N" "VUInteger.8B, VUInteger.8H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__6"))
    )
    ((sve-z reg-list immediate)
      ("sqrshrun_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}, UInteger" (("imm4" (imm-range 0 15 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
      ("sqrshrun_z_mz2_b" "ZUInteger.B, {Z UInteger .H- Z UInteger .H}, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
      ("sqrshrun_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}, UInteger" (("imm5" (imm-range 0 31 1)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
    )
  )
)

(bsl2n
  (c4
    ((sve-z sve-z sve-z sve-z)
      ("bsl2n_z_zzz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm" "Zk"))
    )
  )
)

(asr
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("asr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
      ("asr_z_p_zw_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
    ((sve-z sve-p sve-z immediate)
      ("asr_z_p_zi_" "ZUInteger.B, PUInteger/M, ZUInteger.B, UInteger" (("Pg" (reg-range 0 7)) ("imm3" (imm-range 0 7 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
    )
  )
  (c3
    ((sve-z sve-z immediate)
      ("asr_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
    ((sve-z sve-z sve-z)
      ("asr_z_zw_" "ZUInteger.B, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(rcwsetpa
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSETPA_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(stfmaxl
  (c1m
    ((simd-scalar memory)
      ("STFMAXL_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
      ("STFMAXL_32" "SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
      ("STFMAXL_64" "DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(sshl
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SSHL_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("SSHL_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
  )
)

(fneg
  (c2
    ((simd-vector simd-vector)
      ("FNEG_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FNEG_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("FNEG_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
      ("FNEG_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
      ("FNEG_H_floatdp1" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("fneg_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("fneg_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(umopa
  (c5
    ((sme-za sve-p sve-p sve-z sve-z)
      ("umopa_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
      ("umopa_za32_pp_zz_16" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
      ("umopa_za_pp_zz_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn__2" "Zm"))
    )
  )
)

(umsubl
  (c4
    ((gpr-64 gpr-32 gpr-32 gpr-64)
      ("UMSUBL_64WA_dp_3src" "XZR, WZR, WZR, XZR" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "WnOrWZR__5" "WmOrWZR__6" "XaOrXZR__2"))
    )
  )
)

(setgmn
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETGMN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__9" "XsOrXZR__8"))
    )
  )
)

(pnext
  (c3
    ((sve-p sve-p sve-p)
      ("pnext_p_p_p_" "PUInteger.B, PUInteger, PUInteger.B" (("size" (element-size B H S D))) ("Pdn__2" "Pv" "Pdn__2"))
    )
  )
)

(sqrshru
  (c3
    ((sve-z reg-list immediate)
      ("sqrshru_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}, UInteger" (("imm4" (imm-range 0 15 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
      ("sqrshru_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}, UInteger" (("imm5" (imm-range 0 31 1)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
    )
  )
)

(sqcadd
  (c4
    ((sve-z sve-z sve-z immediate)
      ("sqcadd_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B, 90" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm"))
    )
  )
)

(cbbhs
  (c3
    ((gpr-32 gpr-32 immediate)
      ("CBBHS_8_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
    )
  )
)

(sqdmlalt
  (c3
    ((sve-z sve-z sve-z)
      ("sqdmlalt_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("sqdmlalt_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
      ("sqdmlalt_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
    )
  )
)

(cpyfmtn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFMTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(bfmlalt
  (c3
    ((sve-z sve-z sve-z)
      ("bfmlalt_z_zzzi_" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
      ("bfmlalt_z_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(sqshlr
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("sqshlr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
)

(cbhge
  (c3
    ((gpr-32 gpr-32 immediate)
      ("CBHGE_16_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
    )
  )
)

(ldtrb
  (c1m
    ((gpr-32 memory)
      ("LDTRB_32_ldst_unpriv" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
  )
)

(scvtf
  (c2
    ((simd-vector simd-vector)
      ("SCVTF_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("SCVTF_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar gpr-64)
      ("SCVTF_S64_float2int" "SUInteger, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "XnOrXZR__11"))
      ("SCVTF_D64_float2int" "DUInteger, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "XnOrXZR__11"))
      ("SCVTF_H64_float2int" "HUInteger, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "XnOrXZR__11"))
    )
    ((reg-list reg-list)
      ("scvtf_mz_z_2" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__4" "Zn2__3"))
      ("scvtf_mz_z_4" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
    )
    ((sve-z sve-z)
      ("scvtf_z_z_" "ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
    ((simd-scalar simd-scalar)
      ("SCVTF_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
      ("SCVTF_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
      ("SCVTF_sisd_32D" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
      ("SCVTF_sisd_32H" "HUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Sn"))
      ("SCVTF_sisd_64H" "HUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Dn"))
      ("SCVTF_sisd_64S" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
    )
    ((simd-scalar gpr-32)
      ("SCVTF_S32_float2int" "SUInteger, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "WnOrWZR"))
      ("SCVTF_D32_float2int" "DUInteger, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "WnOrWZR"))
      ("SCVTF_H32_float2int" "HUInteger, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "WnOrWZR"))
    )
  )
  (c3
    ((simd-scalar simd-scalar immediate)
      ("SCVTF_asisdshf_C" "HUInteger, HUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__6" "V_option__6" "immh_shift__3"))
    )
    ((simd-vector simd-vector immediate)
      ("SCVTF_asimdshf_C" "VUInteger.4H, VUInteger.4H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__9"))
    )
    ((sve-z sve-p sve-z)
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
    )
    ((simd-scalar gpr-64 immediate)
      ("SCVTF_S64_float2fix" "SUInteger, XZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "XnOrXZR__11"))
      ("SCVTF_D64_float2fix" "DUInteger, XZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "XnOrXZR__11"))
      ("SCVTF_H64_float2fix" "HUInteger, XZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "XnOrXZR__11"))
    )
    ((simd-scalar gpr-32 immediate)
      ("SCVTF_S32_float2fix" "SUInteger, WZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "WnOrWZR"))
      ("SCVTF_D32_float2fix" "DUInteger, WZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "WnOrWZR"))
      ("SCVTF_H32_float2fix" "HUInteger, WZR, UInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "WnOrWZR"))
    )
  )
)

(msrr
  (c3
    ((system-reg gpr-64 gpr-64)
      ("MSRR_SR_systemmovepr" "ACTLR_EL3, XZR, XUInteger" (("Rt" (reg-range 0 31))) ("XtOrXZR__6" "XtPlus1"))
    )
  )
)

(stshh
  (c1
    ((prefetch-op)
      ("STSHH_HI_hints" "KEEP" () ())
    )
  )
)

(ldaxrh
  (c1m
    ((gpr-32 memory)
      ("LDAXRH_LR32_ldstexclr" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
  )
)

(fmlalt
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMLALT_asimdsame2_J" "VUInteger.8H, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMLALT_asimdelem_H" "VUInteger.8H, VUInteger.16B, VUInteger.B[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__6"))
    )
    ((sve-z sve-z sve-z)
      ("fmlalt_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
      ("fmlalt_z_z8z8z8i_" "ZUInteger.H, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__56"))
      ("fmlalt_z_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("fmlalt_z_z8z8z8_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(ld1rsb
  (c2m
    ((reg-list sve-p memory)
      ("ld1rsb_z_p_bi_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ld1rsb_z_p_bi_s32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ld1rsb_z_p_bi_s16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
  )
)

(ld1row
  (c2
    ((reg-list sve-p)
      ("ld1row_z_p_br_contiguous" "{Z UInteger .S}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld1row_z_p_bi_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
  )
)

(sshllt
  (c3
    ((sve-z sve-z immediate)
      ("sshllt_z_zi_" "ZUInteger.H, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(sadalp
  (c2
    ((simd-vector simd-vector)
      ("SADALP_asimdmisc_P" "VUInteger.4H, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("sadalp_z_p_z_" "ZUInteger.H, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda__2" "Pg" "Zn__2"))
    )
  )
)

(st2w
  (c2
    ((reg-list sve-p)
      ("st2w_z_p_br_contiguous" "{Z UInteger .S Z UInteger .S}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("st2w_z_p_bi_contiguous" "{Z UInteger .S Z UInteger .S}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Pg" "XnSP__3"))
    )
  )
)

(ldlar
  (c1m
    ((gpr-32 memory)
      ("LDLAR_LR32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
    ((gpr-64 memory)
      ("LDLAR_LR64_ldstord" "XZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
    )
  )
)

(ldeorab
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDEORAB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(bfmlal
  (c1
    ((sme-za)
      ("bfmlal_za_zzi_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
      ("bfmlal_za_zzi_2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm__2"))
      ("bfmlal_za_zzi_4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm__2"))
      ("bfmlal_za_zzv_2x1" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn2" "Zm__2"))
      ("bfmlal_za_zzv_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
      ("bfmlal_za_zzv_4x1" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn4" "Zm__2"))
      ("bfmlal_za_zzw_2x2" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("bfmlal_za_zzw_4x4" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("BFMLAL_asimdsame2_F_" "VUInteger.4S, VUInteger.8H, VUInteger.8H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("BFMLAL_asimdelem_F" "VUInteger.4S, VUInteger.8H, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__2"))
    )
  )
)

(ldsmina
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDSMINA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDSMINA_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ldtadda
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDTADDA_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDTADDA_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(wfe
  (c0
    (()
      ("WFE_HI_hints" "" () ())
    )
  )
)

(adclb
  (c3
    ((sve-z sve-z sve-z)
      ("adclb_z_zzz_" "ZUInteger.S, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(cpymwtn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYMWTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(ldxr
  (c1m
    ((gpr-32 memory)
      ("LDXR_LR32_ldstexclr" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
    ((gpr-64 memory)
      ("LDXR_LR64_ldstexclr" "XZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
    )
  )
)

(cmpeq
  (c4
    ((sve-p sve-p sve-z immediate)
      ("cmpeq_p_p_zi_" "PUInteger.B, PUInteger/Z, ZUInteger.B, SInteger" (("size" (element-size B H S D)) ("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn" "imm__43"))
    )
    ((sve-p sve-p sve-z sve-z)
      ("cmpeq_p_p_zw_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
      ("cmpeq_p_p_zz_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
    )
  )
)

(faddv
  (c3
    ((simd-scalar sve-p sve-z)
      ("faddv_v_p_z_" "HUInteger, PUInteger, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V__5" "Pg" "Zn"))
    )
  )
)

(cpyertwn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYERTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(uaddlp
  (c2
    ((simd-vector simd-vector)
      ("UADDLP_asimdmisc_P" "VUInteger.4H, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
  )
)

(saba
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SABA_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((sve-z sve-z sve-z)
      ("saba_z_zzz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(dgh
  (c0
    (()
      ("DGH_HI_hints" "" () ())
    )
  )
)

(ldaddlh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDADDLH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(fmaxp
  (c2
    ((simd-scalar simd-vector)
      ("FMAXP_asisdpair_only_H" "HUInteger, VUInteger.2H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vn"))
      ("FMAXP_asisdpair_only_SD" "SUInteger, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__4" "Vn"))
    )
  )
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fmaxp_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMAXP_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMAXP_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(ldfmin
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDFMIN_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMIN_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMIN_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(sabalt
  (c3
    ((sve-z sve-z sve-z)
      ("sabalt_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(ldtrh
  (c1m
    ((gpr-32 memory)
      ("LDTRH_32_ldst_unpriv" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
  )
)

(bdep
  (c3
    ((sve-z sve-z sve-z)
      ("bdep_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(ldbfadd
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDBFADD_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(cmhi
  (c3
    ((simd-vector simd-vector simd-vector)
      ("CMHI_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("CMHI_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
  )
)

(uunpklo
  (c2
    ((sve-z sve-z)
      ("uunpklo_z_z_" "ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(ldtrsh
  (c1m
    ((gpr-32 memory)
      ("LDTRSH_32_ldst_unpriv" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
    ((gpr-64 memory)
      ("LDTRSH_64_ldst_unpriv" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
    )
  )
)

(sqshrun
  (c3
    ((simd-scalar simd-scalar immediate)
      ("SQSHRUN_asisdshf_N" "BUInteger, HUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vb_option" "Va_option" "immh_shift__2"))
    )
    ((simd-vector simd-vector immediate)
      ("SQSHRUN_asimdshf_N" "VUInteger.8B, VUInteger.8H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__6"))
    )
    ((sve-z reg-list immediate)
      ("sqshrun_z_mz2_" "ZUInteger.B, {Z UInteger . H - Z UInteger . H}, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
    )
  )
)

(pext
  (c2
    ((reg-list sve-pn)
      ("pext_pp_rr_" "{P UInteger . B P UInteger . B}, PNUInteger[UInteger]" (("size" (element-size B H S D)) ("PNn" (reg-range 0 7)) ("Pd" (reg-range 0 15))) ("Pd1" "Pd2" "PNn__2" "imm__82"))
    )
    ((sve-p sve-pn)
      ("pext_pn_rr_" "PUInteger.B, PNUInteger[UInteger]" (("size" (element-size B H S D)) ("imm2" (imm-range 0 3 1)) ("PNn" (reg-range 0 7)) ("Pd" (reg-range 0 15))) ("Pd" "PNn__2" "imm__81"))
    )
  )
)

(wfi
  (c0
    (()
      ("WFI_HI_hints" "" () ())
    )
  )
)

(ldclrb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDCLRB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(cpymwtrn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYMWTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(srshlr
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("srshlr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
)

(pacib1716
  (c0
    (()
      ("PACIB1716_HI_hints" "" () ())
    )
  )
)

(dupq
  (c2
    ((sve-z sve-z)
      ("dupq_z_zi_" "ZUInteger.D, ZUInteger.D[UInteger]" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn" "imm__48"))
    )
  )
)

(rorv
  (c3
    ((gpr-32 gpr-32 gpr-32)
      ("RORV_32_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__4"))
    )
    ((gpr-64 gpr-64 gpr-64)
      ("RORV_64_dp_2src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__7"))
    )
  )
)

(prfh
  (c2
    ((prefetch-op sve-p)
      ("prfh_i_p_bz_s_x32_scaled" "PLDL1KEEP, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
      ("prfh_i_p_br_s" "PLDL1KEEP, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Xm__4"))
      ("prfh_i_p_bz_d_x32_scaled" "PLDL1KEEP, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
      ("prfh_i_p_bz_d_64_scaled" "PLDL1KEEP, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3" "Zm__3"))
    )
  )
  (c2m
    ((prefetch-op sve-p memory)
      ("prfh_i_p_bi_s" "PLDL1KEEP, PUInteger, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("Pg" "XnSP__3"))
      ("prfh_i_p_ai_s" "PLDL1KEEP, PUInteger, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("Pg" "Zn__3"))
      ("prfh_i_p_ai_d" "PLDL1KEEP, PUInteger, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("Pg" "Zn__3"))
    )
  )
)

(cpypwtrn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYPWTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(clasta
  (c4
    ((gpr-32 sve-p gpr-32 sve-z)
      ("clasta_r_p_z_" "WZR, PUInteger, WZR, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Rdn" (reg-range 0 31))) ("Pg" "Zm__5"))
    )
    ((sve-z sve-p sve-z sve-z)
      ("clasta_z_p_zz_" "ZUInteger.B, PUInteger, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
    ((simd-scalar sve-p simd-scalar sve-z)
      ("clasta_v_p_z_" "BUInteger, PUInteger, BUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31))) ("V__2" "Pg" "V__2" "Zm__5"))
    )
  )
)

(lduminlb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDUMINLB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(uzpq2
  (c3
    ((sve-z sve-z sve-z)
      ("uzpq2_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(sshr
  (c3
    ((simd-scalar simd-scalar immediate)
      ("SSHR_asisdshf_R" "DUInteger, DUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
    ((simd-vector simd-vector immediate)
      ("SSHR_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__4"))
    )
  )
)

(urshl
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("urshl_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("URSHL_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((reg-list reg-list sve-z)
      ("urshl_mz_zzv_2x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
      ("urshl_mz_zzv_4x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("URSHL_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
    ((reg-list reg-list reg-list)
      ("urshl_mz_zzw_2x2" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
      ("urshl_mz_zzw_4x4" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
    )
  )
)

(ldxp
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDXP_LP64_ldstexclp" "XZR, XZR, [SP 0]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDXP_LP32_ldstexclp" "WZR, WZR, [SP 0]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option"))
    )
  )
)

(cmplo
  (c4
    ((sve-p sve-p sve-z immediate)
      ("cmplo_p_p_zi_" "PUInteger.B, PUInteger/Z, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm7" (imm-range 0 127 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn" "imm__44"))
    )
    ((sve-p sve-p sve-z sve-z)
      ("cmplo_p_p_zw_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
    )
  )
)

(ldfmaxnml
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDFMAXNML_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMAXNML_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMAXNML_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(swptal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("SWPTAL_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("SWPTAL_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ldaprh
  (c1m
    ((gpr-32 memory)
      ("LDAPRH_32L_memop" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__2" "XnSP_option"))
    )
  )
)

(autib
  (c2
    ((gpr-64 gpr-64)
      ("AUTIB_64P_dp_1src" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__7"))
    )
  )
)

(retaasppc
  (c1
    ((immediate)
      ("RETAASPPC_only_miscbranch" "SInteger" (("imm16" (imm-range 0 65535 1))) ("imm16_offset"))
    )
  )
)

(ldtset
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDTSET_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDTSET_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ldff1sh
  (c2
    ((reg-list sve-p)
      ("ldff1sh_z_p_bz_s_x32_scaled" "{Z UInteger .S}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1sh_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1sh_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1sh_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ldff1sh_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1sh_z_p_ai_s" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("ldff1sh_z_p_br_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldff1sh_z_p_br_s32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldff1sh_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1sh_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
    )
  )
)

(ld1rsh
  (c2m
    ((reg-list sve-p memory)
      ("ld1rsh_z_p_bi_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ld1rsh_z_p_bi_s32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
  )
)

(cpyfertn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFERTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(ustmopa
  (c4
    ((sme-za reg-list sve-z sve-z)
      ("ustmopa_za_zzzi_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
    )
  )
)

(autiza
  (c1
    ((gpr-64)
      ("AUTIZA_64Z_dp_1src" "XZR" (("Rd" (reg-range 0 31))) ("XdOrXZR__6"))
    )
  )
)

(sabal
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SABAL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((sve-z sve-z sve-z)
      ("sabal_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(usdot
  (c1
    ((sme-za)
      ("usdot_za_zzi_s2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
      ("usdot_za_zzi_s4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
      ("usdot_za_zzv_s2x1" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
      ("usdot_za_zzv_s4x1" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
      ("usdot_za_zzw_s2x2" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("usdot_za_zzw_s4x4" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("USDOT_asimdsame2_D" "VUInteger.2S, VUInteger.8B, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "Vm"))
      ("USDOT_asimdelem_D" "VUInteger.2S, VUInteger.8B, VUInteger.4B[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "H_L"))
    )
    ((sve-z sve-z sve-z)
      ("usdot_z_zzz_s" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("usdot_z_zzzi_s" "ZUInteger.S, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__40"))
    )
  )
)

(sbclt
  (c3
    ((sve-z sve-z sve-z)
      ("sbclt_z_zzz_" "ZUInteger.S, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(ldumaxah
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDUMAXAH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ldeorb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDEORB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(uaddlb
  (c3
    ((sve-z sve-z sve-z)
      ("uaddlb_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(histseg
  (c3
    ((sve-z sve-z sve-z)
      ("histseg_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(urshlr
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("urshlr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
)

(cpyfert
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFERT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(cmpls
  (c4
    ((sve-p sve-p sve-z immediate)
      ("cmpls_p_p_zi_" "PUInteger.B, PUInteger/Z, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm7" (imm-range 0 127 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn" "imm__44"))
    )
    ((sve-p sve-p sve-z sve-z)
      ("cmpls_p_p_zw_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
    )
  )
)

(shuh
  (c0
    (()
      ("SHUH_HI_hints" "" () ())
    )
  )
)

(stg
  (c1m1
    ((gpr-64 memory pre-index)
      ("STG_64Spre_ldsttags" "SP, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option"))
    )
    ((gpr-64 memory immediate)
      ("STG_64Spost_ldsttags" "SP, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option"))
    )
  )
  (c1m
    ((gpr-64 memory)
      ("STG_64Soffset_ldsttags" "SP, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option" "imm9_option__2"))
    )
  )
)

(uqshrnb
  (c3
    ((sve-z sve-z immediate)
      ("uqshrnb_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(sqshl
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("sqshl_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
    ((sve-z sve-p sve-z immediate)
      ("sqshl_z_p_zi_" "ZUInteger.B, PUInteger/M, ZUInteger.B, UInteger" (("Pg" (reg-range 0 7)) ("imm3" (imm-range 0 7 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
    )
  )
  (c3
    ((simd-scalar simd-scalar immediate)
      ("SQSHL_asisdshf_R" "BUInteger, BUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__5" "V_option__5" "immh_shift"))
    )
    ((simd-vector simd-vector immediate)
      ("SQSHL_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__5"))
    )
    ((simd-vector simd-vector simd-vector)
      ("SQSHL_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("SQSHL_asisdsame_only" "BUInteger, BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7" "V_option__7"))
    )
  )
)

(saddw
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SADDW_asimddiff_W" "VUInteger.8H, VUInteger.8H, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(sqdmlalbt
  (c3
    ((sve-z sve-z sve-z)
      ("sqdmlalbt_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(sshll
  (c3
    ((simd-vector simd-vector immediate)
      ("SSHLL_asimdshf_L" "VUInteger.8H, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__8"))
    )
  )
)

(saddwt
  (c3
    ((sve-z sve-z sve-z)
      ("saddwt_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(prfum
  (c1m
    ((prefetch-op memory)
      ("PRFUM_P_ldst_unscaled" "PLDL1KEEP, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option" "imm9_option"))
    )
  )
)

(smullt
  (c3
    ((sve-z sve-z sve-z)
      ("smullt_z_zzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__78"))
      ("smullt_z_zzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__2" "imm__88"))
      ("smullt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(udiv
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("udiv_z_p_zz_" "ZUInteger.S, PUInteger/M, ZUInteger.S, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((gpr-32 gpr-32 gpr-32)
      ("UDIV_32_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64)
      ("UDIV_64_dp_2src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
  )
)

(rcwscasal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSCASAL_C64_rcwcomswap" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
    )
  )
)

(sm3tt2b
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SM3TT2B_VVV_crypto3_imm2" "VUInteger.4S, VUInteger.4S, VUInteger.S[UInteger]" (("Rm" (reg-range 0 31)) ("imm2" (imm-range 0 3 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6" "Vm__7"))
    )
  )
)

(faddp
  (c2
    ((simd-scalar simd-vector)
      ("FADDP_asisdpair_only_H" "HUInteger, VUInteger.2H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vn"))
      ("FADDP_asisdpair_only_SD" "SUInteger, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__4" "Vn"))
    )
  )
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("faddp_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FADDP_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FADDP_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(brkpas
  (c4
    ((sve-p sve-p sve-p sve-p)
      ("brkpas_p_p_pp_" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
    )
  )
)

(lduminalh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDUMINALH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(fcvtnt
  (c2
    ((sve-z reg-list)
      ("fcvtnt_z8_mz2_s2b" "ZUInteger.B, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("fcvtnt_z_p_z_s2hz" "ZUInteger.H, PUInteger/Z, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("fcvtnt_z_p_z_d2sz" "ZUInteger.S, PUInteger/Z, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("fcvtnt_z_p_z_s2h" "ZUInteger.H, PUInteger/M, ZUInteger.S" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("fcvtnt_z_p_z_d2s" "ZUInteger.S, PUInteger/M, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(pacia
  (c2
    ((gpr-64 gpr-64)
      ("PACIA_64P_dp_1src" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__7"))
    )
  )
)

(bfmopa
  (c5
    ((sme-za sve-p sve-p sve-z sve-z)
      ("bfmopa_za32_pp_zz_" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
      ("bfmopa_za_pp_zz_16" "ZAUInteger.H, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__3" "Pn" "Pm" "Zn__2" "Zm"))
    )
  )
)

(paciasp
  (c0
    (()
      ("PACIASP_HI_hints" "" () ())
    )
  )
)

(ld4r
  (c1m1
    ((reg-list memory immediate)
      ("LD4R_asisdlsop_R4_i" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], 4" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "imm_option__11"))
    )
    ((reg-list memory gpr-64)
      ("LD4R_asisdlsop_RX4_r" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
    )
  )
  (c1m
    ((reg-list memory)
      ("LD4R_asisdlso_R4" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
    )
  )
)

(fcmge
  (c4
    ((sve-p sve-p sve-z float-const)
      ("fcmge_p_p_z0_" "PUInteger.H, PUInteger/Z, ZUInteger.H, 0.0" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn"))
    )
    ((sve-p sve-p sve-z sve-z)
      ("fcmge_p_p_zz_" "PUInteger.H, PUInteger/Z, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
    )
  )
  (c3
    ((simd-scalar simd-scalar float-const)
      ("FCMGE_asisdmiscfp16_FZ" "HUInteger, HUInteger, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
      ("FCMGE_asisdmisc_FZ" "SUInteger, SUInteger, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
    )
    ((simd-vector simd-vector simd-vector)
      ("FCMGE_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FCMGE_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("FCMGE_asisdsamefp16_only" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
      ("FCMGE_asisdsame_only" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9" "V_option__9"))
    )
    ((simd-vector simd-vector float-const)
      ("FCMGE_asimdmiscfp16_FZ" "VUInteger.4H, VUInteger.4H, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FCMGE_asimdmisc_FZ" "VUInteger.2S, VUInteger.2S, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
  )
)

(setgmt
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETGMT_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__9" "XsOrXZR__8"))
    )
  )
)

(rcwscaspa
  (c4m
    ((gpr-64 gpr-64 gpr-64 gpr-64 memory)
      ("RCWSCASPA_C64_rcwcomswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
    )
  )
)

(swpal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("SWPAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("SWPAL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ldsmaxalh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSMAXALH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(cbbge
  (c3
    ((gpr-32 gpr-32 immediate)
      ("CBBGE_8_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
    )
  )
)

(rcwsetal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSETAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(incp
  (c2
    ((gpr-64 sve-p)
      ("incp_r_p_r_" "XUInteger, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Rdn" (reg-range 0 31))) ("Xdn" "Pm__3"))
    )
    ((sve-z sve-p)
      ("incp_z_p_z_" "ZUInteger.H, PUInteger.H" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pm__3"))
    )
  )
)

(setgomtn
  (c0m1
    ((memory gpr-64)
      ("SETGOMTN_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__9"))
    )
  )
)

(addp
  (c2
    ((simd-scalar simd-vector)
      ("ADDP_asisdpair_only" "DUInteger, VUInteger.2D" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vn"))
    )
  )
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("addp_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("ADDP_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(sumop4s
  (c3
    ((sme-za reg-list sve-z)
      ("sumop4s_za_zz_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
      ("sumop4s_za_zz_h2x1" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
    )
    ((sme-za reg-list reg-list)
      ("sumop4s_za_zz_b2x2" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("sumop4s_za_zz_h2x2" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
    ((sme-za sve-z sve-z)
      ("sumop4s_za_zz_b1x1" "ZAUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
      ("sumop4s_za_zz_h1x1" "ZAUInteger.D, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm_mortlach"))
    )
    ((sme-za sve-z reg-list)
      ("sumop4s_za_zz_b1x2" "ZAUInteger.S, ZUInteger.B, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("sumop4s_za_zz_h1x2" "ZAUInteger.D, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
  )
)

(orv
  (c3
    ((simd-scalar sve-p sve-z)
      ("orv_r_p_z_" "BUInteger, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V" "Pg" "Zn"))
    )
  )
)

(st1d
  (c2
    ((reg-list sve-pn)
      ("st1d_mz_p_br_2" "{Z UInteger .D- Z UInteger .D}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
      ("st1d_mz_p_br_4" "{Z UInteger .D- Z UInteger .D}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
      ("st1d_mzx_p_br_2x8" "{Z UInteger .D Z UInteger .D}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
      ("st1d_mzx_p_br_4x4" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
    )
    ((reg-list sve-p)
      ("st1d_z_p_br_u128" "{Z UInteger .Q}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
      ("st1d_z_p_br_" "{Z UInteger .D}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
      ("st1d_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("st1d_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("st1d_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("st1d_z_p_bz_d_64_unscaled" "{Z UInteger . D}, PUInteger, [SP Z UInteger . D]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("st1d_z_p_ai_d" "{Z UInteger .D}, PUInteger, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("st1d_z_p_bi_u128" "{Z UInteger .Q}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("st1d_z_p_bi_" "{Z UInteger .D}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("st1d_za_p_rrr_" "{ZA UInteger H .D [W UInteger UInteger]}, PUInteger, [SP]" (("Rm" (reg-range 0 31)) ("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("ZAt" "HV" "Ws__3" "offs__3" "Pg" "XnSP__3"))
    )
    ((reg-list sve-pn memory)
      ("st1d_mz_p_bi_2" "{Z UInteger .D- Z UInteger .D}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
      ("st1d_mz_p_bi_4" "{Z UInteger .D- Z UInteger .D}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
      ("st1d_mzx_p_bi_2x8" "{Z UInteger .D Z UInteger .D}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
      ("st1d_mzx_p_bi_4x4" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
    )
  )
)

(ldsminalb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSMINALB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ldclrl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDCLRL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDCLRL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ldnf1sw
  (c2m
    ((reg-list sve-p memory)
      ("ldnf1sw_z_p_bi_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
  )
)

(extq
  (c4
    ((sve-z sve-z sve-z immediate)
      ("extq_z_zi_des" "ZUInteger.B, ZUInteger.B, ZUInteger.B, UInteger" (("imm4" (imm-range 0 15 1)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm" "imm__50"))
    )
  )
)

(xaflag
  (c0
    (()
      ("XAFLAG_M_pstate" "" () ())
    )
  )
)

(ld4h
  (c2
    ((reg-list sve-p)
      ("ld4h_z_p_br_contiguous" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld4h_z_p_bi_contiguous" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3"))
    )
  )
)

(bics
  (c5
    ((gpr-32 gpr-32 gpr-32 keyword immediate)
      ("BICS_32_log_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64 keyword immediate)
      ("BICS_64_log_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
  )
  (c4
    ((sve-p sve-p sve-p sve-p)
      ("bics_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
    )
  )
)

(facge
  (c4
    ((sve-p sve-p sve-z sve-z)
      ("facge_p_p_zz_" "PUInteger.H, PUInteger/Z, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FACGE_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FACGE_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("FACGE_asisdsamefp16_only" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
      ("FACGE_asisdsame_only" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9" "V_option__9"))
    )
  )
)

(lasta
  (c3
    ((gpr-32 sve-p sve-z)
      ("lasta_r_p_z_" "WZR, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Pg" "Zn"))
    )
    ((simd-scalar sve-p sve-z)
      ("lasta_v_p_z_" "BUInteger, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V__7" "Pg" "Zn"))
    )
  )
)

(sqdmullt
  (c3
    ((sve-z sve-z sve-z)
      ("sqdmullt_z_zzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__78"))
      ("sqdmullt_z_zzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__2" "imm__88"))
      ("sqdmullt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(swpb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("SWPB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(lduminlh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDUMINLH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(uabdl
  (c3
    ((simd-vector simd-vector simd-vector)
      ("UABDL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(autiasppc
  (c1
    ((immediate)
      ("AUTIASPPC_only_dp_1src_imm" "SInteger" (("imm16" (imm-range 0 65535 1))) ("imm16_offset"))
    )
  )
)

(ldclrpl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDCLRPL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(insr
  (c2
    ((sve-z gpr-32)
      ("insr_z_r_" "ZUInteger.B, WZR" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
    )
    ((sve-z simd-scalar)
      ("insr_z_v_" "ZUInteger.B, BUInteger" (("size" (element-size B H S D)) ("Vm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "V__6"))
    )
  )
)

(ldsminalh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSMINALH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(fdivr
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fdivr_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
)

(uabdlb
  (c3
    ((sve-z sve-z sve-z)
      ("uabdlb_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(expand
  (c3
    ((sve-z sve-p sve-z)
      ("expand_z_p_z_" "ZUInteger.B, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(ldfmax
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDFMAX_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMAX_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMAX_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(saddlb
  (c3
    ((sve-z sve-z sve-z)
      ("saddlb_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(st3q
  (c2
    ((reg-list sve-p)
      ("st3q_z_p_br_contiguous" "{Z UInteger .Q Z UInteger .Q Z UInteger .Q}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("st3q_z_p_bi_contiguous" "{Z UInteger .Q Z UInteger .Q Z UInteger .Q}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3"))
    )
  )
)

(ldsmaxalb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSMAXALB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(pacnbibsppc
  (c0
    (()
      ("PACNBIBSPPC_64LR_dp_1src" "" () ())
    )
  )
)

(psel
  (c3m
    ((sve-p sve-p sve-p memory)
      ("psel_p_ppi_" "PUInteger, PUInteger, PUInteger.D, [W UInteger UInteger]" (("Pn" (reg-range 0 15)) ("Pm" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pn__2" "Pm__2" "Wv__2" "imm__87"))
    )
  )
)

(swppa
  (c2m
    ((gpr-64 gpr-64 memory)
      ("SWPPA_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(nor
  (c4
    ((sve-p sve-p sve-p sve-p)
      ("nor_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
    )
  )
)

(umaxv
  (c2
    ((simd-scalar simd-vector)
      ("UMAXV_asimdall_only" "BUInteger, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__2" "Vn"))
    )
  )
  (c3
    ((simd-scalar sve-p sve-z)
      ("umaxv_r_p_z_" "BUInteger, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V" "Pg" "Zn"))
    )
  )
)

(ldumaxab
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDUMAXAB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(fmla
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fmla_z_p_zzz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Pg" "Zn__2" "Zm"))
    )
  )
  (c1
    ((sme-za)
      ("fmla_za_zzi_h2xi" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
      ("fmla_za_zzi_s2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .S- Z UInteger .S}, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
      ("fmla_za_zzi_d2xi" "ZA.D[WUInteger, UInteger, VGx2, {Z UInteger .D- Z UInteger .D}, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
      ("fmla_za_zzi_h4xi" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
      ("fmla_za_zzi_s4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .S- Z UInteger .S}, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
      ("fmla_za_zzi_d4xi" "ZA.D[WUInteger, UInteger, VGx4, {Z UInteger .D- Z UInteger .D}, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
      ("fmla_za_zzv_2x1_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
      ("fmla_za_zzv_4x1_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
      ("fmla_za_zzw_2x2_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("fmla_za_zzw_4x4_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMLA_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMLA_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMLA_asimdelem_RH_H" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__2"))
      ("FMLA_asimdelem_R_SD" "VUInteger.2S, VUInteger.2S, VUInteger.S[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2"))
    )
    ((simd-scalar simd-scalar simd-vector)
      ("FMLA_asisdelem_RH_H" "HUInteger, HUInteger, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Vm__2"))
      ("FMLA_asisdelem_R_SD" "SUInteger, SUInteger, VUInteger.S[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
    )
    ((sve-z sve-z sve-z)
      ("fmla_z_zzzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
      ("fmla_z_zzzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__55"))
      ("fmla_z_zzzi_d" "ZUInteger.D, ZUInteger.D, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__54"))
    )
  )
  (c1m2
    ((sme-za memory reg-list sve-z)
      ("fmla_za_zzv_2x1" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}, ZUInteger.S" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
      ("fmla_za_zzv_4x1" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}, ZUInteger.S" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
    )
    ((sme-za memory reg-list reg-list)
      ("fmla_za_zzw_2x2" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}, {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("fmla_za_zzw_4x4" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}, {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
)

(ldpsw
  (c2m1
    ((gpr-64 gpr-64 memory immediate)
      ("LDPSW_64_ldstpair_post" "XZR, XZR, [SP], SInteger" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__12"))
    )
    ((gpr-64 gpr-64 memory pre-index)
      ("LDPSW_64_ldstpair_pre" "XZR, XZR, [SP SInteger], !" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__12"))
    )
  )
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDPSW_64_ldstpair_off" "XZR, XZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm7_option"))
    )
  )
)

(ldfaddl
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDFADDL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFADDL_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFADDL_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(trn2
  (c3
    ((sve-p sve-p sve-p)
      ("trn2_p_pp_" "PUInteger.B, PUInteger.B, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pn__2" "Pm__2"))
    )
    ((simd-vector simd-vector simd-vector)
      ("TRN2_asimdperm_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((sve-z sve-z sve-z)
      ("trn2_z_zz_q" "ZUInteger.Q, ZUInteger.Q, ZUInteger.Q" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
      ("trn2_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(orr
  (c5
    ((gpr-32 gpr-32 gpr-32 keyword immediate)
      ("ORR_32_log_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64 keyword immediate)
      ("ORR_64_log_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
  )
  (c2
    ((simd-vector immediate)
      ("ORR_asimdimm_L_sl" "VUInteger.2S, UInteger" (("Rd" (reg-range 0 31))) ("Vd__2"))
      ("ORR_asimdimm_L_hl" "VUInteger.4H, UInteger" (("Rd" (reg-range 0 31))) ("Vd__2"))
    )
  )
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("orr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
    ((sve-p sve-p sve-p sve-p)
      ("orr_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
    )
  )
  (c3
    ((gpr-64 gpr-64 immediate)
      ("ORR_64_log_imm" "SP, XZR, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option" "XnOrXZR__11" "imm__bitmask_x"))
    )
    ((sve-z sve-z immediate)
      ("orr_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm13" (imm-range 0 8191 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2"))
    )
    ((gpr-32 gpr-32 immediate)
      ("ORR_32_log_imm" "WSP, WZR, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdWSP_option" "WnOrWZR" "imm__bitmask_w"))
    )
    ((simd-vector simd-vector simd-vector)
      ("ORR_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((sve-z sve-z sve-z)
      ("orr_z_zz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(st1h
  (c2
    ((reg-list sve-pn)
      ("st1h_mz_p_br_2" "{Z UInteger .H- Z UInteger .H}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
      ("st1h_mz_p_br_4" "{Z UInteger .H- Z UInteger .H}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
      ("st1h_mzx_p_br_2x8" "{Z UInteger .H Z UInteger .H}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
      ("st1h_mzx_p_br_4x4" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PNUInteger" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
    )
    ((reg-list sve-p)
      ("st1h_z_p_br_" "{Z UInteger . H}, PUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
      ("st1h_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("st1h_z_p_bz_s_x32_scaled" "{Z UInteger .S}, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("st1h_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("st1h_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("st1h_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("st1h_z_p_bz_d_64_unscaled" "{Z UInteger . D}, PUInteger, [SP Z UInteger . D]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("st1h_z_p_ai_d" "{Z UInteger .D}, PUInteger, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("st1h_z_p_ai_s" "{Z UInteger .S}, PUInteger, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("st1h_z_p_bi_" "{Z UInteger . H}, PUInteger, [SP]" (("size" (element-size B H S D)) ("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("st1h_za_p_rrr_" "{ZA UInteger H .H [W UInteger UInteger]}, PUInteger, [SP]" (("Rm" (reg-range 0 31)) ("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("ZAt__2" "HV" "Ws__3" "offs__4" "Pg" "XnSP__3"))
    )
    ((reg-list sve-pn memory)
      ("st1h_mz_p_bi_2" "{Z UInteger .H- Z UInteger .H}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
      ("st1h_mz_p_bi_4" "{Z UInteger .H- Z UInteger .H}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
      ("st1h_mzx_p_bi_2x8" "{Z UInteger .H Z UInteger .H}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
      ("st1h_mzx_p_bi_4x4" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PNUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
    )
  )
)

(ldclrh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDCLRH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(rcwswpa
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSWPA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(ldff1sb
  (c2
    ((reg-list sve-p)
      ("ldff1sb_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ldff1sb_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1sb_z_p_ai_s" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("ldff1sb_z_p_br_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldff1sb_z_p_br_s32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldff1sb_z_p_br_s16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldff1sb_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ldff1sb_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
    )
  )
)

(histcnt
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("histcnt_z_p_zz_" "ZUInteger.S, PUInteger/Z, ZUInteger.S, ZUInteger.S" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn__2" "Zm"))
    )
  )
)

(rcwscasl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSCASL_C64_rcwcomswap" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
    )
  )
)

(urshr
  (c4
    ((sve-z sve-p sve-z immediate)
      ("urshr_z_p_zi_" "ZUInteger.B, PUInteger/M, ZUInteger.B, UInteger" (("Pg" (reg-range 0 7)) ("imm3" (imm-range 0 7 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
    )
  )
  (c3
    ((simd-scalar simd-scalar immediate)
      ("URSHR_asisdshf_R" "DUInteger, DUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
    ((simd-vector simd-vector immediate)
      ("URSHR_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__4"))
    )
  )
)

(frsqrts
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FRSQRTS_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FRSQRTS_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("FRSQRTS_asisdsamefp16_only" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
      ("FRSQRTS_asisdsame_only" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9" "V_option__9"))
    )
    ((sve-z sve-z sve-z)
      ("frsqrts_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(swpah
  (c2m
    ((gpr-32 gpr-32 memory)
      ("SWPAH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(cpyfern
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFERN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(ldnp
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDNP_S_ldstnapair_offs" "SUInteger, SUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St1" "St2" "XnSP_option" "imm7_option"))
      ("LDNP_D_ldstnapair_offs" "DUInteger, DUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt1" "Dt2" "XnSP_option" "imm7_option__2"))
      ("LDNP_Q_ldstnapair_offs" "QUInteger, QUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm7_option__3"))
    )
    ((gpr-64 gpr-64 memory)
      ("LDNP_64_ldstnapair_offs" "XZR, XZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm7_option__2"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDNP_32_ldstnapair_offs" "WZR, WZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option" "imm7_option"))
    )
  )
)

(autiasppcr
  (c1
    ((gpr-64)
      ("AUTIASPPCR_64LRR_dp_1src" "XZR" (("Rn" (reg-range 0 31))) ("XnOrXZR__11"))
    )
  )
)

(ldsmaxlb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSMAXLB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ubfm
  (c4
    ((gpr-64 gpr-64 immediate immediate)
      ("UBFM_64M_bitfield" "XZR, XZR, UInteger, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11" "immr__2" "imms__2"))
    )
    ((gpr-32 gpr-32 immediate immediate)
      ("UBFM_32M_bitfield" "WZR, WZR, UInteger, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR" "immr" "imms"))
    )
  )
)

(ldaprb
  (c1m
    ((gpr-32 memory)
      ("LDAPRB_32L_memop" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__2" "XnSP_option"))
    )
  )
)

(subpt
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("subpt_z_p_zz_" "ZUInteger.D, PUInteger/M, ZUInteger.D, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((gpr-64 gpr-64 gpr-64)
      ("SUBPT_64_addsub_pt" "SP, SP, XZR" (("Rm" (reg-range 0 31)) ("imm3" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option__3" "XnSP_option__5" "XmOrXZR__4" "imm3_option"))
    )
    ((sve-z sve-z sve-z)
      ("subpt_z_zz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(nop
  (c0
    (()
      ("NOP_HI_hints" "" () ())
    )
  )
)

(maddpt
  (c4
    ((gpr-64 gpr-64 gpr-64 gpr-64)
      ("MADDPT_64A_dp_3src" "XZR, XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__13" "XmOrXZR__9" "XaOrXZR"))
    )
  )
)

(esb
  (c0
    (()
      ("ESB_HI_hints" "" () ())
    )
  )
)

(smc
  (c1
    ((immediate)
      ("SMC_EX_exception" "UInteger" (("imm16" (imm-range 0 65535 1))) ("imm"))
    )
  )
)

(caspl
  (c4m
    ((gpr-64 gpr-64 gpr-64 gpr-64 memory)
      ("CASPL_CP64_comswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
    )
    ((gpr-32 gpr-32 gpr-32 gpr-32 memory)
      ("CASPL_CP32_comswappr" "WUInteger, WUInteger, WUInteger, WUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ws" "WsPlus1" "Wt" "WtPlus1" "XnSP_option"))
    )
  )
)

(rcwclral
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWCLRAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(andv
  (c3
    ((simd-scalar sve-p sve-z)
      ("andv_r_p_z_" "BUInteger, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V" "Pg" "Zn"))
    )
  )
)

(umlsl
  (c1
    ((sme-za)
      ("umlsl_za_zzi_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
      ("umlsl_za_zzi_2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm__2"))
      ("umlsl_za_zzi_4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm__2"))
      ("umlsl_za_zzv_2x1" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn2" "Zm__2"))
      ("umlsl_za_zzv_1" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2" "Zn__2" "Zm__2"))
      ("umlsl_za_zzv_4x1" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1" "Zn4" "Zm__2"))
      ("umlsl_za_zzw_2x2" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("umlsl_za_zzw_4x4" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("UMLSL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("UMLSL_asimdelem_L" "VUInteger.4S, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
    )
  )
)

(fmul
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fmul_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
    ((sve-z sve-p sve-z float-const)
      ("fmul_z_p_zs_" "ZUInteger.H, PUInteger/M, ZUInteger.H, 0.5" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMUL_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMUL_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMUL_asimdelem_RH_H" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__2"))
      ("FMUL_asimdelem_R_SD" "VUInteger.2S, VUInteger.2S, VUInteger.S[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2"))
    )
    ((simd-scalar simd-scalar simd-vector)
      ("FMUL_asisdelem_RH_H" "HUInteger, HUInteger, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Vm__2"))
      ("FMUL_asisdelem_R_SD" "SUInteger, SUInteger, VUInteger.S[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
    )
    ((reg-list reg-list sve-z)
      ("fmul_mz_zzv_2x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__2" "Zn2__2" "Zm__2"))
      ("fmul_mz_zzv_4x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__3" "Zn4__2" "Zm__2"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("FMUL_S_floatdp2" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__3" "Sm"))
      ("FMUL_D_floatdp2" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__2" "Dm"))
      ("FMUL_H_floatdp2" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
    )
    ((reg-list reg-list reg-list)
      ("fmul_mz_zzw_2x2" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("fmul_mz_zzw_4x4" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
    ((sve-z sve-z sve-z)
      ("fmul_z_zzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__36"))
      ("fmul_z_zzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__55"))
      ("fmul_z_zzi_d" "ZUInteger.D, ZUInteger.D, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__2" "imm__54"))
      ("fmul_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(ldaddh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDADDH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(cpyprtwn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYPRTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(fcmuo
  (c4
    ((sve-p sve-p sve-z sve-z)
      ("fcmuo_p_p_zz_" "PUInteger.H, PUInteger/Z, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
    )
  )
)

(eor
  (c5
    ((gpr-32 gpr-32 gpr-32 keyword immediate)
      ("EOR_32_log_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64 keyword immediate)
      ("EOR_64_log_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
  )
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("eor_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
    ((sve-p sve-p sve-p sve-p)
      ("eor_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
    )
  )
  (c3
    ((gpr-64 gpr-64 immediate)
      ("EOR_64_log_imm" "SP, XZR, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option" "XnOrXZR__11" "imm__bitmask_x"))
    )
    ((sve-z sve-z immediate)
      ("eor_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm13" (imm-range 0 8191 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2"))
    )
    ((gpr-32 gpr-32 immediate)
      ("EOR_32_log_imm" "WSP, WZR, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdWSP_option" "WnOrWZR" "imm__bitmask_w"))
    )
    ((simd-vector simd-vector simd-vector)
      ("EOR_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((sve-z sve-z sve-z)
      ("eor_z_zz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(whilelo
  (c4
    ((sve-pn gpr-64 gpr-64 vector-length)
      ("whilelo_pn_rr_" "PNUInteger.B, XUInteger, XUInteger, VLx2" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("PNd" (reg-range 0 7))) ("PNd" "Xn__4" "Xm__6"))
    )
  )
  (c3
    ((reg-list gpr-64 gpr-64)
      ("whilelo_pp_rr_" "{P UInteger . B P UInteger . B}, XUInteger, XUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 7))) ("Pd1__2" "Pd2__2" "Xn__4" "Xm__6"))
    )
    ((sve-p gpr-32 gpr-32)
      ("whilelo_p_p_rr_" "PUInteger.B, WZR, WZR" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd"))
    )
  )
)

(ssublb
  (c3
    ((sve-z sve-z sve-z)
      ("ssublb_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(rdffrs
  (c2
    ((sve-p sve-p)
      ("rdffrs_p_p_f_" "PUInteger.B, PUInteger/Z" (("Pg" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2"))
    )
  )
)

(ftmopa
  (c4
    ((sme-za reg-list sve-z sve-z)
      ("ftmopa_za_zzzi_s2x1" "ZAUInteger.S, {Z UInteger .S- Z UInteger .S}, ZUInteger.S, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
      ("ftmopa_za32_z8z8zi_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
      ("ftmopa_za32_zzzi_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
      ("ftmopa_za16_z8z8zi_b2x1" "ZAUInteger.H, {Z UInteger .B- Z UInteger .B}, ZUInteger.B, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda__3" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
      ("ftmopa_za_zzzi_h2x1" "ZAUInteger.H, {Z UInteger .H- Z UInteger .H}, ZUInteger.H, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda__3" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
    )
  )
)

(ldaddah
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDADDAH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(bfmlslb
  (c3
    ((sve-z sve-z sve-z)
      ("bfmlslb_z_zzzi_" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
      ("bfmlslb_z_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(sdiv
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("sdiv_z_p_zz_" "ZUInteger.S, PUInteger/M, ZUInteger.S, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((gpr-32 gpr-32 gpr-32)
      ("SDIV_32_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64)
      ("SDIV_64_dp_2src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
  )
)

(bfsub
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("bfsub_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c1
    ((sme-za)
      ("bfsub_za_zw_2x2_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1" "Zm2"))
      ("bfsub_za_zw_4x4_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1__2" "Zm4"))
    )
  )
  (c3
    ((sve-z sve-z sve-z)
      ("bfsub_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(wfit
  (c1
    ((gpr-64)
      ("WFIT_only_systeminstrswithreg" "XZR" (("Rd" (reg-range 0 31))) ("XtOrXZR__5"))
    )
  )
)

(xpaci
  (c1
    ((gpr-64)
      ("XPACI_64Z_dp_1src" "XZR" (("Rd" (reg-range 0 31))) ("XdOrXZR__6"))
    )
  )
)

(uqrshrnt
  (c3
    ((sve-z sve-z immediate)
      ("uqrshrnt_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(lsl
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("lsl_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
      ("lsl_z_p_zw_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
    ((sve-z sve-p sve-z immediate)
      ("lsl_z_p_zi_" "ZUInteger.B, PUInteger/M, ZUInteger.B, UInteger" (("Pg" (reg-range 0 7)) ("imm3" (imm-range 0 7 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
    )
  )
  (c3
    ((sve-z sve-z immediate)
      ("lsl_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
    ((sve-z sve-z sve-z)
      ("lsl_z_zw_" "ZUInteger.B, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(sha512h2
  (c3
    ((simd-scalar simd-scalar simd-vector)
      ("SHA512H2_QQV_cryptosha512_3" "QUInteger, QUInteger, VUInteger.2D" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Qd__2" "Qn" "Vm__7"))
    )
  )
)

(ret
  (c0
    (()
      ("RET_64R_branch_reg" "" (("Rn" (reg-range 0 31))) ())
    )
  )
)

(smov
  (c2
    ((gpr-64 simd-vector)
      ("SMOV_asimdins_X_x" "XZR, VUInteger.B[UInteger]" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Vn" "imm5_index__3"))
    )
    ((gpr-32 simd-vector)
      ("SMOV_asimdins_W_w" "WZR, VUInteger.B[UInteger]" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Vn" "imm5_index__2"))
    )
  )
)

(sqdmlslb
  (c3
    ((sve-z sve-z sve-z)
      ("sqdmlslb_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("sqdmlslb_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
      ("sqdmlslb_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
    )
  )
)

(xtn
  (c2
    ((simd-vector simd-vector)
      ("XTN_asimdmisc_N" "VUInteger.8B, VUInteger.8H" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
  )
)

(rcwsclrpl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSCLRPL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(uqdech
  (c1
    ((gpr-64)
      ("uqdech_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
    ((sve-z)
      ("uqdech_z_zs_" "ZUInteger.H" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
    )
    ((gpr-32)
      ("uqdech_r_rs_uw" "WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Wdn"))
    )
  )
)

(ldnt1h
  (c2
    ((reg-list sve-pn)
      ("ldnt1h_mz_p_br_2" "{Z UInteger .H- Z UInteger .H}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
      ("ldnt1h_mz_p_br_4" "{Z UInteger .H- Z UInteger .H}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
      ("ldnt1h_mzx_p_br_2x8" "{Z UInteger .H Z UInteger .H}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
      ("ldnt1h_mzx_p_br_4x4" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
    )
    ((reg-list sve-p)
      ("ldnt1h_z_p_br_contiguous" "{Z UInteger .H}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ldnt1h_z_p_ar_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("ldnt1h_z_p_bi_contiguous" "{Z UInteger .H}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldnt1h_z_p_ar_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
    )
    ((reg-list sve-pn memory)
      ("ldnt1h_mz_p_bi_2" "{Z UInteger .H- Z UInteger .H}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
      ("ldnt1h_mz_p_bi_4" "{Z UInteger .H- Z UInteger .H}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
      ("ldnt1h_mzx_p_bi_2x8" "{Z UInteger .H Z UInteger .H}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
      ("ldnt1h_mzx_p_bi_4x4" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
    )
  )
)

(whilehi
  (c4
    ((sve-pn gpr-64 gpr-64 vector-length)
      ("whilehi_pn_rr_" "PNUInteger.B, XUInteger, XUInteger, VLx2" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("PNd" (reg-range 0 7))) ("PNd" "Xn__4" "Xm__6"))
    )
  )
  (c3
    ((reg-list gpr-64 gpr-64)
      ("whilehi_pp_rr_" "{P UInteger . B P UInteger . B}, XUInteger, XUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 7))) ("Pd1__2" "Pd2__2" "Xn__4" "Xm__6"))
    )
    ((sve-p gpr-32 gpr-32)
      ("whilehi_p_p_rr_" "PUInteger.B, WZR, WZR" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd"))
    )
  )
)

(fcmpe
  (c2
    ((simd-scalar simd-scalar)
      ("FCMPE_S_floatcmp" "SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Sn__3" "Sm"))
      ("FCMPE_D_floatcmp" "DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Dn__2" "Dm"))
      ("FCMPE_H_floatcmp" "HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Hn" "Hm"))
    )
    ((simd-scalar float-const)
      ("FCMPE_SZ_floatcmp" "SUInteger, 0.0" (("Rn" (reg-range 0 31))) ("Sn"))
      ("FCMPE_DZ_floatcmp" "DUInteger, 0.0" (("Rn" (reg-range 0 31))) ("Dn"))
      ("FCMPE_HZ_floatcmp" "HUInteger, 0.0" (("Rn" (reg-range 0 31))) ("Hn__2"))
    )
  )
)

(rdffr
  (c2
    ((sve-p sve-p)
      ("rdffr_p_p_f_" "PUInteger.B, PUInteger/Z" (("Pg" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2"))
    )
  )
  (c1
    ((sve-p)
      ("rdffr_p_f_" "PUInteger.B" (("Pd" (reg-range 0 15))) ("Pd"))
    )
  )
)

(sturh
  (c1m
    ((gpr-32 memory)
      ("STURH_32_ldst_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
  )
)

(ldnf1sb
  (c2m
    ((reg-list sve-p memory)
      ("ldnf1sb_z_p_bi_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldnf1sb_z_p_bi_s32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldnf1sb_z_p_bi_s16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
  )
)

(brkn
  (c4
    ((sve-p sve-p sve-p sve-p)
      ("brkn_p_p_pp_" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pdm" (reg-range 0 15))) ("Pdm" "Pg__2" "Pn__2" "Pdm"))
    )
  )
)

(subg
  (c4
    ((gpr-64 gpr-64 immediate immediate)
      ("SUBG_64_addsub_immtags" "SP, SP, UInteger, UInteger" (("imm6" (imm-range 0 63 1)) ("imm4" (imm-range 0 15 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option" "XnSP_option__3"))
    )
  )
)

(ushllt
  (c3
    ((sve-z sve-z immediate)
      ("ushllt_z_zi_" "ZUInteger.H, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(stnp
  (c2m
    ((simd-scalar simd-scalar memory)
      ("STNP_S_ldstnapair_offs" "SUInteger, SUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St1" "St2" "XnSP_option" "imm7_option"))
      ("STNP_D_ldstnapair_offs" "DUInteger, DUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt1" "Dt2" "XnSP_option" "imm7_option__2"))
      ("STNP_Q_ldstnapair_offs" "QUInteger, QUInteger, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt1" "Qt2" "XnSP_option" "imm7_option__3"))
    )
    ((gpr-64 gpr-64 memory)
      ("STNP_64_ldstnapair_offs" "XZR, XZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm7_option__2"))
    )
    ((gpr-32 gpr-32 memory)
      ("STNP_32_ldstnapair_offs" "WZR, WZR, [SP]" (("imm7" (imm-range 0 127 1)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option" "imm7_option"))
    )
  )
)

(smlslt
  (c3
    ((sve-z sve-z sve-z)
      ("smlslt_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("smlslt_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
      ("smlslt_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
    )
  )
)

(cbheq
  (c3
    ((gpr-32 gpr-32 immediate)
      ("CBHEQ_16_regs" "WZR, WZR, SInteger" (("Rm" (reg-range 0 31)) ("imm9" (imm-range 0 511 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "WmOrWZR__2" "imm9_offset"))
    )
  )
)

(ursra
  (c3
    ((simd-scalar simd-scalar immediate)
      ("URSRA_asisdshf_R" "DUInteger, DUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
    ((simd-vector simd-vector immediate)
      ("URSRA_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__4"))
    )
    ((sve-z sve-z immediate)
      ("ursra_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2"))
    )
  )
)

(fclamp
  (c3
    ((reg-list sve-z sve-z)
      ("fclamp_mz_zz_2" "{Z UInteger . H - Z UInteger . H}, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn__2" "Zm"))
      ("fclamp_mz_zz_4" "{Z UInteger . H - Z UInteger . H}, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn__2" "Zm"))
    )
    ((sve-z sve-z sve-z)
      ("fclamp_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(seten
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETEN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__3" "XnOrXZR__7" "XsOrXZR__7"))
    )
  )
)

(umov
  (c2
    ((gpr-64 simd-vector)
      ("UMOV_asimdins_X_x" "XZR, VUInteger.D[UInteger" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Vn"))
    )
    ((gpr-32 simd-vector)
      ("UMOV_asimdins_W_w" "WZR, VUInteger.B[UInteger]" (("imm5" (imm-range 0 31 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Vn" "imm5_index__3"))
    )
  )
)

(pacibsppc
  (c0
    (()
      ("PACIBSPPC_64LR_dp_1src" "" () ())
    )
  )
)

(stlxrb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("STLXRB_SR32_ldstexclr" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "WtOrWZR__4" "XnSP_option"))
    )
  )
)

(frinta
  (c2
    ((simd-vector simd-vector)
      ("FRINTA_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FRINTA_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((reg-list reg-list)
      ("frinta_mz_z_2" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__4" "Zn2__3"))
      ("frinta_mz_z_4" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
    )
    ((simd-scalar simd-scalar)
      ("FRINTA_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
      ("FRINTA_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
      ("FRINTA_H_floatdp1" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("frinta_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("frinta_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(sbfm
  (c4
    ((gpr-64 gpr-64 immediate immediate)
      ("SBFM_64M_bitfield" "XZR, XZR, UInteger, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11" "immr__2" "imms__2"))
    )
    ((gpr-32 gpr-32 immediate immediate)
      ("SBFM_32M_bitfield" "WZR, WZR, UInteger, UInteger" (("immr" (imm-range 0 63 1)) ("imms" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR" "immr" "imms"))
    )
  )
)

(fcmp
  (c2
    ((simd-scalar simd-scalar)
      ("FCMP_S_floatcmp" "SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Sn__3" "Sm"))
      ("FCMP_D_floatcmp" "DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Dn__2" "Dm"))
      ("FCMP_H_floatcmp" "HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("Hn" "Hm"))
    )
    ((simd-scalar float-const)
      ("FCMP_SZ_floatcmp" "SUInteger, 0.0" (("Rn" (reg-range 0 31))) ("Sn"))
      ("FCMP_DZ_floatcmp" "DUInteger, 0.0" (("Rn" (reg-range 0 31))) ("Dn"))
      ("FCMP_HZ_floatcmp" "HUInteger, 0.0" (("Rn" (reg-range 0 31))) ("Hn__2"))
    )
  )
)

(rcwsswp
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSSWP_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(umin
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("umin_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((gpr-64 gpr-64 immediate)
      ("UMIN_64U_minmax_imm" "XZR, XZR, UInteger" (("imm8" (imm-range 0 255 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
    )
    ((sve-z sve-z immediate)
      ("umin_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__37"))
    )
    ((gpr-32 gpr-32 immediate)
      ("UMIN_32U_minmax_imm" "WZR, WZR, UInteger" (("imm8" (imm-range 0 255 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
    )
    ((simd-vector simd-vector simd-vector)
      ("UMIN_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((gpr-32 gpr-32 gpr-32)
      ("UMIN_32_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((reg-list reg-list sve-z)
      ("umin_mz_zzv_2x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
      ("umin_mz_zzv_4x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
    )
    ((gpr-64 gpr-64 gpr-64)
      ("UMIN_64_dp_2src" "XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
    ((reg-list reg-list reg-list)
      ("umin_mz_zzw_2x2" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
      ("umin_mz_zzw_4x4" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
    )
  )
)

(clz
  (c2
    ((simd-vector simd-vector)
      ("CLZ_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((gpr-64 gpr-64)
      ("CLZ_64_dp_1src" "XZR, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
    )
    ((gpr-32 gpr-32)
      ("CLZ_32_dp_1src" "WZR, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("clz_z_p_z_m" "ZUInteger.B, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("clz_z_p_z_z" "ZUInteger.B, PUInteger/Z, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(ldtrsb
  (c1m
    ((gpr-32 memory)
      ("LDTRSB_32_ldst_unpriv" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
    ((gpr-64 memory)
      ("LDTRSB_64_ldst_unpriv" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
    )
  )
)

(cadd
  (c4
    ((sve-z sve-z sve-z immediate)
      ("cadd_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B, 90" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm"))
    )
  )
)

(uqcvt
  (c2
    ((sve-z reg-list)
      ("uqcvt_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
      ("uqcvt_z_mz4_" "ZUInteger.B, {Z UInteger . S - Z UInteger . S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
    )
  )
)

(rsubhn
  (c3
    ((simd-vector simd-vector simd-vector)
      ("RSUBHN_asimddiff_N" "VUInteger.8B, VUInteger.8H, VUInteger.8H" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(uunpkhi
  (c2
    ((sve-z sve-z)
      ("uunpkhi_z_z_" "ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(ldbfmaxl
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDBFMAXL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(fcvtxnt
  (c3
    ((sve-z sve-p sve-z)
      ("fcvtxnt_z_p_z_d2sz" "ZUInteger.S, PUInteger/Z, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("fcvtxnt_z_p_z_d2s" "ZUInteger.S, PUInteger/M, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(setpt
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETPT_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XnOrXZR__5" "XsOrXZR__7"))
    )
  )
)

(bf1cvtl
  (c2
    ((simd-vector simd-vector)
      ("BF1CVTL_asimdmisc_V" "VUInteger.8H, VUInteger.8B" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((reg-list sve-z)
      ("bf1cvtl_mz2_z8_" "{Z UInteger .H- Z UInteger .H}, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
    )
  )
)

(ldsminl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDSMINL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDSMINL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(sturb
  (c1m
    ((gpr-32 memory)
      ("STURB_32_ldst_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
  )
)

(fadda
  (c4
    ((simd-scalar sve-p simd-scalar sve-z)
      ("fadda_v_p_z_" "HUInteger, PUInteger, HUInteger, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31))) ("V__4" "Pg" "V__4" "Zm__5"))
    )
  )
)

(ptrue
  (c1
    ((sve-pn)
      ("ptrue_pn_i_" "PNUInteger.B" (("size" (element-size B H S D)) ("PNd" (reg-range 0 7))) ("PNd"))
    )
    ((sve-p)
      ("ptrue_p_s_" "PUInteger.B" (("size" (element-size B H S D)) ("Pd" (reg-range 0 15))) ("Pd"))
    )
  )
)

(whilege
  (c4
    ((sve-pn gpr-64 gpr-64 vector-length)
      ("whilege_pn_rr_" "PNUInteger.B, XUInteger, XUInteger, VLx2" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("PNd" (reg-range 0 7))) ("PNd" "Xn__4" "Xm__6"))
    )
  )
  (c3
    ((reg-list gpr-64 gpr-64)
      ("whilege_pp_rr_" "{P UInteger . B P UInteger . B}, XUInteger, XUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 7))) ("Pd1__2" "Pd2__2" "Xn__4" "Xm__6"))
    )
    ((sve-p gpr-32 gpr-32)
      ("whilege_p_p_rr_" "PUInteger.B, WZR, WZR" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd"))
    )
  )
)

(bl
  (c1
    ((immediate)
      ("BL_only_branch_imm" "SInteger" (("imm26" (imm-range 0 67108863 1))) ("imm26_offset"))
    )
  )
)

(cpyfmrtrn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFMRTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(uqshrnt
  (c3
    ((sve-z sve-z immediate)
      ("uqshrnt_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(umaxqv
  (c3
    ((simd-vector sve-p sve-z)
      ("umaxqv_z_p_z_" "VUInteger.16B, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
    )
  )
)

(uqshl
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("uqshl_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
    ((sve-z sve-p sve-z immediate)
      ("uqshl_z_p_zi_" "ZUInteger.B, PUInteger/M, ZUInteger.B, UInteger" (("Pg" (reg-range 0 7)) ("imm3" (imm-range 0 7 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
    )
  )
  (c3
    ((simd-scalar simd-scalar immediate)
      ("UQSHL_asisdshf_R" "BUInteger, BUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__5" "V_option__5" "immh_shift"))
    )
    ((simd-vector simd-vector immediate)
      ("UQSHL_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__5"))
    )
    ((simd-vector simd-vector simd-vector)
      ("UQSHL_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("UQSHL_asisdsame_only" "BUInteger, BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7" "V_option__7"))
    )
  )
)

(ldnt1b
  (c2m
    ((reg-list sve-p memory)
      ("ldnt1b_z_p_ar_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("ldnt1b_z_p_br_contiguous" "{Z UInteger .B}, PUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
      ("ldnt1b_z_p_bi_contiguous" "{Z UInteger .B}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldnt1b_z_p_ar_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
    )
    ((reg-list sve-pn memory)
      ("ldnt1b_mz_p_br_2" "{Z UInteger .B- Z UInteger .B}, PNUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
      ("ldnt1b_mz_p_br_4" "{Z UInteger .B- Z UInteger .B}, PNUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
      ("ldnt1b_mz_p_bi_2" "{Z UInteger .B- Z UInteger .B}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
      ("ldnt1b_mz_p_bi_4" "{Z UInteger .B- Z UInteger .B}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
      ("ldnt1b_mzx_p_br_2x8" "{Z UInteger .B Z UInteger .B}, PNUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
      ("ldnt1b_mzx_p_br_4x4" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PNUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
      ("ldnt1b_mzx_p_bi_2x8" "{Z UInteger .B Z UInteger .B}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
      ("ldnt1b_mzx_p_bi_4x4" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
    )
  )
)

(madd
  (c4
    ((gpr-32 gpr-32 gpr-32 gpr-32)
      ("MADD_32A_dp_3src" "WZR, WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__5" "WmOrWZR__6" "WaOrWZR"))
    )
    ((gpr-64 gpr-64 gpr-64 gpr-64)
      ("MADD_64A_dp_3src" "XZR, XZR, XZR, XZR" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__13" "XmOrXZR__9" "XaOrXZR"))
    )
  )
)

(ldclralb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDCLRALB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(usublt
  (c3
    ((sve-z sve-z sve-z)
      ("usublt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(ldnf1sh
  (c2m
    ((reg-list sve-p memory)
      ("ldnf1sh_z_p_bi_s64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldnf1sh_z_p_bi_s32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
  )
)

(cpy
  (c3
    ((sve-z sve-p gpr-32)
      ("cpy_z_p_r_" "ZUInteger.B, PUInteger/M, WSP" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg"))
    )
    ((sve-z sve-p simd-scalar)
      ("cpy_z_p_v_" "ZUInteger.B, PUInteger/M, BUInteger" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Vn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "V__3"))
    )
    ((sve-z sve-p immediate)
      ("cpy_z_o_i_" "ZUInteger.B, PUInteger/Z, SInteger" (("size" (element-size B H S D)) ("Pg" (reg-range 0 15)) ("imm8" (imm-range 0 255 1)) ("Zd" (reg-range 0 31))) ("Zd" "Pg__2" "imm__46"))
      ("cpy_z_p_i_" "ZUInteger.B, PUInteger/M, SInteger" (("size" (element-size B H S D)) ("Pg" (reg-range 0 15)) ("imm8" (imm-range 0 255 1)) ("Zd" (reg-range 0 31))) ("Zd" "Pg__2" "imm__46"))
    )
  )
)

(ldfminl
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDFMINL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMINL_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMINL_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(madpt
  (c3
    ((sve-z sve-z sve-z)
      ("madpt_z_zzz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Za" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zm" "Za"))
    )
  )
)

(dupm
  (c2
    ((sve-z immediate)
      ("dupm_z_i_" "ZUInteger.B, UInteger" (("imm13" (imm-range 0 8191 1)) ("Zd" (reg-range 0 31))) ("Zd"))
    )
  )
)

(pacdzb
  (c1
    ((gpr-64)
      ("PACDZB_64Z_dp_1src" "XZR" (("Rd" (reg-range 0 31))) ("XdOrXZR__6"))
    )
  )
)

(ldaddal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDADDAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDADDAL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ldsmax
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDSMAX_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDSMAX_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(rcwclrpa
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWCLRPA_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(stz2g
  (c1m1
    ((gpr-64 memory pre-index)
      ("STZ2G_64Spre_ldsttags" "SP, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option"))
    )
    ((gpr-64 memory immediate)
      ("STZ2G_64Spost_ldsttags" "SP, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option"))
    )
  )
  (c1m
    ((gpr-64 memory)
      ("STZ2G_64Soffset_ldsttags" "SP, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtSP_option" "XnSP_option" "imm9_option__2"))
    )
  )
)

(ldadd
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDADD_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDADD_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(smaxp
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("smaxp_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SMAXP_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(cpyfpwtn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFPWTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(ldbfminnm
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDBFMINNM_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(ldsmaxal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDSMAXAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDSMAXAL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(nand
  (c4
    ((sve-p sve-p sve-p sve-p)
      ("nand_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
    )
  )
)

(sqrdmlah
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SQRDMLAH_asimdsame2_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("SQRDMLAH_asimdelem_R" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
    )
    ((simd-scalar simd-scalar simd-vector)
      ("SQRDMLAH_asisdelem_R" "HUInteger, HUInteger, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__8" "V_option__8" "Vm__5"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("SQRDMLAH_asisdsame2_only" "HUInteger, HUInteger, HUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__8" "V_option__8" "V_option__8"))
    )
    ((sve-z sve-z sve-z)
      ("sqrdmlah_z_zzz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("sqrdmlah_z_zzzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
      ("sqrdmlah_z_zzzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__41"))
      ("sqrdmlah_z_zzzi_d" "ZUInteger.D, ZUInteger.D, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__42"))
    )
  )
)

(movprfx
  (c2
    ((sve-z sve-z)
      ("movprfx_z_z_" "ZUInteger, ZUInteger" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("movprfx_z_p_z_" "ZUInteger.B, PUInteger/Z, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "ZM" "Zn"))
    )
  )
)

(fvdot
  (c1
    ((sme-za)
      ("fvdot_za_zzi_2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
      ("fvdot_za_z8z8i_2xi" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
    )
  )
)

(bf2cvt
  (c2
    ((reg-list sve-z)
      ("bf2cvt_mz2_z8_" "{Z UInteger .H- Z UInteger .H}, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
    )
    ((sve-z sve-z)
      ("bf2cvt_z_z8_b2bf" "ZUInteger.H, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(uminv
  (c2
    ((simd-scalar simd-vector)
      ("UMINV_asimdall_only" "BUInteger, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__2" "Vn"))
    )
  )
  (c3
    ((simd-scalar sve-p sve-z)
      ("uminv_r_p_z_" "BUInteger, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V" "Pg" "Zn"))
    )
  )
)

(ldfmaxa
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDFMAXA_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMAXA_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMAXA_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(rcwssetpa
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSSETPA_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(decw
  (c1
    ((gpr-64)
      ("decw_r_rs_" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
    ((sve-z)
      ("decw_z_zs_" "ZUInteger.S" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
    )
  )
)

(ldnt1d
  (c2
    ((reg-list sve-pn)
      ("ldnt1d_mz_p_br_2" "{Z UInteger .D- Z UInteger .D}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
      ("ldnt1d_mz_p_br_4" "{Z UInteger .D- Z UInteger .D}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
      ("ldnt1d_mzx_p_br_2x8" "{Z UInteger .D Z UInteger .D}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
      ("ldnt1d_mzx_p_br_4x4" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
    )
    ((reg-list sve-p)
      ("ldnt1d_z_p_br_contiguous" "{Z UInteger .D}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ldnt1d_z_p_bi_contiguous" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldnt1d_z_p_ar_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
    )
    ((reg-list sve-pn memory)
      ("ldnt1d_mz_p_bi_2" "{Z UInteger .D- Z UInteger .D}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
      ("ldnt1d_mz_p_bi_4" "{Z UInteger .D- Z UInteger .D}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
      ("ldnt1d_mzx_p_bi_2x8" "{Z UInteger .D Z UInteger .D}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
      ("ldnt1d_mzx_p_bi_4x4" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
    )
  )
)

(sha512h
  (c3
    ((simd-scalar simd-scalar simd-vector)
      ("SHA512H_QQV_cryptosha512_3" "QUInteger, QUInteger, VUInteger.2D" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Qd__2" "Qn" "Vm__7"))
    )
  )
)

(ldclrp
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDCLRP_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(sqshrn
  (c3
    ((simd-scalar simd-scalar immediate)
      ("SQSHRN_asisdshf_N" "BUInteger, HUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vb_option" "Va_option" "immh_shift__2"))
    )
    ((simd-vector simd-vector immediate)
      ("SQSHRN_asimdshf_N" "VUInteger.8B, VUInteger.8H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__6"))
    )
    ((sve-z reg-list immediate)
      ("sqshrn_z_mz2_" "ZUInteger.B, {Z UInteger . H - Z UInteger . H}, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
    )
  )
)

(smop4s
  (c3
    ((sme-za reg-list sve-z)
      ("smop4s_za_zz_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
      ("smop4s_za32_zz_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
      ("smop4s_za_zz_h2x1" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
    )
    ((sme-za reg-list reg-list)
      ("smop4s_za_zz_b2x2" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("smop4s_za32_zz_h2x2" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("smop4s_za_zz_h2x2" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
    ((sme-za sve-z sve-z)
      ("smop4s_za_zz_b1x1" "ZAUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
      ("smop4s_za32_zz_h1x1" "ZAUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
      ("smop4s_za_zz_h1x1" "ZAUInteger.D, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm_mortlach"))
    )
    ((sme-za sve-z reg-list)
      ("smop4s_za_zz_b1x2" "ZAUInteger.S, ZUInteger.B, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("smop4s_za32_zz_h1x2" "ZAUInteger.S, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("smop4s_za_zz_h1x2" "ZAUInteger.D, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
  )
)

(frinti
  (c2
    ((simd-vector simd-vector)
      ("FRINTI_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FRINTI_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("FRINTI_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
      ("FRINTI_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
      ("FRINTI_H_floatdp1" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("frinti_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("frinti_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(ldxrb
  (c1m
    ((gpr-32 memory)
      ("LDXRB_LR32_ldstexclr" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
  )
)

(ld4w
  (c2
    ((reg-list sve-p)
      ("ld4w_z_p_br_contiguous" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld4w_z_p_bi_contiguous" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3"))
    )
  )
)

(cpyfptrn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFPTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(ld64b
  (c1m
    ((gpr-64 memory)
      ("LD64B_64L_memop" "XZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__9" "XnSP_option"))
    )
  )
)

(mlapt
  (c3
    ((sve-z sve-z sve-z)
      ("mlapt_z_zzz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(ldfminnmal
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDFMINNMAL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMINNMAL_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMINNMAL_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(setgptn
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETGPTN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__4" "XnOrXZR__8" "XsOrXZR__8"))
    )
  )
)

(subhnb
  (c3
    ((sve-z sve-z sve-z)
      ("subhnb_z_zz_" "ZUInteger.B, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(chkfeat
  (c1
    ((gpr-64)
      ("CHKFEAT_HF_hints" "X16" () ())
    )
  )
)

(sqrshrunt
  (c3
    ((sve-z sve-z immediate)
      ("sqrshrunt_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(usmopa
  (c5
    ((sme-za sve-p sve-p sve-z sve-z)
      ("usmopa_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
      ("usmopa_za_pp_zz_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn__2" "Zm"))
    )
  )
)

(rshrnb
  (c3
    ((sve-z sve-z immediate)
      ("rshrnb_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(addhnt
  (c3
    ((sve-z sve-z sve-z)
      ("addhnt_z_zz_" "ZUInteger.B, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(andqv
  (c3
    ((simd-vector sve-p sve-z)
      ("andqv_z_p_z_" "VUInteger.16B, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
    )
  )
)

(fcvtms
  (c2
    ((simd-vector simd-vector)
      ("FCVTMS_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FCVTMS_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("FCVTMS_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
      ("FCVTMS_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
      ("FCVTMS_sisd_32D" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
      ("FCVTMS_sisd_32H" "SUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Hn__2"))
      ("FCVTMS_sisd_64H" "DUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Hn__2"))
      ("FCVTMS_sisd_64S" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
    )
    ((gpr-32 simd-scalar)
      ("FCVTMS_32S_float2int" "WZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
      ("FCVTMS_32D_float2int" "WZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
      ("FCVTMS_32H_float2int" "WZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
    )
    ((gpr-64 simd-scalar)
      ("FCVTMS_64S_float2int" "XZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
      ("FCVTMS_64D_float2int" "XZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
      ("FCVTMS_64H_float2int" "XZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
    )
  )
)

(ldfminnm
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDFMINNM_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMINNM_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMINNM_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(rcwcaspal
  (c4m
    ((gpr-64 gpr-64 gpr-64 gpr-64 memory)
      ("RCWCASPAL_C64_rcwcomswappr" "XUInteger, XUInteger, XUInteger, XUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
    )
  )
)

(usmop4s
  (c3
    ((sme-za reg-list sve-z)
      ("usmop4s_za_zz_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
      ("usmop4s_za_zz_h2x1" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
    )
    ((sme-za reg-list reg-list)
      ("usmop4s_za_zz_b2x2" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("usmop4s_za_zz_h2x2" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
    ((sme-za sve-z sve-z)
      ("usmop4s_za_zz_b1x1" "ZAUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
      ("usmop4s_za_zz_h1x1" "ZAUInteger.D, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm_mortlach"))
    )
    ((sme-za sve-z reg-list)
      ("usmop4s_za_zz_b1x2" "ZAUInteger.S, ZUInteger.B, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("usmop4s_za_zz_h1x2" "ZAUInteger.D, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
  )
)

(usmlall
  (c1
    ((sme-za)
      ("usmlall_za_zzi_s" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
      ("usmlall_za_zzi_s2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm__2"))
      ("usmlall_za_zzi_s4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm__2"))
      ("usmlall_za_zzv_s2x1" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger . B- Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn2" "Zm__2"))
      ("usmlall_za_zzv_s" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
      ("usmlall_za_zzv_s4x1" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger . B- Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn4" "Zm__2"))
      ("usmlall_za_zzw_s2x2" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger . B- Z UInteger . B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("usmlall_za_zzw_s4x4" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger . B- Z UInteger . B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
)

(cpyptwn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYPTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(caspt
  (c4m
    ((gpr-64 gpr-64 gpr-64 gpr-64 memory)
      ("CASPT_CP64_comswappr_unpriv" "XUInteger, XUInteger, XUInteger, XUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
    )
  )
)

(fmaxnmqv
  (c3
    ((simd-vector sve-p sve-z)
      ("fmaxnmqv_z_p_z_" "VUInteger.8H, PUInteger, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
    )
  )
)

(ld1rd
  (c2m
    ((reg-list sve-p memory)
      ("ld1rd_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
  )
)

(addsubp
  (c3
    ((sve-z sve-z sve-z)
      ("addsubp_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(brkbs
  (c3
    ((sve-p sve-p sve-p)
      ("brkbs_p_p_p_z" "PUInteger.B, PUInteger/Z, PUInteger.B" (("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__3"))
    )
  )
)

(sha256su0
  (c2
    ((simd-vector simd-vector)
      ("SHA256SU0_VV_cryptosha2" "VUInteger.4S, VUInteger.4S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6"))
    )
  )
)

(lduminal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDUMINAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDUMINAL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(abs
  (c2
    ((simd-vector simd-vector)
      ("ABS_asimdmisc_R" "VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((gpr-64 gpr-64)
      ("ABS_64_dp_1src" "XZR, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
    )
    ((gpr-32 gpr-32)
      ("ABS_32_dp_1src" "WZR, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
    )
    ((simd-scalar simd-scalar)
      ("ABS_asisdmisc_R" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("abs_z_p_z_m" "ZUInteger.B, PUInteger/M, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("abs_z_p_z_z" "ZUInteger.B, PUInteger/Z, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(bmops
  (c5
    ((sme-za sve-p sve-p sve-z sve-z)
      ("bmops_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
    )
  )
)

(fmlsl2
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMLSL2_asimdsame_F" "VUInteger.2S, VUInteger.2H, VUInteger.2H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMLSL2_asimdelem_LH" "VUInteger.2S, VUInteger.2H, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(rcwssetal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSSETAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(f2cvt
  (c2
    ((reg-list sve-z)
      ("f2cvt_mz2_z8_" "{Z UInteger .H- Z UInteger .H}, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
    )
    ((sve-z sve-z)
      ("f2cvt_z_z8_b2h" "ZUInteger.H, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(sb
  (c0
    (()
      ("SB_only_barriers" "" () ())
    )
  )
)

(ldtclra
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDTCLRA_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDTCLRA_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(bfmlalb
  (c3
    ((sve-z sve-z sve-z)
      ("bfmlalb_z_zzzi_" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
      ("bfmlalb_z_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(fcvt
  (c2
    ((reg-list sve-z)
      ("fcvt_mz2_z_" "{Z UInteger .S- Z UInteger .S}, ZUInteger.H" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
    )
    ((simd-scalar simd-scalar)
      ("FCVT_DS_floatdp1" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
      ("FCVT_HS_floatdp1" "HUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Sn"))
      ("FCVT_SD_floatdp1" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
      ("FCVT_HD_floatdp1" "HUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Dn"))
      ("FCVT_SH_floatdp1" "SUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Hn__2"))
      ("FCVT_DH_floatdp1" "DUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Hn__2"))
    )
    ((sve-z reg-list)
      ("fcvt_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
      ("fcvt_z8_mz2_" "ZUInteger.B, {Z UInteger .H- Z UInteger .H}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
      ("fcvt_z8_mz4_" "ZUInteger.B, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__6" "Zn4__3"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
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
    )
  )
)

(smaxv
  (c2
    ((simd-scalar simd-vector)
      ("SMAXV_asimdall_only" "BUInteger, VUInteger.8B" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__2" "Vn"))
    )
  )
  (c3
    ((simd-scalar sve-p sve-z)
      ("smaxv_r_p_z_" "BUInteger, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V" "Pg" "Zn"))
    )
  )
)

(shrn
  (c3
    ((simd-vector simd-vector immediate)
      ("SHRN_asimdshf_N" "VUInteger.8B, VUInteger.8H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__6"))
    )
  )
)

(cpyfe
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFE_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(fmlalltb
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMLALLTB_asimdsame2_G" "VUInteger.4S, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMLALLTB_asimdelem_J" "VUInteger.4S, VUInteger.16B, VUInteger.B[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__6"))
    )
    ((sve-z sve-z sve-z)
      ("fmlalltb_z32_z8z8z8_" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("fmlalltb_z32_z8z8z8i_" "ZUInteger.S, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__56"))
    )
  )
)

(uqshrn
  (c3
    ((simd-scalar simd-scalar immediate)
      ("UQSHRN_asisdshf_N" "BUInteger, HUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vb_option" "Va_option" "immh_shift__2"))
    )
    ((simd-vector simd-vector immediate)
      ("UQSHRN_asimdshf_N" "VUInteger.8B, VUInteger.8H, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__6"))
    )
    ((sve-z reg-list immediate)
      ("uqshrn_z_mz2_" "ZUInteger.B, {Z UInteger . H - Z UInteger . H}, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
    )
  )
)

(br
  (c1
    ((gpr-64)
      ("BR_64_branch_reg" "XZR" (("Rn" (reg-range 0 31))) ("XnOrXZR"))
    )
  )
)

(stgp
  (c2m1
    ((gpr-64 gpr-64 memory immediate)
      ("STGP_64_ldstpair_post" "XZR, XZR, [SP], SInteger" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__13"))
    )
    ((gpr-64 gpr-64 memory pre-index)
      ("STGP_64_ldstpair_pre" "XZR, XZR, [SP SInteger], !" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option" "imm__13"))
    )
  )
  (c2m
    ((gpr-64 gpr-64 memory)
      ("STGP_64_ldstpair_off" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(cpyfptn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFPTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(fcvtmu
  (c2
    ((simd-vector simd-vector)
      ("FCVTMU_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FCVTMU_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("FCVTMU_asisdmiscfp16_R" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
      ("FCVTMU_asisdmisc_R" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
      ("FCVTMU_sisd_32D" "SUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Dn"))
      ("FCVTMU_sisd_32H" "SUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Hn__2"))
      ("FCVTMU_sisd_64H" "DUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Hn__2"))
      ("FCVTMU_sisd_64S" "DUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Sn"))
    )
    ((gpr-32 simd-scalar)
      ("FCVTMU_32S_float2int" "WZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
      ("FCVTMU_32D_float2int" "WZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Dn"))
      ("FCVTMU_32H_float2int" "WZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
    )
    ((gpr-64 simd-scalar)
      ("FCVTMU_64S_float2int" "XZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Sn"))
      ("FCVTMU_64D_float2int" "XZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
      ("FCVTMU_64H_float2int" "XZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
    )
  )
)

(autib1716
  (c0
    (()
      ("AUTIB1716_HI_hints" "" () ())
    )
  )
)

(bfmmla
  (c3
    ((simd-vector simd-vector simd-vector)
      ("BFMMLA_asimdsame2_E" "VUInteger.4S, VUInteger.8H, VUInteger.8H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__3" "Vn__2" "Vm"))
    )
    ((sve-z sve-z sve-z)
      ("bfmmla_z_zzz_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("bfmmla_z_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(ldumaxal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDUMAXAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDUMAXAL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ld1rb
  (c2m
    ((reg-list sve-p memory)
      ("ld1rb_z_p_bi_u8" "{Z UInteger .B}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ld1rb_z_p_bi_u16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ld1rb_z_p_bi_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ld1rb_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
  )
)

(crc32cw
  (c3
    ((gpr-32 gpr-32 gpr-32)
      ("CRC32CW_32C_dp_2src" "WZR, WZR, WZR" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR__2" "WnOrWZR__4" "WmOrWZR__5"))
    )
  )
)

(sutmopa
  (c4
    ((sme-za reg-list sve-z sve-z)
      ("sutmopa_za_zzzi_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B, ZUInteger[UInteger]" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 15))) ("ZAda" "Zn1__2" "Zn2__2" "Zm" "Zk__2"))
    )
  )
)

(axflag
  (c0
    (()
      ("AXFLAG_M_pstate" "" () ())
    )
  )
)

(ldsmin
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDSMIN_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDSMIN_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(fminnm
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fminnm_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
    ((sve-z sve-p sve-z float-const)
      ("fminnm_z_p_zs_" "ZUInteger.H, PUInteger/M, ZUInteger.H, 0.0" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMINNM_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMINNM_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((reg-list reg-list sve-z)
      ("fminnm_mz_zzv_2x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
      ("fminnm_mz_zzv_4x1" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("FMINNM_S_floatdp2" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn__3" "Sm"))
      ("FMINNM_D_floatdp2" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn__2" "Dm"))
      ("FMINNM_H_floatdp2" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
    )
    ((reg-list reg-list reg-list)
      ("fminnm_mz_zzw_2x2" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
      ("fminnm_mz_zzw_4x4" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
    )
  )
)

(setpn
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETPN_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XnOrXZR__5" "XsOrXZR__7"))
    )
  )
)

(sqrshrnb
  (c3
    ((sve-z sve-z immediate)
      ("sqrshrnb_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(ld1rh
  (c2m
    ((reg-list sve-p memory)
      ("ld1rh_z_p_bi_u16" "{Z UInteger .H}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ld1rh_z_p_bi_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ld1rh_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm6" (imm-range 0 63 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
  )
)

(fmls
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fmls_z_p_zzz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Pg" "Zn__2" "Zm"))
    )
  )
  (c1
    ((sme-za)
      ("fmls_za_zzi_h2xi" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
      ("fmls_za_zzi_s2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .S- Z UInteger .S}, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
      ("fmls_za_zzi_d2xi" "ZA.D[WUInteger, UInteger, VGx2, {Z UInteger .D- Z UInteger .D}, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
      ("fmls_za_zzi_h4xi" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
      ("fmls_za_zzi_s4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .S- Z UInteger .S}, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
      ("fmls_za_zzi_d4xi" "ZA.D[WUInteger, UInteger, VGx4, {Z UInteger .D- Z UInteger .D}, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
      ("fmls_za_zzv_2x1_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
      ("fmls_za_zzv_4x1_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
      ("fmls_za_zzw_2x2_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("fmls_za_zzw_4x4_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMLS_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMLS_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMLS_asimdelem_RH_H" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__2"))
      ("FMLS_asimdelem_R_SD" "VUInteger.2S, VUInteger.2S, VUInteger.S[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2"))
    )
    ((simd-scalar simd-scalar simd-vector)
      ("FMLS_asisdelem_RH_H" "HUInteger, HUInteger, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Vm__2"))
      ("FMLS_asisdelem_R_SD" "SUInteger, SUInteger, VUInteger.S[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
    )
    ((sve-z sve-z sve-z)
      ("fmls_z_zzzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
      ("fmls_z_zzzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__55"))
      ("fmls_z_zzzi_d" "ZUInteger.D, ZUInteger.D, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__54"))
    )
  )
  (c1m2
    ((sme-za memory reg-list sve-z)
      ("fmls_za_zzv_2x1" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}, ZUInteger.S" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
      ("fmls_za_zzv_4x1" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}, ZUInteger.S" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
    )
    ((sme-za memory reg-list reg-list)
      ("fmls_za_zzw_2x2" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}, {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("fmls_za_zzw_4x4" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}, {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
)

(cpyfewtn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFEWTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(brkpbs
  (c4
    ((sve-p sve-p sve-p sve-p)
      ("brkpbs_p_p_pp_" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
    )
  )
)

(stlrb
  (c1m
    ((gpr-32 memory)
      ("STLRB_SL32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
  )
)

(sqdmlal
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SQDMLAL_asimddiff_L" "VUInteger.4S, VUInteger.4H, VUInteger.4H" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("SQDMLAL_asimdelem_L" "VUInteger.4S, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
    )
    ((simd-scalar simd-scalar simd-vector)
      ("SQDMLAL_asisdelem_L" "SUInteger, HUInteger, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Va_option__2" "Vb_option__2" "Vm__5"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("SQDMLAL_asisddiff_only" "SUInteger, HUInteger, HUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Va_option__2" "Vb_option__2" "Vb_option__2"))
    )
  )
)

(uqdecd
  (c1
    ((gpr-64)
      ("uqdecd_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
    ((sve-z)
      ("uqdecd_z_zs_" "ZUInteger.D" (("imm4" (imm-range 0 15 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2"))
    )
    ((gpr-32)
      ("uqdecd_r_rs_uw" "WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Wdn"))
    )
  )
)

(lduminalb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDUMINALB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(firstp
  (c3
    ((gpr-64 sve-p sve-p)
      ("firstp_r_p_p_" "XUInteger, PUInteger, PUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Rd" (reg-range 0 31))) ("Xd__2" "Pg__2" "Pn__3"))
    )
  )
)

(stfmin
  (c1m
    ((simd-scalar memory)
      ("STFMIN_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
      ("STFMIN_32" "SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
      ("STFMIN_64" "DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(stbfmax
  (c1m
    ((simd-scalar memory)
      ("STBFMAX_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(bfdot
  (c1
    ((sme-za)
      ("bfdot_za_zzi_2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
      ("bfdot_za_zzi_4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
      ("bfdot_za_zzv_2x1" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
      ("bfdot_za_zzv_4x1" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
      ("bfdot_za_zzw_2x2" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("bfdot_za_zzw_4x4" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("BFDOT_asimdsame2_D" "VUInteger.2S, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("BFDOT_asimdelem_E" "VUInteger.2S, VUInteger.4H, VUInteger.2H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "H_L__2"))
    )
    ((sve-z sve-z sve-z)
      ("bfdot_z_zzzi_" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__35"))
      ("bfdot_z_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(sm4e
  (c2
    ((simd-vector simd-vector)
      ("SM4E_VV4_cryptosha512_2" "VUInteger.4S, VUInteger.4S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6"))
    )
  )
  (c3
    ((sve-z sve-z sve-z)
      ("sm4e_z_zz_" "ZUInteger.S, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm"))
    )
  )
)

(sxtb
  (c3
    ((sve-z sve-p sve-z)
      ("sxtb_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("sxtb_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(umlslb
  (c3
    ((sve-z sve-z sve-z)
      ("umlslb_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("umlslb_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
      ("umlslb_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
    )
  )
)

(swpab
  (c2m
    ((gpr-32 gpr-32 memory)
      ("SWPAB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(mrs
  (c2
    ((gpr-64 system-reg)
      ("MRS_RS_systemmove" "XZR, ACTLR_EL3" (("Rt" (reg-range 0 31))) ("XtOrXZR__4"))
    )
  )
)

(stfminnm
  (c1m
    ((simd-scalar memory)
      ("STFMINNM_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
      ("STFMINNM_32" "SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
      ("STFMINNM_64" "DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(zero
  (c1
    ((reg-list)
      ("zero_za_i_" "{}" (("imm8" (imm-range 0 255 1))) ())
      ("zero_zt_i_" "{ZT0}" () ())
    )
    ((sme-za)
      ("zero_za1_ri_2" "ZA.D[WUInteger, UInteger, VGx2" (("off3" (imm-range 0 7 1))) ("Wv" "offs"))
      ("zero_za1_ri_4" "ZA.D[WUInteger, UInteger, VGx4" (("off3" (imm-range 0 7 1))) ("Wv" "offs"))
      ("zero_za2_ri_1" "ZA.D[WUInteger, UInteger:UInteger" (("off3" (imm-range 0 7 1))) ("Wv" "offs1" "offs2"))
      ("zero_za2_ri_2" "ZA.D[WUInteger, UInteger:UInteger, VGx2]" (("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2"))
      ("zero_za2_ri_4" "ZA.D[WUInteger, UInteger:UInteger, VGx4]" (("off2" (imm-range 0 3 1))) ("Wv" "offs1__2" "offs2__2"))
      ("zero_za4_ri_1" "ZA.D[WUInteger, UInteger:UInteger" (("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4"))
      ("zero_za4_ri_2" "ZA.D[WUInteger, UInteger:UInteger, VGx2]" () ("Wv" "offs1__4" "offs4__2"))
      ("zero_za4_ri_4" "ZA.D[WUInteger, UInteger:UInteger, VGx4]" () ("Wv" "offs1__4" "offs4__2"))
    )
  )
)

(fnmsb
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fnmsb_z_p_zzz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Za" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zm" "Za"))
    )
  )
)

(ldaddl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDADDL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDADDL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(bf1cvt
  (c2
    ((reg-list sve-z)
      ("bf1cvt_mz2_z8_" "{Z UInteger .H- Z UInteger .H}, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
    )
    ((sve-z sve-z)
      ("bf1cvt_z_z8_b2bf" "ZUInteger.H, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(paciaz
  (c0
    (()
      ("PACIAZ_HI_hints" "" () ())
    )
  )
)

(setgoe
  (c0m1
    ((memory gpr-64)
      ("SETGOE_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__10"))
    )
  )
)

(eon
  (c5
    ((gpr-32 gpr-32 gpr-32 keyword immediate)
      ("EON_32_log_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64 keyword immediate)
      ("EON_64_log_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
  )
)

(uqdecb
  (c1
    ((gpr-64)
      ("uqdecb_r_rs_x" "XUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Xdn"))
    )
    ((gpr-32)
      ("uqdecb_r_rs_uw" "WUInteger" (("imm4" (imm-range 0 15 1)) ("Rdn" (reg-range 0 31))) ("Wdn"))
    )
  )
)

(ldfmaxal
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDFMAXAL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMAXAL_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMAXAL_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(lduminah
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDUMINAH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(rdsvl
  (c2
    ((gpr-64 immediate)
      ("rdsvl_r_i_" "XUInteger, SInteger" (("imm6" (imm-range 0 63 1)) ("Rd" (reg-range 0 31))) ("Xd__2" "imm__28"))
    )
  )
)

(eor3
  (c4
    ((simd-vector simd-vector simd-vector simd-vector)
      ("EOR3_VVV16_crypto4" "VUInteger.16B, VUInteger.16B, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm" "Va"))
    )
    ((sve-z sve-z sve-z sve-z)
      ("eor3_z_zzz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm" "Zk"))
    )
  )
)

(whilels
  (c4
    ((sve-pn gpr-64 gpr-64 vector-length)
      ("whilels_pn_rr_" "PNUInteger.B, XUInteger, XUInteger, VLx2" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("PNd" (reg-range 0 7))) ("PNd" "Xn__4" "Xm__6"))
    )
  )
  (c3
    ((reg-list gpr-64 gpr-64)
      ("whilels_pp_rr_" "{P UInteger . B P UInteger . B}, XUInteger, XUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 7))) ("Pd1__2" "Pd2__2" "Xn__4" "Xm__6"))
    )
    ((sve-p gpr-32 gpr-32)
      ("whilels_p_p_rr_" "PUInteger.B, WZR, WZR" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd"))
    )
  )
)

(casa
  (c2m
    ((gpr-64 gpr-64 memory)
      ("CASA_C64_comswap" "XZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("CASA_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
    )
  )
)

(sqshrunb
  (c3
    ((sve-z sve-z immediate)
      ("sqshrunb_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(ldsetpl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDSETPL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(ucvtflt
  (c2
    ((sve-z sve-z)
      ("ucvtflt_z_z_" "ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(cpyetn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYETN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(stlxrh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("STLXRH_SR32_ldstexclr" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "WtOrWZR__4" "XnSP_option"))
    )
  )
)

(ldrh
  (c1m1
    ((gpr-32 memory pre-index)
      ("LDRH_32_ldst_immpre" "WZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
    ((gpr-32 memory immediate)
      ("LDRH_32_ldst_immpost" "WZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
  )
  (c1m
    ((gpr-32 memory)
      ("LDRH_32_ldst_regoff" "WZR, [SP WZR UXTW 0]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "WorX_choice"))
      ("LDRH_32_ldst_pos" "WZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm12_option__4"))
    )
  )
)

(swpt
  (c2m
    ((gpr-64 gpr-64 memory)
      ("SWPT_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("SWPT_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(eorv
  (c3
    ((simd-scalar sve-p sve-z)
      ("eorv_r_p_z_" "BUInteger, PUInteger, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("V" "Pg" "Zn"))
    )
  )
)

(uaddl
  (c3
    ((simd-vector simd-vector simd-vector)
      ("UADDL_asimddiff_L" "VUInteger.8H, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(rcwseta
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSETA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(aesimc
  (c2
    ((simd-vector simd-vector)
      ("AESIMC_B_cryptoaes" "VUInteger.16B, VUInteger.16B" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((sve-z sve-z)
      ("aesimc_z_z_" "ZUInteger.B, ZUInteger.B" (("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2"))
    )
  )
)

(lduminb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDUMINB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ld1w
  (c2
    ((reg-list sve-pn)
      ("ld1w_mz_p_br_2" "{Z UInteger .S- Z UInteger .S}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3" "Xm__4"))
      ("ld1w_mz_p_br_4" "{Z UInteger .S- Z UInteger .S}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3" "Xm__4"))
      ("ld1w_mzx_p_br_2x8" "{Z UInteger .S Z UInteger .S}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3" "Xm__4"))
      ("ld1w_mzx_p_br_4x4" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PNUInteger/Z" (("Rm" (reg-range 0 31)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3" "Xm__4"))
    )
    ((reg-list sve-p)
      ("ld1w_z_p_bz_s_x32_scaled" "{Z UInteger .S}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ld1w_z_p_br_u32" "{Z UInteger .S}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
      ("ld1w_z_p_br_u64" "{Z UInteger .D}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
      ("ld1w_z_p_br_u128" "{Z UInteger .Q}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
      ("ld1w_z_p_bz_d_x32_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ld1w_z_p_bz_d_64_unscaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ld1w_z_p_bz_d_64_scaled" "{Z UInteger .D}, PUInteger/Z" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld1w_z_p_bz_s_x32_unscaled" "{Z UInteger .S}, PUInteger/Z, [SP Z UInteger .S UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ld1w_z_p_ai_s" "{Z UInteger .S}, PUInteger/Z, [Z UInteger .S]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("ld1w_z_p_bi_u128" "{Z UInteger .Q}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ld1w_z_p_bi_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ld1w_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ld1w_z_p_bz_d_x32_unscaled" "{Z UInteger .D}, PUInteger/Z, [SP Z UInteger .D UXTW]" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Zm__3"))
      ("ld1w_z_p_ai_d" "{Z UInteger .D}, PUInteger/Z, [Z UInteger .D]" (("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("ld1w_za_p_rrr_" "{ZA UInteger H .S [W UInteger UInteger]}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("ZAt__4" "HV" "Ws__3" "offs__6" "Pg" "XnSP__3"))
    )
    ((reg-list sve-pn memory)
      ("ld1w_mz_p_bi_2" "{Z UInteger .S- Z UInteger .S}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 15))) ("Zt1" "Zt2" "PNg" "XnSP__3"))
      ("ld1w_mz_p_bi_4" "{Z UInteger .S- Z UInteger .S}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__2" "Zt4" "PNg" "XnSP__3"))
      ("ld1w_mzx_p_bi_2x8" "{Z UInteger .S Z UInteger .S}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 7))) ("Zt1__3" "Zt2__2" "PNg" "XnSP__3"))
      ("ld1w_mzx_p_bi_4x4" "{Z UInteger .S Z UInteger .S Z UInteger .S Z UInteger .S}, PNUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("PNg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 3))) ("Zt1__4" "Zt2__3" "Zt3" "Zt4__2" "PNg" "XnSP__3"))
    )
  )
)

(csinc
  (c4
    ((gpr-32 gpr-32 gpr-32 cond-code)
      ("CSINC_32_condsel" "WZR, WZR, WZR, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64 cond-code)
      ("CSINC_64_condsel" "XZR, XZR, XZR, EQ" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
  )
)

(addpt
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("addpt_z_p_zz_" "ZUInteger.D, PUInteger/M, ZUInteger.D, ZUInteger.D" (("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((gpr-64 gpr-64 gpr-64)
      ("ADDPT_64_addsub_pt" "SP, SP, XZR" (("Rm" (reg-range 0 31)) ("imm3" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option__3" "XnSP_option__5" "XmOrXZR__4" "imm3_option"))
    )
    ((sve-z sve-z sve-z)
      ("addpt_z_zz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(ssublt
  (c3
    ((sve-z sve-z sve-z)
      ("ssublt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(st4d
  (c2
    ((reg-list sve-p)
      ("st4d_z_p_br_contiguous" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("st4d_z_p_bi_contiguous" "{Z UInteger .D Z UInteger .D Z UInteger .D Z UInteger .D}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3"))
    )
  )
)

(umop4a
  (c3
    ((sme-za reg-list sve-z)
      ("umop4a_za_zz_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
      ("umop4a_za32_zz_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
      ("umop4a_za_zz_h2x1" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
    )
    ((sme-za reg-list reg-list)
      ("umop4a_za_zz_b2x2" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("umop4a_za32_zz_h2x2" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("umop4a_za_zz_h2x2" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
    ((sme-za sve-z sve-z)
      ("umop4a_za_zz_b1x1" "ZAUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
      ("umop4a_za32_zz_h1x1" "ZAUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
      ("umop4a_za_zz_h1x1" "ZAUInteger.D, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm_mortlach"))
    )
    ((sme-za sve-z reg-list)
      ("umop4a_za_zz_b1x2" "ZAUInteger.S, ZUInteger.B, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("umop4a_za32_zz_h1x2" "ZAUInteger.S, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("umop4a_za_zz_h1x2" "ZAUInteger.D, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
  )
)

(cpyern
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYERN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(stllrb
  (c1m
    ((gpr-32 memory)
      ("STLLRB_SL32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
  )
)

(ldnf1w
  (c2m
    ((reg-list sve-p memory)
      ("ldnf1w_z_p_bi_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
      ("ldnf1w_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
  )
)

(drps
  (c0
    (()
      ("DRPS_64E_branch_reg" "" () ())
    )
  )
)

(rcwsclrp
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSCLRP_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(gcsstr
  (c1m
    ((gpr-64 memory)
      ("GCSSTR_64_ldst_gcs" "XZR, [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option"))
    )
  )
)

(cpyfmn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFMN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(sqshrunt
  (c3
    ((sve-z sve-z immediate)
      ("sqshrunt_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(rcwcasa
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWCASA_C64_rcwcomswap" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__4" "XtOrXZR__10" "XnSP_option"))
    )
  )
)

(autdb
  (c2
    ((gpr-64 gpr-64)
      ("AUTDB_64P_dp_1src" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__7"))
    )
  )
)

(sqadd
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("sqadd_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((sve-z sve-z immediate)
      ("sqadd_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__27"))
    )
    ((simd-vector simd-vector simd-vector)
      ("SQADD_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("SQADD_asisdsame_only" "BUInteger, BUInteger, BUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__7" "V_option__7" "V_option__7"))
    )
    ((sve-z sve-z sve-z)
      ("sqadd_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(cpyfmwn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFMWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(sqrdmulh
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SQRDMULH_asimdsame_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("SQRDMULH_asimdelem_R" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__5"))
    )
    ((simd-scalar simd-scalar simd-vector)
      ("SQRDMULH_asisdelem_R" "HUInteger, HUInteger, VUInteger.H[UInteger]" (("size" (element-size B H S D)) ("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__8" "V_option__8" "Vm__5"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("SQRDMULH_asisdsame_only" "HUInteger, HUInteger, HUInteger" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__8" "V_option__8" "V_option__8"))
    )
    ((sve-z sve-z sve-z)
      ("sqrdmulh_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
      ("sqrdmulh_z_zzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__78"))
      ("sqrdmulh_z_zzi_s" "ZUInteger.S, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__41"))
      ("sqrdmulh_z_zzi_d" "ZUInteger.D, ZUInteger.D, ZUInteger.D[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__2" "imm__42"))
    )
  )
)

(cpyfmrtwn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFMRTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(smlslb
  (c3
    ((sve-z sve-z sve-z)
      ("smlslb_z_zzz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("smlslb_z_zzzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__78"))
      ("smlslb_z_zzzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__2" "imm__88"))
    )
  )
)

(fnmls
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fnmls_z_p_zzz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Pg" "Zn__2" "Zm"))
    )
  )
)

(usmops
  (c5
    ((sme-za sve-p sve-p sve-z sve-z)
      ("usmops_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
      ("usmops_za_pp_zz_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn__2" "Zm"))
    )
  )
)

(subs
  (c5
    ((gpr-64 gpr-64 gpr-32 keyword immediate)
      ("SUBS_64S_addsub_ext" "XZR, SP, WZR, UXTB, UInteger" (("Rm" (reg-range 0 31)) ("imm3" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__6"))
    )
    ((gpr-32 gpr-32 gpr-32 keyword immediate)
      ("SUBS_32_addsub_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
      ("SUBS_32S_addsub_ext" "WZR, WSP, WZR, UXTB, UInteger" (("Rm" (reg-range 0 31)) ("imm3" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnWSP_option__2" "WmOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64 keyword immediate)
      ("SUBS_64_addsub_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
  )
  (c3
    ((gpr-64 gpr-64 immediate)
      ("SUBS_64S_addsub_imm" "XZR, SP, UInteger" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__3" "imm__17"))
    )
    ((gpr-32 gpr-32 immediate)
      ("SUBS_32S_addsub_imm" "WZR, WSP, UInteger" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnWSP_option" "imm__17"))
    )
  )
)

(retabsppc
  (c1
    ((immediate)
      ("RETABSPPC_only_miscbranch" "SInteger" (("imm16" (imm-range 0 65535 1))) ("imm16_offset"))
    )
  )
)

(bfclamp
  (c3
    ((reg-list sve-z sve-z)
      ("bfclamp_mz_zz_2" "{Z UInteger .H- Z UInteger .H}, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn__2" "Zm"))
      ("bfclamp_mz_zz_4" "{Z UInteger .H- Z UInteger .H}, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn__2" "Zm"))
    )
    ((sve-z sve-z sve-z)
      ("bfclamp_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(ld1rob
  (c2m
    ((reg-list sve-p memory)
      ("ld1rob_z_p_br_contiguous" "{Z UInteger .B}, PUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
      ("ld1rob_z_p_bi_u8" "{Z UInteger .B}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
  )
)

(ld1rqw
  (c2
    ((reg-list sve-p)
      ("ld1rqw_z_p_br_contiguous" "{Z UInteger .S}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld1rqw_z_p_bi_u32" "{Z UInteger .S}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
  )
)

(ldbfmaxnma
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDBFMAXNMA_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(pacdb
  (c2
    ((gpr-64 gpr-64)
      ("PACDB_64P_dp_1src" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnSP_option__7"))
    )
  )
)

(cpyfmwtn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFMWTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(setgom
  (c0m1
    ((memory gpr-64)
      ("SETGOM_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__9"))
    )
  )
)

(ldfminal
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDFMINAL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMINAL_32" "SUInteger, SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
      ("LDFMINAL_64" "DUInteger, DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(stxrh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("STXRH_SR32_ldstexclr" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "WtOrWZR__4" "XnSP_option"))
    )
  )
)

(ushl
  (c3
    ((simd-vector simd-vector simd-vector)
      ("USHL_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("USHL_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
  )
)

(ldseth
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSETH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(cpyptrn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYPTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(aesemc
  (c3
    ((reg-list reg-list sve-z)
      ("aesemc_mz_zzi_2x1" "{Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}, ZUInteger.Q[UInteger" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm"))
      ("aesemc_mz_zzi_4x1" "{Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}, ZUInteger.Q[UInteger" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm"))
    )
  )
)

(aese
  (c2
    ((simd-vector simd-vector)
      ("AESE_B_cryptoaes" "VUInteger.16B, VUInteger.16B" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6"))
    )
  )
  (c3
    ((reg-list reg-list sve-z)
      ("aese_mz_zzi_2x1" "{Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}, ZUInteger.Q[UInteger" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm"))
      ("aese_mz_zzi_4x1" "{Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}, ZUInteger.Q[UInteger" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm"))
    )
    ((sve-z sve-z sve-z)
      ("aese_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Zdn" "Zm"))
    )
  )
)

(ldsmaxb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSMAXB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(cpyfprtwn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFPRTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(bfmls
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("bfmls_z_p_zzz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Pg" "Zn__2" "Zm"))
    )
  )
  (c1
    ((sme-za)
      ("bfmls_za_zzi_h2xi" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
      ("bfmls_za_zzi_h4xi" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
      ("bfmls_za_zzv_2x1_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
      ("bfmls_za_zzv_4x1_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
      ("bfmls_za_zzw_2x2_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("bfmls_za_zzw_4x4_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
  (c3
    ((sve-z sve-z sve-z)
      ("bfmls_z_zzzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
    )
  )
)

(uqdecp
  (c2
    ((gpr-64 sve-p)
      ("uqdecp_r_p_r_x" "XUInteger, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Rdn" (reg-range 0 31))) ("Xdn" "Pm__3"))
    )
    ((sve-z sve-p)
      ("uqdecp_z_p_z_" "ZUInteger.H, PUInteger.H" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pm__3"))
    )
    ((gpr-32 sve-p)
      ("uqdecp_r_p_r_uw" "WUInteger, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Rdn" (reg-range 0 31))) ("Wdn" "Pm__3"))
    )
  )
)

(frintm
  (c2
    ((simd-vector simd-vector)
      ("FRINTM_asimdmiscfp16_R" "VUInteger.4H, VUInteger.4H" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FRINTM_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((reg-list reg-list)
      ("frintm_mz_z_2" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn1__4" "Zn2__3"))
      ("frintm_mz_z_4" "{Z UInteger .S- Z UInteger .S}, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
    )
    ((simd-scalar simd-scalar)
      ("FRINTM_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
      ("FRINTM_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
      ("FRINTM_H_floatdp1" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("frintm_z_p_z_z" "ZUInteger.H, PUInteger/Z, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("frintm_z_p_z_m" "ZUInteger.H, PUInteger/M, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(ldtsetl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDTSETL_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDTSETL_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ldbfmaxnmal
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDBFMAXNMAL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(fcpy
  (c3
    ((sve-z sve-p float-const)
      ("fcpy_z_p_i_" "ZUInteger.H, PUInteger/M, Real" (("size" (element-size B H S D)) ("Pg" (reg-range 0 15)) ("imm8" (imm-range 0 255 1)) ("Zd" (reg-range 0 31))) ("Zd" "Pg__2"))
    )
  )
)

(cbnz
  (c2
    ((gpr-64 immediate)
      ("CBNZ_64_compbranch" "XZR, SInteger" (("imm19" (imm-range 0 524287 1)) ("Rt" (reg-range 0 31))) ("XtOrXZR" "imm19_offset"))
    )
    ((gpr-32 immediate)
      ("CBNZ_32_compbranch" "WZR, SInteger" (("imm19" (imm-range 0 524287 1)) ("Rt" (reg-range 0 31))) ("WtOrWZR" "imm19_offset"))
    )
  )
)

(rsubhnt
  (c3
    ((sve-z sve-z sve-z)
      ("rsubhnt_z_zz_" "ZUInteger.B, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(stlrh
  (c1m
    ((gpr-32 memory)
      ("STLRH_SL32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
  )
)

(stfadd
  (c1m
    ((simd-scalar memory)
      ("STFADD_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
      ("STFADD_32" "SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
      ("STFADD_64" "DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(smaddl
  (c4
    ((gpr-64 gpr-32 gpr-32 gpr-64)
      ("SMADDL_64WA_dp_3src" "XZR, WZR, WZR, XZR" (("Rm" (reg-range 0 31)) ("Ra" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "WnOrWZR__5" "WmOrWZR__6" "XaOrXZR"))
    )
  )
)

(sqxtunt
  (c2
    ((sve-z sve-z)
      ("sqxtunt_z_zz_" "ZUInteger.B, ZUInteger.H" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(stbfmaxl
  (c1m
    ((simd-scalar memory)
      ("STBFMAXL_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(ursqrte
  (c2
    ((simd-vector simd-vector)
      ("URSQRTE_asimdmisc_R" "VUInteger.2S, VUInteger.2S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
  )
  (c3
    ((sve-z sve-p sve-z)
      ("ursqrte_z_p_z_m" "ZUInteger.S, PUInteger/M, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("ursqrte_z_p_z_z" "ZUInteger.S, PUInteger/Z, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(ld1q
  (c2m
    ((reg-list sve-p memory)
      ("ld1q_z_p_ar_d_64_unscaled" "{Z UInteger .Q}, PUInteger/Z, [Z UInteger .D]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "Zn__3"))
      ("ld1q_za_p_rrr_" "{ZA UInteger H .Q [W UInteger 0]}, PUInteger/Z, [SP]" (("Rm" (reg-range 0 31)) ("Rs" (reg-range 0 3)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31))) ("ZAt__3" "HV" "Ws__3" "offs__5" "Pg" "XnSP__3"))
    )
  )
)

(ld4
  (c1m1
    ((reg-list memory immediate)
      ("LD4_asisdlsep_I4_i" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], 32" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "imm_option"))
    )
    ((reg-list memory gpr-64)
      ("LD4_asisdlsep_R4_r" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
    )
    ((reg-list memory memory)
      ("LD4_asisdlso_B4_4b" "{V UInteger . B V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
      ("LD4_asisdlso_H4_4h" "{V UInteger . H V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
      ("LD4_asisdlso_S4_4s" "{V UInteger . S V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
      ("LD4_asisdlso_D4_4d" "{V UInteger . D V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
    )
  )
  (c1m2
    ((reg-list memory memory immediate)
      ("LD4_asisdlsop_B4_i4b" "{V UInteger . B V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP], 4" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
      ("LD4_asisdlsop_H4_i4h" "{V UInteger . H V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP], 8" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
      ("LD4_asisdlsop_S4_i4s" "{V UInteger . S V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP], 16" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
      ("LD4_asisdlsop_D4_i4d" "{V UInteger . D V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP], 32" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
    )
    ((reg-list memory memory gpr-64)
      ("LD4_asisdlsop_BX4_r4b" "{V UInteger . B V UInteger . B V UInteger . B V UInteger . B}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
      ("LD4_asisdlsop_HX4_r4h" "{V UInteger . H V UInteger . H V UInteger . H V UInteger . H}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
      ("LD4_asisdlsop_SX4_r4s" "{V UInteger . S V UInteger . S V UInteger . S V UInteger . S}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
      ("LD4_asisdlsop_DX4_r4d" "{V UInteger . D V UInteger . D V UInteger . D V UInteger . D}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option" "Xm__2"))
    )
  )
  (c1m
    ((reg-list memory)
      ("LD4_asisdlse_R4" "{V UInteger . 8B V UInteger . 8B V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "Vt3" "Vt4" "XnSP_option"))
    )
  )
)

(ldbfminl
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDBFMINL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(ld1rod
  (c2
    ((reg-list sve-p)
      ("ld1rod_z_p_br_contiguous" "{Z UInteger .D}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld1rod_z_p_bi_u64" "{Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt" "Pg" "XnSP__3"))
    )
  )
)

(ldeor
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDEOR_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDEOR_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(st4h
  (c2
    ((reg-list sve-p)
      ("st4h_z_p_br_contiguous" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PUInteger" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("st4h_z_p_bi_contiguous" "{Z UInteger .H Z UInteger .H Z UInteger .H Z UInteger .H}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3"))
    )
  )
)

(cmpge
  (c4
    ((sve-p sve-p sve-z immediate)
      ("cmpge_p_p_zi_" "PUInteger.B, PUInteger/Z, ZUInteger.B, SInteger" (("size" (element-size B H S D)) ("imm5" (imm-range 0 31 1)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn" "imm__43"))
    )
    ((sve-p sve-p sve-z sve-z)
      ("cmpge_p_p_zz_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
      ("cmpge_p_p_zw_" "PUInteger.B, PUInteger/Z, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn__2" "Zm"))
    )
  )
)

(rcwswppa
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSWPPA_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(saddlbt
  (c3
    ((sve-z sve-z sve-z)
      ("saddlbt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(pacizb
  (c1
    ((gpr-64)
      ("PACIZB_64Z_dp_1src" "XZR" (("Rd" (reg-range 0 31))) ("XdOrXZR__6"))
    )
  )
)

(pmlal
  (c3
    ((reg-list sve-z sve-z)
      ("pmlal_mz_zzzw_1x2" "{Z UInteger .Q- Z UInteger .Q}, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 15))) ("Zda1" "Zda2" "Zn__2" "Zm"))
    )
  )
)

(swpp
  (c2m
    ((gpr-64 gpr-64 memory)
      ("SWPP_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(bfmlslt
  (c3
    ((sve-z sve-z sve-z)
      ("bfmlslt_z_zzzi_" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
      ("bfmlslt_z_zzz_" "ZUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
    )
  )
)

(brkpb
  (c4
    ((sve-p sve-p sve-p sve-p)
      ("brkpb_p_p_pp_" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
    )
  )
)

(cpyprtrn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYPRTRN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(bic
  (c5
    ((gpr-32 gpr-32 gpr-32 keyword immediate)
      ("BIC_32_log_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64 keyword immediate)
      ("BIC_64_log_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
  )
  (c2
    ((simd-vector immediate)
      ("BIC_asimdimm_L_sl" "VUInteger.2S, UInteger" (("Rd" (reg-range 0 31))) ("Vd__2"))
      ("BIC_asimdimm_L_hl" "VUInteger.4H, UInteger" (("Rd" (reg-range 0 31))) ("Vd__2"))
    )
  )
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("bic_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
    ((sve-p sve-p sve-p sve-p)
      ("bic_p_p_pp_z" "PUInteger.B, PUInteger/Z, PUInteger.B, PUInteger.B" (("Pm" (reg-range 0 15)) ("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "Pn__2" "Pm__2"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("BIC_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((sve-z sve-z sve-z)
      ("bic_z_zz_" "ZUInteger.D, ZUInteger.D, ZUInteger.D" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(cpyfm
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFM_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(ldtaddal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDTADDAL_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDTADDAL_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(svc
  (c1
    ((immediate)
      ("SVC_EX_exception" "UInteger" (("imm16" (imm-range 0 65535 1))) ("imm"))
    )
  )
)

(sqxtun
  (c2
    ((simd-vector simd-vector)
      ("SQXTUN_asimdmisc_N" "VUInteger.8B, VUInteger.8H" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("SQXTUN_asisdmisc_N" "BUInteger, HUInteger" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vb_option__3" "Va_option__3"))
    )
  )
)

(ldbfaddl
  (c2m
    ((simd-scalar simd-scalar memory)
      ("LDBFADDL_16" "HUInteger, HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(cpyfmt
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFMT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(ldsetl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDSETL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDSETL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(sha512su1
  (c3
    ((simd-vector simd-vector simd-vector)
      ("SHA512SU1_VVV2_cryptosha512_3" "VUInteger.2D, VUInteger.2D, VUInteger.2D" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd__4" "Vn__6" "Vm__7"))
    )
  )
)

(casplt
  (c4m
    ((gpr-64 gpr-64 gpr-64 gpr-64 memory)
      ("CASPLT_CP64_comswappr_unpriv" "XUInteger, XUInteger, XUInteger, XUInteger, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xs" "XsPlus1" "Xt" "XtPlus1__3" "XnSP_option"))
    )
  )
)

(cpyfmwt
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFMWT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(uzp
  (c2
    ((reg-list reg-list)
      ("uzp_mz_z_4" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
      ("uzp_mz_z_4q" "{Z UInteger .Q- Z UInteger .Q}, {Z UInteger .Q- Z UInteger .Q}" (("Zn" (reg-range 0 7)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__6" "Zn4__3"))
    )
  )
  (c3
    ((reg-list sve-z sve-z)
      ("uzp_mz_zz_2" "{Z UInteger . B - Z UInteger . B}, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn__2" "Zm"))
      ("uzp_mz_zz_2q" "{Z UInteger .Q- Z UInteger .Q}, ZUInteger.Q, ZUInteger.Q" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn__2" "Zm"))
    )
  )
)

(bfmla
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("bfmla_z_p_zzz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Pg" "Zn__2" "Zm"))
    )
  )
  (c1
    ((sme-za)
      ("bfmla_za_zzi_h2xi" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
      ("bfmla_za_zzi_h4xi" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
      ("bfmla_za_zzv_2x1_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
      ("bfmla_za_zzv_4x1_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
      ("bfmla_za_zzw_2x2_16" "ZA.H[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("bfmla_za_zzw_4x4_16" "ZA.H[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
  (c3
    ((sve-z sve-z sve-z)
      ("bfmla_z_zzzi_h" "ZUInteger.H, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__36"))
    )
  )
)

(ld2
  (c1m1
    ((reg-list memory immediate)
      ("LD2_asisdlsep_I2_i" "{V UInteger . 8B V UInteger . 8B}, [SP], 16" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "imm_option__6"))
    )
    ((reg-list memory gpr-64)
      ("LD2_asisdlsep_R2_r" "{V UInteger . 8B V UInteger . 8B}, [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
    )
    ((reg-list memory memory)
      ("LD2_asisdlso_B2_2b" "{V UInteger . B V UInteger . B}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
      ("LD2_asisdlso_H2_2h" "{V UInteger . H V UInteger . H}, [UInteger], [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
      ("LD2_asisdlso_S2_2s" "{V UInteger . S V UInteger . S}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
      ("LD2_asisdlso_D2_2d" "{V UInteger . D V UInteger . D}, [UInteger], [SP]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
    )
  )
  (c1m2
    ((reg-list memory memory immediate)
      ("LD2_asisdlsop_B2_i2b" "{V UInteger . B V UInteger . B}, [UInteger], [SP], 2" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
      ("LD2_asisdlsop_H2_i2h" "{V UInteger . H V UInteger . H}, [UInteger], [SP], 4" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
      ("LD2_asisdlsop_S2_i2s" "{V UInteger . S V UInteger . S}, [UInteger], [SP], 8" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
      ("LD2_asisdlsop_D2_i2d" "{V UInteger . D V UInteger . D}, [UInteger], [SP], 16" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
    )
    ((reg-list memory memory gpr-64)
      ("LD2_asisdlsop_BX2_r2b" "{V UInteger . B V UInteger . B}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
      ("LD2_asisdlsop_HX2_r2h" "{V UInteger . H V UInteger . H}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
      ("LD2_asisdlsop_SX2_r2s" "{V UInteger . S V UInteger . S}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
      ("LD2_asisdlsop_DX2_r2d" "{V UInteger . D V UInteger . D}, [UInteger], [SP], XUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option" "Xm__2"))
    )
  )
  (c1m
    ((reg-list memory)
      ("LD2_asisdlse_R2" "{V UInteger . 8B V UInteger . 8B}, [SP]" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Vt" "Vt2" "XnSP_option"))
    )
  )
)

(ldsetalh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSETALH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ctz
  (c2
    ((gpr-64 gpr-64)
      ("CTZ_64_dp_1src" "XZR, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__11"))
    )
    ((gpr-32 gpr-32)
      ("CTZ_32_dp_1src" "WZR, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR"))
    )
  )
)

(cpypwtn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYPWTN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(sys
  (c4
    ((immediate system-reg system-reg immediate)
      ("SYS_CR_systeminstrs" "UInteger, CUInteger, CUInteger, UInteger" (("Rt" (reg-range 0 31))) ())
    )
  )
)

(ushr
  (c3
    ((simd-scalar simd-scalar immediate)
      ("USHR_asisdshf_R" "DUInteger, DUInteger, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
    ((simd-vector simd-vector immediate)
      ("USHR_asimdshf_R" "VUInteger.8B, VUInteger.8B, UInteger" (("immh" (imm-range 0 15 1)) ("immb" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn" "immh_shift__4"))
    )
  )
)

(lduminh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDUMINH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(cpyfetn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFETN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__4"))
    )
  )
)

(fexpa
  (c2
    ((sve-z sve-z)
      ("fexpa_z_z_" "ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(dcps2
  (c0
    (()
      ("DCPS2_DC_exception" "" (("imm16" (imm-range 0 65535 1))) ())
    )
  )
)

(stllrh
  (c1m
    ((gpr-32 memory)
      ("STLLRH_SL32_ldstord" "WZR, [SP 0]" (("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
  )
)

(fcmlt
  (c4
    ((sve-p sve-p sve-z float-const)
      ("fcmlt_p_p_z0_" "PUInteger.H, PUInteger/Z, ZUInteger.H, 0.0" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Pg" "Zn"))
    )
  )
  (c3
    ((simd-scalar simd-scalar float-const)
      ("FCMLT_asisdmiscfp16_FZ" "HUInteger, HUInteger, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
      ("FCMLT_asisdmisc_FZ" "SUInteger, SUInteger, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
    )
    ((simd-vector simd-vector float-const)
      ("FCMLT_asimdmiscfp16_FZ" "VUInteger.4H, VUInteger.4H, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
      ("FCMLT_asimdmisc_FZ" "VUInteger.2S, VUInteger.2S, 0.0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
  )
)

(stfmax
  (c1m
    ((simd-scalar memory)
      ("STFMAX_16" "HUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
      ("STFMAX_32" "SUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
      ("STFMAX_64" "DUInteger, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31))) ("XnSP_option"))
    )
  )
)

(cpypwn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYPWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(eorbt
  (c3
    ((sve-z sve-z sve-z)
      ("eorbt_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(bti
  (c0
    (()
      ("BTI_HB_hints" "" () ())
    )
  )
)

(rcwsetpal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSETPAL_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(pmov
  (c2
    ((sve-z sve-p)
      ("pmov_z_pi_b" "ZUInteger, PUInteger.B" (("Pn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Pn__3"))
      ("pmov_z_pi_h" "ZUInteger, PUInteger.H" (("Pn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Pn__3"))
      ("pmov_z_pi_s" "ZUInteger, PUInteger.S" (("Pn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Pn__3"))
      ("pmov_z_pi_d" "ZUInteger, PUInteger.D" (("Pn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Pn__3"))
    )
    ((sve-p sve-z)
      ("pmov_p_zi_b" "PUInteger.B, ZUInteger" (("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Zn"))
      ("pmov_p_zi_h" "PUInteger.H, ZUInteger" (("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Zn"))
      ("pmov_p_zi_s" "PUInteger.S, ZUInteger" (("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Zn"))
      ("pmov_p_zi_d" "PUInteger.D, ZUInteger" (("Zn" (reg-range 0 31)) ("Pd" (reg-range 0 15))) ("Pd" "Zn"))
    )
  )
)

(rshrnt
  (c3
    ((sve-z sve-z immediate)
      ("rshrnt_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(stilp
  (c2m1
    ((gpr-64 gpr-64 memory pre-index)
      ("STILP_64SS_ldiappstilp" "XZR, XZR, [SP -16], !" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory pre-index)
      ("STILP_32SE_ldiappstilp" "WZR, WZR, [SP -8], !" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option"))
    )
  )
  (c2m
    ((gpr-64 gpr-64 memory)
      ("STILP_64S_ldiappstilp" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("STILP_32S_ldiappstilp" "WZR, WZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Wt1OrWZR" "Wt2OrWZR" "XnSP_option"))
    )
  )
)

(wrffr
  (c1
    ((sve-p)
      ("wrffr_f_p_" "PUInteger.B" (("Pn" (reg-range 0 15))) ("Pn__3"))
    )
  )
)

(rcwsswppa
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSSWPPA_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(casalb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("CASALB_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
    )
  )
)

(ldsmaxh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSMAXH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(lsr
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("lsr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
      ("lsr_z_p_zw_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
    ((sve-z sve-p sve-z immediate)
      ("lsr_z_p_zi_" "ZUInteger.B, PUInteger/M, ZUInteger.B, UInteger" (("Pg" (reg-range 0 7)) ("imm3" (imm-range 0 7 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
    )
  )
  (c3
    ((sve-z sve-z immediate)
      ("lsr_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
    ((sve-z sve-z sve-z)
      ("lsr_z_zw_" "ZUInteger.B, ZUInteger.B, ZUInteger.D" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(ld3d
  (c2
    ((reg-list sve-p)
      ("ld3d_z_p_br_contiguous" "{Z UInteger .D Z UInteger .D Z UInteger .D}, PUInteger/Z" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3" "Xm__4"))
    )
  )
  (c2m
    ((reg-list sve-p memory)
      ("ld3d_z_p_bi_contiguous" "{Z UInteger .D Z UInteger .D Z UInteger .D}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3"))
    )
  )
)

(lduminl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDUMINL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDUMINL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(uqrshlr
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("uqrshlr_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
)

(ldsetp
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDSETP_128_memop_128" "XZR, XZR, [SP]" (("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
  )
)

(umullt
  (c3
    ((sve-z sve-z sve-z)
      ("umullt_z_zzi_s" "ZUInteger.S, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__4" "imm__78"))
      ("umullt_z_zzi_d" "ZUInteger.D, ZUInteger.S, ZUInteger.S[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm__2" "imm__88"))
      ("umullt_z_zz_" "ZUInteger.H, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(ldumaxa
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDUMAXA_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDUMAXA_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(cmge
  (c3
    ((simd-scalar simd-scalar immediate)
      ("CMGE_asisdmisc_Z" "DUInteger, DUInteger, 0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
    ((simd-vector simd-vector immediate)
      ("CMGE_asimdmisc_Z" "VUInteger.8B, VUInteger.8B, 0" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((simd-vector simd-vector simd-vector)
      ("CMGE_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("CMGE_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
  )
)

(ldtsetal
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDTSETAL_64_memop_unpriv" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDTSETAL_32_memop_unpriv" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(brkb
  (c3
    ((sve-p sve-p sve-p)
      ("brkb_p_p_p_" "PUInteger.B, PUInteger/Z, PUInteger.B" (("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pg__2" "ZM" "Pn__3"))
    )
  )
)

(fsubr
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fsubr_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
    ((sve-z sve-p sve-z float-const)
      ("fsubr_z_p_zs_" "ZUInteger.H, PUInteger/M, ZUInteger.H, 0.5" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Pg" "Zdn__2"))
    )
  )
)

(stxp
  (c3m
    ((gpr-32 gpr-64 gpr-64 memory)
      ("STXP_SP64_ldstexclp" "WZR, XZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
    ((gpr-32 gpr-32 gpr-32 memory)
      ("STXP_SP32_ldstexclp" "WZR, WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "Wt1OrWZR" "Wt2OrWZR" "XnSP_option"))
    )
  )
)

(stlxp
  (c3m
    ((gpr-32 gpr-64 gpr-64 memory)
      ("STLXP_SP64_ldstexclp" "WZR, XZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "Xt1OrXZR" "Xt2OrXZR" "XnSP_option"))
    )
    ((gpr-32 gpr-32 gpr-32 memory)
      ("STLXP_SP32_ldstexclp" "WZR, WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rt2" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "Wt1OrWZR" "Wt2OrWZR" "XnSP_option"))
    )
  )
)

(bf2cvtlt
  (c2
    ((sve-z sve-z)
      ("bf2cvtlt_z_z8_b2bf" "ZUInteger.H, ZUInteger.B" (("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(pacm
  (c0
    (()
      ("PACM_HI_hints" "" () ())
    )
  )
)

(ldsmaxah
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSMAXAH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(ptest
  (c2
    ((sve-p sve-p)
      ("ptest__p_p_" "PUInteger, PUInteger.B" (("Pg" (reg-range 0 15)) ("Pn" (reg-range 0 15))) ("Pg__2" "Pn__3"))
    )
  )
)

(svdot
  (c1
    ((sme-za)
      ("svdot_za32_zzi_2xi" "ZA.S[WUInteger, UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm__2"))
      ("svdot_za_zzi_s4xi" "ZA.S[WUInteger, UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
      ("svdot_za_zzi_d4xi" "ZA.D[WUInteger, UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm__2"))
    )
  )
)

(rcwsclral
  (c2m
    ((gpr-64 gpr-64 memory)
      ("RCWSCLRAL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
  )
)

(sxth
  (c3
    ((sve-z sve-p sve-z)
      ("sxth_z_p_z_m" "ZUInteger.S, PUInteger/M, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("sxth_z_p_z_z" "ZUInteger.S, PUInteger/Z, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(ld3b
  (c2m
    ((reg-list sve-p memory)
      ("ld3b_z_p_br_contiguous" "{Z UInteger .B Z UInteger .B Z UInteger .B}, PUInteger/Z, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3" "Xm__4"))
      ("ld3b_z_p_bi_contiguous" "{Z UInteger .B Z UInteger .B Z UInteger .B}, PUInteger/Z, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Pg" "XnSP__3"))
    )
  )
)

(fmulx
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fmulx_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMULX_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMULX_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMULX_asimdelem_RH_H" "VUInteger.4H, VUInteger.4H, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__2"))
      ("FMULX_asimdelem_R_SD" "VUInteger.2S, VUInteger.2S, VUInteger.S[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2"))
    )
    ((simd-scalar simd-scalar simd-vector)
      ("FMULX_asisdelem_RH_H" "HUInteger, HUInteger, VUInteger.H[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Vm__2"))
      ("FMULX_asisdelem_R_SD" "SUInteger, SUInteger, VUInteger.S[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("FMULX_asisdsamefp16_only" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
      ("FMULX_asisdsame_only" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9" "V_option__9"))
    )
  )
)

(ldapur
  (c1m
    ((gpr-32 memory)
      ("LDAPUR_32_ldapstl_unscaled" "WZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm9_option"))
    )
    ((simd-scalar memory)
      ("LDAPUR_B_ldapstl_simd" "BUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Bt" "XnSP_option" "imm9_option"))
      ("LDAPUR_Q_ldapstl_simd" "QUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Qt" "XnSP_option" "imm9_option"))
      ("LDAPUR_H_ldapstl_simd" "HUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Ht" "XnSP_option" "imm9_option"))
      ("LDAPUR_S_ldapstl_simd" "SUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("St" "XnSP_option" "imm9_option"))
      ("LDAPUR_D_ldapstl_simd" "DUInteger, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("Dt" "XnSP_option" "imm9_option"))
    )
    ((gpr-64 memory)
      ("LDAPUR_64_ldapstl_unscaled" "XZR, [SP]" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XtOrXZR__11" "XnSP_option" "imm9_option"))
    )
  )
)

(fmov
  (c2
    ((simd-vector immediate)
      ("FMOV_asimdimm_S_s" "VUInteger.2S, SInteger" (("Rd" (reg-range 0 31))) ("Vd"))
      ("FMOV_asimdimm_H_h" "VUInteger.4H, SInteger" (("Rd" (reg-range 0 31))) ("Vd"))
      ("FMOV_asimdimm_D2_d" "VUInteger.2D, SInteger" (("Rd" (reg-range 0 31))) ("Vd"))
    )
    ((simd-scalar gpr-32)
      ("FMOV_S32_float2int" "SUInteger, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "WnOrWZR"))
      ("FMOV_H32_float2int" "HUInteger, WZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "WnOrWZR"))
    )
    ((simd-vector gpr-64)
      ("FMOV_V64I_float2int" "VUInteger.D[1], XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "XnOrXZR__11"))
    )
    ((simd-scalar immediate)
      ("FMOV_S_floatimm" "SUInteger, SInteger" (("imm8" (imm-range 0 255 1)) ("Rd" (reg-range 0 31))) ("Sd" "imm__20"))
      ("FMOV_D_floatimm" "DUInteger, SInteger" (("imm8" (imm-range 0 255 1)) ("Rd" (reg-range 0 31))) ("Dd" "imm__20"))
      ("FMOV_H_floatimm" "HUInteger, SInteger" (("imm8" (imm-range 0 255 1)) ("Rd" (reg-range 0 31))) ("Hd" "imm__20"))
    )
    ((simd-scalar gpr-64)
      ("FMOV_D64_float2int" "DUInteger, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "XnOrXZR__11"))
      ("FMOV_H64_float2int" "HUInteger, XZR" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "XnOrXZR__11"))
    )
    ((gpr-64 simd-vector)
      ("FMOV_64VX_float2int" "XZR, VUInteger.D[1]" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Vn"))
    )
    ((simd-scalar simd-scalar)
      ("FMOV_S_floatdp1" "SUInteger, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Sd" "Sn"))
      ("FMOV_D_floatdp1" "DUInteger, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Dd" "Dn"))
      ("FMOV_H_floatdp1" "HUInteger, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn__2"))
    )
    ((gpr-32 simd-scalar)
      ("FMOV_32S_float2int" "WZR, SUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Sn"))
      ("FMOV_32H_float2int" "WZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "Hn__2"))
    )
    ((gpr-64 simd-scalar)
      ("FMOV_64D_float2int" "XZR, DUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Dn"))
      ("FMOV_64H_float2int" "XZR, HUInteger" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "Hn__2"))
    )
  )
)

(addva
  (c4
    ((sme-za sve-p sve-p sve-z)
      ("addva_za_pp_z_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.S" (("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn"))
      ("addva_za_pp_z_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.D" (("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn"))
    )
  )
)

(umops
  (c5
    ((sme-za sve-p sve-p sve-z sve-z)
      ("umops_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
      ("umops_za32_pp_zz_16" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
      ("umops_za_pp_zz_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn__2" "Zm"))
    )
  )
)

(usubwt
  (c3
    ((sve-z sve-z sve-z)
      ("usubwt_z_zz_" "ZUInteger.H, ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(addpl
  (c3
    ((gpr-64 gpr-64 immediate)
      ("addpl_r_ri_" "SP, SP, SInteger" (("Rn" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rd" (reg-range 0 31))) ("XdSP__2" "XnSP__2" "imm__28"))
    )
  )
)

(retaa
  (c0
    (()
      ("RETAA_64E_branch_reg" "" () ())
    )
  )
)

(ldrb
  (c1m1
    ((gpr-32 memory pre-index)
      ("LDRB_32_ldst_immpre" "WZR, [SP SInteger], !" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
    ((gpr-32 memory immediate)
      ("LDRB_32_ldst_immpost" "WZR, [SP], SInteger" (("imm9" (imm-range 0 511 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option"))
    )
  )
  (c1m
    ((gpr-32 memory)
      ("LDRB_32B_ldst_regoff" "WZR, [SP WZR UXTW]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "WorX_choice" "S_option"))
      ("LDRB_32BL_ldst_regoff" "WZR, [SP XZR]" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "XmOrXZR__2"))
      ("LDRB_32_ldst_pos" "WZR, [SP]" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WtOrWZR__4" "XnSP_option" "imm12_option"))
    )
  )
)

(uminp
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("uminp_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("UMINP_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(sqrshrnt
  (c3
    ((sve-z sve-z immediate)
      ("sqrshrnt_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(ushllb
  (c3
    ((sve-z sve-z immediate)
      ("ushllb_z_zi_" "ZUInteger.H, ZUInteger.B, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(bfcvtn
  (c2
    ((simd-vector simd-vector)
      ("BFCVTN_asimdmisc_4S" "VUInteger.4H, VUInteger.4S" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((sve-z reg-list)
      ("bfcvtn_z8_mz2_bf2b" "ZUInteger.B, {Z UInteger .H- Z UInteger .H}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
      ("bfcvtn_z_mz2_" "ZUInteger.H, {Z UInteger .S- Z UInteger .S}" (("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 31))) ("Zd" "Zn1__4" "Zn2__3"))
    )
  )
)

(raddhn
  (c3
    ((simd-vector simd-vector simd-vector)
      ("RADDHN_asimddiff_N" "VUInteger.8B, VUInteger.8H, VUInteger.8H" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
  )
)

(st64bv0
  (c2m
    ((gpr-64 gpr-64 memory)
      ("ST64BV0_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__3" "XtOrXZR__9" "XnSP_option"))
    )
  )
)

(movn
  (c2
    ((gpr-64 immediate)
      ("MOVN_64_movewide" "XZR, UInteger" (("imm16" (imm-range 0 65535 1)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "imm__18"))
    )
    ((gpr-32 immediate)
      ("MOVN_32_movewide" "WZR, UInteger" (("imm16" (imm-range 0 65535 1)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "imm__18"))
    )
  )
)

(fminnmqv
  (c3
    ((simd-vector sve-p sve-z)
      ("fminnmqv_z_p_z_" "VUInteger.8H, PUInteger, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Vd" (reg-range 0 31))) ("Vd__5" "Pg" "Zn"))
    )
  )
)

(ldumaxlh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDUMAXLH_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(pfalse
  (c1
    ((sve-p)
      ("pfalse_p_" "PUInteger.B" (("Pd" (reg-range 0 15))) ("Pd"))
    )
  )
)

(ldaddb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDADDB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(add
  (c5
    ((gpr-64 gpr-64 gpr-32 keyword immediate)
      ("ADD_64_addsub_ext" "SP, SP, WZR, UXTB, UInteger" (("Rm" (reg-range 0 31)) ("imm3" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option" "XnSP_option__6"))
    )
    ((gpr-32 gpr-32 gpr-32 keyword immediate)
      ("ADD_32_addsub_shift" "WZR, WZR, WZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdOrWZR" "WnOrWZR__3" "WmOrWZR__2"))
    )
    ((gpr-64 gpr-64 gpr-64 keyword immediate)
      ("ADD_64_addsub_shift" "XZR, XZR, XZR, LSL, UInteger" (("shift" (imm-range 0 3 1)) ("Rm" (reg-range 0 31)) ("imm6" (imm-range 0 63 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__6" "XnOrXZR__12" "XmOrXZR__4"))
    )
  )
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("add_z_p_zz_" "ZUInteger.B, PUInteger/M, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c1m1
    ((sme-za memory reg-list)
      ("add_za_zw_2x2" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1" "Zm2"))
      ("add_za_zw_4x4" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zm1__2" "Zm4"))
    )
  )
  (c3
    ((gpr-64 gpr-64 immediate)
      ("ADD_64_addsub_imm" "SP, SP, UInteger" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdSP_option" "XnSP_option__3" "imm__17"))
    )
    ((sve-z sve-z immediate)
      ("add_z_zi_" "ZUInteger.B, ZUInteger.B, UInteger" (("size" (element-size B H S D)) ("imm8" (imm-range 0 255 1)) ("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2" "imm__27"))
    )
    ((gpr-32 gpr-32 immediate)
      ("ADD_32_addsub_imm" "WSP, WSP, UInteger" (("imm12" (imm-range 0 4095 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdWSP_option" "WnWSP_option" "imm__17"))
    )
    ((simd-vector simd-vector simd-vector)
      ("ADD_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((gpr-32 gpr-32 gpr-32)
      ("ADD_32_addsub_ext" "WSP, WSP, WZR" (("Rm" (reg-range 0 31)) ("imm3" (imm-range 0 7 1)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("WdWSP_option" "WnWSP_option__2" "WmOrWZR__2"))
    )
    ((reg-list reg-list sve-z)
      ("add_mz_zzv_2x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
      ("add_mz_zzv_4x1" "{Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("ADD_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
    ((sve-z sve-z sve-z)
      ("add_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
  (c1m2
    ((sme-za memory reg-list sve-z)
      ("add_za_zzv_2x1" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}, ZUInteger.S" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn2" "Zm__2"))
      ("add_za_zzv_4x1" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}, ZUInteger.S" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1" "Zn4" "Zm__2"))
    )
    ((sme-za memory reg-list reg-list)
      ("add_za_zzw_2x2" "ZA.S, [W UInteger UInteger VGx2], {Z UInteger . S - Z UInteger . S}, {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("add_za_zzw_4x4" "ZA.S, [W UInteger UInteger VGx4], {Z UInteger . S - Z UInteger . S}, {Z UInteger . S - Z UInteger . S}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7)) ("off3" (imm-range 0 7 1))) ("Wv" "offs" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
  )
)

(fmlalltt
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FMLALLTT_asimdsame2_G" "VUInteger.4S, VUInteger.16B, VUInteger.16B" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FMLALLTT_asimdelem_J" "VUInteger.4S, VUInteger.16B, VUInteger.B[UInteger]" (("Rm" (reg-range 0 15)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm__6"))
    )
    ((sve-z sve-z sve-z)
      ("fmlalltt_z32_z8z8z8_" "ZUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm"))
      ("fmlalltt_z32_z8z8z8i_" "ZUInteger.S, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zda" (reg-range 0 31))) ("Zda" "Zn__2" "Zm__4" "imm__56"))
    )
  )
)

(cpyp
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYP_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(setet
  (c0m2
    ((memory gpr-64 gpr-64)
      ("SETET_SET_memcms" "[XZR]!, XZR!, XZR" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__3" "XnOrXZR__7" "XsOrXZR__7"))
    )
  )
)

(zip1
  (c3
    ((sve-p sve-p sve-p)
      ("zip1_p_pp_" "PUInteger.B, PUInteger.B, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pn__2" "Pm__2"))
    )
    ((simd-vector simd-vector simd-vector)
      ("ZIP1_asimdperm_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((sve-z sve-z sve-z)
      ("zip1_z_zz_q" "ZUInteger.Q, ZUInteger.Q, ZUInteger.Q" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
      ("zip1_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(blraa
  (c2
    ((gpr-64 gpr-64)
      ("BLRAA_64P_branch_reg" "XZR, SP" (("Rn" (reg-range 0 31)) ("Rm" (reg-range 0 31))) ("XnOrXZR" "XmSP_option"))
    )
  )
)

(st4b
  (c2m
    ((reg-list sve-p memory)
      ("st4b_z_p_br_contiguous" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PUInteger, [SP X UInteger]" (("Rm" (reg-range 0 31)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3" "Xm__4"))
      ("st4b_z_p_bi_contiguous" "{Z UInteger .B Z UInteger .B Z UInteger .B Z UInteger .B}, PUInteger, [SP]" (("imm4" (imm-range 0 15 1)) ("Pg" (reg-range 0 7)) ("Rn" (reg-range 0 31)) ("Zt" (reg-range 0 31))) ("Zt1__5" "Zt2__4" "Zt3__2" "Zt4__3" "Pg" "XnSP__3"))
    )
  )
)

(revh
  (c3
    ((sve-z sve-p sve-z)
      ("revh_z_z_m" "ZUInteger.S, PUInteger/M, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
      ("revh_z_z_z" "ZUInteger.S, PUInteger/Z, ZUInteger.S" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Pg" "Zn"))
    )
  )
)

(bfscale
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("bfscale_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((reg-list reg-list sve-z)
      ("bfscale_mz_zzv_2x1" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm__2"))
      ("bfscale_mz_zzv_4x1" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm__2"))
    )
    ((reg-list reg-list reg-list)
      ("bfscale_mz_zzw_2x2" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, {Z UInteger . H- Z UInteger . H}" (("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
      ("bfscale_mz_zzw_4x4" "{Z UInteger .H- Z UInteger . H}, {Z UInteger . H- Z UInteger .H}, {Z UInteger . H- Z UInteger . H}" (("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
    )
  )
)

(ldsmaxab
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSMAXAB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(sunpkhi
  (c2
    ((sve-z sve-z)
      ("sunpkhi_z_z_" "ZUInteger.H, ZUInteger.B" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(smlsll
  (c1
    ((sme-za)
      ("smlsll_za_zzi_s" "ZA.S[WUInteger, UInteger:UInteger, ZUInteger.B, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
      ("smlsll_za_zzi_d" "ZA.D[WUInteger, UInteger:UInteger, ZUInteger.H, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
      ("smlsll_za_zzi_s2xi" "ZA.S[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm__2"))
      ("smlsll_za_zzi_d2xi" "ZA.D[WUInteger, UInteger:UInteger, VGx2, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm__2"))
      ("smlsll_za_zzi_s4xi" "ZA.S[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .B- Z UInteger .B}, ZUInteger.B[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm__2"))
      ("smlsll_za_zzi_d4xi" "ZA.D[WUInteger, UInteger:UInteger, VGx4, {Z UInteger .H- Z UInteger .H}, ZUInteger.H[UInteger" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm__2"))
    )
  )
  (c1m2
    ((sme-za memory reg-list sve-z)
      ("smlsll_za_zzv_2x1" "ZA.S, [W UInteger UInteger : UInteger VGx2], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn2" "Zm__2"))
      ("smlsll_za_zzv_4x1" "ZA.S, [W UInteger UInteger : UInteger VGx4], {Z UInteger . B - Z UInteger . B}, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31))) ("Wv" "offs1__4" "offs4__2" "Zn1" "Zn4" "Zm__2"))
    )
    ((sme-za memory reg-list reg-list)
      ("smlsll_za_zzw_2x2" "ZA.S, [W UInteger UInteger : UInteger VGx2], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 15))) ("Wv" "offs1__4" "offs4__2" "Zn1__2" "Zn2__2" "Zm1__3" "Zm2__2"))
      ("smlsll_za_zzw_4x4" "ZA.S, [W UInteger UInteger : UInteger VGx4], {Z UInteger . B - Z UInteger . B}, {Z UInteger . B - Z UInteger . B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("Wv" "offs1__4" "offs4__2" "Zn1__3" "Zn4__2" "Zm1__4" "Zm4__2"))
    )
    ((sme-za memory sve-z sve-z)
      ("smlsll_za_zzv_1" "ZA.S, [W UInteger UInteger : UInteger], ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 15)) ("Zn" (reg-range 0 31)) ("off2" (imm-range 0 3 1))) ("Wv" "offs1__3" "offs4" "Zn__2" "Zm__2"))
    )
  )
)

(stltxr
  (c2m
    ((gpr-32 gpr-32 memory)
      ("STLTXR_SR32_ldstexclr_unpriv" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "WtOrWZR__4" "XnSP_option"))
    )
    ((gpr-32 gpr-64 memory)
      ("STLTXR_SR64_ldstexclr_unpriv" "WZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "XtOrXZR__11" "XnSP_option"))
    )
  )
)

(sqrshrunb
  (c3
    ((sve-z sve-z immediate)
      ("sqrshrunb_z_zi_" "ZUInteger.B, ZUInteger.H, UInteger" (("imm3" (imm-range 0 7 1)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn"))
    )
  )
)

(bmopa
  (c5
    ((sme-za sve-p sve-p sve-z sve-z)
      ("bmopa_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.S, ZUInteger.S" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
    )
  )
)

(ldsmaxl
  (c2m
    ((gpr-64 gpr-64 memory)
      ("LDSMAXL_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR__2" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("LDSMAXL_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(famax
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("famax_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FAMAX_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FAMAX_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((reg-list reg-list reg-list)
      ("famax_mz_zzw_2x2" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 15)) ("Zdn" (reg-range 0 15))) ("Zdn1" "Zdn2" "Zdn1" "Zdn2" "Zm1__3" "Zm2__2"))
      ("famax_mz_zzw_4x4" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}, {Z UInteger . H - Z UInteger . H}" (("size" (element-size B H S D)) ("Zm" (reg-range 0 7)) ("Zdn" (reg-range 0 7))) ("Zdn1__2" "Zdn4" "Zdn1__2" "Zdn4" "Zm1__4" "Zm4__2"))
    )
  )
)

(cmhs
  (c3
    ((simd-vector simd-vector simd-vector)
      ("CMHS_asimdsame_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("CMHS_asisdsame_only" "DUInteger, DUInteger, DUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
  )
)

(stxr
  (c2m
    ((gpr-32 gpr-32 memory)
      ("STXR_SR32_ldstexclr" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "WtOrWZR__4" "XnSP_option"))
    )
    ((gpr-32 gpr-64 memory)
      ("STXR_SR64_ldstexclr" "WZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "XtOrXZR__11" "XnSP_option"))
    )
  )
)

(setgoetn
  (c0m1
    ((memory gpr-64)
      ("SETGOETN_memset_go" "[XZR]!, XZR!" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__5" "XnOrXZR__10"))
    )
  )
)

(swp
  (c2m
    ((gpr-64 gpr-64 memory)
      ("SWP_64_memop" "XZR, XZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("XsOrXZR" "XtOrXZR__8" "XnSP_option"))
    )
    ((gpr-32 gpr-32 memory)
      ("SWP_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__2" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(stlxr
  (c2m
    ((gpr-32 gpr-32 memory)
      ("STLXR_SR32_ldstexclr" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "WtOrWZR__4" "XnSP_option"))
    )
    ((gpr-32 gpr-64 memory)
      ("STLXR_SR64_ldstexclr" "WZR, XZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__4" "XtOrXZR__11" "XnSP_option"))
    )
  )
)

(uclamp
  (c3
    ((reg-list sve-z sve-z)
      ("uclamp_mz_zz_2" "{Z UInteger . B - Z UInteger . B}, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn__2" "Zm"))
      ("uclamp_mz_zz_4" "{Z UInteger . B - Z UInteger . B}, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn__2" "Zm"))
    )
    ((sve-z sve-z sve-z)
      ("uclamp_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(smopa
  (c5
    ((sme-za sve-p sve-p sve-z sve-z)
      ("smopa_za_pp_zz_32" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
      ("smopa_za32_pp_zz_16" "ZAUInteger.S, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda" "Pn" "Pm" "Zn__2" "Zm"))
      ("smopa_za_pp_zz_64" "ZAUInteger.D, PUInteger/M, PUInteger/M, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 31)) ("Pm" (reg-range 0 7)) ("Pn" (reg-range 0 7)) ("Zn" (reg-range 0 31))) ("ZAda__2" "Pn" "Pm" "Zn__2" "Zm"))
    )
  )
)

(autdzb
  (c1
    ((gpr-64)
      ("AUTDZB_64Z_dp_1src" "XZR" (("Rd" (reg-range 0 31))) ("XdOrXZR__6"))
    )
  )
)

(sha256h2
  (c3
    ((simd-scalar simd-scalar simd-vector)
      ("SHA256H2_QQV_cryptosha3" "QUInteger, QUInteger, VUInteger.4S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Qd" "Qn" "Vm__7"))
    )
  )
)

(uzp1
  (c3
    ((sve-p sve-p sve-p)
      ("uzp1_p_pp_" "PUInteger.B, PUInteger.B, PUInteger.B" (("size" (element-size B H S D)) ("Pm" (reg-range 0 15)) ("Pn" (reg-range 0 15)) ("Pd" (reg-range 0 15))) ("Pd" "Pn__2" "Pm__2"))
    )
    ((simd-vector simd-vector simd-vector)
      ("UZP1_asimdperm_only" "VUInteger.8B, VUInteger.8B, VUInteger.8B" (("size" (element-size B H S D)) ("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((sve-z sve-z sve-z)
      ("uzp1_z_zz_q" "ZUInteger.Q, ZUInteger.Q, ZUInteger.Q" (("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
      ("uzp1_z_zz_" "ZUInteger.B, ZUInteger.B, ZUInteger.B" (("size" (element-size B H S D)) ("Zm" (reg-range 0 31)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 31))) ("Zd" "Zn__2" "Zm"))
    )
  )
)

(cpypwt
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYPWT_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR" "XsOrXZR__5" "XnOrXZR__2"))
    )
  )
)

(fabd
  (c4
    ((sve-z sve-p sve-z sve-z)
      ("fabd_z_p_zz_" "ZUInteger.H, PUInteger/M, ZUInteger.H, ZUInteger.H" (("size" (element-size B H S D)) ("Pg" (reg-range 0 7)) ("Zm" (reg-range 0 31)) ("Zdn" (reg-range 0 31))) ("Zdn" "Pg" "Zdn" "Zm"))
    )
  )
  (c3
    ((simd-vector simd-vector simd-vector)
      ("FABD_asimdsamefp16_only" "VUInteger.4H, VUInteger.4H, VUInteger.4H" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
      ("FABD_asimdsame_only" "VUInteger.2S, VUInteger.2S, VUInteger.2S" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn__2" "Vm"))
    )
    ((simd-scalar simd-scalar simd-scalar)
      ("FABD_asisdsamefp16_only" "HUInteger, HUInteger, HUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Hd" "Hn" "Hm"))
      ("FABD_asisdsame_only" "SUInteger, SUInteger, SUInteger" (("Rm" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("V_option__9" "V_option__9" "V_option__9"))
    )
  )
)

(cmlt
  (c3
    ((simd-scalar simd-scalar immediate)
      ("CMLT_asisdmisc_Z" "DUInteger, DUInteger, 0" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ())
    )
    ((simd-vector simd-vector immediate)
      ("CMLT_asimdmisc_Z" "VUInteger.8B, VUInteger.8B, 0" (("size" (element-size B H S D)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
  )
)

(cpyfmtwn
  (c0m3
    ((memory memory pre-index gpr-64)
      ("CPYFMTWN_CPY_memcms" "[XZR]!, [XZR], !, XZR!" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("XdOrXZR__2" "XsOrXZR__6" "XnOrXZR__3"))
    )
  )
)

(ldsetalb
  (c2m
    ((gpr-32 gpr-32 memory)
      ("LDSETALB_32_memop" "WZR, WZR, [SP]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR" "WtOrWZR__2" "XnSP_option"))
    )
  )
)

(smop4a
  (c3
    ((sme-za reg-list sve-z)
      ("smop4a_za_zz_b2x1" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
      ("smop4a_za32_zz_h2x1" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
      ("smop4a_za_zz_h2x1" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm_mortlach"))
    )
    ((sme-za reg-list reg-list)
      ("smop4a_za_zz_b2x2" "ZAUInteger.S, {Z UInteger .B- Z UInteger .B}, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("smop4a_za32_zz_h2x2" "ZAUInteger.S, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("smop4a_za_zz_h2x2" "ZAUInteger.D, {Z UInteger .H- Z UInteger .H}, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn1_mortlach" "Zn2_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
    ((sme-za sve-z sve-z)
      ("smop4a_za_zz_b1x1" "ZAUInteger.S, ZUInteger.B, ZUInteger.B" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
      ("smop4a_za32_zz_h1x1" "ZAUInteger.S, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm_mortlach"))
      ("smop4a_za_zz_h1x1" "ZAUInteger.D, ZUInteger.H, ZUInteger.H" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm_mortlach"))
    )
    ((sme-za sve-z reg-list)
      ("smop4a_za_zz_b1x2" "ZAUInteger.S, ZUInteger.B, {Z UInteger .B- Z UInteger .B}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("smop4a_za32_zz_h1x2" "ZAUInteger.S, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
      ("smop4a_za_zz_h1x2" "ZAUInteger.D, ZUInteger.H, {Z UInteger .H- Z UInteger .H}" (("Zm" (reg-range 0 7)) ("Zn" (reg-range 0 7))) ("ZAda__2" "Zn_mortlach" "Zm1_mortlach" "Zm2_mortlach"))
    )
  )
)

(uunpk
  (c2
    ((reg-list reg-list)
      ("uunpk_mz_z_4" "{Z UInteger . H - Z UInteger . H}, {Z UInteger . B - Z UInteger . B}" (("size" (element-size B H S D)) ("Zn" (reg-range 0 15)) ("Zd" (reg-range 0 7))) ("Zd1__2" "Zd4" "Zn1__4" "Zn2__3"))
    )
    ((reg-list sve-z)
      ("uunpk_mz_z_2" "{Z UInteger . H - Z UInteger . H}, ZUInteger.B" (("size" (element-size B H S D)) ("Zn" (reg-range 0 31)) ("Zd" (reg-range 0 15))) ("Zd1" "Zd2" "Zn"))
    )
  )
)

(aesmc
  (c2
    ((simd-vector simd-vector)
      ("AESMC_B_cryptoaes" "VUInteger.16B, VUInteger.16B" (("Rn" (reg-range 0 31)) ("Rd" (reg-range 0 31))) ("Vd" "Vn"))
    )
    ((sve-z sve-z)
      ("aesmc_z_z_" "ZUInteger.B, ZUInteger.B" (("Zdn" (reg-range 0 31))) ("Zdn__2" "Zdn__2"))
    )
  )
)

(casalh
  (c2m
    ((gpr-32 gpr-32 memory)
      ("CASALH_C32_comswap" "WZR, WZR, [SP 0]" (("Rs" (reg-range 0 31)) ("Rn" (reg-range 0 31)) ("Rt" (reg-range 0 31))) ("WsOrWZR__3" "WtOrWZR__3" "XnSP_option"))
    )
  )
)

