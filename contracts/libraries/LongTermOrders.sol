//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


library LongTermOrders {

    struct LTOrders {
        
        ///@notice minimum block interval between order expiries 
        uint256 orderBlockInterval;

        ///@notice last virtual orders were executed immediately before this block
        uint256 lastVirtualOrderBlock;

        address tokenA;
        address tokenB;

        // mapping from token address to pool that is selling that token 
        mapping(address => TokenPool) tokenPoolMap;
    }

    // token pools sell a token at a certain rate to buy the other token
    struct TokenPool {
        ///@notice current sales rate per block
        uint256 salesRate;

        ///@notice total amount of token bought by the pool 
        uint256 boughtTokenReserves;

        ///@notice how much the sales rate will decline from orders expiring per block
        mapping(uint256 => uint256) salesRateEndingPerBlock;
    }

    function initialize(LTOrders storage self
                        , address tokenA
                        , address tokenB
                        , uint256 lastVirtualOrderBlock
                        , uint256 orderBlockInterval) public {
        self.tokenA = tokenA;
        self.tokenB = tokenB;
        self.lastVirtualOrderBlock = lastVirtualOrderBlock;
        self.orderBlockInterval = orderBlockInterval;
    }

    function longTermSwapFromAToB(LTOrders storage self, uint256 amountA, uint256 numberOfBlockIntervals) public {
        performLongTermSwap(self, self.tokenA, amountA, numberOfBlockIntervals);
    }

    function longTermSwapFromBToA(LTOrders storage self, uint256 amountB, uint256 numberOfBlockIntervals) public {
         performLongTermSwap(self, self.tokenB, amountB, numberOfBlockIntervals);
    }

    function performLongTermSwap(LTOrders storage self, address from, uint256 amount, uint256 numberOfBlockIntervals) private {
        // transfer sale amount to contract
        ERC20(from).transferFrom(msg.sender, address(this), amount);
        uint256 currentBlock = block.number;
        uint256 lastExpiryBlock = currentBlock - (currentBlock % self.orderBlockInterval);
        // the block number in which the current sale order will expire
        uint256 currentOrderExpiryBlock = self.orderBlockInterval * (numberOfBlockIntervals + 1) + lastExpiryBlock;
        //selling rate per block 
        uint256 sellingRate = amount / (currentOrderExpiryBlock - currentBlock);
        //add to token pool
        self.tokenPoolMap[from].salesRate += sellingRate;
        self.tokenPoolMap[from].salesRateEndingPerBlock[currentOrderExpiryBlock] += sellingRate;
    }

    function executeVirtualOrders(LTOrders storage self, mapping(address => uint256) storage reserveMap) private {
        //last virtual order execution
        uint256 blockNumber = self.lastVirtualOrderBlock;
        //next possible expiry
        blockNumber = blockNumber - (blockNumber % self.orderBlockInterval) + self.orderBlockInterval;
        //go through order expiries 
        while(blockNumber < block.number) {

        }

    }

    function updateVirtualBalances(LTOrders storage self
        , mapping(address => uint256) storage reserveMap
        , uint256 tokenAIn
        , uint256 tokenBIn) private
    {
        uint256 k = reserveMap[self.tokenA] * reserveMap[self.tokenB];
        
    }

  
}