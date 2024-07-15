// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

// Error
error NFTSwap__InvalidPrice();
error NFTSwap__InsuffienceAmount();
error NFTSwap__NoNFTApproval();
error NFTSwap__NotNFTOwner(
    address ntfAddress,
    uint256 tokenId,
    address checkOwner
);
error NFTSwap__NotOrderOwner();

/**
 * @title 去中心化 NFT 交易所
 * ERC721 的安全转账函数会检查接收合约是否实现了 onERC721Received() 函数，并返回正确的选择器 selector。
 * 用户下单之后，需要将 NFT 发送给 NFTSwap 合约。因此 NFTSwap 继承 IERC721Receiver 接口，并实现 onERC721Received() 函数
 * @author Carl Fu
 * @notice
 */
contract NFTSwap is IERC721Receiver {
    // Type Declaration: NFT 订单抽象为 Order 结构体，包含挂单价格 price 和持有人 owner 信息。
    struct Order {
        address owner;
        uint256 price;
    }
    // State Variable: nftList 映射记录了订单是对应的 NFT 系列（合约地址）和 tokenId 信息。
    mapping(address => mapping(uint256 => Order)) public nftList;

    // Event: 合约包含 4 个事件，对应挂单 list、撤单 revoke、修改价格 update、购买 purchase 这四个行为
    event List(
        address indexed seller,
        address indexed ntfAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    event Revoke(
        address indexed seller,
        address indexed nftAddress,
        uint256 tokenId
    );
    event UpdatePrice(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 newPrice
    );
    event Purchase(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    // Modifier
    modifier validPrice(uint256 price) {
        if (price > 0) {
            _;
        } else {
            revert NFTSwap__InvalidPrice();
        }
    }

    modifier orderOwner(address nftAddress, uint256 tokenId) {
        if (nftList[nftAddress][tokenId].owner == msg.sender) {
            _;
        } else {
            revert NFTSwap__NotOrderOwner();
        }
    }

    // Constructor
    // Functions
    // receive/fallback: 在 NFTSwap 中，用户使用 ETH 购买 NFT。因此，合约需要实现 fallback() 函数来接收 ETH。
    fallback() external payable {}

    // external
    /**
     * 实现{IERC721Receiver}的onERC721Received，能够接收ERC721代币
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // 交易函数：合约实现了 4 个交易相关的函数：挂单list、撤单revoke、更改价格updatePrice、购买purchase
    /**
     * 卖家上架NFT订单
     * @param _nftAddress NTF合约地址
     * @param _tokenId NTF tokenId
     * @param _price 价格
     */
    function list(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _price
    ) public validPrice(_price) {
        // Check: NFT owner是否是卖家、合约是否得到授权、价格是否大于0
        // 初始化IERC721
        IERC721 _nft = IERC721(_nftAddress);
        if (_nft.ownerOf(_tokenId) != msg.sender) {
            revert NFTSwap__NotNFTOwner(_nftAddress, _tokenId, msg.sender);
        }
        if (_nft.getApproved(_tokenId) != address(this)) {
            revert NFTSwap__NoNFTApproval();
        }

        // Effect
        Order storage order = nftList[_nftAddress][_tokenId];
        order.owner = msg.sender;
        order.price = _price;

        // Interaction: NFT转账至合约
        _nft.safeTransferFrom(msg.sender, address(this), _tokenId);
        emit List(msg.sender, _nftAddress, _tokenId, _price);
    }

    /**
     * 撤单
     * @param _nftAddress NFT 合约地址
     * @param _tokenId NFT tokenId
     */
    function revoke(
        address _nftAddress,
        uint256 _tokenId
    ) public orderOwner(_nftAddress, _tokenId) {
        // Check: NFT owner是否是合约、NFT订单owner是否是msg.sender
        IERC721 _nft = IERC721(_nftAddress);
        if (_nft.ownerOf(_tokenId) != address(this)) {
            revert NFTSwap__NotNFTOwner(_nftAddress, _tokenId, address(this));
        }

        // Effect: 删除卖家挂的NFT订单
        delete nftList[_nftAddress][_tokenId];

        // Interaction：将NFT返回给卖家
        _nft.safeTransferFrom(address(this), msg.sender, _tokenId);
        emit Revoke(msg.sender, _nftAddress, _tokenId);
    }

    /**
     *
     * @param _nftAddress NFT 合约地址
     * @param _tokenId NFT token Id
     * @param _newPrice 新价格
     */
    function updatePrice(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _newPrice
    ) public validPrice(_newPrice) orderOwner(_nftAddress, _tokenId) {
        // Check: 订单owner是否是msg.sender、价格是否大于0
        // Effect
        Order storage order = nftList[_nftAddress][_tokenId];
        order.price = _newPrice;

        // Interaction
        emit UpdatePrice(msg.sender, _nftAddress, _tokenId, _newPrice);
    }

    /**
     *
     * @param _nftAddress NTF 合约地址
     * @param _tokenId NTF token Id
     */
    function purchase(address _nftAddress, uint256 _tokenId) public payable {
        // Check：NFT owner是否是合约地址、msg.value是否大于订单价格、NFT订单必须存在（价格大于0）
        IERC721 _nft = IERC721(_nftAddress);
        if (_nft.ownerOf(_tokenId) != address(this)) {
            revert NFTSwap__NotNFTOwner(_nftAddress, _tokenId, address(this));
        }
        Order storage order = nftList[_nftAddress][_tokenId];
        uint256 _price = order.price;
        if (_price <= 0) {
            revert NFTSwap__InvalidPrice();
        }
        if (_price > msg.value) {
            revert NFTSwap__InsuffienceAmount();
        }
        // Effect：删除NTF订单
        delete nftList[_nftAddress][_tokenId];

        // Interaction：NFT转账给卖家、price转账给卖家、剩余amount退还给买家
        _nft.safeTransferFrom(address(this), msg.sender, _tokenId);
        payable(order.owner).transfer(_price);
        payable(msg.sender).transfer(msg.value - _price);
        emit Purchase(msg.sender, _nftAddress, _tokenId, _price);
    }
    // internal
    // view/pure
}
