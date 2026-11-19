#!/usr/bin/env python3
"""Estimate a Supabase organization's monthly bill (plan fee + compute - compute credits).

Rules modelled from the Supabase docs (Manage Compute usage):
  * Compute is billed per project, per hour. Partial hours are billed as full hours.
  * Paused and deleted projects incur no compute charges.
  * On paid plans, Nano is billed at the Micro rate.
  * Paid plans get $10 of compute credits per month. Credits cover compute only
    and do not roll over.
  * The Spend Cap does NOT cover compute hours.

Prices change: always check https://supabase.com/pricing before quoting a customer.

Usage:
  python estimator/estimate.py micro micro micro
  python estimator/estimate.py --plan-fee 25 small:744 medium:300
"""
from __future__ import annotations

import argparse
import math
from dataclasses import dataclass

# Hourly prices in USD, from https://supabase.com/docs/guides/platform/manage-your-usage/compute
HOURLY_USD = {
    "nano": 0.0,
    "micro": 0.01344,
    "small": 0.0206,
    "medium": 0.0822,
    "large": 0.1517,
    "xl": 0.2877,
    "2xl": 0.562,
    "4xl": 1.32,
    "8xl": 2.562,
    "12xl": 3.836,
    "16xl": 5.12,
}

HOURS_IN_MONTH = 744          # 31-day month, as used in the Supabase docs examples
COMPUTE_CREDITS_USD = 10.0    # per paid organization, per month
PRO_PLAN_FEE_USD = 25.0


@dataclass
class ProjectUsage:
    size: str
    hours: float = HOURS_IN_MONTH

    def billed_hours(self) -> int:
        return math.ceil(self.hours)


def hourly_rate(size: str, paid_plan: bool = True) -> float:
    size = size.lower()
    if size not in HOURLY_USD:
        raise ValueError(f"Unknown compute size '{size}'. Known: {', '.join(HOURLY_USD)}")
    if size == "nano" and paid_plan:
        return HOURLY_USD["micro"]      # Nano is billed at the Micro rate on paid plans
    return HOURLY_USD[size]


def estimate(projects: list[ProjectUsage], plan_fee: float = PRO_PLAN_FEE_USD) -> dict:
    paid_plan = plan_fee > 0
    lines = []
    for i, p in enumerate(projects, start=1):
        cost = round(p.billed_hours() * hourly_rate(p.size, paid_plan), 2)
        lines.append({"project": i, "size": p.size, "hours": p.billed_hours(), "cost": cost})

    compute_total = round(sum(l["cost"] for l in lines), 2)
    credits = min(COMPUTE_CREDITS_USD, compute_total) if paid_plan else 0.0
    total = round(plan_fee + compute_total - credits, 2)
    return {
        "plan_fee": plan_fee,
        "compute_lines": lines,
        "compute_total": compute_total,
        "compute_credits": -round(credits, 2),
        "total": total,
    }


def parse_project(arg: str) -> ProjectUsage:
    if ":" in arg:
        size, hours = arg.split(":", 1)
        return ProjectUsage(size=size, hours=float(hours))
    return ProjectUsage(size=arg)


def format_estimate(result: dict) -> str:
    out = [f"{'Plan fee':<28}${result['plan_fee']:>9.2f}"]
    for l in result["compute_lines"]:
        label = f"Project {l['project']} ({l['size']}, {l['hours']} h)"
        out.append(f"{label:<28}${l['cost']:>9.2f}")
    out.append(f"{'Compute credits':<28}${result['compute_credits']:>9.2f}")
    out.append("-" * 38)
    out.append(f"{'Estimated total':<28}${result['total']:>9.2f}")
    out.append("Note: compute is not covered by the Spend Cap; usage over quota is billed separately.")
    return "\n".join(out)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("projects", nargs="+", help="compute size per project, optionally size:hours")
    parser.add_argument("--plan-fee", type=float, default=PRO_PLAN_FEE_USD,
                        help="monthly plan fee in USD (default: 25 for Pro; 0 for Free)")
    args = parser.parse_args()
    print(format_estimate(estimate([parse_project(p) for p in args.projects], args.plan_fee)))


if __name__ == "__main__":
    main()
