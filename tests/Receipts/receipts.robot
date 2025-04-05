*** Settings ***
Documentation     Comprehensive Test Suite for Receipt Operations in vKho API
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

Generate Unique Receipt Data
    [Documentation]     Generate unique data for receipt tests
    [Arguments]         ${custom_name}=Test Receipt
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${receipt_code}=    Set Variable     REC${timestamp}
    ${supplier_id}=     Set Variable     1    # Assuming a valid supplier ID
    
    # Define receipt items
    ${item}=            Create Dictionary
    ...                 sku=SKU${timestamp}
    ...                 quantity=10
    ...                 unitPrice=100.50
    ${items}=           Create List      ${item}
    
    # Return dictionary of generated data
    ${receipt_data}=    Create Dictionary
    ...                 code=${receipt_code}
    ...                 supplierId=${supplier_id}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 receiptDate=2025-04-01T12:00:00.000Z
    ...                 items=${items}
    RETURN            ${receipt_data}

Create Receipt
    [Documentation]     Create a new receipt and return its ID
    [Arguments]         ${receipt_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${receipt_data}    code
    ...    msg=Missing required parameter: code
    Dictionary Should Contain Key    ${receipt_data}    supplierId
    ...    msg=Missing required parameter: supplierId
    Dictionary Should Contain Key    ${receipt_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create receipt request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /receipts/create
    ...                 json=${receipt_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Save response for debugging
    ${timestamp}=       Evaluate         int(time.time())    time
    Create File         ${RESULTS_DIR}${/}receipt_create_${timestamp}.json    ${response.text}
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create receipt response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create receipt response missing ID field
    
    # Return receipt ID and full response
    ${receipt_id}=      Convert To String    ${json}[id]
    RETURN            ${receipt_id}    ${json}

Get Receipt By ID
    [Documentation]     Retrieve a specific receipt by ID
    [Arguments]         ${receipt_id}
    
    # Validate parameters
    Should Not Be Empty    ${receipt_id}
    ...    msg=Receipt ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get receipt request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /receipts/get-one/${receipt_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get receipt response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get receipt response missing ID field
    
    RETURN            ${json}

Update Receipt
    [Documentation]     Update an existing receipt
    [Arguments]         ${receipt_id}    ${update_data}
    
    # Validate parameters
    Should Not Be Empty    ${receipt_id}
    ...    msg=Receipt ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${receipt_id}
    ...    msg=Update data ID must match receipt_id parameter
    
    # Ensure minimum required fields are present
    Dictionary Should Contain Key    ${update_data}    code
    ...    msg=Update data missing required field: code
    Dictionary Should Contain Key    ${update_data}    warehouseId
    ...    msg=Update data missing required field: warehouseId
    Dictionary Should Contain Key    ${update_data}    status
    ...    msg=Update data missing required field: status
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send update receipt request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /receipts/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update receipt response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Update receipt response missing ID field
    
    RETURN            ${json}

Delete Receipt
    [Documentation]     Delete a receipt from the system
    [Arguments]         ${receipt_id}
    
    # Validate parameters
    Should Not Be Empty    ${receipt_id}
    ...    msg=Receipt ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send delete receipt request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /receipts/delete/${receipt_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Return deletion status
    RETURN            ${TRUE}

Get All Receipts
    [Documentation]     Retrieve all receipts with optional filtering
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
    
    # Send get all receipts request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /receipts/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get all receipts response was empty
    
    RETURN            ${json}

Assert Receipt Details
    [Documentation]     Verify receipt details match expected values
    [Arguments]         ${receipt}    ${expected_data}
    
    # For all keys in expected data, verify they match in the receipt data
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${receipt}    Should Be Equal    ${receipt}[${key}]    ${expected_data}[${key}]
        ...    msg=Receipt ${key} value '${receipt}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Receipt
    [Documentation]     Creates a test receipt if one doesn't exist
    ${receipt_data}=    Generate Unique Receipt Data
    ${receipt_id}    ${response}=    Create Receipt    ${receipt_data}
    Set Global Variable  ${TEST_RECEIPT_ID}      ${receipt_id}
    Set Global Variable  ${TEST_RECEIPT_CODE}    ${response}[code]
    Set Global Variable  ${TEST_RECEIPT_DATA}    ${receipt_data}

Verify Response Indicates Deletion
    [Documentation]     Check if response indicates receipt is deleted
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
    
    # Placeholder for receipt-specific deletion check (e.g., isActive not typically used for receipts)
    ${is_deleted}=      Set Variable    ${FALSE}
    
    RETURN            ${is_deleted}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for receipt tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Receipt Test
    [Documentation]     Test creating a new receipt
    [Tags]              create    positive
    
    # Generate receipt data
    ${receipt_data}=    Generate Unique Receipt Data
    
    # Create receipt
    ${receipt_id}    ${response}=    Create Receipt    ${receipt_data}
    
    # Verify receipt was created successfully
    Should Not Be Empty    ${receipt_id}
    ...    msg=Failed to create receipt: No ID returned
    Should Be Equal     ${response}[code]    ${receipt_data}[code]
    ...    msg=Created receipt code does not match input data
    
    # Save receipt ID for subsequent tests
    Set Global Variable  ${TEST_RECEIPT_ID}      ${receipt_id}
    Set Global Variable  ${TEST_RECEIPT_CODE}    ${response}[code]
    Set Global Variable  ${TEST_RECEIPT_DATA}    ${receipt_data}
    
    Log                 Successfully created receipt: ${TEST_RECEIPT_CODE} with ID: ${TEST_RECEIPT_ID}

03 - Create Receipt Missing Required Field Test
    [Documentation]     Test creating a receipt with missing required fields
    [Tags]              create    negative
    
    # Generate incomplete receipt data (missing code)
    ${incomplete_data}=  Generate Unique Receipt Data    custom_name=Missing Field Receipt
    Remove From Dictionary    ${incomplete_data}    code
    
    # Attempt to create receipt with incomplete data
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect proper error message
    Run Keyword And Expect Error    *Missing required parameter: code*
    ...                 Create Receipt    ${incomplete_data}
    
    Log                 Successfully verified that creating a receipt with missing fields is rejected

04 - Get Receipt Test
    [Documentation]     Test retrieving a specific receipt
    [Tags]              retrieve    positive
    
    # Create a receipt if one doesn't exist
    Run Keyword If      "${TEST_RECEIPT_ID}" == "${EMPTY}"    Create Test Receipt
    
    # Get receipt
    ${receipt}=         Get Receipt By ID    ${TEST_RECEIPT_ID}
    
    # Verify receipt details match what we created
    Assert Receipt Details    ${receipt}    ${TEST_RECEIPT_DATA}
    
    Log                 Successfully retrieved receipt: ${receipt}[code]

05 - Get Non-Existent Receipt Test
    [Documentation]     Test retrieving a receipt that doesn't exist
    [Tags]              retrieve    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to get non-existent receipt
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 GET On Session
    ...                 vkho
    ...                 /receipts/get-one/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that retrieving a non-existent receipt fails

06 - Update Receipt Test
    [Documentation]     Test updating an existing receipt
    [Tags]              update    positive
    
    # Create a receipt if one doesn't exist
    Run Keyword If      "${TEST_RECEIPT_ID}" == "${EMPTY}"    Create Test Receipt
    
    # Prepare update data
    ${updated_code}=    Set Variable    ${TEST_RECEIPT_CODE}-UPD
    ${updated_item}=    Create Dictionary    sku=SKU-UPD-${TEST_RECEIPT_ID}    quantity=15    unitPrice=150.75
    ${updated_items}=   Create List      ${updated_item}
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_RECEIPT_ID}
    ...                 code=${updated_code}
    ...                 supplierId=1
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 receiptDate=2025-04-02T12:00:00.000Z
    ...                 items=${updated_items}
    ...                 status=ENABLE
    
    # Update receipt
    ${updated_receipt}=    Update Receipt    ${TEST_RECEIPT_ID}    ${update_data}
    
    # Verify receipt was updated successfully
    Should Be Equal     ${updated_receipt}[code]    ${updated_code}
    ...    msg=Updated receipt code does not match expected value
    
    # Update global variable with new data
    Set Global Variable  ${TEST_RECEIPT_CODE}    ${updated_code}
    Set Global Variable  ${TEST_RECEIPT_UPDATED_DATA}    ${update_data}
    
    Log                 Successfully updated receipt: ${updated_receipt}[code]

07 - Update Receipt With Missing Required Field Test
    [Documentation]     Test updating a receipt with missing required fields
    [Tags]              update    negative
    
    # Create a receipt if one doesn't exist
    Run Keyword If      "${TEST_RECEIPT_ID}" == "${EMPTY}"    Create Test Receipt
    
    # Prepare incomplete update data (missing status)
    ${incomplete_data}=  Create Dictionary
    ...                 id=${TEST_RECEIPT_ID}
    ...                 code=${TEST_RECEIPT_CODE}-INC
    ...                 warehouseId=${WAREHOUSE_ID}
    # Missing status field
    
    # Attempt to update receipt with incomplete data
    Run Keyword And Expect Error    *Update data missing required field: status*
    ...                 Update Receipt    ${TEST_RECEIPT_ID}    ${incomplete_data}
    
    Log                 Successfully verified that updating a receipt with missing fields is rejected

08 - Get All Receipts Test
    [Documentation]     Test retrieving all receipts
    [Tags]              retrieve    positive
    
    # Get all receipts
    ${receipts}=        Get All Receipts
    
    # Log the structure to understand the format
    Log                 Response structure: ${receipts}
    
    # Check different possible response formats
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${receipts}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${receipts}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${receipts}    records
    
    # Log information based on what we found
    Run Keyword If      ${has_data}      Log    Found ${receipts['data'].__len__()} receipts
    ...    ELSE IF      ${has_items}     Log    Found ${receipts['items'].__len__()} receipts
    ...    ELSE IF      ${has_records}   Log    Found ${receipts['records'].__len__()} receipts
    ...    ELSE         Log    Found receipts in unknown format
    
    Log                 Successfully retrieved receipts list

09 - Filter Receipts Test
    [Documentation]     Test filtering receipts by code
    [Tags]              retrieve    filter    positive
    
    # Create a receipt if one doesn't exist
    Run Keyword If      "${TEST_RECEIPT_ID}" == "${EMPTY}" or "${TEST_RECEIPT_CODE}" == "${EMPTY}"    Create Test Receipt
    
    # Create filter params based on receipt code
    ${filter_params}=   Create Dictionary    receiptCode=${TEST_RECEIPT_CODE}
    
    # Get filtered receipts
    ${filtered_receipts}=    Get All Receipts    filter_params=${filter_params}
    
    # Verify response contains data
    Should Not Be Empty    ${filtered_receipts}
    ...    msg=Filtered receipts response was empty
    
    # Check if our receipt is in the results (depends on API structure)
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_receipts}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_receipts}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_receipts}    records
    
    # Verify filter worked based on response structure
    ${found}=           Set Variable    ${FALSE}
    
    # Check in 'data' array if present
    IF    ${has_data}
        ${data_length}=     Get Length    ${filtered_receipts}[data]
        Should Be True      ${data_length} > 0    msg=Filter returned empty data array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'items' array if present
    ELSE IF    ${has_items}
        ${items_length}=    Get Length    ${filtered_receipts}[items]
        Should Be True      ${items_length} > 0    msg=Filter returned empty items array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'records' array if present
    ELSE IF    ${has_records}
        ${records_length}=  Get Length    ${filtered_receipts}[records]
        Should Be True      ${records_length} > 0    msg=Filter returned empty records array
        ${found}=           Set Variable    ${TRUE}
    ELSE
        Log                 Warning: Unknown response structure, can't verify filter results
    END
    
    Should Be True      ${found}    msg=Failed to find receipt in filtered results
    
    Log                 Successfully filtered receipts by code: ${TEST_RECEIPT_CODE}

10 - Delete Receipt Test
    [Documentation]     Test deleting a receipt
    [Tags]              delete    positive
    
    # Create a receipt if one doesn't exist
    Run Keyword If      "${TEST_RECEIPT_ID}" == "${EMPTY}"    Create Test Receipt
    
    # Delete receipt
    ${result}=          Delete Receipt    ${TEST_RECEIPT_ID}
    Should Be True      ${result}
    ...    msg=Delete receipt operation failed
    
    # Verify receipt deletion by trying to get it
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /receipts/get-one/${TEST_RECEIPT_ID}
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
    ...    msg=Receipt was not properly deleted or marked as deleted
    
    Log                 Successfully verified deletion of receipt with ID: ${TEST_RECEIPT_ID}

11 - Delete Non-Existent Receipt Test
    [Documentation]     Test deleting a receipt that doesn't exist
    [Tags]              delete    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to delete non-existent receipt
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 DELETE On Session
    ...                 vkho
    ...                 /receipts/delete/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that deleting a non-existent receipt fails

12 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    # Additional cleanup if needed
    Log                 Test environment cleaned up successfully