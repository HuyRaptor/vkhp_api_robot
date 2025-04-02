*** Settings ***
Documentation     Advanced End-to-End Test Suite for Optimized Warehouse Management
...               Tests zone optimization, temperature control, and real-time auditing
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
${TEST_WAREHOUSE_ID}    ${EMPTY}
@{TEST_ZONE_IDS}        ${EMPTY}
@{TEST_BLOCK_IDS}       ${EMPTY}
@{TEST_RACK_IDS}        ${EMPTY}
${TEST_PRODUCT_ID}      ${EMPTY}
${MAX_WAREHOUSE_ACREAGE}    9000    # Max total acreage
${MAX_ZONE_CAPACITY}        4000    # Max capacity per zone
${MAX_BLOCK_CAPACITY}       2000    # Max capacity per block
${MAX_RACK_CAPACITY}        900     # Max capacity per rack
${MAX_BATCH_QUANTITY}       7000    # Max units per batch
${CURRENT_DATE}             2025-04-01T00:00:00Z    # Fixed date for testing
${TEMP_COLD}                2-8     # Cold storage range in Celsius
${TEMP_AMBIENT}             15-25   # Ambient storage range in Celsius

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
    [Documentation]     Generate warehouse data with optimization settings
    ${timestamp}=       Evaluate         int(time.time())    time
    ${optimization}=    Create Dictionary    strategy=balanced    frequency=daily
    ${warehouse_data}=  Create Dictionary
    ...                 name=Optimized Warehouse ${timestamp}
    ...                 address=700 Smart Ln
    ...                 acreage=${MAX_WAREHOUSE_ACREAGE - 1500}
    ...                 status=ENABLED
    ...                 optimizationSettings=${optimization}
    RETURN            ${warehouse_data}

Generate Zone Data
    [Documentation]     Generate zone data with temperature control
    [Arguments]         ${warehouse_id}    ${capacity}    ${temp_range}    ${type}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${zone_data}=      Create Dictionary
    ...                 capacity=${capacity}
    ...                 name=${type} Zone ${timestamp}
    ...                 warehouseId=${warehouse_id}
    ...                 temperatureRange=${temp_range}
    ...                 type=${type}
    RETURN            ${zone_data}

Generate Block Data
    [Documentation]     Generate block data with capacity
    [Arguments]         ${zone_id}    ${capacity}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${block_data}=     Create Dictionary
    ...                 capacity=${capacity}
    ...                 name=Optimized Block ${timestamp}
    ...                 zoneId=${zone_id}
    RETURN            ${block_data}

Generate Rack Data
    [Documentation]     Generate rack data with capacity and audit flag
    [Arguments]         ${warehouse_id}    ${zone_id}    ${block_id}    ${capacity}    ${audit_enabled}
    ${rack_data}=      Create Dictionary
    ...                 capacity=${capacity}
    ...                 warehouseId=${warehouse_id}
    ...                 zoneId=${zone_id}
    ...                 blockId=${block_id}
    ...                 shelfId=1
    ...                 auditEnabled=${audit_enabled}
    RETURN            ${rack_data}

Generate Product Data
    [Documentation]     Generate product data with batch and storage requirements
    ${timestamp}=       Evaluate         int(time.time())    time
    ${expiration}=      Get Current Date    ${CURRENT_DATE}    increment=10d    result_format=%Y-%m-%dT%H:%M:%SZ
    ${batch}=           Create Dictionary    batchNumber=BN-${timestamp}    quantity=${MAX_BATCH_QUANTITY}    expirationDate=${expiration}
    ${product_data}=   Create Dictionary
    ...                 name=Optimized Product ${timestamp}
    ...                 sku=SKU-${timestamp}
    ...                 batches=${[batch]}
    ...                 storageRequirements=${{"temperatureRange": "${TEMP_COLD}"}}
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
    [Documentation]     Create a new product with batch
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

Optimize Zones
    [Documentation]     Trigger zone optimization
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /warehouses/${warehouse_id}/optimize
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}

Allocate Product To Rack
    [Documentation]     Allocate product batch to a rack with temperature check
    [Arguments]         ${rack_id}    ${product_id}    ${batch_number}    ${quantity}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${allocation_data}= Create Dictionary
    ...                 rackId=${rack_id}
    ...                 productId=${product_id}
    ...                 batchNumber=${batch_number}
    ...                 quantity=${quantity}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /inventory/allocate
    ...                 json=${allocation_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Audit Inventory
    [Documentation]     Perform real-time inventory audit
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /warehouses/${warehouse_id}/audit
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}

