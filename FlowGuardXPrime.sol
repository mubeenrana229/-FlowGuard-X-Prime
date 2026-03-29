// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract FlowGuardXPrime is AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    bytes32 public constant COMPLIANCE_OFFICER = keccak256("COMPLIANCE_OFFICER");

    uint256 public requiredSignatures;
    uint256 public transactionCount;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 signatureCount;
    }

    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    event TransactionProposed(uint256 indexed txId, address proposer, address target, uint256 amount);
    event TransactionExecuted(uint256 indexed txId, address executor);

    constructor(address[] memory admins, address[] memory signers, uint256 _required) {
        require(_required > 0 && _required <= signers.length, "Invalid threshold");
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        requiredSignatures = _required;
        for (uint i = 0; i < admins.length; i++) _grantRole(ADMIN_ROLE, admins[i]);
        for (uint i = 0; i < signers.length; i++) _grantRole(SIGNER_ROLE, signers[i]);
    }

    function proposeTransaction(address _to, uint256 _value, bytes calldata _data) external onlyRole(ADMIN_ROLE) whenNotPaused returns (uint256) {
        uint256 txId = transactionCount++;
        transactions[txId] = Transaction(_to, _value, _data, false, 0);
        emit TransactionProposed(txId, msg.sender, _to, _value);
        return txId;
    }

    function confirmTransaction(uint256 _txId) external onlyRole(SIGNER_ROLE) whenNotPaused nonReentrant {
        Transaction storage txn = transactions[_txId];
        require(!txn.executed && !isConfirmed[_txId][msg.sender], "Invalid state");
        isConfirmed[_txId][msg.sender] = true;
        txn.signatureCount++;
        if (txn.signatureCount >= requiredSignatures) {
            txn.executed = true;
            (bool success, ) = txn.to.call{value: txn.value}(txn.data);
            require(success, "Failed");
            emit TransactionExecuted(_txId, msg.sender);
        }
    }

    function triggerLockdown() external onlyRole(COMPLIANCE_OFFICER) { _pause(); }
    function restoreSystem() external onlyRole(DEFAULT_ADMIN_ROLE) { _unpause(); }
    receive() external payable {}
}
