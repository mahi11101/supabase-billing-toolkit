import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "estimator"))
from estimate import ProjectUsage, estimate, hourly_rate  # noqa: E402


def test_three_micro_projects_on_pro_matches_docs_example():
    # Supabase docs: Pro $25 + 3 Micro projects $30 - $10 credits = $45
    result = estimate([ProjectUsage("micro")] * 3)
    assert result["compute_total"] == 30.0
    assert result["total"] == 45.0


def test_one_micro_project_costs_only_the_plan_fee():
    assert estimate([ProjectUsage("micro")])["total"] == 25.0


def test_partial_hours_are_billed_as_full_hours():
    result = estimate([ProjectUsage("micro", hours=10.2)])
    assert result["compute_lines"][0]["hours"] == 11


def test_nano_billed_at_micro_rate_on_paid_plans():
    assert hourly_rate("nano", paid_plan=True) == hourly_rate("micro")
    assert hourly_rate("nano", paid_plan=False) == 0.0


def test_credits_never_exceed_compute():
    result = estimate([ProjectUsage("micro", hours=100)])
    assert result["compute_credits"] == -result["compute_total"]
    assert result["total"] == 25.0


def test_free_plan_gets_no_credits():
    result = estimate([ProjectUsage("nano")], plan_fee=0)
    assert result["compute_credits"] == 0
    assert result["total"] == 0


def test_unknown_size_raises():
    with pytest.raises(ValueError):
        hourly_rate("huge")
