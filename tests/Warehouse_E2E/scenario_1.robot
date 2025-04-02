*** Settings ***
Documentation     Comprehensive Test Suite for Warehouse Structure in vKho API
...               Covers Warehouses, Zones, and Racks management
...               Includes proper parameter validation and error handling
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime

*** Variables ***
${BASE_URL}             https://api.vkho.net
${ADMIN_USERNAME}       admin
${ADMIN_PASSWORD}       admin
${MANAGER_USERNAME}     huynh22.manager
${MANAGER_PASSWORD}     Snowfox1991
${WAREHOUSE_ID}         6
${RESULTS_DIR}          ${CURDIR}${/}results
${TEST_WAREHOUSE_ID}    ${EMPTY}
${TEST_ZONE_ID}         ${EMPTY}
${TEST_RACK_ID}         ${EMPTY}
${TEST_SHELF_ID}        ${EMPTY}

*** Keywords ***
Setup Admin Session
    [Documentation]     Create API session and authenticate with admin credentials
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${ADMIN_USERNAME}    password=${ADMIN_PASSWORD}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    access_token
    
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${ADMIN_TOKEN}    ${token}
    
    Create Directory    ${RESULTS_DIR}

Setup Manager Session
    [Documentation]     Create API session and authenticate with manager credentials
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${MANAGER_USERNAME}    password=${MANAGER_PASSWORD}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    access_token
    
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${MANAGER_TOKEN}    ${token}

Generate Unique Warehouse Data
    [Documentation]     Generate unique data for warehouse tests
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_name}=  Set Variable     Test Warehouse ${timestamp}
    ${warehouse_data}=  Create Dictionary
    ...                 name=${warehouse_name}
    ...                 address=123 Test Street
    ...                 acreage=1000
    RETURN            ${warehouse_data}

Generate Unique Zone Data
    [Documentation]     Generate unique data for zone tests
    [Arguments]         ${warehouse_id}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${zone_name}=       Set Variable     Test Zone ${timestamp}
    ${zone_data}=      Create Dictionary
    ...                 capacity=500
    ...                 name=${zone_name}
    ...                 warehouseId=${warehouse_id}
    RETURN            ${zone_data}

Generate Unique Rack Data
    [Documentation]     Generate unique data for rack tests
    [Arguments]         ${warehouse_id}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${rack_data}=      Create Dictionary
    ...                 capacity=100
    ...                 warehouseId=${warehouse_id}
    ...                 shelfId=1
    RETURN            ${rack_data}