Get Warehouse Inventory
    [Documentation]     Get warehouse inventory with batch details
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

Validate TemperatureMatch
    [Documentation]     Validate rack temperature matches product requirements
    [Arguments]         ${inventory}    ${product_id}    ${expected_temp_range}
    ${actual_temp}=    Evaluate    ${inventory}[zones][0][temperatureRange]
    Should Be Equal    ${actual_temp}    ${expected_temp_range}
    ...                Rack temperature ${actual_temp} does not match expected ${expected_temp_range}

Validate AuditConsistency
    [Documentation]     Validate audit matches inventory
    [Arguments]         ${audit}    ${inventory}    ${product_id}    ${batch_number}    ${expected_quantity}
    ${audit_quantity}=    Evaluate    ${audit}[products][${product_id}][batches][${batch_number}][quantity]
    ${inventory_quantity}=    Evaluate    ${inventory}[zones][0][blocks][0][racks][0][inventory][${product_id}][batches][${batch_number}][quantity]
    Should Be Equal As Integers    ${audit_quantity}    ${inventory_quantity}
    ...                            Audit quantity ${audit_quantity} does not match inventory ${inventory_quantity}
    Should Be Equal As Integers    ${audit_quantity}    ${expected_quantity}
    ...                            Audit quantity ${audit_quantity} does not match expected ${expected_quantity}

