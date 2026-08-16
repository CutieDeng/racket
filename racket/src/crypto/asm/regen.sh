#!/bin/bash
# regen.sh — rktcrypto 汇编内核一键再生与一致性检查（Phase 0 护栏）
#
#   asm/regen.sh check [kernel]    # 校验已提交产物可从已提交源复现（不写文件）
#   asm/regen.sh gate  [kernel]    # 用当前 rktasm 再生到临时文件并跑差分门禁（不写
#                                  # 工作树）——证明**当前 rktasm 产物**正确
#   asm/regen.sh regen <kernel>    # 重生成 .asm 与 .S，并自动门禁刚写下的 .S
#                                  # （门禁失败 → 非零退出并提示回滚）
#   asm/regen.sh list              # 列出内核与支持状态
#
# check 与 gate 的分工：check 比"已提交 .S 是否可复现"（字节口径），gate 比"当前
# rktasm 产物是否语义正确"（差分口径）。KNOWN_DRIFT 内核 check 必然报漂移，其正确性
# 只能由 gate 证明——故信任任何 regen 前先跑 gate。
#
# 比较口径：指令体等价——剥离注释行/尾注释/空行/平台 guard 后逐行 diff，
# 因此 provenance 头与 --keep-comments 注释不影响 check 结果。
#
# 已知漂移（rktasm(原 asmp) 分配器演进，重提交需先过差分门禁，见 ASM-ENHANCEMENT-PLAN.md）:
#   keccak (性能性漂移, 不可重提交)、p256 (_mont_mul_p256, 中性)
# 生成器全部为 asm/gen/*.rkt (Racket, require rktasm gnu-writer; Phase F 迁移完成)

set -euo pipefail
cd "$(dirname "$0")/.."   # crypto/ 根

# rktasm (原 asmp) 已入树: racket/src/rktasm (与 crypto 平级)
RKTASM=${RKTASM:-$(cd ../rktasm && pwd)}
RACKET=${RACKET:-racket}
# --allow-sp-writes: 放行 p256_hand 里 M3 未实现故手写的 scratch 内存帧 sp 增减；
# 对不手写 sp 的其它内核是 no-op（放行性标志，不改 codegen）。
RKTASM_FLAGS="--gnu-input --apple --elim --default-abi aapcs64 --keep-comments --allow-sp-writes"
# ELF/GNU 变体：去掉 --apple。rktasm 直出 GNU 语法（`;`→`//`，符号去下划线，
# 无 .subsections_via_symbols）——**指令/操作数逐字节相同**，仅发射层符号装饰不同。
# 每个 .S 因此双分支包裹：__APPLE__ 走 apple 体（committed 逐字节不变），否则走此 ELF 体。
RKTASM_ELF_FLAGS="--gnu-input --elim --default-abi aapcs64 --keep-comments --allow-sp-writes"
# gate-elf：aarch64-linux 差分门禁的容器镜像与编译器（可被真 CI 用环境变量覆盖，无需 Docker）。
ELF_IMAGE=${ELF_IMAGE:-gcc12-openeuler-built:latest}
ELF_CC=${ELF_CC:-gcc}
# 非空 → 直接在本机跑 ELF 门禁（假定已是 aarch64-linux）；空 → 用 docker 跑镜像。
ELF_NATIVE=${ELF_NATIVE:-}
# 基线 arch。feature 内核(sha1/keccak)的 ELF 体靠 .S 内 `.arch_extension` 自声明
# 所需扩展(见 elf_arch_ext)，故 gate-elf 用基线 arch 即可，正好复刻 build.zuo(无 per-file
# -march)的真实构建场景——若某 feature .S 漏了 .arch_extension，这里会装配失败暴露。
ELF_MARCH=${ELF_MARCH:-armv8-a}
ELF_SHIM=${ELF_SHIM:-asm/tests/elf-shim}
# 已知漂移（当前 asmp 产物 != 已提交 .S）。两者正确性均由 gate 差分证实，但性能不同：
#   keccak — 当前 rktasm 分配**慢 2~5%**（gate 交织 A/B 实测 2026-08-02；空对照 ±0.2%，
#            五个 rate 同向 → 真回归，非噪声）。**故不可重提交**，白名单保留旧 .S。
#   p256   — _mont_mul_p256 分配漂移，但性能中性（±0.3%），仅无必要重提交。
KNOWN_DRIFT=" keccak p256 "

