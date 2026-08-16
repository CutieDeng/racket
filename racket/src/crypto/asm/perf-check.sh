#!/bin/bash
# perf-check.sh — multi-group performance regression harness for the rktcrypto
# AArch64 kernels. Complements regen.sh's do_perf (which only compares a freshly
# regenerated .S against the committed .S at the same instant): this checks the
# ACTUAL measured ns/op against a PERSISTENT, per-machine baseline, in both
# directions —
#
#   NEGATIVE (regression): current slower than baseline by > REGRESS_TOL  -> FAIL
#   POSITIVE (target):     current within TARGET_MARGIN of baseline        -> the
#                          kernel still meets its known-good performance target
#   A/A control:           the same binary measured twice — the noise floor. If
#                          it exceeds REGRESS_TOL the run is too noisy to trust.
#
# The baseline is tagged with machine identity (hw.model + CPU brand + timebase
# frequency); `check` refuses a baseline recorded on a different machine, so a
# hardware swap invalidates it automatically instead of by prose (BASELINE.md's
# ns figures silently rot across machines — see its own "换机须重测全表" warning).
#
#   asm/perf-check.sh update           # (re)record baseline for THIS machine
#   asm/perf-check.sh check [group]    # measure + assert positive & negative
#   asm/perf-check.sh id               # print this machine's identity/baseline path
#
# Metric contract: harnesses print `BENCH <key>: <number> <unit>`. Each harness
# is one GROUP; keys within it are the individual kernels. Median of REPS
# interleaved reps per metric (A/A interleave fights load drift, like do_perf).

set -euo pipefail
cd "$(dirname "$0")/.."                 # crypto/ root
RKTASM=${RKTASM:-$(cd ../rktasm && pwd)}
RACKET=${RACKET:-racket}

REPS=${REPS:-7}                         # interleaved measurement reps (median)
REGRESS_TOL=${REGRESS_TOL:-6}           # negative gate: % slower-than-baseline that fails
TARGET_MARGIN=${TARGET_MARGIN:-15}      # positive gate: % band around baseline = "meets target"
BASELINE_DIR=asm/perf-baseline

# group | extra cc flags | harness .c | link deps (relative to crypto/)
BENCH_GROUPS=(
  "bn|-I..|asm/tests/test_bn.c|rktcrypto_bn_op.S rktcrypto_bn_fips.S rktcrypto_bn_sqr.S"
  "md5sha1||asm/tests/test_md5_sha1.c|rktcrypto_md5_asm.S rktcrypto_sha1_asm.S"
  "keccak||asm/tests/test_keccak.c|rktcrypto_keccak_asm.S"
  "keccak_f2||asm/tests/test_keccak_f2.c|rktcrypto_keccak_f2_asm.S"
  "ecc|-I..|asm/tests/test_ecc_mul.c|rktcrypto_ecc_asm.S rktcrypto_mont_cios_asm.S rktcrypto_bn.c rktcrypto_bn_op.S rktcrypto_bn_fips.S rktcrypto_bn_sqr.S rktcrypto_p521rr.c"
  "reduce_p384|-I..|asm/tests/test_reduce_p384.c|rktcrypto_ecc_asm.S rktcrypto_mont_cios_asm.S rktcrypto_bn.c rktcrypto_bn_op.S rktcrypto_bn_fips.S rktcrypto_bn_sqr.S rktcrypto_p521rr.c"
  "p256|-I.|asm/tests/test_p256_extra.c|rktcrypto_p256_asm.S rktcrypto_p256_hand.S rktcrypto_bn.c rktcrypto_bn_op.S rktcrypto_bn_fips.S rktcrypto_bn_sqr.S"
  "mont_cios|-I..|asm/tests/test_mont_cios.c|rktcrypto_mont_cios_asm.S"
)

machine_id() {   # stable identity string for this box
  local model brand tb
  model=$(sysctl -n hw.model 2>/dev/null || echo unknown)
  brand=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown)
  tb=$(sysctl -n hw.tbfrequency 2>/dev/null || echo 0)
  echo "${model}|${brand}|tb=${tb}"
}
machine_slug() { machine_id | tr -c 'A-Za-z0-9' '-' | sed 's/-\{1,\}/-/g;s/^-//;s/-$//'; }
baseline_file() { echo "$BASELINE_DIR/$(machine_slug).tsv"; }

# Build one group's harness, run it REPS times interleaved, print "key<TAB>median_ns".
measure_group() { # $1=group row  -> stdout: "group/key\tns" lines
  IFS='|' read -r g flags harness deps <<< "$1"
  local bin; bin=$(mktemp)
  if ! cc -O2 $flags -o "$bin" "$harness" $deps 2>/dev/null; then
    echo "BUILD-FAIL $g" >&2; rm -f "$bin"; return 1
  fi
  local raw; raw=$(mktemp)
  local i
  for i in $(seq 1 "$REPS"); do "$bin" 2>/dev/null | grep '^BENCH' >> "$raw" || true; done
  rm -f "$bin"
  # median per key. Handle both "BENCH name: v unit" and "BENCH name (annot): v unit"
  # by taking everything before the first ':' as the key and the first number after.
  awk -v G="$g" '
    /^BENCH/ { line=$0; sub(/^BENCH[ \t]+/,"",line);
               ci=index(line,":"); if(ci==0) next;
               key=substr(line,1,ci-1); gsub(/[ \t]+/,"_",key); gsub(/[(),]/,"",key);
               rest=substr(line,ci+1); nf=split(rest,ar," "); val=ar[1]+0;
               if(val<=0) next;
               n[key]++; v[key,n[key]]=val }
    END { for (k in n) { c=n[k];
            for(a=1;a<=c;a++){ for(b=a+1;b<=c;b++){ if(v[k,b]<v[k,a]){t=v[k,a];v[k,a]=v[k,b];v[k,b]=t} } }
            m=v[k,int((c+1)/2)]; printf "%s/%s\t%.3f\n", G, k, m } }' "$raw"
  rm -f "$raw"
}

