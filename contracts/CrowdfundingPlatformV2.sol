// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./Project.sol";

contract CrowdfundingPlatformV2 is UUPSUpgradeable, OwnableUpgradeable {
    address[] public projects;

    event ProjectCreated(
        address projectAddress,
        address creator,
        string description,
        uint256 goalAmount,
        uint256 duration
    );

    constructor() {}

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    function createProject(
        string calldata description,
        uint256 goalAmount,
        uint256 duration
    ) public {
        Project newProject = new Project();
        newProject.initialize(
            msg.sender,
            description,
            goalAmount,
            duration + 1
        );
        projects.push(address(newProject));

        emit ProjectCreated(
            address(newProject),
            msg.sender,
            description,
            goalAmount,
            block.timestamp + duration + 1
        );
    }

    function getProjects() public view returns (address[] memory) {
        return projects;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
