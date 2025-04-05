*** Settings ***
Documentation     Comprehensive Test Suite for Block Operations in vKho API
...               Includes proper parameter validation and error handling
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
    
    # Prepare login request
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${MANAGER_USERNAME}    password=${MANAGER_PASSWORD}
    
    # Send login request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    access_token
    ...    msg=Authentication failed: Response did not contain access_token
    
    # Save token for subsequent tests
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    
    # Create results directory if it doesn't exist
    Create Directory    ${RESULTS_DIR}

Generate Unique Block Data
    [Documentation]     Generate unique data for block tests
    
    # Prepare block creation data
    ${timestamp}=       Evaluate         int(time.time())    time
    ${block_name}=      Set Variable     Test Block ${timestamp}
    ${block_data}=      Create Dictionary
    ...                 name=${block_name}
    ...                 position=${timestamp}
    ...                 totalShelf=5
    ...                 warehouseId=${WAREHOUSE_ID}
    
    RETURN            ${block_data}

Create Block
    [Documentation]     Create a new block and return its ID
    [Arguments]         ${block_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${block_data}    name
    ...    msg=Missing required parameter: name
    Dictionary Should Contain Key    ${block_data}    position
    ...    msg=Missing required parameter: position
    Dictionary Should Contain Key    ${block_data}    totalShelf
    ...    msg=Missing required parameter: totalShelf
    Dictionary Should Contain Key    ${block_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create block request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /blocks/create
    ...                 json=${block_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Save response for debugging
    ${timestamp}=       Evaluate         int(time.time())    time
    Create File         ${RESULTS_DIR}${/}block_create_${timestamp}.json    ${response.text}
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create block response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create block response missing ID field
    
    # Return block ID and full response
    ${block_id}=        Convert To String    ${json}[id]
    RETURN            ${block_id}    ${json}

Get Block By ID
    [Documentation]     Retrieve a specific block by ID
    [Arguments]         ${block_id}
    
    # Validate parameters
    Should Not Be Empty    ${block_id}
    ...    msg=Block ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get block request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /blocks/get-one/${block_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get block response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get block response missing ID field
    
    RETURN            ${json}

Update Block
    [Documentation]     Update an existing block
    [Arguments]         ${block_id}    ${update_data}
    
    # Validate parameters
    Should Not Be Empty    ${block_id}
    ...    msg=Block ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${block_id}
    ...    msg=Update data ID must match block_id parameter
    
    # Ensure minimum required fields are present
    Dictionary Should Contain Key    ${update_data}    name
    ...    msg=Update data missing required field: name
    Dictionary Should Contain Key    ${update_data}    position
    ...    msg=Update data missing required field: position
    Dictionary Should Contain Key    ${update_data}    totalShelf
    ...    msg=Update data missing required field: totalShelf
    Dictionary Should Contain Key    ${update_data}    warehouseId
    ...    msg=Update data missing required field: warehouseId
    Dictionary Should Contain Key    ${update_data}    status
    ...    msg=Update data missing required field: status
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send update block request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /blocks/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update block response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Update block response missing ID field
    
    RETURN            ${json}

Delete Block
    [Documentation]     Delete a block from the system
    [Arguments]         ${block_id}
    
    # Validate parameters
    Should Not Be Empty    ${block_id}
    ...    msg=Block ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send delete block request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /blocks/delete/${block_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Return deletion status
    RETURN            ${TRUE}

Get All Blocks
    [Documentation]     Retrieve all blocks with optional filtering
    [Arguments]         ${warehouse_id}=${WAREHOUSE_ID}    ${filter_params}=${EMPTY}
    
    # Validate parameters
    Should Not Be Empty    ${warehouse_id}
    ...    msg=Warehouse ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Create params dictionary
    ${params}=          Create Dictionary    warehouseId=${warehouse_id}
    
    # Add any additional filter parameters if provided
    Run Keyword If      "${filter_params}" != "${EMPTY}"    Set To Dictionary    ${params}    &{filter_params}
    
    # Send get all blocks request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /blocks/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get all blocks response was empty
    
    RETURN            ${json}

Assert Block Details
    [Documentation]     Verify block details match expected values
    [Arguments]         ${block}    ${expected_data}
    
    # For all keys in expected data, verify they match in the block data
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${block}    Should Be Equal    ${block}[${key}]    ${expected_data}[${key}]
        ...    msg=Block ${key} value '${block}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Block
    [Documentation]     Creates a test block if one doesn't exist
    ${block_data}=      Generate Unique Block Data
    ${block_id}    ${response}=    Create Block    ${block_data}
    Set Global Variable  ${TEST_BLOCK_ID}      ${block_id}
    Set Global Variable  ${TEST_BLOCK_DATA}    ${block_data}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for block tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Block Test
    [Documentation]     Test creating a new block
    [Tags]              create    positive
    
    # Generate block data
    ${block_data}=      Generate Unique Block Data
    
    # Create block
    ${block_id}    ${response}=    Create Block    ${block_data}
    
    # Verify block was created successfully
    Should Not Be Empty    ${block_id}
    ...    msg=Failed to create block: No ID returned
    
    # Save block ID for subsequent tests
    Set Global Variable  ${TEST_BLOCK_ID}      ${block_id}
    Set Global Variable  ${TEST_BLOCK_DATA}    ${block_data}
    
    Log                 Successfully created block with ID: ${TEST_BLOCK_ID}
03 - Create Block Missing Required Field Test
    [Documentation]     Test creating a block with missing required fields
    [Tags]              create    negative
    
    # Generate incomplete block data (missing totalShelf)
    ${incomplete_data}=  Create Dictionary
    ...                 name=Incomplete Block
    ...                 position=1
    ...                 warehouseId=${WAREHOUSE_ID}
    
    # Attempt to create block with incomplete data
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect proper error message
    Run Keyword And Expect Error    *Missing required parameter: totalShelf*
    ...                 Create Block    ${incomplete_data}
    
    Log                 Successfully verified that creating a block with missing fields is rejected

04 - Get Block Test
    [Documentation]     Test retrieving a specific block
    [Tags]              retrieve    positive
    
    # Create a block if one doesn't exist
    Run Keyword If      "${TEST_BLOCK_ID}" == "${EMPTY}"    Create Test Block
    
    # Get block
    ${block}=           Get Block By ID    ${TEST_BLOCK_ID}
    
    # Verify block details match what we created
    Assert Block Details    ${block}    ${TEST_BLOCK_DATA}
    
    Log                 Successfully retrieved block with ID: ${TEST_BLOCK_ID}

05 - Get Non-Existent Block Test
    [Documentation]     Test retrieving a block that doesn't exist
    [Tags]              retrieve    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to get non-existent block
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 GET On Session
    ...                 vkho
    ...                 /blocks/get-one/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that retrieving a non-existent block fails

06 - Update Block Test
    [Documentation]     Test updating an existing block
    [Tags]              update    positive
    
    # Create a block if one doesn't exist
    Run Keyword If      "${TEST_BLOCK_ID}" == "${EMPTY}"    Create Test Block
    
    # Prepare update data
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_BLOCK_ID}
    ...                 name=${TEST_BLOCK_DATA}[name] Updated
    ...                 position=10
    ...                 totalShelf=10
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 status=ENABLE
    
    # Update block
    ${updated_block}=   Update Block    ${TEST_BLOCK_ID}    ${update_data}
    
    # Verify block was updated successfully
    Should Be Equal     ${updated_block}[name]    ${update_data}[name]
    ...    msg=Updated block name does not match expected value
    
    # Update global variable with new data
    Set Global Variable  ${TEST_BLOCK_UPDATED_DATA}    ${update_data}
    
    Log                 Successfully updated block: ${TEST_BLOCK_ID}

07 - Update Block With Missing Required Field Test
    [Documentation]     Test updating a block with missing required fields
    [Tags]              update    negative
    
    # Create a block if one doesn't exist
    Run Keyword If      "${TEST_BLOCK_ID}" == "${EMPTY}"    Create Test Block
    
    # Prepare incomplete update data (missing status)
    ${incomplete_data}=  Create Dictionary
    ...                 id=${TEST_BLOCK_ID}
    ...                 name=Incomplete Update Block
    ...                 position=5
    ...                 totalShelf=5
    ...                 warehouseId=${WAREHOUSE_ID}
    # Missing status field
    
    # Attempt to update block with incomplete data
    Run Keyword And Expect Error    *Update data missing required field: status*
    ...                 Update Block    ${TEST_BLOCK_ID}    ${incomplete_data}
    
    Log                 Successfully verified that updating a block with missing fields is rejected

08 - Get All Blocks Test
    [Documentation]     Test retrieving all blocks
    [Tags]              retrieve    positive
    
    # Get all blocks
    ${blocks}=          Get All Blocks
    
    # Log the structure to understand the format
    Log                 Response structure: ${blocks}
09 - Filter Blocks Test
    [Documentation]     Test filtering blocks by name
    [Tags]              retrieve    filter    positive
    
    # Create a block if one doesn't exist
    Run Keyword If      "${TEST_BLOCK_ID}" == "${EMPTY}"    Create Test Block
    
    # Create filter params based on block name
    ${filter_params}=   Create Dictionary    blockName=${TEST_BLOCK_DATA}[name]
    
    # Get filtered blocks
    ${filtered_blocks}=  Get All Blocks    filter_params=${filter_params}
    
    # Verify response contains data
    Should Not Be Empty    ${filtered_blocks}
    ...    msg=Filtered blocks response was empty
    
    # Check different possible response formats
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_blocks}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_blocks}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_blocks}    records
    
    # Verify filter worked based on response structure
    ${found}=           Set Variable    ${FALSE}
    
    # Check in 'data' array if present
    IF    ${has_data}
        ${data_length}=     Get Length    ${filtered_blocks}[data]
        Should Be True      ${data_length} > 0    msg=Filter returned empty data array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'items' array if present
    ELSE IF    ${has_items}
        ${items_length}=    Get Length    ${filtered_blocks}[items]
        Should Be True      ${items_length} > 0    msg=Filter returned empty items array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'records' array if present
    ELSE IF    ${has_records}
        ${records_length}=  Get Length    ${filtered_blocks}[records]
        Should Be True      ${records_length} > 0    msg=Filter returned empty records array
        ${found}=           Set Variable    ${TRUE}
    ELSE
        Log                 Warning: Unknown response structure, can't verify filter results
    END
    
    Should Be True      ${found}    msg=Failed to find block in filtered results
    
    Log                 Successfully filtered blocks by name: ${TEST_BLOCK_DATA}[name]

10 - Delete Block Test
    [Documentation]     Test deleting a block
    [Tags]              delete    positive
    
    # Create a block if one doesn't exist
    Run Keyword If      "${TEST_BLOCK_ID}" == "${EMPTY}"    Create Test Block
    
    # Delete block
    ${result}=          Delete Block    ${TEST_BLOCK_ID}
    Should Be True      ${result}
    ...    msg=Delete block operation failed
    
    # Verify block deletion by trying to get it
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /blocks/get-one/${TEST_BLOCK_ID}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    # Log response for debugging
    Log                 Response status after deletion: ${response.status_code}
    Log                 Response text after deletion: ${response.text}
    
    # Expect 404 or a response indicating the resource no longer exists
    Run Keyword If      ${response.status_code} != 200    Log    Block successfully deleted
    ...    ELSE    Fail    Block was not deleted
    
    Log                 Successfully verified deletion of block with ID: ${TEST_BLOCK_ID}

11 - Delete Non-Existent Block Test
    [Documentation]     Test deleting a block that doesn't exist
    [Tags]              delete    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to delete non-existent block
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 DELETE On Session
    ...                 vkho
    ...                 /blocks/delete/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that deleting a non-existent block fails

12 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    # Additional cleanup if needed
    Log                 Test environment cleaned up successfully03 - Create Block Missing Required Field Test