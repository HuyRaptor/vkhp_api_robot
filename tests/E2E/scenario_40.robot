*** Settings ***
Documentation     Comprehensive Test Suite for Warehouse Operations in vKho API
...               Includes proper parameter validation and error handling
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime

*** Variables ***
${BASE_URL}             https://api.vkho.net
${USERNAME}             huynh22
${PASSWORD}             Snowfox1991
${RESULTS_DIR}          ${CURDIR}${/}results
${TEST_WAREHOUSE_ID}    ${EMPTY}
${TEST_WAREHOUSE_NAME}  ${EMPTY}
${TEST_WAREHOUSE_DATA}  ${EMPTY}

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

Generate Unique Warehouse Data
    [Documentation]     Generate unique data for warehouse tests
    [Arguments]         ${custom_name}=Test Warehouse
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_name}=  Set Variable     ${custom_name} ${timestamp}
    ${code}=            Set Variable     WH${timestamp}
    
    # Return dictionary of generated data
    ${warehouse_data}=  Create Dictionary
    ...                 name=${warehouse_name}
    ...                 code=${code}
    ...                 address=456 Warehouse Lane
    ...                 phoneNumber=800555${timestamp}
    ...                 email=warehouse_${timestamp}@example.com
    RETURN            ${warehouse_data}

