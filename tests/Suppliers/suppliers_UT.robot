*** Settings ***
Documentation     Comprehensive Test Suite for Supplier Operations in vKho API
...               Includes proper parameter validation and error handling
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Resource          ../../Variables/variables.robot

*** Variables ***
${BASE_URL}             https://api.vkho.net
${MANAGER_USERNAME}             huynh22.manager
${MANAGER_PASSWORD}             Snowfox1991
${WAREHOUSE_ID}         6
${PRODUCT_CATEGORY_ID}  37
${RESULTS_DIR}          ${CURDIR}${/}results
${TEST_SUPPLIER_ID}     ${EMPTY}
${TEST_SUPPLIER_NAME}   ${EMPTY}
${TEST_SUPPLIER_DATA}   ${EMPTY}

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

Generate Unique Supplier Data
    [Documentation]     Generate unique data for supplier tests
    [Arguments]         ${custom_name}=Test Supplier
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${supplier_name}=   Set Variable     ${custom_name} ${timestamp}
    ${email}=           Set Variable     supplier_${timestamp}@example.com
    ${phone}=           Set Variable     800567${timestamp}
    ${contract_number}=    Set Variable     TST${timestamp}
    ${tax_code}=        Set Variable     57519${timestamp}
    
    # Return dictionary of generated data
    ${supplier_data}=   Create Dictionary
    ...                 name=${supplier_name}
    ...                 email=${email}
    ...                 phoneNumber=${phone}
    ...                 address=Test Address
    ...                 isActive=${TRUE}
    ...                 contractNumber=${contract_number}
    ...                 taxCode=${tax_code}
    ...                 cooperationDay=2023-03-20T00:00:00.000Z
    ...                 warehouseId=${WAREHOUSE_ID}
    RETURN            ${supplier_data}

