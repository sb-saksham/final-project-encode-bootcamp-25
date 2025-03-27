// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract PropertyRegistry {
    struct Property {
        uint256 plotNo;
        uint256 governmentValue;
        uint256 area;
        address currentOwner;
        bool isEncumbered;
        bool isMutationComplete;
        bytes32 aadhaarHash;
        bytes32 panHash;
        string east;
        string west;
        string north;
        string south;
    }

    struct SaleTransaction {
        address buyer;
        address seller;
        uint256 salePrice;
        uint256 timestamp;
    }

    mapping(uint256 => Property) public properties;
    mapping(uint256 => SaleTransaction[]) public propertyHistory;
    mapping(address => bool) public verifiedRegistrars;

    event PropertyRegistered(uint256 plotNo, address owner);
    event PropertyTransferred(uint256 plotNo, address from, address to, uint256 price);
    event EncumbranceUpdated(uint256 plotNo, bool status);
    event MutationStatusUpdated(uint256 plotNo, bool status);

    modifier onlyRegistrar() {
        require(verifiedRegistrars[msg.sender], "Not an authorized registrar");
        _;
    }

    constructor() {
        verifiedRegistrars[msg.sender] = true;
    }

    function addRegistrar(address _registrar) public onlyRegistrar {
        verifiedRegistrars[_registrar] = true;
    }

    function registerProperty(
        uint256 _plotNo,
        string memory _east,
        string memory _west,
        string memory _north,
        string memory _south,
        uint256 _governmentValue,
        uint256 _area,
        address _owner,
        bytes32 _aadhaarHash,
        bytes32 _panHash
    ) public onlyRegistrar {
        Property storage prop = properties[_plotNo];
        require(prop.plotNo == 0, "Property already registered");
        prop.plotNo = _plotNo;
        prop.governmentValue = _governmentValue;
        prop.area = _area;
        prop.currentOwner = _owner;
        prop.isEncumbered = false;
        prop.isMutationComplete = false;
        prop.aadhaarHash = _aadhaarHash;
        prop.panHash = _panHash;
        prop.east = _east;
        prop.west = _west;
        prop.north = _north;
        prop.south = _south;

        emit PropertyRegistered(_plotNo, _owner);
    }
    function transferProperty(uint256 _plotNo, address _buyer, uint256 _salePrice) public {
        Property storage prop = properties[_plotNo];
        require(msg.sender == prop.currentOwner, "Only owner can transfer");
        require(!prop.isEncumbered, "Property is under dispute");

        // Record the sale transaction.
        propertyHistory[_plotNo].push(
            SaleTransaction({
                buyer: _buyer,
                seller: msg.sender,
                salePrice: _salePrice,
                timestamp: block.timestamp
            })
        );

        prop.currentOwner = _buyer;
        prop.isMutationComplete = false;

        emit PropertyTransferred(_plotNo, msg.sender, _buyer, _salePrice);
    }

    function updateEncumbranceStatus(uint256 _plotNo, bool _status) public {
        require(verifiedRegistrars[msg.sender], "Not an authorized registrar");

        Property storage prop = properties[_plotNo];
        if (prop.isEncumbered != _status) {
            prop.isEncumbered = _status;
            emit EncumbranceUpdated(_plotNo, _status);
        }
    }

    function completeMutation(uint256 _plotNo) public {
        require(verifiedRegistrars[msg.sender], "Not an authorized registrar");
        properties[_plotNo].isMutationComplete = true;
        emit MutationStatusUpdated(_plotNo, true);
    }

    function getPropertyDetails(uint256 _plotNo) public view returns (Property memory) {
        return properties[_plotNo];
    }

    function getPropertyHistory(uint256 _plotNo) public view returns (SaleTransaction[] memory) {
        return propertyHistory[_plotNo];
    }
}