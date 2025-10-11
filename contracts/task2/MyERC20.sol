// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

contract MyERC20 is IERC20{
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;
    address private _owner ;
    mapping(address => uint256) private _balances;
    mapping(address => mapping (address => uint256)) private _allowances;
    constructor() {
        _name = "MyERC20";
        _symbol = "MKT";
        _decimals = 18;
        _owner = msg.sender;
        mint(1000000 * 10 ** _decimals);
    }
    //增发代币
    function mint(uint256 amount) public {
        require(msg.sender != address(0),"sender is zero address");
        require(msg.sender == _owner,"only owner can mint"); // 只有合约所有者才能铸造代币
        _update(address(0), msg.sender, amount);
    }
    function name() public view returns (string memory){
        return _name;
    }
    function symbol() public view returns (string memory){
        return _symbol;
    }
    function decimals() public view returns (uint8){
        return _decimals;
    }
    //代币总供应量
    function totalSupply() public view returns (uint256){
        return _totalSupply;
    }
    //用户余额
    function balanceOf(address account) public view returns (uint256){
        return _balances[account];
    }
    //转账功能
    function transfer(address to, uint256 amount) public returns (bool){
        require(to != address(0),"account the zero address");
        _update(msg.sender, to, amount);
        return true;
    }
    //查询授权额度
    function allowance(address owner, address spender) public view returns (uint256){
        return _allowances[owner][spender];
    }
    //授权功能
    function approve(address spender, uint256 value) public returns (bool){
        _approve(msg.sender,spender,value);
        return true;
    }
    //代扣转账
    function transferFrom(address from, address to, uint256 value) public returns (bool){
        //console.log("transferFrom msg.sender:",msg.sender,"amount:",value);
        console.log("from",from,"to:",to);
        require(from != address(0),"from account the zero address");
        require(to != address(0),"to account the zero address");
        uint256 maxAmount = _allowances[from][msg.sender];
        console.log("msg.sender",msg.sender,"maxAmount:",maxAmount);
        require(value < maxAmount ,"transfer amount exceeds balance");
        _approve(from, msg.sender, maxAmount - value);
        _update(from,to,value);
        return true;
    }
    //内部函数：授权功能 
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from zero address");
        require(spender != address(0), "ERC20: approve to zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
     //内部函数转账
    function _update(address from, address to, uint256 amount) internal {
        if(from == address(0)){
            _totalSupply += amount;
        }else{
            uint256 fromBalace = _balances[from];
            //console.log("from :", from,"fromBalace:",fromBalace);
            //console.log("to",to,"amount:",amount);
            require(amount <= fromBalace,"transfer amount exceeds balance");
            _balances[from] -= amount;
        }
        if(to == address(0)){
            _totalSupply -= amount;
        }else{
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);
    }
}