# kernel|generator 命令(空=无)|.asm 源(空格分隔,空=直出)|.S 产物
TABLE=(
  "bn_op|RKTASM=\"\$RKTASM\" \"\$RACKET\" asm/gen/opscan.rkt 16 asm/mont_mul_op16.asm|asm/mont_mul_op16.asm|rktcrypto_bn_op.S"
  "bn_fips|RKTASM=\"\$RKTASM\" \"\$RACKET\" asm/gen/fips.rkt 32 asm/bn_fips32.asm|asm/bn_fips32.asm|rktcrypto_bn_fips.S"
  "bn_sqr||asm/bn_sqr.asm|rktcrypto_bn_sqr.S"   # .context (scope library) 声明寄存器-ABI 一次；.save all + .frame 32 + .alloca x5,4 生成 M3 帧(帧指针 x29 + 变长 sub sp,sp,x5,lsl#4)；body 手写调度逐指令改名 x.<field>
  "keccak|RKTASM=\"\$RKTASM\" \"\$RACKET\" asm/gen/keccak.rkt absorb asm/keccak_absorb.asm|asm/keccak_absorb.asm|rktcrypto_keccak_asm.S"
  "keccak_f2|RKTASM=\"\$RKTASM\" \"\$RACKET\" asm/gen/keccak.rkt f2 asm/keccak_f2.asm|asm/keccak_f2.asm|rktcrypto_keccak_f2_asm.S"
  "md5||asm/md5_blocks.asm|rktcrypto_md5_asm.S"   # committed .asm is canonical (hand-scheduled, semantic names); gen_md5.py retired
  "ecc|RKTASM=\"\$RKTASM\" \"\$RACKET\" asm/gen/mulplain.rkt 6 asm/mul_plain6.asm && RKTASM=\"\$RKTASM\" \"\$RACKET\" asm/gen/mulplain.rkt 9 asm/mul_plain9.asm|asm/mul_plain6.asm asm/mul_plain9.asm asm/reduce_p384.asm|rktcrypto_ecc_asm.S"
  "sha1|RKTASM=\"\$RKTASM\" \"\$RACKET\" asm/gen/sha1.rkt asm/sha1_blocks.asm|asm/sha1_blocks.asm|rktcrypto_sha1_asm.S"
  "p256||asm/mont_mul.asm asm/mont_mul_p256.asm asm/mont_sqrn.asm|rktcrypto_p256_asm.S"
  "p256_hand||asm/p256_hand.asm|rktcrypto_p256_hand.S"   # .context (scope library) 声明寄存器-ABI 一次；.save all 生成 callee-saved 帧；scratch 内存帧手写(--allow-sp-writes)
  "mont_cios||asm/mont_cios.asm|rktcrypto_mont_cios_asm.S"   # 通用宽度 CIOS Montgomery 乘（任意奇模数），brainpool 曲线 (nl=4/6/8) 的 fp_mul 走它
)
# 所有内核均有 asmp 源（bn_sqr 经 rktasm M3 .frame/.alloca 收编，见上 TABLE 行）。
UNSUPPORTED=""

# 差分门禁映射: kernel|cc 额外 flag|harness .c(空格分隔,逐个构建运行)|链接依赖
# gate 时把本内核的 .S 名替换成"当前 asmp 从已提交 .asm 再生"的临时 .S ——
# 故门禁的是**当前产物**，而非已提交 .S。这对 KNOWN_DRIFT 内核尤其关键：
# 它们的当前 rktasm 输出与已提交 .S 不同，check 只报漂移、不能证明其正确。
GATE=(
  "bn_op|-I..|asm/tests/test_bn.c|rktcrypto_bn_op.S rktcrypto_bn_fips.S rktcrypto_bn_sqr.S"
  "bn_fips|-I..|asm/tests/test_bn.c|rktcrypto_bn_op.S rktcrypto_bn_fips.S rktcrypto_bn_sqr.S"
  "bn_sqr|-I..|asm/tests/test_bn.c|rktcrypto_bn_op.S rktcrypto_bn_fips.S rktcrypto_bn_sqr.S"
  "keccak||asm/tests/test_keccak.c|rktcrypto_keccak_asm.S"
  "keccak_f2||asm/tests/test_keccak_f2.c|rktcrypto_keccak_f2_asm.S"
  "md5||asm/tests/test_md5_sha1.c|rktcrypto_md5_asm.S rktcrypto_sha1_asm.S"
  "sha1||asm/tests/test_md5_sha1.c|rktcrypto_md5_asm.S rktcrypto_sha1_asm.S"
  "ecc|-I..|asm/tests/test_ecc_mul.c asm/tests/test_reduce_p384.c|rktcrypto_ecc_asm.S rktcrypto_mont_cios_asm.S rktcrypto_bn.c rktcrypto_bn_op.S rktcrypto_bn_fips.S rktcrypto_bn_sqr.S rktcrypto_p521rr.c"
  "p256|-I.|asm/tests/test_mont_mul.c asm/tests/test_p256_extra.c|rktcrypto_p256_asm.S rktcrypto_p256_hand.S rktcrypto_bn.c rktcrypto_bn_op.S rktcrypto_bn_fips.S rktcrypto_bn_sqr.S"
  "p256_hand|-I.|asm/tests/test_mont_mul.c asm/tests/test_p256_extra.c asm/tests/test_mixed_add.c asm/tests/test_mont_sqrn.c|rktcrypto_p256_asm.S rktcrypto_p256_hand.S rktcrypto_bn.c rktcrypto_bn_op.S rktcrypto_bn_fips.S rktcrypto_bn_sqr.S"
  "mont_cios|-I..|asm/tests/test_mont_cios.c|rktcrypto_mont_cios_asm.S"
)

