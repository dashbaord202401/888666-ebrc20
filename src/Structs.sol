// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @notice Convenience struct for constructing a LinearEBRC20 contract.
 */
struct LinearEBRC20ConstructorParams {
    /// @notice token name
    string name;
    /// @notice token symbol
    string symbol;
    /// @notice max supply as an integer, before scaling by decimals
    uint128 maxSupply;
    /// @notice whether or not to restrict claims to EOAs (ie, not smart contracts)
    bool onlyEoa;
    /// @notice unix timestamp of start of claim period
    uint256 startTime;
    /// @notice ideal number of seconds claim period should last, so the VRGDA
    /// algorithm can adjust claim amount accordingly
    uint256 duration;
    /// @notice blocktime of the network being deployed to, to help scale target
    /// number of tokens claimed block
    uint256 blockTime;
    /// @notice Percent by which to increase number of tokens claimed per time
    /// period with no activity, scaled by 1e18. eg, 0.04e18 is 4%
    int256 decayConstantPerTimeUnit;
    /// @notice Number of seconds that the VRGDA algorithm uses to calculate
    /// decay – eg, 60 seconds, combined with a 0.04e18 decay constant means
    /// the algorithm will scale down (or up) by 4% every minute.
    uint256 timeUnit;
}
