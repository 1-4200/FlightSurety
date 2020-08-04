import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);

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
let oracles = [];

function randomStatusCode() {
    return STATUS_CODES[Math.floor(Math.random() * STATUS_CODES.length)];
}

(async () => {
    await web3.eth.getAccounts(async (error, accounts) => {
            for (let i = 0; i < ORACLES_COUNT; i++) {
                await flightSuretyApp.methods.registerOracle().send({
                    from: accounts[i],
                    value: web3.utils.toWei("1", "ether"),
                }, async (error, result) => {
                    if (error) {
                        console.log(error);
                    } else {
                        await flightSuretyApp.methods.getMyIndexes().call({from: accounts[i]}, (error, result) => {
                            if (error) {
                                console.log(error);
                            } else {
                                let oracle = {address: accounts[a], index: result};
                                console.log(`oracle: ${JSON.stringify(oracle)}`);
                                oracles.push(oracle);
                            }
                        })
                    }
                })
            }
        }
    );

    await flightSuretyApp.events.OracleRequest({
        fromBlock: 0
    }, async (error, event) => {
        if (error) {
            console.log(error)
        } else {
            const {index, airline, flight, timestamp} = event.returnValues;
            const statusCode = randomStatusCode();
            for (let i = 0; i < ORACLES_COUNT; i++) {
                await flightSuretyApp.methods.submitOracleResponse(index, airline, flight, timestamp, statusCode).send({
                    from: oracles[i].address
                }, (error, result) => {
                    if (error) {
                        console.log(error)
                    } else {
                        console.log(`${JSON.stringify(oracles[i])}: status:  ${statusCode}`);
                    }
                })
            }
        }
        console.log(event)
    });
})()

const app = express();
app.get('/api', (req, res) => {
    res.send({
        message: 'An API for use with your Dapp!'
    })
})

export default app;


