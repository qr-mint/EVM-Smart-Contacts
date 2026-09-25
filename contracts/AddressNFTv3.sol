// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AddressNFTv3 is Ownable {
    using SafeERC20 for IERC20;
    
    uint256 public contractId;
    address public collectionAddress;
    string public metadata_url;

    // События для отслеживания операций
    event ETHReceived(address indexed from, uint256 amount);
    event TokensReceived(address indexed token, address indexed from, uint256 amount);
    event ETHWithdrawn(address indexed to, uint256 amount);
    event TokensWithdrawn(address indexed token, address indexed to, uint256 amount);

    constructor(uint256 _id, address _collectionAddress, address _owner, string memory _metadata_url) Ownable(_owner) {
        contractId = _id;
        collectionAddress = _collectionAddress;
        metadata_url = _metadata_url;
    }

    // Принимаем ETH напрямую
    receive() external payable {
        if (msg.value > 0) {
            emit ETHReceived(msg.sender, msg.value);
        }
    }

    // Функция для приема ERC20 токенов
    function receiveTokens(address tokenAddress, uint256 amount) external {
        require(amount > 0, "No tokens sent");
        require(tokenAddress != address(0), "Invalid token address");

        // Получаем токены от отправителя
        IERC20 token = IERC20(tokenAddress);
        uint256 balanceBefore = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), amount);
        uint256 actualAmount = token.balanceOf(address(this)) - balanceBefore;

        emit TokensReceived(tokenAddress, msg.sender, actualAmount);
    }

    // Получить баланс ETH контракта
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // Получить баланс ERC20 токена в контракте
    function getTokenBalance(address tokenAddress) public view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    // Вывод ETH
    function withdraw() external onlyOwner {
         uint256 balance = address(this).balance;
        require(balance > 0, "Nothing to withdraw");

        address to = owner();
        (bool success, ) = payable(to).call{value: balance}("");
        require(success, "ETH transfer failed");

        emit ETHWithdrawn(to, balance);
    }

    // Вывод ERC20 токенов
    function withdrawTokens(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(0), "Invalid token");

        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "Insufficient token balance");

        address to = owner();
        token.safeTransfer(to, balance);

        emit TokensWithdrawn(tokenAddress, to, balance);
    }

    // Вывод всех токенов определенного типа
    function withdrawAllTokens(address tokenAddress) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");

        token.safeTransfer(owner(), balance);
        emit TokensWithdrawn(tokenAddress, owner(), balance);
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

    // Экстренная функция для одобрения токенов (на случай проблем)
    function approveTokens(address tokenAddress, address spender, uint256 amount) external onlyOwner {
        IERC20(tokenAddress).approve(spender, amount);
    }
}