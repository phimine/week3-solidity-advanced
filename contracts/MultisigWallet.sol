// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// Error
error MultisigWallet__EmptyOwner();
error MultisigWallet__InvalidOwner();
error MultisigWallet__InvalidThreshold();
error MultisigWallet__DuplicatedOwner();
error MultisigWallet__InitialedThreshold();
error MultisigWallet__TxExecutionFailure();
error MultisigWallet__InvalidSignatures();

/**
 * @title 多签钱包合约
 * 1. 设置多签人和门槛（链上）：部署多签合约时，我们需要初始化多签人列表和执行门槛（至少 n 个多签人签名授权后，交易才能执行）。
 * Gnosis Safe 多签钱包支持增加/删除多签人以及改变执行门槛。
 * 2. 创建交易（链下）：一笔待授权的交易包含以下内容
 *     to：目标合约。
 *     value：交易发送的以太坊数量。
 *     data：calldata，包含调用函数的选择器和参数。
 *     nonce：初始为 0，随着多签合约每笔成功执行的交易递增的值，可以防止签名重放攻击。
 *     chainid：链 id，防止不同链的签名重放攻击。
 * 3. 收集多签签名（链下）：将上一步的交易 ABI 编码并计算哈希，得到交易哈希，然后让多签人签名，并拼接到一起的到打包签名。
 * @author  Carl Fu
 * @notice 在Remix部署测试，构造函数改成payable，部署同时向合约发送1ETH
 * 1. 构造函数改成payable，部署同时向合约发送1ETH，
 * 2. 设置owner账号A和B（账号string加引号），threshold为2
 *      账号A： "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
 *      账号B： "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2"
 * 3. 执行计算哈希：encodeTransactionData(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,1,0x,0,1) =>
 *      交易哈希【0x895a875b81a4f5f3c1cf73fced50d5690a5c9e8145a70d37228859ad3c5db073】
 * 4. 选择Remix的账号分别执行签名
 *      账号A签名：0x2372ab7d2e103ddd02c7b8f500220a470aef9d86ad997889cb0094bed1952c5d4afbcd0a16c263ebe015583e2d9dba5088db6a2b5fc498ecedf2aa9fe946bbaa1c
 *      账号B签名：0xe90ed7d91992c52408286cddfef4bd1f3a31d57f18e0b2d1325889d394bce91f5a911a5b815c304ce715726a03d4a70621c767bd4c596c910e0b7315633434df1c
 *      打包签名：0x2372ab7d2e103ddd02c7b8f500220a470aef9d86ad997889cb0094bed1952c5d4afbcd0a16c263ebe015583e2d9dba5088db6a2b5fc498ecedf2aa9fe946bbaa1ce90ed7d91992c52408286cddfef4bd1f3a31d57f18e0b2d1325889d394bce91f5a911a5b815c304ce715726a03d4a70621c767bd4c596c910e0b7315633434df1c
 * 5. 执行execTransaction，传step#3中的交易数据和step#4的打包签名完成交易
 */
