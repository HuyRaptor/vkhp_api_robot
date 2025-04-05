*** Settings ***
Documentation     Advanced Test Suite for Product Management with Position Moves, Rollback Tests, and Bin Interactions
...               Includes moving positions between racks, rollback for failed shelf/rack moves, and bins within positions
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

Move Position To Rack
    [Documentation]     Move a position to a different rack
    [Arguments]         ${position_id}    ${new_rack_id}
    
    ${move_data}=       Create Dictionary
    ...                 id=${position_id}
    ...                 rackId=${new_rack_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /positions/update
    ...                 json=${move_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Be Equal As Integers    ${json}[rackId]    ${new_rack_id}
    RETURN            ${json}

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

02 - Move Position Between Racks Test
    [Documentation]     Test moving a position from one rack to another
    [Tags]              position    rack    move    positive
    
    ${source_rack_id}=  Create Rack    ${SHELF_ID}    rack_name=SourceRack
    ${position_id}=     Create Position    ${source_rack_id}    position_number=1
    ${bin_id}=          Create Bin    ${position_id}
    
    ${product_data}=    Generate Unique Product Data    custom_name=Position Move Product    position_id=${position_id}    bin_id=${bin_id}
    Set To Dictionary   ${product_data}    rackId=${source_rack_id}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    ${target_rack_id}=  Create Rack    ${SHELF_ID}    rack_name=TargetRack
    ${moved_position}=  Move Position To Rack    ${position_id}    ${target_rack_id}
    
    ${updated_product}=    Get Product By ID    ${product_id}
    Assert Product Location    ${updated_product}    ${BLOCK_ID}    ${SHELF_ID}    ${target_rack_id}    ${position_id}    ${bin_id}
    
    Log                 Successfully moved position ${position_id} from rack ${source_rack_id} to ${target_rack_id}

03 - Move Position To Full Rack Test
    [Documentation]     Test moving a position to a rack that exceeds capacity
    [Tags]              position    rack    move    capacity    negative
    
    ${source_rack_id}=  Create Rack    ${SHELF_ID}    rack_name=SourceFullRack
    ${position_id}=     Create Position    ${source_rack_id}    position_number=1
    ${bin_id}=          Create Bin    ${position_id}
    
    ${product_data}=    Generate Unique Product Data    custom_name=Full Position Product    quantity=${POSITION_CAPACITY}    position_id=${position_id}    bin_id=${bin_id}
    Set To Dictionary   ${product_data}    rackId=${source_rack_id}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    ${target_rack_id}=  Create Rack    ${SHELF_ID}    rack_name=TargetFullRack    capacity=${RACK_CAPACITY}
    ${filler_position}= Create Position    ${target_rack_id}    position_number=1
    ${filler_bin}=      Create Bin    ${filler_position}
    
    ${filler_product}=  Generate Unique Product Data    custom_name=Filler Product    quantity=${RACK_CAPACITY - POSITION_CAPACITY + 1}    position_id=${filler_position}    bin_id=${filler_bin}
    Set To Dictionary   ${filler_product}    rackId=${target_rack_id}
    ${filler_id}    ${filler_response}=    Create Product    ${filler_product}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${move_data}=       Create Dictionary    id=${position_id}    rackId=${target_rack_id}
    
    Run Keyword And Expect Error    *
    ...                 PUT On Session
    ...                 vkho
    ...                 /positions/update
    ...                 json=${move_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${updated_product}=    Get Product By ID    ${product_id}
    Assert Product Location    ${updated_product}    ${BLOCK_ID}    ${SHELF_ID}    ${source_rack_id}    ${position_id}    ${bin_id}
    Log                 Successfully verified position ${position_id} remains in ${source_rack_id} due to target rack capacity

04 - Shelf Move Rollback Test
    [Documentation]     Test rollback when moving a shelf to a full block fails
    [Tags]              shelf    block    move    rollback    negative
    
    ${source_block_id}= Create Block    ${ZONE_ID}    block_name=SourceRollbackBlock
    ${shelf_id}=        Create Shelf    ${source_block_id}    shelf_name=RollbackShelf
    ${rack_id}=         Create Rack     ${shelf_id}
    ${position_id}=     Create Position    ${rack_id}    position_number=1
    ${bin_id}=          Create Bin    ${position_id}
    
    ${product_data}=    Generate Unique Product Data    custom_name=Shelf Rollback Product    quantity=${SHELF_CAPACITY}    position_id=${position_id}    bin_id=${bin_id}
    Set To Dictionary   ${product_data}    blockId=${source_block_id}    shelfId=${shelf_id}    rackId=${rack_id}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    ${target_block_id}= Create Block    ${ZONE_ID}    block_name=TargetRollbackBlock    capacity=${BLOCK_CAPACITY}
    ${filler_shelf}=    Create Shelf    ${target_block_id}
    ${filler_rack}=     Create Rack     ${filler_shelf}
    ${filler_position}= Create Position    ${filler_rack}    position_number=1
    ${filler_bin}=      Create Bin    ${filler_position}
    
    ${filler_product}=  Generate Unique Product Data    custom_name=Filler Product    quantity=${BLOCK_CAPACITY - SHELF_CAPACITY + 1}    position_id=${filler_position}    bin_id=${filler_bin}
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
    Assert Product Location    ${updated_product}    ${source_block_id}    ${shelf_id}    ${rack_id}    ${position_id}    ${bin_id}
    Log                 Successfully verified rollback for shelf ${shelf_id} move to full block ${target_block_id}

05 - Rack Move Rollback Test
    [Documentation]     Test rollback when moving a rack to a full shelf fails
    [Tags]              rack    shelf    move    rollback    negative
    
    ${source_shelf_id}= Create Shelf    ${BLOCK_ID}    shelf_name=SourceRollbackShelf
    ${rack_id}=         Create Rack     ${source_shelf_id}    rack_name=RollbackRack
    ${position_id}=     Create Position    ${rack_id}    position_number=1
    ${bin_id}=          Create Bin    ${position_id}
    
    ${product_data}=    Generate Unique Product Data    custom_name=Rack Rollback Product    quantity=${RACK_CAPACITY}    position_id=${position_id}    bin_id=${bin_id}
    Set To Dictionary   ${product_data}    shelfId=${source_shelf_id}    rackId=${rack_id}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    ${target_shelf_id}= Create Shelf    ${BLOCK_ID}    shelf_name=TargetRollbackShelf    capacity=${SHELF_CAPACITY}
    ${filler_rack}=     Create Rack     ${target_shelf_id}
    ${filler_position}= Create Position    ${filler_rack}    position_number=1
    ${filler_bin}=      Create Bin    ${filler_position}
    
    ${filler_product}=  Generate Unique Product Data    custom_name=Filler Product    quantity=${SHELF_CAPACITY - RACK_CAPACITY + 1}    position_id=${filler_position}    bin_id=${filler_bin}
    Set To Dictionary   ${filler_product}    shelfId=${target_shelf_id}    rackId=${filler_rack}
    ${filler_id}    ${filler_response}=    Create Product    ${filler_product}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${move_data}=       Create Dictionary    id=${rack_id}    shelfId=${target_shelf_id}
    
    Run Keyword And Expect Error    *
    ...                 PUT On Session
    ...                 vkho
    ...                 /racks/update
    ...                 json=${move_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${updated_product}=    Get Product By ID    ${product_id}
    Assert Product Location    ${updated_product}    ${BLOCK_ID}    ${source_shelf_id}    ${rack_id}    ${position_id}    ${bin_id}
    Log                 Successfully verified rollback for rack ${rack_id} move to full shelf ${target_shelf_id}

06 - Bin Within Position Test
    [Documentation]     Test creating and using a bin within a position
    [Tags]              bin    position    positive
    
    ${position_id}=     Create Position    ${RACK_ID}    position_number=1
    ${bin_id}=          Create Bin    ${position_id}
    
    ${product_data}=    Generate Unique Product Data    custom_name=Bin Product    position_id=${position_id}    bin_id=${bin_id}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    ${updated_product}=    Get Product By ID    ${product_id}
    Assert Product Location    ${updated_product}    ${BLOCK_ID}    ${SHELF_ID}    ${RACK_ID}    ${position_id}    ${bin_id}
    
    Log                 Successfully created bin ${bin_id} in position ${position_id} and assigned product ${product_id}

07 - Bin Capacity Limit Test
    [Documentation]     Test exceeding bin capacity with a product
    [Tags]              bin    capacity    negative
    
    ${position_id}=     Create Position    ${RACK_ID}    position_number=2
    ${bin_id}=          Create Bin    ${position_id}
    
    ${product_data1}=   Generate Unique Product Data    custom_name=Bin Capacity Product 1    quantity=${BIN_CAPACITY - 1}    position_id=${position_id}    bin_id=${bin_id}
    ${product_id1}    ${response1}=    Create Product    ${product_data1}
    
    ${product_data2}=   Generate Unique Product Data    custom_name=Bin Capacity Product 2    quantity=2    position_id=${position_id}    bin_id=${bin_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data2}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${updated_product}=    Get Product By ID    ${product_id1}
    Assert Product Location    ${updated_product}    ${BLOCK_ID}    ${SHELF_ID}    ${RACK_ID}    ${position_id}    ${bin_id}
    Log                 Successfully verified bin ${bin_id} capacity limit enforcement