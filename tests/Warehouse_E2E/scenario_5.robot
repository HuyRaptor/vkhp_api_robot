*** Settings ***
Documentation     Complex End-to-End Test Suite for Warehouse Management
...               Tests warehouse setup with multiple zones and racks
...               Includes capacity constraints and business rule validation
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Resource          ../../Variables/variables.robot

*** Keywords ***
Setup Admin Session
    [Documentation]     Create API session and authenticate with admin credentials
    Create Session      vkho_admin        ${BASE_URL}      verify=True    disable_warnings=True
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${ADMIN_USERNAME}    password=${ADMIN_PASSWORD}
    ${response}=        POST On Session
    ...                 vkho_admin
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
    Create Session      vkho_manager      ${BASE_URL}      verify=True    disable_warnings=True
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${MANAGER_USERNAME}    password=${MANAGER_PASSWORD}
    ${response}=        POST On Session
    ...                 vkho_manager
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    access_token
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${MANAGER_TOKEN}    ${token}

Generate Warehouse Data
    [Documentation]     Generate data for warehouse creation with capacity limit
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_data}=  Create Dictionary
    ...                 name=Complex Warehouse ${timestamp}
    ...                 address=456 Industrial Park
    ...                 acreage=${MAX_WAREHOUSE_CAPACITY}
    RETURN              ${warehouse_data}

Generate Zone Data
    [Documentation]     Generate zone data with specific capacity
    [Arguments]         ${warehouse_id}    ${capacity}    ${zone_type}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${zone_data}=       Create Dictionary
    ...                 capcity=${capacity}
    ...                 name=${zone_type} Zone ${timestamp}
    ...                 warehouseId=${warehouse_id}
    RETURN              ${zone_data}

Generate Rack Data
    [Documentation]     Generate rack data with specific capacity
    [Arguments]         ${warehouse_id}    ${capacity}
    ${rack_data}=       Create Dictionary
    ...                 capacity=${capacity}
    ...                 warehouseId=${warehouse_id}
    ...                 shelfId=1
    RETURN              ${rack_data}

