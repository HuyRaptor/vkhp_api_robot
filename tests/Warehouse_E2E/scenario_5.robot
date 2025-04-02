*** Settings ***
Documentation     Complex End-to-End Test Suite for Warehouse Management
...               Tests warehouse setup with multiple zones and racks
...               Includes capacity constraints and business rule validation
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
${RESULTS_DIR}          ${CURDIR}${/}results
${TEST_WAREHOUSE_ID}    ${EMPTY}
@{TEST_ZONE_IDS}        ${EMPTY}
@{TEST_RACK_IDS}        ${EMPTY}
${MAX_WAREHOUSE_CAPACITY}    5000    # Total capacity in square footage
${MAX_ZONE_CAPACITY}         2000    # Max capacity per zone

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
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${MANAGER_TOKEN}    ${token}

Generate Warehouse Data
    [Documentation]     Generate data for warehouse creation with capacity limit
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_data}=  Create Dictionary
    ...                 name=Complex Warehouse ${timestamp}
    ...                 address=456 Industrial Park
    ...                 acreage=${MAX_WAREHOUSE_CAPACITY}
    RETURN            ${warehouse_data}

Generate Zone Data
    [Documentation]     Generate zone data with specific capacity
    [Arguments]         ${warehouse_id}    ${capacity}    ${zone_type}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${zone_data}=      Create Dictionary
    ...                 capacity=${capacity}
    ...                 name=${zone_type} Zone ${timestamp}
    ...                 warehouseId=${warehouse_id}
    RETURN            ${zone_data}

Generate Rack Data
    [Documentation]     Generate rack data with specific capacity
    [Arguments]         ${warehouse_id}    ${zone_id}    ${capacity}
    ${rack_data}=      Create Dictionary
    ...                 capacity=${capacity}
    ...                 warehouseId=${warehouse_id}
    ...                 zoneId=${zone_id}
    ...                 shelfId=1
    RETURN            ${rack_data}

