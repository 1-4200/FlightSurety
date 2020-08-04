var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

    var config;
    before('setup contract', async () => {
        config = await Test.Config(accounts);
        await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address, {from: config.owner});
    });

    /****************************************************************************************/
    /* Operations and Settings                                                              */
    /****************************************************************************************/

    it(`(multiparty) has correct initial isOperational() value`, async function () {

        // Get operating status
        let status = await config.flightSuretyData.isOperational.call();
        assert.equal(status, true, "Incorrect initial operating status value");

    });

    it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

        // Ensure that access is denied for non-Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.setOperatingStatus(false, {from: config.testAddresses[2]});
        } catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

        // Ensure that access is allowed for Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.setOperatingStatus(false);
        } catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

        await config.flightSuretyData.setOperatingStatus(false);

        let reverted = false;
        try {
            await config.flightSurety.setTestingMode(true);
        } catch (e) {
            reverted = true;
        }
        assert.equal(reverted, true, "Access not blocked for requireIsOperational");

        // Set it back for other tests to work
        await config.flightSuretyData.setOperatingStatus(true);

    });

    it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {

        // ARRANGE
        let newAirline = accounts[2];
        let newAirlineName = "test";

        // ACT
        try {
            await config.flightSuretyApp.registerAirline(newAirline, newAirlineName, {from: config.secondAirline});
        } catch (e) {

        }
        let result = await config.flightSuretyData.isAirline.call(newAirline);

        // ASSERT
        assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

    });

    it('first airline is registered when contract is deployed', async () => {
        const registeredFlightCnt = await config.flightSuretyData.getRegisteredAirlineCount.call({from: config.owner});
        assert.equal(registeredFlightCnt, 1, "first airline is not registered when contract is deployed")

        const registeredAirline = await config.flightSuretyData.isAirline.call(config.owner, {from: config.owner});
        assert.equal(registeredAirline, true, "first airline is not registered when contract is deployed")
    });

    it('Only existing airline may register a new airline until there are at least four airlines registered', async () => {
        await config.flightSuretyApp.registerAirline(config.secondAirline, {from: config.owner});
        const registeredAirline = await config.flightSuretyData.isAirline.call(config.secondAirline, {from: config.owner});
        assert.equal(registeredAirline, true, "second airline is not registered")

        await config.flightSuretyApp.registerAirline(config.thirdAirline, {from: config.secondAirline});
        await config.flightSuretyApp.registerAirline(config.forthAirline, {from: config.thirdAirline});
        const registeredFlightCnt = await config.flightSuretyData.getRegisteredAirlineCount.call({from: config.owner});
        assert.equal(registeredFlightCnt, 4, "airline is not registered if there are less than forth airline exist without consensus")
    });

    it('Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines', async () => {
        await config.flightSuretyApp.registerAirline(config.fifthAirline, {from: config.owner});
        await config.flightSuretyApp.registerAirline(config.fifthAirline, {from: config.secondAirline});
        const registeredFlightCnt = await config.flightSuretyData.getRegisteredAirlineCount.call({from: config.owner});
        assert.equal(registeredFlightCnt, 5, "fifth airline should be registered with 50% of consensus");
    });

    it('Airline can be registered, but does not participate in contract until it submits funding of 10 ether', async () => {
        await config.flightSuretyData.fund(config.secondAirline, {from: config.owner, value: config.fund});
        let isFunded = await config.flightSuretyData.isAirlineFunded(config.secondAirline, {from: config.owner});
        assert.equal(isFunded, true, "airline is not funded");

        await config.flightSuretyApp.registerFlight(config.secondAirline, config.firstFlightName, config.firstFlightTimestamp, {from: config.owner})
        let registeredFlightCount = await config.flightSuretyData.getRegisteredFlightCount.call({from: config.owner});
        assert.equal(registeredFlightCount, 1, "flight is not registered")
    });

    it('Passengers may pay up to 1 ether for purchasing flight insurance', async () => {
        await config.flightSuretyData.buy(config.secondAirline, config.firstFlightName, config.firstFlightTimestamp, 2, {
            from: config.owner,
            value: config.insuranceFee
        });
        let amount = await config.flightSuretyData.insuranceAmount(config.secondAirline, config.firstFlightName, config.firstFlightTimestamp, config.owner, {from: config.owner});
        assert.equal(amount, config.insuranceFee, "insurance is not bought");
    });
});
