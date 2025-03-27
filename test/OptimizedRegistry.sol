// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/OptimizedRegistry.sol"; 

contract PropertyRegistryTest is Test {
    PropertyRegistry registry;
    
    // Define some addresses for testing
    address nonRegistrar = address(0xBEEF);
    address user1 = address(0x1111);
    address user2 = address(0x2222);

    // Re-declare events for expectEmit tests
    event PropertyRegistered(uint256 plotNo, address owner);
    event PropertyTransferred(uint256 plotNo, address from, address to, uint256 price);
    event EncumbranceUpdated(uint256 plotNo, bool status);
    event MutationStatusUpdated(uint256 plotNo, bool status);

    function setUp() public {
        registry = new PropertyRegistry();
    }

    function testAddRegistrar() public {
        registry.addRegistrar(nonRegistrar);
        bool isReg = registry.verifiedRegistrars(nonRegistrar);
        assertTrue(isReg, "nonRegistrar should now be authorized");
    }

    function testRegisterProperty() public {
        uint256 plotNo = 1;
        bytes32 aadhaarHash = keccak256(abi.encodePacked("aadhaar"));
        bytes32 panHash = keccak256(abi.encodePacked("pan"));

        vm.expectEmit(true, true, true, true);
        emit PropertyRegistered(plotNo, user1);
        registry.registerProperty(
            plotNo,
            "east",
            "west",
            "north",
            "south",
            1000,
            500,
            user1,
            aadhaarHash,
            panHash
        );

        // Retrieve and check property details.
        PropertyRegistry.Property memory prop = registry.getPropertyDetails(plotNo);
        assertEq(prop.plotNo, plotNo);
        assertEq(prop.east, "east");
        assertEq(prop.west, "west");
        assertEq(prop.north, "north");
        assertEq(prop.south, "south");
        assertEq(prop.governmentValue, 1000);
        assertEq(prop.area, 500);
        assertEq(prop.currentOwner, user1);
        assertFalse(prop.isEncumbered);
        assertEq(prop.aadhaarHash, aadhaarHash);
        assertEq(prop.panHash, panHash);
        assertFalse(prop.isMutationComplete);
    }

    function testRegisterPropertyAlreadyExists() public {
        uint256 plotNo = 1;
        bytes32 aadhaarHash = keccak256(abi.encodePacked("aadhaar"));
        bytes32 panHash = keccak256(abi.encodePacked("pan"));

        // First registration should succeed.
        registry.registerProperty(
            plotNo,
            "east",
            "west",
            "north",
            "south",
            1000,
            500,
            user1,
            aadhaarHash,
            panHash
        );

        // A second registration for the same plot number must revert.
        vm.expectRevert("Property already registered");
        registry.registerProperty(
            plotNo,
            "east2",
            "west2",
            "north2",
            "south2",
            2000,
            600,
            user2,
            aadhaarHash,
            panHash
        );
    }

    function testRegisterPropertyNotRegistrar() public {
        uint256 plotNo = 2;
        bytes32 aadhaarHash = keccak256(abi.encodePacked("aadhaar"));
        bytes32 panHash = keccak256(abi.encodePacked("pan"));

        // Call from a non-registrar should revert.
        vm.prank(nonRegistrar);
        vm.expectRevert("Not an authorized registrar");
        registry.registerProperty(
            plotNo,
            "east",
            "west",
            "north",
            "south",
            1000,
            500,
            user1,
            aadhaarHash,
            panHash
        );
    }

    function testTransferProperty() public {
        uint256 plotNo = 1;
        bytes32 aadhaarHash = keccak256(abi.encodePacked("aadhaar"));
        bytes32 panHash = keccak256(abi.encodePacked("pan"));

        // Register a property with user1 as owner.
        registry.registerProperty(
            plotNo,
            "east",
            "west",
            "north",
            "south",
            1000,
            500,
            user1,
            aadhaarHash,
            panHash
        );

        // Transfer property from user1 to user2.
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit PropertyTransferred(plotNo, user1, user2, 2000);
        registry.transferProperty(plotNo, user2, 2000);

        // Check that the current owner is updated.
        PropertyRegistry.Property memory prop = registry.getPropertyDetails(plotNo);
        assertEq(prop.currentOwner, user2);
        // Mutation flag should be reset to false.
        assertFalse(prop.isMutationComplete);

        // Verify that the sale transaction is recorded.
        PropertyRegistry.SaleTransaction[] memory history = registry.getPropertyHistory(plotNo);
        assertEq(history.length, 1);
        PropertyRegistry.SaleTransaction memory tx = history[0];
        assertEq(tx.buyer, user2);
        assertEq(tx.seller, user1);
        assertEq(tx.salePrice, 2000);
        assertGt(tx.timestamp, 0);
    }

    function testTransferPropertyNotOwner() public {
        uint256 plotNo = 1;
        bytes32 aadhaarHash = keccak256(abi.encodePacked("aadhaar"));
        bytes32 panHash = keccak256(abi.encodePacked("pan"));

        registry.registerProperty(
            plotNo,
            "east",
            "west",
            "north",
            "south",
            1000,
            500,
            user1,
            aadhaarHash,
            panHash
        );

        // user2 (not the owner) attempts the transfer.
        vm.prank(user2);
        vm.expectRevert("Only owner can transfer");
        registry.transferProperty(plotNo, user2, 2000);
    }

    function testTransferPropertyEncumbered() public {
        uint256 plotNo = 1;
        bytes32 aadhaarHash = keccak256(abi.encodePacked("aadhaar"));
        bytes32 panHash = keccak256(abi.encodePacked("pan"));

        registry.registerProperty(
            plotNo,
            "east",
            "west",
            "north",
            "south",
            1000,
            500,
            user1,
            aadhaarHash,
            panHash
        );

        // Set the property as encumbered.
        registry.updateEncumbranceStatus(plotNo, true);

        // Even the owner should not be able to transfer an encumbered property.
        vm.prank(user1);
        vm.expectRevert("Property is under dispute");
        registry.transferProperty(plotNo, user2, 2000);
    }

    function testUpdateEncumbranceStatusNotRegistrar() public {
        uint256 plotNo = 1;
        bytes32 aadhaarHash = keccak256(abi.encodePacked("aadhaar"));
        bytes32 panHash = keccak256(abi.encodePacked("pan"));

        registry.registerProperty(
            plotNo,
            "east",
            "west",
            "north",
            "south",
            1000,
            500,
            user1,
            aadhaarHash,
            panHash
        );

        // A non-registrar should not be able to update the encumbrance status.
        vm.prank(nonRegistrar);
        vm.expectRevert("Not an authorized registrar");
        registry.updateEncumbranceStatus(plotNo, true);
    }

    function testUpdateEncumbranceStatus() public {
        uint256 plotNo = 1;
        bytes32 aadhaarHash = keccak256(abi.encodePacked("aadhaar"));
        bytes32 panHash = keccak256(abi.encodePacked("pan"));

        registry.registerProperty(
            plotNo,
            "east",
            "west",
            "north",
            "south",
            1000,
            500,
            user1,
            aadhaarHash,
            panHash
        );

        // Expect the EncumbranceUpdated event.
        vm.expectEmit(true, true, true, true);
        emit EncumbranceUpdated(plotNo, true);
        registry.updateEncumbranceStatus(plotNo, true);

        // Verify state update.
        PropertyRegistry.Property memory prop = registry.getPropertyDetails(plotNo);
        assertTrue(prop.isEncumbered);
    }

    function testCompleteMutation() public {
        uint256 plotNo = 1;
        bytes32 aadhaarHash = keccak256(abi.encodePacked("aadhaar"));
        bytes32 panHash = keccak256(abi.encodePacked("pan"));

        registry.registerProperty(
            plotNo,
            "east",
            "west",
            "north",
            "south",
            1000,
            500,
            user1,
            aadhaarHash,
            panHash
        );

        // Expect the MutationStatusUpdated event.
        vm.expectEmit(true, true, true, true);
        emit MutationStatusUpdated(plotNo, true);
        registry.completeMutation(plotNo);

        // Verify that mutation is marked as complete.
        PropertyRegistry.Property memory prop = registry.getPropertyDetails(plotNo);
        assertTrue(prop.isMutationComplete);
    }
}
