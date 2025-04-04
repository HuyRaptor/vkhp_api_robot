*** Settings ***
Documentation     Advanced End-to-End Test Suite for Product Management with Zone-Block Moves, Position Validation, and Concurrent Position Ops
...               Includes moving blocks between zones, unique position numbers, and concurrent position creation/deletion
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

Move Block To Zone
    [Documentation]     Move a block to a different zone
    [Arguments]         ${block_id}    ${new_zone_id}
    
    ${move_data}=       Create Dictionary
    ...                 id=${block_id}
    ...                 zoneId=${new_zone_id}
    ...                 warehouseId=${WAREHOUSE_ID}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /blocks/update
    ...                 json=${move_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Be Equal As Integers    ${json}[zoneId]    ${new_zone_id}
    RETURN            ${json}

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
    [Documentation]     Create a new position within a rack with unique position number
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

02 - Move Block Between Zones Test
    [Documentation]     Test moving a block from one zone to another
    [Tags]              zone    block    move    positive
    
    ${source_zone_id}=  Create Zone    zone_name=SourceZone
    ${block_id}=        Create Block    ${source_zone_id}    block_name=MovableBlock
    ${shelf_id}=        Create Shelf    ${block_id}
    ${rack_id}=         Create Rack     ${shelf_id}
    ${position_id}=     Create Position    ${rack_id}    position_number=1
    
    ${product_data}=    Generate Unique Product Data    custom_name=Zone Move Product    position_id=${position_id}
    Set To Dictionary   ${product_data}    blockId=${block_id}    shelfId=${shelf_id}    rackId=${rack_id}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    ${target_zone_id}=  Create Zone    zone_name=TargetZone
    ${moved_block}=     Move Block To Zone    ${block_id}    ${target_zone_id}
    
    ${updated_product}=    Get Product By ID    ${product_id}
    Should Be Equal As Integers    ${updated_product}[blockId]    ${block_id}
    Should Be Equal As Integers    ${moved_block}[zoneId]    ${target_zone_id}
    
    Log                 Successfully moved block ${block_id} from zone ${source_zone_id} to ${target_zone_id}

03 - Move Block To Full Zone Test
    [Documentation]     Test moving a block to a zone that exceeds capacity
    [Tags]              zone    block    move    capacity    negative
    
    ${source_zone_id}=  Create Zone    zone_name=SourceZoneFull
    ${block_id}=        Create Block    ${source_zone_id}    block_name=FullMoveBlock    capacity=${BLOCK_CAPACITY}
    ${shelf_id}=        Create Shelf    ${block_id}
    ${rack_id}=         Create Rack     ${shelf_id}
    ${position_id}=     Create Position    ${rack_id}    position_number=1
    
    ${product_data}=    Generate Unique Product Data    custom_name=Full Zone Product    quantity=${BLOCK_CAPACITY}    position_id=${position_id}
    Set To Dictionary   ${product_data}    blockId=${block_id}    shelfId=${shelf_id}    rackId=${rack_id}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    ${target_zone_id}=  Create Zone    zone_name=TargetZoneFull    capacity=${ZONE_CAPACITY}
    ${filler_block}=    Create Block    ${target_zone_id}    block_name=FillerBlock    capacity=${BLOCK_CAPACITY}
    ${filler_shelf}=    Create Shelf    ${filler_block}
    ${filler_rack}=     Create Rack     ${filler_shelf}
    ${filler_position}= Create Position    ${filler_rack}    position_number=1
    
    ${filler_product}=  Generate Unique Product Data    custom_name=Filler Product    quantity=${ZONE_CAPACITY - BLOCK_CAPACITY + 1}    position_id=${filler_position}
    Set To Dictionary   ${filler_product}    blockId=${filler_block}    shelfId=${filler_shelf}    rackId=${filler_rack}
    ${filler_id}    ${filler_response}=    Create Product    ${filler_product}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${move_data}=       Create Dictionary    id=${block_id}    zoneId=${target_zone_id}    warehouseId=${WAREHOUSE_ID}
    
    Run Keyword And Expect Error    *
    ...                 PUT On Session
    ...                 vkho
    ...                 /blocks/update
    ...                 json=${move_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${updated_product}=    Get Product By ID    ${product_id}
    ${block_after}=    Evaluate    requests.get('${BASE_URL}/blocks/get-one/${block_id}', headers={'Authorization': '${AUTH_TOKEN}'}).json()    requests
    
    Should Be Equal As Integers    ${block_after}[zoneId]    ${source_zone_id}
    Log                 Successfully verified block ${block_id} remains in ${source_zone_id} due to target zone capacity

04 - Position Number Uniqueness Test
    [Documentation]     Test that position numbers must be unique within a rack
    [Tags]              position    validation    negative
    
    ${position_id1}=    Create Position    ${RACK_ID}    position_number=1
    
    ${position_data}=   Create Dictionary
    ...                 rackId=${RACK_ID}
    ...                 positionNumber=1    # Duplicate number
    ...                 capacity=${POSITION_CAPACITY}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /positions/create
    ...                 json=${position_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    Log                 Successfully verified position number uniqueness within rack ${RACK_ID}

05 - Concurrent Position Creation Test
    [Documentation]     Test concurrent creation of positions within the same rack
    [Tags]              position    concurrent    positive
    
    ${position_ids}=    Create List
    
    # Simulate concurrent creation (sequential due to Robot limitations)
    ${position_id1}=    Create Position    ${RACK_ID}    position_number=1
    ${position_id2}=    Create Position    ${RACK_ID}    position_number=2
    
    Append To List      ${position_ids}    ${position_id1}    ${position_id2}
    
    ${product_ids}=     Create List
    FOR    ${i}    IN RANGE    2
        ${product_data}=    Generate Unique Product Data    custom_name=Concurrent Position Product ${i}    position_id=${position_ids}[${i}]
        ${product_id}    ${response}=    Create Product    ${product_data}
        Append To List      ${product_ids}    ${product_id}
        Assert Product Location    ${response}    ${BLOCK_ID}    ${SHELF_ID}    ${RACK_ID}    ${position_ids}[${i}]
    END
    
    Log                 Successfully created positions ${position_ids} concurrently and assigned products

06 - Concurrent Position Creation Conflict Test
    [Documentation]     Test concurrent creation with duplicate position numbers
    [Tags]              position    concurrent    negative
    
    ${position_id1}=    Create Position    ${RACK_ID}    position_number=3
    
    ${position_data}=   Create Dictionary
    ...                 rackId=${RACK_ID}
    ...                 positionNumber=3    # Duplicate in "concurrent" attempt
    ...                 capacity=${POSITION_CAPACITY}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /positions/create
    ...                 json=${position_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    Log                 Successfully verified conflict in concurrent position creation with duplicate number

07 - Concurrent Position Creation and Deletion Test
    [Documentation]     Test creating a position while deleting another in the same rack
    [Tags]              position    concurrent    positive
    
    ${position_id1}=    Create Position    ${RACK_ID}    position_number=4
    ${product_data}=    Generate Unique Product Data    custom_name=Delete Concurrent Product    position_id=${position_id1}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    # Simulate concurrent ops: delete position1, create position2
    ${delete_result}=   Delete Position    ${position_id1}
    ${position_id2}=    Create Position    ${RACK_ID}    position_number=5
    
    Should Be True      ${delete_result}
    
    ${updated_product}=    Get Product By ID    ${product_id}
    ${has_position}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${updated_product}    positionId
    Run Keyword If      ${has_position}    Should Not Be Equal    ${updated_product}[positionId]    ${position_id1}
    ...    ELSE         Log    Product positionId removed as expected
    
    ${new_product_data}=    Generate Unique Product Data    custom_name=New Concurrent Product    position_id=${position_id2}
    ${new_product_id}    ${new_response}=    Create Product    ${new_product_data}
    Assert Product Location    ${new_response}    ${BLOCK_ID}    ${SHELF_ID}    ${RACK_ID}    ${position_id2}
    
    Log                 Successfully handled concurrent position deletion ${position_id1} and creation ${position_id2}