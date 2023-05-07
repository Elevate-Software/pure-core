// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Owned } from "./interfaces/Owned.sol";
import { IUniswapV2Pair, IUniswapV2Router02, IUniswapV2Factory } from "./interfaces/Uniswap.sol";

contract PureToken is ERC20, Owned {

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    address constant public DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    address[] public excludedFromCirculatingSupply;

    bool private swapping;
    bool public tradingIsEnabled;

    address public teamWallet;
    address public marketingWallet;
    address public devWallet;
    
    uint256 public swapTokensAtAmount;

    uint8 public cakeDividendRewardsFee;
    uint8 public previousCakeDividendRewardsFee;

    uint8 public marketingFee;
    uint8 public previousMarketingFee;

    uint8 public buyBackFee;
    uint8 public previousBuyBackFee;

    uint8 public teamFee;
    uint8 public previousTeamFee;

    uint8 public totalFees;

    uint256 public gasForProcessing = 600000;
    uint256 public migrationCounter;

    mapping(address => bool) public isExcludedFromFees;
    mapping(address => bool) public isBlacklisted;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping(address => bool) public automatedMarketMakerPairs;
    
    event MarketingEnabledUpdated(bool enabled);
    event BuyBackEnabledUpdated(bool enabled);
    event TeamEnabledUpdated(bool enabled);
    
    event FeesUpdated(uint8 totalFee, uint8 rewardFee, uint8 marketingFee, uint8 buybackFee, uint8 teamFee);
   
    event ExcludeFromFees(address indexed account, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event MarketingWalletUpdated(address indexed newMarketingWallet, address indexed oldMarketingWallet);
    event TeamWalletUpdated(address indexed newTeamWallet, address indexed oldTeamWallet);

    event RoyaltiesTransferred(address indexed wallet, uint256 amountEth);

    event Erc20TokenWithdrawn(address token, uint256 amount);

    event AddressExcludedFromCirculatingSupply(address account, bool excluded);

    event Migrated(address indexed account, uint256 amount);
    
    event TradingEnabled();
    
    constructor(
        address _marketingWallet,
        address _teamWallet,
        address _devWallet
    ) ERC20("Pure ETH", "PURE") Owned(msg.sender) {

        marketingWallet = _marketingWallet;
        teamWallet = _teamWallet;
        devWallet = _devWallet;
        
        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());

        _setAutomatedMarketMakerPair(uniswapV2Pair, true);

        // exclude from paying fees or having max transaction amount
        isExcludedFromFees[address(this)] = true;
        isExcludedFromFees[DEAD_ADDRESS] = true;
        isExcludedFromFees[marketingWallet] = true;
        isExcludedFromFees[teamWallet] = true;
        isExcludedFromFees[devWallet] = true;
        isExcludedFromFees[address(0)] = true;
        isExcludedFromFees[owner] = true;
        
        _mint(owner, 100_000_000 * (10**18));
    }

    receive() external payable {}

    function addPartnerOrExchange(address _partnerOrExchangeAddress) external onlyOwner {
        isExcludedFromFees[_partnerOrExchangeAddress] = true;
    }
    
    function updateTeamWallet(address _newWallet) external onlyOwner {
        require(_newWallet != teamWallet, "GogeToken.sol::updateTeamWallet() address is already set");

        isExcludedFromFees[_newWallet] = true;
        teamWallet = _newWallet;

        emit TeamWalletUpdated(teamWallet, _newWallet);
    }
    
    function updateMarketingWallet(address _newWallet) external onlyOwner {
        require(_newWallet != marketingWallet, "GogeToken.sol::updateMarketingWallet() address is already set");

        isExcludedFromFees[_newWallet] = true;
        marketingWallet = _newWallet;

        emit MarketingWalletUpdated(marketingWallet, _newWallet);
    }
    
    function updateSwapTokensAtAmount(uint256 _swapAmount) external onlyOwner {
        swapTokensAtAmount = _swapAmount * (10**18);
    }
    
    function enableTrading() external onlyOwner {
        require(!tradingIsEnabled, "GogeToken.sol::enableTrading() trading is already enabled");

        cakeDividendRewardsFee = 10;
        marketingFee = 2;
        buyBackFee = 2;
        teamFee = 2;
        totalFees = 16;
        swapTokensAtAmount = 20_000_000 * (10**18);
        tradingIsEnabled = true;

        emit TradingEnabled();
    }
    
    function updateFees(uint8 _rewardFee, uint8 _marketingFee, uint8 _buybackFee, uint8 _teamFee) external onlyOwner {
        totalFees = _rewardFee + _marketingFee + _buybackFee + _teamFee;

        require(totalFees <= 40, "GogeToken.sol::updateFees() sum of fees cannot exceed 40%");
        
        cakeDividendRewardsFee = _rewardFee;
        marketingFee = _marketingFee;
        buyBackFee = _buybackFee;
        teamFee = _teamFee;

        emit FeesUpdated(totalFees, _rewardFee, _marketingFee, _buybackFee, _teamFee);
    }
    
    function updateUniswapV2Router(address newAddress) external onlyOwner {
        require(newAddress != address(uniswapV2Router), "GogeToken.sol::UpdatedUniswapV2Router() the router already has that address");

        uniswapV2Router = IUniswapV2Router02(newAddress);
    }

    function excludeFromFees(address account, bool excluded) external onlyOwner {
        isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function isExcludedFromCirculatingSupply(address _address) public view returns(bool, uint8) {
        for (uint8 i; i < excludedFromCirculatingSupply.length; ++i){
            if (_address == excludedFromCirculatingSupply[i]) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    function excludeFromCirculatingSupply(address account, bool excluded) public onlyOwner {
        (bool _isExcluded, uint8 i) = isExcludedFromCirculatingSupply(account);
        require(_isExcluded != excluded, "GogeToken.sol::excludeFromCirculatingSupply() account already set to that boolean value");

        if(excluded) {
            if(!_isExcluded) excludedFromCirculatingSupply.push(account);        
        } else {
            if(_isExcluded){
                excludedFromCirculatingSupply[i] = excludedFromCirculatingSupply[excludedFromCirculatingSupply.length - 1];
                excludedFromCirculatingSupply.pop();
            } 
        }

        emit AddressExcludedFromCirculatingSupply(account, excluded);
    }

    function setAutomatedMarketMakerPair(address pair, bool value) external onlyOwner {
        require(pair != uniswapV2Pair, "GogeToken.sol::setAutomatedMarketMakerPair() the PancakeSwap pair cannot be removed from automatedMarketMakerPairs");
        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) internal {
        require(automatedMarketMakerPairs[pair] != value, "GogeToken.sol::_setAutomatedMarketMakerPair() Automated market maker pair is already set to that value");

        automatedMarketMakerPairs[pair] = value;
        excludeFromCirculatingSupply(pair, value);

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function getCirculatingMinusReserve() external view returns(uint256 circulating) {
        circulating = totalSupply() - (balanceOf(DEAD_ADDRESS) + balanceOf(address(0)));
        for (uint8 i; i < excludedFromCirculatingSupply.length;) {
            circulating = circulating - balanceOf(excludedFromCirculatingSupply[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 amount

    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(tradingIsEnabled || (isExcludedFromFees[from] || isExcludedFromFees[to]), "GogeToken.sol::_transfer() trading is not enabled or wallet is not whitelisted");
        
        bool excludedAccount = isExcludedFromFees[from] || isExcludedFromFees[to];
        
        if ( // NON whitelisted buy
            tradingIsEnabled &&
            automatedMarketMakerPairs[from] &&
            !excludedAccount
        ) {
            // if receiver or sender is blacklisted, revert
            require(!isBlacklisted[from], "GogeToken.sol::_transfer() sender is blacklisted");
            require(!isBlacklisted[to],   "GogeToken.sol::_transfer() receiver is blacklisted");
        }
        
        else if ( // NON whitelisted sell
            tradingIsEnabled &&
            automatedMarketMakerPairs[to] &&
            !excludedAccount
        ) {
            // if receiver or sender is blacklisted, revert
            require(!isBlacklisted[from], "GogeToken.sol::_transfer() sender is blacklisted");
            require(!isBlacklisted[to],   "GogeToken.sol::_transfer() receiver is blacklisted");
            
            // take contract balance of royalty tokens
            uint256 contractTokenBalance = balanceOf(address(this));
            bool canSwap = contractTokenBalance >= swapTokensAtAmount;
            
            if (!swapping && canSwap) {
                swapping = true;

                swapTokensForWeth(contractTokenBalance);
                
                uint256 contractBalance = address(this).balance;
                uint8   feesTaken = 0;
                
                if (true) {
                    uint256 marketingPortion = contractBalance.mul(marketingFee).div(totalFees);
                    contractBalance = contractBalance - marketingPortion;
                    feesTaken = feesTaken + marketingFee;

                    transferToWallet(payable(marketingWallet), marketingPortion);

                    // if(block.timestamp < _firstBlock + (60 days)) { // dev fee only lasts for 60 days post launch.
                    //     uint256 devPortion = contractBalance.mul(2).div(totalFees - feesTaken);
                    //     contractBalance = contractBalance - devPortion;
                    //     feesTaken = feesTaken + 2;
                    
                    //     royaltiesSent[2] += devPortion;
                    //     transferToWallet(payable(devWallet), devPortion);
                    // }
                }

                if (true) {
                    uint256 teamPortion = contractBalance.mul(teamFee).div(totalFees - feesTaken);
                    contractBalance = contractBalance - teamPortion;
                    feesTaken = feesTaken + teamFee;

                    transferToWallet(payable(teamWallet), teamPortion);
                }
    
                swapping = false;
            }
        }

        bool takeFee = tradingIsEnabled && !swapping && !excludedAccount;

        if(takeFee) {
            require(!isBlacklisted[from], "GogeToken.sol::_transfer() sender is blacklisted");
            require(!isBlacklisted[to],   "GogeToken.sol::_transfer() receiver is blacklisted");

            uint256 fees;

            fees = amount.mul(totalFees).div(100);
            amount = amount.sub(fees);

            super._transfer(from, address(this), fees);
        }

        super._transfer(from, to, amount);
    }

    function modifyBlacklist(address account, bool blacklisted) external onlyOwner {
        isBlacklisted[account] = blacklisted;
    }

    function swapTokensForWeth(uint256 tokenAmount) internal {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
        
    }
    
    function transferToWallet(address payable recipient, uint256 amount) internal {
        recipient.transfer(amount);
        emit RoyaltiesTransferred(recipient, amount);
    }

    /// @notice Withdraw a gogeToken from the treasury.
    /// @dev    Only callable by owner.
    /// @param  _token The token to withdraw from the treasury.
    function safeWithdraw(address _token) external onlyOwner {
        uint256 amount = IERC20(_token).balanceOf(address(this));
        require(amount > 0, "GogeToken.sol::safeWithdraw() Insufficient token balance");
        require(_token != address(this), "GogeToken.sol::safeWithdraw() cannot remove $GOGE from this contract");

        assert(IERC20(_token).transfer(msg.sender, amount));

        emit Erc20TokenWithdrawn(_token, amount);
    }

}