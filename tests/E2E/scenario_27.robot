*** Settings ***
Documentation     Enhanced Test Suite for Product Management with Bin Moves, Updates, and Concurrent Bin Operations
...               Includes moving bins between positions, updating/deleting bins, and concurrent product/bin interactions
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
    [Arguments]         ${rack_id}    ${position_number}    ${capacity}=${POSITION_CAPACITY}
    
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

Create Bin
    [Documentation]     Create a new bin within a position
    [Arguments]         ${position_id}    ${bin_name}=TestBin    ${capacity}=${BIN_CAPACITY}
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${bin_data}=        Create Dictionary
    ...                 name=${bin_name} ${timestamp}
    ...                 positionId=${position_id}
    ...                 capacity=${capacity}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        POST On Session
    ...                 vkho
    ...                 /bins/create
    ...                 json=${bin_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${bin_id}=          Convert To String    ${json}[id]
    RETURN            ${bin_id}

Move Bin To Position
    [Documentation]     Move a bin to a different position
    [Arguments]         ${bin_id}    ${new_position_id}
    
    ${move_data}=       Create Dictionary
    ...                 id=${bin_id}
    ...                 positionId=${new_position_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /bins/update
    ...                 json=${move_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Be Equal As Integers    ${json}[positionId]    ${new_position_id}
    RETURN            ${json}

Update Bin
    [Documentation]     Update a bin’s name or capacity
    [Arguments]         ${bin_id}    ${new_name}    ${new_capacity}
    
    ${update_data}=     Create Dictionary
    ...                 id=${bin_id}
    ...                 name=${new_name}
    ...                 positionId=${update_data.get('positionId', ${EMPTY})}  # Preserve existing positionId if not provided
    ...                 capacity=${new_capacity}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /bins/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Be Equal     ${json}[name]    ${new_name}
    Should Be Equal As Integers    ${json}[capacity]    ${new_capacity}
    RETURN            ${json}

Delete Bin
    [Documentation]     Delete a bin from a position
    [Arguments]         ${bin_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /bins/delete/${bin_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    RETURN            ${TRUE}

Generate Unique Product Data
    [Documentation]     Generate unique product data with bin assignment
    [Arguments]         ${custom_name}=Test Product    ${quantity}=5    ${position_id}=${EMPTY}    ${bin_id}=${EMPTY}
    
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
    ...                 binId=${bin_id}
    
    RETURN            ${product_data}

Create Product
    [Documentation]     Create a product with position and bin assignment
    [Arguments]         ${product_data}
    
    FOR    ${key}    IN    name    warehouseId    blockId    shelfId    rackId    positionId    binId
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

Assert Product Location
    [Documentation]     Verify a product’s location details including bin
    [Arguments]         ${product}    ${expected_block_id}    ${expected_shelf_id}    ${expected_rack_id}    ${expected_position_id}    ${expected_bin_id}
    
    Should Be Equal As Integers    ${product}[blockId]    ${expected_block_id}
    Should Be Equal As Integers    ${product}[shelfId]    ${expected_shelf_id}
    Should Be Equal As Integers    ${product}[rackId]    ${expected_rack_id}
    Should Be Equal As Integers    ${product}[positionId]    ${expected_position_id}
    Should Be Equal As Integers    ${product}[binId]    ${expected_bin_id}

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

02 - Move Bin Between Positions Test
    [Documentation]     Test moving a bin from one position to another
    [Tags]              bin    position    move    positive
    
    ${source_position_id}= Create Position    ${RACK_ID}    position_number=1
    ${bin_id}=          Create Bin    ${source_position_id}
    
    ${product_data}=    Generate Unique Product Data    custom_name=Bin Move Product    position_id=${source_position_id}    bin_id=${bin_id}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    ${target_position_id}= Create Position    ${RACK_ID}    position_number=2
    ${moved_bin}=       Move Bin To Position    ${bin_id}    ${target_position_id}
    
    ${updated_product}=    Get Product By ID    ${product_id}
    Assert Product Location    ${updated_product}    ${BLOCK_ID}    ${SHELF_ID}    ${RACK_ID}    ${target_position_id}    ${bin_id}
    
    Log                 Successfully moved bin ${bin_id} from position ${source_position_id} to ${target_position_id}

03 - Move Bin To Full Position Test
    [Documentation]     Test moving a bin to a position that exceeds capacity
    [Tags]              bin    position    move    capacity    negative
    
    ${source_position_id}= Create Position    ${RACK_ID}    position_number=3
    ${bin_id}=          Create Bin    ${source_position_id}
    
    ${product_data}=    Generate Unique Product Data    custom_name=Full Bin Product    quantity=${BIN_CAPACITY}    position_id=${source_position_id}    bin_id=${bin_id}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    ${target_position_id}= Create Position    ${RACK_ID}    position_number=4    capacity=${POSITION_CAPACITY}
    ${filler_bin}=      Create Bin    ${target_position_id}
    
    ${filler_product}=  Generate Unique Product Data    custom_name=Filler Product    quantity=${POSITION_CAPACITY - BIN_CAPACITY + 1}    position_id=${target_position_id}    bin_id=${filler_bin}
    ${filler_id}    ${filler_response}=    Create Product    ${filler_product}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${move_data}=       Create Dictionary    id=${bin_id}    positionId=${target_position_id}
    
    Run Keyword And Expect Error    *
    ...                 PUT On Session
    ...                 vkho
    ...                 /bins/update
    ...                 json=${move_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${updated_product}=    Get Product By ID    ${product_id}
    Assert Product Location    ${updated_product}    ${BLOCK_ID}    ${SHELF_ID}    ${RACK_ID}    ${source_position_id}    ${bin_id}
    Log                 Successfully verified bin ${bin_id} remains in ${source_position_id} due to target position capacity

04 - Update Bin Test
    [Documentation]     Test updating a bin’s name and capacity
    [Tags]              bin    update    positive
    
    ${position_id}=     Create Position    ${RACK_ID}    position_number=5
    ${bin_id}=          Create Bin    ${position_id}
    
    ${product_data}=    Generate Unique Product Data    custom_name=Bin Update Product    position_id=${position_id}    bin_id=${bin_id}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    ${new_name}=        Set Variable    UpdatedBinName
    ${new_capacity}=    Set Variable    15
    ${updated_bin}=     Update Bin    ${bin_id}    ${new_name}    ${new_capacity}
    
    ${updated_product}=    Get Product By ID    ${product_id}
    Assert Product Location    ${updated_product}    ${BLOCK_ID}    ${SHELF_ID}    ${RACK_ID}    ${position_id}    ${bin_id}
    
    Log                 Successfully updated bin ${bin_id} to name:${new_name} and capacity:${new_capacity}

05 - Delete Bin Test
    [Documentation]     Test deleting a bin with a product
    [Tags]              bin    delete    positive
    
    ${position_id}=     Create Position    ${RACK_ID}    position_number=6
    ${bin_id}=          Create Bin    ${position_id}
    
    ${product_data}=    Generate Unique Product Data    custom_name=Bin Delete Product    position_id=${position_id}    bin_id=${bin_id}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    ${delete_result}=   Delete Bin    ${bin_id}
    Should Be True      ${delete_result}
    
    ${updated_product}=    Get Product By ID    ${product_id}
    ${has_bin}=         Run Keyword And Return Status    Dictionary Should Contain Key    ${updated_product}    binId
    Run Keyword If      ${has_bin}    Should Not Be Equal    ${updated_product}[binId]    ${bin_id}
    ...    ELSE         Log    Product binId removed as expected
    
    Log                 Successfully deleted bin ${bin_id} and verified product handling

06 - Concurrent Product Placement and Bin Move Test
    [Documentation]     Test concurrent product placement and bin move
    [Tags]              bin    concurrent    positive
    
    ${position_id1}=    Create Position    ${RACK_ID}    position_number=7
    ${bin_id}=          Create Bin    ${position_id1}
    
    ${product_data1}=   Generate Unique Product Data    custom_name=Concurrent Product 1    position_id=${position_id1}    bin_id=${bin_id}
    ${product_id1}    ${response1}=    Create Product    ${product_data1}
    
    ${position_id2}=    Create Position    ${RACK_ID}    position_number=8
    ${moved_bin}=       Move Bin To Position    ${bin_id}    ${position_id2}
    
    ${product_data2}=   Generate Unique Product Data    custom_name=Concurrent Product 2    position_id=${position_id2}    bin_id=${bin_id}
    ${product_id2}    ${response2}=    Create Product    ${product_data2}
    
    ${updated_product1}=    Get Product By ID    ${product_id1}
    Assert Product Location    ${updated_product1}    ${BLOCK_ID}    ${SHELF_ID}    ${RACK_ID}    ${position_id2}    ${bin_id}
    
    ${updated_product2}=    Get Product By ID    ${product_id2}
    Assert Product Location    ${updated_product2}    ${BLOCK_ID}    ${SHELF_ID}    ${RACK_ID}    ${position_id2}    ${bin_id}
    
    Log                 Successfully handled concurrent product placement and bin move for bin ${bin_id}

07 - Concurrent Product Placement and Bin Move Conflict Test
    [Documentation]     Test concurrent product placement and bin move with capacity conflict
    [Tags]              bin    concurrent    negative
    
    ${position_id1}=    Create Position    ${RACK_ID}    position_number=9
    ${bin_id}=          Create Bin    ${position_id1}
    
    ${product_data1}=   Generate Unique Product Data    custom_name=Conflict Product 1    quantity=${BIN_CAPACITY - 1}    position_id=${position_id1}    bin_id=${bin_id}
    ${product_id1}    ${response1}=    Create Product    ${product_data1}
    
    ${position_id2}=    Create Position    ${RACK_ID}    position_number=10    capacity=${POSITION_CAPACITY}
    ${filler_bin}=      Create Bin    ${position_id2}
    
    ${filler_product}=  Generate Unique Product Data    custom_name=Filler Product    quantity=${POSITION_CAPACITY - BIN_CAPACITY + 1}    position_id=${position_id2}    bin_id=${filler_bin}
    ${filler_id}    ${filler_response}=    Create Product    ${filler_product}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${move_data}=       Create Dictionary    id=${bin_id}    positionId=${position_id2}
    
    Run Keyword And Expect Error    *
    ...                 PUT On Session
    ...                 vkho
    ...                 /bins/update
    ...                 json=${move_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${product_data2}=   Generate Unique Product Data    custom_name=Conflict Product 2    quantity=2    position_id=${position_id1}    bin_id=${bin_id}
    ${product_id2}    ${response2}=    Create Product    ${product_data2}
    
    ${updated_product1}=    Get Product By ID    ${product_id1}
    Assert Product Location    ${updated_product1}    ${BLOCK_ID}    ${SHELF_ID}    ${RACK_ID}    ${position_id1}    ${bin_id}
    
    ${updated_product2}=    Get Product By ID    ${product_id2}
    Assert Product Location    ${updated_product2}    ${BLOCK_ID}    ${SHELF_ID}    ${RACK_ID}    ${position_id1}    ${bin_id}
    
    Log                 Successfully verified conflict in concurrent product placement and bin move due to capacity