# 选出 APPLE 分支（__aarch64__ && __APPLE__ 均定义），并剥掉所有 cpp 条件指令行。
# .S 现为双分支包裹（# if defined(__APPLE__) / # else <elf> / # endif）；check 要拿
# apple 体与 rktasm --apple 直出比对，故须先滤掉 ELF 分支。本仓所有 guard 条件只用
# defined(__APPLE__)/defined(__aarch64__)（apple 上恒真）与 !defined(__APPLE__)（恒假），
# 故 cond() 只判有无 !defined 即可，无需完整 cpp。
select_apple() {
  awk '
    function cond(s) {
      if (s ~ /!defined\(__APPLE__\)/)   return 0;
      if (s ~ /!defined\(__aarch64__\)/) return 0;
      return 1;
    }
    /^[ \t]*#[ \t]*endif/ { d--; next }
    /^[ \t]*#[ \t]*else/  { taken[d]=!done[d]; done[d]=1;
                            act[d]=(d>1?act[d-1]:1)&&taken[d]; next }
    /^[ \t]*#[ \t]*elif/  { if(done[d]){taken[d]=0}else{taken[d]=cond($0);done[d]=taken[d]}
                            act[d]=(d>1?act[d-1]:1)&&taken[d]; next }
    /^[ \t]*#[ \t]*(ifdef|ifndef|if)/ { d++; taken[d]=cond($0); done[d]=taken[d];
                            act[d]=(d>1?act[d-1]:1)&&taken[d]; next }
    { if (d==0 || act[d]) print }
  ' "$1"
}

# 剥注释/空行/guard 后的指令体（仅 apple 分支）
body() {
  select_apple "$1" \
    | sed -e '/\/\*/,/\*\//d' \
          -e 's/[[:space:]]*;.*$//' -e 's|[[:space:]]*//.*$||' \
    | grep -v '^[[:space:]]*$' \
    || true
}

assemble() { # $1..: .asm 源 → stdout 拼接产物体（apple 语法）
  # as.rkt 从 cwd 解析 config/abi.rktd，必须在 $RKTASM 内调用
  local out here; here=$(pwd)
  for src in "$@"; do
    out=$(mktemp)
    (cd "$RKTASM" && "$RACKET" cli/as.rkt $RKTASM_FLAGS -o "$out" "$here/$src" >/dev/null)
    cat "$out"; rm -f "$out"
  done
}

assemble_elf() { # 同 assemble，但 GNU/ELF 语法（去 --apple）
  local out here; here=$(pwd)
  for src in "$@"; do
    out=$(mktemp)
    (cd "$RKTASM" && "$RACKET" cli/as.rkt $RKTASM_ELF_FLAGS -o "$out" "$here/$src" >/dev/null)
    cat "$out"; rm -f "$out"
  done
}