Create Warehouse
    [Documentation]     Create a new warehouse
    [Arguments]         ${warehouse_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    ${response}=        POST On Session
    ...                 vkho_admin
    ...                 /warehouses/create
    ...                 json=${warehouse_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN              ${json}[id]    ${json}

Create Zone
    [Documentation]     Create a new zone with validation
    [Arguments]         ${zone_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session
    ...                 vkho_manager
    ...                 /zones/create
    ...                 json=${zone_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN              ${response.status_code}    ${json}

Create Rack
    [Documentation]     Create a new rack with validation
    [Arguments]         ${rack_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session
    ...                 vkho_manager
    ...                 /racks/create
    ...                 json=${rack_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN              ${response.status_code}    ${json}

Get Warehouse By ID
    [Documentation]     Get warehouse details
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    ${response}=        GET On Session
    ...                 vkho_admin
    ...                 /warehouses/get-one/${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN              ${json}

Get Zone By ID
    [Documentation]     Get zone details
    [Arguments]         ${zone_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        GET On Session
    ...                 vkho_manager
    ...                 /zones/get-one/${zone_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN              ${json}

Get Rack By ID
    [Documentation]     Get rack details
    [Arguments]         ${rack_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        GET On Session
    ...                 vkho_manager
    ...                 /racks/get-one/${rack_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN              ${json}

Get All Zones For Warehouse
    [Documentation]     Get all zones for a specific warehouse
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${params}=          Create Dictionary    warehouseId=${warehouse_id}
    ${response}=        GET On Session
    ...                 vkho_manager
    ...                 /zones/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN              ${json}

Get All Racks For Warehouse
    [Documentation]     Get all racks for a specific warehouse
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${params}=          Create Dictionary    warehouseId=${warehouse_id}
    ${response}=        GET On Session
    ...                 vkho_manager
    ...                 /racks/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN              ${json}

Update Zone
    [Documentation]     Update zone properties
    [Arguments]         ${zone_id}    ${update_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        PUT On Session
    ...                 vkho_manager
    ...                 /zones/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN              ${response.status_code}    ${json}

Update Zone Capacity
    [Documentation]     Update zone capacity
    [Arguments]         ${zone_id}    ${new_capacity}
    # First get the current zone details
    ${zone}=            Get Zone By ID    ${zone_id}
    
    # Build the update data with all required fields
    ${update_data}=     Create Dictionary
    ...                 id=${zone_id}
    ...                 capcity=${new_capacity}
    ...                 name=${zone}[name]
    ...                 warehouseId=${zone}[warehouseId]
    ...                 status=${zone}[status]
    
    # Update the zone
    ${status}    ${updated_zone}=    Update Zone    ${zone_id}    ${update_data}
    Should Be Equal As Integers    ${status}    200
    
    RETURN              ${updated_zone}

Delete Rack
    [Documentation]     Delete a rack
    [Arguments]         ${rack_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho_manager
    ...                 /racks/delete/${rack_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    RETURN              ${TRUE}

Delete Zone
    [Documentation]     Delete a zone
    [Arguments]         ${zone_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho_manager
    ...                 /zones/delete/${zone_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    RETURN              ${TRUE}

Delete Warehouse
    [Documentation]     Delete a warehouse
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho_admin
    ...                 /warehouses/delete/${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    RETURN              ${TRUE}

Validate Capacity Constraints
    [Documentation]     Validate total capacity doesn't exceed warehouse limits
    [Arguments]         ${warehouse_acreage}    ${total_zone_capacity}    ${total_rack_capacity}
    ${warehouse_capacity}=    Convert To Number    ${warehouse_acreage}
    Should Be True    ${total_zone_capacity} <= ${warehouse_capacity}
    ...               Total zone capacity ${total_zone_capacity} exceeds warehouse capacity ${warehouse_capacity}
    Should Be True    ${total_rack_capacity} <= ${total_zone_capacity}
    ...               Total rack capacity ${total_rack_capacity} exceeds total zone capacity ${total_zone_capacity}

Calculate Total Zone Capacity
    [Documentation]     Calculate total capacity of zones
    [Arguments]         ${zones_data}
    ${total}=          Set Variable    0
    
    # Check if 'data' exists (common response format)
    ${has_data}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${zones_data}    data
    ${has_items}=      Run Keyword And Return Status    Dictionary Should Contain Key    ${zones_data}    items
    ${has_records}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${zones_data}    records
    
    # Extract the correct list based on response format
    @{zones_list}=     Create List
    IF    ${has_data}
        @{zones_list}=    Set Variable    ${zones_data}[data]
    ELSE IF    ${has_items}
        @{zones_list}=    Set Variable    ${zones_data}[items]
    ELSE IF    ${has_records}
        @{zones_list}=    Set Variable    ${zones_data}[records]
    ELSE
        @{zones_list}=    Set Variable    ${zones_data}
    END
    
    # Sum up capacities
    FOR    ${zone}    IN    @{zones_list}
        ${zone_capacity}=    Get From Dictionary    ${zone}    capcity    default=0
        ${zone_capacity_num}=    Convert To Number    ${zone_capacity}
        ${total}=       Evaluate    ${total} + ${zone_capacity_num}
    END
    RETURN              ${total}

Calculate Total Rack Capacity
    [Documentation]     Calculate total capacity of racks
    [Arguments]         ${racks_data}
    ${total}=          Set Variable    0
    
    # Check if 'data' exists (common response format)
    ${has_data}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${racks_data}    data
    ${has_items}=      Run Keyword And Return Status    Dictionary Should Contain Key    ${racks_data}    items
    ${has_records}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${racks_data}    records
    
    # Extract the correct list based on response format
    @{racks_list}=     Create List
    IF    ${has_data}
        @{racks_list}=    Set Variable    ${racks_data}[data]
    ELSE IF    ${has_items}
        @{racks_list}=    Set Variable    ${racks_data}[items]
    ELSE IF    ${has_records}
        @{racks_list}=    Set Variable    ${racks_data}[records]
    ELSE
        @{racks_list}=    Set Variable    ${racks_data}
    END
    
    # Sum up capacities
    FOR    ${rack}    IN    @{racks_list}
        ${rack_capacity}=    Get From Dictionary    ${rack}    capacity    default=0
        ${rack_capacity_num}=    Convert To Number    ${rack_capacity}
        ${total}=       Evaluate    ${total} + ${rack_capacity_num}
    END
    RETURN              ${total}

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
    Set List Value     ${TEST_ZONE_IDS}    0    ${zone1_response}[id]
    Log               Created primary zone: ${zone1_response}[name] with capacity: ${zone1_data}[capcity]

    ${zone2_data}=     Generate Zone Data    ${warehouse_id}    1200    Secondary
    ${status2}    ${zone2_response}=    Create Zone    ${zone2_data}
    Should Be Equal As Integers    ${status2}    201
    Append To List    ${TEST_ZONE_IDS}    ${zone2_response}[id]
    Log               Created secondary zone: ${zone2_response}[name] with capacity: ${zone2_data}[capcity]

    # Step 3: Attempt to Create Zone Exceeding Warehouse Capacity
    # This is a business rule validation that we're testing
    ${zone3_data}=     Generate Zone Data    ${warehouse_id}    3000    Overflow
    ${status3}    ${zone3_response}=    Create Zone    ${zone3_data}
    Run Keyword If    ${status3} == 201    Fail    Zone creation with excessive capacity succeeded but should have failed
    Log               Attempted to create zone exceeding capacity: Status code ${status3}

    # Step 4: Create Racks in Warehouse
    ${rack1_data}=     Generate Rack Data    ${warehouse_id}    800
    ${status_r1}    ${rack1_response}=    Create Rack    ${rack1_data}
    Should Be Equal As Integers    ${status_r1}    201
    Set List Value     ${TEST_RACK_IDS}    0    ${rack1_response}[id]
    Log               Created rack 1 with ID: ${rack1_response}[id] and capacity: ${rack1_data}[capacity]

    ${rack2_data}=     Generate Rack Data    ${warehouse_id}    600
    ${status_r2}    ${rack2_response}=    Create Rack    ${rack2_data}
    Should Be Equal As Integers    ${status_r2}    201
    Append To List    ${TEST_RACK_IDS}    ${rack2_response}[id]
    Log               Created rack 2 with ID: ${rack2_response}[id] and capacity: ${rack2_data}[capacity]

    # Step 5: Attempt to Create Rack Exceeding Total Capacity
    # This is a business rule validation that we're testing
    ${excessive_rack_data}=     Generate Rack Data    ${warehouse_id}    3000
    ${status_r3}    ${rack3_response}=    Create Rack    ${excessive_rack_data}
    Run Keyword If    ${status_r3} == 201    Fail    Rack creation with excessive capacity succeeded but should have failed
    Log               Attempted to create rack exceeding capacity: Status code ${status_r3}

    # Step 6: Update Zone Capacity and Validate
    ${zone1}=          Get Zone By ID    ${zone1_response}[id]
    ${updated_zone1}=  Update Zone Capacity    ${zone1_response}[id]    1800
    Should Be Equal As Integers    ${updated_zone1}[capcity]    1800
    Log                Updated primary zone capacity from ${zone1}[capcity] to ${updated_zone1}[capcity]

    # Step 7: Get All Zones and Racks to Verify Structure and Capacity
    ${warehouse}=       Get Warehouse By ID    ${warehouse_id}
    ${all_zones}=       Get All Zones For Warehouse    ${warehouse_id}
    ${all_racks}=       Get All Racks For Warehouse    ${warehouse_id}
    
    ${zone_capacity}=   Calculate Total Zone Capacity    ${all_zones}
    ${rack_capacity}=   Calculate Total Rack Capacity    ${all_racks}
    
    # Validate capacity constraints
    Validate Capacity Constraints    ${warehouse}[acreage]    ${zone_capacity}    ${rack_capacity}
    Log                Successfully validated capacity constraints:
    Log                - Warehouse capacity: ${warehouse}[acreage]
    Log                - Total zone capacity: ${zone_capacity}
    Log                - Total rack capacity: ${rack_capacity}

    # Step 8: Clean Up
    FOR    ${rack_id}    IN    @{TEST_RACK_IDS}
        ${result}=       Delete Rack    ${rack_id}
        Should Be True   ${result}    Failed to delete rack ${rack_id}
    END
    
    FOR    ${zone_id}    IN    @{TEST_ZONE_IDS}
        ${result}=       Delete Zone    ${zone_id}
        Should Be True   ${result}    Failed to delete zone ${zone_id}
    END
    
    ${result}=         Delete Warehouse    ${warehouse_id}
    Should Be True     ${result}    Failed to delete warehouse ${warehouse_id}
    
    Log                Successfully cleaned up all resources