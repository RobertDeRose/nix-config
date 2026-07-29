#!/usr/bin/env python3
"""Root-owned Maison deployment transaction path contract.

This module is intentionally small and stdlib-only. The deployment scripts use
it to keep repository transaction state outside the managed user's writable
home while preserving a same-filesystem transaction boundary.
"""

from __future__ import annotations

import hashlib
import os
import secrets
import stat
from dataclasses import dataclass
from pathlib import Path


class DeploymentTransactionError(ValueError):
    """Raised when deployment transaction paths violate the safety contract."""


@dataclass(frozen=True, slots=True)
class TransactionPaths:
    """Concrete paths for one deployment transaction."""

    root: Path
    transaction_id: str
    transaction_dir: Path
    staging_dir: Path
    rollback_dir: Path
    journal_path: Path
    lock_path: Path


def repo_hash(repo_path: Path) -> str:
    """Return a stable non-secret namespace hash for a repository path."""

    return hashlib.sha256(str(repo_path).encode("utf-8")).hexdigest()[:16]


def default_transaction_root(repo_path: Path, managed_user: str, managed_home: Path) -> Path:
    """Return the default root-owned same-filesystem transaction namespace.

    For the default `/home/<managed-user>/.maison` shape this yields a sibling
    namespace under `/home`, not under the managed user's home:
    `/home/.maison-deploy/transactions/<managed-user>/<repo-hash>`.
    """

    del repo_path  # The hash is added by allocate_transaction_paths.
    return managed_home.parent / ".maison-deploy" / "transactions" / managed_user


def _is_relative_to(path: Path, ancestor: Path) -> bool:
    try:
        path.relative_to(ancestor)
    except ValueError:
        return False
    return True


def _existing_ancestor(path: Path) -> Path:
    current = path
    while not current.exists() and current != current.parent:
        current = current.parent
    return current


def _assert_not_symlink(path: Path, *, label: str) -> os.stat_result:
    try:
        info = path.lstat()
    except FileNotFoundError as exc:
        raise DeploymentTransactionError(f"{label} does not exist: {path}") from exc
    if stat.S_ISLNK(info.st_mode):
        raise DeploymentTransactionError(f"{label} must not be a symlink: {path}")
    return info


def _assert_no_symlink_components(path: Path, *, label: str) -> None:
    checked: list[Path] = []
    current = path
    while current != current.parent:
        checked.append(current)
        current = current.parent
    checked.append(current)
    for component in reversed(checked):
        if component.exists() or component.is_symlink():
            _assert_not_symlink(component, label=label)


def _assert_same_filesystem(
    *,
    transaction_root: Path,
    transaction_root_info: os.stat_result,
    repo_anchor: Path,
    repo_anchor_info: os.stat_result,
) -> None:
    if transaction_root_info.st_dev != repo_anchor_info.st_dev:
        raise DeploymentTransactionError(
            f"transaction root must be on the same filesystem as {repo_anchor}: {transaction_root}"
        )


def validate_transaction_root(
    *,
    repo_path: Path,
    managed_home: Path,
    transaction_root: Path,
    expected_owner_uid: int = 0,
) -> None:
    """Validate the transaction root before privileged repository mutation."""

    repo_path = repo_path.resolve(strict=False)
    managed_home = managed_home.resolve(strict=False)
    transaction_root = transaction_root.absolute()

    transaction_root_real = transaction_root.resolve(strict=False)
    if _is_relative_to(transaction_root_real, managed_home) or transaction_root_real == managed_home:
        raise DeploymentTransactionError(
            f"transaction root must be outside managed home {managed_home}: {transaction_root}"
        )

    _assert_no_symlink_components(transaction_root, label="transaction root")
    root_info = _assert_not_symlink(transaction_root, label="transaction root")
    if not stat.S_ISDIR(root_info.st_mode):
        raise DeploymentTransactionError(f"transaction root must be a directory: {transaction_root}")
    if root_info.st_uid != expected_owner_uid:
        raise DeploymentTransactionError(
            f"transaction root must be owned by uid {expected_owner_uid}: {transaction_root}"
        )
    if root_info.st_mode & (stat.S_IWGRP | stat.S_IWOTH):
        raise DeploymentTransactionError(
            f"transaction root must not be group/world writable: {transaction_root}"
        )

    repo_anchor = _existing_ancestor(repo_path.parent)
    _assert_no_symlink_components(repo_anchor, label="repository ancestor")
    repo_info = _assert_not_symlink(repo_anchor, label="repository ancestor")
    _assert_same_filesystem(
        transaction_root=transaction_root,
        transaction_root_info=root_info,
        repo_anchor=repo_anchor,
        repo_anchor_info=repo_info,
    )


def allocate_transaction_paths(
    *,
    repo_path: Path,
    managed_user: str,
    managed_home: Path,
    transaction_root: Path | None = None,
    transaction_id: str | None = None,
    expected_owner_uid: int = 0,
) -> TransactionPaths:
    """Validate the transaction root and allocate paths for one transaction."""

    namespace = transaction_root or default_transaction_root(repo_path, managed_user, managed_home)
    namespace = namespace / repo_hash(repo_path)
    validate_transaction_root(
        repo_path=repo_path,
        managed_home=managed_home,
        transaction_root=namespace,
        expected_owner_uid=expected_owner_uid,
    )

    if transaction_id is None:
        transaction_id = secrets.token_urlsafe(24)
    if not transaction_id or any(character in transaction_id for character in "/\0"):
        raise DeploymentTransactionError(f"invalid transaction id: {transaction_id!r}")

    transaction_dir = namespace / transaction_id
    return TransactionPaths(
        root=namespace,
        transaction_id=transaction_id,
        transaction_dir=transaction_dir,
        staging_dir=transaction_dir / "staging",
        rollback_dir=transaction_dir / "rollback",
        journal_path=transaction_dir / "journal.jsonl",
        lock_path=namespace / "transaction.lock",
    )
