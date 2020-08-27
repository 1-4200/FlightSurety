import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async () => {

    let result = null;

    let contract = new Contract('localhost', () => {
        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error, result);
            display('Operational Status', 'Check if contract is operational', [{
                label: 'Operational Status',
                error: error,
                value: result
            }]);
        });

        contract.getFlights((error, result) => {
            console.log("getFlights", error, result);
            displayFlights(result, 'oracle-flights');
            displayFlights([result[0]], 'insurance-flights');
            displayFlights([result[0]], 'insured-flights');
        });

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            const selectedEle = DOM.elid('oracle-flights');
            const airline = selectedEle.value;
            const flight = selectedEle.options[selectedEle.selectedIndex].getAttribute('data-flight');
            const timestamp = selectedEle.options[selectedEle.selectedIndex].getAttribute('data-timestamp');
            // Write transaction
            contract.fetchFlightStatus(airline, flight, timestamp, (error, result) => {
                display('Oracles', 'Trigger oracles', [{
                    label: 'Fetch Flight Status',
                    error: error,
                    value: result.flight + ' ' + result.timestamp
                }]);
            });
        })

        DOM.elid('purchase-insurance').addEventListener('click', () => {
            const selectedEle = DOM.elid('insurance-flights');
            const airline = selectedEle.value;
            const flight = selectedEle.options[selectedEle.selectedIndex].getAttribute('data-flight');
            const timestamp = selectedEle.options[selectedEle.selectedIndex].getAttribute('data-timestamp');
            contract.buy(airline, flight, timestamp, (error, transactionHash) => {
                console.log("buy", error, transactionHash)
                display('Insurance', 'successfully bought!', [{
                    label: 'Buy Insurance',
                    error: error,
                    value: transactionHash
                }]);
            });
        })

        DOM.elid('withdraw-credits').addEventListener('click', () => {
            contract.pay(contract.passengers[0], (error, transactionHash) => {
                console.log("withdraw", error, transactionHash)
                display('Withdraw', 'successfully withdraw!', [{
                    label: 'Withdraw Credit',
                    error: error,
                    value: transactionHash
                }]);
            });
        })

        DOM.elid('claim-flight-insurance').addEventListener('click', () => {
            const selectedEle = DOM.elid('insurance-flights');
            const airline = selectedEle.value;
            const flight = selectedEle.options[selectedEle.selectedIndex].getAttribute('data-flight');
            const timestamp = selectedEle.options[selectedEle.selectedIndex].getAttribute('data-timestamp');
            contract.creditInsurees(airline, flight, timestamp, (error, transactionHash) => {
                console.log("creditInsurees", error, transactionHash)
            });
        });
    });
})();

function displayFlights(flights, id) {
    const selectableFlights = DOM.elid(id);
    flights.forEach((flight) => {
        const option = document.createElement('option');
        option.setAttribute('data-flight', flight.name);
        option.setAttribute('data-timestamp', flight.updatedTimestamp);
        option.value = `${flight.airline}`;
        option.textContent = `${flight.name}`;
        selectableFlights.appendChild(option);
    });
}

function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className: 'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);
}