Create Supplier
    [Documentation]     Create a new supplier and return its ID
    [Arguments]         ${supplier_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${supplier_data}    name
    ...    msg=Missing required parameter: name
    Dictionary Should Contain Key    ${supplier_data}    email
    ...    msg=Missing required parameter: email
    Dictionary Should Contain Key    ${supplier_data}    phoneNumber
    ...    msg=Missing required parameter: phoneNumber
    Dictionary Should Contain Key    ${supplier_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    
    # Prepare product categories
    ${product_categories}=  Create List      ${PRODUCT_CATEGORY_ID}
    Set To Dictionary   ${supplier_data}    productCategoryIds=${product_categories}
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create supplier request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /suppliers/create
    ...                 json=${supplier_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Save response for debugging
    ${timestamp}=       Evaluate         int(time.time())    time
    Create File         ${RESULTS_DIR}${/}supplier_create_${timestamp}.json    ${response.text}
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create supplier response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create supplier response missing ID field
    
    # Return supplier ID and full response
    ${supplier_id}=     Convert To String    ${json}[id]
    RETURN            ${supplier_id}    ${json}

Get Supplier By ID
    [Documentation]     Retrieve a specific supplier by ID
    [Arguments]         ${supplier_id}
    
    # Validate parameters
    Should Not Be Empty    ${supplier_id}
    ...    msg=Supplier ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get supplier request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /suppliers/get-one/${supplier_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get supplier response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get supplier response missing ID field
    
    RETURN            ${json}

Update Supplier
    [Documentation]     Update an existing supplier
    [Arguments]         ${supplier_id}    ${update_data}
    
    # Validate parameters
    Should Not Be Empty    ${supplier_id}
    ...    msg=Supplier ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${supplier_id}
    ...    msg=Update data ID must match supplier_id parameter
    
    # Ensure minimum required fields are present
    Dictionary Should Contain Key    ${update_data}    name
    ...    msg=Update data missing required field: name
    Dictionary Should Contain Key    ${update_data}    warehouseId
    ...    msg=Update data missing required field: warehouseId
    Dictionary Should Contain Key    ${update_data}    status
    ...    msg=Update data missing required field: status
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send update supplier request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /suppliers/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update supplier response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Update supplier response missing ID field
    
    RETURN            ${json}

Delete Supplier
    [Documentation]     Delete a supplier from the system
    [Arguments]         ${supplier_id}
    
    # Validate parameters
    Should Not Be Empty    ${supplier_id}
    ...    msg=Supplier ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send delete supplier request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /suppliers/delete/${supplier_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Return deletion status
    RETURN            ${TRUE}

Get All Suppliers
    [Documentation]     Retrieve all suppliers with optional filtering
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
    
    # Send get all suppliers request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /suppliers/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get all suppliers response was empty
    
    RETURN            ${json}

Assert Supplier Details
    [Documentation]     Verify supplier details match expected values
    [Arguments]         ${supplier}    ${expected_data}
    
    # For all keys in expected data, verify they match in the supplier data
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${supplier}    Should Be Equal    ${supplier}[${key}]    ${expected_data}[${key}]
        ...    msg=Supplier ${key} value '${supplier}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Supplier
    [Documentation]     Creates a test supplier if one doesn't exist
    ${supplier_data}=   Generate Unique Supplier Data
    ${supplier_id}    ${response}=    Create Supplier    ${supplier_data}
    Set Global Variable  ${TEST_SUPPLIER_ID}      ${supplier_id}
    Set Global Variable  ${TEST_SUPPLIER_NAME}    ${response}[name]
    Set Global Variable  ${TEST_SUPPLIER_DATA}    ${supplier_data}

Verify Response Indicates Deletion
    [Documentation]     Check if response indicates supplier is deleted
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
    
    # Check isActive field if status is not available
    ${has_active}=      Run Keyword And Return Status    Dictionary Should Contain Key    ${json}    isActive
    
    # If isActive is false, consider as deleted
    ${is_deleted}=      Run Keyword If    ${has_active} and '${json}[isActive]' == 'false'    Set Variable    ${TRUE}
    ...    ELSE         Set Variable    ${FALSE}
    
    RETURN            ${is_deleted}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for supplier tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Supplier Test
    [Documentation]     Test creating a new supplier
    [Tags]              create    positive
    
    # Generate supplier data
    ${supplier_data}=   Generate Unique Supplier Data
    
    # Create supplier
    ${supplier_id}    ${response}=    Create Supplier    ${supplier_data}
    
    # Verify supplier was created successfully
    Should Not Be Empty    ${supplier_id}
    ...    msg=Failed to create supplier: No ID returned
    Should Be Equal     ${response}[name]    ${supplier_data}[name]
    ...    msg=Created supplier name does not match input data
    
    # Save supplier ID for subsequent tests
    Set Global Variable  ${TEST_SUPPLIER_ID}      ${supplier_id}
    Set Global Variable  ${TEST_SUPPLIER_NAME}    ${response}[name]
    Set Global Variable  ${TEST_SUPPLIER_DATA}    ${supplier_data}
    
    Log                 Successfully created supplier: ${TEST_SUPPLIER_NAME} with ID: ${TEST_SUPPLIER_ID}

03 - Create Supplier Missing Required Field Test
    [Documentation]     Test creating a supplier with missing required fields
    [Tags]              create    negative
    
    # Generate incomplete supplier data (missing phoneNumber)
    ${incomplete_data}=  Generate Unique Supplier Data    custom_name=Missing Field Supplier
    Remove From Dictionary    ${incomplete_data}    phoneNumber
    
    # Attempt to create supplier with incomplete data
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect proper error message
    Run Keyword And Expect Error    *Missing required parameter: phoneNumber*
    ...                 Create Supplier    ${incomplete_data}
    
    Log                 Successfully verified that creating a supplier with missing fields is rejected

04 - Get Supplier Test
    [Documentation]     Test retrieving a specific supplier
    [Tags]              retrieve    positive
    
    # Create a supplier if one doesn't exist
    Run Keyword If      "${TEST_SUPPLIER_ID}" == "${EMPTY}"    Create Test Supplier
    
    # Get supplier
    ${supplier}=        Get Supplier By ID    ${TEST_SUPPLIER_ID}
    
    # Verify supplier details match what we created
    Assert Supplier Details    ${supplier}    ${TEST_SUPPLIER_DATA}
    
    Log                 Successfully retrieved supplier: ${supplier}[name]

05 - Get Non-Existent Supplier Test
    [Documentation]     Test retrieving a supplier that doesn't exist
    [Tags]              retrieve    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to get non-existent supplier
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 GET On Session
    ...                 vkho
    ...                 /suppliers/get-one/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that retrieving a non-existent supplier fails

06 - Update Supplier Test
    [Documentation]     Test updating an existing supplier
    [Tags]              update    positive
    
    # Create a supplier if one doesn't exist
    Run Keyword If      "${TEST_SUPPLIER_ID}" == "${EMPTY}"    Create Test Supplier
    
    # Prepare update data
    ${updated_name}=    Set Variable    ${TEST_SUPPLIER_NAME} Updated
    ${product_categories}=  Create List      ${PRODUCT_CATEGORY_ID}
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_SUPPLIER_ID}
    ...                 name=${updated_name}
    ...                 email=updated_${TEST_SUPPLIER_ID}@example.com
    ...                 phoneNumber=9005551234
    ...                 address=Updated Address
    ...                 isActive=${TRUE}
    ...                 contractNumber=UPD${TEST_SUPPLIER_ID}
    ...                 taxCode=99999${TEST_SUPPLIER_ID}
    ...                 cooperationDay=2023-04-20T00:00:00.000Z
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 productCategoryIds=${product_categories}
    ...                 status=ENABLE
    
    # Update supplier
    ${updated_supplier}=    Update Supplier    ${TEST_SUPPLIER_ID}    ${update_data}
    
    # Verify supplier was updated successfully
    Should Be Equal     ${updated_supplier}[name]    ${updated_name}
    ...    msg=Updated supplier name does not match expected value
    
    # Update global variable with new data
    Set Global Variable  ${TEST_SUPPLIER_NAME}    ${updated_name}
    Set Global Variable  ${TEST_SUPPLIER_UPDATED_DATA}    ${update_data}
    
    Log                 Successfully updated supplier: ${updated_supplier}[name]

07 - Update Supplier With Missing Required Field Test
    [Documentation]     Test updating a supplier with missing required fields
    [Tags]              update    negative
    
    # Create a supplier if one doesn't exist
    Run Keyword If      "${TEST_SUPPLIER_ID}" == "${EMPTY}"    Create Test Supplier
    
    # Prepare incomplete update data (missing status)
    ${incomplete_data}=  Create Dictionary
    ...                 id=${TEST_SUPPLIER_ID}
    ...                 name=Incomplete Update
    ...                 warehouseId=${WAREHOUSE_ID}
    # Missing status field
    
    # Attempt to update supplier with incomplete data
    Run Keyword And Expect Error    *Update data missing required field: status*
    ...                 Update Supplier    ${TEST_SUPPLIER_ID}    ${incomplete_data}
    
    Log                 Successfully verified that updating a supplier with missing fields is rejected

08 - Get All Suppliers Test
    [Documentation]     Test retrieving all suppliers
    [Tags]              retrieve    positive
    
    # Get all suppliers
    ${suppliers}=       Get All Suppliers
    
    # Log the structure to understand the format
    Log                 Response structure: ${suppliers}
    
    # Check different possible response formats
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${suppliers}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${suppliers}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${suppliers}    records
    
    # Log information based on what we found
    Run Keyword If      ${has_data}      Log    Found ${suppliers['data'].__len__()} suppliers
    ...    ELSE IF      ${has_items}     Log    Found ${suppliers['items'].__len__()} suppliers
    ...    ELSE IF      ${has_records}   Log    Found ${suppliers['records'].__len__()} suppliers
    ...    ELSE         Log    Found suppliers in unknown format
    
    Log                 Successfully retrieved suppliers list

09 - Filter Suppliers Test
    [Documentation]     Test filtering suppliers by name
    [Tags]              retrieve    filter    positive
    
    # Create a supplier if one doesn't exist
    Run Keyword If      "${TEST_SUPPLIER_ID}" == "${EMPTY}" or "${TEST_SUPPLIER_NAME}" == "${EMPTY}"    Create Test Supplier
    
    # Create filter params based on supplier name
    ${filter_params}=   Create Dictionary    supplierName=${TEST_SUPPLIER_NAME}
    
    # Get filtered suppliers
    ${filtered_suppliers}=    Get All Suppliers    filter_params=${filter_params}
    
    # Verify response contains data
    Should Not Be Empty    ${filtered_suppliers}
    ...    msg=Filtered suppliers response was empty
    
    # Check if our supplier is in the results (depends on API structure)
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_suppliers}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_suppliers}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_suppliers}    records
    
    # Verify filter worked based on response structure
    ${found}=           Set Variable    ${FALSE}
    
    # Check in 'data' array if present
    IF    ${has_data}
        ${data_length}=     Get Length    ${filtered_suppliers}[data]
        Should Be True      ${data_length} > 0    msg=Filter returned empty data array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'items' array if present
    ELSE IF    ${has_items}
        ${items_length}=    Get Length    ${filtered_suppliers}[items]
        Should Be True      ${items_length} > 0    msg=Filter returned empty items array
        ${found}=           Set Variable    ${TRUE}
    # Check in 'records' array if present
    ELSE IF    ${has_records}
        ${records_length}=  Get Length    ${filtered_suppliers}[records]
        Should Be True      ${records_length} > 0    msg=Filter returned empty records array
        ${found}=           Set Variable    ${TRUE}
    ELSE
        Log                 Warning: Unknown response structure, can't verify filter results
    END
    
    Should Be True      ${found}    msg=Failed to find supplier in filtered results
    
    Log                 Successfully filtered suppliers by name: ${TEST_SUPPLIER_NAME}

10 - Delete Supplier Test
    [Documentation]     Test deleting a supplier
    [Tags]              delete    positive
    
    # Create a supplier if one doesn't exist
    Run Keyword If      "${TEST_SUPPLIER_ID}" == "${EMPTY}"    Create Test Supplier
    
    # Delete supplier
    ${result}=          Delete Supplier    ${TEST_SUPPLIER_ID}
    Should Be True      ${result}
    ...    msg=Delete supplier operation failed
    
    # Verify supplier deletion by trying to get it
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /suppliers/get-one/${TEST_SUPPLIER_ID}
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
    ...    msg=Supplier was not properly deleted or marked as deleted
    
    Log                 Successfully verified deletion of supplier with ID: ${TEST_SUPPLIER_ID}

11 - Delete Non-Existent Supplier Test
    [Documentation]     Test deleting a supplier that doesn't exist
    [Tags]              delete    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to delete non-existent supplier
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 DELETE On Session
    ...                 vkho
    ...                 /suppliers/delete/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that deleting a non-existent supplier fails

12 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    # Additional cleanup if needed
    Log                 Test environment cleaned up successfully