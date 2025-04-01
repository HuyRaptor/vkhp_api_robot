*** Settings ***
Documentation     End-to-End Test Suite for Product Management with Blocks, Shelves, Racks, and Positions
...               Tests product placement, movement, and retrieval within warehouse locations
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
${BLOCK_ID}             1
${SHELF_ID}             1
${RACK_ID}              1
${POSITION_ID}          1
${PRODUCT_ID}           ${EMPTY}
${RESULTS_DIR}          ${CURDIR}${/}results
${TEST_PRODUCT_NAME}    ${EMPTY}

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
    ...    msg=Authentication failed: No access_token in response
    
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    
    Create Directory    ${RESULTS_DIR}

Generate Unique Product Data
    [Documentation]     Generate unique product data with location details
    [Arguments]         ${custom_name}=Test Product
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_name}=    Set Variable     ${custom_name} ${timestamp}
    ${product_code}=    Set Variable     PRD${timestamp}
    
    ${product_data}=    Create Dictionary
    ...                 name=${product_name}
    ...                 totalQuantity=100
    ...                 expectedQuantity=100
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
    
    [Return]            ${product_data}

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
    ...    msg=Create product response was empty
    Dictionary Should Contain Key        ${json}    id
    
    ${product_id}=      Convert To String    ${json}[id]
    [Return]            ${product_id}    ${json}

