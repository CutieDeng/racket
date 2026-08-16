#!/usr/bin/env python3
"""
alias-extractor.py
从 MRS Instructions.json 自动提取别名信息，生成:
  - alias-signatures.rktd   (别名签名)
  - alias-transforms.rktd   (别名转换规则)

处理两类别名:
1. optional_shift: 同一指令省略尾部 shift 操作数 (如 AND X0, X0, X1 省略 LSL #0)
2. InstructionAlias: 不同助记符映射到基础指令 (如 MOV → ORR, CMP → SUBS)

使用方法:
  python3 tool/extract/alias-extractor.py
"""

import json
import re
import sys
from collections import defaultdict

# ============================================================
# 配置
# ============================================================

MRS_PATH = "AARCHMRS_OPENSOURCE_A_profile_FAT-2025-12/Instructions.json"
SPEC_PATH = "syntax/data/generated/instruction-spec.rktd"
SIG_OUTPUT = "syntax/data/alias-signatures.rktd"
TRANSFORM_OUTPUT = "syntax/data/alias-transforms.rktd"

# ============================================================
# S-expression 最小解析器 (用于读取 instruction-spec.rktd)
# ============================================================

def tokenize_sexp(text):
    """将 s-expression 文本分词"""
    tokens = []
    i = 0
    while i < len(text):
        c = text[i]
        if c in ' \t\n\r':
            i += 1
        elif c == ';':
            # 跳过注释
            while i < len(text) and text[i] != '\n':
                i += 1
        elif c == '(':
            tokens.append('(')
            i += 1
        elif c == ')':
            tokens.append(')')
            i += 1
        elif c == '"':
            # 字符串
            j = i + 1
            while j < len(text) and text[j] != '"':
                if text[j] == '\\':
                    j += 1
                j += 1
            tokens.append(text[i:j+1])
            i = j + 1
        else:
            # 符号/数字
            j = i
            while j < len(text) and text[j] not in ' \t\n\r();"':
                j += 1
            tokens.append(text[i:j])
            i = j
    return tokens

def parse_sexp(tokens, pos=0):
    """解析一个 s-expression，返回 (value, next_pos)"""
    if pos >= len(tokens):
        return None, pos
    tok = tokens[pos]
    if tok == '(':
        lst = []
        pos += 1
        while pos < len(tokens) and tokens[pos] != ')':
            val, pos = parse_sexp(tokens, pos)
            if val is not None:
                lst.append(val)
        if pos < len(tokens):
            pos += 1  # skip ')'
        return lst, pos
    elif tok == ')':
        return None, pos + 1
    elif tok.startswith('"'):
        return tok[1:-1], pos + 1  # strip quotes
    else:
        return tok, pos + 1

def parse_all_sexps(text):
    """解析文本中所有顶层 s-expression"""
    tokens = tokenize_sexp(text)
    results = []
    pos = 0
    while pos < len(tokens):
        val, pos = parse_sexp(tokens, pos)
        if val is not None:
            results.append(val)
    return results

# ============================================================
# 加载数据
# ============================================================

def load_mrs(path):
    with open(path) as f:
        return json.load(f)

def load_spec(path):
    """加载 instruction-spec.rktd，返回 [(enc_id, mnem, template, constraints), ...]"""
    with open(path) as f:
        text = f.read()
    return parse_all_sexps(text)

# ============================================================
# 从 instruction-spec 解析签名
# (与 Racket operand-type.rkt / classify-template-part 保持一致)
# ============================================================