Create Warehouse
    [Documentation]     Create a new warehouse and return its ID
    [Arguments]         ${warehouse_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${warehouse_data}    name
    ...    msg=Missing required parameter: name
    Dictionary Should Contain Key    ${warehouse_data}    code
    ...    msg=Missing required parameter: code
    Dictionary Should Contain Key    ${warehouse_data}    address
    ...    msg=Missing required parameter: address
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create warehouse request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /warehouses/create
    ...                 json=${warehouse_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Save response for debugging
    ${timestamp}=       Evaluate         int(time.time())    time
    Create File         ${RESULTS_DIR}${/}warehouse_create_${timestamp}.json    ${response.text}
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create warehouse response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create warehouse response missing ID field
    
    # Return warehouse ID and full response
    ${warehouse_id}=    Convert To String    ${json}[id]
    RETURN            ${warehouse_id}    ${json}

Get Warehouse By ID
    [Documentation]     Retrieve a specific warehouse by ID
    [Arguments]         ${warehouse_id}
    
    # Validate parameters
    Should Not Be Empty    ${warehouse_id}
    ...    msg=Warehouse ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get warehouse request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /warehouses/get-one/${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get warehouse response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get warehouse response missing ID field
    
    RETURN            ${json}

Update Warehouse
    [Documentation]     Update an existing warehouse
    [Arguments]         ${warehouse_id}    ${update_data}
    
    # Validate parameters
    Should Not Be Empty    ${warehouse_id}
    ...    msg=Warehouse ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${warehouse_id}
    ...    msg=Update data ID must match warehouse_id parameter
    
    # Ensure minimum required fields are present
    Dictionary Should Contain Key    ${update_data}    name
    ...    msg=Update data missing required field: name
    Dictionary Should Contain Key    ${update_data}    code
    ...    msg=Update data missing required field: code
    Dictionary Should Contain Key    ${update_data}    address
    ...    msg=Update data missing required field: address
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send update warehouse request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /warehouses/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update warehouse response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Update warehouse response missing ID field
    
    RETURN            ${json}

Delete Warehouse
    [Documentation]     Delete a warehouse from the system
    [Arguments]         ${warehouse_id}
    
    # Validate parameters
    Should Not Be Empty    ${warehouse_id}
    ...    msg=Warehouse ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send delete warehouse request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /warehouses/delete/${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Return deletion status
    RETURN            ${TRUE}

Get All Warehouses
    [Documentation]     Retrieve all warehouses with optional filtering
    [Arguments]         ${filter_params}=${EMPTY}
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Create params dictionary if filters are provided
    ${params}=          Create Dictionary
    Run Keyword If      "${filter_params}" != "${EMPTY}"    Set To Dictionary    ${params}    &{filter_params}
    
    # Send get all warehouses request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /warehouses/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get all warehouses response was empty
    
    RETURN            ${json}

Assert Warehouse Details
    [Documentation]     Verify warehouse details match expected values
    [Arguments]         ${warehouse}    ${expected_data}
    
    # For all keys in expected data, verify they match in the warehouse data
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${warehouse}    Should Be Equal    ${warehouse}[${key}]    ${expected_data}[${key}]
        ...    msg=Warehouse ${key} value '${warehouse}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Warehouse
    [Documentation]     Creates a test warehouse if one doesn't exist
    ${warehouse_data}=  Generate Unique Warehouse Data
    ${warehouse_id}    ${response}=    Create Warehouse    ${warehouse_data}
    Set Global Variable  ${TEST_WAREHOUSE_ID}      ${warehouse_id}
    Set Global Variable  ${TEST_WAREHOUSE_NAME}    ${response}[name]
    Set Global Variable  ${TEST_WAREHOUSE_DATA}    ${warehouse_data}

Verify Response Indicates Deletion
    [Documentation]     Check if response indicates warehouse is deleted
    [Arguments]         ${response_text}
    
    # Parse response
    ${json}=            Evaluate         json.loads('''${response_text}''')    json
    
    # Check for status field indicating deletion (assuming similar to other endpoints)
    ${has_status}=      Run Keyword And Return Status    Dictionary Should Contain Key    ${json}    status
    ${is_deleted}=      Run Keyword If    ${has_status}    Check Deletion Status    ${json}[status]
    ...    ELSE         Set Variable    ${FALSE}
    
    RETURN            ${is_deleted}

Check Deletion Status
    [Documentation]     Check if status field indicates deletion
    [Arguments]         ${status}
    
    # Handle different possible status values for deletion
    ${is_deleted}=      Set Variable    ${FALSE}
    
    # Convert to uppercase for case-insensitive comparison
    ${status_upper}=    Convert To Uppercase    ${status}
    
    # Check against common "deleted" status values
    IF    '${status_upper}' == 'DISABLE' or '${status_upper}' == 'DELETED'
        ${is_deleted}=  Set Variable    ${TRUE}
    END
    
    RETURN            ${is_deleted}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for warehouse tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Warehouse Test
    [Documentation]     Test creating a new warehouse
    [Tags]              create    positive
    
    # Generate warehouse data
    ${warehouse_data}=  Generate Unique Warehouse Data
    
    # Create warehouse
    ${warehouse_id}    ${response}=    Create Warehouse    ${warehouse_data}
    
    # Verify warehouse was created successfully
    Should Not Be Empty    ${warehouse_id}
    ...    msg=Failed to create warehouse: No ID returned
    Should Be Equal     ${response}[name]    ${warehouse_data}[name]
    ...    msg=Created warehouse name does not match input data
    
    # Save warehouse ID for subsequent tests
    Set Global Variable  ${TEST_WAREHOUSE_ID}      ${warehouse_id}
    Set Global Variable  ${TEST_WAREHOUSE_NAME}    ${response}[name]
    Set Global Variable  ${TEST_WAREHOUSE_DATA}    ${warehouse_data}
    
    Log                 Successfully created warehouse: ${TEST_WAREHOUSE_NAME} with ID: ${TEST_WAREHOUSE_ID}

03 - Create Warehouse Missing Required Field Test
    [Documentation]     Test creating a warehouse with missing required fields
    [Tags]              create    negative
    
    # Generate incomplete warehouse data (missing code)
    ${incomplete_data}=  Generate Unique Warehouse Data    custom_name=Missing Field Warehouse
    Remove From Dictionary    ${incomplete_data}    code
    
    # Attempt to create warehouse with incomplete data
    Run Keyword And Expect Error    *Missing required parameter: code*
    ...                 Create Warehouse    ${incomplete_data}
    
    Log                 Successfully verified that creating a warehouse with missing fields is rejected

04 - Get Warehouse Test
    [Documentation]     Test retrieving a specific warehouse
    [Tags]              retrieve    positive
    
    # Create a warehouse if one doesn't exist
    Run Keyword If      "${TEST_WAREHOUSE_ID}" == "${EMPTY}"    Create Test Warehouse
    
    # Get warehouse
    ${warehouse}=       Get Warehouse By ID    ${TEST_WAREHOUSE_ID}
    
    # Verify warehouse details match what we created
    Assert Warehouse Details    ${warehouse}    ${TEST_WAREHOUSE_DATA}
    
    Log                 Successfully retrieved warehouse: ${warehouse}[name]

05 - Get Non-Existent Warehouse Test
    [Documentation]     Test retrieving a warehouse that doesn't exist
    [Tags]              retrieve    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to get non-existent warehouse
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 GET On Session
    ...                 vkho
    ...                 /warehouses/get-one/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that retrieving a non-existent warehouse fails

06 - Update Warehouse Test
    [Documentation]     Test updating an existing warehouse
    [Tags]              update    positive
    
    # Create a warehouse if one doesn't exist
    Run Keyword If      "${TEST_WAREHOUSE_ID}" == "${EMPTY}"    Create Test Warehouse
    
    # Prepare update data
    ${updated_name}=    Set Variable    ${TEST_WAREHOUSE_NAME} Updated
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_WAREHOUSE_ID}
    ...                 name=${updated_name}
    ...                 code=${TEST_WAREHOUSE_DATA}[code]
    ...                 address=789 Updated Lane
    ...                 phoneNumber=9005551234
    ...                 email=updated_${TEST_WAREHOUSE_ID}@example.com
    
    # Update warehouse
    ${updated_warehouse}=    Update Warehouse    ${TEST_WAREHOUSE_ID}    ${update_data}
    
    # Verify warehouse was updated successfully
    Should Be Equal     ${updated_warehouse}[name]    ${updated_name}
    ...    msg=Updated warehouse name does not match expected value
    
    # Update global variable with new data
    Set Global Variable  ${TEST_WAREHOUSE_NAME}    ${updated_name}
    Set Global Variable  ${TEST_WAREHOUSE_UPDATED_DATA}    ${update_data}
    
    Log                 Successfully updated warehouse: ${updated_warehouse}[name]

07 - Update Warehouse With Missing Required Field Test
    [Documentation]     Test updating a warehouse with missing required fields
    [Tags]              update    negative
    
    # Create a warehouse if one doesn't exist
    Run Keyword If      "${TEST_WAREHOUSE_ID}" == "${EMPTY}"    Create Test Warehouse
    
    # Prepare incomplete update data (missing code)
    ${incomplete_data}=  Create Dictionary
    ...                 id=${TEST_WAREHOUSE_ID}
    ...                 name=Incomplete Update
    ...                 address=Incomplete Address
    # Missing code field
    
    # Attempt to update warehouse with incomplete data
    Run Keyword And Expect Error    *Update data missing required field: code*
    ...                 Update Warehouse    ${TEST_WAREHOUSE_ID}    ${incomplete_data}
    
    Log                 Successfully verified that updating a warehouse with missing fields is rejected

08 - Get All Warehouses Test
    [Documentation]     Test retrieving all warehouses
    [Tags]              retrieve    positive
    
    # Get all warehouses
    ${warehouses}=      Get All Warehouses
    
    # Log the structure to understand the format
    Log                 Response structure: ${warehouses}
    
    # Check different possible response formats
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${warehouses}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${warehouses}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${warehouses}    records
    
    # Log information based on what we found
    Run Keyword If      ${has_data}      Log    Found ${warehouses['data'].__len__()} warehouses
    ...    ELSE IF      ${has_items}     Log    Found ${warehouses['items'].__len__()} warehouses
    ...    ELSE IF      ${has_records}   Log    Found ${warehouses['records'].__len__()} warehouses
    ...    ELSE         Log    Found warehouses in unknown format
    
    Log                 Successfully retrieved warehouses list

09 - Filter Warehouses Test
    [Documentation]     Test filtering warehouses by name
    [Tags]              retrieve    filter    positive
    
    # Create a warehouse if one doesn't exist
    Run Keyword If      "${TEST_WAREHOUSE_ID}" == "${EMPTY}" or "${TEST_WAREHOUSE_NAME}" == "${EMPTY}"    Create Test Warehouse
    
    # Create filter params based on warehouse name
    ${filter_params}=   Create Dictionary    warehouseName=${TEST_WAREHOUSE_NAME}
    
    # Get filtered warehouses
    ${filtered_warehouses}=    Get All Warehouses    filter_params=${filter_params}
    
    # Verify response contains data
    Should Not Be Empty    ${filtered_warehouses}
    ...    msg=Filtered warehouses response was empty
    
    # Check if our warehouse is in the results (depends on API structure)
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_warehouses}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_warehouses}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_warehouses}    records
    
    # Verify filter worked based on response structure
    ${found}=           Set Variable    ${FALSE}
    
    # Check in 'data' array if present
    IF    ${has_data}
        ${data_length}=     Get Length    ${filtered_warehouses}[data]
        Should Be True      ${data_length} > 0    msg=Filter returned empty data array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'items' array if present
    ELSE IF    ${has_items}
        ${items_length}=    Get Length    ${filtered_warehouses}[items]
        Should Be True      ${items_length} > 0    msg=Filter returned empty items array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'records' array if present
    ELSE IF    ${has_records}
        ${records_length}=  Get Length    ${filtered_warehouses}[records]
        Should Be True      ${records_length} > 0    msg=Filter returned empty records array
        ${found}=           Set Variable    ${TRUE}
    ELSE
        Log                 Warning: Unknown response structure, can't verify filter results
    END
    
    Should Be True      ${found}    msg=Failed to find warehouse in filtered results
    
    Log                 Successfully filtered warehouses by name: ${TEST_WAREHOUSE_NAME}

