*** Settings ***
Documentation     End-to-End Test Suite for Product Management with Position-Level Capacity, Shelf/Rack Updates, and Concurrent Scenarios
...               Focuses on position capacity, shelf/rack management, and multi-product/order concurrency
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime

*** Variables ***
${BASE_URL}             https://api.vkho.net
${USERNAME}             huynh22.manager
${PASSWORD}             Snowfox1991
${WAREHOUSE_ID}         6
${SUPPLIER_ID}          56
${PRODUCT_CATEGORY_ID}  37
${BLOCK_ID}             ${EMPTY}
${SHELF_ID}             ${EMPTY}
${RACK_ID}              ${EMPTY}
${POSITION_CAPACITY}    20       # Example capacity per position in units
${RACK_CAPACITY}        50
${SHELF_CAPACITY}       100
${BLOCK_CAPACITY}       200
${RESULTS_DIR}          ${CURDIR}${/}results
${PRODUCT_IDS}          ${EMPTY}  # List for multiple products
${ORDER_IDS}            ${EMPTY}  # List for multiple orders

*** Keywords ***
Setup API Session
    [Documentation]     Create API session and authenticate
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${USERNAME}    password=${PASSWORD}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    access_token
    
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    
    Create Directory    ${RESULTS_DIR}

Create Block
    [Documentation]     Create a new block in the warehouse
    [Arguments]         ${block_name}=TestBlock    ${capacity}=${BLOCK_CAPACITY}
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${block_data}=      Create Dictionary
    ...                 name=${block_name} ${timestamp}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 capacity=${capacity}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /blocks/create
    ...                 json=${block_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${block_id}=        Convert To String    ${json}[id]
    [Return]            ${block_id}

Create Shelf
    [Documentation]     Create a new shelf within a block
    [Arguments]         ${block_id}    ${shelf_name}=TestShelf    ${capacity}=${SHELF_CAPACITY}
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${shelf_data}=      Create Dictionary
    ...                 name=${shelf_name} ${timestamp}
    ...                 blockId=${block_id}
    ...                 capacity=${capacity}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /shelves/create
    ...                 json=${shelf_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${shelf_id}=        Convert To String    ${json}[id]
    [Return]            ${shelf_id}

Update Shelf
    [Documentation]     Update an existing shelf’s details
    [Arguments]         ${shelf_id}    ${new_name}    ${new_capacity}
    
    ${update_data}=     Create Dictionary
    ...                 id=${shelf_id}
    ...                 name=${new_name}
    ...                 blockId=${BLOCK_ID}
    ...                 capacity=${new_capacity}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /shelves/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Be Equal     ${json}[name]    ${new_name}
    Should Be Equal As Integers    ${json}[capacity]    ${new_capacity}
    [Return]            ${json}

Create Rack
    [Documentation]     Create a new rack within a shelf with position capacity
    [Arguments]         ${shelf_id}    ${rack_name}=TestRack    ${capacity}=${RACK_CAPACITY}    ${position_capacity}=${POSITION_CAPACITY}
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${rack_data}=       Create Dictionary
    ...                 name=${rack_name} ${timestamp}
    ...                 shelfId=${shelf_id}
    ...                 capacity=${capacity}
    ...                 positionCapacity=${position_capacity}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /racks/create
    ...                 json=${rack_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${rack_id}=         Convert To String    ${json}[id]
    [Return]            ${rack_id}

Update Rack
    [Documentation]     Update an existing rack’s details
    [Arguments]         ${rack_id}    ${new_name}    ${new_capacity}    ${new_position_capacity}
    
    ${update_data}=     Create Dictionary
    ...                 id=${rack_id}
    ...                 name=${new_name}
    ...                 shelfId=${SHELF_ID}
    ...                 capacity=${new_capacity}
    ...                 positionCapacity=${new_position_capacity}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /racks/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Be Equal     ${json}[name]    ${new_name}
    Should Be Equal As Integers    ${json}[capacity]    ${new_capacity}
    Should Be Equal As Integers    ${json}[positionCapacity]    ${new_position_capacity}
    [Return]            ${json}

Generate Unique Product Data
    [Documentation]     Generate unique product data with position assignment
    [Arguments]         ${custom_name}=Test Product    ${quantity}=10    ${position_id}=1
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_name}=    Set Variable     ${custom_name} ${timestamp}
    ${product_code}=    Set Variable     PRD${timestamp}
    
    ${product_data}=    Create Dictionary
    ...                 name=${product_name}
    ...                 totalQuantity=${quantity}
    ...                 expectedQuantity=${quantity}
    ...                 importDate=2025-03-31T00:00:00.000Z
    ...                 cost=50.00
    ...                 salePrice=75.00
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 inboundKind=NEW
    ...                 expireDate=2026-03-31T00:00:00.000Z
    ...                 productCode=${product_code}
    ...                 supplierId=${SUPPLIER_ID}
    ...                 productCategoryId=${PRODUCT_CATEGORY_ID}
    ...                 blockId=${BLOCK_ID}
    ...                 shelfId=${SHELF_ID}
    ...                 rackId=${RACK_ID}
    ...                 positionId=${position_id}
    
    [Return]            ${product_data}

Create Product
    [Documentation]     Create a product with position assignment
    [Arguments]         ${product_data}
    
    FOR    ${key}    IN    name    warehouseId    blockId    shelfId    rackId    positionId
        Should Not Be Empty    ${product_data}[${key}]
    END
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${timestamp}=       Evaluate         int(time.time())    time
    Create File         ${RESULTS_DIR}${/}product_create_${timestamp}.json    ${response.text}
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${product_id}=      Convert To String    ${json}[id]
    [Return]            ${product_id}    ${json}

Get Product By ID
    [Documentation]     Retrieve a product by ID
    [Arguments]         ${product_id}
    
    Should Not Be Empty    ${product_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        GET On Session
    ...                 vkho
    ...                 /products/get-one/${product_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    [Return]            ${json}

Create Order With Products
    [Documentation]     Create an order with multiple products
    [Arguments]         ${product_ids}    ${quantities}
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${order_code}=      Set Variable     ORD${timestamp}
    ${items}=           Create List
    
    FOR    ${i}    IN RANGE    ${product_ids.__len__()}
        ${item}=        Create Dictionary
        ...             productId=${product_ids}[${i}]
        ...             quantity=${quantities}[${i}]
        ...             price=75.00
        Append To List  ${items}    ${item}
    END
    
    ${total_amount}=    Evaluate    sum([q * 75.00 for q in ${quantities}])
    
    ${order_data}=      Create Dictionary
    ...                 orderCode=${order_code}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 customerName=Test Customer ${timestamp}
    ...                 customerPhone=1234567890
    ...                 customerAddress=123 Test St
    ...                 items=${items}
    ...                 totalAmount=${total_amount}
    ...                 status=NEW
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/create
    ...                 json=${order_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${order_id}=        Convert To String    ${json}[id]
    [Return]            ${order_id}    ${json}

Pick Order With Multiple Relocations
    [Documentation]     Pick an order and relocate multiple products
    [Arguments]         ${order_id}    ${product_ids}    ${new_block_ids}    ${new_shelf_ids}    ${new_rack_ids}    ${new_position_ids}
    
    ${pick_data}=       Create Dictionary
    ...                 orderId=${order_id}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 pickerId=1
    ...                 relocations=${EMPTY}
    
    ${relocations}=     Create List
    FOR    ${i}    IN RANGE    ${product_ids.__len__()}
        ${relocation}=  Create Dictionary
        ...             productId=${product_ids}[${i}]
        ...             blockId=${new_block_ids}[${i}]
        ...             shelfId=${new_shelf_ids}[${i}]
        ...             rackId=${new_rack_ids}[${i]}
        ...             positionId=${new_position_ids}[${i}]
        Append To List  ${relocations}    ${relocation}
    END
    
    Set To Dictionary   ${pick_data}    relocations=${relocations}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /orders/pick
    ...                 json=${pick_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Contain Any    ${json}[status]    PICKING    PICKED
    [Return]            ${json}

Assert Product Location
    [Documentation]     Verify a product’s location details
    [Arguments]         ${product}    ${expected_block_id}    ${expected_shelf_id}    ${expected_rack_id}    ${expected_position_id}
    
    Should Be Equal As Integers    ${product}[blockId]    ${expected_block_id}
    Should Be Equal As Integers    ${product}[shelfId]    ${expected_shelf_id}
    Should Be Equal As Integers    ${product}[rackId]    ${expected_rack_id}
    Should Be Equal As Integers    ${product}[positionId]    ${expected_position_id}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session and initial block/shelf/rack structure
    [Tags]              setup
    
    Setup API Session
    
    ${block_id}=        Create Block
    ${shelf_id}=        Create Shelf    ${block_id}
    ${rack_id}=         Create Rack     ${shelf_id}
    
    Set Global Variable  ${BLOCK_ID}    ${block_id}
    Set Global Variable  ${SHELF_ID}    ${shelf_id}
    Set Global Variable  ${RACK_ID}     ${rack_id}
    
    Log                 Successfully set up Block:${BLOCK_ID}, Shelf:${SHELF_ID}, Rack:${RACK_ID}

02 - Position Capacity Limit Test
    [Documentation]     Test exceeding position capacity with a product
    [Tags]              capacity    position    negative
    
    ${product_data1}=   Generate Unique Product Data    custom_name=Position Capacity Product 1    quantity=${POSITION_CAPACITY / 2}    position_id=1
    ${product_id1}    ${response1}=    Create Product    ${product_data1}
    
    ${product_data2}=   Generate Unique Product Data    custom_name=Position Capacity Product 2    quantity=${POSITION_CAPACITY}    position_id=1
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data2}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    Log                 Successfully verified position capacity limit enforcement

03 - Multiple Positions Capacity Test
    [Documentation]     Test placing products across multiple positions with capacity limits
    [Tags]              capacity    position    positive
    
    ${product_ids}=     Create List
    ${positions}=       Create List    1    2    3
    
    FOR    ${pos}    IN    @{positions}
        ${product_data}=    Generate Unique Product Data    custom_name=Multi Position Product ${pos}    quantity=${POSITION_CAPACITY - 5}    position_id=${pos}
        ${product_id}    ${response}=    Create Product    ${product_data}
        Append To List      ${product_ids}    ${product_id}
        Assert Product Location    ${response}    ${BLOCK_ID}    ${SHELF_ID}    ${RACK_ID}    ${pos}
    END
    
    # Attempt to exceed capacity on position 1
    ${product_data_exceed}=    Generate Unique Product Data    custom_name=Exceed Position Product    quantity=${POSITION_CAPACITY}    position_id=1
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data_exceed}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    Log                 Successfully verified capacity across multiple positions

04 - Update Shelf Details Test
    [Documentation]     Test updating a shelf’s name and capacity
    [Tags]              shelf    update    positive
    
    ${shelf_id}=        Create Shelf    ${BLOCK_ID}    shelf_name=UpdatableShelf
    ${new_name}=        Set Variable    UpdatedShelfName
    ${new_capacity}=    Set Variable    150
    
    ${updated_shelf}=   Update Shelf    ${shelf_id}    ${new_name}    ${new_capacity}
    
    Should Be Equal     ${updated_shelf}[name]    ${new_name}
    Should Be Equal As Integers    ${updated_shelf}[capacity]    ${new_capacity}
    
    Log                 Successfully updated shelf ${shelf_id} to name:${new_name} and capacity:${new_capacity}

05 - Update Rack Details Test
    [Documentation]     Test updating a rack’s name, capacity, and position capacity
    [Tags]              rack    update    positive
    
    ${rack_id}=         Create Rack    ${SHELF_ID}    rack_name=UpdatableRack
    ${new_name}=        Set Variable    UpdatedRackName
    ${new_capacity}=    Set Variable    75
    ${new_position_capacity}=    Set Variable    25
    
    ${updated_rack}=    Update Rack    ${rack_id}    ${new_name}    ${new_capacity}    ${new_position_capacity}
    
    Should Be Equal     ${updated_rack}[name]    ${new_name}
    Should Be Equal As Integers    ${updated_rack}[capacity]    ${new_capacity}
    Should Be Equal As Integers    ${updated_rack}[positionCapacity]    ${new_position_capacity}
    
    Log                 Successfully updated rack ${rack_id} to name:${new_name}, capacity:${new_capacity}, positionCapacity:${new_position_capacity}

06 - Complex Concurrent Picking Multiple Products Test
    [Documentation]     Test concurrent picking and relocation of multiple products across multiple orders
    [Tags]              order    relocation    concurrent    positive
    
    # Create multiple products
    ${product_ids}=     Create List
    ${positions}=       Create List    1    2
    FOR    ${i}    IN RANGE    2
        ${product_data}=    Generate Unique Product Data    custom_name=Concurrent Product ${i}    quantity=10    position_id=${positions}[${i}]
        ${product_id}    ${response}=    Create Product    ${product_data}
        Append To List      ${product_ids}    ${product_id}
    END
    
    # Create multiple orders
    ${order_ids}=       Create List
    ${quantities}=      Create List    5    5
    ${order_id1}    ${order_response1}=    Create Order With Products    ${product_ids}    ${quantities}
    ${order_id2}    ${order_response2}=    Create Order With Products    ${product_ids}    ${quantities}
    Append To List      ${order_ids}    ${order_id1}    ${order_id2}
    
    # Create new locations for relocation
    ${new_block_ids}=   Create List
    ${new_shelf_ids}=   Create List
    ${new_rack_ids}=    Create List
    ${new_position_ids}=    Create List    1    2
    
    FOR    ${i}    IN RANGE    2
        ${block_id}=    Create Block    block_name=NewBlock${i}
        ${shelf_id}=    Create Shelf    ${block_id}    shelf_name=NewShelf${i}
        ${rack_id}=     Create Rack     ${shelf_id}    rack_name=NewRack${i}
        Append To List  ${new_block_ids}    ${block_id}
        Append To List  ${new_shelf_ids}    ${shelf_id}
        Append To List  ${new_rack_ids}     ${rack_id}
    END
    
    # Pick orders with relocations (simulated concurrency)
    ${pick_response1}=    Pick Order With Multiple Relocations    ${order_id1}    ${product_ids}    ${new_block_ids}    ${new_shelf_ids}    ${new_rack_ids}    ${new_position_ids}
    ${pick_response2}=    Pick Order With Multiple Relocations    ${order_id2}    ${product_ids}    ${new_block_ids}    ${new_shelf_ids}    ${new_rack_ids}    ${new_position_ids}
    
    # Verify final locations (last relocation wins due to sequential execution)
    FOR    ${i}    IN RANGE    ${product_ids.__len__()}
        ${updated_product}=    Get Product By ID    ${product_ids}[${i}]
        Assert Product Location    ${updated_product}    ${new_block_ids}[${i}]    ${new_shelf_ids}[${i}]    ${new_rack_ids}[${i}]    ${new_position_ids}[${i}]
    END
    
    Log                 Successfully handled concurrent picking and relocation for multiple products across orders ${order_ids}

07 - Concurrent Picking With Position Capacity Conflict Test
    [Documentation]     Test concurrent picking where relocation exceeds position capacity
    [Tags]              order    relocation    concurrent    capacity    negative
    
    # Create two products in different positions
    ${product_ids}=     Create List
    ${product_data1}=   Generate Unique Product Data    custom_name=Conflict Product 1    quantity=10    position_id=1
    ${product_id1}    ${response1}=    Create Product    ${product_data1}
    ${product_data2}=   Generate Unique Product Data    custom_name=Conflict Product 2    quantity=10    position_id=2
    ${product_id2}    ${response2}=    Create Product    ${product_data2}
    Append To List      ${product_ids}    ${product_id1}    ${product_id2}
    
    # Create two orders
    ${quantities}=      Create List    5    5
    ${order_id1}    ${order_response1}=    Create Order With Products    ${product_ids}    ${quantities}
    ${order_id2}    ${order_response2}=    Create Order With Products    ${product_ids}    ${quantities}
    
    # Create a target location with limited position capacity
    ${target_block_id}=    Create Block    block_name=TargetBlock
    ${target_shelf_id}=    Create Shelf    ${target_block_id}    shelf_name=TargetShelf
    ${target_rack_id}=     Create Rack     ${target_shelf_id}    rack_name=TargetRack    position_capacity=${POSITION_CAPACITY}
    
    # Fill target position partially
    ${filler_product}=    Generate Unique Product Data    custom_name=Filler Product    quantity=${POSITION_CAPACITY - 5}    position_id=1
    Set To Dictionary     ${filler_product}    blockId=${target_block_id}    shelfId=${target_shelf_id}    rackId=${target_rack_id}
    ${filler_id}    ${filler_response}=    Create Product    ${filler_product}
    
    # Attempt concurrent relocation to the same position
    ${new_block_ids}=   Create List    ${target_block_id}    ${target_block_id}
    ${new_shelf_ids}=   Create List    ${target_shelf_id}    ${target_shelf_id}
    ${new_rack_ids}=    Create List    ${target_rack_id}    ${target_rack_id}
    ${new_position_ids}=    Create List    1    1
    
    ${pick_response1}=    Pick Order With Multiple Relocations    ${order_id1}    ${product_ids}    ${new_block_ids}    ${new_shelf_ids}    ${new_rack_ids}    ${new_position_ids}
    
    # Second pick should fail due to position capacity
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${pick_data}=       Create Dictionary
    ...                 orderId=${order_id2}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 pickerId=1
    ...                 relocations=${EMPTY}
    
    ${relocations}=     Create List
    FOR    ${i}    IN RANGE    ${product_ids.__len__()}
        ${relocation}=  Create Dictionary
        ...             productId=${product_ids}[${i}]
        ...             blockId=${new_block_ids}[${i}]
        ...             shelfId=${new_shelf_ids}[${i]}
        ...             rackId=${new_rack_ids}[${i]}
        ...             positionId=${new_position_ids}[${i}]
        Append To List  ${relocations}    ${relocation}
    END
    Set To Dictionary   ${pick_data}    relocations=${relocations}
    
    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /orders/pick
    ...                 json=${pick_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified position capacity conflict in concurrent picking