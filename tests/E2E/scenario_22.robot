*** Settings ***
Documentation     Comprehensive End-to-End Test Suite for Product Management with Position Management, Rollbacks, and Zones
...               Includes position creation/deletion, rollback for concurrent failures, and zone interactions
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Resource          ../../Variables/variables.robot

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

Create Zone
    [Documentation]     Create a new zone in the warehouse
    [Arguments]         ${zone_name}=TestZone    ${capacity}=${ZONE_CAPACITY}
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${zone_data}=       Create Dictionary
    ...                 name=${zone_name} ${timestamp}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 capacity=${capacity}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /zones/create
    ...                 json=${zone_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${zone_id}=         Convert To String    ${json}[id]
    RETURN            ${zone_id}

Create Block
    [Documentation]     Create a new block within a zone
    [Arguments]         ${zone_id}    ${block_name}=TestBlock    ${capacity}=${BLOCK_CAPACITY}
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${block_data}=      Create Dictionary
    ...                 name=${block_name} ${timestamp}
    ...                 zoneId=${zone_id}
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
    RETURN            ${block_id}

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
    RETURN            ${shelf_id}

Create Rack
    [Documentation]     Create a new rack within a shelf
    [Arguments]         ${shelf_id}    ${rack_name}=TestRack    ${capacity}=${RACK_CAPACITY}
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${rack_data}=       Create Dictionary
    ...                 name=${rack_name} ${timestamp}
    ...                 shelfId=${shelf_id}
    ...                 capacity=${capacity}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /racks/create
    ...                 json=${rack_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${rack_id}=         Convert To String    ${json}[id]
    RETURN            ${rack_id}

Create Position
    [Documentation]     Create a new position within a rack
    [Arguments]         ${rack_id}    ${position_number}=1    ${capacity}=${POSITION_CAPACITY}
    
    ${position_data}=   Create Dictionary
    ...                 rackId=${rack_id}
    ...                 positionNumber=${position_number}
    ...                 capacity=${capacity}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /positions/create
    ...                 json=${position_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${position_id}=     Convert To String    ${json}[id]
    RETURN            ${position_id}

Delete Position
    [Documentation]     Delete a position from a rack
    [Arguments]         ${position_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /positions/delete/${position_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    RETURN            ${TRUE}

Generate Unique Product Data
    [Documentation]     Generate unique product data with position assignment
    [Arguments]         ${custom_name}=Test Product    ${quantity}=10    ${position_id}=${EMPTY}
    
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
    
    RETURN            ${product_data}

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
    RETURN            ${product_id}    ${json}

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
    RETURN            ${json}

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
    RETURN            ${order_id}    ${json}

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
        ...             shelfId=${new_shelf_ids}[${i]}
        ...             rackId=${new_rack_ids}[${i]}
        ...             positionId=${new_position_ids}[${i]}
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
    RETURN            ${json}

Assert Product Location
    [Documentation]     Verify a product’s location details
    [Arguments]         ${product}    ${expected_block_id}    ${expected_shelf_id}    ${expected_rack_id}    ${expected_position_id}
    
    Should Be Equal As Integers    ${product}[blockId]    ${expected_block_id}
    Should Be Equal As Integers    ${product}[shelfId]    ${expected_shelf_id}
    Should Be Equal As Integers    ${product}[rackId]    ${expected_rack_id}
    Should Be Equal As Integers    ${product}[positionId]    ${expected_position_id}

*** Test Cases ***
01 - Setup Test Environment With Zones
    [Documentation]     Setup API session and initial zone/block/shelf/rack structure
    [Tags]              setup
    
    Setup API Session
    
    ${zone_id}=         Create Zone
    ${block_id}=        Create Block    ${zone_id}
    ${shelf_id}=        Create Shelf    ${block_id}
    ${rack_id}=         Create Rack     ${shelf_id}
    
    Set Global Variable  ${ZONE_ID}     ${zone_id}
    Set Global Variable  ${BLOCK_ID}    ${block_id}
    Set Global Variable  ${SHELF_ID}    ${shelf_id}
    Set Global Variable  ${RACK_ID}     ${rack_id}
    
    Log                 Successfully set up Zone:${ZONE_ID}, Block:${BLOCK_ID}, Shelf:${SHELF_ID}, Rack:${RACK_ID}

02 - Create Position Test
    [Documentation]     Test creating a position within a rack
    [Tags]              position    create    positive
    
    ${position_id}=     Create Position    ${RACK_ID}    position_number=1
    
    ${product_data}=    Generate Unique Product Data    custom_name=Position Product    position_id=${position_id}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    Assert Product Location    ${response}    ${BLOCK_ID}    ${SHELF_ID}    ${RACK_ID}    ${position_id}
    
    Log                 Successfully created position ${position_id} and assigned product ${product_id}

03 - Delete Position Test
    [Documentation]     Test deleting a position and handling associated products
    [Tags]              position    delete    positive
    
    ${position_id}=     Create Position    ${RACK_ID}    position_number=2
    ${product_data}=    Generate Unique Product Data    custom_name=Delete Position Product    position_id=${position_id}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    ${delete_result}=   Delete Position    ${position_id}
    Should Be True      ${delete_result}
    
    ${updated_product}=    Get Product By ID    ${product_id}
    ${has_position}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${updated_product}    positionId
    Run Keyword If      ${has_position}    Should Not Be Equal    ${updated_product}[positionId]    ${position_id}
    ...    ELSE         Log    Product positionId removed as expected
    
    Log                 Successfully deleted position ${position_id} and verified product handling

04 - Zone Capacity Limit Test
    [Documentation]     Test exceeding zone capacity with multiple blocks
    [Tags]              capacity    zone    negative
    
    ${zone_id}=         Create Zone    zone_name=CapacityZone    capacity=${ZONE_CAPACITY}
    ${block_id1}=       Create Block    ${zone_id}    block_name=Block1    capacity=${BLOCK_CAPACITY}
    ${shelf_id1}=       Create Shelf    ${block_id1}
    ${rack_id1}=        Create Rack     ${shelf_id1}
    
    ${product_data1}=   Generate Unique Product Data    custom_name=Zone Capacity Product 1    quantity=${BLOCK_CAPACITY}    position_id=1
    Set To Dictionary   ${product_data1}    blockId=${block_id1}    shelfId=${shelf_id1}    rackId=${rack_id1}
    ${product_id1}    ${response1}=    Create Product    ${product_data1}
    
    ${block_id2}=       Create Block    ${zone_id}    block_name=Block2    capacity=${BLOCK_CAPACITY}
    ${shelf_id2}=       Create Shelf    ${block_id2}
    ${rack_id2}=        Create Rack     ${shelf_id2}
    
    ${product_data2}=   Generate Unique Product Data    custom_name=Zone Capacity Product 2    quantity=${ZONE_CAPACITY - BLOCK_CAPACITY + 1}    position_id=1
    Set To Dictionary   ${product_data2}    blockId=${block_id2}    shelfId=${shelf_id2}    rackId=${rack_id2}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data2}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    Log                 Successfully verified zone capacity limit enforcement

05 - Concurrent Picking Rollback Test
    [Documentation]     Test rollback when concurrent picking fails due to position capacity
    [Tags]              order    relocation    concurrent    rollback    negative
    
    # Create initial positions and products
    ${position_id1}=    Create Position    ${RACK_ID}    position_number=1
    ${position_id2}=    Create Position    ${RACK_ID}    position_number=2
    
    ${product_ids}=     Create List
    ${product_data1}=   Generate Unique Product Data    custom_name=Rollback Product 1    quantity=10    position_id=${position_id1}
    ${product_id1}    ${response1}=    Create Product    ${product_data1}
    ${product_data2}=   Generate Unique Product Data    custom_name=Rollback Product 2    quantity=10    position_id=${position_id2}
    ${product_id2}    ${response2}=    Create Product    ${product_data2}
    Append To List      ${product_ids}    ${product_id1}    ${product_id2}
    
    # Create orders
    ${quantities}=      Create List    5    5
    ${order_id1}    ${order_response1}=    Create Order With Products    ${product_ids}    ${quantities}
    ${order_id2}    ${order_response2}=    Create Order With Products    ${product_ids}    ${quantities}
    
    # Create a target position with limited capacity
    ${target_zone_id}=    Create Zone    zone_name=TargetZone
    ${target_block_id}=   Create Block    ${target_zone_id}    block_name=TargetBlock
    ${target_shelf_id}=   Create Shelf    ${target_block_id}
    ${target_rack_id}=    Create Rack     ${target_shelf_id}
    ${target_position_id}=    Create Position    ${target_rack_id}    position_number=1    capacity=${POSITION_CAPACITY}
    
    ${filler_product}=    Generate Unique Product Data    custom_name=Filler Product    quantity=${POSITION_CAPACITY - 5}    position_id=${target_position_id}
    Set To Dictionary     ${filler_product}    blockId=${target_block_id}    shelfId=${target_shelf_id}    rackId=${target_rack_id}
    ${filler_id}    ${filler_response}=    Create Product    ${filler_product}
    
    # First pick succeeds
    ${new_block_ids}=   Create List    ${target_block_id}    ${target_block_id}
    ${new_shelf_ids}=   Create List    ${target_shelf_id}    ${target_shelf_id}
    ${new_rack_ids}=    Create List    ${target_rack_id}    ${target_rack_id}
    ${new_position_ids}=    Create List    ${target_position_id}    ${target_position_id}
    
    ${pick_response1}=    Pick Order With Multiple Relocations    ${order_id1}    ${product_ids}    ${new_block_ids}    ${new_shelf_ids}    ${new_rack_ids}    ${new_position_ids}
    
    # Second pick fails due to capacity, should rollback
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
        ...             positionId=${new_position_ids}[${i]}
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
    
    # Verify rollback (second product should remain in original location)
    ${product1_after}=    Get Product By ID    ${product_ids}[0]
    Assert Product Location    ${product1_after}    ${target_block_id}    ${target_shelf_id}    ${target_rack_id}    ${target_position_id}
    
    ${product2_after}=    Get Product By ID    ${product_ids}[1]
    Assert Product Location    ${product2_after}    ${BLOCK_ID}    ${SHELF_ID}    ${RACK_ID}    ${position_id2}
    
    Log                 Successfully verified rollback on concurrent picking failure

06 - Zone Interaction With Multiple Blocks Test
    [Documentation]     Test placing products across multiple blocks within a zone
    [Tags]              zone    block    positive
    
    ${zone_id}=         Create Zone    zone_name=MultiBlockZone
    ${block_ids}=       Create List
    ${product_ids}=     Create List
    
    FOR    ${i}    IN RANGE    2
        ${block_id}=    Create Block    ${zone_id}    block_name=Block${i}
        ${shelf_id}=    Create Shelf    ${block_id}
        ${rack_id}=     Create Rack     ${shelf_id}
        ${position_id}= Create Position    ${rack_id}    position_number=1
        
        ${product_data}=    Generate Unique Product Data    custom_name=Zone Product ${i}    quantity=10    position_id=${position_id}
        Set To Dictionary   ${product_data}    blockId=${block_id}    shelfId=${shelf_id}    rackId=${rack_id}
        ${product_id}    ${response}=    Create Product    ${product_data}
        
        Append To List      ${block_ids}    ${block_id}
        Append To List      ${product_ids}    ${product_id}
    END
    
    # Verify products are correctly placed
    FOR    ${i}    IN RANGE    ${product_ids.__len__()}
        ${product}=    Get Product By ID    ${product_ids}[${i}]
        Should Be Equal As Integers    ${product}[blockId]    ${block_ids}[${i}]
    END
    
    Log                 Successfully placed products across multiple blocks in zone ${zone_id}