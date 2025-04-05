*** Settings ***
Documentation     Comprehensive Test Suite for Product Management with Shelf/Rack Moves, Position Updates, and Zone Deletion
...               Includes moving shelves/racks, updating positions, and deleting zones with blocks
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

Delete Zone
    [Documentation]     Delete a zone from the warehouse
    [Arguments]         ${zone_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /zones/delete/${zone_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    RETURN            ${TRUE}

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

Move Shelf To Block
    [Documentation]     Move a shelf to a different block
    [Arguments]         ${shelf_id}    ${new_block_id}
    
    ${move_data}=       Create Dictionary
    ...                 id=${shelf_id}
    ...                 blockId=${new_block_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /shelves/update
    ...                 json=${move_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Be Equal As Integers    ${json}[blockId]    ${new_block_id}
    RETURN            ${json}

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

Move Rack To Shelf
    [Documentation]     Move a rack to a different shelf
    [Arguments]         ${rack_id}    ${new_shelf_id}
    
    ${move_data}=       Create Dictionary
    ...                 id=${rack_id}
    ...                 shelfId=${new_shelf_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /racks/update
    ...                 json=${move_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Be Equal As Integers    ${json}[shelfId]    ${new_shelf_id}
    RETURN            ${json}

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

Update Position
    [Documentation]     Update a position’s number or capacity
    [Arguments]         ${position_id}    ${new_position_number}    ${new_capacity}
    
    ${update_data}=     Create Dictionary
    ...                 id=${position_id}
    ...                 rackId=${RACK_ID}
    ...                 positionNumber=${new_position_number}
    ...                 capacity=${new_capacity}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /positions/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Be Equal As Integers    ${json}[positionNumber]    ${new_position_number}
    Should Be Equal As Integers    ${json}[capacity]    ${new_capacity}
    RETURN            ${json}

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

02 - Move Shelf Between Blocks Test
    [Documentation]     Test moving a shelf from one block to another
    [Tags]              shelf    block    move    positive
    
    ${source_block_id}= Create Block    ${ZONE_ID}    block_name=SourceBlock
    ${shelf_id}=        Create Shelf    ${source_block_id}    shelf_name=MovableShelf
    ${rack_id}=         Create Rack     ${shelf_id}
    ${position_id}=     Create Position    ${rack_id}    position_number=1
    
    ${product_data}=    Generate Unique Product Data    custom_name=Shelf Move Product    position_id=${position_id}
    Set To Dictionary   ${product_data}    blockId=${source_block_id}    shelfId=${shelf_id}    rackId=${rack_id}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    ${target_block_id}= Create Block    ${ZONE_ID}    block_name=TargetBlock
    ${moved_shelf}=     Move Shelf To Block    ${shelf_id}    ${target_block_id}
    
    ${updated_product}=    Get Product By ID    ${product_id}
    Should Be Equal As Integers    ${updated_product}[shelfId]    ${shelf_id}
    Should Be Equal As Integers    ${moved_shelf}[blockId]    ${target_block_id}
    
    Log                 Successfully moved shelf ${shelf_id} from block ${source_block_id} to ${target_block_id}

03 - Move Rack Between Shelves Test
    [Documentation]     Test moving a rack from one shelf to another
    [Tags]              rack    shelf    move    positive
    
    ${source_shelf_id}= Create Shelf    ${BLOCK_ID}    shelf_name=SourceShelf
    ${rack_id}=         Create Rack     ${source_shelf_id}    rack_name=MovableRack
    ${position_id}=     Create Position    ${rack_id}    position_number=1
    
    ${product_data}=    Generate Unique Product Data    custom_name=Rack Move Product    position_id=${position_id}
    Set To Dictionary   ${product_data}    shelfId=${source_shelf_id}    rackId=${rack_id}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    ${target_shelf_id}= Create Shelf    ${BLOCK_ID}    shelf_name=TargetShelf
    ${moved_rack}=      Move Rack To Shelf    ${rack_id}    ${target_shelf_id}
    
    ${updated_product}=    Get Product By ID    ${product_id}
    Should Be Equal As Integers    ${updated_product}[rackId]    ${rack_id}
    Should Be Equal As Integers    ${moved_rack}[shelfId]    ${target_shelf_id}
    
    Log                 Successfully moved rack ${rack_id} from shelf ${source_shelf_id} to ${target_shelf_id}

04 - Move Shelf To Full Block Test
    [Documentation]     Test moving a shelf to a block that exceeds capacity
    [Tags]              shelf    block    move    capacity    negative
    
    ${source_block_id}= Create Block    ${ZONE_ID}    block_name=SourceFullBlock
    ${shelf_id}=        Create Shelf    ${source_block_id}    shelf_name=FullMoveShelf
    ${rack_id}=         Create Rack     ${shelf_id}
    ${position_id}=     Create Position    ${rack_id}    position_number=1
    
    ${product_data}=    Generate Unique Product Data    custom_name=Full Shelf Product    quantity=${SHELF_CAPACITY}    position_id=${position_id}
    Set To Dictionary   ${product_data}    blockId=${source_block_id}    shelfId=${shelf_id}    rackId=${rack_id}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    ${target_block_id}= Create Block    ${ZONE_ID}    block_name=TargetFullBlock    capacity=${BLOCK_CAPACITY}
    ${filler_shelf}=    Create Shelf    ${target_block_id}    shelf_name=FillerShelf
    ${filler_rack}=     Create Rack     ${filler_shelf}
    ${filler_position}= Create Position    ${filler_rack}    position_number=1
    
    ${filler_product}=  Generate Unique Product Data    custom_name=Filler Product    quantity=${BLOCK_CAPACITY - SHELF_CAPACITY + 1}    position_id=${filler_position}
    Set To Dictionary   ${filler_product}    blockId=${target_block_id}    shelfId=${filler_shelf}    rackId=${filler_rack}
    ${filler_id}    ${filler_response}=    Create Product    ${filler_product}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${move_data}=       Create Dictionary    id=${shelf_id}    blockId=${target_block_id}
    
    Run Keyword And Expect Error    *
    ...                 PUT On Session
    ...                 vkho
    ...                 /shelves/update
    ...                 json=${move_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${updated_product}=    Get Product By ID    ${product_id}
    Should Be Equal As Integers    ${updated_product}[blockId]    ${source_block_id}
    Log                 Successfully verified shelf ${shelf_id} remains in ${source_block_id} due to target block capacity

05 - Update Position Capacity Test
    [Documentation]     Test updating a position’s capacity
    [Tags]              position    update    positive
    
    ${position_id}=     Create Position    ${RACK_ID}    position_number=1
    ${product_data}=    Generate Unique Product Data    custom_name=Position Capacity Product    quantity=10    position_id=${position_id}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    ${new_capacity}=    Set Variable    30
    ${updated_position}=    Update Position    ${position_id}    1    ${new_capacity}
    
    ${updated_product}=    Get Product By ID    ${product_id}
    Assert Product Location    ${updated_product}    ${BLOCK_ID}    ${SHELF_ID}    ${RACK_ID}    ${position_id}
    
    Log                 Successfully updated position ${position_id} capacity to ${new_capacity}

06 - Update Position Number Test
    [Documentation]     Test updating a position’s number with uniqueness validation
    [Tags]              position    update    positive
    
    ${position_id1}=    Create Position    ${RACK_ID}    position_number=2
    ${position_id2}=    Create Position    ${RACK_ID}    position_number=3
    
    ${product_data}=    Generate Unique Product Data    custom_name=Position Number Product    position_id=${position_id1}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    ${new_number}=      Set Variable    4
    ${updated_position}=    Update Position    ${position_id1}    ${new_number}    ${POSITION_CAPACITY}
    
    ${updated_product}=    Get Product By ID    ${product_id}
    Assert Product Location    ${updated_product}    ${BLOCK_ID}    ${SHELF_ID}    ${RACK_ID}    ${position_id1}
    
    # Attempt to update to a duplicate number
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${update_data}=     Create Dictionary    id=${position_id1}    rackId=${RACK_ID}    positionNumber=3    capacity=${POSITION_CAPACITY}
    
    Run Keyword And Expect Error    *
    ...                 PUT On Session
    ...                 vkho
    ...                 /positions/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully updated position ${position_id1} number to ${new_number} and verified uniqueness

07 - Delete Zone With Blocks Test
    [Documentation]     Test deleting a zone containing blocks
    [Tags]              zone    delete    negative
    
    ${zone_id}=         Create Zone    zone_name=DeleteZone
    ${block_id}=        Create Block    ${zone_id}    block_name=DeleteBlock
    ${shelf_id}=        Create Shelf    ${block_id}
    ${rack_id}=         Create Rack     ${shelf_id}
    ${position_id}=     Create Position    ${rack_id}    position_number=1
    
    ${product_data}=    Generate Unique Product Data    custom_name=Zone Delete Product    position_id=${position_id}
    Set To Dictionary   ${product_data}    blockId=${block_id}    shelfId=${shelf_id}    rackId=${rack_id}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    Run Keyword And Expect Error    *
    ...                 DELETE On Session
    ...                 vkho
    ...                 /zones/delete/${zone_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${updated_product}=    Get Product By ID    ${product_id}
    Should Be Equal As Integers    ${updated_product}[blockId]    ${block_id}
    
    Log                 Successfully verified that zone ${zone_id} with block ${block_id} cannot be deleted