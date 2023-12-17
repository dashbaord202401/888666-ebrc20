// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "solady/tokens/ERC20.sol";
import {LinearVRGDA} from "vrgdas/LinearVRGDA.sol";
import {toWadUnsafe, unsafeWadMul} from "solmate/utils/SignedWadMath.sol";

struct LinearEBRC20Params {
    string name;
    string symbol;
    uint128 maxSupply;
    bool onlyEoa;
    uint256 startTime;
    uint256 duration;
    uint256 blockTime;
    int256 decayConstantPerTimeUnit;
    uint256 timeUnit;
}

/**
 * @title  EBRC20
 * @author emo.eth
 * @notice An ERC20 token inspired by the "fair mint" BRC20 model, where
 *         anyone can mint tokens for free until maximum supply is reached by
 *         simply submitting a transaction.
 *         LinearEBRC20 uses the Linear VRGDA algorithm to scale the claim
 *         amount according to the rate of claims, so that the claim period
 *         lasts approximately a set amount of time, without wasting blockspace
 *         or gas to keep redemption rate on track to reach max supply.
 */
contract LinearEBRC20 is ERC20, LinearVRGDA {
    /// @notice The maximum supply of the token, scaled by decimals()
    uint256 public immutable MAX_SUPPLY;

    /// @notice Whether or not this token restricts claiming to EOA addresses
    bool public immutable ONLY_EOA;

    /// @notice The time the claim starts
    uint256 public immutable START_TIME;
    /// @notice The ideal end time for the clai period.. Actual end time depends
    ///         on rate of claims.
    uint256 public immutable TARGET_END_TIME;
    /// @notice The ideal duration of the claim period. Actual duration depends
    ///         on the rate of claims.
    uint256 public immutable TARGET_DURATION;
    /// @notice The number of seconds that comprise a discrete "time period"
    ///         according to the VRGDA algorithm.
    uint256 public immutable TIME_UNIT_SECONDS;
    /// @notice The number of seconds used to calculate the TARGET_WAD_TOKENS_PER_BLOCK
    uint256 public immutable BLOCK_TIME_SECONDS;
    /// @dev The ideal number of tokens that should be claimed per block, if
    ///      claims are constant according to issuance schedule. Scaled by 1e18.
    uint256 public immutable TARGET_WAD_TOKENS_PER_BLOCK;

    /// @notice A mapping tracking whether or not an address has claimed tokens
    mapping(address claimer => bool claimed) public claimed;

    /// @dev Token name
    string _name;
    /// @dev Token symbol
    string _symbol;

    /**
     * @notice Raised on construction when the maxSupply param is not a multiple
     *         of the claimAmount param.
     */
    error MaxSupplyMustBeMultipleOfClaimed();

    /**
     * @notice Raised on construction when the maxSupply param is 0.
     */
    error MaxSupplyMustBeGreaterThanZero();

    /**
     * @notice Raised on construction when the claimAmount param is 0.
     */
    error ClaimAmountMustBeGreaterThanZero();

    /**
     * @notice Raised on claim when the max supply has been reached
     */
    error MaxSupplyReached();
    /**
     * @notice Raised on claim when the address has already claimed
     */
    error AlreadyClaimed();

    /**
     * @notice Raised on claim when the address is not an EOA, and ONLY_EOA is true.
     */
    error OnlyEOA();

    /**
     * @notice Raised on claim when the claim period has not started
     */
    error ClaimNotStarted();

    constructor(LinearEBRC20Params memory params)
        LinearVRGDA(
            toWadUnsafe(1),
            params.decayConstantPerTimeUnit,
            toWadUnsafe(((params.maxSupply * 10 ** 18 * params.timeUnit) / params.duration))
        )
    {
        _name = params.name;
        _symbol = params.symbol;
        MAX_SUPPLY = params.maxSupply * 10 ** decimals();
        ONLY_EOA = params.onlyEoa;
        START_TIME = params.startTime;
        TARGET_END_TIME = params.startTime + params.duration;
        TARGET_DURATION = params.duration;
        TARGET_WAD_TOKENS_PER_BLOCK = uint256(toWadUnsafe(MAX_SUPPLY * params.blockTime / TARGET_DURATION)); // op stack blocktime is 2
        TIME_UNIT_SECONDS = params.timeUnit;
        BLOCK_TIME_SECONDS = params.blockTime;
    }

    function toTimeUnitWadUnsafe(uint256 x) internal view returns (int256 r) {
        uint256 timeUnit = TIME_UNIT_SECONDS;
        assembly {
            r := div(mul(x, 1000000000000000000), timeUnit)
        }
    }

    /**
     * @notice The name of the token
     */
    function name() public view override returns (string memory) {
        return _name;
    }

    /**
     * @notice The symbol of the token
     */
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Claim CLAIM_AMOUNT tokens for msg.sender. Can only be called once
     *         per address.
     */
    function claim() public {
        // NOTE: This check will prevent smart contracts from batch deploying
        // claim contracts, but won't prevent someone running a script with
        // several seeded wallets. On optimistic L2s, however, the latter will
        // be much more expensive to actually execute, given that each discrete
        // TX incurs more expensive L1 fees.
        if (ONLY_EOA && msg.sender != tx.origin) {
            revert OnlyEOA();
        }
        if (block.timestamp < START_TIME) {
            revert ClaimNotStarted();
        }
        // Restrict claiming to once per address
        if (claimed[msg.sender]) {
            revert AlreadyClaimed();
        }

        // Quotient to adjust TARGET_WAD_TOKENS_PER_BLOCK
        uint256 claimQuotient;

        // cache current totalSupply
        uint256 currentSupply = totalSupply();

        // copied from expWad to mitigate exp overflow errors
        // todo: ideally prove that this isn't possible with constrained constructor params
        if (
            unsafeWadMul(
                decayConstant,
                // Theoretically calling toWadUnsafe with sold can silently overflow but under
                // any reasonable circumstance it will never be large enough. We use sold + 1 as
                // the VRGDA formula's n param represents the nth token and sold is the n-1th token.
                timeUnitsSinceStart() - getTargetSaleTime(toWadUnsafe(currentSupply + 1))
            ) >= 135305999368893231589
        ) {
            claimQuotient = type(uint256).max;
        } else {
            // Calculate the amount of tokens to mint
            // instead of using VRGDA formula for price, use it to calculate the amount of tokens to mint
            // eg, 0.5e18 = "2x amount", 1e18 = "normal amount", 2e18 = "1/2 amount", 5e18 = "1/5 amount", etc
            claimQuotient = getVRGDAPrice(timeUnitsSinceStart(), currentSupply);
        }
        // in case a negative exponent was too large, set to 1
        claimQuotient = (claimQuotient == 0) ? 1 : claimQuotient;
        uint256 amount = uint256(((TARGET_WAD_TOKENS_PER_BLOCK))) / claimQuotient;

        // Check that claiming this amount won't exceed the max supply
        if (amount + currentSupply > MAX_SUPPLY) {
            uint256 remaining = MAX_SUPPLY - currentSupply;
            if (remaining > 0) {
                amount = remaining;
            } else {
                revert MaxSupplyReached();
            }
        }

        if (amount > 0) {
            // Update claim mapping
            claimed[msg.sender] = true;

            // Mint tokens to msg.sender
            _mint(msg.sender, amount);
        }
    }

    function timeUnitsSinceStart() internal view returns (int256) {
        return toTimeUnitWadUnsafe(block.timestamp - START_TIME);
    }

    /**
     * @notice Claim CLAIM_AMOUNT tokens for msg.sender. Can only be called once
     *         per address.
     * @dev This function is optimized to use less gas than `claim()`, as its
     *      selector is 0x00000000
     */
    function claim2981390163() public {
        claim();
    }
}