Get Product By ID
    [Documentation]     Retrieve a product by ID
    [Arguments]         ${product_id}
    
    Should Not Be Empty    ${product_id}
    ...    msg=Product ID cannot be empty
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        GET On Session
    ...                 vkho
    ...                 /products/get-one/${product_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get product response was empty
    
    [Return]            ${json}

Update Product Location
    [Documentation]     Update a product's location (block, shelf, rack, position)
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
    Should Be Equal As Integers    ${json}[blockId]    ${new_block_id}
    ...    msg=Block ID update failed
    Should Be Equal As Integers    ${json}[shelfId]    ${new_shelf_id}
    ...    msg=Shelf ID update failed
    Should Be Equal As Integers    ${json}[rackId]    ${new_rack_id}
    ...    msg=Rack ID update failed
    Should Be Equal As Integers    ${json}[positionId]    ${new_position_id}
    ...    msg=Position ID update failed
    
    [Return]            ${json}

Get Products By Location
    [Documentation]     Retrieve products by block, shelf, rack, and position
    [Arguments]         ${block_id}    ${shelf_id}    ${rack_id}    ${position_id}
    
    ${params}=          Create Dictionary
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 blockId=${block_id}
    ...                 shelfId=${shelf_id}
    ...                 rackId=${rack_id}
    ...                 positionId=${position_id}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    ${response}=        GET On Session
    ...                 vkho
    ...                 /products/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get products by location response was empty
    
    [Return]            ${json}

Assert Product Location
    [Documentation]     Verify a product’s location details
    [Arguments]         ${product}    ${expected_block_id}    ${expected_shelf_id}    ${expected_rack_id}    ${expected_position_id}
    
    Should Be Equal As Integers    ${product}[blockId]    ${expected_block_id}
    ...    msg=Block ID mismatch: ${product}[blockId] != ${expected_block_id}
    Should Be Equal As Integers    ${product}[shelfId]    ${expected_shelf_id}
    ...    msg=Shelf ID mismatch: ${product}[shelfId] != ${expected_shelf_id}
    Should Be Equal As Integers    ${product}[rackId]    ${expected_rack_id}
    ...    msg=Rack ID mismatch: ${product}[rackId] != ${expected_rack_id}
    Should Be Equal As Integers    ${product}[positionId]    ${expected_position_id}
    ...    msg=Position ID mismatch: ${product}[positionId] != ${expected_position_id}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for location-based product tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Product With Location Flow
    [Documentation]     Test creating a product and assigning it to a specific location
    [Tags]              create    location    positive
    
    ${product_data}=    Generate Unique Product Data
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    Should Not Be Empty    ${product_id}
    ...    msg=Failed to create product: No ID returned
    Assert Product Location    ${response}    ${BLOCK_ID}    ${SHELF_ID}    ${RACK_ID}    ${POSITION_ID}
    
    Set Global Variable  ${PRODUCT_ID}    ${product_id}
    Set Global Variable  ${TEST_PRODUCT_NAME}    ${response}[name]
    Log                 Successfully created product ${TEST_PRODUCT_NAME} at Block:${BLOCK_ID}, Shelf:${SHELF_ID}, Rack:${RACK_ID}, Position:${POSITION_ID}

03 - Retrieve Product By Location Flow
    [Documentation]     Test retrieving a product by its assigned block, shelf, rack, and position
    [Tags]              retrieve    location    positive
    
    Run Keyword If      "${PRODUCT_ID}" == "${EMPTY}"    Create Product With Location Flow
    
    ${products}=        Get Products By Location    ${BLOCK_ID}    ${SHELF_ID}    ${RACK_ID}    ${POSITION_ID}
    
    ${items}=           Set Variable    ${products}
    FOR    ${key}    IN    data    items    records
        ${has_key}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${products}    ${key}
        Run Keyword If  ${has_key}    Set Variable    ${products}[${key}]    ${items}
    END
    
    ${found}=           Set Variable    ${FALSE}
    FOR    ${product}    IN    @{items}
        ${id_match}=    Run Keyword And Return Status    Should Be Equal    ${product}[id]    ${PRODUCT_ID}
        Run Keyword If  ${id_match}    Set Variable    ${TRUE}    ${found}
    END
    
    Should Be True      ${found}
    ...    msg=Product ${PRODUCT_ID} not found at specified location
    
    Log                 Successfully retrieved product ${TEST_PRODUCT_NAME} by location

04 - Move Product To New Location Flow
    [Documentation]     Test moving a product to a new block, shelf, rack, and position
    [Tags]              update    location    positive
    
    Run Keyword If      "${PRODUCT_ID}" == "${EMPTY}"    Create Product With Location Flow
    
    ${new_block_id}=    Set Variable    2
    ${new_shelf_id}=    Set Variable    2
    ${new_rack_id}=     Set Variable    2
    ${new_position_id}= Set Variable    2
    
    ${updated_product}=    Update Product Location    ${PRODUCT_ID}    ${new_block_id}    ${new_shelf_id}    ${new_rack_id}    ${new_position_id}
    Assert Product Location    ${updated_product}    ${new_block_id}    ${new_shelf_id}    ${new_rack_id}    ${new_position_id}
    
    Log                 Successfully moved product ${TEST_PRODUCT_NAME} to Block:${new_block_id}, Shelf:${new_shelf_id}, Rack:${new_rack_id}, Position:${new_position_id}

05 - Invalid Location Assignment Test
    [Documentation]     Test creating a product with an invalid rack ID
    [Tags]              create    location    negative
    
    ${invalid_data}=    Generate Unique Product Data    custom_name=Invalid Location Product
    Set To Dictionary   ${invalid_data}    rackId=999999  # Assuming an invalid ID
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${invalid_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    Log                 Successfully verified that invalid rack ID is rejected

06 - Move Product To Occupied Position Test
    [Documentation]     Test moving a product to an already occupied position (assuming API enforces uniqueness)
    [Tags]              update    location    negative
    
    # Create first product
    ${product_data1}=   Generate Unique Product Data    custom_name=Product One
    ${product_id1}    ${response1}=    Create Product    ${product_data1}
    
    # Create second product at a different location
    ${product_data2}=   Generate Unique Product Data    custom_name=Product Two
    Set To Dictionary   ${product_data2}    blockId=2    shelfId=2    rackId=2    positionId=2
    ${product_id2}    ${response2}=    Create Product    ${product_data2}
    
    # Attempt to move first product to second product’s location
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${update_data}=     Create Dictionary
    ...                 id=${product_id1}
    ...                 blockId=2
    ...                 shelfId=2
    ...                 rackId=2
    ...                 positionId=2
    ...                 warehouseId=${WAREHOUSE_ID}
    
    Run Keyword And Expect Error    *
    ...                 PUT On Session
    ...                 vkho
    ...                 /products/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that moving to an occupied position fails

07 - Bulk Product Placement Flow
    [Documentation]     Test placing multiple products across different locations
    [Tags]              create    location    bulk    positive
    
    ${product_count}=   Set Variable    3
    ${product_ids}=     Create List
    
    FOR    ${i}    IN RANGE    ${product_count}
        ${block_id}=    Evaluate    ${i} + 1
        ${shelf_id}=    Evaluate    ${i} + 1
        ${rack_id}=     Evaluate    ${i} + 1
        ${position_id}= Evaluate    ${i} + 1
        
        ${product_data}=    Generate Unique Product Data    custom_name=Bulk Product ${i}
        Set To Dictionary   ${product_data}    blockId=${block_id}    shelfId=${shelf_id}    rackId=${rack_id}    positionId=${position_id}
        
        ${product_id}    ${response}=    Create Product    ${product_data}
        Append To List      ${product_ids}    ${product_id}
        
        Assert Product Location    ${response}    ${block_id}    ${shelf_id}    ${rack_id}    ${position_id}
    END
    
    # Verify all products are retrievable by their locations
    FOR    ${i}    IN RANGE    ${product_count}
        ${block_id}=    Evaluate    ${i} + 1
        ${shelf_id}=    Evaluate    ${i} + 1
        ${rack_id}=     Evaluate    ${i} + 1
        ${position_id}= Evaluate    ${i} + 1
        
        ${products}=    Get Products By Location    ${block_id}    ${shelf_id}    ${rack_id}    ${position_id}
        ${items}=       Set Variable    ${products}
        FOR    ${key}    IN    data    items    records
            ${has_key}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${products}    ${key}
            Run Keyword If  ${has_key}    Set Variable    ${products}[${key}]    ${items}
        END
        
        ${found}=       Set Variable    ${FALSE}
        FOR    ${product}    IN    @{items}
            ${id_match}=    Run Keyword And Return Status    Should Be Equal    ${product}[id]    ${product_ids}[${i}]
            Run Keyword If  ${id_match}    Set Variable    ${TRUE}    ${found}
        END
        
        Should Be True    ${found}
        ...    msg=Product ${product_ids}[${i}] not found at expected location
    END
    
    Log                 Successfully placed and verified ${product_count} products across different locations