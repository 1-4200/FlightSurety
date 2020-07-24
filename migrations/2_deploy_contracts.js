const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');
const BigNumber = require('bignumber.js');
const weiMultiple = (new BigNumber(10)).pow(18);

let firstAirline = '0xf17f52151EbEF6C7334FAD080c5704D77216b732';
let firstAirlineName = 'Test Airline';
let fund = 10 * weiMultiple;

module.exports = function (deployer, network, accounts) {
    if (network === "develop") {
        let owner = accounts[0];
        
        deployer.deploy(FlightSuretyData, {from: owner, value: fund.toString()})
            .then(() => {
                return deployer.deploy(FlightSuretyApp, FlightSuretyData.address, firstAirlineName, {from: owner})
                    .then(() => {
                        let config = {
                            localhost: {
                                url: 'http://localhost:7545',
                                dataAddress: FlightSuretyData.address,
                                appAddress: FlightSuretyApp.address
                            }
                        }
                        fs.writeFileSync(__dirname + '/../src/dapp/config.json', JSON.stringify(config, null, '\t'), 'utf-8');
                        fs.writeFileSync(__dirname + '/../src/server/config.json', JSON.stringify(config, null, '\t'), 'utf-8');
                    });
            });
    }
}
