pragma solidity 0.5.16 <= 0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    mapping(address => bool) private authorizedContracts;

    struct Airline {
        bool isRegistered;
        bool isFunded;
        uint256 deposit;
    }

    mapping(address => Airline) private registeredAirlines;
    address[] airlines;

    struct Insurance {
        address passenger;
        uint256 amount;
    }

    struct Flight {
        string name;
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
        Insurance[] insurances;
    }

    mapping(bytes32 => Flight) private registeredFlights;
    bytes32[] flights;

    mapping(address => uint256) private passengersRefund;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    event eventAirlineRegistered(address airline);
    event eventFlightRegistered(address _airline, string _name, uint256 _timestamp);
    event eventFlightStatusUpdated(bytes32 _flightKey, uint8 _statusCode);
    event eventInsurancePurchased(bytes32 flightKey, address passender, uint256 amount);
    event eventInsuranceRefunded(bytes32 flightKey, address passender, uint256 refund);

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor() public payable {
        contractOwner = msg.sender;
        registerFirstAirline(msg.sender);
        fund(msg.sender);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _;
        // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not data contract owner");
        _;
    }

    modifier isCallerAuthorized() {
        require(authorizedContracts[msg.sender] == true, 'Caller is not authorized app contract');
        _;
    }

    modifier requireNot0xAddress(address _sender) {
        require(_sender != address(0), "Invalid address");
        _;
    }

    modifier requireNotRegisteredAirlineAddress(address _airline) {
        require(isAirlineRegistered(_airline) == false, "Airline is already registered");
        _;
    }

    modifier requireRegisteredAirlineAddress(address _airline) {
        require(isAirlineRegistered(_airline) == true, "Airline is not registered");
        _;
    }

    modifier requireFundedAirline(address _airline) {
        require(isAirlineFunded(_airline) == true, "Airline is not funded");
        _;
    }

    modifier requireRegisteredFlight(bytes32 _flightKey) {
        require(isFlightRegistered(_flightKey) == true, "Flight is not registered");
        _;
    }

    modifier requireMinimumFund(uint _value) {
        require(_value >= 10 ether, "Fund is not enough, must be more than 10 ether");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function authorizeCaller(address _doa) external requireContractOwner requireNot0xAddress(_doa) {
        authorizedContracts[_doa] = true;
    }

    function deauthorizeCaller(address _doa) external requireContractOwner requireNot0xAddress(_doa) {
        authorizedContracts[_doa] = false;
    }

    function isAirlineRegistered(address _airline) public view returns (bool) {
        return registeredAirlines[_airline].isRegistered;
    }

    function isAirlineFunded(address _airline) public view returns (bool) {
        return registeredAirlines[_airline].isFunded;
    }

    function isFlightRegistered(bytes32 _flightKey) public view returns (bool) {
        return registeredFlights[_flightKey].isRegistered;
    }

    function insuranceAmount(address _airline, string calldata _flight, uint256 _timestamp, address _passenger) external view returns (uint256) {
        uint256 amount = 0;
        bytes32 flightKey = getFlightKey(_airline, _flight, _timestamp);
        uint insuranceCnt = registeredFlights[flightKey].insurances.length;
        for (uint i = 0; i < insuranceCnt; i++) {
            if (registeredFlights[flightKey].insurances[i].passenger == _passenger) {
                amount = registeredFlights[flightKey].insurances[i].amount;
                break;
            }
        }
        return amount;
    }


    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */
    function isOperational() public view returns (bool) {
        return operational;
    }

    function isAirline(address _airline) external view returns (bool) {
        return registeredAirlines[_airline].isRegistered;
    }

    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */
    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function getRegisteredAirlineCount() external view returns (uint256) {
        return airlines.length;
    }

    function getRegisteredFlightCount() external view returns (uint256) {
        return flights.length;
    }

    function getFlight(uint256 index) external view returns (string memory name, uint256 updatedTimestamp, address airline, uint8 statusCode)
    {
        name = registeredFlights[flights[index]].name;
        updatedTimestamp = registeredFlights[flights[index]].updatedTimestamp;
        airline = registeredFlights[flights[index]].airline;
        statusCode = registeredFlights[flights[index]].statusCode;
    }

    function registerFirstAirline(address airline) internal requireIsOperational requireNot0xAddress(airline) {
        registeredAirlines[airline] = Airline({isRegistered : true, isFunded : false, deposit : 0});
        airlines.push(airline);
        emit eventAirlineRegistered(airline);
    }

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function registerAirline(address _airline) external requireIsOperational requireNot0xAddress(_airline) requireNotRegisteredAirlineAddress(_airline) {
        registeredAirlines[_airline] = Airline({isRegistered : true, isFunded : false, deposit : 0});
        airlines.push(_airline);
        emit eventAirlineRegistered(_airline);
    }

    function registerFlight(address _airline, string calldata _flight, uint256 _timestamp) external requireIsOperational requireNot0xAddress(_airline) {
        bytes32 flightKey = getFlightKey(_airline, _flight, _timestamp);
        registeredFlights[flightKey].name = _flight;
        registeredFlights[flightKey].isRegistered = true;
        registeredFlights[flightKey].updatedTimestamp = _timestamp;
        registeredFlights[flightKey].airline = _airline;

        flights.push(flightKey);
        emit eventFlightRegistered(_airline, _flight, _timestamp);
    }

    function setFlightStatus(bytes32 _flightKey, uint8 _statusCode) external isCallerAuthorized requireIsOperational {
        registeredFlights[_flightKey].statusCode = _statusCode;
        emit eventFlightStatusUpdated(_flightKey, _statusCode);
    }

    /**
     * @dev Buy insurance for a flight
     *
     */
    function buy(address airline, string calldata flight, uint256 timestamp) external payable requireIsOperational requireNot0xAddress(airline) requireRegisteredAirlineAddress(airline) {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        registeredFlights[flightKey].insurances.push(Insurance({passenger : msg.sender, amount : uint256(msg.value)}));
        emit eventInsurancePurchased(flightKey, msg.sender, uint256(msg.value));
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees(address _airline, string calldata _flight, uint256 _timestamp) external requireIsOperational requireRegisteredAirlineAddress(_airline) {
        bytes32 flightKey = getFlightKey(_airline, _flight, _timestamp);
        require(registeredFlights[flightKey].statusCode == 20, 'Airline is not delayed');
        uint insuranceCnt = registeredFlights[flightKey].insurances.length;
        for (uint i = 0; i < insuranceCnt; i++) {
            address passenger = registeredFlights[flightKey].insurances[i].passenger;
            uint256 refund = registeredFlights[flightKey].insurances[i].amount.mul(3).div(2);
            passengersRefund[passenger] = refund;
            emit eventInsuranceRefunded(flightKey, passenger, refund);
        }
    }


    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay(address payable passenger) external {
        require(passengersRefund[passenger] > 0, "Passenger has no balance");
        uint256 refund = passengersRefund[passenger];
        passengersRefund[passenger] = 0;
        passenger.transfer(refund);
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function fund(address _airline) public payable requireMinimumFund(msg.value) {
        registeredAirlines[_airline].isFunded = true;
        registeredAirlines[_airline].deposit.add(msg.value);
    }

    function getFlightKey(address airline, string memory flight, uint256 timestamp) pure internal returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable {
        fund(tx.origin);
    }
}

