// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// Error
error SignatureNFT__AlreadyMinted();
error SignatureNFT__InvalidSignature();

/**
 * @title NFT 项目方可以利用 ECDSA 的这个特性发放白名单。
 * 由于签名是链下的，不需要 gas，因此这种白名单发放模式比 Merkle Tree 模式还要经济。
 * 方法非常简单，项目方利用项目方账户把白名单发放地址签名（可以加上地址可以铸造的 tokenId）。
 * 然后 mint 的时候利用 ECDSA 检验签名是否有效，如果有效，则给他 mint。
 * SignatureNFT 合约实现了利用签名发放 NFT 白名单。
 *
 * @author Carl Fu
 * @notice Remix 测试（向【account】发放【tokenId】的代币）
 * 1. 复制SignatureNFT代码到Remix，部署
 * 2. 通过getMessageHash(account, tokenId)获取 【消息Hash】
 * 3. 通过浏览器Metamask获取 签名【signurature】
 *     3.a. 打开开发者工具Console：ethereum.enabled()
 *     3.b. account =【account】
 *     3.c. hash =【消息Hash】
 *     3.d. await ethereum.request({method: "personal_sign", [account, hash]}) --> 【signurature】
 * 4. 使用【account】【tokenId】【signature】调用remix部署的合约mint方法铸造
 * 5. 执行remix的ownerOf()检查是否铸造成功
 */
contract SignatureNFT is ERC721 {
    // Type Declaration
    // State Variable
    address private immutable i_signer;
    mapping(address => bool) private mintedAddress;

    // Event
    event LogMint(address indexed _account, uint256 indexed _tokenId);

    // Modifier
    modifier unminted(address _account) {
        if (mintedAddress[_account]) {
            revert SignatureNFT__AlreadyMinted();
        }
        _;
    }

    // Constructor
    constructor(
        string memory _name,
        string memory _symbol,
        address _signer
    ) ERC721(_name, _symbol) {
        i_signer = _signer;
    }

    // Functions
    // receive/fallback
    // external
    function mint(
        address _account,
        uint256 _tokenId,
        bytes memory _signature
    ) external unminted(_account) {
        // _account + _tokenId --> _msgHash
        bytes32 _msgHash = this.getMessageHash(_account, _tokenId);
        // _msgHash --> _ethSignedMsgHash
        bytes32 _ethSignedMsgHash = MessageHashUtils.toEthSignedMessageHash(
            _msgHash
        );

        if (this.verify(_ethSignedMsgHash, _signature)) {
            mintedAddress[_account] = true;
            _mint(_account, _tokenId);
            emit LogMint(_account, _tokenId);
        } else {
            revert SignatureNFT__InvalidSignature();
        }
    }

    // view/pure
    function getSigner() public view returns (address) {
        return i_signer;
    }

    /*
     * 将mint地址（address类型）和tokenId（uint256类型）拼成消息msgHash
     * _account: 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
     * _tokenId: 0
     * 对应的消息: 0x1bf2c0ce4546651a1a2feb457b39d891a6b83931cc2454434f39961345ac378c
     */
    function getMessageHash(
        address _account,
        uint256 _tokenId
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account, _tokenId));
    }

    /*
     * ECDSA验证，调用ECDSA库的verify()函数
     * @param _msgHash
     * @param _signature
     */
    function verify(
        bytes32 _msgHash,
        bytes memory _signature
    ) public view returns (bool) {
        address recovered = ECDSA.recover(_msgHash, _signature);
        return recovered == i_signer;
    }
}