def classify_template_part(part):
    """分类单个模板部分 (对应 Racket classify-template-part)"""
    trimmed = part.strip()
    if not trimmed:
        return 'unknown'

    # Pre-index
    if trimmed == '!':
        return 'pre-index'
    # Memory [...]
    if trimmed.startswith('['):
        return 'memory'
    # Register list {...}
    if trimmed.startswith('{'):
        return 'reg-list'
    # 64-bit GPR: XZR, XUInteger, SP, X16
    if re.match(r'^X(ZR|UInteger|[0-9]+)', trimmed) or trimmed == 'SP':
        return 'gpr-64'
    # 32-bit GPR: WZR, WUInteger, WSP
    if re.match(r'^W(ZR|UInteger|SP|[0-9]+)', trimmed) or trimmed == 'WSP':
        return 'gpr-32'
    # SIMD element: VUInteger[...]
    if re.match(r'^V\s*UInteger\[', trimmed):
        return 'simd-element'
    # SIMD scalar: BUInteger, HUInteger, SUInteger, DUInteger, QUInteger
    if re.match(r'^[BHSDQ]UInteger$', trimmed):
        return 'simd-scalar'
    # SIMD vector: VUInteger.xxx
    if re.match(r'^V\s*UInteger\.', trimmed):
        return 'simd-vector'
    # SME ZT register
    if re.match(r'^ZT[0-9]', trimmed):
        return 'sme-zt'
    # SVE Z register: ZUInteger
    if re.match(r'^Z\s*UInteger', trimmed):
        return 'sve-z'
    # SVE PN predicate: PNUInteger
    if re.match(r'^PN\s*UInteger', trimmed):
        return 'sve-pn'
    # SVE P predicate: PUInteger
    if re.match(r'^P\s*UInteger', trimmed):
        return 'sve-p'
    # SME ZA
    if trimmed.startswith('ZA'):
        return 'sme-za'
    # Float constant
    if trimmed == 'Real' or re.match(r'^[0-9]+\.[0-9]+$', trimmed):
        return 'float-const'
    # Immediate: UInteger, SInteger, numeric
    if re.match(r'^[US]Integer', trimmed) or re.match(r'^-?[0-9]+$', trimmed):
        return 'immediate'
    # Barrier options
    if trimmed in ('SY', 'CSYNC', 'DSYNC', 'SYnXS',
                   'ISH', 'ISHLD', 'ISHST', 'OSH', 'OSHLD', 'OSHST',
                   'NSH', 'NSHLD', 'NSHST', 'LD', 'ST'):
        return 'barrier-option'
    # Vector length
    if re.match(r'^VLx[0-9]+', trimmed):
        return 'vector-length'
    # Prefetch
    if re.match(r'^P(LD|LI|ST)L[123](KEEP|STRM)$', trimmed):
        return 'prefetch-op'
    if trimmed in ('KEEP', 'STRM', 'PLDKEEP', 'PSTKEEP', 'PLIKEEP'):
        return 'prefetch-op'
    # Keywords: shift/extend
    if trimmed in ('LSL', 'LSR', 'ASR', 'ROR', 'MSL',
                   'UXTB', 'UXTH', 'UXTW', 'UXTX',
                   'SXTB', 'SXTH', 'SXTW', 'SXTX',
                   'MUL', 'VL'):
        return 'keyword'
    # Condition codes
    if trimmed in ('EQ', 'NE', 'CS', 'HS', 'CC', 'LO', 'MI', 'PL',
                   'VS', 'VC', 'HI', 'LS', 'GE', 'LT', 'GT', 'LE', 'AL', 'NV'):
        return 'cond-code'
    # System registers
    if re.match(r'^(UAO|PAN|DIT|SSBS|TCO|SVCRSM|SVCRZA|SVCRSMZA)', trimmed):
        return 'system-reg'
    if re.match(r'^CUInteger', trimmed):
        return 'system-reg'

    return 'unknown'

def split_template(template):
    """按逗号分割模板，尊重括号"""
    parts = []
    current = []
    depth = 0
    brace_depth = 0
    for c in template:
        if c == '[':
            depth += 1
            current.append(c)
        elif c == ']':
            depth -= 1
            current.append(c)
        elif c == '{':
            brace_depth += 1
            current.append(c)
        elif c == '}':
            brace_depth -= 1
            current.append(c)
        elif c == ',' and depth == 0 and brace_depth == 0:
            if current:
                parts.append(''.join(current).strip())
            current = []
        else:
            current.append(c)
    if current:
        parts.append(''.join(current).strip())
    return parts

def parse_template_signature(template):
    """从模板字符串解析操作数类型签名 (与 Racket 一致)"""
    if not template or not template.strip():
        return []
    parts = split_template(template.strip())
    return [classify_template_part(p) for p in parts]

# ============================================================
# Part 1: optional_shift 提取
# ============================================================

def find_instruction_nodes(node):
    """递归查找所有 Instruction.Instruction 节点"""
    results = []
    if isinstance(node, dict):
        if node.get('_type') == 'Instruction.Instruction':
            results.append(node)
        for v in node.values():
            results.extend(find_instruction_nodes(v))
    elif isinstance(node, list):
        for v in node:
            results.extend(find_instruction_nodes(v))
    return results

