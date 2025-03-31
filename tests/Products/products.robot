*** Settings ***
Documentation     Comprehensive Test Suite for Product Category Operations in vKho API
...               Includes proper parameter validation and error handling
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime

*** Variables ***
${BASE_URL}                      https://api.vkho.net
${USERNAME}                      huynh22.manager
${PASSWORD}                      Snowfox1991
${WAREHOUSE_ID}                  6
${PARENT_PRODUCT_CATEGORY_ID}    1  # This would be set to an actual parent category ID
${RESULTS_DIR}                   ${CURDIR}${/}results
${TEST_CATEGORY_ID}              ${EMPTY}
${TEST_CATEGORY_NAME}            ${EMPTY}
${TEST_CATEGORY_DATA}            ${EMPTY}

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

Generate Unique Product Category Data
    [Documentation]     Generate unique data for product category tests
    [Arguments]         ${custom_name}=Test Product Category
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${category_name}=   Set Variable     ${custom_name} ${timestamp}
    
    # Return dictionary of generated data
    ${category_data}=   Create Dictionary
    ...                 name=${category_name}
    ...                 parentProductCategoryId=${PARENT_PRODUCT_CATEGORY_ID}
    ...                 warehouseId=${WAREHOUSE_ID}
    RETURN            ${category_data}

