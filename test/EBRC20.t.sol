// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {EBRC20} from "../src/EBRC20.sol";

contract EBRC20Test is Test {
    EBRC20 token;

    function setUp() public {
        token = new EBRC20("Test", "TEST", 100, 10, false);
    }

    function testName() public {
        assertEq(token.name(), "Test");
    }

    function testSymbol() public {
        assertEq(token.symbol(), "TEST");
    }

    function testMaxSupply() public {
        assertEq(token.MAX_SUPPLY(), 100 * 10 ** 18);
    }

    function testClaimAmount() public {
        assertEq(token.CLAIM_AMOUNT(), 10 * 10 ** 18);
    }

    function testClaim() public {
        token.claim();
        assertEq(token.totalSupply(), 10 * 10 ** 18);
        assertEq(token.balanceOf(address(this)), 10 * 10 ** 18);
    }

    function testClaim_AlreadyClaimed() public {
        token.claim();
        vm.expectRevert(EBRC20.AlreadyClaimed.selector);
        token.claim();
    }

    function testClaim_MaxSupplyReached() public {
        for (uint256 i; i < 10; i++) {
            vm.prank(address(uint160(100 + i)));
            token.claim();
        }
        vm.expectRevert(EBRC20.MaxSupplyReached.selector);
        token.claim();

        assertEq(token.totalSupply(), token.MAX_SUPPLY());
    }

    // function testClaim_optimized() public {
    //     token.claim2981390163();
    //     assertEq(token.totalSupply(), 10 * 10 ** 18);
    //     assertEq(token.balanceOf(address(this)), 10 * 10 ** 18);
    // }
}