def extract_optional_shift_aliases(mrs_data, specs):
    """提取 optional_shift 别名: 省略尾部 (keyword, immediate) 的短形式"""
    # 1. 从 MRS 找到所有含 optional_shift 的编码名
    all_instructions = find_instruction_nodes(mrs_data)
    shift_encodings = []  # [(enc_name, rule_id)]

    for inst in all_instructions:
        name = inst.get('name', '')
        asm = inst.get('assembly', {})
        if not isinstance(asm, dict):
            continue
        symbols = asm.get('symbols', [])
        for sym in symbols:
            if isinstance(sym, dict):
                rid = sym.get('rule_id', '')
                if rid.startswith('optional_shift'):
                    shift_encodings.append((name, rid))
                    break

    print(f"  optional_shift 编码数: {len(shift_encodings)}")

    # 2. 从 spec 获取签名
    sig_map = {}  # enc_id -> (mnem, sig)
    for spec in specs:
        if len(spec) >= 3:
            enc_id = spec[0]
            mnem = spec[1]
            template = spec[2]
            sig = parse_template_signature(template)
            sig_map[enc_id] = (mnem, sig)

    # 3. 对每个含 optional_shift 的编码，检查签名是否有 shift 后缀
    by_mnem = defaultdict(list)  # mnem -> [(class, short_sig)]
    transforms = defaultdict(list)  # mnem -> [(class, short_sig, target_mnem, rule)]

    for enc_name, _ in shift_encodings:
        info = sig_map.get(enc_name)
        if not info:
            continue
        mnem, full_sig = info

        # 检查末尾是否是 (keyword, immediate)
        if len(full_sig) >= 2 and full_sig[-2] == 'keyword' and full_sig[-1] == 'immediate':
            short_sig = full_sig[:-2]
            n = len(short_sig)

            # 计算 Layer1 class
            cls = classify_operand_count(short_sig)

            key = (mnem, cls, tuple(short_sig))
            entry = (cls, short_sig)
            transform = (cls, short_sig, mnem, list(range(n)) + [('const', 'lsl'), ('const', 0)])

            if entry not in by_mnem[mnem]:
                by_mnem[mnem].append(entry)
            if transform not in transforms[mnem]:
                transforms[mnem].append(transform)

    print(f"  optional_shift 助记符数: {len(by_mnem)}")
    return dict(by_mnem), dict(transforms)

# ============================================================
# Part 2: InstructionAlias 提取
# ============================================================

def find_alias_nodes(node):
    """递归查找所有 InstructionAlias 节点"""
    results = []
    if isinstance(node, dict):
        if node.get('_type') == 'Instruction.InstructionAlias':
            results.append(node)
        for v in node.values():
            results.extend(find_alias_nodes(v))
    elif isinstance(node, list):
        for v in node:
            results.extend(find_alias_nodes(v))
    return results

def rule_id_to_gpr_size(rule_id):
    """从 rule_id 判断寄存器位宽: 32 或 64"""
    if any(p in rule_id for p in ['Wd', 'Wn', 'Wm', 'WSP', 'Wsp']):
        return 32
    if any(p in rule_id for p in ['Xd', 'Xn', 'Xm', 'XSP', 'Xsp', 'XnSP', 'XdSP']):
        return 64
    return None

def is_gpr_rule(rule_id):
    """判断 rule_id 是否是 GPR 类操作数"""
    gpr_patterns = [
        'WdOrWZR', 'WnOrWZR', 'WmOrWZR', 'WdWSP', 'WnWSP',
        'XdOrXZR', 'XnOrXZR', 'XmOrXZR', 'XdSP', 'XnSP', 'XdOrSP',
    ]
    for pat in gpr_patterns:
        if rule_id.startswith(pat):
            return True
    return False

def is_imm_rule(rule_id):
    """判断 rule_id 是否是 immediate 类操作数"""
    return rule_id.startswith('imm') or rule_id.startswith('hw_imm')

def parse_condition_pinned_fields(cond):
    """从 condition AST 提取固定字段: {field_name: value}"""
    if not isinstance(cond, dict):
        return {}

    op = cond.get('op', '')

    if op == '==':
        left = cond.get('left', {})
        right = cond.get('right', {})
        if isinstance(left, dict) and left.get('_type') == 'AST.Identifier':
            field = left['value']
            if isinstance(right, dict) and right.get('_type') == 'Values.Value':
                val = right['value']
                return {field: val}
        return {}

    if op == '&&':
        left_pins = parse_condition_pinned_fields(cond.get('left', {}))
        right_pins = parse_condition_pinned_fields(cond.get('right', {}))
        left_pins.update(right_pins)
        return left_pins

    return {}

