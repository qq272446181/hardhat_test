// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RomenConvert{
    mapping(bytes1=>uint16) private romanValues;
    constructor(){
        // 初始化映射关系
        romanValues['I'] = 1;
        romanValues['V'] = 5;
        romanValues['X'] = 10;
        romanValues['L'] = 50;
        romanValues['C'] = 100;
        romanValues['D'] = 500;
        romanValues['M'] = 1000;
    }
    function IntToRomen(uint16 num) public pure returns (string memory str){
        require(num <=3999,"Classic Roman numerals only up to 3999");
        string[10] memory ones = ["","I","II","III","IV","V","VI","VII","VIII","IX"];
        string[10] memory tens = ["","X","XX","XXX","XL","L","LX","LXX","LXXX","XC"];
        string[10] memory hundreds = ["","C","CC","CCC","CD","D","DC","DCC","DCCC","CM"];
        string[4] memory thousands = ["","M","MM","MMM"];
        uint16 num1 = num / 1000;
        uint16 num2 = (num % 1000) / 100;
        uint16 num3 = (num % 100) / 10;
        uint16 num4 = num % 10;
        return string(abi.encodePacked(thousands[num1],hundreds[num2],tens[num3],ones[num4]));
    }
    function RomenToInt(string memory s) public view returns(uint16){
        bytes memory roman = bytes(s);
        uint16 total =0;
        uint16 prevValue = 0; 
        for(uint256 i = roman.length;i>0;i--){
            bytes1 currentChar = roman[i];
            uint16 currentValue = romanValues[currentChar];
            if(currentValue == 0){
                revert("Invalid Roman numeral");
            }
            if(currentValue < prevValue){
                total -= currentValue;
            }else{
                total += currentValue;
            }
            prevValue = currentValue;
        }
        // 验证转换后的值是否在合理范围内（1-3999）
        require(total > 0 && total < 4000, "Value out of Roman numeral range");
        return  total;
    }
    function romanToInt2(string memory s) public view returns (uint256) {
        bytes memory roman = bytes(s);
        uint256 total = 0;
        uint256 prevValue = 0;
        
        // 从右向左遍历
        for (uint256 i = roman.length; i > 0; i--) {
            bytes1 currentChar = roman[i-1];
            uint256 currentValue = romanValues[currentChar];
            
            // 如果当前字符无效（非罗马数字）
            if (currentValue == 0) {
                revert("Invalid Roman numeral");
            }
            
            // 根据罗马数字规则处理（如IV=4，IX=9等）
            if (currentValue < prevValue) {
                total -= currentValue;
            } else {
                total += currentValue;
            }
            
            prevValue = currentValue;
        }
        
        // 验证转换后的值是否在合理范围内（1-3999）
        require(total > 0 && total < 4000, "Value out of Roman numeral range");
        
        return total;
    }
}