// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// Error
error DIYERC721__NotOwner();
error DIYERC721__NotOwnerOrApproved();
error DIYERC721__InvalidAddress();
error DIYERC721__ERC721InvalidReceiver(address receiver);
error DIYERC721__TokenNotExist();

/**
 * @title ERC721 NFT代币
 * @author Carl Fu
 * @notice
 */
contract DIYERC721 is IERC721, IERC721Metadata {
    // Type Declaration
    using Strings for uint256; // 使用String库

    // State Variable
    string public override name;
    string public override symbol;
    // tokenId到owner地址
    mapping(uint256 => address) private owners;
    mapping(address => uint256) private balances;
    mapping(uint256 => address) private approvals;
    mapping(address => mapping(address => bool)) private operatorApprovals;

    // Event

    // Modifier
    modifier validAddress(address account) {
        if (account == address(0)) {
            revert DIYERC721__InvalidAddress();
        }
        _;
    }

    modifier existingToken(uint256 tokenId) {
        if (owners[tokenId] == address(0)) {
            revert DIYERC721__TokenNotExist();
        }
        _;
    }

    // Constructor
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    // Functions
    // receive/fallback
    // external
    function transferFrom(address from, address to, uint256 tokenId) public {
        // Check：msg.sender是token的owner或授权
        address owner = owners[tokenId];
        if (!_isApprovedOrOwner(owner, msg.sender, tokenId)) {
            revert DIYERC721__NotOwnerOrApproved();
        }
        // Effect：_transfer
        _transfer(owner, from, to, tokenId);

        // Interaction
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override {
        transferFrom(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    function approve(address to, uint256 tokenId) external {
        // Check：msg.sender是token的owner或授权
        address owner = owners[tokenId];
        if (owner != msg.sender && !operatorApprovals[owner][msg.sender]) {
            revert DIYERC721__NotOwnerOrApproved();
        }
        // Effect: _approve
        _approve(owner, to, tokenId);
        // Interaction
    }

    function setApprovalForAll(address operator, bool approved) external {
        operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    // internal/private
    function _transfer(
        address owner,
        address from,
        address to,
        uint256 tokenId
    ) private validAddress(to) {
        // Check：token的owner是from、to是有效地址
        if (owner != from) {
            revert DIYERC721__NotOwner();
        }

        // Effect：token的owner变成to、token的授权清空、from的balance减一、to的balance加一
        _approve(owner, address(0), tokenId);
        owners[tokenId] = to;
        balances[from] -= 1;
        balances[to] += 1;

        // Interaction
        emit Transfer(from, to, tokenId);
    }

    function _approve(
        address owner,
        address approved,
        uint256 tokenId
    ) private {
        // Check：token的owner是owner
        if (owners[tokenId] != owner) {
            revert DIYERC721__NotOwner();
        }
        // Effect：授权token给approved地址
        approvals[tokenId] = approved;

        // Interaction
        emit Approval(owner, approved, tokenId);
    }

    function _isApprovedOrOwner(
        address owner,
        address operator,
        uint256 tokenId
    ) private view returns (bool) {
        return
            owner == operator ||
            operatorApprovals[owner][operator] ||
            approvals[tokenId] == operator;
    }

    /**
     * _checkOnERC721Received：函数，用于在 to 为合约的时候调用IERC721Receiver-onERC721Received, 以防 tokenId 被不小心转入黑洞。
     * @param from from地址
     * @param to to地址
     * @param tokenId tokenId
     * @param data 数据
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private {
        // 目标是否是合约地址
        if (to.code.length > 0) {
            try
                IERC721Receiver(to).onERC721Received(from, to, tokenId, data)
            returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    revert DIYERC721__ERC721InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert DIYERC721__ERC721InvalidReceiver(to);
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    // view/pure
    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId;
    }

    /**
     * 实现IERC721Metadata的tokenURI函数，查询metadata。
     * @param tokenId  tokenId
     */
    function tokenURI(
        uint256 tokenId
    ) external view existingToken(tokenId) returns (string memory) {
        // Check: tokenId是否存在
        string memory baseURI = _baseURI();
        return
            (bytes(baseURI).length > 0)
                ? string(abi.encodePacked(baseURI, tokenId.toString()))
                : "";
    }

    /**
     * 计算{tokenURI}的BaseURI，tokenURI就是把baseURI和tokenId拼接在一起，需要开发重写。
     * BAYC的baseURI为ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return owners[tokenId];
    }

    function balanceOf(address owner) external view returns (uint256) {
        return balances[owner];
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        return approvals[tokenId];
    }

    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool) {
        return operatorApprovals[owner][operator];
    }
}