contract MultisigWallet {
    // Type Declaration
    // State Variable
    /**
     * MultisigWallet 合约有 5 个状态变量：
     * - owners：多签持有人数组
     * - isOwner：address => bool 的映射，记录一个地址是否为多签持有人
     * - ownerCount：多签持有人数量
     * - threshold：多签执行门槛，交易至少有 n 个多签人签名才能被执行
     * - nonce：初始为 0，随着多签合约每笔成功执行的交易递增的值，可以防止签名重放攻击。
     */
    address[] private owners;
    mapping(address => bool) private isOwner;
    uint256 private ownerCount;
    uint256 private threshold;
    uint256 private nonce;

    // Event
    /**
     * MultisigWallet 合约有 2 个事件，ExecutionSuccess 和 ExecutionFailure，分别在交易成功和失败时释放，参数为交易哈希。
     */
    event ExecutionSuccess(bytes32 indexed txHash);
    event ExecutionFailure(bytes32 indexed txHash);

    // Modifier
    modifier nonSetup() {
        if (threshold == 0) {
            _;
        } else {
            revert MultisigWallet__InitialedThreshold();
        }
    }

    // Constructor: 构造函数：调用 _setupOwners()，初始化和多签持有人和执行门槛相关的变量。
    constructor(address[] memory _owners, uint256 _threshold) payable {
        _setupOwners(_owners, _threshold);
    }

    // Functions
    /**
     * MultisigWallet 合约有 5 个函数：
     * 1. _setupOwners()：在合约部署时被构造函数调用，初始化 owners，isOwner，ownerCount，threshold 状态变量。
     *      传入的参数中，执行门槛需大于等于 1 且小于等于多签人数；多签地址不能为 0 地址且不能重复。
     * 2. execTransaction()：在收集足够的多签签名后，验证签名并执行交易。
     *      传入的参数为目标地址 to，发送的以太坊数额 value，数据 data，以及打包签名 signatures。
     *      打包签名就是将收集的多签人对交易哈希的签名，按多签持有人地址从小到大顺序，打包到一个[bytes]数据中。
     *      这一步调用编码交易，调用了 checkSignatures() 检验签名是否有效、数量是否达到执行门槛。
     * 3. checkSignatures()：检查签名和交易数据的哈希是否对应，数量是否达到门槛，若否，交易会 revert。
     *      单个签名长度为 65 字节，因此打包签名的长度要长于 threshold * 65。调用了 signatureSplit() 分离出单个签名。
     *      这个函数的大致思路：
     *          - 用 ecdsa 获取签名地址。
     *          - 利用 currentOwner > lastOwner 确定签名来自不同多签（多签地址递增）。
     *          - 利用 isOwner[currentOwner] 确定签名者为多签持有人。
     * 4. signatureSplit()：将单个签名从打包的签名分离出来，参数分别为打包签名 signatures 和要读取的签名位置 pos。
     *      利用了内联汇编，将签名的 r，s，和 v 三个值分离出来。
     * 5. encodeTransactionData()：将交易数据打包并计算哈希，利用了 abi.encode() 和 keccak256() 函数。
     *      这个函数可以计算出一个交易的哈希，然后在链下让多签人签名并收集，再调用 execTransaction() 函数执行。
     */

    /**
     * 在合约部署时被构造函数调用，初始化 owners，isOwner，ownerCount，threshold 状态变量。
     *      传入的参数中，执行门槛需大于等于 1 且小于等于多签人数；多签地址不能为 0 地址且不能重复。
     * @param _owners owners数组
     * @param _threshold 门槛
     */
    function _setupOwners(
        address[] memory _owners,
        uint256 _threshold
    ) internal nonSetup {
        uint256 _ownerCount = _owners.length;
        if (_ownerCount == 0) {
            revert MultisigWallet__EmptyOwner();
        }
        if (_threshold < 1 || _threshold > _ownerCount) {
            revert MultisigWallet__InvalidThreshold();
        }
        for (uint256 i = 0; i < _ownerCount; ) {
            address _owner = _owners[i];
            if (_owner == address(0) || _owner == address(this)) {
                revert MultisigWallet__InvalidOwner();
            }
            if (isOwner[_owner]) {
                revert MultisigWallet__DuplicatedOwner();
            }
            owners.push(_owner);
            isOwner[_owner] = true;
            unchecked {
                i++;
            }
        }
        ownerCount = _ownerCount;
        threshold = _threshold;
    }

    // receive/fallback
    // external
    /**
     * 在收集足够的多签签名后，验证签名并执行交易。
     *      传入的参数为目标地址 to，发送的以太坊数额 value，数据 data，以及打包签名 signatures。
     *      打包签名就是将收集的多签人对交易哈希的签名，按多签持有人地址从小到大顺序，打包到一个[bytes]数据中。
     *      这一步调用编码交易，调用了 checkSignatures() 检验签名是否有效、数量是否达到执行门槛。
     * @param to 目标地址
     * @param value 发送的以太坊数额
     * @param data 数据
     * @param signatures 打包签名
     */
    function execTransaction(
        address to,
        uint256 value,
        bytes memory data,
        bytes memory signatures
    ) external payable returns (bool success) {
        // to + value + data + nonce + chainId --> txHash
        bytes32 txHash = this.encodeTransactionData(
            to,
            value,
            data,
            nonce,
            block.chainid
        );

        // check(txHash, signatures)
        this.checkSignatures(txHash, signatures);

        nonce++;

        (success, ) = payable(to).call{value: value}(data);
        if (success) {
            emit ExecutionSuccess(txHash);
        } else {
            // revert MultisigWallet__TxExecutionFailure();
            emit ExecutionFailure(txHash);
        }
    }

    // internal
    /**
     * 将单个签名从打包的签名分离出来，参数分别为打包签名 signatures 和要读取的签名位置 pos。
     *      利用了内联汇编，将签名的 r，s，和 v 三个值分离出来。
     * @param _signatures 打包签名
     * @param pos 签名位置
     * @return r uint32
     * @return s uint32
     * @return v uint8
     */
    function signatureSplit(
        bytes memory _signatures,
        uint256 pos
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        // 签名的格式：{bytes32 r}{bytes32 s}{uint8 v}
        assembly {
            let signaturePos := mul(0x41, pos)
            r := mload(add(_signatures, add(signaturePos, 0x20)))
            s := mload(add(_signatures, add(signaturePos, 0x40)))
            v := and(mload(add(_signatures, add(signaturePos, 0x41))), 0xff)
        }
    }

    // view/pure
    /**
     * 检查签名和交易数据的哈希是否对应，数量是否达到门槛，若否，交易会 revert。
     *      单个签名长度为 65 字节，因此打包签名的长度要长于 threshold * 65。调用了 signatureSplit() 分离出单个签名。
     *      这个函数的大致思路：
     *          - 用 ecdsa 获取签名地址。
     *          - 利用 currentOwner > lastOwner 确定签名来自不同多签（多签地址递增）。
     *          - 利用 isOwner[currentOwner] 确定签名者为多签持有人。
     * @param dataHash 交易哈希
     * @param signatures 打包签名
     */
    function checkSignatures(
        bytes32 dataHash,
        bytes memory signatures
    ) public view {
        uint256 _threshold = threshold;
        if (_threshold == 0) {
            revert MultisigWallet__InvalidThreshold();
        }

        uint256 _length = signatures.length;
        if (_length < _threshold * 65) {
            revert MultisigWallet__InvalidSignatures();
        }

        address lastOwner = address(0);
        address curOwner;
        bytes32 r;
        bytes32 s;
        uint8 v;
        for (uint256 i = 0; i < _threshold; i++) {
            (r, s, v) = signatureSplit(signatures, i);
            // 利用ecrecover检查签名是否有效
            curOwner = ecrecover(
                MessageHashUtils.toEthSignedMessageHash(dataHash),
                v,
                r,
                s
            );
            if (curOwner > lastOwner && isOwner[curOwner]) {
                lastOwner = curOwner;
            } else {
                revert MultisigWallet__InvalidSignatures();
            }
        }
    }

    /**
     * 将交易数据打包并计算哈希，利用了 abi.encode() 和 keccak256() 函数。
     *      这个函数可以计算出一个交易的哈希，然后在链下让多签人签名并收集，再调用 execTransaction() 函数执行。
     * @param to to
     * @param value 交易数量
     * @param data 交易data
     * @param _nonce nonce
     * @param chainId chainId
     */
    function encodeTransactionData(
        address to,
        uint256 value,
        bytes memory data,
        uint256 _nonce,
        uint256 chainId
    ) public pure returns (bytes32 safeTxHash) {
        safeTxHash = keccak256(
            abi.encode(to, value, keccak256(data), _nonce, chainId)
        );
    }

    function getOwnerCount() public view returns (uint256) {
        return ownerCount;
    }

    function getThreshold() public view returns (uint256) {
        return threshold;
    }

    function getNonce() public view returns (uint256) {
        return nonce;
    }
}
