pragma solidity ^0.5.16;

//奖励分配接收者
contract RewardsDistributionRecipient {
    address public rewardsDistribution; //存储factory合约地址

    function notifyRewardAmount(uint256 reward) external;

    modifier onlyRewardsDistribution() {
        require(msg.sender == rewardsDistribution, 'Caller is not RewardsDistribution contract');
        _;
    }
}
