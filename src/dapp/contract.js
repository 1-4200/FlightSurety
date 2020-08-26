import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {
        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.flights = [];
        this.passengers = [];
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
            this.owner = accts[0];

            for (let i = 0; i < 5; i++) {
                this.airlines.push({
                    airline: accts[i],
                    flight: `Flight#${i}`,
                    time: Math.floor(Date.now() / 1000)
                });
            }
            for (let i = 1; i <= 5; i++) {
                this.passengers.push(accts[i]);
            }
            // this.registerAirlines();
            this.registerFlights();

            callback();
        }).then(r => function () {

        });
    }

    async registerAirlines() {
        let self = this;
        for (let i = 1; i <= self.airlines.length; i++) {
            let res = await self.flightSuretyApp.methods
                .registerAirline(self.airlines[i].airline)
                .send({from: self.owner}, (error, result) => {
                    console.log("registerAirline", error, result)
                });
            await self.flightSuretyData.methods
                .fund(self.airlines[i].airline)
                .send({from: self.owner, value: this.web3.utils.toWei('10', 'ether')}, (error, result) => {
                    console.log("fund", error, result)
                })
        }
    }

    registerFlights() {
        const self = this;
        const length = self.airlines.length;
        for (let i = 0; i < length; i++) {
            self.flightSuretyApp.methods
                .registerFlight(self.airlines[i].airline, self.airlines[i].flight, self.airlines[i].time)
                .send({from: self.owner, gas: 3000000}, (error, result) => {
                    console.log(error, result)
                });
        }
    }

    isOperational(callback) {
        let self = this;
        self.flightSuretyApp.methods
            .isOperational()
            .call({from: self.owner}, callback);
    }

    fetchFlightStatus(airline, flight, timestamp, callback) {
        let self = this;
        let payload = {
            airline: airline,
            flight: flight,
            timestamp: timestamp
        }
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({from: self.owner}, (error, result) => {
                callback(error, payload);
            });
    }

    async getFlights(callback) {
        let self = this;
        let result = await self.flightSuretyApp.methods
            ._getRegisteredFlightCount()
            .call({from: self.owner});
        let flightCount = result.toNumber();
        this.flights = [];
        for (let i = 0; i < flightCount; i++) {
            let res = await self.flightSuretyApp.methods
                ._getFlight(i)
                .call({from: self.owner});
            this.flights.push(res);
        }
        callback(false, this.flights);
    };

    async buy(airline, flight, timestamp, callback) {
        let self = this;
        let amount = this.web3.utils.toWei('1', 'ether').toString();

        await self.flightSuretyData.methods
            .buy(airline, flight, timestamp)
            .send({ from: self.passengers[0], value: amount, gas: 3000000 }, (error, result) => {
                callback(error, result);
            });
    }
}
