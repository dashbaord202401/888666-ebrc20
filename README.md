# EBRC20

BRC-20 style "fair mints" on EVM compatible chains.

## Overview

EBRC20 is a simple ERC20 token that does no creator allocations, and does not require payment to mint tokens.

Instead, each address may submit one `claim()` transaction to mint a fixed amount of tokens.

When the max supply is reached, the contract will stop accepting claims.