Create Warehouse
    [Documentation]     Create a new warehouse and return its ID
    [Arguments]         ${warehouse_data}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /warehouses/create
    ...                 json=${warehouse_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    
    ${warehouse_id}=    Convert To String    ${json}[id]
    RETURN            ${warehouse_id}    ${json}

Create Zone
    [Documentation]     Create a new zone and return its ID
    [Arguments]         ${zone_data}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /zones/create
    ...                 json=${zone_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    
    ${zone_id}=        Convert To String    ${json}[id]
    RETURN            ${zone_id}    ${json}

Create Rack
    [Documentation]     Create a new rack and return its ID
    [Arguments]         ${rack_data}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /racks/create
    ...                 json=${rack_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    id
    
    ${rack_id}=        Convert To String    ${json}[id]
    RETURN            ${rack_id}    ${json}

Get Warehouse By ID
    [Documentation]     Retrieve a specific warehouse by ID
    [Arguments]         ${warehouse_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    
    ${response}=        GET On Session
    ...                 vkho
    ...                 /warehouses/get-one/${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}

Get Zone By ID
    [Documentation]     Retrieve a specific zone by ID
    [Arguments]         ${zone_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        GET On Session
    ...                 vkho
    ...                 /zones/get-one/${zone_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}

Get Rack By ID
    [Documentation]     Retrieve a specific rack by ID
    [Arguments]         ${rack_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        GET On Session
    ...                 vkho
    ...                 /racks/get-one/${rack_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}

Update Warehouse
    [Documentation]     Update an existing warehouse
    [Arguments]         ${warehouse_id}    ${update_data}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /warehouses/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}

Update Zone
    [Documentation]     Update an existing zone
    [Arguments]         ${zone_id}    ${update_data}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /zones/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}

Update Rack
    [Documentation]     Update an existing rack
    [Arguments]         ${rack_id}    ${update_data}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /racks/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}

Delete Warehouse
    [Documentation]     Delete a warehouse
    [Arguments]         ${warehouse_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /warehouses/delete/${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    RETURN            ${TRUE}

Delete Zone
    [Documentation]     Delete a zone
    [Arguments]         ${zone_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /zones/delete/${zone_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    RETURN            ${TRUE}

Delete Rack
    [Documentation]     Delete a rack
    [Arguments]         ${rack_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /racks/delete/${rack_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    RETURN            ${TRUE}

Assert Structure Details
    [Documentation]     Verify structure details match expected values
    [Arguments]         ${actual}    ${expected}
    
    FOR    ${key}    IN    @{expected.keys()}
        Run Keyword If    "${key}" in ${actual}    Should Be Equal    ${actual}[${key}]    ${expected}[${key}]
        ...    msg=${key} value '${actual}[${key}]' does not match expected '${expected}[${key}]'
    END

Create Test Warehouse
    [Documentation]     Creates a test warehouse if one doesn't exist
    ${warehouse_data}=  Generate Unique Warehouse Data
    ${warehouse_id}    ${response}=    Create Warehouse    ${warehouse_data}
    Set Global Variable  ${TEST_WAREHOUSE_ID}    ${warehouse_id}
    RETURN            ${warehouse_id}    ${warehouse_data}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API sessions for warehouse structure tests
    [Tags]              setup
    Setup Admin Session
    Setup Manager Session
    Log                 Successfully authenticated with admin and manager tokens

02 - Create Warehouse Test
    [Documentation]     Test creating a new warehouse
    [Tags]              warehouse    create    positive
    
    ${warehouse_data}=  Generate Unique Warehouse Data
    ${warehouse_id}    ${response}=    Create Warehouse    ${warehouse_data}
    
    Should Not Be Empty    ${warehouse_id}
    Should Be Equal     ${response}[name]    ${warehouse_data}[name]
    
    Set Global Variable  ${TEST_WAREHOUSE_ID}    ${warehouse_id}
    Log                 Successfully created warehouse: ${response}[name] with ID: ${warehouse_id}

03 - Create Zone Test
    [Documentation]     Test creating a new zone
    [Tags]              zone    create    positive
    
    Run Keyword If      "${TEST_WAREHOUSE_ID}" == "${EMPTY}"    Create Test Warehouse
    ${zone_data}=       Generate Unique Zone Data    ${TEST_WAREHOUSE_ID}
    ${zone_id}    ${response}=    Create Zone    ${zone_data}
    
    Should Not Be Empty    ${zone_id}
    Should Be Equal     ${response}[name]    ${zone_data}[name]
    
    Set Global Variable  ${TEST_ZONE_ID}    ${zone_id}
    Log                 Successfully created zone: ${response}[name] with ID: ${zone_id}

04 - Create Rack Test
    [Documentation]     Test creating a new rack
    [Tags]              rack    create    positive
    
    Run Keyword If      "${TEST_WAREHOUSE_ID}" == "${EMPTY}"    Create Test Warehouse
    ${rack_data}=       Generate Unique Rack Data    ${TEST_WAREHOUSE_ID}
    ${rack_id}    ${response}=    Create Rack    ${rack_data}
    
    Should Not Be Empty    ${rack_id}
    Should Be Equal     ${response}[capacity]    ${rack_data}[capacity]
    
    Set Global Variable  ${TEST_RACK_ID}    ${rack_id}
    Log                 Successfully created rack with ID: ${rack_id}

05 - Get Warehouse Test
    [Documentation]     Test retrieving a specific warehouse
    [Tags]              warehouse    retrieve    positive
    
    Run Keyword If      "${TEST_WAREHOUSE_ID}" == "${EMPTY}"    Create Test Warehouse
    ${warehouse}=       Get Warehouse By ID    ${TEST_WAREHOUSE_ID}
    
    Should Not Be Empty    ${warehouse}[name]
    Log                 Successfully retrieved warehouse: ${warehouse}[name]

06 - Get Zone Test
    [Documentation]     Test retrieving a specific zone
    [Tags]              zone    retrieve    positive
    
    Run Keyword If      "${TEST_ZONE_ID}" == "${EMPTY}"    Create Zone    ${Generate Unique Zone Data    ${TEST_WAREHOUSE_ID}}
    ${zone}=           Get Zone By ID    ${TEST_ZONE_ID}
    
    Should Not Be Empty    ${zone}[name]
    Log                 Successfully retrieved zone: ${zone}[name]

07 - Get Rack Test
    [Documentation]     Test retrieving a specific rack
    [Tags]              rack    retrieve    positive
    
    Run Keyword If      "${TEST_RACK_ID}" == "${EMPTY}"    Create Rack    ${Generate Unique Rack Data    ${TEST_WAREHOUSE_ID}}
    ${rack}=           Get Rack By ID    ${TEST_RACK_ID}
    
    Should Not Be Empty    ${rack}[capacity]
    Log                 Successfully retrieved rack with ID: ${rack}[id]

08 - Update Warehouse Test
    [Documentation]     Test updating an existing warehouse
    [Tags]              warehouse    update    positive
    
    ${warehouse_id}    ${warehouse_data}=    Create Test Warehouse
    ${update_data}=    Create Dictionary
    ...                 id=${warehouse_id}
    ...                 name=${warehouse_data}[name] Updated
    ...                 address=456 Updated Street
    ...                 acreage=1500
    ...                 status=ENABLE
    
    ${updated}=         Update Warehouse    ${warehouse_id}    ${update_data}
    Should Be Equal     ${updated}[name]    ${update_data}[name]
    Log                 Successfully updated warehouse: ${updated}[name]

09 - Update Zone Test
    [Documentation]     Test updating an existing zone
    [Tags]              zone    update    positive
    
    Run Keyword If      "${TEST_ZONE_ID}" == "${EMPTY}"    Create Zone    ${Generate Unique Zone Data    ${TEST_WAREHOUSE_ID}}
    ${update_data}=    Create Dictionary
    ...                 id=${TEST_ZONE_ID}
    ...                 capacity=750
    ...                 name=Updated Zone
    ...                 warehouseId=${TEST_WAREHOUSE_ID}
    ...                 status=ENABLE
    
    ${updated}=         Update Zone    ${TEST_ZONE_ID}    ${update_data}
    Should Be Equal     ${updated}[name]    ${update_data}[name]
    Log                 Successfully updated zone: ${updated}[name]

10 - Update Rack Test
    [Documentation]     Test updating an existing rack
    [Tags]              rack    update    positive
    
    Run Keyword If      "${TEST_RACK_ID}" == "${EMPTY}"    Create Rack    ${Generate Unique Rack Data    ${TEST_WAREHOUSE_ID}}
    ${update_data}=    Create Dictionary
    ...                 id=${TEST_RACK_ID}
    ...                 capacity=150
    ...                 warehouseId=${TEST_WAREHOUSE_ID}
    ...                 shelfId=2
    ...                 status=ENABLE
    
    ${updated}=         Update Rack    ${TEST_RACK_ID}    ${update_data}
    Should Be Equal     ${updated}[capacity]    ${update_data}[capacity]
    Log                 Successfully updated rack with ID: ${updated}[id]

11 - Delete Rack Test
    [Documentation]     Test deleting a rack
    [Tags]              rack    delete    positive
    
    Run Keyword If      "${TEST_RACK_ID}" == "${EMPTY}"    Create Rack    ${Generate Unique Rack Data    ${TEST_WAREHOUSE_ID}}
    ${result}=          Delete Rack    ${TEST_RACK_ID}
    Should Be True      ${result}
    Log                 Successfully deleted rack with ID: ${TEST_RACK_ID}

12 - Delete Zone Test
    [Documentation]     Test deleting a zone
    [Tags]              zone    delete    positive
    
    Run Keyword If      "${TEST_ZONE_ID}" == "${EMPTY}"    Create Zone    ${Generate Unique Zone Data    ${TEST_WAREHOUSE_ID}}
    ${result}=          Delete Zone    ${TEST_ZONE_ID}
    Should Be True      ${result}
    Log                 Successfully deleted zone with ID: ${TEST_ZONE_ID}

13 - Delete Warehouse Test
    [Documentation]     Test deleting a warehouse
    [Tags]              warehouse    delete    positive
    
    Run Keyword If      "${TEST_WAREHOUSE_ID}" == "${EMPTY}"    Create Test Warehouse
    ${result}=          Delete Warehouse    ${TEST_WAREHOUSE_ID}
    Should Be True      ${result}
    Log                 Successfully deleted warehouse with ID: ${TEST_WAREHOUSE_ID}

14 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    Run Keyword If      "${TEST_RACK_ID}" != "${EMPTY}"    Delete Rack    ${TEST_RACK_ID}
    Run Keyword If      "${TEST_ZONE_ID}" != "${EMPTY}"    Delete Zone    ${TEST_ZONE_ID}
    Run Keyword If      "${TEST_WAREHOUSE_ID}" != "${EMPTY}"    Delete Warehouse    ${TEST_WAREHOUSE_ID}
    Log                 Test environment cleaned up successfully