def extract_alias_operands(alias_node):
    """从 alias 节点提取操作数信息: [(type, rule_id), ...]"""
    symbols = alias_node.get('assembly', {}).get('symbols', [])
    operands = []
    prev_is_hash = False

    for sym in symbols:
        if not isinstance(sym, dict):
            continue
        rule_id = sym.get('rule_id', '')
        value = sym.get('value', '')

        # 跳过装饰性 token
        if rule_id in ('SPACE', 'COMMA', '') and not value:
            continue
        if sym.get('_type') == 'Instruction.Symbols.Literal':
            continue
        if rule_id == 'hash':
            prev_is_hash = True
            continue

        # GPR 操作数
        if is_gpr_rule(rule_id):
            size = rule_id_to_gpr_size(rule_id)
            if size:
                operands.append((f'gpr-{size}', rule_id))
            prev_is_hash = False
            continue

        # Immediate 操作数 (跟在 hash 后)
        if prev_is_hash and is_imm_rule(rule_id):
            operands.append(('immediate', rule_id))
            prev_is_hash = False
            continue

        # optional_shift / optional_extend → 跳过 (这些是可选后缀)
        if rule_id.startswith('optional_'):
            prev_is_hash = False
            continue

        prev_is_hash = False

    return operands

# 定义 InstructionAlias 到基础指令的映射规则
# key: operation_id 的 pattern (alias_target_class)
# value: (target_mnem, condition_type, has_optional_shift)
#   condition_type: 'rd_zr' = Rd is zero register
#                   'rn_zr' = Rn is zero register
#                   'rn_zr_shift0' = Rn is zero register + shift/imm forced to 0

ALIAS_DEFINITIONS = {
    # MOV (register) → ORR Rd, WZR, Rm (Rn=ZR, shift=0, imm6=0)
    'MOV_ORR_log_shift': {
        'target': 'orr',
        'build_transform': lambda ops, size: (
            [0, ('zr', size), 1, ('const', 'lsl'), ('const', 0)]
        ),
    },
    # MOV (SP) → ADD Rd, Rn, #0
    'MOV_ADD_addsub_imm': {
        'target': 'add',
        'build_transform': lambda ops, size: (
            [0, 1, ('const', 0)]
        ),
    },
    # CMP (register) → SUBS ZR, Rn, Rm (Rd=ZR)
    'CMP_SUBS_addsub_shift': {
        'target': 'subs',
        'build_transform': lambda ops, size: (
            [('zr', size), 0, 1, ('const', 'lsl'), ('const', 0)]
        ),
    },
    # CMP (immediate) → SUBS ZR, Rn, #imm (Rd=ZR)
    'CMP_SUBS_addsub_imm': {
        'target': 'subs',
        'build_transform': lambda ops, size: (
            [('zr', size), 0, 1]
        ),
    },
    # CMN (register) → ADDS ZR, Rn, Rm (Rd=ZR)
    'CMN_ADDS_addsub_shift': {
        'target': 'adds',
        'build_transform': lambda ops, size: (
            [('zr', size), 0, 1, ('const', 'lsl'), ('const', 0)]
        ),
    },
    # CMN (immediate) → ADDS ZR, Rn, #imm (Rd=ZR)
    'CMN_ADDS_addsub_imm': {
        'target': 'adds',
        'build_transform': lambda ops, size: (
            [('zr', size), 0, 1]
        ),
    },
    # TST (register) → ANDS ZR, Rn, Rm (Rd=ZR)
    'TST_ANDS_log_shift': {
        'target': 'ands',
        'build_transform': lambda ops, size: (
            [('zr', size), 0, 1, ('const', 'lsl'), ('const', 0)]
        ),
    },
    # TST (immediate) → ANDS ZR, Rn, #imm (Rd=ZR)
    'TST_ANDS_log_imm': {
        'target': 'ands',
        'build_transform': lambda ops, size: (
            [('zr', size), 0, 1]
        ),
    },
    # NEG → SUB Rd, ZR, Rm (Rn=ZR)
    'NEG_SUB_addsub_shift': {
        'target': 'sub',
        'build_transform': lambda ops, size: (
            [0, ('zr', size), 1, ('const', 'lsl'), ('const', 0)]
        ),
    },
    # NEGS → SUBS Rd, ZR, Rm (Rn=ZR)
    'NEGS_SUBS_addsub_shift': {
        'target': 'subs',
        'build_transform': lambda ops, size: (
            [0, ('zr', size), 1, ('const', 'lsl'), ('const', 0)]
        ),
    },
    # MVN → ORN Rd, ZR, Rm (Rn=ZR)
    'MVN_ORN_log_shift': {
        'target': 'orn',
        'build_transform': lambda ops, size: (
            [0, ('zr', size), 1, ('const', 'lsl'), ('const', 0)]
        ),
    },
    # NGC → SBC Rd, ZR, Rm (Rn=ZR, no shift)
    'NGC_SBC': {
        'target': 'sbc',
        'build_transform': lambda ops, size: (
            [0, ('zr', size), 1]
        ),
    },
    # NGCS → SBCS Rd, ZR, Rm (Rn=ZR, no shift)
    'NGCS_SBCS': {
        'target': 'sbcs',
        'build_transform': lambda ops, size: (
            [0, ('zr', size), 1]
        ),
    },
}

