*** Settings ***
Documentation     Advanced End-to-End Test Suite for Multi-Tenant Warehouse Management
...               Tests tenant isolation, batch tracking, and warehouse transfers
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
${TENANT1_USERNAME}     tenant1.manager
${TENANT1_PASSWORD}     Tenant1Pass
${TENANT2_USERNAME}     tenant2.manager
${TENANT2_PASSWORD}     Tenant2Pass
${RESULTS_DIR}          ${CURDIR}${/}results
@{TEST_WAREHOUSE_IDS}   ${EMPTY}
@{TEST_ZONE_IDS}        ${EMPTY}
@{TEST_BLOCK_IDS}       ${EMPTY}
@{TEST_RACK_IDS}        ${EMPTY}
${TEST_PRODUCT_ID}      ${EMPTY}
${MAX_WAREHOUSE_ACREAGE}    7000    # Max total acreage
${MAX_ZONE_CAPACITY}        3000    # Max capacity per zone
${MAX_BLOCK_CAPACITY}       1500    # Max capacity per block
${MAX_RACK_CAPACITY}        700     # Max capacity per rack
${MAX_BATCH_QUANTITY}       5000    # Max units per batch
${TENANT_ID_1}              tenant1
${TENANT_ID_2}              tenant2

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

Setup Tenant Session
    [Documentation]     Create API session and authenticate with tenant credentials
    [Arguments]         ${username}    ${password}    ${tenant_id}
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    ${headers}=         Create Dictionary    Content-Type=application/json    X-Tenant-Id=${tenant_id}
    ${body}=            Create Dictionary    username=${username}    password=${password}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${token}=           Set Variable     Bearer ${json}[access_token]
    RETURN            ${token}

Generate Warehouse Data
    [Documentation]     Generate warehouse data for a tenant
    [Arguments]         ${tenant_id}    ${acreage}    ${suffix}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_data}=  Create Dictionary
    ...                 name=MT Warehouse ${suffix} ${timestamp}
    ...                 address=500 ${suffix} Rd
    ...                 acreage=${acreage}
    ...                 status=ENABLED
    ...                 tenantId=${tenant_id}
    RETURN            ${warehouse_data}

Generate Zone Data
    [Documentation]     Generate zone data with capacity
    [Arguments]         ${warehouse_id}    ${capacity}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${zone_data}=      Create Dictionary
    ...                 capacity=${capacity}
    ...                 name=MT Zone ${timestamp}
    ...                 warehouseId=${warehouse_id}
    RETURN            ${zone_data}

Generate Block Data
    [Documentation]     Generate block data with capacity
    [Arguments]         ${zone_id}    ${capacity}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${block_data}=     Create Dictionary
    ...                 capacity=${capacity}
    ...                 name=MT Block ${timestamp}
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
    [Documentation]     Generate product data with batch
    [Arguments]         ${tenant_id}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${batch}=           Create Dictionary    batchNumber=BN-${timestamp}    quantity=${MAX_BATCH_QUANTITY}
    ${product_data}=   Create Dictionary
    ...                 name=MT Product ${timestamp}
    ...                 sku=SKU-${timestamp}
    ...                 batches=${[batch]}
    ...                 tenantId=${tenant_id}
    RETURN            ${product_data}

