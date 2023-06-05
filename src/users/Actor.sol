// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.6;
pragma experimental ABIEncoderV2;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Actor {

    receive() payable external {}

    /*********************/
    /*** TRY FUNCTIONS ***/
    /*********************/

    function try_transferToken(address token, address to, uint256 amt) external returns (bool ok) {
        string memory sig = "transfer(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, to, amt));
    }

    function try_transferFromToken(address token, address from, address to, uint256 amt) external returns (bool ok) {
        string memory sig = "transferFrom(address,address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, to, amt));
    }

    function try_approveToken(address token, address to, uint256 amt) external returns (bool ok) {
        string memory sig = "approve(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, to, amt));
    }

    function try_increaseAllowance(address token, address account, uint amt) external returns (bool ok) {
        string memory sig = "increaseAllowance(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, account, amt));
    }

    function try_decreaseAllowance(address token, address account, uint amt) external returns (bool ok) {
        string memory sig = "decreaseAllowance(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, account, amt));
    }

    function try_updateStable(address treasury, address stablecoin) external returns (bool ok) {
        string memory sig = "updateStable(address)";
        (ok,) = address(treasury).call(abi.encodeWithSignature(sig, stablecoin));
    }

    function try_enableTrading(address token) external returns (bool ok) {
        string memory sig = "enableTrading()";
        (ok,) = address(token).call(abi.encodeWithSignature(sig));
    }

    function try_modifyBlacklist(address token, address account, bool blacklisted) external returns (bool ok) {
        string memory sig = "modifyBlacklist(address,bool)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, account, blacklisted));
    }

    function try_excludeFromFees(address token, address account, bool whitelisted) external returns (bool ok) {
        string memory sig = "excludeFromFees(address,bool)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, account, whitelisted));
    }

    function try_setGogeDao(address token, address dao) external returns (bool ok) {
        string memory sig = "setGogeDao(address)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, dao));
    }

    function try_updateSwapTokensAtAmount(address token, uint256 amount) external returns (bool ok) {
        string memory sig = "updateSwapTokensAtAmount(uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, amount));
    }

    function try_updateRoyalties(address token, uint8 rewardFee, uint8 marketingFee, uint8 buyBackFee) external returns (bool ok) {
        string memory sig = "updateRoyalties(uint8,uint8,uint8)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, rewardFee, marketingFee, buyBackFee));
    }

    function try_setBuyBackEnabled(address token, bool enabled) external returns (bool ok) {
        string memory sig = "setBuyBackEnabled(bool)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, enabled));
    }

    function try_setMarketingEnabled(address token, bool enabled) external returns (bool ok) {
        string memory sig = "setMarketingEnabled(bool)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, enabled));
    }

    function try_setTeamEnabled(address token, bool enabled) external returns (bool ok) {
        string memory sig = "setTeamEnabled(bool)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, enabled));
    }

    function try_migrate(address token) external returns (bool ok) {
        string memory sig = "migrate()";
        (ok,) = address(token).call(abi.encodeWithSignature(sig));
    }

    function try_safeWithdraw(address token, address tokenToWithdraw) external returns (bool ok) {
        string memory sig = "safeWithdraw(address)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, tokenToWithdraw));
    }


}