def alias_sort_key(alias):
    """排序 InstructionAlias，优先处理 _shift/_log_shift 变体"""
    opid = alias.get('operation_id', '')
    # _log_shift 和 _addsub_shift 优先 (标准寄存器形式)
    if '_log_shift' in opid or '_addsub_shift' in opid:
        return (0, opid)
    # _log_imm 和 _addsub_imm 次优先 (立即数形式)
    if '_log_imm' in opid or '_addsub_imm' in opid:
        return (1, opid)
    # 其他
    return (2, opid)

def extract_instruction_aliases(mrs_data):
    """提取 InstructionAlias 别名"""
    all_aliases = find_alias_nodes(mrs_data)
    print(f"  InstructionAlias 总数: {len(all_aliases)}")

    by_mnem = defaultdict(list)  # mnem -> [(class, sig)]
    transforms = defaultdict(list)  # mnem -> [(class, sig, target_mnem, rule)]

    processed = set()

    # 排序: _shift 变体优先于 _imm 变体
    all_aliases.sort(key=alias_sort_key)

    for alias in all_aliases:
        opid = alias.get('operation_id', '')
        name = alias.get('name', '').lower()

        # 只处理已定义的别名映射
        if opid not in ALIAS_DEFINITIONS:
            continue

        defn = ALIAS_DEFINITIONS[opid]

        # 提取操作数
        operands = extract_alias_operands(alias)
        if not operands:
            continue

        # 确定寄存器位宽
        gpr_sizes = [int(t.split('-')[1]) for t, _ in operands if t.startswith('gpr-')]
        if not gpr_sizes:
            continue
        size = gpr_sizes[0]  # 取第一个 GPR 的大小

        sig = [t for t, _ in operands]
        cls = classify_operand_count(sig)

        # 去重
        key = (name, cls, tuple(sig))
        if key in processed:
            continue
        processed.add(key)

        # 构建转换规则
        target = defn['target']
        rule = defn['build_transform'](operands, size)

        entry = (cls, sig)
        transform = (cls, sig, target, rule)

        by_mnem[name].append(entry)
        transforms[name].append(transform)

    print(f"  InstructionAlias 助记符数: {len(by_mnem)}")
    return dict(by_mnem), dict(transforms)

# ============================================================
# 公共函数
# ============================================================

def classify_operand_count(sig):
    """根据操作数签名计算 Layer1 class"""
    if isinstance(sig, list):
        types = sig
    else:
        types = list(sig)

    has_mem = 'memory' in types
    if has_mem:
        mem_idx = types.index('memory')
        pre = mem_idx
        post = len(types) - mem_idx - 1
    else:
        pre = len(types)
        post = 0

    # 与 Racket classify-operand-count 一致
    if has_mem:
        if pre == 0 and post == 0:
            return 'cm0'
        elif pre == 1 and post == 0:
            return 'cm1'
        elif pre == 2 and post == 0:
            return 'cm2'
        elif pre == 0 and post == 1:
            return 'c0m1'
        elif pre == 1 and post == 1:
            return 'c1m1'
        elif pre == 0 and post == 2:
            return 'c0m2'
        elif pre == 1 and post == 2:
            return 'c1m2'
        else:
            return f'c{pre}m{post}'
    else:
        return f'c{pre}'

