// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

// IUniswapV2接口路由器
interface IUniswapV2Router {
    // 获取WETH地址
    function factory() external pure returns (address);
    // 获取工厂合约地址
    function WETH() external pure returns (address);

    // 代币兑换ETH
    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    // 添加ETH-ERC20流动性
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    // 支持税费的代币兑换
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract MyMeme is ERC20, Ownable {
    using Address for address payable;

    // 代币税配置
    uint256 public constant TAX_DENOMINATOR = 10000;
    uint256 public buyTax = 500;  // 5%
    uint256 public sellTax = 500; // 5%
    uint256 public transferTax = 200; // 2%
    
    address public taxWallet;   //税钱包
    address public marketingWallet; //营销性钱包
    address public liquidityWallet; //流动性钱包
    
    // 交易限制
    uint256 public maxTxAmount; //最大交易量
    uint256 public maxWalletAmount; //最大持币量
    uint256 public dailySellLimit;  //每日卖出限额
    uint256 public sellCooldown = 1 hours;  //卖出冷却时间
    
    mapping(address => uint256) public lastSellTime;  //上一次卖出时间
    mapping(address => uint256) public dailySellAmount;  //每日卖出数量
    mapping(address => uint256) public lastSellDate;  //上一次卖出日期
    
    // 流动性池相关
    IUniswapV2Router public uniswapV2Router;
    address public uniswapV2Pair;
    
    bool private swapping;  // 防重入保护标志
    bool public tradingEnabled; //交易开关状态变量:控制代币交易是否开启
    uint256 public liquidityAddTimestamp; //流动性池添加时间戳
    
    // 黑名单和豁免名单
    mapping(address => bool) public isBlacklisted;  //黑名单
    mapping(address => bool) public isExcludedFromTax;  // 豁免名单
    mapping(address => bool) public isExcludedFromLimit;    // 限制豁免名单
    
    // 事件
    event TaxesUpdated(uint256 buyTax, uint256 sellTax, uint256 transferTax);   // 税费更新事件
    event TradingEnabled(); //交易启用事件
    event LiquidityAdded(uint256 tokenAmount, uint256 ethAmount, uint256 liquidity); // 流动性添加事件
    event BlacklistUpdated(address indexed account, bool excluded);// 黑名单更新事件
    event TaxDistribution(uint256 marketingAmount, uint256 liquidityAmount, uint256 taxWalletAmount);// 税费分配事件
    
    modifier onlyExchange() {
        require(msg.sender == address(uniswapV2Router) || msg.sender == uniswapV2Pair, 
                "Caller is not the exchange");
        _;
    }

    constructor(
        address routerAddress
    ) ERC20("MyMeme", "MMM") Ownable(msg.sender) {
        // 初始总供应量
        uint256 _totalSupply = 100000000 * 1e18;
        _mint(msg.sender, _totalSupply);
        
        // 初始化钱包地址
        taxWallet = msg.sender;
        marketingWallet = msg.sender;
        liquidityWallet = msg.sender;
        
        // 设置交易限制（初始为总供应量的2%）
        maxTxAmount = _totalSupply  / 50; // 2%
        maxWalletAmount = _totalSupply / 50; // 2%
        dailySellLimit = _totalSupply  / 100; // 1%
        
        // 初始化Uniswap路由
        IUniswapV2Router _uniswapV2Router = IUniswapV2Router(routerAddress);
        uniswapV2Router = _uniswapV2Router;
        
        // 创建交易对
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        
        // 设置豁免
        isExcludedFromTax[msg.sender] = true;
        isExcludedFromTax[address(this)] = true;
        isExcludedFromTax[taxWallet] = true;
        isExcludedFromTax[marketingWallet] = true;
        
        isExcludedFromLimit[msg.sender] = true;
        isExcludedFromLimit[address(this)] = true;
    }

    // 代币税核心功能
    function _update(address from, address to, uint256 amount) internal override {
        require(!isBlacklisted[from] && !isBlacklisted[to], "Account blacklisted");
        
        if (!tradingEnabled) {
            require(isExcludedFromTax[from] || isExcludedFromTax[to], "Trading not enabled");
        }
        
        // 应用交易限制
        if (!isExcludedFromLimit[from] && !isExcludedFromLimit[to]) {
            _applyTradingLimits(from, to, amount);
        }
        
        // 处理税费
        uint256 taxAmount = 0;
        if (!swapping && !isExcludedFromTax[from] && !isExcludedFromTax[to]) {
            taxAmount = _calculateTax(from, to, amount);
        }
        
        if (taxAmount > 0) {
            super._update(from, address(this), taxAmount);
            amount -= taxAmount;
            
            // 处理累积的税费
            _processAccumulatedTax();
        }
        
        super._update(from, to, amount);
    }
    
    function _calculateTax(address from, address to, uint256 amount) internal view returns (uint256) {
        if (from == uniswapV2Pair) {
            // 买入
            return amount * buyTax / TAX_DENOMINATOR;
        } else if (to == uniswapV2Pair) {
            // 卖出
            return amount * sellTax / TAX_DENOMINATOR;
        } else {
            // 普通转账
            return amount * transferTax / TAX_DENOMINATOR;
        }
    }
    
    function _applyTradingLimits(address from, address to, uint256 amount) internal {
        // 最大交易量限制
        if (from == uniswapV2Pair || to == uniswapV2Pair) {
            require(amount <= maxTxAmount, "Exceeds max transaction amount");
        }
        
        // 最大持币量限制
        if (to != uniswapV2Pair && to != address(uniswapV2Router)) {
            require(balanceOf(to) + amount <= maxWalletAmount, "Exceeds max wallet amount");
        }
        
        // 卖出限制
        if (to == uniswapV2Pair) {
            _applySellLimits(from, amount);
        }
    }
    
    function _applySellLimits(address seller, uint256 amount) internal {
        // 卖出冷却时间
        require(block.timestamp >= lastSellTime[seller] + sellCooldown, "Sell cooldown active");
        lastSellTime[seller] = block.timestamp;
        
        // 每日卖出限额
        uint256 today = block.timestamp / 1 days;
        if (lastSellDate[seller] != today) {
            dailySellAmount[seller] = 0;
            lastSellDate[seller] = today;
        }
        
        dailySellAmount[seller] += amount;
        require(dailySellAmount[seller] <= dailySellLimit, "Exceeds daily sell limit");
    }
    
    function _processAccumulatedTax() internal {
        uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwap = contractTokenBalance >= (totalSupply() * 10 / TAX_DENOMINATOR); // 0.1% of supply
        
        if (canSwap && !swapping) {
            swapping = true;
            
            // 分配税费
            uint256 totalTax = contractTokenBalance;
            uint256 marketingAmount = totalTax * 40 / 100; // 40% to marketing
            uint256 liquidityAmount = totalTax * 30 / 100; // 30% to liquidity
            uint256 taxWalletAmount = totalTax * 30 / 100; // 30% to tax wallet
            
            // 营销钱包直接转账
            if (marketingAmount > 0) {
                super._update(address(this), marketingWallet, marketingAmount);
            }
            
            // 税钱包直接转账
            if (taxWalletAmount > 0) {
                super._update(address(this), taxWallet, taxWalletAmount);
            }
            
            // 流动性部分转换为ETH并添加流动性
            if (liquidityAmount > 0) {
                _swapAndAddLiquidity(liquidityAmount);
            }
            
            swapping = false;
            emit TaxDistribution(marketingAmount, liquidityAmount, taxWalletAmount);
        }
    }
    
    function _swapAndAddLiquidity(uint256 tokenAmount) internal {
        uint256 half = tokenAmount / 2;
        uint256 otherHalf = tokenAmount - half;
        
        // 将一半代币转换为ETH
        uint256 initialBalance = address(this).balance;
        _swapTokensForEth(half);
        uint256 newBalance = address(this).balance - initialBalance;
        
        // 添加流动性
        _addLiquidity(otherHalf, newBalance);
    }
    
    function _swapTokensForEth(uint256 tokenAmount) internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }
    
