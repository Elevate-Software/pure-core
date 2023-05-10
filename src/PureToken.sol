// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Owned } from "./interfaces/Owned.sol";
import { IUniswapV2Pair, IUniswapV2Router02, IUniswapV2Factory } from "./interfaces/Uniswap.sol";

// TODO: Config NATSPEC

contract PureToken is ERC20, Owned {


    // ---------------
    // State Variables
    // ---------------

    // TODO: Slot pack?

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    address constant public DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    address[] public excludedFromCirculatingSupply;

    bool private inSwap;
    bool public tradingIsEnabled;
    
    uint256 public swapTokensAtAmount;

    uint256 public operationsFee;
    uint256 public marketingFee;
    uint256 public devFee;

    address public operationsWallet;
    address public marketingWallet;
    address public devWallet;

    uint8 public buyTax;
    uint8 public sellTax;
    uint8 public txTax;
    uint256 public maxWallet; // TODO: Add to transfer and add updateMaxWallet func

    mapping(address => bool) public isExcludedFromFees;
    mapping(address => bool) public isBlacklisted;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    mapping(address => bool) public automatedMarketMakerPairs;


    // -----------
    // Constructor
    // -----------

    constructor(
        address _marketingWallet,
        address _operationsWallet,
        address _devWallet
    ) ERC20("Pure ETH", "PURE") Owned(msg.sender) {

        marketingWallet = _marketingWallet;
        operationsWallet = _operationsWallet;
        devWallet = _devWallet;
        
        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());

        _setAutomatedMarketMakerPair(uniswapV2Pair, true);

        // exclude from paying fees or having max transaction amount
        isExcludedFromFees[address(this)] = true;
        isExcludedFromFees[DEAD_ADDRESS] = true;
        isExcludedFromFees[marketingWallet] = true;
        isExcludedFromFees[operationsWallet] = true;
        isExcludedFromFees[devWallet] = true;
        isExcludedFromFees[address(0)] = true;
        isExcludedFromFees[owner] = true;
        
        _mint(owner, 100_000_000 * (10**18));
    }


    // ---------
    // Modifiers
    // ---------

    modifier lockSwap {
        inSwap = true;
        _;
        inSwap = false;
    }


    // ------
    // Events
    // ------
    
    event RoyaltiesUpdated(uint8 operationsFee, uint8 marketingFee, uint8 devFee);

    event BuyTaxUpdated(uint8, uint8);

    event SellTaxUpdated(uint8, uint8);

    event TransferTaxUpdated(uint8, uint8);
   
    event ExcludeFromFees(address indexed account, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event MarketingWalletUpdated(address indexed newMarketingWallet, address indexed oldMarketingWallet);
    
    event operationsWalletUpdated(address indexed newoperationsWallet, address indexed oldoperationsWallet);

    event RoyaltiesTransferred(address indexed wallet, uint256 amountEth);

    event Erc20TokenWithdrawn(address token, uint256 amount);

    event AddressExcludedFromCirculatingSupply(address account, bool excluded);
    
    event TradingEnabled();


    // ---------
    // Functions
    // ---------

    receive() external payable {}

    
    // ~ internal ~

    // TODO: TEST this!!
    function _transfer(
        address from,
        address to,
        uint256 amount

    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(tradingIsEnabled || (isExcludedFromFees[from] || isExcludedFromFees[to]), "PureToken.sol::_transfer() trading is not enabled or wallet is not whitelisted");
        require(balanceOf(from) >= amount, "PureToken::_transfer(), insufficient balance");

        if (!isExcludedFromFees[from] && !isExcludedFromFees[to]) {
            require(!isBlacklisted[from], "PureToken.sol::_transfer() sender is blacklisted");
            require(!isBlacklisted[to],   "PureToken.sol::_transfer() receiver is blacklisted");
            // TODO: Check MaxWallet

            uint256 takeTax;

            // non-whitelisted buy
            if (automatedMarketMakerPairs[from]) {
                takeTax = buyTax;
            }
            // non-whitelisted sell
            else if (automatedMarketMakerPairs[to]) {
                takeTax = sellTax;

                uint256 contractTokenBalance = balanceOf(address(this));
                bool canSwap = contractTokenBalance >= swapTokensAtAmount;
                
                if (!inSwap && canSwap) {
                    _handleRoyalties(contractTokenBalance);
                }

            }
            // non-whitelisted transfer
            else {
                takeTax = txTax;
            }

            uint256 taxAmount = (amount * takeTax) / 100;
            amount = amount - taxAmount;
                
            super._transfer(from, address(this), taxAmount);
        }
        
        super._transfer(from, to, amount);
    }

    function _handleRoyalties(uint256 _contractTokenBalance) internal lockSwap {
        _swapTokensForWeth(_contractTokenBalance);
        _distributeTaxes();
    }

    function _swapTokensForWeth(uint256 tokenAmount) internal {
        // TODO: Maybe swap for stablecoin??
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

    function _distributeTaxes() internal {
        uint256 contractBalance = address(this).balance;

        // transfer portion for operations
        uint256 marketingPortion = (contractBalance * marketingFee) / 100;
        _transferToWallet(payable(marketingWallet), marketingPortion);
        
        // transfer portion for marketing
        uint256 operationsPortion = (contractBalance * operationsFee) / 100;
        _transferToWallet(payable(operationsWallet), operationsPortion);

        // transfer portion for dev
        uint256 devPortion = (contractBalance * devFee) / 100;
        _transferToWallet(payable(devWallet), devPortion);
    }
    
    function _transferToWallet(address payable recipient, uint256 amount) internal {
        recipient.transfer(amount); // TODO: update to use .call instead of .transfer
        emit RoyaltiesTransferred(recipient, amount);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) internal {
        require(automatedMarketMakerPairs[pair] != value, "PureToken.sol::_setAutomatedMarketMakerPair() Automated market maker pair is already set to that value");

        automatedMarketMakerPairs[pair] = value;
        excludeFromCirculatingSupply(pair, value);

        emit SetAutomatedMarketMakerPair(pair, value);
    }


    // ~ View ~

    function getCirculatingMinusReserve() external view returns(uint256 circulating) {
        circulating = totalSupply() - (balanceOf(DEAD_ADDRESS) + balanceOf(address(0)));
        for (uint8 i; i < excludedFromCirculatingSupply.length;) {
            circulating = circulating - balanceOf(excludedFromCirculatingSupply[i]);
            unchecked {
                ++i;
            }
        }
    }


    // ~ onlyOwner ~

    function addPartnerOrExchange(address _partnerOrExchangeAddress) external onlyOwner {
        isExcludedFromFees[_partnerOrExchangeAddress] = true;
    }
    
    function updateOperationsWallet(address _newWallet) external onlyOwner {
        require(_newWallet != operationsWallet, "PureToken.sol::updateOperationsWallet() address is already set");

        isExcludedFromFees[_newWallet] = true;
        operationsWallet = _newWallet;

        emit operationsWalletUpdated(operationsWallet, _newWallet);
    }
    
    function updateMarketingWallet(address _newWallet) external onlyOwner {
        require(_newWallet != marketingWallet, "PureToken.sol::updateMarketingWallet() address is already set");

        isExcludedFromFees[_newWallet] = true;
        marketingWallet = _newWallet;

        emit MarketingWalletUpdated(marketingWallet, _newWallet);
    }
    
    function updateSwapTokensAtAmount(uint256 _swapAmount) external onlyOwner {
        swapTokensAtAmount = _swapAmount * (10**18);
    }
    
    function enableTrading() external onlyOwner {
        require(!tradingIsEnabled, "PureToken.sol::enableTrading() trading is already enabled");

        operationsFee = 40;
        marketingFee = 40;
        devFee = 20;

        buyTax = 5;
        sellTax = 5;
        txTax = 5;

        maxWallet = totalSupply() * 2 / 100; // TODO: Check
        swapTokensAtAmount = 20_000 * (10**18); // TODO: Config
        tradingIsEnabled = true;

        emit TradingEnabled();
    }
    
    function updateRoyalties(uint8 _operationsFee, uint8 _marketingFee, uint8 _devFee) external onlyOwner {
        require(_operationsFee + _marketingFee + _devFee == 40, "PureToken.sol::updateFees() sum of fees must be 100");
        
        operationsFee = _operationsFee;
        marketingFee = _marketingFee;
        devFee = _devFee;

        emit RoyaltiesUpdated(_operationsFee, _marketingFee, _devFee);
    }

    function updateBuyTax(uint8 _buyTax) external onlyOwner {
        require(_buyTax <= 20, "PuteToken.sol::updateBuyTax() buy tax must not be greater than 20%");

        emit BuyTaxUpdated(buyTax, _buyTax);

        buyTax = _buyTax;
    }

    function updateSellTax(uint8 _sellTax) external onlyOwner {
        require(_sellTax <= 20, "PuteToken.sol::updateSellTax() sell tax must not be greater than 20%");

        emit SellTaxUpdated(sellTax, _sellTax);

        sellTax = _sellTax;
    }

    function updateTransferTax(uint8 _txTax) external onlyOwner {
        require(_txTax <= 20, "PuteToken.sol::updateTransferTax() transfer tax must not be greater than 20%");

        emit TransferTaxUpdated(txTax, _txTax);

        txTax = _txTax;
    }
    
    function updateUniswapV2Router(address newAddress) external onlyOwner {
        require(newAddress != address(uniswapV2Router), "PureToken.sol::UpdatedUniswapV2Router() the router already has that address");

        uniswapV2Router = IUniswapV2Router02(newAddress);
    }

    function excludeFromFees(address account, bool excluded) external onlyOwner {
        isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function modifyBlacklist(address account, bool blacklisted) external onlyOwner {
        isBlacklisted[account] = blacklisted;
    }

    function isExcludedFromCirculatingSupply(address _address) public view returns(bool, uint8) {
        for (uint8 i; i < excludedFromCirculatingSupply.length;){
            if (_address == excludedFromCirculatingSupply[i]) {
                return (true, i);
            }
            unchecked {
                ++i;
            }
        }
        return (false, 0);
    }

    function excludeFromCirculatingSupply(address account, bool excluded) public onlyOwner {
        (bool _isExcluded, uint8 i) = isExcludedFromCirculatingSupply(account);
        require(_isExcluded != excluded, "PureToken.sol::excludeFromCirculatingSupply() account already set to that boolean value");

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
        require(pair != uniswapV2Pair, "PureToken.sol::setAutomatedMarketMakerPair() the PancakeSwap pair cannot be removed from automatedMarketMakerPairs");
        _setAutomatedMarketMakerPair(pair, value);
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        isExcludedFromFees[newOwner] = true;
        _transferOwnership(newOwner);
    }

    /// @notice Withdraw a PureToken from the treasury.
    /// @dev    Only callable by owner.
    /// @param  _token The token to withdraw from the treasury.
    function safeWithdraw(address _token) external onlyOwner {
        uint256 amount = IERC20(_token).balanceOf(address(this));
        require(amount > 0, "PureToken.sol::safeWithdraw() Insufficient token balance");
        require(_token != address(this), "PureToken.sol::safeWithdraw() cannot remove $Pure from this contract");

        assert(IERC20(_token).transfer(msg.sender, amount));

        emit Erc20TokenWithdrawn(_token, amount);
    }

}