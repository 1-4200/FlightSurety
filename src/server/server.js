import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';

import Config from './config.json';
import Web3 from 'web3';
import express from 'express';


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];

let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let registeredOracles = [];

const ORACLES_COUNT = 20;
const STATUS_CODE_UNKNOWN = 0;
const STATUS_CODE_ON_TIME = 10;
const STATUS_CODE_LATE_AIRLINE = 20;
const STATUS_CODE_LATE_WEATHER = 30;
const STATUS_CODE_LATE_TECHNICAL = 40;
const STATUS_CODE_LATE_OTHER = 50;
const STATUS_CODES = [
    STATUS_CODE_UNKNOWN,
    STATUS_CODE_ON_TIME,
    STATUS_CODE_LATE_AIRLINE,
    STATUS_CODE_LATE_WEATHER,
    STATUS_CODE_LATE_TECHNICAL,
    STATUS_CODE_LATE_OTHER
];
let gas = 3000000;

function randomStatusCode() {
    return STATUS_CODES[Math.floor(Math.random() * STATUS_CODES.length)];
}

web3.eth.getAccounts(async (error, accounts) => {
    web3.eth.defaultAccount = accounts[0];
    for (let i = 0; i < ORACLES_COUNT; i++) {
        let oracleAccount = accounts[i]

        await flightSuretyApp.methods.registerOracle().send({
            from: oracleAccount,
            value: web3.utils.toWei("1", "ether"),
            gas: gas
        }, async (error, result) => {
            await flightSuretyApp.methods.getMyIndexes().call({
                from: oracleAccount
            }, (error, indexesResult) => {
                if (!error) {
                    registeredOracles.push({address: oracleAccount, index: indexesResult})
                }
            })
        })
    }
})


flightSuretyApp.events.OracleRequest({
    fromBlock: 0
}, async function (error, event) {
    if (error) {
        console.log(error)
    }
    let statusCode = randomStatusCode()
    let indexes;
    let oracle;
    for (let i = 0; i < registeredOracles.length; i++) {
        indexes = registeredOracles[i].index;
        oracle = registeredOracles[i].address
        console.log("indexes", indexes)
        console.log("oracle", oracle)
        try {
            await flightSuretyApp.methods.submitOracleResponse(
                event.returnValues.index,
                event.returnValues.airline,
                event.returnValues.flight,
                event.returnValues.timestamp,
                statusCode
            ).send({from: oracle, gas: gas}, (error, result) => {
                if (error) {
                    console.log(error);
                } else {
                    console.log(result);
                }
            })
        } catch (e) {
            console.log(e);
        }
    }
});

const app = express();
app.get('/api', (req, res) => {
    res.send({
        message: 'An API for use with your Dapp!'
    })
})

export default app;

