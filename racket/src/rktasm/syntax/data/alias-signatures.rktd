;; ============================================================
;; alias-signatures.rktd - 别名签名定义
;; ============================================================
;;
;; 生成: racket syntax/gen-alias-signatures.rkt
;; 数据来源: MRS Instructions.json
;;

(stumaxl ((c2 (gpr-32 gpr-64)) (c2 (gpr-64 gpr-64))))

(stuminh ((c2 (gpr-32 gpr-64))))

(stclrb ((c2 (gpr-32 gpr-64))))

(not ((c3 (sve-p sve-p sve-p))))

(cinc ((c3 (gpr-32 gpr-64 cond-code)) (c3 (gpr-64 gpr-64 cond-code))))

(umull ((c3 (gpr-64 gpr-32 gpr-32))))

(mul ((c3 (gpr-32 gpr-32 gpr-32)) (c3 (gpr-64 gpr-64 gpr-64))))

(ngcs ((c2 (gpr-32 gpr-32)) (c2 (gpr-64 gpr-64))))

(asr ((c3 (gpr-32 gpr-32 keyword)) (c3 (gpr-64 gpr-64 keyword)) (c3 (gpr-32 gpr-32 gpr-32)) (c3 (gpr-64 gpr-64 gpr-64))))

(stsetl ((c2 (gpr-32 gpr-64)) (c2 (gpr-64 gpr-64))))

(faclt ((c4 (sve-p sve-p sve-z sve-z))))

(dc ((c1 (gpr-64))))

(lsl ((c3 (gpr-32 gpr-32 keyword)) (c3 (gpr-64 gpr-64 keyword)) (c3 (gpr-32 gpr-32 gpr-32)) (c3 (gpr-64 gpr-64 gpr-64))))

(stsmax ((c2 (gpr-32 gpr-64)) (c2 (gpr-64 gpr-64))))

(steorh ((c2 (gpr-32 gpr-64))))

(trcit ((c1 (gpr-64))))

(cset ((c2 (gpr-32 cond-code)) (c2 (gpr-64 cond-code))))

(uxth ((c2 (gpr-32 gpr-32))))

(gcsss2 ((c1 (gpr-64))))

(staddh ((c2 (gpr-32 gpr-64))))

(cbls ((c3 (gpr-32 gpr-32 immediate)) (c3 (gpr-64 gpr-64 immediate)) (c3 (gpr-32 immediate immediate)) (c3 (gpr-64 immediate immediate))))

(cmple ((c4 (sve-p sve-p sve-z sve-z))))

(cbble ((c3 (gpr-32 gpr-32 immediate))))

(ror ((c3 (gpr-32 gpr-64 keyword)) (c3 (gpr-64 gpr-64 keyword)) (c3 (gpr-32 gpr-32 gpr-32)) (c3 (gpr-64 gpr-64 gpr-64))))

(mvn ((c2 (gpr-32 gpr-32)) (c2 (gpr-64 gpr-64)) (c2 (simd-v simd-v))))

(ubfx ((c2 (gpr-32 gpr-32)) (c2 (gpr-64 gpr-64))))

(stset ((c2 (gpr-32 gpr-64)) (c2 (gpr-64 gpr-64))))

(stsmaxlh ((c2 (gpr-32 gpr-64))))

(pssbb ((c0 ())))

(sttsetl ((c2 (gpr-32 gpr-64)) (c2 (gpr-64 gpr-64))))

(cblt ((c3 (gpr-32 gpr-32 immediate)) (c3 (gpr-64 gpr-64 immediate))))

(stclr ((c2 (gpr-32 gpr-64)) (c2 (gpr-64 gpr-64))))

(stumaxlb ((c2 (gpr-32 gpr-64))))

(cosp ((c1 (gpr-64))))

(ubfiz ((c2 (gpr-32 gpr-32)) (c2 (gpr-64 gpr-64))))

(stseth ((c2 (gpr-32 gpr-64))))

(csetm ((c2 (gpr-32 cond-code)) (c2 (gpr-64 cond-code))))

(orn ((c3 (sve-z sve-z immediate))))

(stuminl ((c2 (gpr-32 gpr-64)) (c2 (gpr-64 gpr-64))))

(stumaxlh ((c2 (gpr-32 gpr-64))))

(cblo ((c3 (gpr-32 gpr-32 immediate)) (c3 (gpr-64 gpr-64 immediate))))

(cpp ((c1 (gpr-64))))

(steorlh ((c2 (gpr-32 gpr-64))))

(sbfx ((c2 (gpr-32 gpr-32)) (c2 (gpr-64 gpr-64))))

(sttset ((c2 (gpr-32 gpr-64)) (c2 (gpr-64 gpr-64))))

(staddb ((c2 (gpr-32 gpr-64))))

(steor ((c2 (gpr-32 gpr-64)) (c2 (gpr-64 gpr-64))))

(bic ((c3 (sve-z sve-z immediate))))

(stsminl ((c2 (gpr-32 gpr-64)) (c2 (gpr-64 gpr-64))))

(stsmaxb ((c2 (gpr-32 gpr-64))))

