// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.6;

import { Test } from "../lib/forge-std/src/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Actor } from "../src/users/Actor.sol";

/// @notice All contract addresses provided below have been configured for a Binance Smart Chain contract.
contract Utility is Test {

    /***********************/
    /*** Protocol Actors ***/
    /***********************/

    Actor  joe;
    Actor  dev;


    /**********************************/
    /*** Mainnet Contract Addresses ***/
    /**********************************/

    address constant WETH  = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC  = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // IERC20 constant dai  = IERC20(BUSD);
    // IERC20 constant wbnb = IERC20(WBNB);
    // IERC20 constant cake = IERC20(CAKE);

    address constant UNISWAP_V2_ROUTER_02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;


    /*****************/
    /*** Constants ***/
    /*****************/

    uint256 constant USD = 10 ** 6;  // USDC precision decimals
    uint256 constant BTC = 10 ** 8;  // WBTC precision decimals
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;


    /**************************************/
    /*** Actor/Multisig Setup Functions ***/
    /**************************************/

    function createActors() public {
        joe = new Actor();
        dev = new Actor();

        vm.label(address(joe), "Joe");
        vm.label(address(dev), "Dev");
    }


    /******************************/
    /*** Test Utility Functions ***/
    /******************************/

    // Verify equality within accuracy decimals.
    function withinPrecision(uint256 val0, uint256 val1, uint256 accuracy) public {
        uint256 diff  = val0 > val1 ? val0 - val1 : val1 - val0;
        if (diff == 0) return;

        uint256 denominator = val0 == 0 ? val1 : val0;
        bool check = ((diff * RAY) / denominator) < (RAY / 10 ** accuracy);

        if (!check){
            emit log_named_uint("Error: approx a == b not satisfied, accuracy digits ", accuracy);
            emit log_named_uint("  Expected", val0);
            emit log_named_uint("    Actual", val1);
            fail();
        }
    }

    // Verify equality within difference.
    function withinDiff(uint256 val0, uint256 val1, uint256 expectedDiff) public {
        uint256 actualDiff = val0 > val1 ? val0 - val1 : val1 - val0;
        bool check = actualDiff <= expectedDiff;

        if (!check) {
            emit log_named_uint("Error: approx a == b not satisfied, accuracy difference ", expectedDiff);
            emit log_named_uint("  Expected", val0);
            emit log_named_uint("    Actual", val1);
            fail();
        }
    }

    function constrictToRange(uint256 val, uint256 min, uint256 max) public pure returns (uint256) {
        return constrictToRange(val, min, max, false);
    }

    function constrictToRange(uint256 val, uint256 min, uint256 max, bool nonZero) public pure returns (uint256) {
        if      (val == 0 && !nonZero) return 0;
        else if (max == min)           return max;
        else                           return val % (max - min) + min;
    }
    
}