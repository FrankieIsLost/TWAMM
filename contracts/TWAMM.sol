//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@rari-capital/solmate/src/tokens/ERC20.sol";
import "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import "@rari-capital/solmate/src/utils/ReentrancyGuard.sol";
import "./libraries/LongTermOrders.sol";

///@notice TWAMM -- https://www.paradigm.xyz/2021/07/twamm/
contract TWAMM is ERC20, ReentrancyGuard {
    using LongTermOrdersLib for LongTermOrdersLib.LongTermOrders;
    using PRBMathUD60x18 for uint256;
    using SafeTransferLib for ERC20;

    /// ---------------------------
    /// ------ AMM Parameters -----
    /// ---------------------------
    
    ///@notice tokens that can be traded in the AMM
    address public tokenA;
    address public tokenB;
    
    ///@notice fee for LP providers, 4 decimal places, i.e. 30 = 0.3%
    uint256 public constant LP_FEE = 30;

    ///@notice map token addresses to current amm reserves
    mapping(address => uint256) reserveMap;

    /// ---------------------------
    /// -----TWAMM Parameters -----
    /// ---------------------------

    ///@notice interval between blocks that are eligible for order expiry 
    uint256 public orderBlockInterval;

    ///@notice data structure to handle long term orders  
    LongTermOrdersLib.LongTermOrders internal longTermOrders;

    /// ---------------------------
    /// --------- Events ----------
    /// ---------------------------

    ///@notice An event emitted when initial liquidity is provided 
    event InitialLiquidityProvided(address indexed addr, uint256 amountA, uint256 amountB);

    ///@notice An event emitted when liquidity is provided 
    event LiquidityProvided(address indexed addr, uint256 lpTokens);

    ///@notice An event emitted when liquidity is removed 
    event LiquidityRemoved(address indexed addr, uint256 lpTokens);

    ///@notice An event emitted when a swap from tokenA to tokenB is performed 
    event SwapAToB(address indexed addr, uint256 amountAIn, uint256 amountBOut);

    ///@notice An event emitted when a swap from tokenB to tokenA is performed 
    event SwapBToA(address indexed addr, uint256 amountBIn, uint256 amountAOut);

    ///@notice An event emitted when a long term swap from tokenA to tokenB is performed 
    event LongTermSwapAToB(address indexed addr, uint256 amountAIn, uint256 orderId);

    ///@notice An event emitted when a long term swap from tokenB to tokenA is performed 
    event LongTermSwapBToA(address indexed addr, uint256 amountBIn, uint256 orderId);

    ///@notice An event emitted when a long term swap is cancelled
    event CancelLongTermOrder(address indexed addr, uint256 orderId);

    ///@notice An event emitted when proceeds from a long term swap are withdrawm 
    event WithdrawProceedsFromLongTermOrder(address indexed addr, uint256 orderId);

    
    constructor(string memory _name
                ,string memory _symbol
                ,address _tokenA
                ,address _tokenB
                ,uint256 _orderBlockInterval
    ) ERC20(_name, _symbol, 18) {
        
        tokenA = _tokenA;
        tokenB = _tokenB;
        orderBlockInterval = _orderBlockInterval;
        longTermOrders.initialize(_tokenA, _tokenB, block.number, _orderBlockInterval);

    }

    ///@notice provide initial liquidity to the amm. This sets the relative price between tokens
    function provideInitialLiquidity(uint256 amountA, uint256 amountB) external nonReentrant {
        require(totalSupply == 0, 'liquidity has already been provided, need to call provideLiquidity');

        reserveMap[tokenA] = amountA;
        reserveMap[tokenB] = amountB;
        
        //initial LP amount is the geometric mean of supplied tokens
        uint256 lpAmount = amountA.fromUint().sqrt().mul(amountB.fromUint().sqrt()).toUint();
        _mint(msg.sender, lpAmount);

        ERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        ERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountB);

        emit InitialLiquidityProvided(msg.sender, amountA, amountB);
    }

    ///@notice provide liquidity to the AMM 
    ///@param lpTokenAmount number of lp tokens to mint with new liquidity  
    function provideLiquidity(uint256 lpTokenAmount) external nonReentrant {
        require(totalSupply != 0, 'no liquidity has been provided yet, need to call provideInitialLiquidity');

        //execute virtual orders 
        longTermOrders.executeVirtualOrdersUntilCurrentBlock(reserveMap);

        //the ratio between the number of underlying tokens and the number of lp tokens must remain invariant after mint 
        uint256 amountAIn = lpTokenAmount * reserveMap[tokenA] / totalSupply;
        uint256 amountBIn = lpTokenAmount * reserveMap[tokenB] / totalSupply;

        reserveMap[tokenA] += amountAIn;
        reserveMap[tokenB] += amountBIn;

        _mint(msg.sender, lpTokenAmount);

        ERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountAIn);
        ERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountBIn);
        
        emit LiquidityProvided(msg.sender, lpTokenAmount);
    }

    ///@notice remove liquidity to the AMM 
    ///@param lpTokenAmount number of lp tokens to burn
    function removeLiquidity(uint256 lpTokenAmount) external nonReentrant {
        require(lpTokenAmount <= totalSupply, 'not enough lp tokens available');

        //execute virtual orders 
        longTermOrders.executeVirtualOrdersUntilCurrentBlock(reserveMap);
        
        //the ratio between the number of underlying tokens and the number of lp tokens must remain invariant after burn 
        uint256 amountAOut = reserveMap[tokenA] * lpTokenAmount / totalSupply;
        uint256 amountBOut = reserveMap[tokenB] * lpTokenAmount / totalSupply;

        reserveMap[tokenA] -= amountAOut;
        reserveMap[tokenB] -= amountBOut;

        _burn(msg.sender, lpTokenAmount);

        ERC20(tokenA).safeTransfer(msg.sender, amountAOut);
        ERC20(tokenB).safeTransfer(msg.sender, amountBOut);

        emit LiquidityRemoved(msg.sender, lpTokenAmount);
    }

    ///@notice swap a given amount of TokenA against embedded amm 
    function swapFromAToB(uint256 amountAIn) external nonReentrant {
        uint256 amountBOut = performSwap(tokenA, tokenB, amountAIn);
        emit SwapAToB(msg.sender, amountAIn, amountBOut);
    }

    ///@notice create a long term order to swap from tokenA 
    ///@param amountAIn total amount of token A to swap 
    ///@param numberOfBlockIntervals number of block intervals over which to execute long term order
    function longTermSwapFromAToB(uint256 amountAIn, uint256 numberOfBlockIntervals) external nonReentrant {
        uint256 orderId =  longTermOrders.longTermSwapFromAToB(amountAIn, numberOfBlockIntervals, reserveMap);
        emit LongTermSwapAToB(msg.sender, amountAIn, orderId);
    }

    ///@notice swap a given amount of TokenB against embedded amm 
    function swapFromBToA(uint256 amountBIn) external nonReentrant {
        uint256 amountAOut = performSwap(tokenB, tokenA, amountBIn);
        emit SwapBToA(msg.sender, amountBIn, amountAOut);
    }

    ///@notice create a long term order to swap from tokenB 
    ///@param amountBIn total amount of tokenB to swap 
    ///@param numberOfBlockIntervals number of block intervals over which to execute long term order
    function longTermSwapFromBToA(uint256 amountBIn, uint256 numberOfBlockIntervals) external nonReentrant {
        uint256 orderId = longTermOrders.longTermSwapFromBToA(amountBIn, numberOfBlockIntervals, reserveMap);
        emit LongTermSwapBToA(msg.sender, amountBIn, orderId);
    }

    ///@notice stop the execution of a long term order 
    function cancelLongTermSwap(uint256 orderId) external nonReentrant {
        longTermOrders.cancelLongTermSwap(orderId, reserveMap);
        emit CancelLongTermOrder(msg.sender, orderId);
    }

    ///@notice withdraw proceeds from a long term swap 
    function withdrawProceedsFromLongTermSwap(uint256 orderId) external nonReentrant {
        longTermOrders.withdrawProceedsFromLongTermSwap(orderId, reserveMap);
        emit WithdrawProceedsFromLongTermOrder(msg.sender, orderId);
    }

    ///@notice private function which implements swap logic 
    function performSwap(address from, address to, uint256 amountIn) private returns (uint256 amountOutMinusFee) {
        require(amountIn > 0, 'swap amount must be positive');

        //execute virtual orders 
        longTermOrders.executeVirtualOrdersUntilCurrentBlock(reserveMap);

        //constant product formula
        uint256 amountOut = reserveMap[to] * amountIn / (reserveMap[from] + amountIn);
        //charge LP fee
        amountOutMinusFee = amountOut * (10000 - LP_FEE) / 10000;
        
        reserveMap[from] += amountIn;
        reserveMap[to] -= amountOutMinusFee;

        ERC20(from).safeTransferFrom(msg.sender, address(this), amountIn);  
        ERC20(to).safeTransfer(msg.sender, amountOutMinusFee);
    }

    ///@notice get tokenA reserves
    function tokenAReserves() public view returns (uint256) {
        return reserveMap[tokenA];
    }

    ///@notice get tokenB reserves
    function tokenBReserves() public view returns (uint256) {
        return reserveMap[tokenB];
    }

    ///@notice convenience function to execute virtual orders. Note that this already happens
    ///before most interactions with the AMM 
    function executeVirtualOrders() public {
        longTermOrders.executeVirtualOrdersUntilCurrentBlock(reserveMap);
    }

    
}