*** Test Cases ***
01 - Optimized Warehouse Management Flow
    [Documentation]     Test optimized warehouse management with complex validations
    [Tags]              e2e    warehouse    optimization    temperature    audit    validation

    # Setup
    Setup Admin Session
    Setup Manager Session
    Log                 Authentication completed successfully

    # Step 1: Positive - Create Warehouse with Optimization Settings
    ${warehouse_data}=    Generate Warehouse Data
    ${status_w}    ${warehouse_response}=    Create Warehouse    ${warehouse_data}
    Should Be Equal As Integers    ${status_w}    201
    Set Global Variable  ${TEST_WAREHOUSE_ID}    ${warehouse_response}[id]
    Log                 Created warehouse: ${warehouse_response}[id]

    # Step 2: Positive - Create Temperature-Controlled Zones
    ${zone1_data}=    Generate Zone Data    ${TEST_WAREHOUSE_ID}    ${MAX_ZONE_CAPACITY - 1000}    ${TEMP_COLD}    cold
    ${status_z1}    ${zone1_response}=    Create Zone    ${zone1_data}
    Should Be Equal As Integers    ${status_z1}    201
    Append To List    ${TEST_ZONE_IDS}    ${zone1_response}[id]
    Log                 Created cold zone: ${zone1_response}[id]

    ${zone2_data}=    Generate Zone Data    ${TEST_WAREHOUSE_ID}    ${MAX_ZONE_CAPACITY - 1500}    ${TEMP_AMBIENT}    ambient
    ${status_z2}    ${zone2_response}=    Create Zone    ${zone2_data}
    Should Be Equal As Integers    ${status_z2}    201
    Append To List    ${TEST_ZONE_IDS}    ${zone2_response}[id]
    Log                 Created ambient zone: ${zone2_response}[id]

    # Step 3: Positive - Create Block in Cold Zone
    ${block_data}=    Generate Block Data    ${zone1_response}[id]    ${MAX_BLOCK_CAPACITY - 400}
    ${status_b}    ${block_response}=    Create Block    ${block_data}
    Should Be Equal As Integers    ${status_b}    201
    Append To List    ${TEST_BLOCK_IDS}    ${block_response}[id]
    Log                 Created block: ${block_response}[id]

    # Step 4: Positive - Create Racks with Audit Enabled
    ${rack1_data}=    Generate Rack Data    ${TEST_WAREHOUSE_ID}    ${zone1_response}[id]    ${block_response}[id]    600    ${TRUE}
    ${status_r1}    ${rack1_response}=    Create Rack    ${rack1_data}
    Should Be Equal As Integers    ${status_r1}    201
    Append To List    ${TEST_RACK_IDS}    ${rack1_response}[id]
    Log                 Created audit-enabled rack: ${rack1_response}[id]

    ${rack2_data}=    Generate Rack Data    ${TEST_WAREHOUSE_ID}    ${zone1_response}[id]    ${block_response}[id]    700    ${FALSE}
    ${status_r2}    ${rack2_response}=    Create Rack    ${rack2_data}
    Should Be Equal As Integers    ${status_r2}    201
    Append To List    ${TEST_RACK_IDS}    ${rack2_response}[id]
    Log                 Created non-audited rack: ${rack2_response}[id]

    # Step 5: Edge Case - Create Rack at Maximum Capacity
    ${rack3_data}=    Generate Rack Data    ${TEST_WAREHOUSE_ID}    ${zone1_response}[id]    ${block_response}[id]    ${MAX_RACK_CAPACITY}    ${TRUE}
    ${status_r3}    ${rack3_response}=    Create Rack    ${rack3_data}
    Should Be Equal As Integers    ${status_r3}    201
    Append To List    ${TEST_RACK_IDS}    ${rack3_response}[id]
    Log                 Created rack at max capacity: ${rack3_response}[id]

    # Step 6: Negative - Attempt Rack Creation Exceeding Block Capacity
    ${excess_rack}=    Generate Rack Data    ${TEST_WAREHOUSE_ID}    ${zone1_response}[id]    ${block_response}[id]    800    ${TRUE}
    ${status_r4}    ${rack4_response}=    Create Rack    ${excess_rack}
    Should Be Equal As Integers    ${status_r4}    400
    Should Contain    ${rack4_response}[message]    capacity    ignore_case=True
    Log                 Successfully prevented rack creation exceeding block capacity

    # Step 7: Positive - Create Product with Temperature Requirements
    ${product_data}=    Generate Product Data
    ${product_id}    ${product_response}=    Create Product    ${product_data}
    Set Global Variable  ${TEST_PRODUCT_ID}    ${product_id}
    ${batch_number}=    Set Variable    ${product_response}[batches][0][batchNumber]
    Log                 Created product: ${product_id} with batch ${batch_number}

    # Step 8: Positive - Allocate Product to Cold Rack
    ${status_a1}    ${alloc1_response}=    Allocate Product To Rack    ${rack1_response}[id]    ${product_id}    ${batch_number}    5000
    Should Be Equal As Integers    ${status_a1}    201
    Log                 Allocated 5000 units of batch ${batch_number} to cold rack ${rack1_response}[id]

    # Step 9: Negative - Attempt Allocation to Ambient Rack
    ${status_a2}    ${alloc2_response}=    Allocate Product To Rack    ${rack2_response}[id]    ${product_id}    ${batch_number}    1000
    Should Be Equal As Integers    ${status_a2}    400
    Should Contain    ${alloc2_response}[message]    temperature    ignore_case=True
    Log                 Successfully prevented allocation to incompatible temperature rack

    # Step 10: Edge Case - Allocate Remaining Quantity
    ${status_a3}    ${alloc3_response}=    Allocate Product To Rack    ${rack3_response}[id]    ${product_id}    ${batch_number}    ${MAX_BATCH_QUANTITY - 5000}
    Should Be Equal As Integers    ${status_a3}    201
    Log                 Allocated remaining ${MAX_BATCH_QUANTITY - 5000} units to rack ${rack3_response}[id]

    # Step 11: Positive - Optimize Zones
    ${optimize_response}=    Optimize Zones    ${TEST_WAREHOUSE_ID}
    Log                 Triggered zone optimization for warehouse ${TEST_WAREHOUSE_ID}

    # Step 12: Positive - Perform Inventory Audit
    ${audit_response}=    Audit Inventory    ${TEST_WAREHOUSE_ID}
    Log                 Performed real-time inventory audit

    # Step 13: Validate Temperature and Audit
    ${inventory}=    Get Warehouse Inventory    ${TEST_WAREHOUSE_ID}
    Validate TemperatureMatch    ${inventory}    ${product_id}    ${TEMP_COLD}
    Validate AuditConsistency    ${audit_response}    ${inventory}    ${product_id}    ${batch_number}    ${MAX_BATCH_QUANTITY}
    Log                 Successfully validated temperature and audit consistency

    # Step 14: Clean Up
    FOR    ${rack_id}    IN    @{TEST_RACK_IDS}
        Delete Rack    ${rack_id}
    END
    FOR    ${block_id}    IN    @{TEST_BLOCK_IDS}
        Delete Block    ${block_id}
    END
    FOR    ${zone_id}    IN    @{TEST_ZONE_IDS}
        Delete Zone    ${zone_id}
    END
    Delete Warehouse    ${TEST_WAREHOUSE_ID}
    Delete Product    ${TEST_PRODUCT_ID}
    Log                 Successfully cleaned up all resources