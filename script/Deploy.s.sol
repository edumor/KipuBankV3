// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/KipuBankV3.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // Sepolia testnet addresses
        address initialOwner  = deployer;
        address ethPriceFeed  = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
        address usdcAddress   = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
        address usdcPriceFeed = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;
        address uniswapRouter = 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008;

        KipuBankV3 bank = new KipuBankV3(
            initialOwner,
            ethPriceFeed,
            usdcAddress,
            usdcPriceFeed,
            uniswapRouter
        );
        console.log("KipuBankV3 deployed at:", address(bank));

        vm.stopBroadcast();
    }
}