    function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) internal {
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            liquidityWallet,
            block.timestamp
        );
        
        emit LiquidityAdded(tokenAmount, ethAmount, 0);
    }

    // 流动性池集成功能
    function addLiquidity(uint256 tokenAmount) external payable onlyOwner {
        require(msg.value > 0, "Must send ETH");
        
        _approve(msg.sender, address(uniswapV2Router), tokenAmount);
        
        uniswapV2Router.addLiquidityETH{value: msg.value}(
            address(this),
            tokenAmount,
            0,
            0,
            msg.sender,
            block.timestamp
        );
        
        liquidityAddTimestamp = block.timestamp;
        tradingEnabled = true;
        emit TradingEnabled();
        emit LiquidityAdded(tokenAmount, msg.value, 0);
    }
    
    function removeTradingRestrictions() external onlyOwner {
        maxTxAmount = totalSupply();
        maxWalletAmount = totalSupply();
        dailySellLimit = totalSupply();
        sellCooldown = 0;
    }

    // 管理功能
    function setTaxes(uint256 _buyTax, uint256 _sellTax, uint256 _transferTax) external onlyOwner {
        require(_buyTax <= 1000 && _sellTax <= 1000 && _transferTax <= 500, "Tax too high");
        buyTax = _buyTax;
        sellTax = _sellTax;
        transferTax = _transferTax;
        emit TaxesUpdated(_buyTax, _sellTax, _transferTax);
    }
    
    function setWallets(address _taxWallet, address _marketingWallet, address _liquidityWallet) external onlyOwner {
        taxWallet = _taxWallet;
        marketingWallet = _marketingWallet;
        liquidityWallet = _liquidityWallet;
    }
    
    function setTradingLimits(uint256 _maxTxAmount, uint256 _maxWalletAmount, uint256 _dailySellLimit) external onlyOwner {
        maxTxAmount = _maxTxAmount;
        maxWalletAmount = _maxWalletAmount;
        dailySellLimit = _dailySellLimit;
    }
    
    function setBlacklist(address account, bool excluded) external onlyOwner {
        isBlacklisted[account] = excluded;
        emit BlacklistUpdated(account, excluded);
    }
    
    function setExcludedFromTax(address account, bool excluded) external onlyOwner {
        isExcludedFromTax[account] = excluded;
    }
    
    function setExcludedFromLimit(address account, bool excluded) external onlyOwner {
        isExcludedFromLimit[account] = excluded;
    }
    
    function enableTrading() external onlyOwner {
        tradingEnabled = true;
        emit TradingEnabled();
    }

    // 工具函数
    function getCirculatingSupply() public view returns (uint256) {
        return totalSupply() - balanceOf(address(0xdead));
    }
    
    receive() external payable {}
}