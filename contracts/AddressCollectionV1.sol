// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

import "./AddressNFTv1.sol";

interface IAddressNFT {
    function setCommission(uint256 _commission) external;
    function setCommissionWallet(address _wallet) external;
    function setMetadataUrl(string calldata _url) external;
}

contract AddressCollectionV1 is Ownable, IERC2981  {
    uint256 public royaltyFee;
    address public royaltyRecipient;

    mapping(address => bool) public isOurNFT;
    mapping(uint256 => bool) public exists;

    event TokenCreated(address indexed tokenAddress, address indexed owner);

    constructor(uint256 _royaltyFee, address _royaltyRecipient, address initialOwner) 
        Ownable(initialOwner)
    {
        royaltyFee = _royaltyFee;
        royaltyRecipient = _royaltyRecipient;
    }

    function mintNFT(
        uint256 contractId,
        address nftOwner,
        string memory metadata_url,
        uint256 commission,
        address commissionWallet
    ) external onlyOwner returns (address) {
        require(!exists[contractId], "Already minted");

        bytes32 salt = keccak256(abi.encodePacked(contractId, address(this)));
        AddressNFTv1 newToken = new AddressNFTv1{salt: salt}(
            contractId,
            address(this),
            nftOwner, // Владелец нового токена
            metadata_url,
            commission,
            commissionWallet
        );
        address nftAddr = address(newToken);
        exists[contractId] = true;
        isOurNFT[nftAddr] = true;
        emit TokenCreated(nftAddr, msg.sender);
        
        return nftAddr;
    }

    function setRoyaltyInfo(address _recipient, uint256 _fee) external onlyOwner {
        require(_fee <= 10000, "Royalty fee too high");
        royaltyRecipient = _recipient;
        royaltyFee = _fee;
    }

    function royaltyInfo(uint256, uint256 salePrice) 
        external 
        view 
        override 
        returns (address receiver, uint256 royaltyAmount) 
    {
        return (royaltyRecipient, (salePrice * royaltyFee) / 10000);
    }

    function supportsInterface(bytes4 interfaceId) 
        public 
        pure 
        override(IERC165) 
        returns (bool) 
    {
        return 
            interfaceId == type(IERC2981).interfaceId || 
            interfaceId == type(IERC165).interfaceId;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds available");
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdraw failed");
    }

    /// Изменить комиссию у конкретного NFT через коллекцию
    function updateNFTCommission(address nftAddress, uint256 newCommission) external onlyOwner {
        require(isOurNFT[nftAddress], "Not our NFT");

        IAddressNFT(nftAddress).setCommission(newCommission);
    }

    /// Изменить commissionWallet у конкретного NFT
    function updateNFTCommissionWallet(address nftAddress, address newWallet) external onlyOwner {
        require(isOurNFT[nftAddress], "Not our NFT");

        IAddressNFT(nftAddress).setCommissionWallet(newWallet);
    }

    /// Изменить metadata_url у конкретного NFT
    function updateNFTMetadata(address nftAddress, string calldata newUrl) external onlyOwner {
        require(isOurNFT[nftAddress], "Not our NFT");

        IAddressNFT(nftAddress).setMetadataUrl(newUrl);
    }
    // /// Пакетное обновление для нескольких NFT одной транзакцией
    // function batchUpdateCommission(
    //     uint256[] calldata tokenIds,
    //     uint256[] calldata commissions
    // ) external onlyOwner {
    //     require(tokenIds.length == commissions.length, "Length mismatch");

    //     for (uint256 i = 0; i < tokenIds.length; i++) {
    //         address nftAddr = isOurNFT[tokenIds[i]];
    //         require(nftAddr != address(0), "NFT not registered");
    //         IAddressNFT(nftAddr).setCommission(commissions[i]);
    //     }
    // }
}
