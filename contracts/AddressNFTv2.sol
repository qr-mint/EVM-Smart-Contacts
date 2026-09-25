// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AddressNFTv2 is Ownable {
    using SafeERC20 for IERC20;
    
    uint256 public contractId;
    address public collectionAddress;
    string public metadata_url;

    // События для отслеживания операций
    event TokensReceived(address indexed token, address indexed from, uint256 amount);
    event TokensWithdrawn(address indexed token, address indexed to, uint256 amount);
    event ETHReceived(address indexed from, uint256 amount);

    constructor(uint256 _id, address _collectionAddress, address _owner, string memory _metadata_url) Ownable(_owner) {
        contractId = _id;
        collectionAddress = _collectionAddress;
        metadata_url = _metadata_url;
    }

    // При поступлении ETH сразу пересылаем владельцу
    receive() external payable {
        require(msg.value > 0, "No ETH sent");
        
        // Отправляем всю сумму владельцу
        (bool successOwner, ) = payable(owner()).call{value: msg.value}("");
        require(successOwner, "Owner transfer failed");

        emit ETHReceived(msg.sender, msg.value);
    }

    // Функция для приема ERC20 токенов и немедленной пересылки владельцу
    function receiveTokens(address tokenAddress, uint256 amount) external {
        require(amount > 0, "No tokens sent");
        require(tokenAddress != address(0), "Invalid token address");

        // Получаем токены от отправителя
        IERC20 token = IERC20(tokenAddress);
        uint256 balanceBefore = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), amount);
        uint256 actualAmount = token.balanceOf(address(this)) - balanceBefore;

        // Немедленно отправляем все токены владельцу
        token.safeTransfer(owner(), actualAmount);

        emit TokensReceived(tokenAddress, msg.sender, actualAmount);
    }

    // Баланс ETH в контракте (должен быть всегда near zero, так как все сразу пересылается)
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // Функция для вывода случайно оставшихся токенов (на всякий случай)
    function withdrawStuckTokens(address tokenAddress) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        
        token.safeTransfer(owner(), balance);
        emit TokensWithdrawn(tokenAddress, owner(), balance);
    }

    // Функция для вывода случайно оставшегося ETH
    function withdrawStuckETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "ETH transfer failed");
    }

    function setMetadataUrl(string calldata _url) external {
        require(msg.sender == collectionAddress, "Not owner");
        metadata_url = _url;
    }

    function tokenURI() public view returns (string memory) {
        return metadata_url;
    }

    function getCollectionAddress() public view returns (address) {
        return collectionAddress;
    }

    // Получить баланс конкретного токена в контракте
    function getTokenBalance(address tokenAddress) public view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }
}