# ELF 汇编器启用某内核 SHA1/SHA3 指令所需特性的 arch 指令。整行注入 ELF 分支，使
# .S 自声明依赖 → build.zuo 无需 per-file -march（apple 分支不受影响：指令在
# `# else` 内，仅 GNU as 可见）。其余内核为基线 ARMv8-A，返回空。
#
# 注意 SHA3 (eor3/rax1/xar/bcax) 是 FEAT_SHA3 = ARMv8.2-A 可选扩展：GNU as 上单靠
# `.arch_extension sha3` 不足以启用（默认基线 armv8-a 为 v8.0，扩展位不生效，debian12/
# ubuntu2204 装配报 "selected processor does not support eor3"），必须用 `.arch
# armv8.2-a+sha3` 一并抬高基线。SHA1/2 (FEAT_SHA1/SHA256) 是 v8.0 可选扩展，
# `.arch_extension sha2` 在基线上即可启用，保持原样。
elf_arch_ext() { # $1=kernel → ELF 分支 arch 指令整行（可空）
  case "$1" in
    keccak|keccak_f2) echo ".arch armv8.2-a+sha3" ;;  # FEAT_SHA3 需 v8.2 基线
    sha1)             echo ".arch_extension sha2" ;;   # FEAT_SHA1/2 v8.0 扩展即可
    *)                echo "" ;;
  esac
}

# 输出双分支包裹体：__APPLE__ 走 $1（apple 体），否则走 $2（ELF 体）。
# $3（可选）=ELF 分支 arch 指令整行，使 ELF 体自声明所需指令扩展。
emit_dual() { # $1=apple 体文件 $2=elf 体文件 $3=elf arch 指令整行（可空）
  printf '#if defined(__aarch64__)\n'
  printf '# if defined(__APPLE__)\n'
  cat "$1"
  printf '# else\n'
  [ -n "$3" ] && printf '%s\n' "$3"
  cat "$2"
  printf '# endif\n'
  printf '#endif\n'
}

# A kernel's human description lives in its first .asm source as a leading block
# of ';;'-comment lines (before .function). regen carries it into the .S header
# so the description is version-controlled with the source and survives regen.
source_description() { # $1 = first .asm source (may be empty for direct-output)
  [ -z "$1" ] || [ ! -f "$1" ] && return 0
  awk '/^[[:space:]]*;;/ { sub(/^[[:space:]]*;;[[:space:]]?/, ""); print "   " $0; next }
       /^[[:space:]]*$/ { next }
       { exit }' "$1"
}

provenance() { # $1=kernel $2=gen $3=srcs $4=out
  local commit; commit=$(git -C "$RKTASM" rev-parse --short HEAD 2>/dev/null || echo unknown)
  local first_src; first_src=$(echo "$3" | awk '{print $1}')
  printf '/* %s — GENERATED; do not edit by hand.\n' "$4"
  source_description "$first_src"
  [ -n "$3" ] && printf '   Source: %s\n' "$3"
  [ -n "$2" ] && printf '   Generator: %s\n' "$2"
  printf '   rktasm %s: cli/as.rkt %s\n' "$commit" "$RKTASM_FLAGS"
  printf '   Regenerate: asm/regen.sh regen %s   (gates: asm/tests/ diff + BASELINE.md ±2%%)\n' "$1"
  printf '   AArch64 dual-branch: __APPLE__ = Apple/Mach-O body (%s),\n' "$RKTASM_FLAGS"
  printf '   else = ELF/GNU body (same instructions, ELF symbol syntax). */\n'
}

do_check() { # $1=kernel row → 0 pass / 1 drift
  IFS='|' read -r k gen srcs out <<< "$1"
  local tmp; tmp=$(mktemp -d)
  # 1) 生成器 → .asm 一致性（仅校验生成器实际产出的源；混入的手写源如
  #    reduce_p384.asm 不在生成器命令里，跳过——它们是 committed 手写真源）
  if [ -n "$gen" ] && [ -n "$srcs" ]; then
    local gencheck="$gen" genfiles=() genorigs=()
    for src in $srcs; do
      case "$gen" in
        *"$src"*)  # 该源确由生成器产出
          gencheck=${gencheck//$src/$tmp/$(basename "$src")}
          genfiles+=("$tmp/$(basename "$src")"); genorigs+=("$src") ;;
      esac
    done
    if [ "${#genfiles[@]}" -gt 0 ]; then
      eval "$gencheck" >/dev/null
      for i in "${!genfiles[@]}"; do
        if ! diff -q "${genfiles[$i]}" "${genorigs[$i]}" >/dev/null; then
          # 返回 2 = 生成器失配, 与 .S 分配器漂移 (返回 1) 区分:
          # KNOWN_DRIFT 白名单只豁免后者, 生成器坏了必须硬失败
          echo "DRIFT($k): generator output != committed $(basename "${genorigs[$i]}")"; rm -rf "$tmp"; return 2
        fi
      done
    fi
  fi
  # 2) .asm → .S 指令体一致性
  if [ -n "$srcs" ]; then
    assemble $srcs > "$tmp/gen.s"
  else # 直出型 (bn_fips)
    eval "${gen//__DIRECT__/$tmp/gen.s}" >/dev/null
  fi
  body "$tmp/gen.s" > "$tmp/gen.body"
  body "$out" > "$tmp/committed.body"
  if diff -q "$tmp/gen.body" "$tmp/committed.body" >/dev/null; then
    echo "PASS($k): $out reproducible"; rm -rf "$tmp"; return 0
  else
    echo "DRIFT($k): $out body differs ($(diff "$tmp/gen.body" "$tmp/committed.body" | grep -c '^[<>]') lines)"
    rm -rf "$tmp"; return 1
  fi
}

