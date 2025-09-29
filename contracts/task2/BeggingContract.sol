// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
/*
使用 Solidity 编写一个合约，允许用户向合约地址发送以太币。
记录每个捐赠者的地址和捐赠金额。
允许合约所有者提取所有捐赠的资金。
*/
contract BeggingContract is Ownable{
    //捐赠者总额
    mapping(address donor => uint) private donors;
    uint256 private _donorCount;    //捐赠者数量
    //捐赠者对象
    struct DonorInfo {
        address donor;
        uint256 amount;
    }
    //捐赠者排序
    DonorInfo[] private arrDonors;
    uint256 private _startTime;
    uint256 private _endTime;
    //是否启用时间限制
    bool private isDonationPeriodActive;    
    
    // 事件：当有新的捐赠时触发
    event DonationReceived(address indexed donor, uint256 amount);
    
    // 事件：当所有者提取资金时触发
    event FundsWithdrawn(address indexed owner, uint256 amount);

    // 事件：当捐赠时间段更新时触发
    event DonationPeriodUpdated(uint256 startTime, uint256 endTime, bool isActive);

    constructor() Ownable(msg.sender){
    }
    //启用时间段捐赠
    function openDonationTime(uint256 startTime,uint256 endTime) external onlyOwner{
        require(endTime > startTime ,"The end time must be greater than the start time");
        require(block.timestamp < endTime, "The end time must be greater than the current time");
        _startTime = startTime;
        _endTime = endTime;
        isDonationPeriodActive =true;
        emit DonationPeriodUpdated(startTime,endTime,true);
    }
    //关闭时间段捐赠
    function closeDonationTime() external onlyOwner{
        if(!isDonationPeriodActive){
            isDonationPeriodActive = false;
            emit DonationPeriodUpdated(_startTime,_endTime,false);
        }
    }
    function getNowTime() external view returns (uint256){
        return block.timestamp;
    }
    modifier donationTime(){
        if(isDonationPeriodActive){
            require(_startTime <= block.timestamp,"The donation deadline has not yet arrived");
            require(_endTime >= block.timestamp,"The donation period has ended");
        }
        _;
    }

    function donate() external payable donationTime{
        require(msg.value > 0, "Donation amount must be greater than 0");
        if(donors[msg.sender] == 0){
            _donorCount++;
            arrDonors.push(DonorInfo({
                donor: msg.sender,
                amount: msg.value
            }));
        }
        donors[msg.sender] += msg.value;
        emit DonationReceived(msg.sender, msg.value);
    }
    function withdraw() external onlyOwner{
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        address myowner = owner();
        payable(myowner).transfer(balance);
        emit FundsWithdrawn(myowner, balance);
    }
    function getDonation(address donor) external view returns (uint){
        return donors[donor];
    }
    function sortDonation() internal {
        for(uint i = 0; i < _donorCount; i++){
            arrDonors[i].amount = donors[arrDonors[i].donor];
        }
        for(uint i = 0; i < _donorCount; i++){
            for(uint j = i+1; j< _donorCount; j++){
                if(arrDonors[i].amount < arrDonors[j].amount){
                    DonorInfo memory temp = arrDonors[i];
                    arrDonors[i] = arrDonors[j];
                    arrDonors[j] = temp;
                }
            }
        }
    }
    function getTopDonors(uint256 topN) external returns (DonorInfo[] memory){
        require(topN != 0, "Invalid topN value");
        sortDonation();
         // 返回前topN名
        uint256 resultCount = topN < _donorCount ? topN : _donorCount;
        DonorInfo[] memory topDonors = new DonorInfo[](resultCount);
        for(uint i = 0; i < resultCount; i++) {
            topDonors[i] = arrDonors[i];
        }
        return topDonors;
    }
    function getTop3() external returns(DonorInfo[] memory){
        return this.getTopDonors(3);
    }
}