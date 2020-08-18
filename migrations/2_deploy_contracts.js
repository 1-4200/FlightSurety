const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');
const Web3 = require('web3');

module.exports = function (deployer) {

    let web3 = new Web3(new Web3.providers.WebsocketProvider('ws://127.0.0.1:8545'));
    let fund = web3.utils.toWei('10', 'ether')
    deployer.deploy(FlightSuretyData, {value: fund})
        .then(() => {
            return deployer.deploy(FlightSuretyApp, FlightSuretyData.address)
                .then(() => {
                    let config = {
                        localhost: {
                            url: 'http://localhost:8545',
                            dataAddress: FlightSuretyData.address,
                            appAddress: FlightSuretyApp.address
                        }
                    }
                    fs.writeFileSync(__dirname + '/../src/dapp/config.json', JSON.stringify(config, null, '\t'), 'utf-8');
                    fs.writeFileSync(__dirname + '/../src/server/config.json', JSON.stringify(config, null, '\t'), 'utf-8');
                });
        });
}
