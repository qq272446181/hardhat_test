// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721Utils} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol";
import "hardhat/console.sol";

contract MyERC721 is IERC721, Ownable {

    error ERC721InvalidSender(address);
    error ERC721InvalidApprover(address);
    error ERC721InsufficientApproval(address, uint256);
    error ERC721NonexistentToken(uint256);

    // 基础URI，用于构建tokenURI
    string private _name;
    string private _symbol;

    //记录每个地址拥有NFT数量
    mapping(address owner => uint256) private _balances;
    //记录每个拥有tokenId的地址
    mapping(uint256 tokenId => address) private _owners;
    //tokenId的授权人
    mapping(uint256 tokenId => address) private _tokenApprovals;
    //用户所有授权  
    mapping(address owner => mapping(address operator => bool)) private _operatorApprovals;
    //tokenId文件地址
    mapping(uint256 => string) private _tokenURIs;
    uint256 private nexttokenid;
    constructor(string memory name_,string memory symbol_) Ownable(msg.sender) {
        _name = name_;
        _symbol = symbol_;
        nexttokenid = 1;
    }
    function supportsInterface(bytes4 interfaceId)
        external
        pure 
        returns (bool){
        return interfaceId == type(IERC721).interfaceId;
    }
    function mintNFT(address to, string memory _tokenURI)
    public{
        require(to != address(0), "ERC721: to address the zero address");
        uint256 tokenId = nexttokenid;
        nexttokenid++;
        address previousOwner = _update(to, tokenId, address(0));
        _setTokenURI(tokenId, _tokenURI);
        if (previousOwner != address(0)) {
            revert ERC721InvalidSender(address(0));
        }
        console.log("tokenId:",tokenId);
    }

    //判断tokenId是否存在
    function _exists(uint256 tokenId) internal view returns (bool){
        address owner = _owners[tokenId];
        return owner != address(0);
    }
    function _setTokenURI(uint256 tokenId,string memory _tokenURI) internal {
        //require(_owners[tokenId] != address(0),"ERC721Metadata: URI set of nonexistent token");
         _tokenURIs[tokenId] = _tokenURI;
    }
    function name() public view returns (string memory) {
        return _name;
    }
    function symbol() public view returns (string memory){
        return _symbol;
    }
    function tokenURI(uint256 tokenId) public view returns(string memory){
        return _tokenURIs[tokenId];
    }
    //查询账户持有的 NFT 数量
    function balanceOf(address owner) public view returns (uint256){
        return _balances[owner];
    }
    //查询特定 tokenId 对应的代币所有者
    function ownerOf(uint256 tokenId) public view returns (address) {
        return _owners[tokenId];
    }
    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from,to,tokenId,"");
    }
    function safeTransferFrom(
        address from, 
        address to, 
        uint256 tokenId, 
        bytes memory data) 
    public virtual {
        transferFrom(from,to,tokenId);
        ERC721Utils.checkOnERC721Received(msg.sender, from, to, tokenId, data);
    }
    
    //从一个地址转移 NFT 到另一个地址。调用者必须是所有者或已获授权
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public{
        require(to != address(0),"ERC721: transfer to the zero address");
        _update(to, tokenId, from);
    }
    //判断调用者是否为拥有者或以授权
    function _checkAuthorized(
        address owner,
        address spender,
        uint256 tokenId
    ) internal view{
        bool isAuthor = spender != address(0) && (spender == _owners[tokenId] || 
            spender == _tokenApprovals[tokenId] || 
            _operatorApprovals[owner][spender]);
        if(!isAuthor){
            if (owner == address(0)) {
                revert ERC721NonexistentToken(tokenId);
            } else {
                revert ERC721InsufficientApproval(spender, tokenId);
            }
        }
    }
    //tokenId转移
    function _update(
        address to,
        uint256 tokenId, 
        address auth
    ) internal returns(address){
        require(to != address(0),"ERC721: transfer to the zero address");
        address from = _owners[tokenId];
        if(auth != address(0)){
            _checkAuthorized(to,auth,tokenId);
        }
        if(from != address(0)){
            _balances[from] -= 1;
        }
        if(to != address(0)){
            _balances[to] += 1;
        }
        _owners[tokenId] = to;
        emit Transfer(from,to,tokenId);
        return from;
    }
    ///授权某个地址管理特定的代币
    function approve(address to, uint256 tokenId) public virtual {
        _approve(to,tokenId,msg.sender,true);
    }
    //授权某个地址管理所有的代币
    function setApprovalForAll(address operator, bool approved)  external {
        require(operator != address(0),"ERC721: setApprovalForAll operator the zero address");
        _operatorApprovals[msg.sender][operator] = approved;
    }
    //查询某个代币的授权地址
    function getApproved(uint256 tokenId) public view returns (address operator){
        return _tokenApprovals[tokenId];
    }
    //查询某个操作员是否被授权管理所有代币
    function isApprovedForAll(address owner, address operator) public view returns (bool){
        return _operatorApprovals[owner][operator];
    }
    //tokenId授权
    function _approve(
        address to,
        uint256 tokenId,
        address auth,
        bool emitEvent
    ) internal {
        require(to != address(0), "ERC721: to to the zero address");
        address owner = _owners[tokenId];
        if (
            auth != address(0) &&
            owner != auth &&
            !isApprovedForAll(owner, auth)
        ) {
            revert ERC721InvalidApprover(auth);
        }
        if (emitEvent) {
            emit Approval(owner, to, tokenId);
        }
        _tokenApprovals[tokenId] = to;
    }
}