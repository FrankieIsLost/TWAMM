# TWAMM

## Introduction


An implementation of [TWAMM](https://www.paradigm.xyz/2021/07/twamm/), an AMM design by [@\_Dave\_\_White\_](https://twitter.com/_Dave__White_), [@danrobinson](https://twitter.com/danrobinson) and [@haydenzadams](https://twitter.com/haydenzadams). TWAMM allows market participants to efficiently execute large orders over multiple blocks. 

## Implementation Notes

### Overview 

`TWAMM.sol` directly implements most of the standard AMM functionality (liquidity provision, liquidity removal, and swapping). The logic for execution of long term orders is split across two libraries, `OrderPool.sol` and `LongTermOrders.sol`. 

### Order Pool 

The main abstraction for implementing long term orders is the `Order Pool`. The order pool represents a set of long term, which sell a given token to the embedded AMM at a constant rate. The token pool also handles the logic for the distribution of sales proceeds to the owners of the long term orders. 

The distribution of rewards is done through a modified version of algorithm from [Scalable Reward Distribution on the Ethereum Blockchain](https://uploads-ssl.webflow.com/5ad71ffeb79acc67c8bcdaba/5ad8d1193a40977462982470_scalable-reward-distribution-paper.pdf). Since order expiries are decopuled from reward distribution in the TWAMM model, the modified algorithm needs to keep track of additional parameters to compute rewards correctly. 

### Long term orders

In addition to the order pools, the `LongTermOrders` struct keep the state of the virtual order execution. Most importantly, it keep track of the last block where virtual orders were executed. Before every interaction with the embedded AMM, the state of virtual order execution is brought forward to the present block. We can do this efficiently because only certain blocks are eligible for virtual order expiry. Thus, we can advance the state by a full block interval in a single computation. Crucially, advancing the state of long term order execution is linear only in the number of block intervals since the last interaction with TWAMM, not linear in the number of orders. 

### Fixed Point Math

This implementation uses the [PBRMath Library](https://github.com/hifi-finance/prb-math) for fixed point arithmetic, in order to implement the closed form solution to settling long term trades. Efforts were made to make the computation numerically stable, but there's remaining work to be done here in order to ensure that the computation is correct for the full set of expected inputs. 