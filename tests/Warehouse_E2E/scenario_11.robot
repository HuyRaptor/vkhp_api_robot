*** Settings ***
Documentation     Advanced End-to-End Test Suite for Dynamic Warehouse Management
...               Tests dynamic routing, quality control, and batch recall
...               Includes positive, negative, and edge case validations
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Library           BuiltIn
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
    [Documentation]     Generate warehouse data with routing preferences
    ${timestamp}=       Evaluate         int(time.time())    time
    ${routing_prefs}=   Create Dictionary    priority=high    type=perishable
    ${warehouse_data}=  Create Dictionary
    ...                 name=Dynamic Warehouse ${timestamp}
    ...                 address=600 Logistics Dr
    ...                 acreage=${Evaluate    ${MAX_WAREHOUSE_ACREAGE} - 1000}
    ...                 status=ENABLED
    ...                 routingPreferences=${routing_prefs}
    RETURN            ${warehouse_data}

Generate Zone Data
    [Documentation]     Generate zone data with capacity and type
    [Arguments]         ${warehouse_id}    ${capacity}    ${zone_type}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${zone_data}=      Create Dictionary
    ...                 capacity=${capacity}
    ...                 name=${zone_type} Zone ${timestamp}
    ...                 warehouseId=${warehouse_id}
    ...                 type=${zone_type}
    RETURN            ${zone_data}

Generate Block Data
    [Documentation]     Generate block data with capacity
    [Arguments]         ${zone_id}    ${capacity}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${block_data}=     Create Dictionary
    ...                 capacity=${capacity}
    ...                 name=Dynamic Block ${timestamp}
    ...                 zoneId=${zone_id}
    RETURN            ${block_data}

Generate Rack Data
    [Documentation]     Generate rack data with capacity and priority
    [Arguments]         ${warehouse_id}    ${zone_id}    ${block_id}    ${capacity}    ${priority}
    ${rack_data}=      Create Dictionary
    ...                 capacity=${capacity}
    ...                 warehouseId=${warehouse_id}
    ...                 zoneId=${zone_id}
    ...                 blockId=${block_id}
    ...                 shelfId=1
    ...                 priority=${priority}
    RETURN            ${rack_data}

Generate Product Data
    [Documentation]     Generate product data with batch and quality status
    ${timestamp}=       Evaluate         int(time.time())    time
    ${expiration}=      Get Current Date    ${CURRENT_DATE}    increment=15d    result_format=%Y-%m-%dT%H:%M:%SZ
    ${batch}=           Create Dictionary    batchNumber=BN-${timestamp}    quantity=${MAX_BATCH_QUANTITY}    expirationDate=${expiration}
    ${product_data}=   Create Dictionary
    ...                 name=Dynamic Product ${timestamp}
    ...                 sku=SKU-${timestamp}
    ...                 batches=${[batch]}
    ...                 type=perishable
    ...                 qualityStatus=PENDING
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
    ${json}=            Evangelize         json.loads('''${response.text}''')    json
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

