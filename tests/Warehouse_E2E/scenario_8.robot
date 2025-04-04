*** Settings ***
Documentation     Advanced End-to-End Test Suite for Warehouse Management
...               Tests complex hierarchy, inventory with variants, and operational constraints
...               Includes positive, negative, and edge case validations
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
    [Documentation]     Generate warehouse data with specific acreage and status
    [Arguments]         ${acreage}    ${status}=ENABLED
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_data}=  Create Dictionary
    ...                 name=Advanced Warehouse ${timestamp}
    ...                 address=300 Complex St
    ...                 acreage=${acreage}
    ...                 status=${status}
    RETURN            ${warehouse_data}

Generate Zone Data
    [Documentation]     Generate zone data with specific capacity
    [Arguments]         ${warehouse_id}    ${capacity}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${zone_data}=      Create Dictionary
    ...                 capacity=${capacity}
    ...                 name=Complex Zone ${timestamp}
    ...                 warehouseId=${warehouse_id}
    RETURN            ${zone_data}

Generate Block Data
    [Documentation]     Generate block data with specific capacity
    [Arguments]         ${zone_id}    ${capacity}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${block_data}=     Create Dictionary
    ...                 capacity=${capacity}
    ...                 name=Storage Block ${timestamp}
    ...                 zoneId=${zone_id}
    RETURN            ${block_data}

Generate Rack Data
    [Documentation]     Generate rack data with specific capacity
    [Arguments]         ${warehouse_id}    ${zone_id}    ${block_id}    ${capacity}
    ${rack_data}=      Create Dictionary
    ...                 capacity=${capacity}
    ...                 warehouseId=${warehouse_id}
    ...                 zoneId=${zone_id}
    ...                 blockId=${block_id}
    ...                 shelfId=1
    RETURN            ${rack_data}

Generate Product Data
    [Documentation]     Generate product data with variants
    ${timestamp}=       Evaluate         int(time.time())    time
    ${variants}=        Create List
    ...                 ${{"size": "Small", "quantity": 1000}}
    ...                 ${{"size": "Large", "quantity": 1000}}
    ${product_data}=   Create Dictionary
    ...                 name=Complex Product ${timestamp}
    ...                 sku=SKU-${timestamp}
    ...                 variants=${variants}
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
    [Documentation]     Create a new product with variants
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
    [Documentation]     Allocate product variant to a rack
    [Arguments]         ${rack_id}    ${product_id}    ${variant_index}    ${quantity}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${allocation_data}= Create Dictionary
    ...                 rackId=${rack_id}
    ...                 productId=${product_id}
    ...                 variantIndex=${variant_index}
    ...                 quantity=${quantity}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /inventory/allocate
    ...                 json=${allocation_data}
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

Validate Structure Capacity
    [Documentation]     Validate capacity constraints across hierarchy
    [Arguments]         ${warehouse}    ${zone_id}    ${block_id}    @{rack_ids}
    ${total_rack_capacity}=    Evaluate    sum([${rack.capacity} for ${rack} in ${warehouse.zones[0].blocks[0].racks}])
    Should Be True    ${total_rack_capacity} <= ${MAX_BLOCK_CAPACITY}
    ...               Rack capacity ${total_rack_capacity} exceeds block max ${MAX_BLOCK_CAPACITY}
    Should Be True    ${warehouse}[zones][0][capacity] <= ${MAX_ZONE_CAPACITY}
    ...               Zone capacity ${warehouse}[zones][0][capacity] exceeds max ${MAX_ZONE_CAPACITY}
    Should Be True    ${warehouse}[acreage] <= ${MAX_WAREHOUSE_ACREAGE}
    ...               Warehouse acreage ${warehouse}[acreage] exceeds max ${MAX_WAREHOUSE_ACREAGE}

