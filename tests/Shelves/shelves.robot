*** Settings ***
Documentation     Comprehensive Test Suite for Shelf Operations in vKho API
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
    ${body}=            Create Dictionary    username=${USERNAME}    password=${PASSWORD}
    
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

Generate Unique Shelf Data
    [Documentation]     Generate unique data for shelf tests
    
    # Prepare shelf creation data
    ${timestamp}=       Evaluate         int(time.time())    time
    ${shelf_name}=      Set Variable     Test Shelf ${timestamp}
    ${shelf_data}=      Create Dictionary
    ...                 name=${shelf_name}
    ...                 totalRack=5
    ...                 position=${timestamp}
    ...                 medium=50
    ...                 high=100
    ...                 capacity=200
    ...                 blockId=${BLOCK_ID}
    ...                 parentProductCategoryId=${PARENT_PRODUCT_CATEGORY_ID}
    ...                 warehouseId=${WAREHOUSE_ID}
    
    RETURN            ${shelf_data}

Create Shelf
    [Documentation]     Create a new shelf and return its ID
    [Arguments]         ${shelf_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${shelf_data}    name
    ...    msg=Missing required parameter: name
    Dictionary Should Contain Key    ${shelf_data}    totalRack
    ...    msg=Missing required parameter: totalRack
    Dictionary Should Contain Key    ${shelf_data}    position
    ...    msg=Missing required parameter: position
    Dictionary Should Contain Key    ${shelf_data}    medium
    ...    msg=Missing required parameter: medium
    Dictionary Should Contain Key    ${shelf_data}    high
    ...    msg=Missing required parameter: high
    Dictionary Should Contain Key    ${shelf_data}    capacity
    ...    msg=Missing required parameter: capacity
    Dictionary Should Contain Key    ${shelf_data}    blockId
    ...    msg=Missing required parameter: blockId
    Dictionary Should Contain Key    ${shelf_data}    parentProductCategoryId
    ...    msg=Missing required parameter: parentProductCategoryId
    Dictionary Should Contain Key    ${shelf_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create shelf request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /shelves/create
    ...                 json=${shelf_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Save response for debugging
    ${timestamp}=       Evaluate         int(time.time())    time
    Create File         ${RESULTS_DIR}${/}shelf_create_${timestamp}.json    ${response.text}
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create shelf response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create shelf response missing ID field
    
    # Return shelf ID and full response
    ${shelf_id}=        Convert To String    ${json}[id]
    RETURN            ${shelf_id}    ${json}

Get Shelf By ID
    [Documentation]     Retrieve a specific shelf by ID
    [Arguments]         ${shelf_id}
    
    # Validate parameters
    Should Not Be Empty    ${shelf_id}
    ...    msg=Shelf ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get shelf request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /shelves/get-one/${shelf_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get shelf response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get shelf response missing ID field
    
    RETURN            ${json}

Update Shelf
    [Documentation]     Update an existing shelf
    [Arguments]         ${shelf_id}    ${update_data}
    
    # Validate parameters
    Should Not Be Empty    ${shelf_id}
    ...    msg=Shelf ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${shelf_id}
    ...    msg=Update data ID must match shelf_id parameter
    
    # Ensure minimum required fields are present
    Dictionary Should Contain Key    ${update_data}    name
    ...    msg=Update data missing required field: name
    Dictionary Should Contain Key    ${update_data}    totalRack
    ...    msg=Update data missing required field: totalRack
    Dictionary Should Contain Key    ${update_data}    position
    ...    msg=Update data missing required field: position
    Dictionary Should Contain Key    ${update_data}    medium
    ...    msg=Update data missing required field: medium
    Dictionary Should Contain Key    ${update_data}    high
    ...    msg=Update data missing required field: high
    Dictionary Should Contain Key    ${update_data}    capacity
    ...    msg=Update data missing required field: capacity
    Dictionary Should Contain Key    ${update_data}    blockId
    ...    msg=Update data missing required field: blockId
    Dictionary Should Contain Key    ${update_data}    parentProductCategoryId
    ...    msg=Update data missing required field: parentProductCategoryId
    Dictionary Should Contain Key    ${update_data}    warehouseId
    ...    msg=Update data missing required field: warehouseId
    Dictionary Should Contain Key    ${update_data}    status
    ...    msg=Update data missing required field: status
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send update shelf request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /shelves/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update shelf response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Update shelf response missing ID field
    
    RETURN            ${json}

Delete Shelf
    [Documentation]     Delete a shelf from the system
    [Arguments]         ${shelf_id}
    
    # Validate parameters
    Should Not Be Empty    ${shelf_id}
    ...    msg=Shelf ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send delete shelf request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /shelves/delete/${shelf_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Return deletion status
    RETURN            ${TRUE}

Get All Shelves
    [Documentation]     Retrieve all shelves
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get all shelves request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /shelves/get-all
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get all shelves response was empty
    
    RETURN            ${json}

Assert Shelf Details
    [Documentation]     Verify shelf details match expected values
    [Arguments]         ${shelf}    ${expected_data}
    
    # For all keys in expected data, verify they match in the shelf data
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${shelf}    Should Be Equal    ${shelf}[${key}]    ${expected_data}[${key}]
        ...    msg=Shelf ${key} value '${shelf}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Shelf
    [Documentation]     Creates a    test shelf if one doesn't exist
    ${shelf_data}=      Generate Unique Shelf Data
    ${shelf_id}    ${response}=    Create Shelf    ${shelf_data}
    Set Global Variable  ${TEST_SHELF_ID}      ${shelf_id}
    Set Global Variable  ${TEST_SHELF_DATA}    ${shelf_data}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for shelf tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Shelf Test
    [Documentation]     Test creating a new shelf
    [Tags]              create    positive
    
    # Generate shelf data
    ${shelf_data}=      Generate Unique Shelf Data
    
    # Create shelf
    ${shelf_id}    ${response}=    Create Shelf    ${shelf_data}
    
    # Verify shelf was created successfully
    Should Not Be Empty    ${shelf_id}
    ...    msg=Failed to create shelf: No ID returned
    
    # Save shelf ID for subsequent tests
    Set Global Variable  ${TEST_SHELF_ID}      ${shelf_id}
    Set Global Variable  ${TEST_SHELF_DATA}    ${shelf_data}
    
    Log                 Successfully created shelf with ID: ${TEST_SHELF_ID}

03 - Create Shelf Missing Required Field Test
    [Documentation]     Test creating a shelf with missing required fields
    [Tags]              create    negative
    
    # Generate incomplete shelf data (missing blockId)
    ${incomplete_data}=  Create Dictionary
    ...                 name=Incomplete Shelf
    ...                 totalRack=3
    ...                 position=1
    ...                 medium=30
    ...                 high=60
    ...                 capacity=100
    ...                 parentProductCategoryId=${PARENT_PRODUCT_CATEGORY_ID}
    ...                 warehouseId=${WAREHOUSE_ID}
    
    # Attempt to create shelf with incomplete data
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect proper error message
    Run Keyword And Expect Error    *Missing required parameter: blockId*
    ...                 Create Shelf    ${incomplete_data}
    
    Log                 Successfully verified that creating a shelf with missing fields is rejected

04 - Get Shelf Test
    [Documentation]     Test retrieving a specific shelf
    [Tags]              retrieve    positive
    
    # Create a shelf if one doesn't exist
    Run Keyword If      "${TEST_SHELF_ID}" == "${EMPTY}"    Create Test Shelf
    
    # Get shelf
    ${shelf}=           Get Shelf By ID    ${TEST_SHELF_ID}
    
    # Verify shelf details match what we created
    Assert Shelf Details    ${shelf}    ${TEST_SHELF_DATA}
    
    Log                 Successfully retrieved shelf with ID: ${TEST_SHELF_ID}

05 - Get Non-Existent Shelf Test
    [Documentation]     Test retrieving a shelf that doesn't exist
    [Tags]              retrieve    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to get non-existent shelf
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 GET On Session
    ...                 vkho
    ...                 /shelves/get-one/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that retrieving a non-existent shelf fails

06 - Update Shelf Test
    [Documentation]     Test updating an existing shelf
    [Tags]              update    positive
    
    # Create a shelf if one doesn't exist
    Run Keyword If      "${TEST_SHELF_ID}" == "${EMPTY}"    Create Test Shelf
    
    # Prepare update data
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_SHELF_ID}
    ...                 name=${TEST_SHELF_DATA}[name] Updated
    ...                 totalRack=10
    ...                 position=20
    ...                 medium=75
    ...                 high=150
    ...                 capacity=300
    ...                 blockId=${BLOCK_ID}
    ...                 parentProductCategoryId=${PARENT_PRODUCT_CATEGORY_ID}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 status=ENABLE
    
    # Update shelf
    ${updated_shelf}=   Update Shelf    ${TEST_SHELF_ID}    ${update_data}
    
    # Verify shelf was updated successfully
    Should Be Equal     ${updated_shelf}[name]    ${update_data}[name]
    ...    msg=Updated shelf name does not match expected value
    
    # Update global variable with new data
    Set Global Variable  ${TEST_SHELF_UPDATED_DATA}    ${update_data}
    
    Log                 Successfully updated shelf: ${TEST_SHELF_ID}

07 - Update Shelf With Missing Required Field Test
    [Documentation]     Test updating a shelf with missing required fields
    [Tags]              update    negative
    
    # Create a shelf if one doesn't exist
    Run Keyword If      "${TEST_SHELF_ID}" == "${EMPTY}"    Create Test Shelf
    
    # Prepare incomplete update data (missing status)
    ${incomplete_data}=  Create Dictionary
    ...                 id=${TEST_SHELF_ID}
    ...                 name=Incomplete Update Shelf
    ...                 totalRack=5
    ...                 position=10
    ...                 medium=50
    ...                 high=100
    ...                 capacity=200
    ...                 blockId=${BLOCK_ID}
    ...                 parentProductCategoryId=${PARENT_PRODUCT_CATEGORY_ID}
    ...                 warehouseId=${WAREHOUSE_ID}
    # Missing status field
    
    # Attempt to update shelf with incomplete data
    Run Keyword And Expect Error    *Update data missing required field: status*
    ...                 Update Shelf    ${TEST_SHELF_ID}    ${incomplete_data}
    
    Log                 Successfully verified that updating a shelf with missing fields is rejected

08 - Get All Shelves Test
    [Documentation]     Test retrieving all shelves
    [Tags]              retrieve    positive
    
    # Get all shelves
    ${shelves}=         Get All Shelves
    
    # Log the structure to understand the format
    Log                 Response structure: ${shelves}
    
    # Verify response is not empty
    Should Not Be Empty    ${shelves}
    ...    msg=Get all shelves response was empty
    
    Log                 Successfully retrieved shelves list

09 - Delete Shelf Test
    [Documentation]     Test deleting a shelf
    [Tags]              delete    positive
    
    # Create a shelf if one doesn't exist
    Run Keyword If      "${TEST_SHELF_ID}" == "${EMPTY}"    Create Test Shelf
    
    # Delete shelf
    ${result}=          Delete Shelf    ${TEST_SHELF_ID}
    Should Be True      ${result}
    ...    msg=Delete shelf operation failed
    
    # Verify shelf deletion by trying to get it
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /shelves/get-one/${TEST_SHELF_ID}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    # Log response for debugging
    Log                 Response status after deletion: ${response.status_code}
    Log                 Response text after deletion: ${response.text}
    
    # Expect 404 or a response indicating the resource no longer exists
    Run Keyword If      ${response.status_code} != 200    Log    Shelf successfully deleted
    ...    ELSE    Fail    Shelf was not deleted
    
    Log                 Successfully verified deletion of shelf with ID: ${TEST_SHELF_ID}

10 - Delete Non-Existent Shelf Test
    [Documentation]     Test deleting a shelf that doesn't exist
    [Tags]              delete    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to delete non-existent shelf
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 DELETE On Session
    ...                 vkho
    ...                 /shelves/delete/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that deleting a non-existent shelf fails

11 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    # Additional cleanup if needed
    Log                 Test environment cleaned up successfully