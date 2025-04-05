*** Settings ***
Documentation     Enhanced End-to-End Test Suite for Product Management with Blocks, Shelves, Racks, and Positions
...               Includes capacity limits, independent block/shelf/rack management, and order picking relocation
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
    ${body}=            Create Dictionary    username=${MANAGER_USERNAME}    password=${MANAGER_PASSWORD}
    
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
    [Arguments]         ${block_name}=TestBlock
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${block_data}=      Create Dictionary
    ...                 name=${block_name} ${timestamp}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 capacity=${SHELF_CAPACITY * 2}  # Arbitrary large capacity for block
    
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
    [Arguments]         ${block_id}    ${shelf_name}=TestShelf
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${shelf_data}=      Create Dictionary
    ...                 name=${shelf_name} ${timestamp}
    ...                 blockId=${block_id}
    ...                 capacity=${SHELF_CAPACITY}
    
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
    [Arguments]         ${shelf_id}    ${rack_name}=TestRack
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${rack_data}=       Create Dictionary
    ...                 name=${rack_name} ${timestamp}
    ...                 shelfId=${shelf_id}
    ...                 capacity=${RACK_CAPACITY}
    
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

Create Product
    [Documentation]     Create a product with location assignment
    [Arguments]         ${product_data}
    
    FOR    ${key}    IN    name    warehouseId    blockId    shelfId    rackId    positionId
        Should Not Be Empty    ${product_data}[${key}]
        ...    msg=Missing or empty required parameter: ${key}
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
    Should Not Be Empty    ${json}
    
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
    Should Not Be Empty    ${json}
    
    RETURN            ${json}

Update Product Location
    [Documentation]     Update a product's location
    [Arguments]         ${product_id}    ${new_block_id}    ${new_shelf_id}    ${new_rack_id}    ${new_position_id}
    
    ${update_data}=     Create Dictionary
    ...                 id=${product_id}
    ...                 blockId=${new_block_id}
    ...                 shelfId=${new_shelf_id}
    ...                 rackId=${new_rack_id}
    ...                 positionId=${new_position_id}
    ...                 warehouseId=${WAREHOUSE_ID}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /products/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}

Update Block
    [Documentation]     Update an existing block’s details
    [Arguments]         ${block_id}    ${new_name}    ${new_capacity}
    
    ${update_data}=     Create Dictionary
    ...                 id=${block_id}
    ...                 name=${new_name}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 capacity=${new_capacity}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /blocks/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Be Equal     ${json}[name]    ${new_name}
    Should Be Equal As Integers    ${json}[capacity]    ${new_capacity}
    RETURN            ${json}

