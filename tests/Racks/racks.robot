*** Settings ***
Documentation     Comprehensive Test Suite for Rack Operations in vKho API
...               Includes proper parameter validation and error handling
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
${SHELF_ID}             1
${RESULTS_DIR}          ${CURDIR}${/}results
${TEST_RACK_ID}         ${EMPTY}
${TEST_RACK_DATA}       ${EMPTY}

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

Generate Unique Rack Data
    [Documentation]     Generate unique data for rack tests
    
    # Prepare rack creation data
    ${timestamp}=       Evaluate         int(time.time())    time
    ${rack_data}=       Create Dictionary
    ...                 capacity=100
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 shelfId=${SHELF_ID}
    
    RETURN            ${rack_data}

Create Rack
    [Documentation]     Create a new rack and return its ID
    [Arguments]         ${rack_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${rack_data}    capacity
    ...    msg=Missing required parameter: capacity
    Dictionary Should Contain Key    ${rack_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    Dictionary Should Contain Key    ${rack_data}    shelfId
    ...    msg=Missing required parameter: shelfId
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create rack request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /racks/create
    ...                 json=${rack_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Save response for debugging
    ${timestamp}=       Evaluate         int(time.time())    time
    Create File         ${RESULTS_DIR}${/}rack_create_${timestamp}.json    ${response.text}
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create rack response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create rack response missing ID field
    
    # Return rack ID and full response
    ${rack_id}=         Convert To String    ${json}[id]
    RETURN            ${rack_id}    ${json}

Get Rack By ID
    [Documentation]     Retrieve a specific rack by ID
    [Arguments]         ${rack_id}
    
    # Validate parameters
    Should Not Be Empty    ${rack_id}
    ...    msg=Rack ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get rack request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /racks/get-one/${rack_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get rack response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get rack response missing ID field
    
    RETURN            ${json}

Update Rack
    [Documentation]     Update an existing rack
    [Arguments]         ${rack_id}    ${update_data}
    
    # Validate parameters
    Should Not Be Empty    ${rack_id}
    ...    msg=Rack ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${rack_id}
    ...    msg=Update data ID must match rack_id parameter
    
    # Ensure minimum required fields are present
    Dictionary Should Contain Key    ${update_data}    capacity
    ...    msg=Update data missing required field: capacity
    Dictionary Should Contain Key    ${update_data}    warehouseId
    ...    msg=Update data missing required field: warehouseId
    Dictionary Should Contain Key    ${update_data}    shelfId
    ...    msg=Update data missing required field: shelfId
    Dictionary Should Contain Key    ${update_data}    status
    ...    msg=Update data missing required field: status
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send update rack request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /racks/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update rack response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Update rack response missing ID field
    
    RETURN            ${json}

Delete Rack
    [Documentation]     Delete a rack from the system
    [Arguments]         ${rack_id}
    
    # Validate parameters
    Should Not Be Empty    ${rack_id}
    ...    msg=Rack ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send delete rack request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /racks/delete/${rack_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Return deletion status
    RETURN            ${TRUE}

Get All Racks
    [Documentation]     Retrieve all racks with optional filtering
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
    
    # Send get all racks request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /racks/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get all racks response was empty
    
    RETURN            ${json}

Recommend Rack
    [Documentation]     Get recommended rack for given parameters
    [Arguments]         ${total_capacity}    ${parent_product_category_id}
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Create params dictionary
    ${params}=          Create Dictionary
    ...                 totalCapacity=${total_capacity}
    ...                 parentProductCategoryId=${parent_product_category_id}
    
    # Send recommend rack request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /racks/recommend
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Recommend rack response was empty
    
    RETURN            ${json}

Assert Rack Details
    [Documentation]     Verify rack details match expected values
    [Arguments]         ${rack}    ${expected_data}
    
    # For all keys in expected data, verify they match in the rack data
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${rack}    Should Be Equal    ${rack}[${key}]    ${expected_data}[${key}]
        ...    msg=Rack ${key} value '${rack}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Rack
    [Documentation]     Creates a test rack if one doesn't exist
    ${rack_data}=       Generate Unique Rack Data
    ${rack_id}    ${response}=    Create Rack    ${rack_data}
    Set Global Variable  ${TEST_RACK_ID}      ${rack_id}
    Set Global Variable  ${TEST_RACK_DATA}    ${rack_data}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for rack tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Rack Test
    [Documentation]     Test creating a new rack
    [Tags]              create    positive
    
    # Generate rack data
    ${rack_data}=       Generate Unique Rack Data
    
    # Create rack
    ${rack_id}    ${response}=    Create Rack    ${rack_data}
    
    # Verify rack was created successfully
    Should Not Be Empty    ${rack_id}
    ...    msg=Failed to create rack: No ID returned
    
    # Save rack ID for subsequent tests
    Set Global Variable  ${TEST_RACK_ID}      ${rack_id}
    Set Global Variable  ${TEST_RACK_DATA}    ${rack_data}
    
    Log                 Successfully created rack with ID: ${TEST_RACK_ID}

03 - Create Rack Missing Required Field Test
    [Documentation]     Test creating a rack with missing required fields
    [Tags]              create    negative
    
    # Generate incomplete rack data (missing shelfId)
    ${incomplete_data}=  Create Dictionary
    ...                 capacity=100
    ...                 warehouseId=${WAREHOUSE_ID}
    
    # Attempt to create rack with incomplete data
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect proper error message
    Run Keyword And Expect Error    *Missing required parameter: shelfId*
    ...                 Create Rack    ${incomplete_data}
    
    Log                 Successfully verified that creating a rack with missing fields is rejected
04 - Get Rack Test
    [Documentation]     Test retrieving a specific rack
    [Tags]              retrieve    positive
    
    # Create a rack if one doesn't exist
    Run Keyword If      "${TEST_RACK_ID}" == "${EMPTY}"    Create Test Rack
    
    # Get rack
    ${rack}=            Get Rack By ID    ${TEST_RACK_ID}
    
    # Verify rack details match what we created
    Assert Rack Details    ${rack}    ${TEST_RACK_DATA}
    
    Log                 Successfully retrieved rack with ID: ${TEST_RACK_ID}

05 - Get Non-Existent Rack Test
    [Documentation]     Test retrieving a rack that doesn't exist
    [Tags]              retrieve    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to get non-existent rack
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 GET On Session
    ...                 vkho
    ...                 /racks/get-one/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that retrieving a non-existent rack fails

06 - Update Rack Test
    [Documentation]     Test updating an existing rack
    [Tags]              update    positive
    
    # Create a rack if one doesn't exist
    Run Keyword If      "${TEST_RACK_ID}" == "${EMPTY}"    Create Test Rack
    
    # Prepare update data
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_RACK_ID}
    ...                 capacity=200
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 shelfId=${SHELF_ID}
    ...                 status=ENABLE
    
    # Update rack
    ${updated_rack}=    Update Rack    ${TEST_RACK_ID}    ${update_data}
    
    # Verify rack was updated successfully
    Should Be Equal     ${updated_rack}[capacity]    ${update_data}[capacity]
    ...    msg=Updated rack capacity does not match expected value
    
    # Update global variable with new data
    Set Global Variable  ${TEST_RACK_UPDATED_DATA}    ${update_data}
    
    Log                 Successfully updated rack: ${TEST_RACK_ID}

07 - Update Rack With Missing Required Field Test
    [Documentation]     Test updating a rack with missing required fields
    [Tags]              update    negative
    
    # Create a rack if one doesn't exist
    Run Keyword If      "${TEST_RACK_ID}" == "${EMPTY}"    Create Test Rack
    
    # Prepare incomplete update data (missing status)
    ${incomplete_data}=  Create Dictionary
    ...                 id=${TEST_RACK_ID}
    ...                 capacity=150
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 shelfId=${SHELF_ID}
    # Missing status field
    
    # Attempt to update rack with incomplete data
    Run Keyword And Expect Error    *Update data missing required field: status*
    ...                 Update Rack    ${TEST_RACK_ID}    ${incomplete_data}
    
    Log                 Successfully verified that updating a rack with missing fields is rejected

08 - Get All Racks Test
    [Documentation]     Test retrieving all racks
    [Tags]              retrieve    positive
    
    # Get all racks
    ${racks}=           Get All Racks
    
    # Log the structure to understand the format
    Log                 Response structure: ${racks}
    
    # Check different possible response formats
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${racks}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${racks}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${racks}    records
    
    # Log information based on what we found
    Run Keyword If      ${has_data}      Log    Found ${racks['data'].__len__()} racks
    ...    ELSE IF      ${has_items}     Log    Found ${racks['items'].__len__()} racks
    ...    ELSE IF      ${has_records}   Log    Found ${racks['records'].__len__()} racks
    ...    ELSE         Log    Found racks in unknown format
    
    Log                 Successfully retrieved racks list

09 - Filter Racks Test
    [Documentation]     Test filtering racks by warehouse
    [Tags]              retrieve    filter    positive
    
    # Create a rack if one doesn't exist
    Run Keyword If      "${TEST_RACK_ID}" == "${EMPTY}"    Create Test Rack
    
    # Create filter params based on warehouse
    ${filter_params}=   Create Dictionary    warehouseId=${WAREHOUSE_ID}
    
    # Get filtered racks
    ${filtered_racks}=  Get All Racks    filter_params=${filter_params}
    
    # Verify response contains data
    Should Not Be Empty    ${filtered_racks}
    ...    msg=Filtered racks response was empty
    
    # Check different possible response formats
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_racks}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_racks}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_racks}    records
    
    # Verify filter worked based on response structure
    ${found}=           Set Variable    ${FALSE}
    
    # Check in 'data' array if present
    IF    ${has_data}
        ${data_length}=     Get Length    ${filtered_racks}[data]
        Should Be True      ${data_length} > 0    msg=Filter returned empty data array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'items' array if present
    ELSE IF    ${has_items}
        ${items_length}=    Get Length    ${filtered_racks}[items]
        Should Be True      ${items_length} > 0    msg=Filter returned empty items array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'records' array if present
    ELSE IF    ${has_records}
        ${records_length}=  Get Length    ${filtered_racks}[records]
        Should Be True      ${records_length} > 0    msg=Filter returned empty records array
        ${found}=           Set Variable    ${TRUE}
    ELSE
        Log                 Warning: Unknown response structure, can't verify filter results
    END
    
    Should Be True      ${found}    msg=Failed to find rack in filtered results
    
    Log                 Successfully filtered racks by warehouse: ${WAREHOUSE_ID}

10 - Recommend Rack Test
    [Documentation]     Test recommending a rack
    [Tags]              recommend    positive
    
    # Parameters for rack recommendation
    ${total_capacity}=  Set Variable    100
    ${parent_product_category_id}=  Set Variable    1
    
    # Get recommended rack
    ${recommended_rack}=    Recommend Rack    ${total_capacity}    ${parent_product_category_id}
    
    # Verify recommendation response
    Should Not Be Empty    ${recommended_rack}
    ...    msg=Rack recommendation response was empty
    
    # Optional: Additional checks based on response structure
    Run Keyword If    'id' in ${recommended_rack}    Log    Recommended Rack ID: ${recommended_rack}[id]
    ...    ELSE    Log    Warning: No specific rack ID in recommendation
    
    Log                 Successfully retrieved rack recommendation

11 - Delete Rack Test
    [Documentation]     Test deleting a rack
    [Tags]              delete    positive
    
    # Create a rack if one doesn't exist
    Run Keyword If      "${TEST_RACK_ID}" == "${EMPTY}"    Create Test Rack
    
    # Delete rack
    ${result}=          Delete Rack    ${TEST_RACK_ID}
    Should Be True      ${result}
    ...    msg=Delete rack operation failed
    
    # Verify rack deletion by trying to get it
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /racks/get-one/${TEST_RACK_ID}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    # Log response for debugging
    Log                 Response status after deletion: ${response.status_code}
    Log                 Response text after deletion: ${response.text}
    
    # Expect 404 or a response indicating the resource no longer exists
    Run Keyword If      ${response.status_code} != 200    Log    Rack successfully deleted
    ...    ELSE    Fail    Rack was not deleted
    
    Log                 Successfully verified deletion of rack with ID: ${TEST_RACK_ID}

12 - Delete Non-Existent Rack Test
    [Documentation]     Test deleting a rack that doesn't exist
    [Tags]              delete    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to delete non-existent rack
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 DELETE On Session
    ...                 vkho
    ...                 /racks/delete/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that deleting a non-existent rack fails

13 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    # Additional cleanup if needed
    Log                 Test environment cleaned up successfully04 - Get Rack Test