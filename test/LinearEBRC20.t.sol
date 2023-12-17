// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {LinearEBRC20, LinearEBRC20ConstructorParams} from "src/LinearEBRC20.sol";
import {toWadUnsafe, wadLn} from "solmate/utils/SignedWadMath.sol";

import {LinearEBRC20ConstructorParams} from "../src/Structs.sol";

contract WeirdLinearEBRC20 is LinearEBRC20 {
    constructor(LinearEBRC20ConstructorParams memory params) LinearEBRC20(params) {}

    function forceMint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}

contract LinearEBRC20Test is Test {
    LinearEBRC20 token;

    function setUp() public {
        vm.warp(1);
        token = new LinearEBRC20(
            LinearEBRC20ConstructorParams({
                name: "Test",
                symbol: "TEST",
                maxSupply: 1e9,
                onlyEoa: false,
                startTime: 1 seconds,
                duration: 7 days,
                blockTime: 2,
                decayConstantPerTimeUnit: 0.04e18,
                timeUnit: 60 seconds
            })
        );
    }

    function testName() public {
        assertEq(token.name(), "Test");
    }

    function testSymbol() public {
        assertEq(token.symbol(), "TEST");
    }

    function testMaxSupply() public {
        assertEq(token.MAX_SUPPLY(), 1e9 * 10 ** 18);
    }

    function testClaim() public {
        token.claim();
        assertEq(token.totalSupply(), token.TARGET_WAD_TOKENS_PER_BLOCK() / 1e18);
        assertEq(token.balanceOf(address(this)), token.TARGET_WAD_TOKENS_PER_BLOCK() / 1e18);
    }

    function testTwoClaim() public {
        vm.prank(makeAddr("bob"));
        token.claim();
        vm.warp(3);
        token.claim();
        assertEq(token.totalSupply(), token.balanceOf(address(this)) * 2);
        assertEq(token.balanceOf(address(this)), token.TARGET_WAD_TOKENS_PER_BLOCK() / 1e18);
    }

    function testMaxSupplyClaim() public {
        token.claim();

        vm.warp(1e6 days);
        vm.prank(makeAddr("bob"));
        token.claim();
        assertEq(token.totalSupply(), token.MAX_SUPPLY());
    }

    function testClaimAfter() public {
        vm.warp(token.TARGET_END_TIME());
        token.claim();
        assertEq(token.totalSupply(), token.MAX_SUPPLY());

        vm.prank(makeAddr("bob"));
        vm.expectRevert(LinearEBRC20.MaxSupplyReached.selector);
        token.claim();
    }

    function testClaim_onlyEOA() public {
        token = new LinearEBRC20(
            LinearEBRC20ConstructorParams({
                name: "Test",
                symbol: "TEST",
                maxSupply: 1e9,
                onlyEoa: true,
                startTime: 1 seconds,
                duration: 7 days,
                blockTime: 2,
                decayConstantPerTimeUnit: 0.04e18,
                timeUnit: 60 seconds
            })
        );
        vm.expectRevert(LinearEBRC20.OnlyEOA.selector);
        token.claim();
    }

    function testClaim_ClaimNotStarted() public {
        token = new LinearEBRC20(
            LinearEBRC20ConstructorParams({
                name: "Test",
                symbol: "TEST",
                maxSupply: 1e9,
                onlyEoa: false,
                startTime: 2 seconds,
                duration: 7 days,
                blockTime: 2,
                decayConstantPerTimeUnit: 0.04e18,
                timeUnit: 60 seconds
            })
        );
        vm.expectRevert(LinearEBRC20.ClaimNotStarted.selector);
        token.claim();
    }

    function testClaim_optimized() public {
        token.claim2981390163();
        assertGt(token.balanceOf(address(this)), 0);
    }

    function testWeird() public {
        WeirdLinearEBRC20 weirdToken = new WeirdLinearEBRC20(
            LinearEBRC20ConstructorParams({
                name: "Test",
                symbol: "TEST",
                maxSupply: 1e9,
                onlyEoa: false,
                startTime: 1 seconds,
                duration: 7 days,
                blockTime: 2,
                decayConstantPerTimeUnit: 0.04e18,
                timeUnit: 60 seconds
            })
        );
        weirdToken.forceMint(5e8 * 10 ** token.decimals());
        vm.prank(makeAddr("bob"));
        weirdToken.claim();
        assertEq(token.balanceOf(makeAddr("bob")), 0);
    }

    function testClaim_AlreadyClaimed() public {
        token.claim();
        vm.expectRevert(LinearEBRC20.AlreadyClaimed.selector);
        token.claim();
    }

    function toMinutesWadUnsafe(uint256 secs) internal pure returns (int256 r) {
        assembly {
            r := div(mul(secs, 1000000000000000000), 60)
        }
    }

    function minutesSinceStart() internal view returns (int256 r) {
        return toMinutesWadUnsafe(block.timestamp - 1);
    }
}