Validate Inventory
    [Documentation]     Validate product inventory allocation
    [Arguments]         ${warehouse}    ${product_id}    ${variant_index}    ${expected_quantity}
    ${allocated}=      Evaluate    ${warehouse.zones[0].blocks[0].racks[0].inventory[${product_id}][variants][${variant_index}][quantity]}
    Should Be Equal As Integers    ${allocated}    ${expected_quantity}
    ...                            Allocated quantity ${allocated} does not match expected ${expected_quantity}

*** Test Cases ***
01 - Advanced Warehouse Management Flow
    [Documentation]     Test complex warehouse management with advanced validations
    [Tags]              e2e    warehouse    zone    block    rack    inventory    validation

    # Setup
    Setup Admin Session
    Setup Manager Session
    Log                 Authentication completed successfully

    # Step 1: Positive - Create Warehouse with Maximum Acreage
    ${warehouse_data}=    Generate Warehouse Data    ${MAX_WAREHOUSE_ACREAGE}
    ${status_w}    ${warehouse_response}=    Create Warehouse    ${warehouse_data}
    Should Be Equal As Integers    ${status_w}    201
    Set Global Variable  ${TEST_WAREHOUSE_ID}    ${warehouse_response}[id]
    Log                 Created warehouse: ${warehouse_response}[name] with ID: ${warehouse_response}[id]

    # Step 2: Negative - Attempt Warehouse with Excess Acreage
    ${invalid_warehouse}=    Generate Warehouse Data    ${MAX_WAREHOUSE_ACREAGE + 1}
    ${status_w2}    ${warehouse_response2}=    Create Warehouse    ${invalid_warehouse}
    Should Be Equal As Integers    ${status_w2}    400
    Should Contain    ${warehouse_response2}[message]    acreage    ignore_case=True
    Log                 Successfully prevented warehouse creation exceeding max acreage

    # Step 3: Positive - Create Zone with Valid Capacity
    ${zone_data}=    Generate Zone Data    ${TEST_WAREHOUSE_ID}    ${MAX_ZONE_CAPACITY - 100}
    ${status_z}    ${zone_response}=    Create Zone    ${zone_data}
    Should Be Equal As Integers    ${status_z}    201
    Set Global Variable  ${TEST_ZONE_ID}    ${zone_response}[id]
    Log                 Created zone: ${zone_response}[name] with ID: ${zone_response}[id]

    # Step 4: Edge Case - Create Zone at Maximum Capacity
    ${edge_zone_data}=    Generate Zone Data    ${TEST_WAREHOUSE_ID}    ${MAX_ZONE_CAPACITY}
    ${status_z2}    ${zone_response2}=    Create Zone    ${edge_zone_data}
    Should Be Equal As Integers    ${status_z2}    201
    Delete Zone    ${zone_response2}[id]    # Clean up edge case zone
    Log                 Successfully created zone at maximum capacity

    # Step 5: Negative - Attempt Zone Exceeding Capacity
    ${invalid_zone}=    Generate Zone Data    ${TEST_WAREHOUSE_ID}    ${MAX_ZONE_CAPACITY + 1}
    ${status_z3}    ${zone_response3}=    Create Zone    ${invalid_zone}
    Should Be Equal As Integers    ${status_z3}    400
    Should Contain    ${zone_response3}[message]    capacity    ignore_case=True
    Log                 Successfully prevented zone creation exceeding max capacity

    # Step 6: Positive - Create Block with Valid Capacity
    ${block_data}=    Generate Block Data    ${TEST_ZONE_ID}    ${MAX_BLOCK_CAPACITY - 100}
    ${status_b}    ${block_response}=    Create Block    ${block_data}
    Should Be Equal As Integers    ${status_b}    201
    Set Global Variable  ${TEST_BLOCK_ID}    ${block_response}[id]
    Log                 Created block: ${block_response}[name] with ID: ${block_response}[id]

    # Step 7: Edge Case - Create Rack with Minimum Capacity
    ${min_rack_data}=    Generate Rack Data    ${TEST_WAREHOUSE_ID}    ${TEST_ZONE_ID}    ${TEST_BLOCK_ID}    ${MIN_RACK_CAPACITY}
    ${status_r1}    ${rack_response1}=    Create Rack    ${min_rack_data}
    Should Be Equal As Integers    ${status_r1}    201
    Append To List    ${TEST_RACK_IDS}    ${rack_response1}[id]
    Log                 Created rack with minimum capacity: ${rack_response1}[id]

    # Step 8: Positive - Create Rack with Valid Capacity
    ${rack_data}=    Generate Rack Data    ${TEST_WAREHOUSE_ID}    ${TEST_ZONE_ID}    ${TEST_BLOCK_ID}    400
    ${status_r2}    ${rack_response2}=    Create Rack    ${rack_data}
    Should Be Equal As Integers    ${status_r2}    201
    Append To List    ${TEST_RACK_IDS}    ${rack_response2}[id]
    Log                 Created rack with ID: ${rack_response2}[id]

    # Step 9: Negative - Attempt Rack Exceeding Block Capacity
    ${excess_rack}=    Generate Rack Data    ${TEST_WAREHOUSE_ID}    ${TEST_ZONE_ID}    ${TEST_BLOCK_ID}    ${MAX_BLOCK_CAPACITY}
    ${status_r3}    ${rack_response3}=    Create Rack    ${excess_rack}
    Should Be Equal As Integers    ${status_r3}    400
    Should Contain    ${rack_response3}[message]    capacity    ignore_case=True
    Log                 Successfully prevented rack creation exceeding block capacity

    # Step 10: Positive - Create Product with Variants
    ${product_data}=    Generate Product Data
    ${product_id}    ${product_response}=    Create Product    ${product_data}
    Set Global Variable  ${TEST_PRODUCT_ID}    ${product_id}
    Log                 Created product: ${product_response}[name] with ID: ${product_id}

    # Step 11: Positive - Allocate Product Variant to Rack
    ${status_a1}    ${alloc_response1}=    Allocate Product To Rack    ${rack_response2}[id]    ${product_id}    0    800
    Should Be Equal As Integers    ${status_a1}    201
    Log                 Allocated 800 units of Small variant to rack ${rack_response2}[id]

    # Step 12: Negative - Attempt Allocation Exceeding Variant Quantity
    ${status_a2}    ${alloc_response2}=    Allocate Product To Rack    ${rack_response1}[id]    ${product_id}    0    300
    Should Be Equal As Integers    ${status_a2}    400
    Should Contain    ${alloc_response2}[message]    quantity    ignore_case=True
    Log                 Successfully prevented allocation exceeding variant quantity

    # Step 13: Edge Case - Allocate Remaining Variant Quantity
    ${status_a3}    ${alloc_response3}=    Allocate Product To Rack    ${rack_response1}[id]    ${product_id}    0    200
    Should Be Equal As Integers    ${status_a3}    201
    Log                 Allocated remaining 200 units of Small variant to rack ${rack_response1}[id]

    # Step 14: Validate Structure and Inventory
    ${warehouse_details}=    Get Warehouse Details    ${TEST_WAREHOUSE_ID}
    Validate Structure Capacity    ${warehouse_details}    ${TEST_ZONE_ID}    ${TEST_BLOCK_ID}    @{TEST_RACK_IDS}
    Validate Inventory    ${warehouse_details}    ${product_id}    0    1000
    Log                 Successfully validated structure capacity and inventory allocation

    # Step 15: Clean Up
    FOR    ${rack_id}    IN    @{TEST_RACK_IDS}
        Delete Rack    ${rack_id}
    END
    Delete Block    ${TEST_BLOCK_ID}
    Delete Zone    ${TEST_ZONE_ID}
    Delete Warehouse    ${TEST_WAREHOUSE_ID}
    Delete Product    ${TEST_PRODUCT_ID}
    Log                 Successfully cleaned up all resources