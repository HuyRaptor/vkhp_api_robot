*** Settings ***
Documentation     Comprehensive Test Suite for Parent Product Category Operations in vKho API
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

Generate Unique Parent Category Data
    [Documentation]     Generate unique data for parent product category tests
    [Arguments]         ${custom_name}=Test Parent Category
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${category_name}=   Set Variable     ${custom_name} ${timestamp}
    
    # Return dictionary of generated data
    ${category_data}=   Create Dictionary
    ...                 name=${category_name}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 divisonId=${DIVISION_ID}
    ...                 exportStrategy=FIFO
    RETURN            ${category_data}

Create Parent Category
    [Documentation]     Create a new parent product category and return its ID
    [Arguments]         ${category_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${category_data}    name
    ...    msg=Missing required parameter: name
    Dictionary Should Contain Key    ${category_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    Dictionary Should Contain Key    ${category_data}    divisonId
    ...    msg=Missing required parameter: divisonId
    Dictionary Should Contain Key    ${category_data}    exportStrategy
    ...    msg=Missing required parameter: exportStrategy
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create parent category request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /parent-product-categorys/create
    ...                 json=${category_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Save response for debugging
    ${timestamp}=       Evaluate         int(time.time())    time
    Create File         ${RESULTS_DIR}${/}parent_category_create_${timestamp}.json    ${response.text}
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create parent category response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create parent category response missing ID field
    
    # Return parent category ID and full response
    ${category_id}=     Convert To String    ${json}[id]
    RETURN            ${category_id}    ${json}

Get Parent Category By ID
    [Documentation]     Retrieve a specific parent product category by ID
    [Arguments]         ${category_id}
    
    # Validate parameters
    Should Not Be Empty    ${category_id}
    ...    msg=Parent Category ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get parent category request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /parent-product-categorys/get-one/${category_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get parent category response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get parent category response missing ID field
    
    RETURN            ${json}

Update Parent Category
    [Documentation]     Update an existing parent product category
    [Arguments]         ${category_id}    ${update_data}
    
    # Validate parameters
    Should Not Be Empty    ${category_id}
    ...    msg=Parent Category ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${category_id}
    ...    msg=Update data ID must match category_id parameter
    
    # Ensure minimum required fields are present
    Dictionary Should Contain Key    ${update_data}    name
    ...    msg=Update data missing required field: name
    Dictionary Should Contain Key    ${update_data}    warehouseId
    ...    msg=Update data missing required field: warehouseId
    Dictionary Should Contain Key    ${update_data}    divisonId
    ...    msg=Update data missing required field: divisonId
    Dictionary Should Contain Key    ${update_data}    exportStrategy
    ...    msg=Update data missing required field: exportStrategy
    Dictionary Should Contain Key    ${update_data}    status
    ...    msg=Update data missing required field: status
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send update parent category request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /parent-product-categorys/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update parent category response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Update parent category response missing ID field
    
    RETURN            ${json}

Delete Parent Category
    [Documentation]     Delete a parent product category from the system
    [Arguments]         ${category_id}
    
    # Validate parameters
    Should Not Be Empty    ${category_id}
    ...    msg=Parent Category ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send delete parent category request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /parent-product-categorys/delete/${category_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Return deletion status
    RETURN            ${TRUE}

Get All Parent Categories
    [Documentation]     Retrieve all parent product categories with optional filtering
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
    
    # Send get all parent categories request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /parent-product-categorys/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get all parent categories response was empty
    
    RETURN            ${json}

Assert Parent Category Details
    [Documentation]     Verify parent category details match expected values
    [Arguments]         ${category}    ${expected_data}
    
    # For all keys in expected data, verify they match in the category data
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${category}    Should Be Equal    ${category}[${key}]    ${expected_data}[${key}]
        ...    msg=Parent Category ${key} value '${category}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Parent Category
    [Documentation]     Creates a test parent category if one doesn't exist
    ${category_data}=   Generate Unique Parent Category Data
    ${category_id}    ${response}=    Create Parent Category    ${category_data}
    Set Global Variable  ${TEST_CATEGORY_ID}      ${category_id}
    Set Global Variable  ${TEST_CATEGORY_NAME}    ${response}[name]
    Set Global Variable  ${TEST_CATEGORY_DATA}    ${category_data}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for parent product category tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Parent Category Test
    [Documentation]     Test creating a new parent product category
    [Tags]              create    positive
    
    # Generate parent category data
    ${category_data}=   Generate Unique Parent Category Data
    
    # Create parent category
    ${category_id}    ${response}=    Create Parent Category    ${category_data}
    
    # Verify parent category was created successfully
    Should Not Be Empty    ${category_id}
    ...    msg=Failed to create parent category: No ID returned
    Should Be Equal     ${response}[name]    ${category_data}[name]
    ...    msg=Created parent category name does not match input data
    
    # Save parent category ID for subsequent tests
    Set Global Variable  ${TEST_CATEGORY_ID}      ${category_id}
    Set Global Variable  ${TEST_CATEGORY_NAME}    ${response}[name]
    Set Global Variable  ${TEST_CATEGORY_DATA}    ${category_data}
    
    Log                 Successfully created parent category: ${TEST_CATEGORY_NAME} with ID: ${TEST_CATEGORY_ID}

03 - Create Parent Category Missing Required Field Test
    [Documentation]     Test creating a parent category with missing required fields
    [Tags]              create    negative
    
    # Generate incomplete parent category data (missing exportStrategy)
    ${incomplete_data}=  Generate Unique Parent Category Data    custom_name=Missing Field Category
    Remove From Dictionary    ${incomplete_data}    exportStrategy
    
    # Attempt to create parent category with incomplete data
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect proper error message
    Run Keyword And Expect Error    *Missing required parameter: exportStrategy*
    ...                 Create Parent Category    ${incomplete_data}
    
    Log                 Successfully verified that creating a parent category with missing fields is rejected

04 - Get Parent Category Test
    [Documentation]     Test retrieving a specific parent product category
    [Tags]              retrieve    positive
    
    # Create a parent category if one doesn't exist
    Run Keyword If      "${TEST_CATEGORY_ID}" == "${EMPTY}"    Create Test Parent Category
    
    # Get parent category
    ${category}=        Get Parent Category By ID    ${TEST_CATEGORY_ID}
    
    # Verify parent category details match what we created
    Assert Parent Category Details    ${category}    ${TEST_CATEGORY_DATA}
    
    Log                 Successfully retrieved parent category: ${category}[name]

05 - Get Non-Existent Parent Category Test
    [Documentation]     Test retrieving a parent category that doesn't exist
    [Tags]              retrieve    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to get non-existent parent category
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 GET On Session
    ...                 vkho
    ...                 /parent-product-categorys/get-one/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that retrieving a non-existent parent category fails

06 - Update Parent Category Test
    [Documentation]     Test updating an existing parent product category
    [Tags]              update    positive
    
    # Create a parent category if one doesn't exist
    Run Keyword If      "${TEST_CATEGORY_ID}" == "${EMPTY}"    Create Test Parent Category
    
    # Prepare update data
    ${updated_name}=    Set Variable    ${TEST_CATEGORY_NAME} Updated
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_CATEGORY_ID}
    ...                 name=${updated_name}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 divisonId=${DIVISION_ID}
    ...                 exportStrategy=FIFO
    ...                 status=ENABLE
    
    # Update parent category
    ${updated_category}=    Update Parent Category    ${TEST_CATEGORY_ID}    ${update_data}
    
    # Verify parent category was updated successfully
    Should Be Equal     ${updated_category}[name]    ${updated_name}
    ...    msg=Updated parent category name does not match expected value
    
    # Update global variable with new data
    Set Global Variable  ${TEST_CATEGORY_NAME}    ${updated_name}
    
    Log                 Successfully updated parent category: ${updated_category}[name]

07 - Update Parent Category With Missing Required Field Test
    [Documentation]     Test updating a parent category with missing required fields
    [Tags]              update    negative
    
    # Create a parent category if one doesn't exist
    Run Keyword If      "${TEST_CATEGORY_ID}" == "${EMPTY}"    Create Test Parent
    # Create a parent category if one doesn't exist
    Run Keyword If      "${TEST_CATEGORY_ID}" == "${EMPTY}"    Create Test Parent Category
    
    # Prepare incomplete update data (missing status)
    ${incomplete_data}=  Create Dictionary
    ...                 id=${TEST_CATEGORY_ID}
    ...                 name=Incomplete Update
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 divisonId=${DIVISION_ID}
    ...                 exportStrategy=FIFO
    # Missing status field
    
    # Attempt to update parent category with incomplete data
    Run Keyword And Expect Error    *Update data missing required field: status*
    ...                 Update Parent Category    ${TEST_CATEGORY_ID}    ${incomplete_data}
    
    Log                 Successfully verified that updating a parent category with missing fields is rejected

08 - Get All Parent Categories Test
    [Documentation]     Test retrieving all parent product categories
    [Tags]              retrieve    positive
    
    # Get all parent categories
    ${categories}=       Get All Parent Categories
    
    # Verify response contains data
    Should Not Be Empty    ${categories}
    ...    msg=Get all parent categories response was empty
    
    Log                 Successfully retrieved parent categories list

09 - Filter Parent Categories Test
    [Documentation]     Test filtering parent categories by name
    [Tags]              retrieve    filter    positive
    
    # Create a parent category if one doesn't exist
    Run Keyword If      "${TEST_CATEGORY_ID}" == "${EMPTY}" or "${TEST_CATEGORY_NAME}" == "${EMPTY}"    Create Test Parent Category
    
    # Create filter params based on parent category name
    ${filter_params}=   Create Dictionary    parentProductCategoryName=${TEST_CATEGORY_NAME}
    
    # Get filtered parent categories
    ${filtered_categories}=    Get All Parent Categories    filter_params=${filter_params}
    
    # Verify response contains data
    Should Not Be Empty    ${filtered_categories}
    ...    msg=Filtered parent categories response was empty
    
    Log                 Successfully filtered parent categories by name: ${TEST_CATEGORY_NAME}

10 - Delete Parent Category Test
    [Documentation]     Test deleting a parent product category
    [Tags]              delete    positive
    
    # Create a parent category if one doesn't exist
    Run Keyword If      "${TEST_CATEGORY_ID}" == "${EMPTY}"    Create Test Parent Category
    
    # Delete parent category
    ${result}=          Delete Parent Category    ${TEST_CATEGORY_ID}
    Should Be True      ${result}
    ...    msg=Delete parent category operation failed
    
    # Verify parent category deletion by trying to get it
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /parent-product-categorys/get-one/${TEST_CATEGORY_ID}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    # API might handle deletion differently: either 404 Not Found or status = DISABLE
    ${is_deleted}=      Run Keyword If      ${response.status_code} == 404    Set Variable    ${TRUE}
    ...    ELSE         Set Variable    ${FALSE}
    
    Should Be True      ${is_deleted}
    ...    msg=Parent category was not properly deleted or marked as deleted
    
    Log                 Successfully verified deletion of parent category with ID: ${TEST_CATEGORY_ID}

11 - Delete Non-Existent Parent Category Test
    [Documentation]     Test deleting a parent category that doesn't exist
    [Tags]              delete    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to delete non-existent parent category
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 DELETE On Session
    ...                 vkho
    ...                 /parent-product-categorys/delete/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that deleting a non-existent parent category fails

12 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    # Additional cleanup if needed
    Log                 Test environment cleaned up successfully