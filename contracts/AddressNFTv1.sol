// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AddressNFTv1 is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    uint256 public contractId;
    uint256 public commission;
    address public commissionWallet;
    address public collectionAddress;
    string public metadata_url;

    // Маппинг для хранения балансов токенов
    mapping(address => uint256) public tokenBalances;

    event TokensReceived(address indexed token, address indexed from, uint256 amount, uint256 fee);
    event TokensWithdrawn(address indexed token, address indexed to, uint256 amount);
    event CommissionWithdrawn(address indexed to, uint256 amount);

    constructor(
        uint256 _id,
        address _collectionAddress,
        address _owner,
        string memory _metadata_url,
        uint256 _commission, 
        address _commissionWallet
    ) Ownable(_owner) {
        contractId = _id;
        commission = _commission; // комиссия в bp (100 = 1%)
        commissionWallet = _commissionWallet;
        collectionAddress = _collectionAddress;
        metadata_url = _metadata_url;
    }

    // При поступлении ETH сразу пересылаем владельцу за вычетом комиссии
    receive() external payable {
        require(msg.value > 0, "No ETH sent");

        uint256 fee = (msg.value * commission) / 10000; 
        uint256 payout = msg.value - fee;

        (bool successOwner, ) = payable(owner()).call{value: payout}("");
        require(successOwner, "Owner transfer failed");
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

        // Рассчитываем комиссию
        uint256 fee = (actualAmount * commission) / 10000;
        uint256 payout = actualAmount - fee;

        token.safeTransfer(owner(), payout);

        // Сохраняем комиссию в контракте
        tokenBalances[tokenAddress] += fee;

        emit TokensReceived(tokenAddress, msg.sender, actualAmount, fee);
    }

    // Вывод накопленной комиссии в ETH
    function withdrawCommission() external nonReentrant {
        require(msg.sender == commissionWallet, "Not commissionWallet");

        uint256 balance = address(this).balance;
        require(balance > 0, "Nothing to withdraw");

        (bool success, ) = payable(commissionWallet).call{value: balance}("");
        require(success, "ETH commission transfer failed");

        emit CommissionWithdrawn(commissionWallet, balance);
    }

    // Вывод накопленной комиссии в токенах
    function withdrawTokenCommission(address tokenAddress) external nonReentrant {
        require(msg.sender == commissionWallet, "Not commissionWallet");
        require(tokenAddress != address(0), "Invalid token");

        uint256 balance = tokenBalances[tokenAddress];
        require(balance > 0, "Nothing to withdraw");

        tokenBalances[tokenAddress] = 0;
        IERC20(tokenAddress).safeTransfer(commissionWallet, balance);

        emit TokensWithdrawn(tokenAddress, commissionWallet, balance);
    }

    // Получить баланс комиссии для конкретного токена
    function getTokenBalance(address tokenAddress) public view returns (uint256) {
        return tokenBalances[tokenAddress];
    }

    // Получить баланс ETH комиссии
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // Обновить адрес commissionWallet
    function setCommissionWallet(address _commissionWallet) external {
        require(msg.sender == collectionAddress, "Not owner");
        commissionWallet = _commissionWallet;
    }

    // Обновить комиссию (в bp)
    function setCommission(uint256 _commission) external {
        require(msg.sender == collectionAddress, "Not owner");
        commission = _commission;
    }

    function setMetadataUrl(string calldata _url) external {
        require(msg.sender == collectionAddress, "Not owner");
        metadata_url = _url;
    }

    function tokenURI() public view returns (string memory) {
        return metadata_url;
    }
    
    function commissionAddress() public view returns (address) {
        return commissionWallet;
    }

    function getCommission() public view returns (uint256) {
        return commission;
    }

    function getCollectionAddress() public view returns (address) {
        return collectionAddress;
    }

    // Экстренная функция для возврата ошибочно отправленных токенов
    function recoverERC20(address tokenAddress, uint256 amount) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(amount <= balance - tokenBalances[tokenAddress], "Cannot withdraw commission funds");
        
        token.safeTransfer(owner(), amount);
    }
}