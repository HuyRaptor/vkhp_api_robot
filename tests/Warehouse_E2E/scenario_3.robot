*** Settings ***
Documentation     End-to-End Test Suite for Warehouse Management Workflow
...               Tests complete flow from warehouse creation to rack management
...               Validates relationships between warehouse, zones, and racks
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
${TEST_ZONE_ID}         ${EMPTY}
${TEST_RACK_ID}         ${EMPTY}

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
    [Documentation]     Generate data for warehouse creation
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_data}=  Create Dictionary
    ...                 name=E2E Warehouse ${timestamp}
    ...                 address=789 Logistics Ave
    ...                 acreage=2000
    RETURN            ${warehouse_data}

Generate Zone Data
    [Documentation]     Generate data for zone creation
    [Arguments]         ${warehouse_id}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${zone_data}=      Create Dictionary
    ...                 capacity=1000
    ...                 name=Storage Zone ${timestamp}
    ...                 warehouseId=${warehouse_id}
    RETURN            ${zone_data}

Generate Rack Data
    [Documentation]     Generate data for rack creation
    [Arguments]         ${warehouse_id}    ${zone_id}
    ${rack_data}=      Create Dictionary
    ...                 capacity=200
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
    [Documentation]     Create a new zone
    [Arguments]         ${zone_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /zones/create
    ...                 json=${zone_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}[id]    ${json}

Create Rack
    [Documentation]     Create a new rack
    [Arguments]         ${rack_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /racks/create
    ...                 json=${rack_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}[id]    ${json}

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

Update Rack Capacity
    [Documentation]     Update rack capacity
    [Arguments]         ${rack_id}    ${new_capacity}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${update_data}=    Create Dictionary
    ...                 id=${rack_id}
    ...                 capacity=${new_capacity}
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /racks/update
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

Verify Structure Relationships
    [Documentation]     Verify relationships between warehouse, zone, and rack
    [Arguments]         ${warehouse}    ${zone_id}    ${rack_id}
    Should Be Equal As Strings    ${warehouse}[id]    ${warehouse}[zones][0][warehouseId]
    Should Be Equal As Strings    ${zone_id}         ${warehouse}[zones][0][id]
    Should Contain                ${warehouse}[zones][0][racks]    ${rack_id}

*** Test Cases ***
01 - Warehouse Management End-to-End Flow
    [Documentation]     Test complete warehouse management workflow
    [Tags]              e2e    warehouse    zone    rack

    # Setup
    Setup Admin Session
    Setup Manager Session
    Log                 Authentication completed successfully

    # Step 1: Create Warehouse
    ${warehouse_data}=  Generate Warehouse Data
    ${warehouse_id}    ${warehouse_response}=    Create Warehouse    ${warehouse_data}
    Set Global Variable  ${TEST_WAREHOUSE_ID}    ${warehouse_id}
    Should Be Equal     ${warehouse_response}[name]    ${warehouse_data}[name]
    Log                 Created warehouse: ${warehouse_response}[name] with ID: ${warehouse_id}

    # Step 2: Create Zone in Warehouse
    ${zone_data}=      Generate Zone Data    ${warehouse_id}
    ${zone_id}    ${zone_response}=    Create Zone    ${zone_data}
    Set Global Variable  ${TEST_ZONE_ID}    ${zone_id}
    Should Be Equal     ${zone_response}[warehouseId]    ${warehouse_id}
    Log                 Created zone: ${zone_response}[name] with ID: ${zone_id}

    # Step 3: Create Rack in Zone
    ${rack_data}=      Generate Rack Data    ${warehouse_id}    ${zone_id}
    ${rack_id}    ${rack_response}=    Create Rack    ${rack_data}
    Set Global Variable  ${TEST_RACK_ID}    ${rack_id}
    Should Be Equal     ${rack_response}[warehouseId]    ${warehouse_id}
    Should Be Equal     ${rack_response}[zoneId]        ${zone_id}
    Log                 Created rack with ID: ${rack_id}

    # Step 4: Verify Structure
    ${warehouse_details}=    Get Warehouse Details    ${warehouse_id}
    Verify Structure Relationships    ${warehouse_details}    ${zone_id}    ${rack_id}
    Log                 Successfully verified warehouse structure relationships

    # Step 5: Update Rack Capacity
    ${updated_rack}=    Update Rack Capacity    ${rack_id}    300
    Should Be Equal As Integers    ${updated_rack}[capacity]    300
    Log                 Updated rack capacity to 300

    # Step 6: Clean Up
    ${rack_deleted}=    Delete Rack    ${rack_id}
    ${zone_deleted}=    Delete Zone    ${zone_id}
    ${warehouse_deleted}=    Delete Warehouse    ${warehouse_id}
    
    Should Be True      ${rack_deleted}
    Should Be True      ${zone_deleted}
    Should Be True      ${warehouse_deleted}
    Log                 Successfully cleaned up all created resources