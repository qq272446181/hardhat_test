// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Voting{
   //一个mapping来存储候选人的得票数
    mapping(string => uint) private votesReceived; //候选人票数
    string[] private candidateList; //选举人列表
    constructor(){
        candidateList = ["user1","user2","user3"];
    }
    //一个vote函数，允许用户投票给某个候选人
    function vote(string memory candidate) public {
        votesReceived[candidate] += 1;
    }
    //一个getVotes函数，返回某个候选人的得票数
    function getVotes(string memory candidate) public view returns (uint) {
        require(isCandidate(candidate),"candidate is not found.");
        return votesReceived[candidate];
    }
    //一个resetVotes函数，重置所有候选人的得票数
    function resetVotes() public {
        for(uint i=0;i<candidateList.length; i++) { 
            votesReceived[candidateList[i]] = 0;
        }
    }
    //判断候选人是否存在
    function isCandidate(string memory candidate) private view returns (bool) {
        for(uint i=0;i<candidateList.length;i++){
            if(keccak256(bytes(candidateList[i])) == keccak256(bytes(candidate))){
                return true;
            }
        }
        return false;
    }
}