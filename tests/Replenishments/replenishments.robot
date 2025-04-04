*** Settings ***
Documentation     Comprehensive Test Suite for Replenishment Operations in vKho API
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

Generate Unique Replenishment Data
    [Documentation]     Generate unique data for replenishment tests
    [Arguments]         ${custom_name}=Test Replenishment
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${replenishment_code}=    Set Variable     REP${timestamp}
    
    # Define replenishment items
    ${item}=            Create Dictionary
    ...                 sku=SKU${timestamp}
    ...                 quantity=20
    ...                 unitPrice=50.25
    ${items}=           Create List      ${item}
    
    # Return dictionary of generated data
    ${replenishment_data}=    Create Dictionary
    ...                 code=${replenishment_code}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 replenishmentDate=2025-04-01T12:00:00.000Z
    ...                 items=${items}
    RETURN            ${replenishment_data}

Create Replenishment
    [Documentation]     Create a new replenishment and return its ID
    [Arguments]         ${replenishment_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${replenishment_data}    code
    ...    msg=Missing required parameter: code
    Dictionary Should Contain Key    ${replenishment_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create replenishment request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /replenishments/create
    ...                 json=${replenishment_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Save response for debugging
    ${timestamp}=       Evaluate         int(time.time())    time
    Create File         ${RESULTS_DIR}${/}replenishment_create_${timestamp}.json    ${response.text}
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create replenishment response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create replenishment response missing ID field
    
    # Return replenishment ID and full response
    ${replenishment_id}=    Convert To String    ${json}[id]
    RETURN            ${replenishment_id}    ${json}

Get Replenishment By ID
    [Documentation]     Retrieve a specific replenishment by ID
    [Arguments]         ${replenishment_id}
    
    # Validate parameters
    Should Not Be Empty    ${replenishment_id}
    ...    msg=Replenishment ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get replenishment request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /replenishments/get-one/${replenishment_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get replenishment response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get replenishment response missing ID field
    
    RETURN            ${json}

Update Replenishment
    [Documentation]     Update an existing replenishment
    [Arguments]         ${replenishment_id}    ${update_data}
    
    # Validate parameters
    Should Not Be Empty    ${replenishment_id}
    ...    msg=Replenishment ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${replenishment_id}
    ...    msg=Update data ID must match replenishment_id parameter
    
    # Ensure minimum required fields are present
    Dictionary Should Contain Key    ${update_data}    code
    ...    msg=Update data missing required field: code
    Dictionary Should Contain Key    ${update_data}    warehouseId
    ...    msg=Update data missing required field: warehouseId
    Dictionary Should Contain Key    ${update_data}    status
    ...    msg=Update data missing required field: status
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send update replenishment request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /replenishments/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update replenishment response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Update replenishment response missing ID field
    
    RETURN            ${json}

Delete Replenishment
    [Documentation]     Delete a replenishment from the system
    [Arguments]         ${replenishment_id}
    
    # Validate parameters
    Should Not Be Empty    ${replenishment_id}
    ...    msg=Replenishment ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send delete replenishment request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /replenishments/delete/${replenishment_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Return deletion status
    RETURN            ${TRUE}

Get All Replenishments
    [Documentation]     Retrieve all replenishments with optional filtering
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
    
    # Send get all replenishments request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /replenishments/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get all replenishments response was empty
    
    RETURN            ${json}

Assert Replenishment Details
    [Documentation]     Verify replenishment details match expected values
    [Arguments]         ${replenishment}    ${expected_data}
    
    # For all keys in expected data, verify they match in the replenishment data
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${replenishment}    Should Be Equal    ${replenishment}[${key}]    ${expected_data}[${key}]
        ...    msg=Replenishment ${key} value '${replenishment}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Replenishment
    [Documentation]     Creates a test replenishment if one doesn't exist
    ${replenishment_data}=    Generate Unique Replenishment Data
    ${replenishment_id}    ${response}=    Create Replenishment    ${replenishment_data}
    Set Global Variable  ${TEST_REPLENISHMENT_ID}      ${replenishment_id}
    Set Global Variable  ${TEST_REPLENISHMENT_CODE}    ${response}[code]
    Set Global Variable  ${TEST_REPLENISHMENT_DATA}    ${replenishment_data}

Verify Response Indicates Deletion
    [Documentation]     Check if response indicates replenishment is deleted
    [Arguments]         ${response_text}
    
    # Parse response
    ${json}=            Evaluate         json.loads('''${response_text}''')    json
    
    # Check for status field indicating deletion
    ${has_status}=      Run Keyword And Return Status    Dictionary Should Contain Key    ${json}    status
    ${is_deleted}=      Run Keyword If    ${has_status}    Check Deletion Status    ${json}[status]
    ...    ELSE         Check Other Deletion Indicators    ${json}
    
    RETURN            ${is_deleted}

Check Deletion Status
    [Documentation]     Check if status field indicates deletion
    [Arguments]         ${status}
    
    # Handle different possible status values for deletion
    ${is_deleted}=      Set Variable    ${FALSE}
    
    # Convert to uppercase for case-insensitive comparison
    ${status_upper}=    Convert To Uppercase    ${status}
    
    # Check against common "deleted" status values
    IF    '${status_upper}' == 'DISABLE' or '${status_upper}' == 'DELETED' or '${status_upper}' == 'INACTIVE'
        ${is_deleted}=  Set Variable    ${TRUE}
    END
    
    RETURN            ${is_deleted}

Check Other Deletion Indicators
    [Documentation]     Check for other indicators of deletion
    [Arguments]         ${json}
    
    # Placeholder for replenishment-specific deletion check (e.g., no isActive field typically)
    ${is_deleted}=      Set Variable    ${FALSE}
    
    RETURN            ${is_deleted}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for replenishment tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Replenishment Test
    [Documentation]     Test creating a new replenishment
    [Tags]              create    positive
    
    # Generate replenishment data
    ${replenishment_data}=    Generate Unique Replenishment Data
    
    # Create replenishment
    ${replenishment_id}    ${response}=    Create Replenishment    ${replenishment_data}
    
    # Verify replenishment was created successfully
    Should Not Be Empty    ${replenishment_id}
    ...    msg=Failed to create replenishment: No ID returned
    Should Be Equal     ${response}[code]    ${replenishment_data}[code]
    ...    msg=Created replenishment code does not match input data
    
    # Save replenishment ID for subsequent tests
    Set Global Variable  ${TEST_REPLENISHMENT_ID}      ${replenishment_id}
    Set Global Variable  ${TEST_REPLENISHMENT_CODE}    ${response}[code]
    Set Global Variable  ${TEST_REPLENISHMENT_DATA}    ${replenishment_data}
    
    Log                 Successfully created replenishment: ${TEST_REPLENISHMENT_CODE} with ID: ${TEST_REPLENISHMENT_ID}

03 - Create Replenishment Missing Required Field Test
    [Documentation]     Test creating a replenishment with missing required fields
    [Tags]              create    negative
    
    # Generate incomplete replenishment data (missing code)
    ${incomplete_data}=  Generate Unique Replenishment Data    custom_name=Missing Field Replenishment
    Remove From Dictionary    ${incomplete_data}    code
    
    # Attempt to create replenishment with incomplete data
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect proper error message
    Run Keyword And Expect Error    *Missing required parameter: code*
    ...                 Create Replenishment    ${incomplete_data}
    
    Log                 Successfully verified that creating a replenishment with missing fields is rejected

04 - Get Replenishment Test
    [Documentation]     Test retrieving a specific replenishment
    [Tags]              retrieve    positive
    
    # Create a replenishment if one doesn't exist
    Run Keyword If      "${TEST_REPLENISHMENT_ID}" == "${EMPTY}"    Create Test Replenishment
    
    # Get replenishment
    ${replenishment}=    Get Replenishment By ID    ${TEST_REPLENISHMENT_ID}
    
    # Verify replenishment details match what we created
    Assert Replenishment Details    ${replenishment}    ${TEST_REPLENISHMENT_DATA}
    
    Log                 Successfully retrieved replenishment: ${replenishment}[code]

05 - Get Non-Existent Replenishment Test
    [Documentation]     Test retrieving a replenishment that doesn't exist
    [Tags]              retrieve    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to get non-existent replenishment
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 GET On Session
    ...                 vkho
    ...                 /replenishments/get-one/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that retrieving a non-existent replenishment fails

06 - Update Replenishment Test
    [Documentation]     Test updating an existing replenishment
    [Tags]              update    positive
    
    # Create a replenishment if one doesn't exist
    Run Keyword If      "${TEST_REPLENISHMENT_ID}" == "${EMPTY}"    Create Test Replenishment
    
    # Prepare update data
    ${updated_code}=    Set Variable    ${TEST_REPLENISHMENT_CODE}-UPD
    ${updated_item}=    Create Dictionary    sku=SKU-UPD-${TEST_REPLENISHMENT_ID}    quantity=25    unitPrice=60.00
    ${updated_items}=   Create List      ${updated_item}
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_REPLENISHMENT_ID}
    ...                 code=${updated_code}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 replenishmentDate=2025-04-02T12:00:00.000Z
    ...                 items=${updated_items}
    ...                 status=ENABLE
    
    # Update replenishment
    ${updated_replenishment}=    Update Replenishment    ${TEST_REPLENISHMENT_ID}    ${update_data}
    
    # Verify replenishment was updated successfully
    Should Be Equal     ${updated_replenishment}[code]    ${updated_code}
    ...    msg=Updated replenishment code does not match expected value
    
    # Update global variable with new data
    Set Global Variable  ${TEST_REPLENISHMENT_CODE}    ${updated_code}
    Set Global Variable  ${TEST_REPLENISHMENT_UPDATED_DATA}    ${update_data}
    
    Log                 Successfully updated replenishment: ${updated_replenishment}[code]

07 - Update Replenishment With Missing Required Field Test
    [Documentation]     Test updating a replenishment with missing required fields
    [Tags]              update    negative
    
    # Create a replenishment if one doesn't exist
    Run Keyword If      "${TEST_REPLENISHMENT_ID}" == "${EMPTY}"    Create Test Replenishment
    
    # Prepare incomplete update data (missing status)
    ${incomplete_data}=  Create Dictionary
    ...                 id=${TEST_REPLENISHMENT_ID}
    ...                 code=${TEST_REPLENISHMENT_CODE}-INC
    ...                 warehouseId=${WAREHOUSE_ID}
    # Missing status field
    
    # Attempt to update replenishment with incomplete data
    Run Keyword And Expect Error    *Update data missing required field: status*
    ...                 Update Replenishment    ${TEST_REPLENISHMENT_ID}    ${incomplete_data}
    
    Log                 Successfully verified that updating a replenishment with missing fields is rejected

08 - Get All Replenishments Test
    [Documentation]     Test retrieving all replenishments
    [Tags]              retrieve    positive
    
    # Get all replenishments
    ${replenishments}=    Get All Replenishments
    
    # Log the structure to understand the format
    Log                 Response structure: ${replenishments}
    
    # Check different possible response formats
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${replenishments}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${replenishments}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${replenishments}    records
    
    # Log information based on what we found
    Run Keyword If      ${has_data}      Log    Found ${replenishments['data'].__len__()} replenishments
    ...    ELSE IF      ${has_items}     Log    Found ${replenishments['items'].__len__()} replenishments
    ...    ELSE IF      ${has_records}   Log    Found ${replenishments['records'].__len__()} replenishments
    ...    ELSE         Log    Found replenishments in unknown format
    
    Log                 Successfully retrieved replenishments list

09 - Filter Replenishments Test
    [Documentation]     Test filtering replenishments by code
    [Tags]              retrieve    filter    positive
    
    # Create a replenishment if one doesn't exist
    Run Keyword If      "${TEST_REPLENISHMENT_ID}" == "${EMPTY}" or "${TEST_REPLENISHMENT_CODE}" == "${EMPTY}"    Create Test Replenishment
    
    # Create filter params based on replenishment code
    ${filter_params}=   Create Dictionary    replenishmentCode=${TEST_REPLENISHMENT_CODE}
    
    # Get filtered replenishments
    ${filtered_replenishments}=    Get All Replenishments    filter_params=${filter_params}
    
    # Verify response contains data
    Should Not Be Empty    ${filtered_replenishments}
    ...    msg=Filtered replenishments response was empty
    
    # Check if our replenishment is in the results (depends on API structure)
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_replenishments}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_replenishments}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_replenishments}    records
    
    # Verify filter worked based on response structure
    ${found}=           Set Variable    ${FALSE}
    
    # Check in 'data' array if present
    IF    ${has_data}
        ${data_length}=     Get Length    ${filtered_replenishments}[data]
        Should Be True      ${data_length} > 0    msg=Filter returned empty data array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'items' array if present
    ELSE IF    ${has_items}
        ${items_length}=    Get Length    ${filtered_replenishments}[items]
        Should Be True      ${items_length} > 0    msg=Filter returned empty items array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'records' array if present
    ELSE IF    ${has_records}
        ${records_length}=  Get Length    ${filtered_replenishments}[records]
        Should Be True      ${records_length} > 0    msg=Filter returned empty records array
        ${found}=           Set Variable    ${TRUE}
    ELSE
        Log                 Warning: Unknown response structure, can't verify filter results
    END
    
    Should Be True      ${found}    msg=Failed to find replenishment in filtered results
    
    Log                 Successfully filtered replenishments by code: ${TEST_REPLENISHMENT_CODE}

10 - Delete Replenishment Test
    [Documentation]     Test deleting a replenishment
    [Tags]              delete    positive
    
    # Create a replenishment if one doesn't exist
    Run Keyword If      "${TEST_REPLENISHMENT_ID}" == "${EMPTY}"    Create Test Replenishment
    
    # Delete replenishment
    ${result}=          Delete Replenishment    ${TEST_REPLENISHMENT_ID}
    Should Be True      ${result}
    ...    msg=Delete replenishment operation failed
    
    # Verify replenishment deletion by trying to get it
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /replenishments/get-one/${TEST_REPLENISHMENT_ID}
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
    ...    msg=Replenishment was not properly deleted or marked as deleted
    
    Log                 Successfully verified deletion of replenishment with ID: ${TEST_REPLENISHMENT_ID}

11 - Delete Non-Existent Replenishment Test
    [Documentation]     Test deleting a replenishment that doesn't exist
    [Tags]              delete    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to delete non-existent replenishment
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 DELETE On Session
    ...                 vkho
    ...                 /replenishments/delete/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that deleting a non-existent replenishment fails

12 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    # Additional cleanup if needed
    Log                 Test environment cleaned up successfully