# A/A noise floor for a group: two independent median passes, max |Δ%| over keys.
aa_control() { # $1=group row -> stdout: "group\tmaxpct"
  IFS='|' read -r g _ _ _ <<< "$1"
  local a b; a=$(measure_group "$1"); b=$(measure_group "$1")
  paste <(echo "$a") <(echo "$b") | awk -v G="$g" '
    { split($1,ka,"/"); v1=$2; v2=$4; if(v1>0){ d=(v2/v1-1)*100; if(d<0)d=-d; if(d>mx)mx=d } }
    END { printf "%s\t%.2f\n", G, mx+0 }'
}

want=${2:-}
cmd=${1:-check}
case "$cmd" in
  id)
    echo "machine: $(machine_id)"
    echo "baseline: $(baseline_file)"
    [ -f "$(baseline_file)" ] && echo "status: present" || echo "status: ABSENT (run: asm/perf-check.sh update)"
    ;;
  update)
    mkdir -p "$BASELINE_DIR"
    bf=$(baseline_file); tmp=$(mktemp)
    { echo "# machine: $(machine_id)"
      echo "# recorded by perf-check.sh update; ns/op median of $REPS reps"; } > "$tmp"
    for row in "${BENCH_GROUPS[@]}"; do
      IFS='|' read -r g _ _ _ <<< "$row"
      if [ -n "$want" ] && [ "$want" != "$g" ]; then continue; fi
      echo "measuring $g ..." >&2
      measure_group "$row" >> "$tmp" || { echo "  (skip $g: build failed)" >&2; continue; }
    done
    mv "$tmp" "$bf"
    echo "wrote $bf"; grep -v '^#' "$bf" | sort
    ;;
  check)
    bf=$(baseline_file)
    if [ ! -f "$bf" ]; then echo "No baseline for this machine ($(machine_id)). Run: asm/perf-check.sh update"; exit 2; fi
    # machine guard
    want_id=$(machine_id); have_id=$(grep '^# machine:' "$bf" | sed 's/^# machine: //')
    if [ "$want_id" != "$have_id" ]; then
      echo "BASELINE MACHINE MISMATCH"; echo "  baseline: $have_id"; echo "  current : $want_id"
      echo "  -> run 'asm/perf-check.sh update' on this machine"; exit 2
    fi
    # bash 3.2 (macOS default) has no associative arrays — look keys up in the file.
    base_lookup() { awk -F'\t' -v k="$1" '$1==k{print $2; exit}' "$bf"; }
    fail=0; npos=0; nneg=0
    printf '%-34s %10s %10s %8s  %-4s %-4s\n' "metric" "baseline" "current" "Δ%" "neg" "pos"
    for row in "${BENCH_GROUPS[@]}"; do
      IFS='|' read -r g _ _ _ <<< "$row"
      if [ -n "$want" ] && [ "$want" != "$g" ]; then continue; fi
      # A/A noise floor for this group
      aa=$(aa_control "$row" 2>/dev/null | cut -f2 || echo "?")
      cur=$(measure_group "$row" 2>/dev/null) || { echo "BUILD-FAIL($g)"; fail=1; continue; }
      awk_noise="$aa"
      while IFS=$'\t' read -r key val; do
        b=$(base_lookup "$key")
        if [ -z "$b" ]; then printf '%-34s %10s %10.3f %8s  %-4s %-4s (no baseline key)\n' "$key" "-" "$val" "-" "-" "-"; continue; fi
        pct=$(awk -v c="$val" -v b="$b" 'BEGIN{printf "%.2f",(c/b-1)*100}')
        neg=$(awk -v c="$val" -v b="$b" -v t="$REGRESS_TOL" 'BEGIN{print (c> b*(1+t/100))?"FAIL":"ok"}')
        pos=$(awk -v c="$val" -v b="$b" -v m="$TARGET_MARGIN" 'BEGIN{print (c<=b*(1+m/100))?"ok":"MISS"}')
        [ "$neg" = "FAIL" ] && { fail=1; nneg=$((nneg+1)); }
        [ "$pos" = "MISS" ] && { fail=1; npos=$((npos+1)); }
        printf '%-34s %10.3f %10.3f %+8s  %-4s %-4s\n' "$key" "$b" "$val" "$pct" "$neg" "$pos"
      done <<< "$cur"
      printf '   %-30s A/A noise floor: %s%% (tol %s%%)\n' "[$g]" "$aa" "$REGRESS_TOL"
    done
    echo "----"
    if [ $fail -eq 0 ]; then echo "PERF OK — no regression (neg) and all targets met (pos), tol ${REGRESS_TOL}% / margin ${TARGET_MARGIN}%";
    else echo "PERF FAIL — $nneg regression(s), $npos missed target(s)"; fi
    exit $fail ;;
  *) echo "usage: perf-check.sh {update [group] | check [group] | id}"; exit 2 ;;
esac
