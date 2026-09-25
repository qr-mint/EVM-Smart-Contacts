// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract Pool is Ownable, ReentrancyGuard {
    // События для отслеживания действий
    event ETHDeposited(address indexed from, uint256 amount);
    event TokenDeposited(address indexed token, address indexed from, uint256 amount);
    event ETHWithdrawn(address indexed to, uint256 amount);
    event TokenWithdrawn(address indexed token, address indexed to, uint256 amount);
    event OwnerChanged(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Конструктор устанавливает начального владельца.
     */
    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @dev Приём ETH на контракт.
     */
    receive() external payable {
        emit ETHDeposited(msg.sender, msg.value);
    }

    /**
     * @dev Внесение ERC-20 токенов на контракт.
     * @param token Адрес токена.
     * @param amount Количество токенов.
     */
    function depositToken(address token, uint256 amount) external nonReentrant {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be > 0");
        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");
        emit TokenDeposited(token, msg.sender, amount);
    }

    /**
     * @dev Вывод ETH на несколько адресов.
     * @param recipients Массив адресов получателей.
     * @param amounts Массив сумм (в wei) для каждого получателя.
     */
    function withdrawETH(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyOwner nonReentrant {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(recipients.length > 0, "No recipients");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Invalid recipient");
            require(amounts[i] > 0, "Amount must be > 0");
            totalAmount += amounts[i];
        }
        require(address(this).balance >= totalAmount, "Insufficient ETH balance");

        for (uint256 i = 0; i < recipients.length; i++) {
            (bool sent, ) = recipients[i].call{value: amounts[i]}("");
            require(sent, "ETH transfer failed");
            emit ETHWithdrawn(recipients[i], amounts[i]);
        }
    }

    /**
     * @dev Вывод ERC-20 токенов на несколько адресов.
     * @param token Адрес токена.
     * @param recipients Массив адресов получателей.
     * @param amounts Массив сумм токенов для каждого получателя.
     */
    function withdrawToken(
        address token,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyOwner nonReentrant {
        require(token != address(0), "Invalid token address");
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(recipients.length > 0, "No recipients");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Invalid recipient");
            require(amounts[i] > 0, "Amount must be > 0");
            totalAmount += amounts[i];
        }

        IERC20 tokenContract = IERC20(token);
        require(tokenContract.balanceOf(address(this)) >= totalAmount, "Insufficient token balance");

        for (uint256 i = 0; i < recipients.length; i++) {
            bool success = tokenContract.transfer(recipients[i], amounts[i]);
            require(success, "Token transfer failed");
            emit TokenWithdrawn(token, recipients[i], amounts[i]);
        }
    }

    /**
     * @dev Возвращает баланс ETH контракта.
     */
    function getETHBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Возвращает баланс ERC-20 токена на контракте.
     * @param token Адрес токена.
     */
    function getTokenBalance(address token) external view returns (uint256) {
        require(token != address(0), "Invalid token address");
        return IERC20(token).balanceOf(address(this));
    }

    // Функция смены владельца уже есть в Ownable (transferOwnership).
    // Переопределяем событие для удобства (опционально).
    function transferOwnership(address newOwner) public override onlyOwner {
        address oldOwner = owner();
        super.transferOwnership(newOwner);
        emit OwnerChanged(oldOwner, newOwner);
    }
}