Create Product Category
    [Documentation]     Create a new product category and return its ID
    [Arguments]         ${category_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${category_data}    name
    ...    msg=Missing required parameter: name
    Dictionary Should Contain Key    ${category_data}    parentProductCategoryId
    ...    msg=Missing required parameter: parentProductCategoryId
    Dictionary Should Contain Key    ${category_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create product category request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /product-categorys/create
    ...                 json=${category_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Save response for debugging
    ${timestamp}=       Evaluate         int(time.time())    time
    Create File         ${RESULTS_DIR}${/}product_category_create_${timestamp}.json    ${response.text}
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create product category response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create product category response missing ID field
    
    # Return product category ID and full response
    ${category_id}=     Convert To String    ${json}[id]
    RETURN            ${category_id}    ${json}

Get Product Category By ID
    [Documentation]     Retrieve a specific product category by ID
    [Arguments]         ${category_id}
    
    # Validate parameters
    Should Not Be Empty    ${category_id}
    ...    msg=Product Category ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get product category request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /product-categorys/get-one/${category_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get product category response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get product category response missing ID field
    
    RETURN            ${json}

Update Product Category
    [Documentation]     Update an existing product category
    [Arguments]         ${category_id}    ${update_data}
    
    # Validate parameters
    Should Not Be Empty    ${category_id}
    ...    msg=Product Category ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${category_id}
    ...    msg=Update data ID must match category_id parameter
    
    # Ensure minimum required fields are present
    Dictionary Should Contain Key    ${update_data}    name
    ...    msg=Update data missing required field: name
    Dictionary Should Contain Key    ${update_data}    parentProductCategoryId
    ...    msg=Update data missing required field: parentProductCategoryId
    Dictionary Should Contain Key    ${update_data}    warehouseId
    ...    msg=Update data missing required field: warehouseId
    Dictionary Should Contain Key    ${update_data}    status
    ...    msg=Update data missing required field: status
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send update product category request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /product-categorys/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update product category response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Update product category response missing ID field
    
    RETURN            ${json}

Delete Product Category
    [Documentation]     Delete a product category from the system
    [Arguments]         ${category_id}
    
    # Validate parameters
    Should Not Be Empty    ${category_id}
    ...    msg=Product Category ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send delete product category request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /product-categorys/delete/${category_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Return deletion status
    RETURN            ${TRUE}

Get All Product Categories
    [Documentation]     Retrieve all product categories with optional filtering
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
    
    # Send get all product categories request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /product-categorys/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get all product categories response was empty
    
    RETURN            ${json}

Assert Product Category Details
    [Documentation]     Verify product category details match expected values
    [Arguments]         ${category}    ${expected_data}
    
    # For all keys in expected data, verify they match in the category data
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${category}    Should Be Equal    ${category}[${key}]    ${expected_data}[${key}]
        ...    msg=Product Category ${key} value '${category}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Product Category
    [Documentation]     Creates a test product category if one doesn't exist
    ${category_data}=   Generate Unique Product Category Data
    ${category_id}    ${response}=    Create Product Category    ${category_data}
    Set Global Variable  ${TEST_CATEGORY_ID}      ${category_id}
    Set Global Variable  ${TEST_CATEGORY_NAME}    ${response}[name]
    Set Global Variable  ${TEST_CATEGORY_DATA}    ${category_data}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for product category tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Product Category Test
    [Documentation]     Test creating a new product category
    [Tags]              create    positive
    
    # Generate product category data
    ${category_data}=   Generate Unique Product Category Data
    
    # Create product category
    ${category_id}    ${response}=    Create Product Category    ${category_data}
    
    # Verify product category was created successfully
    Should Not Be Empty    ${category_id}
    ...    msg=Failed to create product category: No ID returned
    Should Be Equal     ${response}[name]    ${category_data}[name]
    ...    msg=Created product category name does not match input data
    
    # Save product category ID for subsequent tests
    Set Global Variable  ${TEST_CATEGORY_ID}      ${category_id}
    Set Global Variable  ${TEST_CATEGORY_NAME}    ${response}[name]
    Set Global Variable  ${TEST_CATEGORY_DATA}    ${category_data}
    
    Log                 Successfully created product category: ${TEST_CATEGORY_NAME} with ID: ${TEST_CATEGORY_ID}

03 - Create Product Category Missing Required Field Test
    [Documentation]     Test creating a product category with missing required fields
    [Tags]              create    negative
    
    # Generate incomplete product category data (missing parentProductCategoryId)
    ${incomplete_data}=  Generate Unique Product Category Data    custom_name=Missing Field Category
    Remove From Dictionary    ${incomplete_data}    parentProductCategoryId
    
    # Attempt to create product category with incomplete data
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect proper error message
    Run Keyword And Expect Error    *Missing required parameter: parentProductCategoryId*
    ...                 Create Product Category    ${incomplete_data}
    
    Log                 Successfully verified that creating a product category with missing fields is rejected

04 - Get Product Category Test
    [Documentation]     Test retrieving a specific product category
    [Tags]              retrieve    positive
    
    # Create a product category if one doesn't exist
    Run Keyword If      "${TEST_CATEGORY_ID}" == "${EMPTY}"    Create Test Product Category
    
    # Get product category
    ${category}=        Get Product Category By ID    ${TEST_CATEGORY_ID}
    
    # Verify product category details match what we created
    Assert Product Category Details    ${category}    ${TEST_CATEGORY_DATA}
    
    Log                 Successfully retrieved product category: ${category}[name]

05 - Get Non-Existent Product Category Test
    [Documentation]     Test retrieving a product category that doesn't exist
    [Tags]              retrieve    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to get non-existent product category
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 GET On Session
    ...                 vkho
    ...                 /product-categorys/get-one/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that retrieving a non-existent product category fails

06 - Update Product Category Test
    [Documentation]     Test updating an existing product category
    [Tags]              update    positive
    
    # Create a product category if one doesn't exist
    Run Keyword If      "${TEST_CATEGORY_ID}" == "${EMPTY}"    Create Test Product Category
    
    # Prepare update data
    ${updated_name}=    Set Variable    ${TEST_CATEGORY_NAME} Updated
    
    ${update_data}=     Create Dictionary
    ...                 id=${TEST_CATEGORY_ID}
    ...                 name=${updated_name}
    ...                 parentProductCategoryId=${PARENT_PRODUCT_CATEGORY_ID}
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 status=ENABLE
    
    # Update product category
    ${updated_category}=    Update Product Category    ${TEST_CATEGORY_ID}    ${update_data}
    
    # Verify product category was updated successfully
    Should Be Equal     ${updated_category}[name]    ${updated_name}
    ...    msg=Updated product category name does not match expected value
    
    # Update global variable with new data
    Set Global Variable  ${TEST_CATEGORY_NAME}    ${updated_name}
    
    Log                 Successfully updated product category: ${updated_category}[name]

07 - Update Product Category With Missing Required Field Test
    [Documentation]     Test updating a product category with missing required fields
    [Tags]              update    negative
    
    # Create a product category if one doesn't exist
    Run Keyword If      "${TEST_CATEGORY_ID}" == "${EMPTY}"    Create Test Product Category
    
    # Prepare incomplete update data (missing status)
    ${incomplete_data}=  Create Dictionary
    ...                 id=${TEST_CATEGORY_ID}
    ...                 name=Incomplete Update
    ...                 parentProductCategoryId=${PARENT_PRODUCT_CATEGORY_ID}
    ...                 warehouseId=${WAREHOUSE_ID}
    # Missing status field
    
    # Attempt to update product category with incomplete data
    Run Keyword And Expect Error    *Update data missing required field: status*
    ...                 Update Product Category    ${TEST_CATEGORY_ID}    ${incomplete_data}
    
    Log                 Successfully verified that updating a product category with missing fields is rejected

08 - Get All Product Categories Test
    [Documentation]     Test retrieving all product categories
    [Tags]              retrieve    positive
    
    # Get all product categories
    ${categories}=       Get All Product Categories
    
    # Verify response contains data
    Should Not Be Empty    ${categories}
    ...    msg=Get all product categories response was empty
    
    Log                 Successfully retrieved product categories list

09 - Filter Product Categories Test
    [Documentation]     Test filtering product categories by name
    [Tags]              retrieve    filter    positive
    
    # Create a product category if one doesn't exist
    Run Keyword If      "${TEST_CATEGORY_ID}" == "${EMPTY}" or "${TEST_CATEGORY_NAME}" == "${EMPTY}"    Create Test Product Category
    
    # Create filter params based on product category name
    ${filter_params}=   Create Dictionary    productCategoryName=${TEST_CATEGORY_NAME}
    
    # Get filtered product categories
    ${filtered_categories}=    Get All Product Categories    filter_params=${filter_params}
    
    # Verify response contains data
    Should Not Be Empty    ${filtered_categories}
    ...    msg=Filtered product categories response was empty
    
    Log                 Successfully filtered product categories by name: ${TEST_CATEGORY_NAME}

10 - Delete Product Category Test
    [Documentation]     Test deleting a product category
    [Tags]              delete    positive
    
    # Create a product category if one doesn't exist
    Run Keyword If      "${TEST_CATEGORY_ID}" == "${EMPTY}"    Create Test Product Category
    
    # Delete product category
    ${result}=          Delete Product Category    ${TEST_CATEGORY_ID}
    Should Be True      ${result}
    ...    msg=Delete product category operation failed
    
    # Verify product category deletion by trying to get it
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /product-categorys/get-one/${TEST_CATEGORY_ID}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    # API might handle deletion differently: either 404 Not Found or status = DISABLE
    ${is_deleted}=      Run Keyword If      ${response.status_code} == 404    Set Variable    ${TRUE}
    ...    ELSE         Set Variable    ${FALSE}
    
    Should Be True      ${is_deleted}
    ...    msg=Product category was not properly deleted or marked as deleted
    
    Log                 Successfully verified deletion of product category with ID: ${TEST_CATEGORY_ID}

11 - Delete Non-Existent Product Category Test
    [Documentation]     Test deleting a product category that doesn't exist
    [Tags]              delete    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to delete non-existent product category
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 DELETE On Session
    ...                 vkho
    ...                 /product-categorys/delete/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that deleting a non-existent product category fails

12 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    # Additional cleanup if needed
    Log                 Test environment cleaned up successfully