Create Warehouse
    [Documentation]     Create a new warehouse
    [Arguments]         ${warehouse_data}    ${token}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${token}    X-Tenant-Id=${warehouse_data}[tenantId]
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
    [Arguments]         ${zone_data}    ${token}    ${tenant_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${token}    X-Tenant-Id=${tenant_id}
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
    [Arguments]         ${block_data}    ${token}    ${tenant_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${token}    X-Tenant-Id=${tenant_id}
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
    [Arguments]         ${rack_data}    ${token}    ${tenant_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${token}    X-Tenant-Id=${tenant_id}
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
    [Arguments]         ${product_data}    ${token}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${token}    X-Tenant-Id=${product_data}[tenantId]
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}[id]    ${json}

Allocate Product To Rack
    [Documentation]     Allocate product batch to a rack
    [Arguments]         ${rack_id}    ${product_id}    ${batch_number}    ${quantity}    ${token}    ${tenant_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${token}    X-Tenant-Id=${tenant_id}
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

Transfer Product Between Warehouses
    [Documentation]     Transfer product batch between warehouses
    [Arguments]         ${source_rack_id}    ${dest_rack_id}    ${product_id}    ${batch_number}    ${quantity}    ${token}    ${tenant_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${token}    X-Tenant-Id=${tenant_id}
    ${transfer_data}=   Create Dictionary
    ...                 sourceRackId=${source_rack_id}
    ...                 destinationRackId=${dest_rack_id}
    ...                 productId=${product_id}
    ...                 batchNumber=${batch_number}
    ...                 quantity=${quantity}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /inventory/transfer
    ...                 json=${transfer_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Get Warehouse Inventory
    [Documentation]     Get warehouse inventory with batch details
    [Arguments]         ${warehouse_id}    ${token}    ${tenant_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${token}    X-Tenant-Id=${tenant_id}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /warehouses/${warehouse_id}/inventory
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}

Delete Rack
    [Documentation]     Delete a rack
    [Arguments]         ${rack_id}    ${token}    ${tenant_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${token}    X-Tenant-Id=${tenant_id}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /racks/delete/${rack_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    RETURN            ${TRUE}

Delete Block
    [Documentation]     Delete a block
    [Arguments]         ${block_id}    ${token}    ${tenant_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${token}    X-Tenant-Id=${tenant_id}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /blocks/delete/${block_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    RETURN            ${TRUE}

Delete Zone
    [Documentation]     Delete a zone
    [Arguments]         ${zone_id}    ${token}    ${tenant_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${token}    X-Tenant-Id=${tenant_id}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /zones/delete/${zone_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    RETURN            ${TRUE}

Delete Warehouse
    [Documentation]     Delete a warehouse
    [Arguments]         ${warehouse_id}    ${token}    ${tenant_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${token}    X-Tenant-Id=${tenant_id}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /warehouses/delete/${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    RETURN            ${TRUE}

Delete Product
    [Documentation]     Delete a product
    [Arguments]         ${product_id}    ${token}    ${tenant_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${token}    X-Tenant-Id=${tenant_id}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /products/delete/${product_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    RETURN            ${TRUE}

Validate TenantIsolation
    [Documentation]     Validate tenant cannot access another tenant's resources
    [Arguments]         ${warehouse_id}    ${token}    ${wrong_tenant_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${token}    X-Tenant-Id=${wrong_tenant_id}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /warehouses/get-one/${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=403
    Should Contain    ${response.text}    unauthorized    ignore_case=True

Validate BatchInventory
    [Documentation]     Validate batch quantity in warehouse inventory
    [Arguments]         ${inventory}    ${product_id}    ${batch_number}    ${expected_quantity}
    ${actual_quantity}=    Evaluate    ${inventory}[products][${product_id}][batches][${batch_number}][quantity]
    Should Be Equal As Integers    ${actual_quantity}    ${expected_quantity}
    ...                            Batch quantity ${actual_quantity} does not match expected ${expected_quantity}

*** Test Cases ***
01 - Multi-Tenant Warehouse Management Flow
    [Documentation]     Test multi-tenant warehouse management with complex validations
    [Tags]              e2e    warehouse    multi-tenant    batch    transfer    validation

    # Setup
    Setup Admin Session
    ${tenant1_token}=    Setup Tenant Session    ${TENANT1_USERNAME}    ${TENANT1_PASSWORD}    ${TENANT_ID_1}
    ${tenant2_token}=    Setup Tenant Session    ${TENANT2_USERNAME}    ${TENANT2_PASSWORD}    ${TENANT_ID_2}
    Log                 Authentication completed successfully for admin and tenants

    # Step 1: Positive - Create Warehouses for Tenant 1
    ${warehouse1_data}=    Generate Warehouse Data    ${TENANT_ID_1}    ${MAX_WAREHOUSE_ACREAGE - 1000}    Primary
    ${status_w1}    ${warehouse1_response}=    Create Warehouse    ${warehouse1_data}    ${tenant1_token}
    Should Be Equal As Integers    ${status_w1}    201
    Append To List    ${TEST_WAREHOUSE_IDS}    ${warehouse1_response}[id]
    Log                 Created Tenant 1 primary warehouse: ${warehouse1_response}[id]

    # Step 2: Positive - Create Warehouse for Tenant 2
    ${warehouse2_data}=    Generate Warehouse Data    ${TENANT_ID_2}    ${MAX_WAREHOUSE_ACREAGE - 2000}    Secondary
    ${status_w2}    ${warehouse2_response}=    Create Warehouse    ${warehouse2_data}    ${tenant2_token}
    Should Be Equal As Integers    ${status_w2}    201
    Append To List    ${TEST_WAREHOUSE_IDS}    ${warehouse2_response}[id]
    Log                 Created Tenant 2 secondary warehouse: ${warehouse2_response}[id]

    # Step 3: Negative - Tenant 2 Attempts to Access Tenant 1 Warehouse
    Validate TenantIsolation    ${warehouse1_response}[id]    ${tenant2_token}    ${TENANT_ID_2}
    Log                 Successfully validated tenant isolation

    # Step 4: Positive - Create Zone and Block for Tenant 1
    ${zone1_data}=    Generate Zone Data    ${warehouse1_response}[id]    ${MAX_ZONE_CAPACITY - 500}
    ${status_z1}    ${zone1_response}=    Create Zone    ${zone1_data}    ${tenant1_token}    ${TENANT_ID_1}
    Should Be Equal As Integers    ${status_z1}    201
    Append To List    ${TEST_ZONE_IDS}    ${zone1_response}[id]
    Log                 Created Tenant 1 zone: ${zone1_response}[id]

    ${block1_data}=    Generate Block Data    ${zone1_response}[id]    ${MAX_BLOCK_CAPACITY - 200}
    ${status_b1}    ${block1_response}=    Create Block    ${block1_data}    ${tenant1_token}    ${TENANT_ID_1}
    Should Be Equal As Integers    ${status_b1}    201
    Append To List    ${TEST_BLOCK_IDS}    ${block1_response}[id]
    Log                 Created Tenant 1 block: ${block1_response}[id]

    # Step 5: Edge Case - Create Rack at Maximum Capacity
    ${rack1_data}=    Generate Rack Data    ${warehouse1_response}[id]    ${zone1_response}[id]    ${block1_response}[id]    ${MAX_RACK_CAPACITY}
    ${status_r1}    ${rack1_response}=    Create Rack    ${rack1_data}    ${tenant1_token}    ${TENANT_ID_1}
    Should Be Equal As Integers    ${status_r1}    201
    Append To List    ${TEST_RACK_IDS}    ${rack1_response}[id]
    Log                 Created Tenant 1 rack at max capacity: ${rack1_response}[id]

    # Step 6: Positive - Create Second Rack for Transfer
    ${rack2_data}=    Generate Rack Data    ${warehouse1_response}[id]    ${zone1_response}[id]    ${block1_response}[id]    400
    ${status_r2}    ${rack2_response}=    Create Rack    ${rack2_data}    ${tenant1_token}    ${TENANT_ID_1}
    Should Be Equal As Integers    ${status_r2}    201
    Append To List    ${TEST_RACK_IDS}    ${rack2_response}[id]
    Log                 Created Tenant 1 second rack: ${rack2_response}[id]

    # Step 7: Negative - Attempt Rack Creation Exceeding Block Capacity
    ${excess_rack}=    Generate Rack Data    ${warehouse1_response}[id]    ${zone1_response}[id]    ${block1_response}[id]    600
    ${status_r3}    ${rack3_response}=    Create Rack    ${excess_rack}    ${tenant1_token}    ${TENANT_ID_1}
    Should Be Equal As Integers    ${status_r3}    400
    Should Contain    ${rack3_response}[message]    capacity    ignore_case=True
    Log                 Successfully prevented rack creation exceeding block capacity

    # Step 8: Positive - Create Product with Batch for Tenant 1
    ${product_data}=    Generate Product Data    ${TENANT_ID_1}
    ${product_id}    ${product_response}=    Create Product    ${product_data}    ${tenant1_token}
    Set Global Variable  ${TEST_PRODUCT_ID}    ${product_id}
    ${batch_number}=    Set Variable    ${product_response}[batches][0][batchNumber]
    Log                 Created Tenant 1 product: ${product_id} with batch ${batch_number}

    # Step 9: Positive - Allocate Product Batch to Rack
    ${status_a1}    ${alloc1_response}=    Allocate Product To Rack    ${rack1_response}[id]    ${product_id}    ${batch_number}    3000    ${tenant1_token}    ${TENANT_ID_1}
    Should Be Equal As Integers    ${status_a1}    201
    Log                 Allocated 3000 units of batch ${batch_number} to rack ${rack1_response}[id]

    # Step 10: Edge Case - Transfer Exact Remaining Batch Quantity
    ${status_t1}    ${transfer1_response}=    Transfer Product Between Warehouses    ${rack1_response}[id]    ${rack2_response}[id]    ${product_id}    ${batch_number}    2000    ${tenant1_token}    ${TENANT_ID_1}
    Should Be Equal As Integers    ${status_t1}    201
    Log                 Transferred 2000 units of batch ${batch_number} to rack ${rack2_response}[id]

    # Step 11: Negative - Attempt Transfer Exceeding Batch Quantity
    ${status_t2}    ${transfer2_response}=    Transfer Product Between Warehouses    ${rack1_response}[id]    ${rack2_response}[id]    ${product_id}    ${batch_number}    2000    ${tenant1_token}    ${TENANT_ID_1}
    Should Be Equal As Integers    ${status_t2}    400
    Should Contain    ${transfer2_response}[message]    quantity    ignore_case=True
    Log                 Successfully prevented transfer exceeding batch quantity

    # Step 12: Positive - Create Structure for Tenant 2 and Transfer Between Tenants
    ${zone2_data}=    Generate Zone Data    ${warehouse2_response}[id]    ${MAX_ZONE_CAPACITY - 1000}
    ${status_z2}    ${zone2_response}=    Create Zone    ${zone2_data}    ${tenant2_token}    ${TENANT_ID_2}
    Should Be Equal As Integers    ${status_z2}    201
    Append To List    ${TEST_ZONE_IDS}    ${zone2_response}[id]

    ${block2_data}=    Generate Block Data    ${zone2_response}[id]    ${MAX_BLOCK_CAPACITY - 300}
    ${status_b2}    ${block2_response}=    Create Block    ${block2_data}    ${tenant2_token}    ${TENANT_ID_2}
    Should Be Equal As Integers    ${status_b2}    201
    Append To List    ${TEST_BLOCK_IDS}    ${block2_response}[id]

    ${rack3_data}=    Generate Rack Data    ${warehouse2_response}[id]    ${zone2_response}[id]    ${block2_response}[id]    500
    ${status_r4}    ${rack3_response}=    Create Rack    ${rack3_data}    ${tenant2_token}    ${TENANT_ID_2}
    Should Be Equal As Integers    ${status_r4}    201
    Append To List    ${TEST_RACK_IDS}    ${rack3_response}[id]
    Log                 Created Tenant 2 rack: ${rack3_response}[id]

    # Step 13: Negative - Attempt Cross-Tenant Transfer
    ${status_t3}    ${transfer3_response}=    Transfer Product Between Warehouses    ${rack1_response}[id]    ${rack3_response}[id]    ${product_id}    ${batch_number}    500    ${tenant1_token}    ${TENANT_ID_1}
    Should Be Equal As Integers    ${status_t3}    403
    Should Contain    ${transfer3_response}[message]    unauthorized    ignore_case=True
    Log                 Successfully prevented cross-tenant transfer

    # Step 14: Validate Inventory for Tenant 1
    ${inventory1}=    Get Warehouse Inventory    ${warehouse1_response}[id]    ${tenant1_token}    ${TENANT_ID_1}
    Validate BatchInventory    ${inventory1}    ${product_id}    ${batch_number}    3000
    Log                 Successfully validated Tenant 1 inventory

    # Step 15: Clean Up
    FOR    ${rack_id}    IN    @{TEST_RACK_IDS}
        ${tenant_token}=    Run Keyword If    '${rack_id}' in '${warehouse1_response}[id]'    Set Variable    ${tenant1_token}    ELSE    Set Variable    ${tenant2_token}
        ${tenant_id}=       Run Keyword If    '${rack_id}' in '${warehouse1_response}[id]'    Set Variable    ${TENANT_ID_1}    ELSE    Set Variable    ${TENANT_ID_2}
        Delete Rack    ${rack_id}    ${tenant_token}    ${tenant_id}
    END
    FOR    ${block_id}    IN    @{TEST_BLOCK_IDS}
        Delete Block    ${block_id}    ${tenant2_token}    ${TENANT_ID_2}
    END
    FOR    ${zone_id}    IN    @{TEST_ZONE_IDS}
        ${tenant_token}=    Run Keyword If    '${zone_id}' in '${warehouse1_response}[id]'    Set Variable    ${tenant1_token}    ELSE    Set Variable    ${tenant2_token}
        ${tenant_id}=       Run Keyword If    '${zone_id}' in '${warehouse1_response}[id]'    Set Variable    ${TENANT_ID_1}    ELSE    Set Variable    ${TENANT_ID_2}
        Delete Zone    ${zone_id}    ${tenant_token}    ${tenant_id}
    END
    FOR    ${warehouse_id}    IN    @{TEST_WAREHOUSE_IDS}
        ${tenant_token}=    Run Keyword If    '${warehouse_id}' == '${warehouse1_response}[id]'    Set Variable    ${tenant1_token}    ELSE    Set Variable    ${tenant2_token}
        ${tenant_id}=       Run Keyword If    '${warehouse_id}' == '${warehouse1_response}[id]'    Set Variable    ${TENANT_ID_1}    ELSE    Set Variable    ${TENANT_ID_2}
        Delete Warehouse    ${warehouse_id}    ${tenant_token}    ${tenant_id}
    END
    Delete Product    ${TEST_PRODUCT_ID}    ${tenant1_token}    ${TENANT_ID_1}
    Log                 Successfully cleaned up all resources