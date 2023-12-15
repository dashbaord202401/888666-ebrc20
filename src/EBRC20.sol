// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "solady/tokens/ERC20.sol";

/**
 * @title  EBRC20
 * @author emo.eth
 * @notice A simple ERC20 token inspired by the "fair mint" BRC20 model, where
 *         anyone can mint tokens for free until maxmum supply is reached by
 *         simply submitting a transaction.
 */
contract EBRC20 is ERC20 {
    string _name;
    string _symbol;
    uint256 public immutable MAX_SUPPLY;
    uint256 public immutable CLAIM_AMOUNT;
    bool public immutable ONLY_EOA;
    mapping(address claimer => bool claimed) claimed;

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
     * @param name_ Name of the token
     * @param symbol_ Symbol of the token
     * @param maxSupply Maximum supply of the token, before being scaled by decimals()
     *                  Only supports whole numbers.
     * @param claimAmount The amount of tokens that can be claimed by each address
     *                    Only supports whole numbers.
     * @param onlyEoa Whether or not to restrict claiming from EOA addresses
     */
    constructor(string memory name_, string memory symbol_, uint256 maxSupply, uint256 claimAmount, bool onlyEoa) {
        _name = name_;
        _symbol = symbol_;
        MAX_SUPPLY = maxSupply * 10 ** decimals();
        CLAIM_AMOUNT = claimAmount * 10 ** decimals();
        if (MAX_SUPPLY % CLAIM_AMOUNT != 0) {
            revert MaxSupplyMustBeMultipleOfClaimed();
        }
        ONLY_EOA = onlyEoa;
    }

    /**
     * @inheritdoc ERC20
     */
    function name() public view override returns (string memory) {
        return _name;
    }

    /**
     * @inheritdoc ERC20
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
        if (msg.sender != tx.origin) {
            revert OnlyEOA();
        }

        /// @dev NOTE: This check will fail if the contract is extended to add
        /// a burn() function that uses the inherited internal _burn() function,
        /// since that function updates totalSupply as part of burning.
        // Check that claiming this amount won't exceed the max supply
        if (totalSupply() + CLAIM_AMOUNT > MAX_SUPPLY) {
            revert MaxSupplyReached();
        }

        // Restrict claiming to once per address
        if (claimed[msg.sender]) {
            revert AlreadyClaimed();
        }

        // Update claim mapping
        claimed[msg.sender] = true;

        // Mint tokens to msg.sender
        _mint(msg.sender, CLAIM_AMOUNT);
    }

    // /**
    //  * @notice Claim CLAIM_AMOUNT tokens for msg.sender. Can only be called once
    //  *         per address.
    //  * @dev This function is optimized to use less gas than `claim()`, as its
    //  *      selector is 0x00000000
    //  */
    // function claim2981390163() public {
    //     claim();
    // }
}
