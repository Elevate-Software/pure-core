// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Utility } from "./Utility.sol";
import { PureToken } from "../src/PureToken.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CounterTest is Utility {
    PureToken public pureToken;

    function setUp() public {
        createActors();
        
        // deploy token.
        pureToken = new PureToken(
            address(1),
            address(2),
            address(3)
        );

        // Give tokens and ownership to dev.
        pureToken.transfer(address(dev), 100_000_000 ether);
        pureToken.transferOwnership(address(dev));

        // enable trading.
        assert(dev.try_enableTrading(address(pureToken)));
    }

    // Initial state test.
    function test_pureToken_init_state() public {
        assertEq(pureToken.marketingWallet(),       address(1));
        assertEq(pureToken.operationsWallet(),      address(2));
        assertEq(pureToken.devWallet(),             address(3));
        assertEq(pureToken.totalSupply(),           100_000_000 ether);
        assertEq(pureToken.balanceOf(address(dev)), 100_000_000 ether);
        assertEq(pureToken.owner(),                 address(dev));

        assertEq(pureToken.isExcludedFromFees(pureToken.marketingWallet()),  true);
        assertEq(pureToken.isExcludedFromFees(pureToken.operationsWallet()), true);
        assertEq(pureToken.isExcludedFromFees(pureToken.devWallet()),        true);
        assertEq(pureToken.isExcludedFromFees(address(pureToken)),           true);
        assertEq(pureToken.isExcludedFromFees(pureToken.owner()),            true);
        assertEq(pureToken.isExcludedFromFees(pureToken.DEAD_ADDRESS()),     true);
        assertEq(pureToken.isExcludedFromFees(address(0)),                   true);

        assertEq(pureToken.marketingFee(),           40);
        assertEq(pureToken.operationsFee(),          40);
        assertEq(pureToken.devFee(),                 20);
        assertEq(pureToken.buyTax(),                 5);
        assertEq(pureToken.sellTax(),                5);
        assertEq(pureToken.txTax(),                  5);
        assertEq(pureToken.swapTokensAtAmount(),     20_000 ether);

        assertEq(pureToken.tradingIsEnabled(), true);
    }

    // ~ Transfer Testing ~

    // Whitelisted Transfer test -> no tax.
    function test_pureToken_transfer_WL() public {
        assert(dev.try_transferToken(address(pureToken), address(joe), 1_000_000 ether));
        assertEq(pureToken.balanceOf(address(joe)), 1_000_000 ether);
    }

    // ~ Blacklist Testing ~

    // This tests blacklisting of the receiver.
    function test_pureToken_blacklist_receiver() public {
        assert(dev.try_transferToken(address(pureToken), address(joe), 100 ether));

        assert(joe.try_transferToken(address(pureToken), address(32), 10 ether));
        assert(dev.try_modifyBlacklist(address(pureToken), address(32), true));
        assert(!joe.try_transferToken(address(pureToken), address(32), 10 ether));
    }

    // This tests blacklisting of the sender.
    function test_pureToken_blacklist_sender() public {
        assert(dev.try_transferToken(address(pureToken), address(joe), 100 ether));

        assert(joe.try_transferToken(address(pureToken), address(32), 10 ether));
        assert(dev.try_modifyBlacklist(address(pureToken), address(joe), true));
        assert(!joe.try_transferToken(address(pureToken), address(32), 10 ether));
    }

    // This tests that a blacklisted sender can send tokens to a whitelisted receiver.
    function test_pureToken_blacklist_to_whitelist() public {
        // This contract can successfully send assets to address(joe).
        assert(dev.try_transferToken(address(pureToken), address(joe), 100 ether));

        // Blacklist joe.
        assert(dev.try_modifyBlacklist(address(pureToken), address(joe), true));

        // Joe can no longer send tokens to address(32).
        assert(!joe.try_transferToken(address(pureToken), address(32), 10 ether));

        // Whitelist address(32).
        assert(dev.try_excludeFromFees(address(pureToken), address(32), true));

        // Joe can successfully send assets to whitelisted address(32).
        assert(joe.try_transferToken(address(pureToken), address(32), 10 ether));
    }

    // This tests that a whitelisted sender can send tokens to a blacklisted receiver.
    function test_pureToken_whitelist_to_blacklist() public {
        // This contract can successfully send assets to address(joe).
        assert(dev.try_transferToken(address(pureToken), address(joe), 100 ether));

        // Blacklist address(32).
        assert(dev.try_modifyBlacklist(address(pureToken), address(32), true));

        // Joe can no longer send tokens to address(32).
        assert(!joe.try_transferToken(address(pureToken), address(32), 10 ether));

        // Whitelist Joe.
        assert(dev.try_excludeFromFees(address(pureToken), address(joe), true));

        // Joe can successfully send assets to blacklisted address(32).
        assert(joe.try_transferToken(address(pureToken), address(32), 10 ether));
    }

    // ~ Whitelist testing (excludedFromFees) ~

    // This test case verifies that a whitelisted sender is not taxed when transferring tokens.
    function test_pureToken_whitelist() public {
        // This contract can successfully send assets to address(joe).
        assert(dev.try_transferToken(address(pureToken), address(joe), 200 ether));

        // Post-state check. Joe has all 100 tokens.
        assertEq(pureToken.balanceOf(address(joe)), 200 ether);

        // Joe sends tokens to address(32).
        assert(joe.try_transferToken(address(pureToken), address(32), 100 ether));

        // Post-state check. Address(32) has been taxed 5% on transfer.
        assertEq(pureToken.balanceOf(address(32)), (100 ether) - ((100 ether) * 5/100));

        // Whitelist joe.
        assert(dev.try_excludeFromFees(address(pureToken), address(joe), true));

        // Joe is whitelisted thus sends non-taxed tokens to address(34).
        assert(joe.try_transferToken(address(pureToken), address(34), 100 ether));

        // Post-state check. Address(34) has NOT been taxed.
        assertEq(pureToken.balanceOf(address(34)), 100 ether);
    }

    // ~ setters ~

    // This tests the proper state changes when calling updateSwapTokensAtAmount().
    function test_pureToken_updateSwapTokensAtAmount() public {
        // Pre-state check. Verify current value of swapTokensAtAmount
        assertEq(pureToken.swapTokensAtAmount(), 20_000 * WAD);

        // Update swapTokensAtAmount
        assert(dev.try_updateSwapTokensAtAmount(address(pureToken), 1_000));

        // Post-state check. Verify updated value of swapTokensAtAmount
        assertEq(pureToken.swapTokensAtAmount(), 1_000 * WAD);
    }

    // updateRoyalties test
    function test_pureToken_updateRoyalties() public {
        //Pre-state check.
        assertEq(pureToken.marketingFee(), 40);
        assertEq(pureToken.operationsFee(), 40);
        assertEq(pureToken.devFee(), 20);

        // Call updateRoyalties
        assert(dev.try_updateRoyalties(address(pureToken), 33, 33, 34));

        // Post-state check.
        assertEq(pureToken.marketingFee(), 33);
        assertEq(pureToken.operationsFee(), 33);
        assertEq(pureToken.devFee(), 34);

        // Restriction: Sum must be == 100
        assert(!dev.try_updateRoyalties(address(pureToken), 30, 30, 30)); // 90
    }

    // safeWithdraw test
    function test_pureToken_safeWithdraw() public {
        // mint USDC to pureToken contract
        deal(USDC, address(pureToken), 1_000 ether);

        // Pre-state check.
        assertEq(IERC20(USDC).balanceOf(address(pureToken)), 1_000 ether);
        assertEq(IERC20(USDC).balanceOf(address(dev)), 0);

        // Call safeWithdraw()
        assert(dev.try_safeWithdraw(address(pureToken), USDC));

        // Post-state check.
        assertEq(IERC20(USDC).balanceOf(address(pureToken)), 0);
        assertEq(IERC20(USDC).balanceOf(address(dev)), 1_000 ether);
    }
}