Delete Block
    [Documentation]     Delete a block from the warehouse
    [Arguments]         ${block_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /blocks/delete/${block_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    RETURN            ${TRUE}

Delete Shelf
    [Documentation]     Delete a shelf from the block
    [Arguments]         ${shelf_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /shelves/delete/${shelf_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    RETURN            ${TRUE}

Delete Rack
    [Documentation]     Delete a rack from the shelf
    [Arguments]         ${rack_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /racks/delete/${rack_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    RETURN            ${TRUE}

Generate Unique Product Data
    [Documentation]     Generate unique product data with location details
    [Arguments]         ${custom_name}=Test Product    ${quantity}=100
    
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
    ...                 positionId=${POSITION_ID}
    ...                 note=Test product with location
    
    RETURN            ${product_data}


Create Order With Product
    [Documentation]     Create an order linked to a product for picking
    [Arguments]         ${product_id}    ${quantity}=5
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${order_code}=      Set Variable     ORD${timestamp}
    
    ${item}=            Create Dictionary
    ...                 productId=${product_id}
    ...                 quantity=${quantity}
    ...                 price=75.00
    
    ${items}=           Create List    ${item}
    
    ${order_data}=      Create Dictionary
    ...                 orderCode=${order_code}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 customerName=Test Customer ${timestamp}
    ...                 customerPhone=1234567890
    ...                 customerAddress=123 Test St
    ...                 items=${items}
    ...                 totalAmount=${quantity * 75.00}
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

Pick Order With Relocation
    [Documentation]     Pick an order and relocate the product to a new location
    [Arguments]         ${order_id}    ${product_id}    ${new_block_id}    ${new_shelf_id}    ${new_rack_id}    ${new_position_id}
    
    ${pick_data}=       Create Dictionary
    ...                 orderId=${order_id}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 pickerId=1
    ...                 relocation=${EMPTY}
    
    ${relocation}=      Create Dictionary
    ...                 productId=${product_id}
    ...                 blockId=${new_block_id}
    ...                 shelfId=${new_shelf_id}
    ...                 rackId=${new_rack_id}
    ...                 positionId=${new_position_id}
    
    Set To Dictionary   ${pick_data}    relocation=${relocation}
    
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
01 - Setup Test Environment With Locations
    [Documentation]     Setup API session and create block, shelf, and rack
    [Tags]              setup
    
    Setup API Session
    
    ${block_id}=        Create Block
    ${shelf_id}=        Create Shelf    ${block_id}
    ${rack_id}=         Create Rack     ${shelf_id}
    
    Set Global Variable  ${BLOCK_ID}    ${block_id}
    Set Global Variable  ${SHELF_ID}    ${shelf_id}
    Set Global Variable  ${RACK_ID}     ${rack_id}
    
    Log                 Successfully set up Block:${BLOCK_ID}, Shelf:${SHELF_ID}, Rack:${RACK_ID}

02 - Create Product With Location Flow
    [Documentation]     Test creating a product and assigning it to a specific location
    [Tags]              create    location    positive
    
    ${product_data}=    Generate Unique Product Data
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    Should Not Be Empty    ${product_id}
    Assert Product Location    ${response}    ${BLOCK_ID}    ${SHELF_ID}    ${RACK_ID}    ${POSITION_ID}
    
    Set Global Variable  ${PRODUCT_ID}    ${product_id}
    Set Global Variable  ${TEST_PRODUCT_NAME}    ${response}[name]
    Log                 Successfully created product ${TEST_PRODUCT_NAME} at Block:${BLOCK_ID}, Shelf:${SHELF_ID}, Rack:${RACK_ID}, Position:${POSITION_ID}

03 - Rack Capacity Limit Test
    [Documentation]     Test exceeding rack capacity with multiple products
    [Tags]              capacity    rack    negative
    
    # Create first product filling half the rack capacity
    ${product_data1}=   Generate Unique Product Data    custom_name=Rack Capacity Product 1    quantity=${RACK_CAPACITY / 2}
    ${product_id1}    ${response1}=    Create Product    ${product_data1}
    
    # Create second product exceeding rack capacity
    ${product_data2}=   Generate Unique Product Data    custom_name=Rack Capacity Product 2    quantity=${RACK_CAPACITY}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data2}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    Log                 Successfully verified rack capacity limit enforcement

04 - Shelf Capacity Limit Test
    [Documentation]     Test exceeding shelf capacity with multiple racks
    [Tags]              capacity    shelf    negative
    
    # Create a second rack in the same shelf
    ${rack_id2}=        Create Rack    ${SHELF_ID}    rack_name=TestRack2
    
    # Fill first rack to capacity
    ${product_data1}=   Generate Unique Product Data    custom_name=Shelf Capacity Product 1    quantity=${RACK_CAPACITY}
    ${product_id1}    ${response1}=    Create Product    ${product_data1}
    
    # Attempt to place product in second rack exceeding shelf capacity
    ${product_data2}=   Generate Unique Product Data    custom_name=Shelf Capacity Product 2    quantity=${SHELF_CAPACITY - RACK_CAPACITY + 1}
    Set To Dictionary   ${product_data2}    rackId=${rack_id2}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data2}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    Log                 Successfully verified shelf capacity limit enforcement

05 - Independent Rack Management Test
    [Documentation]     Test creating and using a new rack independently
    [Tags]              rack    independent    positive
    
    ${new_rack_id}=     Create Rack    ${SHELF_ID}    rack_name=IndependentRack
    
    ${product_data}=    Generate Unique Product Data    custom_name=Independent Rack Product
    Set To Dictionary   ${product_data}    rackId=${new_rack_id}
    
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    Assert Product Location    ${response}    ${BLOCK_ID}    ${SHELF_ID}    ${new_rack_id}    ${POSITION_ID}
    
    Log                 Successfully created and used independent rack ${new_rack_id}

06 - Order Picking With Relocation Flow
    [Documentation]     Test picking an order and relocating the product to a new location
    [Tags]              order    relocation    positive
    
    Run Keyword If      "${PRODUCT_ID}" == "${EMPTY}"    Create Product With Location Flow
    
    # Create a second location for relocation
    ${new_block_id}=    Create Block    block_name=RelocationBlock
    ${new_shelf_id}=    Create Shelf    ${new_block_id}    shelf_name=RelocationShelf
    ${new_rack_id}=     Create Rack     ${new_shelf_id}    rack_name=RelocationRack
    
    # Create an order with the product
    ${order_id}    ${order_response}=    Create Order With Product    ${PRODUCT_ID}
    Set Global Variable  ${ORDER_ID}    ${order_id}
    
    # Pick the order and relocate the product
    ${pick_response}=    Pick Order With Relocation    ${ORDER_ID}    ${PRODUCT_ID}    ${new_block_id}    ${new_shelf_id}    ${new_rack_id}    ${POSITION_ID}
    
    # Verify product relocation
    ${updated_product}=    Get Product By ID    ${PRODUCT_ID}
    Assert Product Location    ${updated_product}    ${new_block_id}    ${new_shelf_id}    ${new_rack_id}    ${POSITION_ID}
    
    Log                 Successfully picked order ${ORDER_ID} and relocated product ${TEST_PRODUCT_NAME} to Block:${new_block_id}, Shelf:${new_shelf_id}, Rack:${new_rack_id}

07 - Relocation To Full Rack During Picking Test
    [Documentation]     Test relocating a product to a full rack during picking
    [Tags]              order    relocation    capacity    negative
    
    # Create a full rack
    ${full_block_id}=   Create Block    block_name=FullBlock
    ${full_shelf_id}=   Create Shelf    ${full_block_id}    shelf_name=FullShelf
    ${full_rack_id}=    Create Rack     ${full_shelf_id}    rack_name=FullRack
    
    ${product_data1}=   Generate Unique Product Data    custom_name=Full Rack Product    quantity=${RACK_CAPACITY}
    Set To Dictionary   ${product_data1}    blockId=${full_block_id}    shelfId=${full_shelf_id}    rackId=${full_rack_id}
    ${full_product_id}    ${response1}=    Create Product    ${product_data1}
    
    # Create a product and order to relocate
    Run Keyword If      "${PRODUCT_ID}" == "${EMPTY}"    Create Product With Location Flow
    ${order_id}    ${order_response}=    Create Order With Product    ${PRODUCT_ID}
    
    # Attempt to relocate to full rack
    ${pick_data}=       Create Dictionary
    ...                 orderId=${order_id}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 pickerId=1
    ...                 relocation=${EMPTY}
    
    ${relocation}=      Create Dictionary
    ...                 productId=${PRODUCT_ID}
    ...                 blockId=${full_block_id}
    ...                 shelfId=${full_shelf_id}
    ...                 rackId=${full_rack_id}
    ...                 positionId=${POSITION_ID}
    
    Set To Dictionary   ${pick_data}    relocation=${relocation}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /orders/pick
    ...                 json=${pick_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that relocation to a full rack during picking fails
08 - Block Capacity Limit Test
    [Documentation]     Test exceeding block capacity with multiple shelves
    [Tags]              capacity    block    negative
    
    ${block_id}=        Create Block    block_name=CapacityBlock    capacity=${BLOCK_CAPACITY}
    ${shelf_id1}=       Create Shelf    ${block_id}    shelf_name=Shelf1
    ${rack_id1}=        Create Rack     ${shelf_id1}    rack_name=Rack1
    
    ${product_data1}=   Generate Unique Product Data    custom_name=Block Capacity Product 1    quantity=${SHELF_CAPACITY}
    Set To Dictionary   ${product_data1}    blockId=${block_id}    shelfId=${shelf_id1}    rackId=${rack_id1}
    ${product_id1}    ${response1}=    Create Product    ${product_data1}
    
    ${shelf_id2}=       Create Shelf    ${block_id}    shelf_name=Shelf2
    ${rack_id2}=        Create Rack     ${shelf_id2}    rack_name=Rack2
    
    ${product_data2}=   Generate Unique Product Data    custom_name=Block Capacity Product 2    quantity=${BLOCK_CAPACITY - SHELF_CAPACITY + 1}
    Set To Dictionary   ${product_data2}    blockId=${block_id}    shelfId=${shelf_id2}    rackId=${rack_id2}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data2}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    Log                 Successfully verified block capacity limit enforcement

09 - Update Block Details Test
    [Documentation]     Test updating a block’s name and capacity
    [Tags]              block    update    positive
    
    ${block_id}=        Create Block    block_name=UpdatableBlock
    ${new_name}=        Set Variable    UpdatedBlockName
    ${new_capacity}=    Set Variable    300
    
    ${updated_block}=   Update Block    ${block_id}    ${new_name}    ${new_capacity}
    
    Should Be Equal     ${updated_block}[name]    ${new_name}
    Should Be Equal As Integers    ${updated_block}[capacity]    ${new_capacity}
    
    Log                 Successfully updated block ${block_id} to name:${new_name} and capacity:${new_capacity}

10 - Delete Shelf Test
    [Documentation]     Test deleting a shelf and ensuring products are handled
    [Tags]              shelf    delete    positive
    
    ${block_id}=        Create Block    block_name=DeleteTestBlock
    ${shelf_id}=        Create Shelf    ${block_id}    shelf_name=DeleteTestShelf
    ${rack_id}=         Create Rack     ${shelf_id}    rack_name=DeleteTestRack
    
    ${product_data}=    Generate Unique Product Data    custom_name=Delete Shelf Product
    Set To Dictionary   ${product_data}    blockId=${block_id}    shelfId=${shelf_id}    rackId=${rack_id}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    ${delete_result}=   Delete Shelf    ${shelf_id}
    Should Be True      ${delete_result}
    
    # Verify product is no longer associated with deleted shelf (assuming API handles this)
    ${updated_product}=    Get Product By ID    ${product_id}
    ${has_shelf}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${updated_product}    shelfId
    Run Keyword If      ${has_shelf}    Should Not Be Equal    ${updated_product}[shelfId]    ${shelf_id}
    ...    ELSE         Log    Product shelfId removed as expected
    
    Log                 Successfully deleted shelf ${shelf_id} and verified product handling

11 - Concurrent Picking and Relocation Test
    [Documentation]     Test concurrent picking and relocation of the same product
    [Tags]              order    relocation    concurrent    positive
    
    Run Keyword If      "${PRODUCT_ID}" == "${EMPTY}"    Create Product With Location Flow
    
    # Create two orders for the same product
    ${order_id1}    ${order_response1}=    Create Order With Product    ${PRODUCT_ID}    quantity=2
    ${order_id2}    ${order_response2}=    Create Order With Product    ${PRODUCT_ID}    quantity=2
    
    # Create two new locations for relocation
    ${block_id1}=       Create Block    block_name=ConcurrentBlock1
    ${shelf_id1}=       Create Shelf    ${block_id1}    shelf_name=ConcurrentShelf1
    ${rack_id1}=        Create Rack     ${shelf_id1}    rack_name=ConcurrentRack1
    
    ${block_id2}=       Create Block    block_name=ConcurrentBlock2
    ${shelf_id2}=       Create Shelf    ${block_id2}    shelf_name=ConcurrentShelf2
    ${rack_id2}=        Create Rack     ${shelf_id2}    rack_name=ConcurrentRack2
    
    # Simulate concurrent picking (sequential here due to Robot limitations, but assumes API handles concurrency)
    ${pick_response1}=    Pick Order With Relocation    ${order_id1}    ${PRODUCT_ID}    ${block_id1}    ${shelf_id1}    ${rack_id1}    ${POSITION_ID}
    ${pick_response2}=    Pick Order With Relocation    ${order_id2}    ${PRODUCT_ID}    ${block_id2}    ${shelf_id2}    ${rack_id2}    ${POSITION_ID}
    
    # Verify final product location (should reflect last relocation due to sequential execution)
    ${updated_product}=    Get Product By ID    ${PRODUCT_ID}
    Assert Product Location    ${updated_product}    ${block_id2}    ${shelf_id2}    ${rack_id2}    ${POSITION_ID}
    
    Log                 Successfully handled concurrent picking and relocation for product ${TEST_PRODUCT_NAME}

12 - Delete Rack With Products Test
    [Documentation]     Test deleting a rack containing products
    [Tags]              rack    delete    negative
    
    ${block_id}=        Create Block    block_name=RackDeleteBlock
    ${shelf_id}=        Create Shelf    ${block_id}    shelf_name=RackDeleteShelf
    ${rack_id}=         Create Rack     ${shelf_id}    rack_name=RackDeleteRack
    
    ${product_data}=    Generate Unique Product Data    custom_name=Rack Delete Product
    Set To Dictionary   ${product_data}    blockId=${block_id}    shelfId=${shelf_id}    rackId=${rack_id}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect failure due to products present (assuming API enforces this)
    Run Keyword And Expect Error    *
    ...                 DELETE On Session
    ...                 vkho
    ...                 /racks/delete/${rack_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that deleting a rack with products fails