PERF_TOL=${PERF_TOL:-2}   # 允许的回归百分比（新 vs 已提交）

# 性能门禁：新 .S vs 已提交 .S 的 **A/B 交织**比较（载入免疫）。
# 刻意不与 BASELINE.md 的绝对数比——本机负载会让绝对值漂移 ±15%，制造假警报；
# 交织比值同机同时刻采样，才是"这次再生是否变慢"的可信答案。
# 指令体相同 → 性能由构造保证相同，直接跳过。
do_perf() { # $1=kernel row, $2=旧(基准) .S, $3=新 .S → 0 通过 / 1 回归 / 2 跳过
  IFS='|' read -r k _gen _srcs out <<< "$1"
  local spec flags harnesses deps
  gate_spec "$k" >/dev/null || return 2
  spec=$(gate_spec "$k"); IFS='|' read -r flags harnesses deps <<< "$spec"
  local tmp; tmp=$(mktemp -d)
  if diff -q <(body "$2") <(body "$3") >/dev/null 2>&1; then
    echo "  perf($k): 指令体与基准相同 → 性能构造性不变，跳过"; rm -rf "$tmp"; return 2
  fi
  local h binA binB rc=0
  for h in $harnesses; do
    binA="$tmp/a"; binB="$tmp/b"
    cc -O2 $flags -o "$binA" "$h" ${deps//$out/$2} 2>/dev/null || continue  # 基准
    cc -O2 $flags -o "$binB" "$h" ${deps//$out/$3} 2>/dev/null || continue  # 新
    : > "$tmp/a.txt"; : > "$tmp/b.txt"
    local i
    for i in 1 2 3 4 5; do                     # 交织采样
      "$binA" 2>/dev/null | grep '^BENCH' >> "$tmp/a.txt" || true
      "$binB" 2>/dev/null | grep '^BENCH' >> "$tmp/b.txt" || true
    done
    [ -s "$tmp/a.txt" ] || { echo "  perf($k) $(basename "$h"): 无 BENCH 输出，跳过"; continue; }
    PERF_TOL="$PERF_TOL" perl - "$tmp/a.txt" "$tmp/b.txt" "$k" "$(basename "$h")" <<'PERL' || rc=1
my ($fa,$fb,$k,$h)=@ARGV; my $tol=$ENV{PERF_TOL}||2;
sub load { my %m; open my $F,'<',$_[0] or return %m;
  while(<$F>){ next unless /^BENCH\s+(.+?):\s*([0-9.]+)/; push @{$m{$1}},$2 } %m }
sub med { my @s=sort {$a<=>$b} @{$_[0]}; $s[int(@s/2)] }
my %A=load($fa); my %B=load($fb); my $bad=0;
for my $key (sort keys %A){ next unless $B{$key};
  my ($a,$b)=(med($A{$key}),med($B{$key})); next unless $a>0;
  my $r=$b/$a; my $pct=($r-1)*100;
  if($pct > $tol){ printf("  PERF-REGRESS(%s) %s: %s  %.2f→%.2f  (+%.1f%% > %d%%)\n",$k,$h,$key,$a,$b,$pct,$tol); $bad=1 }
  else { printf("  perf(%s) %s: %-34s %.2f→%.2f  (%+.1f%%)\n",$k,$h,$key,$a,$b,$pct) } }
exit($bad?1:0);
PERL
  done
  rm -rf "$tmp"
  [ $rc -eq 0 ] && echo "  PASS-PERF($k): 无回归 (交织 A/B, 容差 ${PERF_TOL}%)"
  return $rc
}

gate_spec() { # $1=kernel → 打印 "flags|harnesses|deps"，无规格则空
  local g gk gf gh gd
  for g in "${GATE[@]}"; do
    IFS='|' read -r gk gf gh gd <<< "$g"
    [ "$gk" = "$1" ] && { printf '%s|%s|%s' "$gf" "$gh" "$gd"; return 0; }
  done
  return 1
}

# 对指定 .S 跑该内核的差分门禁（把依赖里的本内核 .S 名替换成 $2）
do_gate() { # $1=kernel row, $2=待门禁的 .S 路径 → 0 通过 / 1 失败 / 2 无规格
  IFS='|' read -r k _gen _srcs out <<< "$1"
  local spec flags harnesses deps
  if ! spec=$(gate_spec "$k"); then
    echo "NOGATE($k): 无差分门禁规格 — 须手动门禁"; return 2
  fi
  IFS='|' read -r flags harnesses deps <<< "$spec"
  # 依赖里本内核 .S → 待门禁的 .S
  local linkdeps; linkdeps=${deps//$out/$2}
  local h bin rc=0
  for h in $harnesses; do
    bin=$(mktemp)
    if ! cc -O2 $flags -o "$bin" "$h" $linkdeps 2>/dev/null; then
      echo "GATE-FAIL($k): $(basename "$h") 编译/链接失败"; rm -f "$bin"; rc=1; continue
    fi
    if "$bin" > "$bin.log" 2>&1; then
      echo "  gate($k) $(basename "$h"): PASS  [$(grep -cE 'mismatch|PASS' "$bin.log" 2>/dev/null || echo 0) 项]"
    else
      echo "GATE-FAIL($k): $(basename "$h") 差分未通过 —"; sed 's/^/    /' "$bin.log" | head -12; rc=1
    fi
    rm -f "$bin" "$bin.log"
  done
  [ $rc -eq 0 ] && echo "PASS-GATE($k): 差分门禁全绿"
  return $rc
}

# 用当前 asmp 从**已提交** .asm 源再生该内核到 $1（不跑生成器、不触碰工作树）
build_current_S() { # $1=dest, $2=kernel row
  IFS='|' read -r k gen srcs out <<< "$2"
  local tmp; tmp=$(mktemp)
  if [ -n "$srcs" ]; then
    local tmpe; tmpe=$(mktemp)
    assemble $srcs > "$tmp"           # apple 体
    assemble_elf $srcs > "$tmpe"      # ELF 体（指令逐字节同，仅符号装饰不同）
    { provenance "$k" "$gen" "$srcs" "$out"
      emit_dual "$tmp" "$tmpe" "$(elf_arch_ext "$k")"; } > "$1"
    rm -f "$tmpe"
  else   # 直出型 (bn_fips)：生成器自带 guard
    eval "${gen//__DIRECT__/$tmp}" >/dev/null
    { provenance "$k" "$gen" "$srcs" "$out"; cat "$tmp"; } > "$1"
  fi
  rm -f "$tmp"
}

do_regen() { # $1=kernel row
  IFS='|' read -r k gen srcs out <<< "$1"
  if [ -n "$gen" ] && [ -n "$srcs" ]; then eval "$gen" >/dev/null; echo "regen($k): sources refreshed"; fi
  local tmp; tmp=$(mktemp)
  if [ -n "$srcs" ]; then
    # asmp 产物体：双分支包裹（apple 体 + ELF 体）
    local tmpe; tmpe=$(mktemp)
    assemble $srcs > "$tmp"
    assemble_elf $srcs > "$tmpe"
    { provenance "$k" "$gen" "$srcs" "$out"
      emit_dual "$tmp" "$tmpe" "$(elf_arch_ext "$k")"; } > "$out"
    rm -f "$tmpe"
  else
    # 直出型 (bn_fips)：生成器自带 guard，仅前置 provenance 头
    eval "${gen//__DIRECT__/$tmp}" >/dev/null
    { provenance "$k" "$gen" "$srcs" "$out"; cat "$tmp"; } > "$out"
  fi
  rm -f "$tmp"
  echo "regen($k): wrote $out — 重提交前必须过 asm/tests/ 差分 + BASELINE.md ±2% 门禁"
}

# 把已提交单 guard .S 就地转双分支：apple 指令体逐字节保留，追加 rktasm 直出的 ELF 体。
# （KNOWN_DRIFT 内核 regen 会因性能门禁被拒——dualize 不重跑 apple 侧，故安全。）
do_dualize() { # $1=kernel row
  IFS='|' read -r k gen srcs out <<< "$1"
  [ -f "$out" ] || { echo "dualize($k): $out 不存在，跳过"; return 0; }
  local ab eb; ab=$(mktemp); eb=$(mktemp)
  # 提取已提交 apple 体：apple guard 行 与 文件末 #endif 之间（含生成器注释头）
  awk 'done{next}
       f && /^#[ \t]*endif/ {done=1; next}
       f {print}
       /^#[ \t]*if[ \t]+defined\(__aarch64__\)[ \t]*&&[ \t]*defined\(__APPLE__\)/ {f=1}' "$out" > "$ab"
  if [ ! -s "$ab" ]; then echo "dualize($k): 未找到 apple guard，$out 可能已双分支，跳过"; rm -f "$ab" "$eb"; return 0; fi
  assemble_elf $srcs > "$eb"
  { provenance "$k" "$gen" "$srcs" "$out"; emit_dual "$ab" "$eb" "$(elf_arch_ext "$k")"; } > "$out.new"
  mv "$out.new" "$out"
  rm -f "$ab" "$eb"
  echo "dualize($k): $out → 双分支（apple 体保留 + ELF 体）"
}

# 在 aarch64-linux（容器或本机）编译并运行一个差分 harness，断言 0 mismatch。
run_elf_harness() { # $1=k $2=cc额外flag $3=harness $4=链接依赖 → 0 通过 /1 失败
  local k=$1 flags=$2 h=$3 deps=$4
  local bin="/tmp/elfgate_${k}_$$"
  local build="$ELF_CC -O2 -march=$ELF_MARCH -I$ELF_SHIM $flags \"$h\" $deps -lm -o \"$bin\""
  local run="\"$bin\""
  local sh_cmd="set -e; $build; $run; rm -f \"$bin\""
  local log rc
  if [ -n "$ELF_NATIVE" ]; then
    log=$(sh -c "$sh_cmd" 2>&1); rc=$?
  else
    log=$(docker run --rm -v "$(pwd)":/work -w /work "$ELF_IMAGE" sh -c "$sh_cmd" 2>&1); rc=$?
  fi
  local mm
  mm=$(printf '%s\n' "$log" | grep -oE '[0-9]+/[0-9]+ (mismatch|mismatches)' | tail -1)
  [ -z "$mm" ] && mm=$(printf '%s\n' "$log" | grep -iE 'mismatch' | tail -1)
  if [ $rc -ne 0 ]; then
    echo "GATE-ELF-FAIL($k): $(basename "$h") rc=$rc"; printf '%s\n' "$log" | sed 's/^/    /' | tail -20
    return 1
  fi
  # 断言存在且为 0 mismatch
  if printf '%s\n' "$log" | grep -qiE '(^|[^0-9])0/[0-9]+ mismatch|0 mismatches|all .*match|PASS'; then
    echo "  gate-elf($k) $(basename "$h"): PASS  [${mm:-ok}]"
    return 0
  else
    echo "GATE-ELF-FAIL($k): $(basename "$h") 未见 0-mismatch —"; printf '%s\n' "$log" | sed 's/^/    /' | tail -20
    return 1
  fi
}

cmd=${1:-check}; want=${2:-}
case "$cmd" in
  list)
    for row in "${TABLE[@]}"; do IFS='|' read -r k _ _ out <<< "$row"; echo "  $k -> $out"; done
    echo "  不支持 (孤儿, 待 Phase A): $UNSUPPORTED" ;;
  check)
    fail=0
    for row in "${TABLE[@]}"; do
      IFS='|' read -r k _ _ _ <<< "$row"
      [ -n "$want" ] && [ "$want" != "$k" ] && continue
      rc=0; do_check "$row" || rc=$?
      if [ "$rc" -eq 2 ]; then
        echo "  (生成器与已提交 .asm 失配 → 硬失败; KNOWN_DRIFT 只豁免 .S 分配器漂移)"; fail=1
      elif [ "$rc" -ne 0 ]; then
        if [[ "$KNOWN_DRIFT" == *" $k "* ]]; then echo "  (known drift, 不计失败)"; else fail=1; fi
      fi
    done
    for k in $UNSUPPORTED; do [ -z "$want" ] && echo "SKIP($k): 无 asmp 源 (Phase A)"; done
    # 发射器静态成本回归门禁 (纯模型确定值, 无测量噪声; F3)——全内核 check 时附带
    if [ -z "$want" ]; then
      RKTASM="$RKTASM" "$RACKET" asm/gen/sched-cost.rkt --check || fail=1
    fi
    exit $fail ;;
  gate)
    # 门禁"当前 asmp 从已提交 .asm 再生"的产物（不写工作树）。
    # KNOWN_DRIFT 内核的正确性只能由此证明——check 对它们只报漂移。
    fail=0
    for row in "${TABLE[@]}"; do
      IFS='|' read -r k _ _ out <<< "$row"
      [ -n "$want" ] && [ "$want" != "$k" ] && continue
      tmpS=$(mktemp -t "${k}.XXXXXX").S
      build_current_S "$tmpS" "$row"
      set +e
      do_gate "$row" "$tmpS"; rc=$?
      [ $rc -eq 1 ] && fail=1
      # 正确性过了才谈性能（交织 A/B vs 已提交 .S）
      if [ $rc -eq 0 ]; then do_perf "$row" "$out" "$tmpS"; [ $? -eq 1 ] && fail=1; fi
      set -e
      rm -f "$tmpS"
    done
    for k in $UNSUPPORTED; do
      [ -z "$want" ] && echo "SKIP($k): 无 asmp 源 — 真源即 .S，由 test_bn 守护"
    done
    exit $fail ;;
  regen)
    [ -z "$want" ] && { echo "用法: regen.sh regen <kernel>"; exit 2; }
    for row in "${TABLE[@]}"; do
      IFS='|' read -r k _ _ out <<< "$row"
      if [ "$want" = "$k" ]; then
        prevS=$(mktemp)                    # 快照旧 .S 作性能基准（regen 会覆盖它）
        [ -f "$out" ] && cp "$out" "$prevS"
        do_regen "$row"
        # 写完立即门禁刚写下的 .S —— 让"再门禁"是强制而非纪律
        set +e
        do_gate "$row" "$out"; rc=$?
        if [ $rc -eq 0 ] && [ -s "$prevS" ]; then
          do_perf "$row" "$prevS" "$out"
          [ $? -eq 1 ] && { echo "!! regen($k): 性能回归 —— $out 已写入但**不可提交**，请回滚 (git checkout $out)"; rm -f "$prevS"; exit 1; }
        fi
        set -e; rm -f "$prevS"
        if [ $rc -eq 1 ]; then
          echo "!! regen($k): 差分门禁未通过 —— $out 已写入但**不可提交**，请回滚 (git checkout $out)"
          exit 1
        elif [ $rc -eq 2 ]; then
          echo "!! regen($k): 无门禁规格，$out 提交前须手动过 asm/tests/ 差分"
        fi
        exit 0
      fi
    done
    echo "未知或不支持的内核: $want (见 regen.sh list)"; exit 2 ;;
  dualize)
    # 把已提交 .S 就地转双分支（apple 体保留 + ELF 体）。bn_sqr 为纯手写、非 TABLE，手工维护。
    for row in "${TABLE[@]}"; do
      IFS='|' read -r k _ _ _ <<< "$row"
      [ -n "$want" ] && [ "$want" != "$k" ] && continue
      do_dualize "$row"
    done
    exit 0 ;;
  gate-elf)
    # aarch64-linux 差分门禁：逐 GATE 内核在容器(或本机)编译 ELF 分支 + harness，断言 0 mismatch。
    # 默认用 docker 镜像 $ELF_IMAGE；设 ELF_NATIVE=1 则直接本机跑（真 aarch64-linux CI，无需 Docker）。
    fail=0
    for g in "${GATE[@]}"; do
      IFS='|' read -r k flags harnesses deps <<< "$g"
      [ -n "$want" ] && [ "$want" != "$k" ] && continue
      for h in $harnesses; do
        set +e; run_elf_harness "$k" "$flags" "$h" "$deps"; [ $? -ne 0 ] && fail=1; set -e
      done
    done
    exit $fail ;;
  *) echo "用法: regen.sh {check [kernel] | gate [kernel] | regen <kernel> | dualize [kernel] | gate-elf [kernel] | list}"; exit 2 ;;
esac
