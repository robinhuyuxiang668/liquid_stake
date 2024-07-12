pragma solidity ^0.5.16;

import 'openzeppelin-solidity-2.3.0/contracts/token/ERC20/IERC20.sol';
import 'openzeppelin-solidity-2.3.0/contracts/ownership/Ownable.sol';

import './StakingRewards.sol';

contract StakingRewardsFactory is Ownable {
    // immutables
    address public rewardsToken;
    uint public stakingRewardsGenesis; //质押挖矿开始的时间

    // 质押代币数组，实现多挖
    address[] public stakingTokens;

    // info about rewards for a particular staking token
    struct StakingRewardsInfo {
        address stakingRewards; // 质押代币转入的StakingRewards合约地址
        uint rewardAmount; // 质押合约每周期的奖励总量
    }

    // 质押代币和质押合约信息之间的映射
    mapping(address => StakingRewardsInfo) public stakingRewardsInfoByStakingToken;

    constructor(address _rewardsToken, uint _stakingRewardsGenesis) public Ownable() {
        //质押挖矿开始的时间 必须大于当前时间
        require(_stakingRewardsGenesis >= block.timestamp, 'StakingRewardsFactory::constructor: genesis too soon');

        rewardsToken = _rewardsToken;
        stakingRewardsGenesis = _stakingRewardsGenesis;
    }

    ///// permissioned functions

    // 为质押代币部署质押奖励合约，并存储奖励金额
    // 奖励将在创世后分配给质押奖励合约
    //stakingToken 就是质押代币，在Uniswap中为 LPToken，在自己的Dapp中可以改成erc20 token。rewardAmount 则是奖励数量
    function deploy(address stakingToken, uint rewardAmount) public onlyOwner {
        StakingRewardsInfo storage info = stakingRewardsInfoByStakingToken[stakingToken];
        //质押代币转入的StakingRewards合约地址 必须是0 说明还没部署过
        require(info.stakingRewards == address(0), 'StakingRewardsFactory::deploy: already deployed');

        info.stakingRewards = address(
            new StakingRewards(/*_rewardsDistribution=*/ address(this), rewardsToken, stakingToken)
        );
        info.rewardAmount = rewardAmount;
        stakingTokens.push(stakingToken);
    }

    ///// permissionless functions

    // 为所有质押代币调用notifyRewardAmount。
    function notifyRewardAmounts() public {
        require(stakingTokens.length > 0, 'StakingRewardsFactory::notifyRewardAmounts: called before any deploys');
        for (uint i = 0; i < stakingTokens.length; i++) {
            notifyRewardAmount(stakingTokens[i]);
        }
    }

    // 将奖励代币转入到质押合约中, 前提是需要先将用来挖矿奖励的代币先转入该工厂合约。
    //有个这个前提，工厂合约的该函数才能实现将 UNI 代币下发到质押合约中去。
    function notifyRewardAmount(address stakingToken) public {
        require(block.timestamp >= stakingRewardsGenesis, 'StakingRewardsFactory::notifyRewardAmount: not ready');

        StakingRewardsInfo storage info = stakingRewardsInfoByStakingToken[stakingToken];
        require(info.stakingRewards != address(0), 'StakingRewardsFactory::notifyRewardAmount: not deployed');

        if (info.rewardAmount > 0) {
            uint rewardAmount = info.rewardAmount;
            info.rewardAmount = 0;

            require(
                IERC20(rewardsToken).transfer(info.stakingRewards, rewardAmount),
                'StakingRewardsFactory::notifyRewardAmount: transfer failed'
            );
            StakingRewards(info.stakingRewards).notifyRewardAmount(rewardAmount);
        }
    }
}
