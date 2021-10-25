const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TWAMM", function () {
   
    let tokenA;
    let tokenB;

    let twamm;

    let owner;
    let addr1;
    let addr2;
    let addrs;

    const initialLPTokenAmount = ethers.BigNumber.from("1000000000"); // 1,000,000,000
    const initialLiquidityProvided = ethers.BigNumber.from("10000000"); // 10,000,000
    const ERC20Supply = ethers.BigNumber.from("1000000000") // 1,000,000,000

    beforeEach(async function () {

        [owner, addr1, addr2, ...addrs] = await ethers.getSigners();


        const ERC20Factory =  await ethers.getContractFactory("ERC20Mock");
        tokenA = await ERC20Factory.deploy("TokenA", "TokenA", ERC20Supply);
        tokenB = await ERC20Factory.deploy("TokenB", "TokenB", ERC20Supply);

        const longTermOrdersFactory = await ethers.getContractFactory("LongTermOrders");
        const longTermOrders = await longTermOrdersFactory.deploy();
        const TWAMMFactory = await ethers.getContractFactory("TWAMM", {
            libraries: {
                LongTermOrders: longTermOrders.address,
            }
        });

        twamm = await TWAMMFactory.deploy(
              "TWAMM" 
            , "TWAMM"
            , tokenA.address
            , tokenB.address);

        tokenA.approve(twamm.address, ERC20Supply);
        tokenB.approve(twamm.address, ERC20Supply);

        await twamm.provideInitialLiquidity(initialLiquidityProvided,initialLiquidityProvided);
    });

    describe("AMM Functionality", function () {

        describe("Providing Liquidity", function () {

            it("Should mint correct number of LP tokens", async function () {

                const LPBalance = await twamm.balanceOf(owner.address);

                expect(LPBalance).to.eq(initialLPTokenAmount);
            });

            it("LP token value is constant after mint", async function () {
                
                let totalSupply = await twamm.totalSupply();
                
                let tokenAReserve = await twamm.tokenAReserves();
                let tokenBReserve = await twamm.tokenBReserves();

                const initialTokenAPerLP = tokenAReserve / totalSupply;
                const initialTokenBPerLP = tokenBReserve / totalSupply;

                await twamm.provideLiquidity(initialLPTokenAmount);

                totalSupply = await twamm.totalSupply();
                
                tokenAReserve = await twamm.tokenAReserves();
                tokenBReserve = await twamm.tokenBReserves();

                const finalTokenAPerLP = tokenAReserve / totalSupply;
                const finalTokenBPerLP = tokenBReserve / totalSupply;

                expect(finalTokenAPerLP).to.eq(initialTokenAPerLP);
                expect(finalTokenBPerLP).to.eq(initialTokenBPerLP);
            });
        });

        describe("Removing Liquidity", function () {

            it("LP token value is constant after removing", async function () {
                
                let totalSupply = await twamm.totalSupply();
                
                let tokenAReserve = await twamm.tokenAReserves();
                let tokenBReserve = await twamm.tokenBReserves();

                const initialTokenAPerLP = tokenAReserve / totalSupply;
                const initialTokenBPerLP = tokenBReserve / totalSupply;

                await twamm.removeLiquidity(initialLPTokenAmount / 2);

                totalSupply = await twamm.totalSupply();
                
                tokenAReserve = await twamm.tokenAReserves();
                tokenBReserve = await twamm.tokenBReserves();

                const finalTokenAPerLP = tokenAReserve / totalSupply;
                const finalTokenBPerLP = tokenBReserve / totalSupply;

                expect(finalTokenAPerLP).to.eq(initialTokenAPerLP);
                expect(finalTokenBPerLP).to.eq(initialTokenBPerLP);
            });
        });
    });

    describe("Swapping", function () {

        it("swaps expected amount", async function () {
            const amountInA = ethers.BigNumber.from(1000000);
            const tokenAReserve = await twamm.tokenAReserves();
            const tokenBReserve = await twamm.tokenBReserves();
            const expectedOutBeforeFees = 
                tokenBReserve
                    .mul(amountInA)
                    .div(tokenAReserve.add(amountInA));
            //adjust for LP fee of 0.3%
            const expectedOutput = expectedOutBeforeFees.mul(1000 - 3).div(1000);
            
            const beforeBalanceB = await tokenB.balanceOf(owner.address);
            await twamm.swapFromAToB(amountInA);
            const afterBalanceB = await tokenB.balanceOf(owner.address);
            const actualOutput = afterBalanceB.sub(beforeBalanceB);

            expect(actualOutput).to.eq(expectedOutput);
        
        });
    });
});