Create Warehouse
    [Documentation]     Create a new warehouse
    [Arguments]         ${warehouse_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /warehouses/create
    ...                 json=${warehouse_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}[id]    ${json}

Create Zone
    [Documentation]     Create a new zone with validation
    [Arguments]         ${zone_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /zones/create
    ...                 json=${zone_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Create Rack
    [Documentation]     Create a new rack with validation
    [Arguments]         ${rack_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /racks/create
    ...                 json=${rack_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Get Warehouse Details
    [Documentation]     Get warehouse details with nested structures
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /warehouses/get-one/${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}

Update Zone Capacity
    [Documentation]     Update zone capacity
    [Arguments]         ${zone_id}    ${new_capacity}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${update_data}=    Create Dictionary
    ...                 id=${zone_id}
    ...                 capacity=${new_capacity}
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /zones/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}

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

Validate Capacity Constraints
    [Documentation]     Validate total capacity doesn't exceed warehouse limits
    [Arguments]         ${warehouse}    ${total_zone_capacity}    ${total_rack_capacity}
    ${warehouse_capacity}=    Convert To Number    ${warehouse}[acreage]
    Should Be True    ${total_zone_capacity} <= ${warehouse_capacity}
    ...               Total zone capacity ${total_zone_capacity} exceeds warehouse capacity ${warehouse_capacity}
    Should Be True    ${total_rack_capacity} <= ${total_zone_capacity}
    ...               Total rack capacity ${total_rack_capacity} exceeds total zone capacity ${total_zone_capacity}

Calculate Total Capacity
    [Documentation]     Calculate total capacity of zones or racks
    [Arguments]         @{items}
    ${total}=          Set Variable    0
    FOR    ${item}    IN    @{items}
        ${capacity}=    Convert To Number    ${item}[capacity]
        ${total}=       Evaluate    ${total} + ${capacity}
    END
    RETURN            ${total}

*** Test Cases ***
01 - Complex Warehouse Management Flow
    [Documentation]     Test complex warehouse management with capacity validation
    [Tags]              e2e    warehouse    zone    rack    validation

    # Setup
    Setup Admin Session
    Setup Manager Session
    Log                 Authentication completed successfully

    # Step 1: Create Warehouse
    ${warehouse_data}=  Generate Warehouse Data
    ${warehouse_id}    ${warehouse_response}=    Create Warehouse    ${warehouse_data}
    Set Global Variable  ${TEST_WAREHOUSE_ID}    ${warehouse_id}
    Should Be Equal As Integers    ${warehouse_response}[acreage]    ${MAX_WAREHOUSE_CAPACITY}
    Log                 Created warehouse: ${warehouse_response}[name] with ID: ${warehouse_id}

    # Step 2: Create Multiple Zones with Capacity Constraints
    ${zone1_data}=     Generate Zone Data    ${warehouse_id}    1500    Primary
    ${status1}    ${zone1_response}=    Create Zone    ${zone1_data}
    Should Be Equal As Integers    ${status1}    201
    Append To List    ${TEST_ZONE_IDS}    ${zone1_response}[id]
    Log               Created primary zone: ${zone1_response}[name]

    ${zone2_data}=     Generate Zone Data    ${warehouse_id}    1200    Secondary
    ${status2}    ${zone2_response}=    Create Zone    ${zone2_data}
    Should Be Equal As Integers    ${status2}    201
    Append To List    ${TEST_ZONE_IDS}    ${zone2_response}[id]
    Log               Created secondary zone: ${zone2_response}[name]

    # Step 3: Attempt to Create Zone Exceeding Warehouse Capacity
    ${zone3_data}=     Generate Zone Data    ${warehouse_id}    3000    Overflow
    ${status3}    ${zone3_response}=    Create Zone    ${zone3_data}
    Should Be Equal As Integers    ${status3}    400
    Should Contain    ${zone3_response}[message]    capacity    ignore_case=True
    Log               Successfully prevented zone creation exceeding warehouse capacity

    # Step 4: Create Racks in Zones
    ${rack1_data}=     Generate Rack Data    ${warehouse_id}    ${zone1_response}[id]    800
    ${status_r1}    ${rack1_response}=    Create Rack    ${rack1_data}
    Should Be Equal As Integers    ${status_r1}    201
    Append To List    ${TEST_RACK_IDS}    ${rack1_response}[id]
    Log               Created rack 1 in primary zone with ID: ${rack1_response}[id]

    ${rack2_data}=     Generate Rack Data    ${warehouse_id}    ${zone2_response}[id]    600
    ${status_r2}    ${rack2_response}=    Create Rack    ${rack2_data}
    Should Be Equal As Integers    ${status_r2}    201
    Append To List    ${TEST_RACK_IDS}    ${rack2_response}[id]
    Log               Created rack 2 in secondary zone with ID: ${rack2_response}[id]

    # Step 5: Attempt to Create Rack Exceeding Zone Capacity
    ${rack3_data}=     Generate Rack Data    ${warehouse_id}    ${zone1_response}[id]    1000
    ${status_r3}    ${rack3_response}=    Create Rack    ${rack3_data}
    Should Be Equal As Integers    ${status_r3}    400
    Should Contain    ${rack3_response}[message]    capacity    ignore_case=True
    Log               Successfully prevented rack creation exceeding zone capacity

    # Step 6: Update Zone Capacity and Validate
    ${updated_zone1}=    Update Zone Capacity    ${zone1_response}[id]    1800
    Should Be Equal As Integers    ${updated_zone1}[capacity]    1800
    Log                 Updated primary zone capacity to 1800

    # Step 7: Verify Structure and Capacity
    ${warehouse_details}=    Get Warehouse Details    ${warehouse_id}
    ${zone_capacity}=    Calculate Total Capacity    @{warehouse_details}[zones]
    ${rack_capacity}=    Calculate Total Capacity    @{warehouse_details}[zones][0][racks]    @{warehouse_details}[zones][1][racks]
    Validate Capacity Constraints    ${warehouse_details}    ${zone_capacity}    ${rack_capacity}
    Log                 Successfully validated capacity constraints

    # Step 8: Clean Up
    FOR    ${rack_id}    IN    @{TEST_RACK_IDS}
        Delete Rack    ${rack_id}
    END
    FOR    ${zone_id}    IN    @{TEST_ZONE_IDS}
        Delete Zone    ${zone_id}
    END
    Delete Warehouse    ${TEST_WAREHOUSE_ID}
    Log                 Successfully cleaned up all resources