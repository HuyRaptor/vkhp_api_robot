*** Settings ***
Documentation     Advanced End-to-End Test Suite for Synchronized Warehouse Management
...               Tests multi-warehouse sync, time-based operations, and expiration tracking
...               Includes positive, negative, and edge case validations
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime

*** Variables ***
${BASE_URL}             https://api.vkho.net
${ADMIN_USERNAME}       huynh22
${ADMIN_PASSWORD}       Snowfox1991
${MANAGER_USERNAME}     huynh22.manager
${MANAGER_PASSWORD}     Snowfox1991
${RESULTS_DIR}          ${CURDIR}${/}results
@{TEST_WAREHOUSE_IDS}   ${EMPTY}
${TEST_ZONE_ID}         ${EMPTY}
${TEST_BLOCK_ID}        ${EMPTY}
@{TEST_RACK_IDS}        ${EMPTY}
${TEST_PRODUCT_ID}      ${EMPTY}
${MAX_WAREHOUSE_ACREAGE}    6000    # Max total acreage
${MAX_ZONE_CAPACITY}        2500    # Max capacity per zone
${MAX_BLOCK_CAPACITY}       1200    # Max capacity per block
${MAX_RACK_CAPACITY}        600     # Max capacity per rack
${MAX_PRODUCT_QUANTITY}     3000    # Total product units across warehouses
${CURRENT_DATE}         2025-04-01T00:00:00Z    # Fixed date for testing
${MAINTENANCE_DURATION}  2h    # Maintenance window duration

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
    [Documentation]     Generate warehouse data with maintenance schedule
    [Arguments]         ${suffix}    ${acreage}    ${status}=ENABLED
    ${timestamp}=       Evaluate         int(time.time())    time
    ${start_time}=      Get Current Date    ${CURRENT_DATE}    result_format=%Y-%m-%dT%H:%M:%SZ
    ${end_time}=        Get Current Date    ${CURRENT_DATE}    increment=${MAINTENANCE_DURATION}    result_format=%Y-%m-%dT%H:%M:%SZ
    ${maintenance}=     Create Dictionary    startTime=${start_time}    endTime=${end_time}
    ${warehouse_data}=  Create Dictionary
    ...                 name=Sync Warehouse ${suffix} ${timestamp}
    ...                 address=400 ${suffix} Lane
    ...                 acreage=${acreage}
    ...                 status=${status}
    ...                 maintenanceSchedule=${maintenance}
    RETURN            ${warehouse_data}

Generate Zone Data
    [Documentation]     Generate zone data with capacity
    [Arguments]         ${warehouse_id}    ${capacity}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${zone_data}=      Create Dictionary
    ...                 capacity=${capacity}
    ...                 name=Sync Zone ${timestamp}
    ...                 warehouseId=${warehouse_id}
    RETURN            ${zone_data}

Generate Block Data
    [Documentation]     Generate block data with capacity
    [Arguments]         ${zone_id}    ${capacity}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${block_data}=     Create Dictionary
    ...                 capacity=${capacity}
    ...                 name=Sync Block ${timestamp}
    ...                 zoneId=${zone_id}
    RETURN            ${block_data}

Generate Rack Data
    [Documentation]     Generate rack data with capacity
    [Arguments]         ${warehouse_id}    ${zone_id}    ${block_id}    ${capacity}
    ${rack_data}=      Create Dictionary
    ...                 capacity=${capacity}
    ...                 warehouseId=${warehouse_id}
    ...                 zoneId=${zone_id}
    ...                 blockId=${block_id}
    ...                 shelfId=1
    RETURN            ${rack_data}

Generate Product Data
    [Documentation]     Generate product data with expiration
    ${timestamp}=       Evaluate         int(time.time())    time
    ${expiration}=      Get Current Date    ${CURRENT_DATE}    increment=30d    result_format=%Y-%m-%dT%H:%M:%SZ
    ${product_data}=   Create Dictionary
    ...                 name=Sync Product ${timestamp}
    ...                 sku=SKU-${timestamp}
    ...                 totalQuantity=${MAX_PRODUCT_QUANTITY}
    ...                 expirationDate=${expiration}
    RETURN            ${product_data}

