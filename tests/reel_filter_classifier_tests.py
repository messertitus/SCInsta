#!/usr/bin/env python3
"""Deterministic tests for the pure Reel classifier marker rules."""

from __future__ import annotations


def normalized_marker(value: object) -> str | None:
    if not isinstance(value, str):
        return None
    return value.strip().lower()


def is_exact_reel_product_type(value: object) -> bool:
    normalized = normalized_marker(value)
    return normalized in {"clips", "reels", "reel", "sundial"}


def has_clips_or_sundial_marker(value: object) -> bool:
    normalized = normalized_marker(value)
    return normalized is not None and ("clips" in normalized or "sundial" in normalized)


def metadata_looks_like_clips(value: object) -> bool:
    if value is None:
        return False
    if isinstance(value, dict):
        return any(isinstance(key, str) and has_clips_or_sundial_marker(key) for key in value)
    return has_clips_or_sundial_marker(type(value).__name__)


def assert_case(name: str, actual: bool, expected: bool) -> None:
    if actual != expected:
        raise AssertionError(f"{name}: expected {expected}, got {actual}")


class ClipsMetadata:
    pass


class OrdinaryVideoMetadata:
    pass


def main() -> None:
    assert_case("clips product type", is_exact_reel_product_type("clips"), True)
    assert_case("reels product type", is_exact_reel_product_type(" Reels "), True)
    assert_case("ordinary feed product type", is_exact_reel_product_type("feed"), False)
    assert_case("generic class reel substring ignored", has_clips_or_sundial_marker("IGStoryReelTrayItem"), False)
    assert_case("clips class marker", has_clips_or_sundial_marker("IGClipsMedia"), True)
    assert_case("sundial class marker", has_clips_or_sundial_marker("IGSundialMedia"), True)
    assert_case("metadata key marker", metadata_looks_like_clips({"clips_metadata": object()}), True)
    assert_case("ordinary metadata object", metadata_looks_like_clips(OrdinaryVideoMetadata()), False)
    assert_case("metadata class marker", metadata_looks_like_clips(ClipsMetadata()), True)


if __name__ == "__main__":
    main()
