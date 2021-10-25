//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./libraries/LongTermOrders.sol";

///@notice TWAMM -- https://www.paradigm.xyz/2021/07/twamm/
contract TWAMM is ERC20 {
    using LongTermOrders for LongTermOrders.LTOrders;

    address public tokenA;
    address public tokenB;

    ///@notice map token addresses to current reserves
    mapping(address => uint256) reserveMap;

    uint256 public constant INITIAL_LP_TOKEN_AMOUNT = 1_000_000_000;
    ///@notice fee for LP providers, 4 decimal places, i.e. 30 = 0.3%
    uint256 public constant LP_FEE = 30;

    ///@notice block interval in which orders can expire
    uint256 public constant ORDER_BLOCK_INTERVAL = 200;

    ///@notice last virtual orders were executed immediately before this block
    uint256 public lastVirtualOrderBlock;

    LongTermOrders.LTOrders internal longTermOrders;


    constructor(string memory _name
                ,string memory _symbol
                ,address _tokenA
                ,address _tokenB
    ) ERC20(_name, _symbol) {
        
        tokenA = _tokenA;
        tokenB = _tokenB;
        longTermOrders.initialize(_tokenA, _tokenB, block.number, ORDER_BLOCK_INTERVAL);

    }

    //initial liquidity provision, where price is determined by token amounts
    function provideInitialLiquidity(uint256 amountA, uint256 amountB) external {
        require(totalSupply() == 0, 'liquidity has already been provided, need to call provideLiquidity');
        //transfer tokens
        ERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        ERC20(tokenB).transferFrom(msg.sender, address(this), amountB);
        //update reserves
        reserveMap[tokenA] = amountA;
        reserveMap[tokenB] = amountB;
        //mint LP tokens
        _mint(msg.sender, INITIAL_LP_TOKEN_AMOUNT);
    }

    //provide liquidity to embedded amm
    function provideLiquidity(uint256 lpTokenAmount) external {
        require(totalSupply() != 0, 'no liquidity has been provided yet, need to call provideInitialLiquidity');
        //calculate amount of tokens that need to be transfered to create LP tokens
        uint256 amountAIn = lpTokenAmount * reserveMap[tokenA] / totalSupply();
        uint256 amountBIn = lpTokenAmount * reserveMap[tokenB] / totalSupply();

        ERC20(tokenA).transferFrom(msg.sender, address(this), amountAIn);
        ERC20(tokenB).transferFrom(msg.sender, address(this), amountBIn);

        reserveMap[tokenA] += amountAIn;
        reserveMap[tokenB] += amountBIn;

        _mint(msg.sender, lpTokenAmount);
    }

    // remove liquidity from embedded amm
    function removeLiquidity(uint256 lpTokenAmount) external {
        require(lpTokenAmount <= totalSupply(), 'not enough lp tokens available');

        uint256 amountAOut = reserveMap[tokenA] * lpTokenAmount / totalSupply();
        uint256 amountBOut = reserveMap[tokenB] * lpTokenAmount / totalSupply();

        ERC20(tokenA).transfer(msg.sender, amountAOut);
        ERC20(tokenB).transfer(msg.sender, amountBOut);

        reserveMap[tokenA] -= amountAOut;
        reserveMap[tokenB] -= amountBOut;

        _burn(msg.sender, lpTokenAmount);
    }

    function swapFromAToB(uint256 amountA) external {
        performSwap(tokenA, tokenB, amountA);
    }

    function swapFromBToA(uint256 amountB) external {
         performSwap(tokenB, tokenA, amountB);
    }

    function performSwap(address from, address to, uint256 amountIn) private {
        require(amountIn > 0, 'swap amount must be positive');
        uint256 amountOut = reserveMap[to] * amountIn / (reserveMap[from] + amountIn);
        uint256 amountOutMinusFee = amountOut * (10000 - LP_FEE) / 10000;
        
        ERC20(from).transferFrom(msg.sender, address(this), amountIn);  
        ERC20(to).transfer(msg.sender, amountOutMinusFee);

        reserveMap[from] += amountIn;
        reserveMap[to] -= amountOutMinusFee;
    }

    function tokenAReserves() public view returns (uint256) {
        return reserveMap[tokenA];
    }

    function tokenBReserves() public view returns (uint256) {
        return reserveMap[tokenB];
    }

    
}
