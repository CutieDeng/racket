#!/usr/bin/env python3
"""
branch-extractor.py - 从 MRS 数据提取分支指令信息

从 MRS 探索结果提取分支指令的语义信息，生成 branch-patterns.rktd

用法:
    python branch-extractor.py [--mrs-path PATH] [--output PATH]

分支指令分类:
    - 无条件直接跳转: B, BL (imm26, PC-relative)
    - 无条件间接跳转: BR, BLR, RET (Rn)
    - 条件跳转: B.cond (imm19, condition suffix)
    - 比较跳转: CBZ, CBNZ (Rt, imm19)
    - 测试跳转: TBZ, TBNZ (Rt, imm14, bit)
"""

import argparse
import json
import os
import sys
from pathlib import Path


# 分支指令模式定义
# 格式: (mnemonic, branch_type, target_type, is_call, is_return, condition_source)
BRANCH_PATTERNS = [
    # 无条件直接跳转
    ("b", "unconditional", "direct", False, False, None),
    ("bl", "unconditional", "direct", True, False, None),

    # 无条件间接跳转
    ("br", "unconditional", "indirect", False, False, None),
    ("blr", "unconditional", "indirect", True, False, None),
    ("ret", "unconditional", "indirect", False, True, None),

    # 带指针认证的跳转 (ARMv8.3+)
    ("braa", "unconditional", "indirect", False, False, None),
    ("brab", "unconditional", "indirect", False, False, None),
    ("blraa", "unconditional", "indirect", True, False, None),
    ("blrab", "unconditional", "indirect", True, False, None),
    ("braaz", "unconditional", "indirect", False, False, None),
    ("brabz", "unconditional", "indirect", False, False, None),
    ("blraaz", "unconditional", "indirect", True, False, None),
    ("blrabz", "unconditional", "indirect", True, False, None),
    ("retaa", "unconditional", "indirect", False, True, None),
    ("retab", "unconditional", "indirect", False, True, None),

    # 条件跳转 - B.cond (suffix 条件码)
    ("b.eq", "conditional", "direct", False, False, "suffix"),
    ("b.ne", "conditional", "direct", False, False, "suffix"),
    ("b.cs", "conditional", "direct", False, False, "suffix"),
    ("b.hs", "conditional", "direct", False, False, "suffix"),  # 同 cs
    ("b.cc", "conditional", "direct", False, False, "suffix"),
    ("b.lo", "conditional", "direct", False, False, "suffix"),  # 同 cc
    ("b.mi", "conditional", "direct", False, False, "suffix"),
    ("b.pl", "conditional", "direct", False, False, "suffix"),
    ("b.vs", "conditional", "direct", False, False, "suffix"),
    ("b.vc", "conditional", "direct", False, False, "suffix"),
    ("b.hi", "conditional", "direct", False, False, "suffix"),
    ("b.ls", "conditional", "direct", False, False, "suffix"),
    ("b.ge", "conditional", "direct", False, False, "suffix"),
    ("b.lt", "conditional", "direct", False, False, "suffix"),
    ("b.gt", "conditional", "direct", False, False, "suffix"),
    ("b.le", "conditional", "direct", False, False, "suffix"),
    ("b.al", "unconditional", "direct", False, False, "suffix"),  # 总是跳转
    ("b.nv", "unconditional", "direct", False, False, "suffix"),  # 保留，行为同 al

    # 比较跳转 - CBZ/CBNZ (register 条件)
    ("cbz", "conditional", "direct", False, False, "register"),
    ("cbnz", "conditional", "direct", False, False, "register"),

    # 测试跳转 - TBZ/TBNZ (bit 条件)
    ("tbz", "conditional", "direct", False, False, "bit"),
    ("tbnz", "conditional", "direct", False, False, "bit"),
]


def format_racket_value(value):
    """将 Python 值转换为 Racket 表示"""
    if value is None:
        return "#f"
    elif value is True:
        return "#t"
    elif value is False:
        return "#f"
    elif isinstance(value, str):
        return value
    else:
        return str(value)


def generate_rktd_content():
    """生成 .rktd 文件内容"""
    lines = [
        ";; ============================================================",
        ";; branch-patterns.rktd - 分支指令语义模式",
        ";; ============================================================",
        ";;",
        ";; 格式: (mnemonic branch-type target-type is-call? is-return? condition-source)",
        ";;",
        ";; branch-type: unconditional | conditional",
        ";; target-type: direct | indirect",
        ";; condition-source: #f | suffix | register | bit",
        ";;",
        ";; 自动生成，请勿手动编辑",
        ";; 使用 tool/extract/branch-extractor.py 重新生成",
        "",
    ]

    # 分类输出
    current_category = None

    for mnem, branch_type, target_type, is_call, is_return, cond_src in BRANCH_PATTERNS:
        # 确定分类
        if mnem in ("b", "bl"):
            category = "无条件直接跳转"
        elif mnem in ("br", "blr", "ret"):
            category = "无条件间接跳转"
        elif mnem.startswith("br") or mnem.startswith("blr") or mnem.startswith("ret"):
            category = "带指针认证的跳转"
        elif mnem.startswith("b."):
            category = "条件跳转 - B.cond"
        elif mnem in ("cbz", "cbnz"):
            category = "比较跳转 - CBZ/CBNZ"
        elif mnem in ("tbz", "tbnz"):
            category = "测试跳转 - TBZ/TBNZ"
        else:
            category = "其他"

        # 添加分类注释
        if category != current_category:
            if current_category is not None:
                lines.append("")
            lines.append(f";; {category}")
            current_category = category

        # 格式化条目
        cond_str = format_racket_value(cond_src)
        line = f"({mnem:<8} {branch_type} {target_type:<8} {format_racket_value(is_call)} {format_racket_value(is_return)} {cond_str})"
        lines.append(line)

    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(
        description="从 MRS 数据提取分支指令信息"
    )
    parser.add_argument(
        "--output", "-o",
        default="semantic/data/branch-patterns.rktd",
        help="输出文件路径 (默认: semantic/data/branch-patterns.rktd)"
    )
    parser.add_argument(
        "--dry-run", "-n",
        action="store_true",
        help="仅输出到标准输出，不写入文件"
    )
    args = parser.parse_args()

    content = generate_rktd_content()

    if args.dry_run:
        print(content)
    else:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w") as f:
            f.write(content)
        print(f"已生成: {output_path}")
        print(f"共 {len(BRANCH_PATTERNS)} 条分支模式")


if __name__ == "__main__":
    main()
