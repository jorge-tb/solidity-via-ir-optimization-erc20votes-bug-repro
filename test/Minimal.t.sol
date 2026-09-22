// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import {Test} from "forge-std/Test.sol";
import {Minimal} from "../src/Minimal.sol";

contract MinimalTest is Test {
    Minimal minimal;
    address stakeholder;
    uint256 immutable totalTokens = 100;

    function setUp() public {
        stakeholder = makeAddr("stakeholder");

        minimal = new Minimal();
        vm.prank(stakeholder);
        minimal.mint(totalTokens);
    }

    function test_GetPastVotes_ReturnsZeroBeforeDelegation() public {
        uint256 delegationTimestamp = block.timestamp + 1 days;

        vm.warp(delegationTimestamp);
        vm.prank(stakeholder);
        minimal.delegate(stakeholder);

        vm.warp(delegationTimestamp + 1 days);
        assertEq(minimal.getPastVotes(stakeholder, delegationTimestamp - 1), 0);
        assertEq(minimal.getPastVotes(stakeholder, delegationTimestamp), totalTokens);
    }
}