(bfi ((c2 (gpr-32 gpr-32)) (c2 (gpr-64 gpr-64))))

(gcspopx ((c4 (immediate immediate immediate immediate))))

(stsminb ((c2 (gpr-32 gpr-64))))

(cmplo ((c4 (sve-p sve-p sve-z sve-z))))

(sxtw ((c2 (gpr-64 gpr-32))))

(steorb ((c2 (gpr-32 gpr-64))))

(mov ((c2 (sve-z sve-z)) (c2 (sve-z immediate)) (c3 (sve-z sve-p immediate)) (c2 (sve-z simd-v)) (c3 (sve-z sve-z immediate)) (c2 (sve-z gpr-64)) (c3 (sve-z sve-p simd-v)) (c3 (sve-z sve-p gpr-64)) (c3 (sve-z sve-p sve-z)) (c3 (sve-p sve-p sve-p)) (c2 (sve-p sve-p)) (c4 (gpr-32 immediate sve-p sve-z)) (c5 (sve-z gpr-32 immediate sve-p sve-z)) (c5 (gpr-32 immediate immediate sve-z sve-z)) (c6 (sve-z gpr-32 immediate immediate sve-z sve-z)) (c4 (gpr-32 immediate sve-z sve-z)) (c4 (sve-z sve-p gpr-32 immediate)) (c5 (sve-z sve-p sve-z gpr-32 immediate)) (c5 (sve-z sve-z gpr-32 immediate immediate)) (c6 (sve-z sve-z sve-z gpr-32 immediate immediate)) (c4 (sve-z sve-z gpr-32 immediate)) (c2 (gpr-32 gpr-32)) (c2 (gpr-64 gpr-64)) (c2 (gpr-32 immediate)) (c2 (gpr-64 immediate)) (c1 (gpr-32)) (c1 (gpr-64)) (c3 (simd-v simd-v immediate)) (c2 (gpr-32 simd-v)) (c4 (simd-v immediate gpr-64 gpr-64)) (c2 (gpr-64 simd-v)) (c4 (simd-v immediate simd-v immediate)) (c2 (simd-v simd-v))))

(sttclr ((c2 (gpr-32 gpr-64)) (c2 (gpr-64 gpr-64))))

(staddlb ((c2 (gpr-32 gpr-64))))

(gcspushm ((c1 (gpr-64))))

(uxtl ((c2 (simd-v simd-v))))

(tlbip ((c4 (immediate immediate immediate immediate))))

(stuminb ((c2 (gpr-32 gpr-64))))

(stsmin ((c2 (gpr-32 gpr-64)) (c2 (gpr-64 gpr-64))))

(fcmlt ((c4 (sve-p sve-p sve-z sve-z))))

(cbhlo ((c3 (gpr-32 gpr-32 immediate))))

(cmpls ((c4 (sve-p sve-p sve-z sve-z))))

(cmp ((c2 (gpr-32 immediate)) (c2 (gpr-64 immediate)) (c2 (gpr-32 gpr-32)) (c2 (gpr-64 gpr-64)) (c3 (gpr-64 gpr-64 gpr-64))))

(stclrh ((c2 (gpr-32 gpr-64))))

(negs ((c2 (gpr-32 gpr-32)) (c2 (gpr-64 gpr-64))))

(lsr ((c3 (gpr-32 gpr-32 keyword)) (c3 (gpr-64 gpr-64 keyword)) (c3 (gpr-32 gpr-32 gpr-32)) (c3 (gpr-64 gpr-64 gpr-64))))

(tlbi ((c4 (immediate immediate immediate immediate))))

(stumaxb ((c2 (gpr-32 gpr-64))))

(stumax ((c2 (gpr-32 gpr-64)) (c2 (gpr-64 gpr-64))))

(steorlb ((c2 (gpr-32 gpr-64))))

(cmplt ((c4 (sve-p sve-p sve-z sve-z))))

(apas ((c1 (gpr-64))))

(mneg ((c3 (gpr-32 gpr-32 gpr-32)) (c3 (gpr-64 gpr-64 gpr-64))))

(stsmaxl ((c2 (gpr-32 gpr-64)) (c2 (gpr-64 gpr-64))))

(cfp ((c1 (gpr-64))))

(movs ((c3 (sve-p sve-p sve-p)) (c2 (sve-p sve-p))))

(cbhs ((c3 (gpr-32 immediate immediate)) (c3 (gpr-64 immediate immediate))))

(smull ((c3 (gpr-64 gpr-32 gpr-32))))

(gicr ((c1 (gpr-64))))

(at ((c1 (gpr-64))))

(mlbi ((c4 (immediate immediate immediate immediate))))

(cbbls ((c3 (gpr-32 gpr-32 immediate))))

(stuminlb ((c2 (gpr-32 gpr-64))))

(stsetlh ((c2 (gpr-32 gpr-64))))

(smstart ((c1 (immediate))))

(cmn ((c2 (gpr-32 immediate)) (c2 (gpr-64 immediate)) (c2 (gpr-32 gpr-32)) (c2 (gpr-64 gpr-64)) (c3 (gpr-64 gpr-64 gpr-64))))

