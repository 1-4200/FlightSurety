pragma solidity 0.5.16 <= 0.6.0;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "@openzeppelin/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    FlightSuretyData flightSuretyData;

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner; // Account used to deploy contract
    bool private operational = true;

    // Only existing airline may register a new airline until there are at least four airlines registered
    // Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines
    uint8 private constant FLIGHT_NUMBER_REQUIREMENT_BEFORE_CONSENSUS = 4;

    address[] flightRegistrationConsensusApprovedBy = new address[](0);

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    event eventAirlineRegistered(address _airline);

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
    modifier requireIsOperational()
    {
        require(operational, "Contract is currently not operational");
        _;
        // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireNotApprovedBySender(address _sender) {
        bool alreadyApproved = false;
        uint consensusCount = flightRegistrationConsensusApprovedBy.length;
        for (uint i = 0; i < consensusCount; i++) {
            if (flightRegistrationConsensusApprovedBy[i] == _sender) {
                alreadyApproved == true;
                break;
            }
        }
        require(alreadyApproved == false, "Sender is already approved");
        _;
    }

    modifier requireNotRegisteredAirlineAddress(address _airline) {
        require(flightSuretyData.isAirlineRegistered(_airline) == false, "Airline is already registered");
        _;
    }

    modifier requireNotRegisteredFlight(address _airline, string memory _name, uint256 _timestamp) {
        bytes32 flightKey = getFlightKey(_airline, _name, _timestamp);
        require(flightSuretyData.isFlightRegistered(flightKey) == false, "Flight is already registered");
        _;
    }

    modifier requireRegisteredFlight(address _airline, string memory _name, uint256 _timestamp) {
        bytes32 flightKey = getFlightKey(_airline, _name, _timestamp);
        require(flightSuretyData.isFlightRegistered(flightKey) == true, "Flight is not registered");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor(address payable _doa) public {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(_doa);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns (bool) {
        return operational;
    }

    function setOperatingStatus(bool _mode) external requireContractOwner {
        operational = _mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/


    /**
     * @dev Add an airline to the registration queue
     *
     */
    function registerAirline(address _airline) external requireIsOperational requireNotRegisteredAirlineAddress(_airline) requireNotApprovedBySender(msg.sender) {
        bool success = true;
        uint256 currentRegisteredAirlineCount = flightSuretyData.getRegisteredAirlineCount();
        if (currentRegisteredAirlineCount >= FLIGHT_NUMBER_REQUIREMENT_BEFORE_CONSENSUS) {
            success = false;
            flightRegistrationConsensusApprovedBy.push(msg.sender);
            uint consensusCount = flightRegistrationConsensusApprovedBy.length;
            uint requirementCount = currentRegisteredAirlineCount.div(2);
            if (consensusCount >= requirementCount) {
                success = true;
                flightRegistrationConsensusApprovedBy = new address[](0);
            }
        }
        if (success == true) {
            flightSuretyData.registerAirline(_airline);
            emit eventAirlineRegistered(_airline);
        }
    }

    function _getRegisteredFlightCount() external requireIsOperational view returns (uint256) {
        return flightSuretyData.getRegisteredFlightCount();
    }

    function _getFlight(uint256 index) external requireIsOperational view returns (string memory name, uint256 updatedTimestamp, address airline, uint8 statusCode) {
        return flightSuretyData.getFlight(index);
    }

    /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight(address _airline, string calldata _flight, uint256 _timestamp) external requireIsOperational requireNotRegisteredFlight(_airline, _flight, _timestamp) {
        flightSuretyData.registerFlight(_airline, _flight, _timestamp);
    }

    /**
     * @dev Called after oracle has updated flight status
     *
     */
    function processFlightStatus(address _airline, string memory _flight, uint256 _timestamp, uint8 _statusCode) internal requireIsOperational requireRegisteredFlight(_airline, _flight, _timestamp) {
        bytes32 flightKey = getFlightKey(_airline, _flight, _timestamp);
        flightSuretyData.setFlightStatus(flightKey, _statusCode);
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(address airline, string calldata flight, uint256 timestamp) external {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
        requester : msg.sender,
        isOpen : true
        });

        emit OracleRequest(index, airline, flight, timestamp);
    }


    // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
        // This lets us group responses and identify
        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle() external payable {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
        isRegistered : true,
        indexes : indexes
        });
    }

    function getMyIndexes() view external returns (uint8[3] memory) {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }


    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(uint8 index, address airline, string calldata flight, uint256 timestamp, uint8 statusCode) external {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");

        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey(address airline, string memory flight, uint256 timestamp) pure internal returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account) internal returns (uint8[3] memory) {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while (indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account) internal returns (uint8) {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;
            // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }
}

// FlightSuretyContract interface
contract FlightSuretyData {
    // UTILITY FUNCTIONS
    function isAirlineRegistered(address _airline) external view returns (bool);

    function isFlightRegistered(bytes32 _flightKey) external view returns (bool);

    function isOperational() public view returns (bool);

    function isAirline(address _airline) external view returns (bool);

    // SMART CONTRACT FUNCTIONS
    function getRegisteredFlightCount() external view returns (uint256);

    function getFlight(uint256 index) external view returns (string memory name, uint256 updatedTimestamp, address airline, uint8 statusCode);

    function getRegisteredAirlineCount() external view returns (uint256);

    function registerAirline(address _airline) external;

    function registerFlight(address _airline, string calldata _flight, uint256 _timestamp) external;

    function setFlightStatus(bytes32 flightKey, uint8 statusCode) external;

    function creditInsuree(address _airline, string calldata _flight, uint256 _timestamp) external;

    function() external payable;
}
