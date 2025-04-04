*** Settings ***
Documentation     Complex End-to-End Test Suite for Warehouse Management with Status and Blocks
...               Tests warehouse state transitions and multi-level storage hierarchy
...               Includes concurrent resource management validation
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Resource          ../../Variables/variables.robot

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
    [Documentation]     Generate data for warehouse with initial status
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_data}=  Create Dictionary
    ...                 name=State Warehouse ${timestamp}
    ...                 address=101 Warehouse Lane
    ...                 acreage=3000
    ...                 status=${INITIAL_STATUS}
    RETURN            ${warehouse_data}

Generate Zone Data
    [Documentation]     Generate zone data
    [Arguments]         ${warehouse_id}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${zone_data}=      Create Dictionary
    ...                 capacity=1500
    ...                 name=Main Zone ${timestamp}
    ...                 warehouseId=${warehouse_id}
    RETURN            ${zone_data}

Generate Block Data
    [Documentation]     Generate block data
    [Arguments]         ${zone_id}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${block_data}=     Create Dictionary
    ...                 capacity=1000
    ...                 name=Storage Block ${timestamp}
    ...                 zoneId=${zone_id}
    RETURN            ${block_data}

Generate Rack Data
    [Documentation]     Generate rack data with block association
    [Arguments]         ${warehouse_id}    ${zone_id}    ${block_id}    ${capacity}
    ${rack_data}=      Create Dictionary
    ...                 capacity=${capacity}
    ...                 warehouseId=${warehouse_id}
    ...                 zoneId=${zone_id}
    ...                 blockId=${block_id}
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
    [Documentation]     Create a new zone
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

Create Block
    [Documentation]     Create a new block
    [Arguments]         ${block_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /blocks/create
    ...                 json=${block_data}
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

Update Warehouse Status
    [Documentation]     Update warehouse status
    [Arguments]         ${warehouse_id}    ${new_status}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    ${update_data}=    Create Dictionary
    ...                 id=${warehouse_id}
    ...                 status=${new_status}
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /warehouses/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}

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

Delete Block
    [Documentation]     Delete a block
    [Arguments]         ${block_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /blocks/delete/${block_id}
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

Validate Warehouse Structure
    [Documentation]     Validate the complete warehouse structure
    [Arguments]         ${warehouse}    ${zone_id}    ${block_id}    @{rack_ids}
    Should Be Equal As Strings    ${warehouse}[zones][0][id]         ${zone_id}
    Should Be Equal As Strings    ${warehouse}[zones][0][blocks][0][id]    ${block_id}
    ${rack_count}=               Get Length    ${rack_ids}
    Should Be Equal As Integers  ${rack_count}    ${warehouse}[zones][0][blocks][0][racks][@size]
    FOR    ${rack_id}    IN    @{rack_ids}
        Should Contain    ${warehouse}[zones][0][blocks][0][racks]    ${rack_id}
    END

*** Test Cases ***
01 - Warehouse State and Structure Management Flow
    [Documentation]     Test warehouse management with status transitions and block hierarchy
    [Tags]              e2e    warehouse    zone    block    rack    state

    # Setup
    Setup Admin Session
    Setup Manager Session
    Log                 Authentication completed successfully

    # Step 1: Create Warehouse in Disabled State
    ${warehouse_data}=  Generate Warehouse Data
    ${warehouse_id}    ${warehouse_response}=    Create Warehouse    ${warehouse_data}
    Set Global Variable  ${TEST_WAREHOUSE_ID}    ${warehouse_id}
    Should Be Equal     ${warehouse_response}[status]    ${INITIAL_STATUS}
    Log                 Created warehouse: ${warehouse_response}[name] with ID: ${warehouse_id} in ${INITIAL_STATUS} state

    # Step 2: Attempt Zone Creation While Disabled
    ${zone_data}=      Generate Zone Data    ${warehouse_id}
    ${status_z}    ${zone_response}=    Create Zone    ${zone_data}
    Should Be Equal As Integers    ${status_z}    400
    Should Contain    ${zone_response}[message]    disabled    ignore_case=True
    Log               Successfully prevented zone creation in disabled warehouse

    # Step 3: Activate Warehouse
    ${updated_warehouse}=    Update Warehouse Status    ${warehouse_id}    ${ACTIVE_STATUS}
    Should Be Equal     ${updated_warehouse}[status]    ${ACTIVE_STATUS}
    Log                 Activated warehouse to ${ACTIVE_STATUS} state

    # Step 4: Create Zone
    ${zone_data}=      Generate Zone Data    ${warehouse_id}
    ${status_z}    ${zone_response}=    Create Zone    ${zone_data}
    Should Be Equal As Integers    ${status_z}    201
    Set Global Variable  ${TEST_ZONE_ID}    ${zone_response}[id]
    Log                 Created zone: ${zone_response}[name] with ID: ${zone_response}[id]

    # Step 5: Create Block
    ${block_data}=     Generate Block Data    ${zone_response}[id]
    ${status_b}    ${block_response}=    Create Block    ${block_data}
    Should Be Equal As Integers    ${status_b}    201
    Set Global Variable  ${TEST_BLOCK_ID}    ${block_response}[id]
    Log                 Created block: ${block_response}[name] with ID: ${block_response}[id]

    # Step 6: Create Multiple Racks Concurrently
    ${rack1_data}=     Generate Rack Data    ${warehouse_id}    ${zone_response}[id]    ${block_response}[id]    300
    ${status_r1}    ${rack1_response}=    Create Rack    ${rack1_data}
    Should Be Equal As Integers    ${status_r1}    201
    Append To List    ${TEST_RACK_IDS}    ${rack1_response}[id]
    Log               Created rack 1 with ID: ${rack1_response}[id]

    ${rack2_data}=     Generate Rack Data    ${warehouse_id}    ${zone_response}[id]    ${block_response}[id]    400
    ${status_r2}    ${rack2_response}=    Create Rack    ${rack2_data}
    Should Be Equal As Integers    ${status_r2}    201
    Append To List    ${TEST_RACK_IDS}    ${rack2_response}[id]
    Log               Created rack 2 with ID: ${rack2_response}[id]

    # Step 7: Attempt Rack Creation Exceeding Block Capacity
    ${rack3_data}=     Generate Rack Data    ${warehouse_id}    ${zone_response}[id]    ${block_response}[id]    600
    ${status_r3}    ${rack3_response}=    Create Rack    ${rack3_data}
    Should Be Equal As Integers    ${status_r3}    400
    Should Contain    ${rack3_response}[message]    capacity    ignore_case=True
    Log               Successfully prevented rack creation exceeding block capacity

    # Step 8: Validate Complete Structure
    ${warehouse_details}=    Get Warehouse Details    ${warehouse_id}
    Validate Warehouse Structure    ${warehouse_details}    ${zone_response}[id]    ${block_response}[id]    @{TEST_RACK_IDS}
    Log                 Successfully validated warehouse structure with blocks

    # Step 9: Clean Up
    FOR    ${rack_id}    IN    @{TEST_RACK_IDS}
        Delete Rack    ${rack_id}
    END
    Delete Block    ${TEST_BLOCK_ID}
    Delete Zone    ${TEST_ZONE_ID}
    Delete Warehouse    ${TEST_WAREHOUSE_ID}
    Log                 Successfully cleaned up all resources