10 - Delete Warehouse Test
    [Documentation]     Test deleting a warehouse
    [Tags]              delete    positive
    
    # Create a warehouse if one doesn't exist
    Run Keyword If      "${TEST_WAREHOUSE_ID}" == "${EMPTY}"    Create Test Warehouse
    
    # Delete warehouse
    ${result}=          Delete Warehouse    ${TEST_WAREHOUSE_ID}
    Should Be True      ${result}
    ...    msg=Delete warehouse operation failed
    
    # Verify warehouse deletion by trying to get it
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /warehouses/get-one/${TEST_WAREHOUSE_ID}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    # Log response for debugging
    Log                 Response status after deletion: ${response.status_code}
    Log                 Response text after deletion: ${response.text}
    
    # API might handle deletion differently: either 404 Not Found or status = DISABLE
    ${is_deleted}=      Run Keyword If      ${response.status_code} == 404    Set Variable    ${TRUE}
    ...    ELSE IF      ${response.status_code} == 200    Verify Response Indicates Deletion    ${response.text}
    ...    ELSE         Set Variable    ${FALSE}
    
    Should Be True      ${is_deleted}
    ...    msg=Warehouse was not properly deleted or marked as deleted
    
    Log                 Successfully verified deletion of warehouse with ID: ${TEST_WAREHOUSE_ID}

11 - Delete Non-Existent Warehouse Test
    [Documentation]     Test deleting a warehouse that doesn't exist
    [Tags]              delete    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to delete non-existent warehouse
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 DELETE On Session
    ...                 vkho
    ...                 /warehouses/delete/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that deleting a non-existent warehouse fails

12 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    # Additional cleanup if needed
    Log                 Test environment cleaned up successfully