Route Product To Rack
    [Documentation]     Dynamically route product batch to a rack
    [Arguments]         ${product_id}    ${batch_number}    ${quantity}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${routing_data}=    Create Dictionary
    ...                 productId=${product_id}
    ...                 batchNumber=${batch_number}
    ...                 quantity=${quantity}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /inventory/route
    ...                 json=${routing_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Update Quality Status
    [Documentation]     Update product quality status
    [Arguments]         ${product_id}    ${status}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${update_data}=     Create Dictionary
    ...                 id=${product_id}
    ...                 qualityStatus=${status}
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /products/update-quality
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Recall Batch
    [Documentation]     Recall a product batch
    [Arguments]         ${product_id}    ${batch_number}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${recall_data}=     Create Dictionary
    ...                 productId=${product_id}
    ...                 batchNumber=${batch_number}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /inventory/recall
    ...                 json=${recall_data}
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

Validate Routing
    [Documentation]     Validate product was routed to highest priority rack
    [Arguments]         ${inventory}    ${product_id}    ${batch_number}    ${expected_rack_id}
    ${actual_rack_id}=    Evaluate    ${inventory}[zones][0][blocks][0][racks][0][id] if ${inventory}[zones][0][blocks][0][racks][0][inventory][${product_id}][batches][${batch_number}][quantity] > 0 else None
    Should Be Equal    ${actual_rack_id}    ${expected_rack_id}
    ...                Product routed to rack ${actual_rack_id} instead of expected ${expected_rack_id}

Validate BatchQuantity
    [Documentation]     Validate batch quantity in inventory
    [Arguments]         ${inventory}    ${product_id}    ${batch_number}    ${expected_quantity}
    ${actual_quantity}=    Evaluate    ${inventory}[zones][0][blocks][0][racks][0][inventory][${product_id}][batches][${batch_number}][quantity]
    Should Be Equal As Integers    ${actual_quantity}    ${expected_quantity}
    ...                            Batch quantity ${actual_quantity} does not match expected ${expected_quantity}

*** Test Cases ***
01 - Dynamic Warehouse Management Flow
    [Documentation]     Test dynamic warehouse management with complex validations
    [Tags]              e2e    warehouse    routing    quality    recall    validation

    # Setup
    Setup Admin Session
    Setup Manager Session
    Log                 Authentication completed successfully

    # Step 1: Positive - Create Warehouse with Routing Preferences
    ${warehouse_data}=    Generate Warehouse Data
    ${status_w}    ${warehouse_response}=    Create Warehouse    ${warehouse_data}
    Should Be Equal As Integers    ${status_w}    201
    Set Global Variable  ${TEST_WAREHOUSE_ID}    ${warehouse_response}[id]
    Log                 Created warehouse: ${warehouse_response}[id]

    # Step 2: Positive - Create Zones for Different Types
    ${zone1_data}=    Generate Zone Data    ${TEST_WAREHOUSE_ID}    ${MAX_ZONE_CAPACITY - 1000}    perishable
    ${status_z1}    ${zone1_response}=    Create Zone    ${zone1_data}
    Should Be Equal As Integers    ${status_z1}    201
    Append To List    ${TEST_ZONE_IDS}    ${zone1_response}[id]
    Log                 Created perishable zone: ${zone1_response}[id]

    ${zone2_data}=    Generate Zone Data    ${TEST_WAREHOUSE_ID}    ${MAX_ZONE_CAPACITY - 1500}    standard
    ${status_z2}    ${zone2_response}=    Create Zone    ${zone2_data}
    Should Be Equal As Integers    ${status_z2}    201
    Append To List    ${TEST_ZONE_IDS}    ${zone2_response}[id]
    Log                 Created standard zone: ${zone2_response}[id]

    # Step 3: Positive - Create Block in Perishable Zone
    ${block_data}=    Generate Block Data    ${zone1_response}[id]    ${MAX_BLOCK_CAPACITY - 300}
    ${status_b}    ${block_response}=    Create Block    ${block_data}
    Should Be Equal As Integers    ${status_b}    201
    Set Global Variable  ${TEST_BLOCK_ID}    ${block_response}[id]
    Append To List    ${TEST_BLOCK_IDS}    ${block_response}[id]
    Log                 Created block: ${block_response}[id]

    # Step 4: Positive - Create Racks with Priorities
    ${rack1_data}=    Generate Rack Data    ${TEST_WAREHOUSE_ID}    ${zone1_response}[id]    ${block_response}[id]    500    high
    ${status_r1}    ${rack1_response}=    Create Rack    ${rack1_data}
    Should Be Equal As Integers    ${status_r1}    201
    Append To List    ${TEST_RACK_IDS}    ${rack1_response}[id]
    Log                 Created high-priority rack: ${rack1_response}[id]

    ${rack2_data}=    Generate Rack Data    ${TEST_WAREHOUSE_ID}    ${zone1_response}[id]    ${block_response}[id]    600    low
    ${status_r2}    ${rack2_response}=    Create Rack    ${rack2_data}
    Should Be Equal As Integers    ${status_r2}    201
    Append To List    ${TEST_RACK_IDS}    ${rack2_response}[id]
    Log                 Created low-priority rack: ${rack2_response}[id]

    # Step 5: Edge Case - Create Rack at Maximum Capacity
    ${rack3_data}=    Generate Rack Data    ${TEST_WAREHOUSE_ID}    ${zone1_response}[id]    ${block_response}[id]    ${MAX_RACK_CAPACITY}    medium
    ${status_r3}    ${rack3_response}=    Create Rack    ${rack3_data}
    Should Be Equal As Integers    ${status_r3}    201
    Append To List    ${TEST_RACK_IDS}    ${rack3_response}[id]
    Log                 Created rack at max capacity: ${rack3_response}[id]

    # Step 6: Negative - Attempt Rack Creation Exceeding Block Capacity
    ${excess_rack}=    Generate Rack Data    ${TEST_WAREHOUSE_ID}    ${zone1_response}[id]    ${block_response}[id]    700    medium
    ${status_r4}    ${rack4_response}=    Create Rack    ${excess_rack}
    Should Be Equal As Integers    ${status_r4}    400
    Should Contain    ${rack4_response}[message]    capacity    ignore_case=True
    Log                 Successfully prevented rack creation exceeding block capacity

    # Step 7: Positive - Create Product with Batch
    ${product_data}=    Generate Product Data
    ${product_id}    ${product_response}=    Create Product    ${product_data}
    Set Global Variable  ${TEST_PRODUCT_ID}    ${product_id}
    ${batch_number}=    Set Variable    ${product_response}[batches][0][batchNumber]
    Log                 Created product: ${product_id} with batch ${batch_number}

    # Step 8: Negative - Attempt Routing Before Quality Approval
    ${status_route1}    ${route1_response}=    Route Product To Rack    ${product_id}    ${batch_number}    4000
    Should Be Equal As Integers    ${status_route1}    400
    Should Contain    ${route1_response}[message]    quality    ignore_case=True
    Log                 Successfully prevented routing before quality approval

    # Step 9: Positive - Approve Quality
    ${status_q1}    ${quality1_response}=    Update Quality Status    ${product_id}    APPROVED
    Should Be Equal As Integers    ${status_q1}    200
    Log                 Approved product quality for ${product_id}

    # Step 10: Positive - Route Product to High-Priority Rack
    ${status_route2}    ${route2_response}=    Route Product To Rack    ${product_id}    ${batch_number}    4000
    Should Be Equal As Integers    ${status_route2}    201
    Log                 Routed 4000 units of batch ${batch_number} to high-priority rack

    # Step 11: Edge Case - Route Remaining Quantity
    ${status_route3}    ${route3_response}=    Route Product To Rack    ${product_id}    ${batch_number}    ${MAX_BATCH_QUANTITY - 4000}
    Should Be Equal As Integers    ${status_route3}    201
    Log                 Routed remaining ${MAX_BATCH_QUANTITY - 4000} units of batch ${batch_number}

    # Step 12: Negative - Attempt Routing Exceeding Batch Quantity
    ${status_route4}    ${route4_response}=    Route Product To Rack    ${product_id}    ${batch_number}    1000
    Should Be Equal As Integers    ${status_route4}    400
    Should Contain    ${route4_response}[message]    quantity    ignore_case=True
    Log                 Successfully prevented routing exceeding batch quantity

    # Step 13: Positive - Simulate Quality Issue and Recall Batch
    ${status_q2}    ${quality2_response}=    Update Quality Status    ${product_id}    REJECTED
    Should Be Equal As Integers    ${status_q2}    200
    Log                 Marked product quality as REJECTED

    ${recall_response}=    Recall Batch    ${product_id}    ${batch_number}
    Log                 Recalled batch ${batch_number} for ${product_id}

    # Step 14: Validate Inventory and Routing
    ${inventory}=    Get Warehouse Inventory    ${TEST_WAREHOUSE_ID}
    Validate Routing    ${inventory}    ${product_id}    ${batch_number}    ${rack1_response}[id]
    Validate BatchQuantity    ${inventory}    ${product_id}    ${batch_number}    ${MAX_BATCH_QUANTITY}
    Log                 Successfully validated routing and batch quantity

    # Step 15: Clean Up
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