# ============================================================
# 输出
# ============================================================

def format_sig(sig):
    """格式化签名为 s-expression"""
    return '(' + ' '.join(sig) + ')'

def format_transform_element(elem):
    """格式化转换规则元素"""
    if isinstance(elem, int):
        return str(elem)
    elif isinstance(elem, tuple):
        return f'({elem[0]} {elem[1]})'
    else:
        return str(elem)

def format_transform_rule(rule):
    """格式化转换规则"""
    return '(' + ' '.join(format_transform_element(e) for e in rule) + ')'

def write_signatures(by_mnem, output_path):
    """写入 alias-signatures.rktd"""
    with open(output_path, 'w') as f:
        f.write(";; ============================================================\n")
        f.write(";; alias-signatures.rktd - 自动生成的别名签名\n")
        f.write(";; 来源: MRS InstructionAlias + optional_shift\n")
        f.write(";; 生成命令: python3 tool/extract/alias-extractor.py\n")
        f.write(";; ============================================================\n\n")

        for mnem in sorted(by_mnem.keys()):
            entries = by_mnem[mnem]
            f.write(f"({mnem}\n")
            f.write(f"  (")
            for i, (cls, sig) in enumerate(entries):
                if i > 0:
                    f.write(f"\n   ")
                f.write(f"({cls} {format_sig(sig)})")
            f.write(f"))\n\n")

    print(f"已保存签名: {output_path} ({len(by_mnem)} 个助记符)")

def write_transforms(transforms, output_path):
    """写入 alias-transforms.rktd"""
    with open(output_path, 'w') as f:
        f.write(";; ============================================================\n")
        f.write(";; alias-transforms.rktd - 自动生成的别名转换规则\n")
        f.write(";; 来源: MRS InstructionAlias + optional_shift\n")
        f.write(";; 生成命令: python3 tool/extract/alias-extractor.py\n")
        f.write(";; ============================================================\n\n")

        for mnem in sorted(transforms.keys()):
            entries = transforms[mnem]
            f.write(f"({mnem}\n")
            for cls, sig, target, rule in entries:
                f.write(f"  (({cls} {format_sig(sig)})  {target}  {format_transform_rule(rule)})\n")
            f.write(f")\n\n")

    print(f"已保存转换: {output_path} ({len(transforms)} 个助记符)")

# ============================================================
# 合并
# ============================================================

def merge_aliases(dict1, dict2):
    """合并两个别名字典"""
    merged = defaultdict(list)
    for d in [dict1, dict2]:
        for mnem, entries in d.items():
            for entry in entries:
                if entry not in merged[mnem]:
                    merged[mnem].append(entry)
    return dict(merged)

# ============================================================
# 主程序
# ============================================================

def main():
    import argparse
    parser = argparse.ArgumentParser(description='Extract alias data from MRS')
    parser.add_argument('-m', '--mrs', default=MRS_PATH, help='MRS Instructions.json path')
    parser.add_argument('-s', '--spec', default=SPEC_PATH, help='instruction-spec.rktd path')
    parser.add_argument('--sig-out', default=SIG_OUTPUT, help='Output alias-signatures.rktd')
    parser.add_argument('--transform-out', default=TRANSFORM_OUTPUT, help='Output alias-transforms.rktd')
    args = parser.parse_args()

    print("加载 MRS 数据...")
    mrs_data = load_mrs(args.mrs)

    print("加载指令规范...")
    specs = load_spec(args.spec)
    print(f"  spec 记录数: {len(specs)}")

    print("\n提取 optional_shift 别名...")
    shift_sigs, shift_transforms = extract_optional_shift_aliases(mrs_data, specs)

    print("\n提取 InstructionAlias 别名...")
    alias_sigs, alias_transforms = extract_instruction_aliases(mrs_data)

    print("\n合并结果...")
    all_sigs = merge_aliases(shift_sigs, alias_sigs)
    all_transforms = merge_aliases(shift_transforms, alias_transforms)

    total_entries = sum(len(v) for v in all_sigs.values())
    print(f"  总计: {len(all_sigs)} 个助记符, {total_entries} 条签名")

    print("\n写入输出文件...")
    write_signatures(all_sigs, args.sig_out)
    write_transforms(all_transforms, args.transform_out)

    print("\n完成!")

if __name__ == '__main__':
    main()