Create Warehouse
    [Documentation]     Create a new warehouse
    [Arguments]         ${warehouse_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /warehouses/create
    ...                 json=${warehouse_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

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
    [Documentation]     Create a new rack
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

Create Product
    [Documentation]     Create a new product with expiration
    [Arguments]         ${product_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}[id]    ${json}

Allocate Product To Rack
    [Documentation]     Allocate product to a rack with expiration check
    [Arguments]         ${rack_id}    ${product_id}    ${quantity}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${allocation_data}= Create Dictionary
    ...                 rackId=${rack_id}
    ...                 productId=${product_id}
    ...                 quantity=${quantity}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /inventory/allocate
    ...                 Expect maintenanceSchedule in headers    ${headers}
    ...                 json=${allocation_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Get Warehouse Inventory
    [Documentation]     Get warehouse inventory with expiration details
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /warehouses/${warehouse_id}/inventory
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

Delete Product
    [Documentation]     Delete a product
    [Arguments]         ${product_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /products/delete/${product_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    RETURN            ${TRUE}

Validate MultiWarehouseInventory
    [Documentation]     Validate total product quantity across warehouses
    [Arguments]         ${inventory1}    ${inventory2}    ${product_id}    ${expected_total}
    ${total}=          Evaluate    ${inventory1}[products][${product_id}][quantity] + ${inventory2}[products][${product_id}][quantity]
    Should Be Equal As Integers    ${total}    ${expected_total}
    ...                            Total allocated quantity ${total} does not match expected ${expected_total}

Validate Expiration
    [Documentation]     Validate product expiration date
    [Arguments]         ${inventory}    ${product_id}    ${expected_expiration}
    ${actual_expiration}=    Set Variable    ${inventory}[products][${product_id}][expirationDate]
    Should Be Equal    ${actual_expiration}    ${expected_expiration}
    ...                Expiration date ${actual_expiration} does not match expected ${expected_expiration}

*** Test Cases ***
01 - Synchronized Warehouse Management Flow
    [Documentation]     Test synchronized warehouse management with complex validations
    [Tags]              e2e    warehouse    multi-warehouse    inventory    time    validation

    # Setup
    Setup Admin Session
    Setup Manager Session
    Log                 Authentication completed successfully

    # Step 1: Positive - Create Primary Warehouse with Maintenance Schedule
    ${warehouse1_data}=    Generate Warehouse Data    Primary    ${MAX_WAREHOUSE_ACREAGE - 1000}
    ${status_w1}    ${warehouse1_response}=    Create Warehouse    ${warehouse1_data}
    Should Be Equal As Integers    ${status_w1}    201
    Append To List    ${TEST_WAREHOUSE_IDS}    ${warehouse1_response}[id]
    Log                 Created primary warehouse: ${warehouse1_response}[name] with ID: ${warehouse1_response}[id]

    # Step 2: Positive - Create Secondary Warehouse
    ${warehouse2_data}=    Generate Warehouse Data    Secondary    ${MAX_WAREHOUSE_ACREAGE - 2000}
    ${status_w2}    ${warehouse2_response}=    Create Warehouse    ${warehouse2_data}
    Should Be Equal As Integers    ${status_w2}    201
    Append To List    ${TEST_WAREHOUSE_IDS}    ${warehouse2_response}[id]
    Log                 Created secondary warehouse: ${warehouse2_response}[name] with ID: ${warehouse2_response}[id]

    # Step 3: Negative - Attempt Warehouse Creation During Maintenance Overlap
    ${overlap_warehouse}=    Generate Warehouse Data    Overlap    ${MAX_WAREHOUSE_ACREAGE}
    ${status_w3}    ${warehouse_response3}=    Create Warehouse    ${overlap_warehouse}
    Should Be Equal As Integers    ${status_w3}    400
    Should Contain    ${warehouse_response3}[message]    maintenance    ignore_case=True
    Log                 Successfully prevented warehouse creation during maintenance overlap

    # Step 4: Positive - Create Zone in Primary Warehouse
    ${zone_data}=    Generate Zone Data    ${warehouse1_response}[id]    ${MAX_ZONE_CAPACITY - 500}
    ${status_z}    ${zone_response}=    Create Zone    ${zone_data}
    Should Be Equal As Integers    ${status_z}    201
    Set Global Variable  ${TEST_ZONE_ID}    ${zone_response}[id]
    Log                 Created zone: ${zone_response}[name] with ID: ${zone_response}[id]

    # Step 5: Edge Case - Create Block at Maximum Capacity
    ${block_data}=    Generate Block Data    ${TEST_ZONE_ID}    ${MAX_BLOCK_CAPACITY}
    ${status_b}    ${block_response}=    Create Block    ${block_data}
    Should Be Equal As Integers    ${status_b}    201
    Set Global Variable  ${TEST_BLOCK_ID}    ${block_response}[id]
    Log                 Created block at max capacity: ${block_response}[id]

    # Step 6: Positive - Create Racks in Block
    ${rack1_data}=    Generate Rack Data    ${warehouse1_response}[id]    ${TEST_ZONE_ID}    ${TEST_BLOCK_ID}    300
    ${status_r1}    ${rack1_response}=    Create Rack    ${rack1_data}
    Should Be Equal As Integers    ${status_r1}    201
    Append To List    ${TEST_RACK_IDS}    ${rack1_response}[id]
    Log                 Created rack 1: ${rack1_response}[id]

    ${rack2_data}=    Generate Rack Data    ${warehouse1_response}[id]    ${TEST_ZONE_ID}    ${TEST_BLOCK_ID}    400
    ${status_r2}    ${rack2_response}=    Create Rack    ${rack2_data}
    Should Be Equal As Integers    ${status_r2}    201
    Append To List    ${TEST_RACK_IDS}    ${rack2_response}[id]
    Log                 Created rack 2: ${rack2_response}[id]

    # Step 7: Negative - Attempt Rack Creation During Maintenance
    ${rack3_data}=    Generate Rack Data    ${warehouse1_response}[id]    ${TEST_ZONE_ID}    ${TEST_BLOCK_ID}    200
    ${status_r3}    ${rack3_response}=    Create Rack    ${rack3_data}
    Should Be Equal As Integers    ${status_r3}    400
    Should Contain    ${rack3_response}[message]    maintenance    ignore_case=True
    Log                 Successfully prevented rack creation during maintenance

    # Step 8: Positive - Create Product with Expiration
    ${product_data}=    Generate Product Data
    ${product_id}    ${product_response}=    Create Product    ${product_data}
    Set Global Variable  ${TEST_PRODUCT_ID}    ${product_id}
    Log                 Created product: ${product_response}[name] with ID: ${product_id}

    # Step 9: Positive - Allocate Product to Primary Warehouse Rack
    ${status_a1}    ${alloc1_response}=    Allocate Product To Rack    ${rack1_response}[id]    ${product_id}    1500
    Should Be Equal As Integers    ${status_a1}    201
    Log                 Allocated 1500 units to rack ${rack1_response}[id]

    # Step 10: Edge Case - Allocate Remaining Quantity to Secondary Warehouse
    ${zone2_data}=    Generate Zone Data    ${warehouse2_response}[id]    ${MAX_ZONE_CAPACITY - 500}
    ${status_z2}    ${zone2_response}=    Create Zone    ${zone2_data}
    ${block2_data}=   Generate Block Data    ${zone2_response}[id]    ${MAX_BLOCK_CAPACITY - 300}
    ${status_b2}    ${block2_response}=    Create Block    ${block2_data}
    ${rack3_data}=    Generate Rack Data    ${warehouse2_response}[id]    ${zone2_response}[id]    ${block2_response}[id]    ${MAX_RACK_CAPACITY}
    ${status_r3}    ${rack3_response}=    Create Rack    ${rack3_data}

    ${status_a2}    ${alloc2_response}=    Allocate Product To Rack    ${rack3_response}[id]    ${product_id}    ${MAX_PRODUCT_QUANTITY - 1500}
    Should Be Equal As Integers    ${status_a2}    201
    Append To List    ${TEST_RACK_IDS}    ${rack3_response}[id]
    Log                 Allocated remaining ${MAX_PRODUCT_QUANTITY - 1500} units to rack ${rack3_response}[id]

    # Step 11: Negative - Attempt Allocation Exceeding Total Quantity
    ${status_a3}    ${alloc3_response}=    Allocate Product To Rack    ${rack2_response}[id]    ${product_id}    100
    Should Be Equal As Integers    ${status_a3}    400
    Should Contain    ${alloc3_response}[message]    quantity    ignore_case=True
    Log                 Successfully prevented allocation exceeding total quantity

    # Step 12: Validate Inventory and Expiration Across Warehouses
    ${inventory1}=    Get Warehouse Inventory    ${warehouse1_response}[id]
    ${inventory2}=    Get Warehouse Inventory    ${warehouse2_response}[id]
    Validate MultiWarehouseInventory    ${inventory1}    ${inventory2}    ${product_id}    ${MAX_PRODUCT_QUANTITY}
    Validate Expiration    ${inventory1}    ${product_id}    ${product_response}[expirationDate]
    Log                 Successfully validated inventory and expiration across warehouses

    # Step 13: Clean Up
    FOR    ${rack_id}    IN    @{TEST_RACK_IDS}
        Delete Rack    ${rack_id}
    END
    Delete Block    ${TEST_BLOCK_ID}
    Delete Block    ${block2_response}[id]
    Delete Zone    ${TEST_ZONE_ID}
    Delete Zone    ${zone2_response}[id]
    FOR    ${warehouse_id}    IN    @{TEST_WAREHOUSE_IDS}
        Delete Warehouse    ${warehouse_id}
    END
    Delete Product    ${TEST_PRODUCT_ID}
    Log                 Successfully cleaned up all resources