(gcspopcx ((c4 (immediate immediate immediate immediate))))

(steorl ((c2 (gpr-32 gpr-64)) (c2 (gpr-64 gpr-64))))

(gcsss1 ((c1 (gpr-64))))

(sxth ((c2 (gpr-32 gpr-32)) (c2 (gpr-64 gpr-32))))

(stsminlb ((c2 (gpr-32 gpr-64))))

(stclrlh ((c2 (gpr-32 gpr-64))))

(fmov ((c2 (sve-z sve-p)) (c3 (sve-z sve-p immediate)) (c1 (sve-z)) (c2 (sve-z immediate))))

(uxtb ((c2 (gpr-32 gpr-32))))

(plbi ((c4 (immediate immediate immediate immediate))))

(stsmaxlb ((c2 (gpr-32 gpr-64))))

(sttadd ((c2 (gpr-32 gpr-64)) (c2 (gpr-64 gpr-64))))

(rev64 ((c2 (gpr-64 gpr-64))))

(sbfiz ((c2 (gpr-32 gpr-32)) (c2 (gpr-64 gpr-64))))

(staddlh ((c2 (gpr-32 gpr-64))))

(ic ((c4 (immediate immediate immediate immediate))))

(gcspopm ((c5 (gpr-64 immediate immediate immediate immediate))))

(cbblt ((c3 (gpr-32 gpr-32 immediate))))

(cmpp ((c2 (gpr-64 gpr-64))))

(stsetlb ((c2 (gpr-32 gpr-64))))

(cbge ((c3 (gpr-32 immediate immediate)) (c3 (gpr-64 immediate immediate))))

(cbhle ((c3 (gpr-32 gpr-32 immediate))))

(fcmle ((c4 (sve-p sve-p sve-z sve-z))))

(ngc ((c2 (gpr-32 gpr-32)) (c2 (gpr-64 gpr-64))))

(tst ((c2 (gpr-32 immediate)) (c2 (gpr-64 immediate)) (c2 (gpr-32 gpr-32)) (c2 (gpr-64 gpr-64))))

(cble ((c3 (gpr-32 gpr-32 immediate)) (c3 (gpr-64 gpr-64 immediate)) (c3 (gpr-32 immediate immediate)) (c3 (gpr-64 immediate immediate))))

(facle ((c4 (sve-p sve-p sve-z sve-z))))

(stclrl ((c2 (gpr-32 gpr-64)) (c2 (gpr-64 gpr-64))))

(stumaxh ((c2 (gpr-32 gpr-64))))

(stsminlh ((c2 (gpr-32 gpr-64))))

(stclrlb ((c2 (gpr-32 gpr-64))))

(stsetb ((c2 (gpr-32 gpr-64))))

(sttclrl ((c2 (gpr-32 gpr-64)) (c2 (gpr-64 gpr-64))))

(cbhls ((c3 (gpr-32 gpr-32 immediate))))

(staddl ((c2 (gpr-32 gpr-64)) (c2 (gpr-64 gpr-64))))

(smnegl ((c3 (gpr-64 gpr-32 gpr-32))))

(sttaddl ((c2 (gpr-32 gpr-64)) (c2 (gpr-64 gpr-64))))

(stsmaxh ((c2 (gpr-32 gpr-64))))

(ssbb ((c0 ())))

(umnegl ((c3 (gpr-64 gpr-32 gpr-32))))

(neg ((c2 (gpr-32 gpr-32)) (c2 (gpr-64 gpr-64))))

(sxtb ((c2 (gpr-32 gpr-32)) (c2 (gpr-64 gpr-32))))

(nots ((c3 (sve-p sve-p sve-p))))

(gic ((c4 (immediate immediate immediate immediate))))

(bfc ((c1 (gpr-32)) (c1 (gpr-64))))

(cbhlt ((c3 (gpr-32 gpr-32 immediate))))

(stsminh ((c2 (gpr-32 gpr-64))))

(gcspushx ((c4 (immediate immediate immediate immediate))))

(cneg ((c3 (gpr-32 gpr-64 cond-code)) (c3 (gpr-64 gpr-64 cond-code))))

(smstop ((c1 (immediate))))

(cinv ((c3 (gpr-32 gpr-64 cond-code)) (c3 (gpr-64 gpr-64 cond-code))))

(stuminlh ((c2 (gpr-32 gpr-64))))

(brb ((c4 (immediate immediate immediate immediate))))

(eon ((c3 (sve-z sve-z immediate))))

(dvp ((c1 (gpr-64))))

(gsb ((c4 (immediate immediate immediate immediate))))

(cbblo ((c3 (gpr-32 gpr-32 immediate))))

(sxtl ((c2 (simd-v simd-v))))

(stadd ((c2 (gpr-32 gpr-64)) (c2 (gpr-64 gpr-64))))

(bfxil ((c2 (gpr-32 gpr-32)) (c2 (gpr-64 gpr-64))))

(stumin ((c2 (gpr-32 gpr-64)) (c2 (gpr-64 gpr-64))))

