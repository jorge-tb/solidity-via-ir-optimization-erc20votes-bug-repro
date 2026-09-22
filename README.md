# Minimal reproduction: `Panic(0x11)` under `--via-ir` with the optimizer enabled

A `getPastVotes` query that should return `0` reverts with an arithmetic underflow
panic when Solidity compiles with **both** `via_ir` and `optimizer` enabled. The same
source returns the correct value with either flag alone, or with neither.

## Reproduce

```
forge install
forge test
```

`foundry.toml` ships with the failing configuration already set.

## Result matrix

| `via_ir` | `optimizer` | Result |
|---|---|---|
| `false` | `false` | passes |
| `false` | `true` | passes |
| `true` | `false` | passes |
| `true` | `true` | **`Panic(0x11)`** |

Reproduced at `optimizer_runs` of 1, 200, 2000, 20000 and 20000000 — the value makes no
difference, only that the optimizer is on.

Reproduced on Solidity **0.8.36** and **0.8.37**.

## What happens

`Minimal` is an ERC-20 with `ERC20Votes` and timestamp clock mode (ERC-6372). The test
mints, self-delegates at timestamp `T`, then queries voting power at `T - 1` — before the
account's first checkpoint exists.

The expected answer is `0`. Instead the call reverts with `Panic(0x11)`.

## Why it looks like a codegen issue

The call reaches `Checkpoints.upperLookupRecent`, whose only reachable subtraction is in
the final statement:

```solidity
return index == 0 ? 0 : _unsafeAccess(self._checkpoints, index - 1)._value;
```

Tracing the failing case by hand:

- the checkpoint array has length `1`, so the `len > 5` tail heuristic is skipped and
  `_upperBinaryLookup` is called with `low = 0`, `high = 1`
- `mid = average(0, 1) = 0`; the checkpoint's key is `T`, the query key is `T - 1`, so
  `key_at_mid > key` holds and the first branch sets `high = 0`
- the loop exits and `_upperBinaryLookup` returns `high`, which is `0`

With `index == 0` the ternary should short-circuit and `index - 1` should never be
evaluated. The underflow therefore occurs on a path the source makes unreachable, which
suggests the conditional guard is not preserved by the optimizer on the IR pipeline.

## Environment

- Solidity 0.8.37 (also reproduces on 0.8.36)
- Foundry / `forge test`
- OpenZeppelin Contracts (pinned in `.gitmodules`)
- Ubuntu on WSL2

## Files

- `src/Minimal.sol` — the token
- `test/Minimal.t.sol` — the failing test
- `foundry.toml` — the triggering configuration
